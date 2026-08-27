import ActivityKit
import SwiftUI
import WidgetKit

struct RecognitionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecognitionActivityAttributes.self) { context in
            RecognitionLockScreenView(state: context.state)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    RecognitionExpandedView(state: context.state)
                }
                .contentMargins(.leading, 24)
                .contentMargins(.trailing, 24)
                .contentMargins(.bottom, 12)
            } compactLeading: {
                LiveActivityWaveform(
                    state: context.state,
                    barCount: 6,
                    barWidth: 3
                )
                .frame(width: 28, height: 16)
            } compactTrailing: {
                CompactRecognitionStatus(isListening: context.state.isListening)
            } minimal: {
                LiveActivityWaveform(
                    state: context.state,
                    barCount: 6,
                    barWidth: 18 / 7
                )
                .frame(width: 24, height: 14)
            }
            .keylineTint(LiveActivityColor.brand)
        }
    }
}

#Preview("Lock Screen · 인식 중", as: .content, using: RecognitionActivityAttributes.preview) {
    RecognitionLiveActivityWidget()
} contentStates: {
    RecognitionActivityAttributes.ContentState.previewListening
    RecognitionActivityAttributes.ContentState.previewPaused
}

#Preview("Dynamic Island · Expanded", as: .dynamicIsland(.expanded), using: RecognitionActivityAttributes.preview) {
    RecognitionLiveActivityWidget()
} contentStates: {
    RecognitionActivityAttributes.ContentState.previewListening
    RecognitionActivityAttributes.ContentState.previewRecognized
    RecognitionActivityAttributes.ContentState.previewPaused
}

#Preview("Dynamic Island · Compact", as: .dynamicIsland(.compact), using: RecognitionActivityAttributes.preview) {
    RecognitionLiveActivityWidget()
} contentStates: {
    RecognitionActivityAttributes.ContentState.previewListening
    RecognitionActivityAttributes.ContentState.previewPaused
}

#Preview("Dynamic Island · Minimal", as: .dynamicIsland(.minimal), using: RecognitionActivityAttributes.preview) {
    RecognitionLiveActivityWidget()
} contentStates: {
    RecognitionActivityAttributes.ContentState.previewListening
}

private extension RecognitionActivityAttributes {
    static let preview = RecognitionActivityAttributes(
        concertID: UUID(),
        startedAt: .now
    )
}

private extension RecognitionActivityAttributes.ContentState {
    static let previewListening = Self(
        phase: .listening,
        songNumber: 1,
        latestTitle: nil,
        latestArtist: nil,
        waveformSeed: 1,
        animationToken: 1
    )

    static let previewRecognized = Self(
        phase: .recognized,
        songNumber: 1,
        latestTitle: "After Hours Dinner",
        latestArtist: "Almost Here",
        waveformSeed: 1,
        animationToken: 2
    )

    static let previewPaused = Self(
        phase: .paused,
        songNumber: 2,
        latestTitle: "After Hours Dinner",
        latestArtist: "Almost Here",
        waveformSeed: 2,
        animationToken: 2
    )
}
