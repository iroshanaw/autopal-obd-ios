import Foundation
@testable import AutopalCore

final class FixtureTransport: ObdTransport, @unchecked Sendable {
    struct LiveEntry {
        let reply: String
        let delayMs: Int?
        let isOnce: Bool
    }

    struct SessionScript {
        var name: String = ""
        var chunkSize: Int? = nil
        var cycles: Int = 2
        var expectations: [(key: String, value: String)] = []
        var initSteps: [(tx: String, rx: String)] = []
        var liveEntries: [String: [LiveEntry]] = [:]
    }

    let label: String = "FixtureTransport"
    let script: SessionScript
    let clock: any Clock<Duration>

    private let stream: AsyncStream<Data>
    private let continuation: AsyncStream<Data>.Continuation

    private let linkStream: AsyncStream<LinkState>
    private let linkContinuation: AsyncStream<LinkState>.Continuation

    private var initIndex = 0
    private var liveTable: [String: [LiveEntry]] = [:]

    var sentCommands: [String] = []
    var unscriptedCommands: [String] = []
    var initMismatches: [String] = []

    init(script: SessionScript, clock: any Clock<Duration>) {
        self.script = script
        self.clock = clock
        self.liveTable = script.liveEntries

        var cont: AsyncStream<Data>.Continuation!
        self.stream = AsyncStream<Data> { c in
            cont = c
        }
        self.continuation = cont

        var lCont: AsyncStream<LinkState>.Continuation!
        self.linkStream = AsyncStream<LinkState> { c in
            lCont = c
        }
        self.linkContinuation = lCont
        lCont.yield(.connected)
    }

    var incoming: AsyncStream<Data> {
        stream
    }

    var linkState: AsyncStream<LinkState> {
        linkStream
    }

    func connect() async throws {}

    func close() async {
        continuation.finish()
        linkContinuation.finish()
    }

    func write(_ bytes: Data) async throws {
        guard let cmdStr = String(data: bytes, encoding: .utf8) else {
            return
        }
        let trimmedCmd = cmdStr.trimmingCharacters(in: .whitespacesAndNewlines)
        sentCommands.append(trimmedCmd)

        if initIndex < script.initSteps.count {
            let expectedTx = script.initSteps[initIndex].tx
            let rx = script.initSteps[initIndex].rx
            if trimmedCmd != expectedTx {
                initMismatches.append("Expected TX '\(expectedTx)', got '\(trimmedCmd)' at step \(initIndex)")
            }
            initIndex += 1
            await emitReply(rx)
        } else {
            // Live table lookup
            if var entries = liveTable[trimmedCmd], !entries.isEmpty {
                let entry = entries.removeFirst()
                if !entry.isOnce {
                    // Put back recurring entry
                    entries.append(entry)
                }
                liveTable[trimmedCmd] = entries

                if entry.delayMs != nil {
                    let replyToEmit = entry.reply
                    Task { [weak self, clock] in
                        guard let self else { return }
                        let testClock = clock as? TestClock

                        // Wait for timeout sleep to register in ElmSession
                        while (testClock?.sleeperCount ?? 0) == 0 {
                            try? await Task.sleep(nanoseconds: 1_000_000)
                        }

                        // Advance clock past the 2500ms timeout
                        testClock?.advance(by: .milliseconds(2501))

                        // Brief pause to allow handleTimeout to execute and enter drain
                        try? await Task.sleep(nanoseconds: 5_000_000)

                        // Emit late reply during drain window
                        await self.emitReply(replyToEmit)
                    }
                } else {
                    await emitReply(entry.reply)
                }
            } else {
                unscriptedCommands.append(trimmedCmd)
                await emitReply("?")
            }
        }
    }

    private func emitReply(_ rawReply: String) async {
        let unescaped = rawReply.replacingOccurrences(of: "\\r", with: "\r")
        let fullReply = unescaped + "\r\r>"
        let data = Data(fullReply.utf8)

        if let chunk = script.chunkSize, chunk > 0 {
            var offset = 0
            while offset < data.count {
                let nextOffset = min(offset + chunk, data.count)
                let slice = data.subdata(in: offset..<nextOffset)
                continuation.yield(slice)
                offset = nextOffset
            }
        } else {
            continuation.yield(data)
        }
    }

    static func parse(content: String) -> SessionScript {
        var script = SessionScript()
        var currentSection = "header"

        let lines = content.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            i += 1

            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            if line.hasPrefix("[init]") {
                currentSection = "init"
                continue
            } else if line.hasPrefix("[live]") {
                currentSection = "live"
                continue
            }

            if currentSection == "header" {
                if line.hasPrefix("@name") {
                    script.name = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("@chunk") {
                    let str = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                    script.chunkSize = Int(str)
                } else if line.hasPrefix("@cycles") {
                    let str = line.dropFirst(7).trimmingCharacters(in: .whitespaces)
                    script.cycles = Int(str) ?? 2
                } else if line.hasPrefix("@expect") {
                    let rest = line.dropFirst(7).trimmingCharacters(in: .whitespaces)
                    if let firstSpace = rest.firstIndex(of: " ") {
                        let key = String(rest[..<firstSpace])
                        let val = String(rest[rest.index(after: firstSpace)...]).trimmingCharacters(in: .whitespaces)
                        script.expectations.append((key, val))
                    }
                }
            } else if currentSection == "init" {
                if line.hasPrefix("TX ") {
                    let tx = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    // Next non-comment line must be RX
                    while i < lines.count {
                        let rxLine = lines[i].trimmingCharacters(in: .whitespaces)
                        i += 1
                        if rxLine.isEmpty || rxLine.hasPrefix("#") {
                            continue
                        }
                        if rxLine.hasPrefix("RX ") {
                            let rx = String(rxLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                            script.initSteps.append((tx: tx, rx: rx))
                            break
                        }
                    }
                }
            } else if currentSection == "live" {
                let isOnce = line.contains("=>1")
                let arrow = isOnce ? "=>1" : "=>"
                if let arrowIdx = line.range(of: arrow) {
                    let cmd = String(line[..<arrowIdx.lowerBound]).trimmingCharacters(in: .whitespaces)
                    var afterArrow = String(line[arrowIdx.upperBound...]).trimmingCharacters(in: .whitespaces)

                    var delayMs: Int? = nil
                    if afterArrow.hasPrefix("@delay=") {
                        let delayPart = afterArrow.dropFirst(7)
                        if let spaceIdx = delayPart.firstIndex(of: " ") {
                            let delayStr = String(delayPart[..<spaceIdx])
                            delayMs = Int(delayStr)
                            afterArrow = String(delayPart[delayPart.index(after: spaceIdx)...]).trimmingCharacters(in: .whitespaces)
                        }
                    }

                    let entry = LiveEntry(reply: afterArrow, delayMs: delayMs, isOnce: isOnce)
                    script.liveEntries[cmd, default: []].append(entry)
                }
            }
        }

        return script
    }
}
