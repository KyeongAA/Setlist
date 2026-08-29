import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SetlistSpacing.xs) {
            Text(title)
                .setlistTextStyle(.utilityStatus)
                .foregroundStyle(SetlistColor.textSecondary)

            content
        }
    }
}

struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(SetlistColor.backgroundSurface)
            .clipShape(RoundedRectangle(cornerRadius: SetlistRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: SetlistRadius.medium)
                    .stroke(SetlistColor.borderDefault, lineWidth: 1)
            }
    }
}

struct SettingsValue: View {
    let title: String
    var foregroundStyle: Color = SetlistColor.textSecondary
    var showsChevron = false

    var body: some View {
        HStack(spacing: SetlistSpacing.xs) {
            Text(title)
                .setlistTextStyle(.utilityStatus)
                .foregroundStyle(foregroundStyle)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SetlistColor.textTertiary)
            }
        }
    }
}

struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color = SetlistColor.textSecondary
    var showsChevron = false

    var body: some View {
        HStack(spacing: SetlistSpacing.small) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(SetlistColor.textSecondary)
                .frame(width: 20)

            Text(title)
                .setlistTextStyle(.bodySecondary)
                .foregroundStyle(SetlistColor.textPrimary)

            Spacer(minLength: SetlistSpacing.small)

            SettingsValue(
                title: value,
                foregroundStyle: valueColor,
                showsChevron: showsChevron
            )
        }
        .padding(.horizontal, SetlistSpacing.medium)
        .frame(height: 60)
    }
}
