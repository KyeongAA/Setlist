import AppIntents
import SwiftUI

struct LiveActivityControl: View {
    let isListening: Bool
    var diameter: CGFloat = 64

    private var borderWidth: CGFloat {
        diameter <= 52 ? 1.5 : 2
    }

    private var playIconSize: CGFloat {
        diameter <= 52 ? 18 : 20
    }

    private var pauseBarSize: CGSize {
        diameter <= 52
            ? CGSize(width: 4, height: 18)
            : CGSize(width: 5, height: 22)
    }

    var body: some View {
        Button(intent: ToggleRecognitionIntent(shouldListen: !isListening)) {
            ZStack {
                Circle()
                    .fill(LiveActivityColor.controlBackground)

                Circle()
                    .strokeBorder(
                        LiveActivityColor.inverseBorder,
                        lineWidth: borderWidth
                    )

                if isListening {
                    HStack(spacing: 3) {
                        Capsule()
                            .frame(
                                width: pauseBarSize.width,
                                height: pauseBarSize.height
                            )
                        Capsule()
                            .frame(
                                width: pauseBarSize.width,
                                height: pauseBarSize.height
                            )
                    }
                    .foregroundStyle(LiveActivityColor.brand)
                } else {
                    FigmaPlayIcon()
                        .fill(LiveActivityColor.brand)
                        .frame(width: playIconSize, height: playIconSize)
                        .offset(x: 1)
                }
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isListening ? "음악 인식 일시정지" : "음악 인식 다시 시작")
    }
}

struct CompactRecognitionStatus: View {
    let isListening: Bool

    var body: some View {
        Group {
            if isListening {
                Circle()
                    .fill(LiveActivityColor.brand)
                    .frame(width: 8, height: 8)
            } else {
                FigmaPlayIcon()
                    .fill(LiveActivityColor.brand)
                    .frame(width: 16, height: 16)
            }
        }
        .frame(width: 20, height: 18)
        .accessibilityHidden(true)
    }
}

private struct FigmaPlayIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 20
        let scaleY = rect.height / 20
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        var path = Path()
        path.move(to: point(16.25, 8.91748))
        path.addCurve(
            to: point(16.25, 11.0825),
            control1: point(17.0833, 9.39861),
            control2: point(17.0833, 10.6014)
        )
        path.addLine(to: point(5, 17.5777))
        path.addCurve(
            to: point(3.125, 16.4952),
            control1: point(4.16667, 18.0589),
            control2: point(3.125, 17.4575)
        )
        path.addLine(to: point(3.125, 3.50482))
        path.addCurve(
            to: point(5, 2.42229),
            control1: point(3.125, 2.54257),
            control2: point(4.16667, 1.94117)
        )
        path.closeSubpath()
        return path
    }
}
