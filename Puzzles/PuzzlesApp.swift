import SwiftUI

@main
struct PuzzlesApp: App {
    var body: some Scene {
        WindowGroup {
            ThemedRoot {
                HomeView()
            }
            .appliesAppearance()
        }
    }
}
