import SwiftUI

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case dark
    case light
    case system

    static let storageKey = "appAppearanceMode"

    var id: Self { self }

    var title: String {
        switch self {
        case .dark: "다크"
        case .light: "라이트"
        case .system: "시스템"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

struct AppearancePicker: View {
    @Binding var selection: AppAppearanceMode

    var body: some View {
        HStack(spacing: SetlistSpacing.xxs) {
            ForEach(AppAppearanceMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Text(mode.title)
                        .setlistTextStyle(.actionButton)
                        .foregroundStyle(
                            selection == mode
                                ? Color.white
                                : SetlistColor.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background {
                            if selection == mode {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(SetlistColor.brandPrimary)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .padding(SetlistSpacing.xxs)
        .frame(height: 44)
        .background(SetlistColor.backgroundSubtle)
        .clipShape(RoundedRectangle(cornerRadius: SetlistRadius.small))
    }
}
