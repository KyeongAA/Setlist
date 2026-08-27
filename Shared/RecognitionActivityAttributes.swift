import ActivityKit
import AppIntents
import Foundation

struct RecognitionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        enum Phase: String, Codable, Hashable, Sendable {
            case listening
            case paused
            case recognized
        }

        var phase: Phase
        var songNumber: Int
        var latestTitle: String?
        var latestArtist: String?
        var waveformSeed: Int
        var animationToken: Int

        var statusText: String {
            switch phase {
            case .listening:
                "\(songNumber)번째 음악을 인식 중이에요"
            case .paused:
                "\(songNumber)번째 음악 인식을 일시정지했어요"
            case .recognized:
                "\(songNumber)번째 음악을 인식했어요"
            }
        }

        var isListening: Bool {
            phase != .paused
        }

        var recentTrackText: String? {
            guard let latestTitle, let latestArtist else { return nil }
            return "최근 인식 · \(latestTitle) — \(latestArtist)"
        }
    }

    var concertID: UUID
    var startedAt: Date
}

@MainActor
final class RecognitionControlBridge {
    static let shared = RecognitionControlBridge()

    private var handler: ((Bool) async -> Void)?

    private init() {}

    func install(_ handler: @escaping (Bool) async -> Void) {
        self.handler = handler
    }

    func perform(shouldListen: Bool) async {
        await handler?(shouldListen)
    }
}

struct ToggleRecognitionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "음악 인식 전환"
    static let description = IntentDescription("진행 중인 음악 인식을 일시정지하거나 다시 시작합니다.")
    static let openAppWhenRun = false

    @Parameter(title: "인식 시작")
    var shouldListen: Bool

    init() {
        shouldListen = false
    }

    init(shouldListen: Bool) {
        self.shouldListen = shouldListen
    }

    func perform() async throws -> some IntentResult {
        await RecognitionControlBridge.shared.perform(shouldListen: shouldListen)
        return .result()
    }
}
