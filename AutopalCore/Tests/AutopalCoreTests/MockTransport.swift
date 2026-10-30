import Foundation
@testable import AutopalCore

/// A mock OBD transport for testing ElmSession.
public final class MockTransport: ObdTransport, @unchecked Sendable {
    public let label: String
    private let linkStateContinuation: AsyncStream<LinkState>.Continuation
    public let linkState: AsyncStream<LinkState>

    private let incomingContinuation: AsyncStream<Data>.Continuation
    public let incoming: AsyncStream<Data>

    private let lock = NSLock()
    public private(set) var writtenData: [Data] = []
    public private(set) var isConnected: Bool = false
    public private(set) var isClosed: Bool = false

    public init(label: String = "MockTransport") {
        self.label = label

        var lsCont: AsyncStream<LinkState>.Continuation!
        self.linkState = AsyncStream { cont in lsCont = cont }
        self.linkStateContinuation = lsCont

        var inCont: AsyncStream<Data>.Continuation!
        self.incoming = AsyncStream { cont in inCont = cont }
        self.incomingContinuation = inCont
    }

    public func connect() async throws {
        lock.withLock { isConnected = true }
        linkStateContinuation.yield(.connected)
    }

    public func write(_ bytes: Data) async throws {
        lock.withLock { writtenData.append(bytes) }
    }

    public func close() async {
        lock.withLock {
            isConnected = false
            isClosed = true
        }
        linkStateContinuation.yield(.disconnected)
        linkStateContinuation.finish()
        incomingContinuation.finish()
    }

    public func yieldIncoming(_ data: Data) {
        incomingContinuation.yield(data)
    }

    public func yieldIncomingString(_ string: String) {
        if let data = string.data(using: .utf8) {
            incomingContinuation.yield(data)
        }
    }
}
