import AVFAudio
import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var spotifySession: SpotifySession
    @AppStorage(AppAppearanceMode.storageKey)
    private var appearanceModeRawValue = AppAppearanceMode.dark.rawValue

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(spacing: SetlistMargin.large) {
                    spotifySection
                    appearanceSection
                    appSection
                }
                .padding(.horizontal, SetlistMargin.medium)
                .padding(.top, SetlistSpacing.large)
                .padding(.bottom, SetlistMargin.large)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var spotifySection: some View {
        SettingsSection(title: "SPOTIFY") {
            SettingsCard {
                HStack(spacing: SetlistSpacing.medium) {
                    VStack(alignment: .leading, spacing: SetlistSpacing.xxs) {
                        Text("Spotify 계정")
                            .setlistTextStyle(.contentSong)
                            .foregroundStyle(SetlistColor.textPrimary)

                        Text("계정 연결 및 내보내기 관리")
                            .setlistTextStyle(.settingsDescription)
                            .foregroundStyle(SetlistColor.textTertiary)
                    }

                    Spacer(minLength: 0)

                    SettingsValue(
                        title: spotifySession.isConnected ? "연결됨" : "연결 필요",
                        showsChevron: true
                    )
                }
                .padding(.horizontal, SetlistSpacing.medium)
                .frame(height: 92)
            }
        }
    }

    private var appearanceSection: some View {
        SettingsSection(title: "화면") {
            SettingsCard {
                VStack(alignment: .leading, spacing: SetlistSpacing.medium) {
                    VStack(alignment: .leading, spacing: SetlistSpacing.xxs) {
                        Text("화면 모드")
                            .setlistTextStyle(.contentSong)
                            .foregroundStyle(SetlistColor.textPrimary)

                        Text("기본값은 다크 모드예요")
                            .setlistTextStyle(.settingsDescription)
                            .foregroundStyle(SetlistColor.textTertiary)
                    }

                    AppearancePicker(selection: appearanceModeBinding)
                }
                .padding(SetlistSpacing.medium)
                .frame(height: 166, alignment: .top)
            }
        }
    }

    private var appSection: some View {
        SettingsSection(title: "앱") {
            SettingsCard {
                VStack(spacing: 0) {
                    SettingsInfoRow(
                        icon: "microphone.fill",
                        title: "마이크 권한",
                        value: microphonePermissionTitle,
                        valueColor: microphonePermissionColor,
                        showsChevron: true
                    )

                    Rectangle()
                        .fill(SetlistColor.borderDefault)
                        .frame(height: 1)

                    SettingsInfoRow(
                        icon: "info.circle",
                        title: "앱 버전",
                        value: appVersion
                    )
                }
            }
        }
    }

    private var microphonePermissionTitle: String {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: "허용됨"
        case .denied: "허용 안 됨"
        case .undetermined: "확인 필요"
        @unknown default: "확인 필요"
        }
    }

    private var microphonePermissionColor: Color {
        AVAudioApplication.shared.recordPermission == .granted
            ? SetlistColor.semanticSuccessContent
            : SetlistColor.textSecondary
    }

    private var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0.0"
    }

    private var appearanceModeBinding: Binding<AppAppearanceMode> {
        Binding(
            get: {
                AppAppearanceMode(rawValue: appearanceModeRawValue) ?? .dark
            },
            set: { mode in
                appearanceModeRawValue = mode.rawValue
            }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsScreen()
    }
    .environmentObject(SpotifySession())
}
