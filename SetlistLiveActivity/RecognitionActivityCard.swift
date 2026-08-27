import SwiftUI

struct RecognitionLockScreenView: View {
    let state: RecognitionActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                LiveActivityWaveform(state: state)
                    .frame(width: 63, height: 27)

                Text(state.statusText)
                    .font(.custom("Pretendard-SemiBold", size: 18))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 10)

            LiveActivityControl(
                isListening: state.isListening,
                diameter: 52
            )
        }
        .padding(.leading, 20)
        .padding(.trailing, 24)
        .frame(maxWidth: .infinity)
        .frame(height: 108)
        .background(Color.black)
        .accessibilityElement(children: .combine)
    }
}

struct RecognitionExpandedStatus: View {
    let state: RecognitionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(state.statusText)
                .font(.custom("Pretendard-SemiBold", size: 18))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            if let recentTrackText = state.recentTrackText {
                Text(recentTrackText)
                    .font(.custom("Pretendard-Regular", size: 12))
                    .foregroundStyle(LiveActivityColor.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 2)
        .accessibilityElement(children: .combine)
    }
}

struct RecognitionExpandedView: View {
    let state: RecognitionActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                LiveActivityWaveform(state: state)
                    .frame(width: 63, height: 27)

                RecognitionExpandedStatus(state: state)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            LiveActivityControl(
                isListening: state.isListening,
                diameter: 48
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 74, alignment: .top)
        .padding(.horizontal, 6)
    }
}
