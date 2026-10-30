import SwiftUI

@main struct MyApp: App {
    @State private var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .preferredColorScheme(appModel.settingsStore.appearance.colorScheme)
        }
    }
}
