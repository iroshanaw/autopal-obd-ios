#!/usr/bin/env python3
"""Generate SwiftUI colour, spacing and radius tokens from the Autopal Design System's tokens.json.

    python3 scripts/tokens_to_swift.py           # write Autopal/Theme/AutopalTokens.swift
    python3 scripts/tokens_to_swift.py --check   # exit 1 if missing or out of date

Source: docs/design/tokens.json (copy of the design system's project/tokens.json; never edit here).
The output is added to both the app target and the widget extension. Standard library only.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/design/tokens.json"
OUT = ROOT / "Autopal/Theme/AutopalTokens.swift"


def camel(name):
    parts = re.split(r"[-_.]", name)
    return parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])


def resolve(tokens, name, theme, seen=()):
    if name in seen:
        sys.exit(f"tokens.json: alias cycle at '{name}'")
    tok = tokens.get(name)
    if tok is None:
        sys.exit(f"tokens.json: alias to missing token '{name}'")
    value = tok["value"]
    if isinstance(value, dict):
        value = value.get(theme) or next(iter(value.values()))
    alias = re.fullmatch(r"\{(.+)\}", value)
    return resolve(tokens, alias.group(1), theme, seen + (name,)) if alias else value


def hex_parts(value, name):
    m = re.fullmatch(r"#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?", value)
    if not m:
        sys.exit(f"tokens.json: colour '{name}' has unsupported value '{value}' (use #rrggbb or #rrggbbaa)")
    alpha = int(m.group(2), 16) / 255 if m.group(2) else 1.0
    return f"0x{m.group(1).upper()}", f"{alpha:.3f}".rstrip("0").rstrip(".") if alpha < 1 else "1"


def px(value, name):
    m = re.fullmatch(r"(\d+(?:\.\d+)?)px", value)
    if not m:
        sys.exit(f"tokens.json: '{name}' must be in px, got '{value}'")
    return m.group(1)


def generate():
    data = json.loads(SRC.read_text(encoding="utf-8"))
    themes = [t["id"] for t in data["color"]["themes"]]
    if "light" not in themes or "dark" not in themes:
        sys.exit("tokens.json: expected themes 'light' and 'dark'")
    colors = data["color"]["tokens"]
    by_name = {t["name"]: t for t in colors}
    out = [
        "// GENERATED from docs/design/tokens.json by scripts/tokens_to_swift.py. Do not edit by hand.",
        f"// Design system: {data.get('name', 'Autopal')} v{data.get('version', 1)}.",
        "import SwiftUI",
        "#if canImport(UIKit)",
        "import UIKit",
        "#endif",
        "",
        "public enum AutopalTokens {",
    ]
    for t in colors:
        lh, la = hex_parts(resolve(by_name, t["name"], "light"), t["name"])
        dh, da = hex_parts(resolve(by_name, t["name"], "dark"), t["name"])
        out.append(f"    /// {t.get('usage', '')}")
        out.append(f"    public static let {camel(t['name'])} = Color(light: {lh}, lightAlpha: {la}, dark: {dh}, darkAlpha: {da})")
    out.append("")
    out.append("    public enum Spacing {")
    for t in data.get("spacing", {}).get("tokens", []):
        out.append(f"        /// {t.get('usage', '')}")
        out.append(f"        public static let {camel(t['name'].replace('space-', 's'))}: CGFloat = {px(t['value'], t['name'])}")
    out.append("    }")
    out.append("")
    out.append("    public enum Radius {")
    for t in data.get("radius", {}).get("tokens", []):
        out.append(f"        /// {t.get('usage', '')}")
        out.append(f"        public static let {camel(t['name'].replace('radius-', ''))}: CGFloat = {px(t['value'], t['name'])}")
    out.append("    }")
    out.append("}")
    out += [
        "",
        "extension Color {",
        "    /// A colour that follows light/dark appearance (phone, widgets, CarPlay).",
        "    init(light: UInt32, lightAlpha: Double, dark: UInt32, darkAlpha: Double) {",
        "        #if canImport(UIKit)",
        "        self.init(uiColor: UIColor { traits in",
        "            let isDark = traits.userInterfaceStyle == .dark",
        "            let hex = isDark ? dark : light",
        "            let alpha = isDark ? darkAlpha : lightAlpha",
        "            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,",
        "                           blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)",
        "        })",
        "        #else",
        "        self.init(red: Double((dark >> 16) & 0xFF) / 255, green: Double((dark >> 8) & 0xFF) / 255,",
        "                  blue: Double(dark & 0xFF) / 255, opacity: darkAlpha)",
        "        #endif",
        "    }",
        "}",
    ]
    return "\n".join(out) + "\n"


def main():
    if not SRC.exists():
        sys.exit(f"missing {SRC.relative_to(ROOT)}; copy tokens.json from the Autopal Design System first")
    text = generate()
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print(f"{OUT.relative_to(ROOT)} is missing or out of date; run: python3 scripts/tokens_to_swift.py")
            sys.exit(1)
        print("Swift tokens up to date")
        return
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
