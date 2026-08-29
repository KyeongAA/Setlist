import Foundation

struct SetlistSong: Identifiable, Hashable {
    let id: Int
    let title: String
    let artist: String
    let storageID: UUID?

    init(
        id: Int,
        title: String,
        artist: String,
        storageID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.storageID = storageID
    }

    var number: String {
        String(format: "%02d", id)
    }
}

struct SetlistConcert: Identifiable, Hashable {
    let id: UUID
    let title: String
    let artist: String
    let date: String
    let photoData: Data?
    let placeholderType: Int

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        date: String,
        photoData: Data? = nil,
        placeholderType: Int = 1
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.date = date
        self.photoData = photoData
        self.placeholderType = placeholderType
    }
}

struct SetlistRecognitionGap: Identifiable, Hashable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let followingSongStorageID: UUID?

    init(
        id: UUID,
        startTime: TimeInterval,
        endTime: TimeInterval,
        followingSongStorageID: UUID? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.followingSongStorageID = followingSongStorageID
    }
}

extension SetlistSong {
    static let sampleSongs = [
        SetlistSong(id: 1, title: "Supernova", artist: "aespa"),
        SetlistSong(id: 2, title: "Blinding Lights", artist: "The Weeknd"),
        SetlistSong(id: 3, title: "Shape of You", artist: "Ed Sheeran"),
        SetlistSong(id: 4, title: "Levitating", artist: "Dua Lipa"),
        SetlistSong(id: 5, title: "Watermelon Sugar", artist: "Harry Styles"),
        SetlistSong(id: 6, title: "Peaches", artist: "Justin Bieber"),
        SetlistSong(id: 7, title: "Montero (Call Me By Your Name)", artist: "Lil Nas X"),
        SetlistSong(id: 8, title: "Stay", artist: "The Kid LAROI & Justin Bieber")
    ]
}

extension SetlistConcert {
    static let samples = [
        SetlistConcert(
            title: "Archive.1",
            artist: "WOODZ",
            date: "2026.03.14",
            placeholderType: 1
        ),
        SetlistConcert(
            title: "index_00",
            artist: "WOODZ",
            date: "2026.03.14",
            placeholderType: 3
        ),
        SetlistConcert(
            title: "부산국제록페스티벌",
            artist: "WOODZ, Suchmos 등",
            date: "2026.03.14",
            placeholderType: 5
        )
    ]
}

extension SetlistRecognitionGap {
    init(
        record: RecognitionGapRecord,
        followingSongStorageID: UUID? = nil
    ) {
        self.init(
            id: record.id,
            startTime: record.startTime,
            endTime: record.endTime,
            followingSongStorageID: followingSongStorageID
        )
    }
}

extension SetlistSong {
    init(record: SongRecord) {
        self.init(
            id: record.sortIndex + 1,
            title: record.title,
            artist: record.artistName,
            storageID: record.id
        )
    }
}

extension SetlistConcert {
    init(record: ConcertRecord) {
        self.init(
            id: record.id,
            title: record.title,
            artist: record.artistDescription,
            date: record.eventDate.formatted(
                .dateTime
                    .year()
                    .month(.twoDigits)
                    .day(.twoDigits)
            ),
            photoData: record.photoData,
            placeholderType: record.placeholderPosterType
        )
    }
}
