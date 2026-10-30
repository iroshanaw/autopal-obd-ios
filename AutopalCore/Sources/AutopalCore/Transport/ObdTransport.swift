import Foundation

/// State of the OBD connection link.
public enum LinkState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)
}

/// Abstract transport layer for OBD communication.
public protocol ObdTransport: Sendable {
    var label: String { get }
    var linkState: AsyncStream<LinkState> { get }
    var incoming: AsyncStream<Data> { get }
    func connect() async throws
    func write(_ bytes: Data) async throws
    func close() async
}
