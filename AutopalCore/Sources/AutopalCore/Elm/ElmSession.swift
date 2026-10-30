import Foundation

/// Manages an ELM327 command-response session over an ObdTransport.
public actor ElmSession {
    public let transport: any ObdTransport
    public let clock: any Clock<Duration>
    public let trafficLog: TrafficLog?

    private var incomingBuffer = Data()
    private var isListening = false
    private var listenTask: Task<Void, Never>?

    private var pendingContinuation: CheckedContinuation<String?, Never>?
    private var pendingCommand: String?
    private var wasLastSentAtsp0 = false

    public init(
        transport: any ObdTransport,
        clock: any Clock<Duration>,
        trafficLog: TrafficLog? = nil
    ) {
        self.transport = transport
        self.clock = clock
        self.trafficLog = trafficLog
    }

    deinit {
        listenTask?.cancel()
    }

    /// Determines the timeout duration for a command.
    public func timeoutFor(command: String) -> Duration {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed == "ATZ" {
            return .seconds(5)
        }
        if wasLastSentAtsp0 && isObdRequest(trimmed) {
            return .seconds(15)
        }
        return .milliseconds(2500)
    }

    /// Tracks sent commands for stateful timeout decisions.
    public func recordSentCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed == "ATSP0" {
            wasLastSentAtsp0 = true
        } else if wasLastSentAtsp0 && isObdRequest(trimmed) {
            wasLastSentAtsp0 = false
        }
    }

    private func isObdRequest(_ cmd: String) -> Bool {
        guard cmd.count >= 2 else { return false }
        let prefix = String(cmd.prefix(2))
        return ["01", "02", "03", "04", "07", "09"].contains(prefix)
    }

    /// Starts listening to transport incoming stream if not already active.
    private func ensureListening() {
        guard !isListening else { return }
        isListening = true

        let incomingStream = transport.incoming
        listenTask = Task { [weak self] in
            for await chunk in incomingStream {
                guard let self else { break }
                await self.handleIncomingData(chunk)
            }
        }
    }

    private func handleIncomingData(_ chunk: Data) {
        // Drop NUL (0x00) bytes per architecture rule 2
        let filtered = chunk.filter { $0 != 0x00 }
        guard !filtered.isEmpty else { return }

        incomingBuffer.append(filtered)
        processBuffer()
    }

    private func processBuffer() {
        // Look for prompt character '>' (0x3E)
        while let promptIndex = incomingBuffer.firstIndex(of: 0x3E) {
            let replyData = incomingBuffer.subdata(in: incomingBuffer.startIndex..<promptIndex)
            incomingBuffer.removeSubrange(incomingBuffer.startIndex...promptIndex)

            let replyString = String(decoding: replyData, as: UTF8.self)

            if let cont = pendingContinuation {
                pendingContinuation = nil
                pendingCommand = nil
                cont.resume(returning: replyString)
            } else {
                // Unsolicited or late reply arrived
                Task { [trafficLog] in
                    await trafficLog?.logUnsolicitedDropped(replyString)
                }
            }
        }
    }

    /// Sends a command to the ELM327 adapter and awaits classified reply.
    public func send(_ command: String) async throws -> ElmReply {
        ensureListening()

        let timeout = timeoutFor(command: command)
        recordSentCommand(command)

        let cmdTrimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        await trafficLog?.logTx(cmdTrimmed)

        // Write command with trailing carriage return
        var cmdData = Data(cmdTrimmed.utf8)
        cmdData.append(0x0D) // \r
        try await transport.write(cmdData)

        pendingCommand = cmdTrimmed

        // Await reply with timeout
        var timeoutTask: Task<Void, Never>?
        let rawReply: String? = await withCheckedContinuation { continuation in
            self.pendingContinuation = continuation
            processBuffer()

            timeoutTask = Task { [weak self, clock] in
                try? await clock.sleep(for: timeout)
                guard let self else { return }
                await self.handleTimeout(for: cmdTrimmed)
            }
        }
        timeoutTask?.cancel()

        if let reply = rawReply {
            await trafficLog?.logRx(reply)
            return ElmReply.classify(raw: reply, command: cmdTrimmed)
        } else {
            // Handle timeout
            pendingContinuation = nil
            pendingCommand = nil

            let ms = Int(timeout.components.seconds * 1000 + timeout.components.attoseconds / 1_000_000_000_000_000)
            await trafficLog?.logTimeout(afterMs: ms, command: cmdTrimmed)

            // 300 ms drain window
            try? await clock.sleep(for: .milliseconds(300))
            incomingBuffer.removeAll()

            return .timeout
        }
    }

    private func handleTimeout(for command: String) {
        guard pendingCommand == command, let cont = pendingContinuation else { return }
        pendingContinuation = nil
        pendingCommand = nil
        cont.resume(returning: nil)
    }
}
