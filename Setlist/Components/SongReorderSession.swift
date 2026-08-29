import SwiftUI

struct SongReorderMove {
    let songs: [SetlistSong]
    let offsets: IndexSet
    let destination: Int
}

struct SongReorderSession {
    private var draggedSongID: String?
    private var initialSongs: [SetlistSong] = []
    private var initialCenters: [String: CGFloat] = [:]

    mutating func transition(
        for song: SetlistSong,
        locationY: CGFloat,
        displayedSongs: [SetlistSong],
        rowCenters: [String: CGFloat]
    ) -> (offsets: IndexSet, destination: Int)? {
        beginIfNeeded(
            with: song,
            displayedSongs: displayedSongs,
            rowCenters: rowCenters
        )

        guard
            draggedSongID == song.stableID,
            let sourceIndex = displayedSongs.firstIndex(where: {
                $0.stableID == song.stableID
            }),
            let targetIndex = targetIndex(for: locationY),
            sourceIndex != targetIndex
        else {
            return nil
        }

        let destination = targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
        return (IndexSet(integer: sourceIndex), destination)
    }

    mutating func finish(displayedSongs: [SetlistSong]) -> SongReorderMove? {
        defer { reset() }

        guard
            let draggedSongID,
            let sourceIndex = initialSongs.firstIndex(where: {
                $0.stableID == draggedSongID
            }),
            let finalIndex = displayedSongs.firstIndex(where: {
                $0.stableID == draggedSongID
            }),
            sourceIndex != finalIndex
        else {
            return nil
        }

        let destination = finalIndex > sourceIndex ? finalIndex + 1 : finalIndex
        return SongReorderMove(
            songs: initialSongs,
            offsets: IndexSet(integer: sourceIndex),
            destination: destination
        )
    }

    private mutating func beginIfNeeded(
        with song: SetlistSong,
        displayedSongs: [SetlistSong],
        rowCenters: [String: CGFloat]
    ) {
        guard draggedSongID == nil else { return }
        draggedSongID = song.stableID
        initialSongs = displayedSongs
        initialCenters = rowCenters
    }

    private func targetIndex(for locationY: CGFloat) -> Int? {
        initialSongs.enumerated()
            .compactMap { index, song -> (index: Int, distance: CGFloat)? in
                guard let center = initialCenters[song.stableID] else {
                    return nil
                }
                return (index, abs(center - locationY))
            }
            .min { $0.distance < $1.distance }?
            .index
    }

    private mutating func reset() {
        draggedSongID = nil
        initialSongs = []
        initialCenters = [:]
    }
}

struct SongRowCenterPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(
        value: inout [String: CGFloat],
        nextValue: () -> [String: CGFloat]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

extension View {
    func measuresSongRowCenter(id: String) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SongRowCenterPreferenceKey.self,
                    value: [id: proxy.frame(in: .global).midY]
                )
            }
        }
    }
}
