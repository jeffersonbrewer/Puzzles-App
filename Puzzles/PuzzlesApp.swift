import SwiftUI

@main
struct PuzzlesApp: App {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some Scene {
        WindowGroup {
            ThemedRoot {
                HomeView()
            }
            .preferredColorScheme(appearance.colorScheme)
        }
    }
}
