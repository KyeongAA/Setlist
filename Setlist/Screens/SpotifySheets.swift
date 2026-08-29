import SwiftUI

enum SpotifySheetState {
    case connection
    case export
    case success
}

struct SpotifySheet: View {
    let state: SpotifySheetState
    var playlistName = "index_00  · WOODZ"
    var songCount = 5
    var primaryAction: () -> Void = {}
    var dismiss: () -> Void = {}

    var body: some View {
        ZStack(alignment: .top) {
            SetlistColor.backgroundCanvas

            SheetHandle()
                .padding(.top, SetlistSpacing.xs)

            switch state {
            case .connection:
                connectionContent
            case .export:
                exportContent
            case .success:
                successContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 40,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 40
            )
        )
    }

    private var connectionContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Spotify 계정 연결")
                .setlistTextStyle(.headingTitle)
                .foregroundStyle(SetlistColor.textPrimary)

            Text("셋리스트를 내 계정의 비공개 플레이리스트로 만들어요.")
                .setlistTextStyle(.bodySecondary)
                .foregroundStyle(SetlistColor.textSecondary)
                .padding(.top, SetlistSpacing.medium)

            Text("요청 권한 · 플레이리스트 생성 및 곡 추가")
                .setlistTextStyle(.utilityStatus)
                .foregroundStyle(SetlistColor.textSecondary)
                .padding(.top, SetlistSpacing.medium)

            SpotifyPrimaryButton(title: "Spotify로 계속하기", action: primaryAction)
                .padding(.top, SetlistSpacing.medium)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SetlistMargin.large)
        .padding(.top, SetlistMargin.large)
    }

    private var exportContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Spotify로 내보내기")
                .setlistTextStyle(.headingTitle)
                .foregroundStyle(SetlistColor.textPrimary)

            Text("플레이리스트 이름")
                .setlistTextStyle(.utilityStatus)
                .foregroundStyle(SetlistColor.textSecondary)
                .padding(.top, SetlistSpacing.medium)

            Text(playlistName)
                .setlistTextStyle(.bodySecondary)
                .foregroundStyle(SetlistColor.textPrimary)
                .padding(SetlistSpacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 48)
                .overlay {
                    RoundedRectangle(cornerRadius: SetlistRadius.medium)
                        .stroke(SetlistColor.borderDefault, lineWidth: 1)
                }
                .padding(.top, SetlistSpacing.medium)

            Text("\(songCount)곡  ·  비공개 플레이리스트")
                .setlistTextStyle(.bodySecondary)
                .foregroundStyle(SetlistColor.textSecondary)
                .padding(.top, SetlistSpacing.medium)

            SpotifyPrimaryButton(title: "플레이리스트 만들기", action: primaryAction)
                .padding(.top, SetlistSpacing.medium)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SetlistMargin.large)
        .padding(.top, SetlistMargin.large)
    }

    private var successContent: some View {
        VStack(spacing: 0) {
            RoundActionButton(icon: .checkmark, size: 48)
                .padding(.top, SetlistSpacing.extraLarge)

            Text("플레이리스트를 만들었어요")
                .setlistTextStyle(.headingTitle)
                .foregroundStyle(SetlistColor.textPrimary)
                .padding(.top, SetlistSpacing.large)

            Text(playlistName)
                .setlistTextStyle(.bodyPrimary)
                .foregroundStyle(SetlistColor.textSecondary)
                .padding(.top, SetlistSpacing.large)

            SpotifyPrimaryButton(title: "Spotify에서 열기", action: primaryAction)
                .padding(.top, SetlistSpacing.large)

            Button(action: dismiss) {
                Text("완료")
                    .setlistTextStyle(.actionButton)
                    .foregroundStyle(SetlistColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
            .padding(.top, SetlistSpacing.xs)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SetlistMargin.large)
    }
}

#Preview("Spotify · Connection") {
    SpotifySheet(state: .connection)
        .frame(width: 375, height: 398)
}

#Preview("Spotify · Export") {
    SpotifySheet(state: .export)
        .frame(width: 375, height: 398)
}

#Preview("Spotify · Success") {
    SpotifySheet(state: .success)
        .frame(width: 375, height: 398)
}
