import Foundation

/// Classified reply from an ELM327 command.
public enum ElmReply: Sendable, Equatable {
    public enum ErrorKind: Sendable, Equatable {
        case canError
        case busError
        case busBusy
        case bufferFull
        case dataError
        case stopped
        case lvReset
        case other(String)
    }

    case ok([String])
    case noData
    case unableToConnect
    case unknown
    case error(ErrorKind)
    case timeout

    /// Classifies raw text returned by the adapter for a given command.
    public static func classify(raw: String, command: String) -> ElmReply {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\r")
                            .replacingOccurrences(of: "\n", with: "\r")

        let rawLines = normalized.components(separatedBy: "\r")
        var filteredLines: [String] = []

        let cmdTrimmed = command.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }

            let upper = trimmed.uppercased()

            // Strip echo if matching command
            if upper == cmdTrimmed || upper == cmdTrimmed.replacingOccurrences(of: " ", with: "") {
                continue
            }

            // Strip intermediate ELM327 status lines
            if upper.hasPrefix("SEARCHING") {
                continue
            }
            if upper.hasPrefix("BUS INIT:") {
                continue
            }

            filteredLines.append(trimmed)
        }

        if filteredLines.isEmpty {
            return .ok([])
        }

        // Check for specific error / sentinel responses in remaining lines
        for line in filteredLines {
            let upper = line.uppercased()
            if upper == "NO DATA" {
                return .noData
            }
            if upper == "UNABLE TO CONNECT" {
                return .unableToConnect
            }
            if upper == "?" {
                return .unknown
            }
            if upper == "CAN ERROR" {
                return .error(.canError)
            }
            if upper == "BUS ERROR" {
                return .error(.busError)
            }
            if upper == "BUS BUSY" {
                return .error(.busBusy)
            }
            if upper == "BUFFER FULL" {
                return .error(.bufferFull)
            }
            if upper == "DATA ERROR" {
                return .error(.dataError)
            }
            if upper == "STOPPED" {
                return .error(.stopped)
            }
            if upper == "LV RESET" {
                return .error(.lvReset)
            }
        }

        return .ok(filteredLines)
    }
}
