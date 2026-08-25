import SwiftUI

struct SplashScreen: View {
    var body: some View {
        ZStack {
            ScreenBackground()

            ListeningWaveform(
                isAnimating: true,
                height: 40,
                backgroundColor: .clear,
                cornerRadius: 0,
                barHeightScale: 2.2,
                barStrokeWidth: 3,
                motionStyle: .randomPulse
            )
            .frame(width: 120)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("앱을 여는 중")
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SplashScreen()
        .preferredColorScheme(.dark)
}
