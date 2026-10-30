import SwiftUI
import AutopalCore

/// Raw diagnostic traffic log screen for protocol analysis and fixture creation (UI_DESIGN-iOS §5).
public struct TrafficLogView: View {
    @Environment(AppModel.self) private var appModel
    @State private var logContent: String = "Loading traffic log..."
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s4) {
                // Header Chips
                HStack(spacing: AutopalTokens.Spacing.s2) {
                    StatusChip(
                        text: appModel.vehicleStore.elmVersion ?? "ELM327",
                        systemImage: "cpu"
                    )
                    StatusChip(
                        text: "BLE • IOS-VLINK",
                        systemImage: "antenna.radiowaves.left.and.right"
                    )
                    if let proto = appModel.vehicleStore.protocolName {
                        StatusChip(
                            text: proto,
                            systemImage: "cable.connector"
                        )
                    }
                }
                
                // Traffic Log Output
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(logLines, id: \.self) { line in
                        logLineView(line)
                    }
                }
                .padding(AutopalTokens.Spacing.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AutopalTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
                
                // Privacy notice
                HStack(alignment: .top, spacing: AutopalTokens.Spacing.s2) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(AutopalTokens.inkMuted)
                        .font(.footnote)
                    Text("Traffic logs contain raw OBD-II diagnostic hex frames and your vehicle VIN. No GPS or location data is ever recorded.")
                        .font(.caption)
                        .foregroundStyle(AutopalTokens.inkMuted)
                }
                .padding(.horizontal, AutopalTokens.Spacing.s2)
            }
            .padding(AutopalTokens.Spacing.s4)
        }
        .background(AutopalTokens.bg)
        .navigationTitle("Traffic Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: logContent) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(AutopalTokens.primary)
                }
            }
        }
        .task {
            if let export = await appModel.connectionManager.exportTrafficLog() {
                logContent = export
            } else {
                logContent = "# autopal-traffic-log v1\n# No session active"
            }
        }
    }
    
    private var logLines: [String] {
        logContent.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
    
    private func logLineView(_ line: String) -> some View {
        let isTx = line.contains(" TX ")
        let isRx = line.contains(" RX ")
        let isComment = line.hasPrefix("#")
        
        let color: Color = {
            if isTx { return AutopalTokens.primary }
            if isRx { return AutopalTokens.ink }
            if isComment { return AutopalTokens.inkMuted }
            return AutopalTokens.warning
        }()
        
        return Text(line)
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .foregroundStyle(color)
            .textSelection(.enabled)
    }
}
