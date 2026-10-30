import SwiftUI
import AutopalCore

/// Root navigation coordinating compact TabView and regular NavigationSplitView (UI_DESIGN-iOS §5, §6).
public struct MainTabView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var selectedTab: Int = 0
    @State private var showingSetup: Bool = false
    
    public init() {}
    
    public var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularSplitView
            } else {
                compactTabView
            }
        }
        .preferredColorScheme(appModel.settingsStore.appearance.colorScheme)
        .fullScreenCover(isPresented: $showingSetup) {
            SetupFlowView()
        }
        .onAppear {
            if !appModel.settingsStore.setupDone {
                showingSetup = true
            }
        }
    }
    
    // MARK: - Compact TabView (iPhone, Folded Duo)
    
    private var compactTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "gauge.with.needle.fill")
                }
                .tag(0)
            
            HealthCheckView()
                .tabItem {
                    Label("Check", systemImage: "checklist")
                }
                .tag(1)
            
            FaultsView()
                .tabItem {
                    Label("Faults", systemImage: "exclamationmark.triangle.fill")
                }
                .tag(2)
                .badge(appModel.vehicleStore.storedDtcs.count)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(AutopalTokens.primary)
    }
    
    // MARK: - Regular Split View (iPad, Unfolded Duo Landscape)
    
    private var regularSplitView: some View {
        NavigationSplitView {
            List {
                Button {
                    selectedTab = 0
                } label: {
                    Label("Home", systemImage: "gauge.with.needle.fill")
                        .foregroundStyle(AutopalTokens.ink)
                }
                .listRowBackground(selectedTab == 0 ? AutopalTokens.primaryContainer : Color.clear)
                
                Button {
                    selectedTab = 1
                } label: {
                    Label("Health Check", systemImage: "checklist")
                        .foregroundStyle(AutopalTokens.ink)
                }
                .listRowBackground(selectedTab == 1 ? AutopalTokens.primaryContainer : Color.clear)
                
                Button {
                    selectedTab = 2
                } label: {
                    HStack {
                        Label("Faults", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AutopalTokens.ink)
                        Spacer()
                        if !appModel.vehicleStore.storedDtcs.isEmpty {
                            Text("\(appModel.vehicleStore.storedDtcs.count)")
                                .font(.caption.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AutopalTokens.warningContainer)
                                .foregroundStyle(AutopalTokens.warning)
                                .clipShape(Capsule())
                        }
                    }
                }
                .listRowBackground(selectedTab == 2 ? AutopalTokens.primaryContainer : Color.clear)
                
                Button {
                    selectedTab = 3
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                        .foregroundStyle(AutopalTokens.ink)
                }
                .listRowBackground(selectedTab == 3 ? AutopalTokens.primaryContainer : Color.clear)
            }
            .navigationTitle("Autopal")
            .listStyle(.sidebar)
        } detail: {
            switch selectedTab {
            case 0:
                HomeView(selectedTab: $selectedTab)
            case 1:
                HealthCheckView()
            case 2:
                FaultsView()
            case 3:
                SettingsView()
            default:
                HomeView(selectedTab: $selectedTab)
            }
        }
        .tint(AutopalTokens.primary)
    }
}
