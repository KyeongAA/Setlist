import SwiftUI

enum SetlistSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 20
    static let extraLarge: CGFloat = 32
}

enum SetlistMargin {
    static let extraSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 40
    static let extraExtraLarge: CGFloat = 80
}

enum SetlistRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let full: CGFloat = 999
}

enum SetlistColor {
    static let brandPrimary = Color("BrandPrimary")
    static let brandSecondary = Color("BrandSecondary")
    static let brandAccent = Color("BrandAccent")
    static let brandSubtle = Color("BrandSubtle")

    static let backgroundCanvas = Color("BackgroundCanvas")
    static let backgroundSurface = Color("BackgroundSurface")
    static let backgroundElevated = Color("BackgroundElevated")
    static let backgroundSubtle = Color("BackgroundSubtle")
    static let backgroundInverse = Color("BackgroundInverse")
    static let backgroundMinibar = Color("BackgroundMinibar")

    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textTertiary = Color("TextTertiary")
    static let textDisabled = Color("TextDisabled")
    static let textInverse = Color("TextInverse")
    static let textBrand = Color("TextBrand")

    static let borderDefault = Color("BorderDefault")
    static let borderStrong = Color("BorderStrong")
    static let borderSubtle = Color("BorderSubtle")
    static let borderInverse = Color("BorderInverse")
    static let borderBrand = Color("BorderBrand")

    static let iconPrimary = Color("IconPrimary")
    static let iconSecondary = Color("IconSecondary")
    static let iconBrand = Color("IconBrand")
    static let iconDisabled = Color("IconDisabled")
    static let iconInverse = Color("IconInverse")

    static let focusRing = Color("FocusRing")
    static let semanticSuccessContent = Color("SemanticSuccessContent")
    static let semanticWarningContent = Color("SemanticWarningContent")
    static let semanticErrorContent = Color("SemanticErrorContent")
    static let semanticInfoContent = Color("SemanticInfoContent")
    static let spotifyGreen = Color("SpotifyGreen")
}

enum SetlistTextStyle {
    case headingTitle
    case headingSheet
    case headingSection
    case contentSong
    case actionButton
    case utilityStatus
    case bodyPrimary
    case bodySecondary
    case contentArtist
    case utilityMetadata

    var size: CGFloat {
        switch self {
        case .headingTitle: 24
        case .headingSheet: 20
        case .headingSection: 18
        case .contentSong, .bodyPrimary: 16
        case .actionButton, .bodySecondary, .contentArtist: 14
        case .utilityStatus, .utilityMetadata: 12
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .headingTitle, .headingSheet: 28
        case .headingSection: 26
        case .contentSong, .bodyPrimary: 24
        case .bodySecondary: 22
        case .actionButton, .contentArtist: 20
        case .utilityStatus, .utilityMetadata: 16
        }
    }

    var tracking: CGFloat {
        switch self {
        case .headingTitle, .headingSheet, .headingSection: -0.2
        default: 0
        }
    }

    var fontName: String {
        switch self {
        case .headingTitle:
            "Pretendard-Bold"
        case .headingSheet, .headingSection, .contentSong, .actionButton, .utilityStatus:
            "Pretendard-SemiBold"
        case .bodyPrimary, .bodySecondary, .contentArtist, .utilityMetadata:
            "Pretendard-Regular"
        }
    }

    var relativeTextStyle: Font.TextStyle {
        switch self {
        case .headingTitle: .title2
        case .headingSheet: .title3
        case .headingSection: .headline
        case .contentSong, .bodyPrimary: .body
        case .actionButton, .bodySecondary, .contentArtist: .subheadline
        case .utilityStatus, .utilityMetadata: .caption
        }
    }
}

private struct SetlistTypographyModifier: ViewModifier {
    let style: SetlistTextStyle

    func body(content: Content) -> some View {
        content
            .font(.custom(style.fontName, size: style.size, relativeTo: style.relativeTextStyle))
            .tracking(style.tracking)
            .lineSpacing(max(0, style.lineHeight - style.size))
    }
}

extension View {
    func setlistTextStyle(_ style: SetlistTextStyle) -> some View {
        modifier(SetlistTypographyModifier(style: style))
    }
}

struct ScreenBackground: View {
    var body: some View {
        ZStack {
            SetlistColor.backgroundCanvas
            LinearGradient(
                colors: [.clear, SetlistColor.brandSubtle.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}
