#!/usr/bin/env python3
"""Convert an Autopal traffic log export into a replayable .elm fixture.

Input format (ARCHITECTURE.md §5.1):
    # autopal-traffic-log v1
    # adapter=ELM327 v1.5 transport=SPP device=ANDROID-VLINK ...
    <epoch ms> <TX|RX|INFO> <text>

Usage:
    traffic_log_to_elm.py <log.txt> <out.elm> [--name "description"] [--force]

Standard library only. Exits non-zero with a message when the log cannot be converted faithfully.
"""
import argparse
import re
import sys
from collections import Counter, OrderedDict

SAMPLE_VIN = "1HGCM82633A004352"
DEFAULT_TIMEOUT_MS = 2500
LINE_RE = re.compile(r"^(\d+)\s+(TX|RX|INFO)\s?(.*)$")
TIMEOUT_RE = re.compile(r"^TIMEOUT after (\d+)ms on (\S+)")
UNSOLICITED_RE = re.compile(r"^Unsolicited reply dropped: (.*)$")
FIRST_RPM_RE = re.compile(r"^010C1?$")


class Exchange:
    def __init__(self, t_ms, command):
        self.t_ms = t_ms
        self.command = command
        self.reply = None          # str with literal \r sequences, or None
        self.timed_out = False
        self.late_reply = None     # reply that arrived after the timeout, if logged


def parse_log(path):
    header = {}
    exchanges = []
    current = None
    with open(path, encoding="utf-8", errors="replace") as fh:
        for n, raw in enumerate(fh, 1):
            line = raw.rstrip("\n")
            if not line.strip():
                continue
            if line.startswith("#"):
                for key, val in re.findall(r"(\w+)=(\S+(?: v[\d.]+)?)", line):
                    header[key] = val
                continue
            m = LINE_RE.match(line)
            if not m:
                sys.exit(f"line {n}: not a traffic log entry: {line!r}")
            t_ms, kind, text = int(m.group(1)), m.group(2), m.group(3)
            if kind == "TX":
                current = Exchange(t_ms, text.strip())
                exchanges.append(current)
            elif kind == "RX":
                if current is None or current.reply is not None or current.timed_out:
                    # RX without a pending TX: treat as unsolicited, attach to the last exchange if it timed out.
                    if current is not None and current.timed_out and current.late_reply is None:
                        current.late_reply = text
                    continue
                current.reply = text
            else:  # INFO
                tm = TIMEOUT_RE.match(text)
                if tm and current is not None and current.command == tm.group(2):
                    current.timed_out = True
                    continue
                um = UNSOLICITED_RE.match(text)
                if um and current is not None and current.timed_out and current.late_reply is None:
                    current.late_reply = um.group(1)
    return header, exchanges


def hex_payload_spans(line):
    """Return (prefix, payload, spaced) for one reply line, or None if it has no hex payload."""
    m = re.match(r"^(\s*[0-9A-Fa-f]\s*:\s*)?([0-9A-Fa-f ]+)$", line)
    if not m:
        return None
    prefix = m.group(1) or ""
    payload = m.group(2)
    return prefix, payload, " " in payload.strip()


def anonymise_vin(reply):
    """Replace a 17-character VIN inside a 0902 reply, keeping frame layout and spacing."""
    lines = reply.split("\\r")
    parsed = []
    all_bytes = []
    for idx, line in enumerate(lines):
        span = hex_payload_spans(line)
        compact = span[1].replace(" ", "") if span else ""
        # Skip the 3-digit multi-frame length line and non-hex lines.
        if not span or len(compact) % 2 or (not span[0] and len(compact) == 3):
            parsed.append(None)
            continue
        data = [int(compact[i:i + 2], 16) for i in range(0, len(compact), 2)]
        parsed.append((span[0], span[2], len(all_bytes), len(data)))
        all_bytes.extend(data)

    text = "".join(chr(b) if 0x30 <= b <= 0x5A else "\x00" for b in all_bytes)
    m = re.search(r"[0-9A-HJ-NPR-Z]{17}", text)
    if not m:
        # Non-CAN replies interleave 49 02 NN headers; search ignoring them.
        return reply, False
    start = m.start()
    for i, ch in enumerate(SAMPLE_VIN):
        all_bytes[start + i] = ord(ch)

    out = []
    for line, info in zip(lines, parsed):
        if info is None:
            out.append(line)
            continue
        prefix, spaced, offset, length = info
        chunk = all_bytes[offset:offset + length]
        sep = " " if spaced else ""
        out.append(prefix + sep.join(f"{b:02X}" for b in chunk))
    return "\\r".join(out), True


def anonymise_noncan_vin(reply):
    """Non-CAN VIN: lines '49 02 NN aa bb cc dd'. Rebuild data bytes only."""
    lines = reply.split("\\r")
    rows = []
    for line in lines:
        compact = line.replace(" ", "")
        if len(compact) == 14 and compact[:4].upper() == "4902":
            rows.append(compact)
        else:
            return reply, False
    data = []
    for r in rows:
        data.extend(int(r[i:i + 2], 16) for i in range(6, 14, 2))
    printable = [i for i, b in enumerate(data) if b != 0]
    if len(printable) < 17:
        return reply, False
    positions = printable[-17:]
    for pos, ch in zip(positions, SAMPLE_VIN):
        data[pos] = ord(ch)
    out = []
    for i, r in enumerate(rows):
        out.append(r[:6] + "".join(f"{b:02X}" for b in data[i * 4:i * 4 + 4]))
    return "\\r".join(out), True


def scrub(command, reply):
    if command.replace(" ", "").upper() != "0902" or reply is None:
        return reply, False
    new, changed = anonymise_vin(reply)
    if changed:
        return new, True
    return anonymise_noncan_vin(reply)


def build(header, exchanges, name):
    if not exchanges:
        sys.exit("log contains no TX entries")

    boundary = None
    for i, ex in enumerate(exchanges):
        if FIRST_RPM_RE.match(ex.command) and ex.reply and ex.reply.replace(" ", "").upper().find("410C") >= 0:
            boundary = i
            break
    if boundary is None:
        boundary = len(exchanges) - 1  # e.g. ignition-off session: everything is init

    vin_scrubbed = False
    init_lines = []
    for ex in exchanges[: boundary + 1]:
        reply, changed = scrub(ex.command, ex.reply)
        vin_scrubbed |= changed
        init_lines.append(f"TX {ex.command}")
        if ex.timed_out:
            init_lines.append(f"# timed out in the original session; late reply: {ex.late_reply or 'not logged'}")
            init_lines.append(f"RX @delay={DEFAULT_TIMEOUT_MS + 200} {ex.late_reply or ''}".rstrip())
        else:
            init_lines.append(f"RX {reply if reply is not None else ''}")

    live = OrderedDict()
    for ex in exchanges[boundary + 1:]:
        reply, changed = scrub(ex.command, ex.reply)
        vin_scrubbed |= changed
        if ex.timed_out:
            reply = f"@delay={DEFAULT_TIMEOUT_MS + 200} {ex.late_reply or ''}".rstrip()
        live.setdefault(ex.command, []).append(reply if reply is not None else "")

    live_lines = []
    for cmd, replies in live.items():
        common = Counter(r for r in replies if not r.startswith("@delay")).most_common(1)
        steady = common[0][0] if common else replies[-1]
        if replies[0] != steady:
            live_lines.append(f"{cmd} =>1 {replies[0]}")
        live_lines.append(f"{cmd} => {steady}")
        others = sorted(set(replies[1:]) - {steady})
        if others:
            live_lines.append(f"# {cmd} also replied (not replayed): " + " | ".join(others[:3]))

    out = []
    desc = name or "Recorded session"
    meta = ", ".join(f"{k}={v}" for k, v in header.items() if k in ("adapter", "transport", "device", "exported"))
    out.append(f"@name   {desc}" + (f" ({meta})" if meta else ""))
    if header.get("transport", "").upper() == "BLE":
        out.append("@chunk  20")
    out.append("@cycles 2")
    out.append("# TODO: add @expect lines for what SHOULD happen (see elm-sessions/README.md), e.g.")
    out.append("# @expect phase LIVE")
    out.append("# @expect reading RPM <value> <tolerance>")
    if vin_scrubbed:
        out.append(f"# VIN replaced with sample {SAMPLE_VIN}")
    out.append("")
    out.append("[init]")
    out.extend(init_lines)
    out.append("")
    out.append("[live]")
    out.extend(live_lines)
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("log")
    ap.add_argument("out")
    ap.add_argument("--name", default="")
    ap.add_argument("--force", action="store_true", help="overwrite an existing output file")
    args = ap.parse_args()

    import os
    if os.path.exists(args.out) and not args.force:
        sys.exit(f"{args.out} exists; recorded fixtures are never overwritten (use --force only for a fixture not yet committed)")

    header, exchanges = parse_log(args.log)
    text = build(header, exchanges, args.name)
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(f"wrote {args.out}: {len(exchanges)} exchanges")


if __name__ == "__main__":
    main()
