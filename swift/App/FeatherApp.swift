import SwiftUI

@main
struct FeatherApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        Window("Feather", id: "main") {
            ContentView()
                .environment(appState)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 420, height: 580)
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
    }
}
