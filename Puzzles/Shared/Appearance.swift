import SwiftUI
import UIKit

/// The app-wide light/dark preference, stored with @AppStorage(AppAppearance.storageKey).
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "app.appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// `.unspecified` follows the phone's setting.
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension View {
    /// Applies the saved preference to the whole window, so every screen and
    /// open sheet changes right away.
    func appliesAppearance() -> some View { modifier(AppearanceModifier()) }
}

/// Reads the preference inside a view: reading it in the App and passing it to
/// `preferredColorScheme` didn't update while the app was running.
private struct AppearanceModifier: ViewModifier {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    func body(content: Content) -> some View {
        content.background(WindowStyleSetter(style: appearance.interfaceStyle).accessibilityHidden(true))
    }
}

private struct WindowStyleSetter: UIViewRepresentable {
    let style: UIUserInterfaceStyle

    final class StyleView: UIView {
        var style: UIUserInterfaceStyle = .unspecified {
            didSet { apply() }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        private func apply() {
            guard let window, window.overrideUserInterfaceStyle != style else { return }
            window.overrideUserInterfaceStyle = style
        }
    }

    func makeUIView(context: Context) -> StyleView {
        let view = StyleView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: StyleView, context: Context) { view.style = style }
}

/// A segmented System / Light / Dark control.
struct AppearancePicker: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some View {
        Picker("Appearance", selection: $appearance) {
            ForEach(AppAppearance.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
}
