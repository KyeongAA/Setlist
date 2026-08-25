import Foundation
import SwiftData

@Model
final class RecognitionGapRecord {
    @Attribute(.unique) var id: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var createdAt: Date
    var concert: ConcertRecord?

    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        createdAt: Date = .now,
        concert: ConcertRecord? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.createdAt = createdAt
        self.concert = concert
    }

    var duration: TimeInterval {
        max(0, endTime - startTime)
    }
}
