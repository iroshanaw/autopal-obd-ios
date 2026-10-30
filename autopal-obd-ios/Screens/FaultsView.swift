import SwiftUI
import AutopalCore

/// Displays active Diagnostic Trouble Codes and emissions readiness (UI_DESIGN-iOS §5).
public struct FaultsView: View {
    @Environment(AppModel.self) private var appModel
    
    public init() {}
    
    private var storedDtcs: [String] {
        appModel.vehicleStore.storedDtcs
    }
    
    private var pendingDtcs: [String] {
        appModel.vehicleStore.pendingDtcs
    }
    
    private var milOn: Bool {
        appModel.vehicleStore.readiness?.milOn ?? !storedDtcs.isEmpty
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AutopalTokens.Spacing.s4) {
                    // Check Engine Light Status Card
                    milStatusCard
                    
                    // Stored DTCs Section
                    if !storedDtcs.isEmpty {
                        faultsSection(
                            title: "CONFIRMED FAULT CODES",
                            subtitle: "These faults triggered the Check Engine light",
                            codes: storedDtcs,
                            isPending: false
                        )
                    }
                    
                    // Pending DTCs Section
                    if !pendingDtcs.isEmpty {
                        faultsSection(
                            title: "PENDING FAULT CODES",
                            subtitle: "Detected during current driving cycle; not yet confirmed",
                            codes: pendingDtcs,
                            isPending: true
                        )
                    }
                    
                    // Empty State
                    if storedDtcs.isEmpty && pendingDtcs.isEmpty {
                        emptyFaultsCard
                    }
                    
                    // Emissions Readiness Section
                    if let readiness = appModel.vehicleStore.readiness {
                        readinessCard(readiness)
                    }
                    
                    // Educational Notice: We Never Clear Codes
                    neverClearsNotice
                }
                .padding(AutopalTokens.Spacing.s4)
            }
            .background(AutopalTokens.bg)
            .navigationTitle("Faults")
        }
    }
    
    // MARK: - MIL Status Card
    
    private var milStatusCard: some View {
        HStack(spacing: AutopalTokens.Spacing.s3) {
            Image(systemName: milOn ? "engine.combustion.fill" : "checkmark.seal.fill")
                .font(.system(size: 34))
                .foregroundStyle(milOn ? AutopalTokens.warning : AutopalTokens.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(milOn ? "Check Engine Light Is ON" : "Check Engine Light Is OFF")
                    .font(.headline)
                    .foregroundStyle(AutopalTokens.ink)
                Text(milOn ? "\(storedDtcs.count) stored fault(s), \(pendingDtcs.count) pending" : "No active diagnostic malfunction indicators reported")
                    .font(.footnote)
                    .foregroundStyle(AutopalTokens.inkMuted)
            }
            
            Spacer()
        }
        .padding(AutopalTokens.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(milOn ? AutopalTokens.warningContainer : AutopalTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
    }
    
    // MARK: - Faults Section
    
    private func faultsSection(title: String, subtitle: String, codes: [String], isPending: Bool) -> some View {
        VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s2) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AutopalTokens.inkMuted)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AutopalTokens.inkMuted)
                .padding(.bottom, AutopalTokens.Spacing.s1)
            
            VStack(spacing: AutopalTokens.Spacing.s2) {
                ForEach(codes, id: \.self) { code in
                    faultRow(code: code, isPending: isPending)
                }
            }
        }
    }
    
    private func faultRow(code: String, isPending: Bool) -> some View {
        let (headline, advice, isCritical) = faultDetails(for: code)
        
        return VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s2) {
            HStack {
                Text(code)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isCritical ? AutopalTokens.criticalContainer : AutopalTokens.warningContainer)
                    .foregroundStyle(isCritical ? AutopalTokens.critical : AutopalTokens.warning)
                    .clipShape(Capsule())
                
                Spacer()
                
                Text(isPending ? "PENDING" : isCritical ? "CRITICAL" : "ATTENTION")
                    .font(.caption2.bold())
                    .foregroundStyle(isCritical ? AutopalTokens.critical : AutopalTokens.warning)
            }
            
            Text(headline)
                .font(.subheadline.bold())
                .foregroundStyle(AutopalTokens.ink)
            
            Text(advice)
                .font(.footnote)
                .foregroundStyle(AutopalTokens.inkMuted)
        }
        .padding(AutopalTokens.Spacing.s3)
        .background(AutopalTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
    }
    
    // MARK: - Empty State
    
    private var emptyFaultsCard: some View {
        VStack(spacing: AutopalTokens.Spacing.s2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(AutopalTokens.primary)
                .padding(.top, AutopalTokens.Spacing.s2)
            
            Text("No Fault Codes Stored")
                .font(.headline)
                .foregroundStyle(AutopalTokens.ink)
            
            Text("Your vehicle engine computer reports no active or pending diagnostic trouble codes.")
                .font(.footnote)
                .foregroundStyle(AutopalTokens.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(AutopalTokens.Spacing.s4)
        .frame(maxWidth: .infinity)
        .background(AutopalTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
    }
    
    // MARK: - Readiness Card
    
    private func readinessCard(_ readiness: ReadinessStatus) -> some View {
        VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s3) {
            Text("I/M EMISSIONS READINESS")
                .font(.caption.bold())
                .foregroundStyle(AutopalTokens.inkMuted)
            
            Text("Monitors completed for emissions inspection testing")
                .font(.caption)
                .foregroundStyle(AutopalTokens.inkMuted)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AutopalTokens.Spacing.s2) {
                ForEach(readiness.available, id: \.self) { monitor in
                    let isReady = !readiness.incomplete.contains(monitor)
                    HStack(spacing: 6) {
                        Image(systemName: isReady ? "checkmark.circle.fill" : "clock.fill")
                            .foregroundStyle(isReady ? AutopalTokens.primary : AutopalTokens.warning)
                            .font(.caption)
                        Text(friendlyMonitorName(monitor))
                            .font(.caption)
                            .foregroundStyle(AutopalTokens.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AutopalTokens.Spacing.s2)
                    .background(AutopalTokens.bg)
                    .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.sm))
                }
            }
        }
        .padding(AutopalTokens.Spacing.s3)
        .background(AutopalTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
    }
    
    // MARK: - Educational Notice (Rule 3)
    
    private var neverClearsNotice: some View {
        HStack(alignment: .top, spacing: AutopalTokens.Spacing.s2) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(AutopalTokens.primary)
                .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Autopal does not clear fault codes")
                    .font(.footnote.bold())
                    .foregroundStyle(AutopalTokens.ink)
                Text("Clearing codes without repair masks mechanical issues, resets emissions testing readiness, and risks engine damage. Repair the cause and your ECU will clear the light automatically.")
                    .font(.caption)
                    .foregroundStyle(AutopalTokens.inkMuted)
            }
        }
        .padding(AutopalTokens.Spacing.s3)
        .background(AutopalTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
    }
    
    // MARK: - Helpers
    
    private func faultDetails(for code: String) -> (headline: String, advice: String, isCritical: Bool) {
        switch code {
        case "P0300":
            return ("Random/Multiple Cylinder Misfire Detected", "Unburned fuel can damage the catalytic converter. Avoid heavy acceleration.", true)
        case "P0301":
            return ("Cylinder 1 Misfire Detected", "Inspect ignition coil 1, spark plug, or fuel injector.", true)
        case "P0302":
            return ("Cylinder 2 Misfire Detected", "Inspect ignition coil 2, spark plug, or fuel injector.", true)
        case "P0303":
            return ("Cylinder 3 Misfire Detected", "Inspect ignition coil 3, spark plug, or fuel injector.", true)
        case "P0304":
            return ("Cylinder 4 Misfire Detected", "Inspect ignition coil 4, spark plug, or fuel injector.", true)
        case "P0420":
            return ("Catalyst System Efficiency Below Threshold (Bank 1)", "Catalytic converter performance degraded. Schedule an exhaust inspection.", false)
        case "P0171":
            return ("System Too Lean (Bank 1)", "Engine receiving too much air or insufficient fuel. Check for vacuum leaks.", false)
        case "P0172":
            return ("System Too Rich (Bank 1)", "Engine receiving excess fuel. Inspect air intake filter and mass airflow sensor.", false)
        case "P0118":
            return ("Coolant Temperature Circuit High Input", "Coolant temperature sensor reading out of expected range. Inspect sensor wiring.", false)
        case "P0562":
            return ("System Voltage Low", "Alternator charging voltage is below normal threshold. Inspect battery and charging belt.", false)
        default:
            return ("Diagnostic Trouble Code \(code)", "Have a qualified mechanic inspect the system associated with code \(code).", false)
        }
    }
    
    private func friendlyMonitorName(_ monitor: MonitorType) -> String {
        switch monitor {
        case .misfire: return "Misfire"
        case .fuelSystem: return "Fuel System"
        case .components: return "Components"
        case .catalyst: return "Catalyst"
        case .heatedCatalyst: return "Heated Catalyst"
        case .evap: return "Evaporative"
        case .secondaryAir: return "Secondary Air"
        case .acRefrigerant: return "A/C Refrigerant"
        case .o2Sensor: return "O2 Sensor"
        case .o2Heater: return "O2 Heater"
        case .egr: return "EGR System"
        case .nmhcCatalyst: return "NMHC Catalyst"
        case .noxScr: return "NOx / SCR"
        case .boostPressure: return "Boost Pressure"
        case .exhaustGasSensor: return "Exhaust Gas"
        case .pmFilter: return "PM Filter"
        case .egrVvt: return "EGR / VVT"
        }
    }
}
