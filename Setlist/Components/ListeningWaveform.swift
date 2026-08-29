import SwiftUI

enum WaveformMotionStyle {
    case flowing
    case randomPulse
}

struct ListeningWaveform: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pausedAt: Date?
    @State private var accumulatedPauseDuration: TimeInterval = 0

    let isAnimating: Bool
    var inputLevel: Double? = nil
    var height: CGFloat = 48
    var backgroundColor = Color(
        red: 25 / 255,
        green: 21 / 255,
        blue: 26 / 255
    )
    var cornerRadius: CGFloat = SetlistRadius.small
    var barHeightScale: CGFloat = 1
    var barStrokeWidth: CGFloat = 2.5
    var motionStyle: WaveformMotionStyle = .flowing

    private var shouldAnimate: Bool {
        isAnimating && !reduceMotion
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 60.0,
                paused: !shouldAnimate
            )
        ) { context in
            WaveformCanvas(
                animationTime: animationTime(at: context.date),
                barHeightScale: barHeightScale,
                barStrokeWidth: barStrokeWidth,
                motionStyle: motionStyle,
                inputLevelScale: inputLevelScale
            )
            .animation(.easeOut(duration: 0.18), value: inputLevelScale)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isAnimating ? "음악 인식 중" : "음악 인식 일시정지")
        .onAppear {
            if !shouldAnimate, pausedAt == nil {
                pausedAt = Date()
            }
        }
        .onChange(of: shouldAnimate) { _, isNowAnimating in
            let now = Date()

            if isNowAnimating {
                if let pausedAt {
                    accumulatedPauseDuration += now.timeIntervalSince(pausedAt)
                    self.pausedAt = nil
                }
            } else if pausedAt == nil {
                pausedAt = now
            }
        }
    }

    private func animationTime(at timelineDate: Date) -> TimeInterval {
        let visibleDate = pausedAt ?? timelineDate
        return visibleDate.timeIntervalSinceReferenceDate - accumulatedPauseDuration
    }

    private var inputLevelScale: CGFloat {
        guard let inputLevel else { return 1 }
        let clampedLevel = min(max(inputLevel, 0), 1)
        return 0.45 + CGFloat(clampedLevel) * 0.95
    }
}

private struct WaveformCanvas: View, Animatable {
    let animationTime: TimeInterval
    let barHeightScale: CGFloat
    let barStrokeWidth: CGFloat
    let motionStyle: WaveformMotionStyle
    var inputLevelScale: CGFloat

    private let barHeights: [CGFloat] = [6, 10, 12, 15, 17]
    private let barSpacing: CGFloat = 6
    private let minimumHorizontalInset: CGFloat = 12

    var animatableData: CGFloat {
        get { inputLevelScale }
        set { inputLevelScale = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let availableWidth = max(0, size.width - minimumHorizontalInset * 2)
            let barCount = max(1, Int(floor(availableWidth / barSpacing)) + 1)
            let waveformWidth = CGFloat(barCount - 1) * barSpacing
            let leadingInset = (size.width - waveformWidth) / 2

            for index in 0..<barCount {
                let x = leadingInset + CGFloat(index) * barSpacing
                let height = barHeight(at: index)
                let drawableHeight = max(0, height - barStrokeWidth)
                let top = (size.height - drawableHeight) / 2
                let bottom = (size.height + drawableHeight) / 2
                var path = Path()
                path.move(to: CGPoint(x: x, y: top))
                path.addLine(to: CGPoint(x: x, y: bottom))
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 248 / 255, green: 88 / 255, blue: 170 / 255),
                            Color(red: 247 / 255, green: 37 / 255, blue: 144 / 255)
                        ]),
                        startPoint: CGPoint(x: x, y: top),
                        endPoint: CGPoint(x: x, y: bottom)
                    ),
                    style: StrokeStyle(lineWidth: barStrokeWidth, lineCap: .round)
                )
            }
        }
        .clipped()
    }

    private func barHeight(at barIndex: Int) -> CGFloat {
        let normalizedHeight: Double

        switch motionStyle {
        case .flowing:
            let position = Double(barIndex) * 0.38
            let primaryWave = sin(position - animationTime * 2.1)
            let secondaryWave = sin(position * 0.56 - animationTime * 1.15 + 1.3) * 0.28
            normalizedHeight = (primaryWave + secondaryWave) / 1.28

        case .randomPulse:
            let phaseSeed = randomUnit(for: barIndex)
            let speedSeed = randomUnit(for: barIndex + 41)
            let phase = phaseSeed * Double.pi * 2
            let speed = 2.4 + speedSeed * 1.6
            let primaryPulse = sin(animationTime * speed + phase)
            let secondaryPulse = sin(
                animationTime * (speed * 0.57) + phase * 1.7
            ) * 0.24
            normalizedHeight = (primaryPulse + secondaryPulse) / 1.24
        }

        let minimumHeight = barHeights.first ?? 5
        let maximumHeight = barHeights.last ?? 15
        let centerHeight = (minimumHeight + maximumHeight) / 2
        let amplitude = (maximumHeight - minimumHeight) / 2
        return (centerHeight + amplitude * CGFloat(normalizedHeight))
            * barHeightScale
            * inputLevelScale
    }

    private func randomUnit(for value: Int) -> Double {
        let generated = sin(Double(value + 1) * 12.9898) * 43_758.5453
        return generated - floor(generated)
    }
}

#Preview {
    ListeningWaveform(isAnimating: true)
        .padding()
        .background(SetlistColor.backgroundCanvas)
        .preferredColorScheme(.dark)
}
