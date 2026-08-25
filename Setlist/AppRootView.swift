import SwiftUI
import SwiftData

struct AppRootView: View {
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
