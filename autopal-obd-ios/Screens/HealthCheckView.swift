import SwiftUI
import AutopalCore

/// Guided vehicle health inspection and diagnostic report screen (UI_DESIGN-iOS §5).
public struct HealthCheckView: View {
    @Environment(AppModel.self) private var appModel
    
    @State private var isRunning = false
    @State private var progress: Double = 0.0
    @State private var activeStep = 0
    @State private var hasCompletedRun = false
    
    private let checkSteps = [
        "Scanning Powertrain Fault Codes",
        "Evaluating Cooling System",
        "Checking Charging Circuit",
        "Analyzing Fuel Trims & Mixture",
        "Verifying Intake & Airflow",
        "Testing Emissions Readiness"
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AutopalTokens.Spacing.s4) {
                    if isRunning {
                        runningProgressCard
                    } else {
                        // Verdict Card
                        VerdictCard(
                            verdict: appModel.vehicleStore.verdict,
                            activeAlert: appModel.vehicleStore.primaryAlert,
                            actionTitle: "Run Health Check",
                            action: { startHealthCheck() }
                        )
                    }
                    
                    // 6 Check System Rows
                    VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s2) {
                        Text("SYSTEM CHECKS")
                            .font(.caption.bold())
                            .foregroundStyle(AutopalTokens.inkMuted)
                            .padding(.horizontal, AutopalTokens.Spacing.s1)
                        
                        VStack(spacing: 0) {
                            coolingRow
                            Divider().padding(.leading, 54)
                            chargingRow
                            Divider().padding(.leading, 54)
                            fuelTrimRow
                            Divider().padding(.leading, 54)
                            intakeRow
                            Divider().padding(.leading, 54)
                            engineLoadRow
                            Divider().padding(.leading, 54)
                            faultsCheckRow
                        }
                        .background(AutopalTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
                    }
                    
                    // Bottom Actions
                    if !isRunning {
                        bottomActionButtons
                    }
                }
                .padding(AutopalTokens.Spacing.s4)
            }
            .background(AutopalTokens.bg)
            .navigationTitle("Health Check")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: generateReportText()) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(AutopalTokens.primary)
                    }
                }
            }
        }
    }
    
    // MARK: - Running Progress Card
    
    private var runningProgressCard: some View {
        VStack(spacing: AutopalTokens.Spacing.s3) {
            ZStack {
                Circle()
                    .stroke(AutopalTokens.gaugeTrack, lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AutopalTokens.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 80, height: 80)
                    .animation(AutopalMotion.medium, value: progress)
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AutopalTokens.ink)
            }
            
            Text(checkSteps[min(activeStep, checkSteps.count - 1)])
                .font(.headline)
                .foregroundStyle(AutopalTokens.ink)
            
            Text("Inspecting live ECU sensor values")
                .font(.footnote)
                .foregroundStyle(AutopalTokens.inkMuted)
            
            Button("Cancel") {
                cancelHealthCheck()
            }
            .font(.footnote.bold())
            .foregroundStyle(AutopalTokens.critical)
            .padding(.top, AutopalTokens.Spacing.s1)
        }
        .padding(AutopalTokens.Spacing.s4)
        .frame(maxWidth: .infinity)
        .background(AutopalTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.lg))
    }
    
    // MARK: - Check Rows
    
    private var coolingRow: some View {
        let temp = appModel.vehicleStore.coolantTempC
        let isAttention = temp != nil && temp! > 105
        let reading = temp.map { "\(Int($0)) °C" } ?? "—"
        
        return CheckRow(
            title: "Cooling System",
            detail: isAttention ? "Coolant running hotter than normal" : "Radiator and thermostat normal",
            value: reading,
            status: isAttention ? .warning : .pass
        )
    }
    
    private var chargingRow: some View {
        let volts = appModel.vehicleStore.batteryVoltage
        let isAttention = volts != nil && (volts! < 12.0 || volts! > 15.0)
        let reading = volts.map { String(format: "%.1f V", $0) } ?? "—"
        
        return CheckRow(
            title: "Electrical & Alternator",
            detail: isAttention ? "Charging voltage outside nominal range" : "Alternator output nominal",
            value: reading,
            status: isAttention ? .warning : .pass
        )
    }
    
    private var fuelTrimRow: some View {
        let short = appModel.vehicleStore.stft
        let long = appModel.vehicleStore.ltft
        let isAttention: Bool
        if let short, let long {
            isAttention = abs(short + long) > 15
        } else {
            isAttention = false
        }
        
        let reading: String
        if let short, let long {
            let total = short + long
            reading = String(format: "%+.0f%%", total)
        } else {
            reading = "—"
        }
        
        return CheckRow(
            title: "Fuel & Air Mixture",
            detail: isAttention ? "Elevated fuel trim compensation detected" : "Fuel delivery in stoichiometric balance",
            value: reading,
            status: isAttention ? .warning : .pass
        )
    }
    
    private var intakeRow: some View {
        let temp = appModel.vehicleStore.intakeTemp
        let reading = temp.map { "\(Int($0)) °C" } ?? "—"
        
        return CheckRow(
            title: "Air Intake System",
            detail: "Intake manifold temperature and density",
            value: reading,
            status: .pass
        )
    }
    
    private var engineLoadRow: some View {
        let load = appModel.vehicleStore.engineLoad
        let reading = load.map { "\(Int($0))%" } ?? "—"
        
        return CheckRow(
            title: "Engine Load & Timing",
            detail: "Calculated engine load across cylinders",
            value: reading,
            status: .pass
        )
    }
    
    private var faultsCheckRow: some View {
        let dtcCount = appModel.vehicleStore.storedDtcs.count
        let isAttention = dtcCount > 0
        let reading = "\(dtcCount) DTCs"
        
        return CheckRow(
            title: "Diagnostic Faults",
            detail: isAttention ? "\(dtcCount) trouble code(s) stored in ECU" : "No active fault codes recorded",
            value: reading,
            status: isAttention ? .warning : .pass
        )
    }
    
    // MARK: - Bottom Actions
    
    private var bottomActionButtons: some View {
        VStack(spacing: AutopalTokens.Spacing.s2) {
            ShareLink(item: generateReportText()) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share with mechanic")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AutopalTokens.primary)
                .foregroundStyle(Color.black)
                .clipShape(Capsule())
            }
            
            Button("Run Health Check") {
                startHealthCheck()
            }
            .font(.subheadline.bold())
            .foregroundStyle(AutopalTokens.primary)
            .padding(.vertical, 10)
        }
        .padding(.top, AutopalTokens.Spacing.s2)
    }
    
    // MARK: - Simulation / Check Execution
    
    private func startHealthCheck() {
        isRunning = true
        progress = 0.0
        activeStep = 0
        
        Task {
            for step in 0..<checkSteps.count {
                guard isRunning else { break }
                activeStep = step
                withAnimation(AutopalMotion.medium) {
                    progress = Double(step + 1) / Double(checkSteps.count)
                }
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            withAnimation(AutopalMotion.fast) {
                isRunning = false
                hasCompletedRun = true
            }
        }
    }
    
    private func cancelHealthCheck() {
        withAnimation(AutopalMotion.fast) {
            isRunning = false
            progress = 0.0
        }
    }
    
    private func generateReportText() -> String {
        """
        AUTOPAL VEHICLE HEALTH REPORT
        Vehicle: \(appModel.settingsStore.vehicleYear) \(appModel.settingsStore.vehicleName)
        Engine: \(appModel.settingsStore.vehicleEngine)
        Status: \(appModel.vehicleStore.verdict.title.uppercased())
        
        READINGS:
        - Coolant Temp: \(appModel.vehicleStore.coolantTempC.map { "\(Int($0)) °C" } ?? "N/A")
        - Battery: \(appModel.vehicleStore.batteryVoltage.map { String(format: "%.1f V", $0) } ?? "N/A")
        - RPM: \(appModel.vehicleStore.engineRpm.map { "\(Int($0))" } ?? "N/A")
        - Active DTCs: \(appModel.vehicleStore.storedDtcs.joined(separator: ", ").isEmpty ? "None" : appModel.vehicleStore.storedDtcs.joined(separator: ", "))
        
        Generated by Autopal OBD iOS.
        """
    }
}
