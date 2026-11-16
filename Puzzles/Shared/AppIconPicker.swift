import SwiftUI
import UIKit

/// The home-screen icons the app ships with. Each `assetName` is an app icon
/// set in Assets.xcassets (drawn by tools/make_icons.py).
enum AppIconOption: String, CaseIterable, Identifiable {
    case teal = "AppIcon"
    case forest = "AppIcon-Forest"
    case midnight = "AppIcon-Midnight"
    case paper = "AppIcon-Paper"
    case sunset = "AppIcon-Sunset"
    case mono = "AppIcon-Mono"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .teal: return "Teal"
        case .forest: return "Forest"
        case .midnight: return "Midnight"
        case .paper: return "Paper"
        case .sunset: return "Sunset"
        case .mono: return "Mono"
        }
    }

    /// nil sets the primary icon.
    var alternateName: String? { self == .teal ? nil : rawValue }

    /// A small copy of the icon (an image set named IconPreview-<asset>),
    /// because app icon sets can't be drawn inside the app.
    var preview: UIImage? { UIImage(named: "IconPreview-\(rawValue)") }
}

struct AppIconPickerView: View {
    @State private var current: AppIconOption = AppIconOption(rawValue: UIApplication.shared.alternateIconName ?? "AppIcon") ?? .teal
    @State private var errorText: String?

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 18) {
                    ForEach(AppIconOption.allCases) { option in
                        Button {
                            choose(option)
                        } label: {
                            VStack(spacing: 8) {
                                iconImage(option)
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay {
                                        if option == current {
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .strokeBorder(Color.accentColor, lineWidth: 3)
                                                .padding(-6)
                                        }
                                    }
                                Text(option.title).font(.caption).foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 104)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                        .accessibilityAddTraits(option == current ? .isSelected : [])
                    }
                }
                .padding(.vertical, 8)
            } footer: {
                Text(errorText ?? "iPhone shows a short confirmation when the icon changes.")
            }
        }
        .themedBackground()
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func iconImage(_ option: AppIconOption) -> some View {
        if let image = option.preview {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 16).fill(Color.secondary.opacity(0.2))
        }
    }

    private func choose(_ option: AppIconOption) {
        guard option != current, UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(option.alternateName) { error in
            Task { @MainActor in
                if let error {
                    errorText = "Couldn't change the icon: \(error.localizedDescription)"
                } else {
                    errorText = nil
                    current = option
                }
            }
        }
    }
}
