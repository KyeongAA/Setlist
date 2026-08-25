import Foundation
import SwiftData

enum SongRecordSource: String, Codable, CaseIterable {
    case shazam
    case spotifySearch
}

@Model
final class SongRecord {
    @Attribute(.unique) var id: UUID
    var sortIndex: Int
    var title: String
    var artistName: String
    var albumName: String?
    var artworkURLString: String?
    var durationMilliseconds: Int?
    var isrc: String?
    var spotifyTrackID: String?
    var spotifyURI: String?
    var shazamID: String?
    var recognizedAt: Date?
    var recognitionStartTime: TimeInterval?
    var recognitionEndTime: TimeInterval?
    var sourceRawValue: String
    var concert: ConcertRecord?

    init(
        id: UUID = UUID(),
        sortIndex: Int,
        title: String,
        artistName: String,
        albumName: String? = nil,
        artworkURLString: String? = nil,
        durationMilliseconds: Int? = nil,
        isrc: String? = nil,
        spotifyTrackID: String? = nil,
        spotifyURI: String? = nil,
        shazamID: String? = nil,
        recognizedAt: Date? = nil,
        recognitionStartTime: TimeInterval? = nil,
        recognitionEndTime: TimeInterval? = nil,
        source: SongRecordSource,
        concert: ConcertRecord? = nil
    ) {
        self.id = id
        self.sortIndex = sortIndex
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.artworkURLString = artworkURLString
        self.durationMilliseconds = durationMilliseconds
        self.isrc = isrc
        self.spotifyTrackID = spotifyTrackID
        self.spotifyURI = spotifyURI
        self.shazamID = shazamID
        self.recognizedAt = recognizedAt
        self.recognitionStartTime = recognitionStartTime
        self.recognitionEndTime = recognitionEndTime
        self.sourceRawValue = source.rawValue
        self.concert = concert
    }

    var source: SongRecordSource {
        get { SongRecordSource(rawValue: sourceRawValue) ?? .spotifySearch }
        set { sourceRawValue = newValue.rawValue }
    }
}
