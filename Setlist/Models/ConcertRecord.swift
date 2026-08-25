import Foundation
import SwiftData

enum ConcertRecordStatus: String, Codable, CaseIterable {
    case recording
    case needsReview
    case completed
}

@Model
final class ConcertRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var artistDescription: String
    var eventDate: Date
    var createdAt: Date
    var updatedAt: Date
    var statusRawValue: String
    var recognitionDuration: TimeInterval = 0

    @Attribute(.externalStorage)
    var photoData: Data?

    @Relationship(deleteRule: .cascade, inverse: \SongRecord.concert)
    var songs: [SongRecord]

    @Relationship(deleteRule: .cascade, inverse: \RecognitionGapRecord.concert)
    var recognitionGaps: [RecognitionGapRecord]

    init(
        id: UUID = UUID(),
        title: String = "",
        artistDescription: String = "",
        eventDate: Date = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        recognitionDuration: TimeInterval = 0,
        status: ConcertRecordStatus = .recording,
        photoData: Data? = nil,
        songs: [SongRecord] = [],
        recognitionGaps: [RecognitionGapRecord] = []
    ) {
        self.id = id
        self.title = title
        self.artistDescription = artistDescription
        self.eventDate = eventDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.recognitionDuration = recognitionDuration
        self.statusRawValue = status.rawValue
        self.photoData = photoData
        self.songs = songs
        self.recognitionGaps = recognitionGaps
    }

    var status: ConcertRecordStatus {
        get { ConcertRecordStatus(rawValue: statusRawValue) ?? .recording }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = .now
        }
    }

    var orderedSongs: [SongRecord] {
        songs.sorted { $0.sortIndex < $1.sortIndex }
    }

    var placeholderPosterType: Int {
        let compactID = id.uuidString.replacingOccurrences(of: "-", with: "")
        let prefix = String(compactID.prefix(8))
        let stableValue = UInt64(prefix, radix: 16) ?? 0
        return Int(stableValue % 6) + 1
    }
}
