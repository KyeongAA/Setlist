import ActivityKit
import Combine
import Foundation

@MainActor
final class RecognitionLiveActivityManager: ObservableObject {
    private let maximumActivityDuration: TimeInterval = 8 * 60 * 60

    private var activity: Activity<RecognitionActivityAttributes>?
    private var transitionTask: Task<Void, Never>?
    private var startedAt: Date?
    private var latestTitle: String?
    private var latestArtist: String?
    private var animationToken = 0

    var isActive: Bool {
        activity != nil
    }

    init() {
        guard let existing = Activity<RecognitionActivityAttributes>.activities.first else {
            return
        }

        activity = existing
        startedAt = existing.attributes.startedAt
        latestTitle = existing.content.state.latestTitle
        latestArtist = existing.content.state.latestArtist
        animationToken = existing.content.state.animationToken
    }

    func startOrResume(concertID: UUID, nextSongNumber: Int) {
        transitionTask?.cancel()

        if activity == nil {
            activity = Activity<RecognitionActivityAttributes>.activities.first {
                $0.attributes.concertID == concertID
            }
        }

        if activity == nil {
            start(
                concertID: concertID,
                nextSongNumber: nextSongNumber,
                phase: .listening
            )
        } else {
            update(
                phase: .listening,
                songNumber: nextSongNumber,
                animatesWaveform: true
            )
        }
    }

    func startPaused(concertID: UUID, nextSongNumber: Int) {
        transitionTask?.cancel()

        if activity == nil {
            activity = Activity<RecognitionActivityAttributes>.activities.first {
                $0.attributes.concertID == concertID
            }
        }

        if activity == nil {
            start(
                concertID: concertID,
                nextSongNumber: nextSongNumber,
                phase: .paused
            )
        } else {
            pause(nextSongNumber: nextSongNumber)
        }
    }

    func pause(nextSongNumber: Int) {
        transitionTask?.cancel()
        update(
            phase: .paused,
            songNumber: nextSongNumber,
            animatesWaveform: false
        )
    }

    func recognized(
        songNumber: Int,
        title: String,
        artist: String
    ) {
        transitionTask?.cancel()
        latestTitle = title
        latestArtist = artist

        update(
            phase: .recognized,
            songNumber: songNumber,
            animatesWaveform: true
        )

        transitionTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }

            guard let self else { return }
            self.update(
                phase: .listening,
                songNumber: songNumber + 1,
                animatesWaveform: true
            )
        }
    }

    func refresh(nextSongNumber: Int, isListening: Bool) {
        guard activity != nil else { return }
        transitionTask?.cancel()
        update(
            phase: isListening ? .listening : .paused,
            songNumber: nextSongNumber,
            animatesWaveform: isListening
        )
    }

    func end() {
        transitionTask?.cancel()
        transitionTask = nil

        let activities = Activity<RecognitionActivityAttributes>.activities
        activity = nil
        startedAt = nil
        latestTitle = nil
        latestArtist = nil

        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func start(
        concertID: UUID,
        nextSongNumber: Int,
        phase: RecognitionActivityAttributes.ContentState.Phase
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date.now
        startedAt = now
        animationToken += 1

        let attributes = RecognitionActivityAttributes(
            concertID: concertID,
            startedAt: now
        )
        let state = makeState(
            phase: phase,
            songNumber: nextSongNumber
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: makeContent(state: state),
                pushType: nil
            )
        } catch {
            assertionFailure("Failed to start Live Activity: \(error)")
        }
    }

    private func update(
        phase: RecognitionActivityAttributes.ContentState.Phase,
        songNumber: Int,
        animatesWaveform: Bool
    ) {
        guard let activity else { return }

        if animatesWaveform {
            animationToken += 1
        }

        let state = makeState(
            phase: phase,
            songNumber: songNumber
        )
        let content = makeContent(state: state)

        Task {
            await activity.update(content)
        }
    }

    private func makeState(
        phase: RecognitionActivityAttributes.ContentState.Phase,
        songNumber: Int
    ) -> RecognitionActivityAttributes.ContentState {
        RecognitionActivityAttributes.ContentState(
            phase: phase,
            songNumber: max(1, songNumber),
            latestTitle: latestTitle,
            latestArtist: latestArtist,
            waveformSeed: max(1, songNumber),
            animationToken: animationToken
        )
    }

    private func makeContent(
        state: RecognitionActivityAttributes.ContentState
    ) -> ActivityContent<RecognitionActivityAttributes.ContentState> {
        let activityStartedAt = startedAt ?? activity?.attributes.startedAt ?? .now
        return ActivityContent(
            state: state,
            staleDate: activityStartedAt.addingTimeInterval(maximumActivityDuration),
            relevanceScore: 100
        )
    }
}
