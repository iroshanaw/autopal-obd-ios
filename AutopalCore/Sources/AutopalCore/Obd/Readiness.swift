import Foundation

public enum EngineType: String, Sendable, Equatable {
    case spark = "SPARK"
    case compression = "COMPRESSION"
}

public enum MonitorType: String, Sendable, Equatable, CaseIterable {
    // Common
    case misfire = "MISFIRE"
    case fuelSystem = "FUEL_SYSTEM"
    case components = "COMPONENTS"

    // Spark
    case catalyst = "CATALYST"
    case heatedCatalyst = "HEATED_CATALYST"
    case evap = "EVAP"
    case secondaryAir = "SECONDARY_AIR"
    case acRefrigerant = "AC_REFRIGERANT"
    case o2Sensor = "O2_SENSOR"
    case o2Heater = "O2_HEATER"
    case egr = "EGR"

    // Compression
    case nmhcCatalyst = "NMHC_CATALYST"
    case noxScr = "NOX_SCR"
    case boostPressure = "BOOST_PRESSURE"
    case exhaustGasSensor = "EXHAUST_GAS_SENSOR"
    case pmFilter = "PM_FILTER"
    case egrVvt = "EGR_VVT"
}

public struct ReadinessStatus: Sendable, Equatable {
    public let milOn: Bool
    public let dtcCount: Int
    public let engine: EngineType
    public let available: [MonitorType]
    public let incomplete: [MonitorType]

    public init(
        milOn: Bool,
        dtcCount: Int,
        engine: EngineType,
        available: [MonitorType],
        incomplete: [MonitorType]
    ) {
        self.milOn = milOn
        self.dtcCount = dtcCount
        self.engine = engine
        self.available = available
        self.incomplete = incomplete
    }
}

/// Decodes SAE J1979 Mode 01 PID 01 (Monitor status since DTCs cleared).
public enum Readiness: Sendable {
    public static func decode(reply: String) -> ReadinessStatus? {
        let compact = reply.unicodeScalars
            .filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
            .map { Character($0) }
        let str = String(compact).uppercased()

        guard str.hasPrefix("4101") else {
            return nil
        }

        guard let bytes = Hex.decode(str), bytes.count >= 6 else {
            return nil
        }

        // bytes: [0x41, 0x01, A, B, C, D]
        let byteA = bytes[2]
        let byteB = bytes[3]
        let byteC = bytes[4]
        let byteD = bytes[5]

        let milOn = (byteA & 0x80) != 0
        let dtcCount = Int(byteA & 0x7F)

        let isCompression = (byteB & 0x08) != 0
        let engine: EngineType = isCompression ? .compression : .spark

        var available: [MonitorType] = []
        var incomplete: [MonitorType] = []

        // Continuous monitors (Byte B)
        // Misfire
        if (byteB & 0x01) != 0 {
            available.append(.misfire)
            if (byteB & 0x10) != 0 {
                incomplete.append(.misfire)
            }
        }
        // Fuel system
        if (byteB & 0x02) != 0 {
            available.append(.fuelSystem)
            if (byteB & 0x20) != 0 {
                incomplete.append(.fuelSystem)
            }
        }
        // Comprehensive components
        if (byteB & 0x04) != 0 {
            available.append(.components)
            if (byteB & 0x40) != 0 {
                incomplete.append(.components)
            }
        }

        // Non-continuous monitors (Byte C = available, Byte D = incomplete)
        if !isCompression {
            // Spark monitors
            checkMonitor(byteC: byteC, byteD: byteD, bit: 0, type: .catalyst, avail: &available, incomp: &incomplete)
            checkMonitor(byteC: byteC, byteD: byteD, bit: 1, type: .heatedCatalyst, avail: &available, incomp: &incomplete)
            checkMonitor(byteC: byteC, byteD: byteD, bit: 2, type: .evap, avail: &available, incomp: &incomplete)
            checkMonitor(byteC: byteC, byteD: byteD, bit: 3, type: .secondaryAir, avail: &available, incomp: &incomplete)
            checkMonitor(byteC: byteC, byteD: byteD, bit: 4, type: .acRefrigerant, avail: &available, incomp: &incomplete)
            checkMonitor(byteC: byteC, byteD: byteD, bit: 5, type: .o2Sensor, avail: &available, incomp: &incomplete)
            checkMonitor(byteC: byteC, byteD: byteD, bit: 6, type: .o2Heater, avail: &available, incomp: &incomplete)
            checkMonitor(byteC: byteC, byteD: byteD, bit: 7, type: .egr, avail: &available, incomp: &incomplete)
        } else {
            // Compression monitors
            checkMonitor(byteC: byteC, byteD: byteD, bit: 0, type: .nmhcCatalyst, avail: &available, incomp: &incomplete)
            checkMonitor(byteC: byteC, byteD: byteD, bit: 1, type: .noxScr, avail: &available, incomp: &incomplete)
            checkMonitor(byteC: byteC, byteD: byteD, bit: 3, type: .boostPressure, avail: &available, incomp: &incomplete)
            checkMonitor(byteC: byteC, byteD: byteD, bit: 5, type: .exhaustGasSensor, avail: &available, incomp: &incomplete)
            checkMonitor(byteC: byteC, byteD: byteD, bit: 6, type: .pmFilter, avail: &available, incomp: &incomplete)
            checkMonitor(byteC: byteC, byteD: byteD, bit: 7, type: .egrVvt, avail: &available, incomp: &incomplete)
        }

        return ReadinessStatus(
            milOn: milOn,
            dtcCount: dtcCount,
            engine: engine,
            available: available,
            incomplete: incomplete
        )
    }

    private static func checkMonitor(
        byteC: UInt8,
        byteD: UInt8,
        bit: UInt8,
        type: MonitorType,
        avail: inout [MonitorType],
        incomp: inout [MonitorType]
    ) {
        let mask: UInt8 = 1 << bit
        if (byteC & mask) != 0 {
            avail.append(type)
            if (byteD & mask) != 0 {
                incomp.append(type)
            }
        }
    }
}
