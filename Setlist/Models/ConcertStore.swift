import Foundation
import SwiftData

@MainActor
final class ConcertStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchConcerts() throws -> [ConcertRecord] {
        let descriptor = FetchDescriptor<ConcertRecord>(
            sortBy: [SortDescriptor(\.eventDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    @discardableResult
    func createConcert(eventDate: Date = .now) throws -> ConcertRecord {
        let concert = ConcertRecord(eventDate: eventDate)
        modelContext.insert(concert)
        try modelContext.save()
        return concert
    }

    func save(_ concert: ConcertRecord) throws {
        concert.updatedAt = .now
        try modelContext.save()
    }

    func complete(_ concert: ConcertRecord) throws {
        concert.status = concert.recognitionGaps.isEmpty ? .completed : .needsReview
        try modelContext.save()
    }

    func updateRecognitionDuration(
        _ duration: TimeInterval,
        in concert: ConcertRecord
    ) throws {
        concert.recognitionDuration = max(0, duration)
        concert.updatedAt = .now
        try modelContext.save()
    }

    func delete(_ concert: ConcertRecord) throws {
        modelContext.delete(concert)
        try modelContext.save()
    }

    @discardableResult
    func addSpotifySong(
        to concert: ConcertRecord,
        title: String,
        artistName: String,
        albumName: String?,
        artworkURLString: String?,
        durationMilliseconds: Int?,
        isrc: String?,
        spotifyTrackID: String,
        spotifyURI: String
    ) throws -> SongRecord {
        let song = SongRecord(
            sortIndex: nextSongIndex(in: concert),
            title: title,
            artistName: artistName,
            albumName: albumName,
            artworkURLString: artworkURLString,
            durationMilliseconds: durationMilliseconds,
            isrc: isrc,
            spotifyTrackID: spotifyTrackID,
            spotifyURI: spotifyURI,
            source: .spotifySearch,
            concert: concert
        )
        modelContext.insert(song)
        concert.songs.append(song)
        concert.updatedAt = .now
        try modelContext.save()
        return song
    }

    @discardableResult
    func addRecognizedSong(
        to concert: ConcertRecord,
        title: String,
        artistName: String,
        shazamID: String?,
        isrc: String? = nil,
        recognizedAt: Date = .now,
        recognitionStartTime: TimeInterval?,
        recognitionEndTime: TimeInterval?
    ) throws -> SongRecord {
        let song = SongRecord(
            sortIndex: nextSongIndex(in: concert),
            title: title,
            artistName: artistName,
            isrc: isrc,
            shazamID: shazamID,
            recognizedAt: recognizedAt,
            recognitionStartTime: recognitionStartTime,
            recognitionEndTime: recognitionEndTime,
            source: .shazam,
            concert: concert
        )
        modelContext.insert(song)
        concert.songs.append(song)
        concert.updatedAt = .now
        try modelContext.save()
        return song
    }

    @discardableResult
    func addRecognitionGap(
        to concert: ConcertRecord,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) throws -> RecognitionGapRecord {
        let gap = RecognitionGapRecord(
            startTime: startTime,
            endTime: endTime,
            concert: concert
        )
        modelContext.insert(gap)
        concert.recognitionGaps.append(gap)
        concert.updatedAt = .now
        try modelContext.save()
        return gap
    }

    func remove(_ song: SongRecord, from concert: ConcertRecord) throws {
        concert.songs.removeAll { $0.id == song.id }
        modelContext.delete(song)
        normalizeSongOrder(in: concert)
        concert.updatedAt = .now
        try modelContext.save()
    }

    func updateSongOrder(in concert: ConcertRecord, orderedSongIDs: [UUID]) throws {
        let indexByID = Dictionary(
            uniqueKeysWithValues: orderedSongIDs.enumerated().map { ($1, $0) }
        )

        for song in concert.songs {
            if let index = indexByID[song.id] {
                song.sortIndex = index
            }
        }

        concert.updatedAt = .now
        try modelContext.save()
    }

    private func nextSongIndex(in concert: ConcertRecord) -> Int {
        (concert.songs.map(\.sortIndex).max() ?? -1) + 1
    }

    private func normalizeSongOrder(in concert: ConcertRecord) {
        for (index, song) in concert.orderedSongs.enumerated() {
            song.sortIndex = index
        }
    }
}
