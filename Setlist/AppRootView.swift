import SwiftUI
import SwiftData

struct AppRootView: View {
    @AppStorage(AppAppearanceMode.storageKey)
    private var appearanceModeRawValue = AppAppearanceMode.dark.rawValue
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            if isShowingSplash {
                SplashScreen()
                    .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .task {
            guard isShowingSplash else { return }

            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }

            withAnimation(.easeOut(duration: 0.25)) {
                isShowingSplash = false
            }
        }
    }

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRawValue) ?? .dark
    }
}

#Preview {
    AppRootView()
        .preferredColorScheme(.dark)
        .modelContainer(
            for: [
                ConcertRecord.self,
                SongRecord.self,
                RecognitionGapRecord.self,
            ],
            inMemory: true
        )
        .environmentObject(SpotifySession())
}
