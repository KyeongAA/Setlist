import SwiftUI

struct LiveActivityWaveform: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    let state: RecognitionActivityAttributes.ContentState
    var barCount = 9
    var barWidth: CGFloat = 4

    var body: some View {
        let animates = state.phase != .paused && !isLuminanceReduced

        Color.clear
            .keyframeAnimator(
                initialValue: WaveformAnimationValues(),
                trigger: state.animationToken
            ) { _, values in
                WaveformBars(
                    barCount: barCount,
                    barWidth: barWidth,
                    seed: state.waveformSeed,
                    phase: animates ? values.phase : 0
                )
            } keyframes: { _ in
                KeyframeTrack(\.phase) {
                    CubicKeyframe(0.75, duration: 0.5)
                    CubicKeyframe(1.5, duration: 0.5)
                    CubicKeyframe(2.25, duration: 0.5)
                    CubicKeyframe(3, duration: 0.5)
                }
            }
            .accessibilityHidden(true)
    }
}

private struct WaveformAnimationValues {
    var phase: CGFloat = 0
}

private struct WaveformBars: View {
    let barCount: Int
    let barWidth: CGFloat
    let seed: Int
    let phase: CGFloat

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: spacing(in: proxy.size.width)) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    LiveActivityColor.waveformTop,
                                    LiveActivityColor.brand,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(
                            width: barWidth,
                            height: barHeight(
                                at: index,
                                availableHeight: proxy.size.height
                            )
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func spacing(in availableWidth: CGFloat) -> CGFloat {
        guard barCount > 1 else { return 0 }
        return max(1.5, (availableWidth - CGFloat(barCount) * barWidth) / CGFloat(barCount - 1))
    }

    private func barHeight(at index: Int, availableHeight: CGFloat) -> CGFloat {
        let baseHeight = designHeight(at: index, availableHeight: availableHeight)
        let progress = min(3, max(0, phase)) / 3
        let envelope = sin(Double(progress) * .pi)
        let animation = sin(
            Double(phase) * .pi * 2
                + Double(index) * 0.82
                + Double(seed) * 0.31
        )
        let offset = CGFloat(animation * envelope) * availableHeight * 0.1
        return min(availableHeight, max(3, baseHeight + offset))
    }

    private func designHeight(at index: Int, availableHeight: CGFloat) -> CGFloat {
        let ratios: [CGFloat]

        if barCount == 9 {
            ratios = [9, 19, 15, 19, 27, 21, 15, 21, 9].map { $0 / 27 }
        } else {
            ratios = [11, 9, 16, 13, 13, 5].map { $0 / 16 }
        }

        return ratios[index % ratios.count] * availableHeight
    }
}

enum LiveActivityColor {
    static let brand = Color(red: 247 / 255, green: 37 / 255, blue: 144 / 255)
    static let waveformTop = Color(red: 248 / 255, green: 88 / 255, blue: 170 / 255)
    static let controlBackground = Color(red: 25 / 255, green: 21 / 255, blue: 26 / 255)
    static let inverseBorder = Color(red: 243 / 255, green: 240 / 255, blue: 243 / 255)
    static let secondaryText = Color(red: 151 / 255, green: 140 / 255, blue: 151 / 255)
}
