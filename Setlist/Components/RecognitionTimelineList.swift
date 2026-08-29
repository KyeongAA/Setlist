import SwiftUI
import UniformTypeIdentifiers

struct RecognitionTimelineList<Footer: View>: View {
    let songs: [SetlistSong]
    let gaps: [SetlistRecognitionGap]
    let activeGapStartTime: TimeInterval?
    let activeGapEndTime: TimeInterval
    let footer: Footer
    var includesFooter: Bool
    var fillsAvailableHeight: Bool
    var automaticallyScrollsToLatest: Bool
    var gapAction: () -> Void = {}
    var deleteSong: (SetlistSong) -> Void = { _ in }
    var moveSongs: ([SetlistSong], IndexSet, Int) -> Void = { _, _, _ in }

    @State private var displayedSongs: [SetlistSong]
    @State private var draggingSong: SetlistSong?

    private let rowHeight: CGFloat = 48
    private let gapHeight: CGFloat = 122
    private let rowSpacing = SetlistSpacing.small
    private let activeGapScrollID = "active-recognition-gap"

    init(
        songs: [SetlistSong],
        gaps: [SetlistRecognitionGap],
        activeGapStartTime: TimeInterval? = nil,
        activeGapEndTime: TimeInterval = 0,
        includesFooter: Bool = true,
        fillsAvailableHeight: Bool = false,
        automaticallyScrollsToLatest: Bool = false,
        gapAction: @escaping () -> Void = {},
        deleteSong: @escaping (SetlistSong) -> Void = { _ in },
        moveSongs: @escaping ([SetlistSong], IndexSet, Int) -> Void = { _, _, _ in },
        @ViewBuilder footer: () -> Footer
    ) {
        self.songs = songs
        self.gaps = gaps
        self.activeGapStartTime = activeGapStartTime
        self.activeGapEndTime = activeGapEndTime
        self.footer = footer()
        self.includesFooter = includesFooter
        self.fillsAvailableHeight = fillsAvailableHeight
        self.automaticallyScrollsToLatest = automaticallyScrollsToLatest
        self.gapAction = gapAction
        self.deleteSong = deleteSong
        self.moveSongs = moveSongs
        _displayedSongs = State(initialValue: songs)
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            List {
                ForEach(displayedSongs) { song in
                    ForEach(gaps(before: song)) { gap in
                        gapRow(gap)
                    }

                    songRow(song)
                }

                ForEach(trailingGaps) { gap in
                    gapRow(gap)
                }

                if let activeGapStartTime {
                    MissingCard(
                        startTime: activeGapStartTime,
                        endTime: activeGapEndTime,
                        action: gapAction
                    )
                    .id(activeGapScrollID)
                    .timelineListRow()
                }

                if includesFooter {
                    footer
                        .timelineListRow()
                }
            }
            .listStyle(.plain)
            .listRowSpacing(rowSpacing)
            .contentMargins(.vertical, 0, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: fillsAvailableHeight ? nil : timelineHeight)
            .frame(maxHeight: fillsAvailableHeight ? .infinity : nil)
            .environment(\.defaultMinListRowHeight, rowHeight)
            .onChange(of: songs) { oldSongs, newSongs in
                guard newSongs != displayedSongs else { return }
                displayedSongs = newSongs

                guard
                    automaticallyScrollsToLatest,
                    newSongs.count > oldSongs.count,
                    let latestSongID = newSongs.last?.id
                else {
                    return
                }

                scroll(to: latestSongID, using: scrollProxy)
            }
            .onChange(of: activeGapStartTime) { oldValue, newValue in
                guard
                    automaticallyScrollsToLatest,
                    oldValue == nil,
                    newValue != nil
                else {
                    return
                }

                scroll(to: activeGapScrollID, using: scrollProxy)
            }
        }
    }

    private func songRow(_ song: SetlistSong) -> some View {
        SongRow(
            song: song,
            accessory: .handle,
            dragProvider: {
                draggingSong = song
                return NSItemProvider(
                    object: dragIdentifier(for: song) as NSString
                )
            }
        )
        .id(song.id)
        .contentShape(Rectangle())
        .onDrop(
            of: [UTType.text],
            delegate: SongReorderDropDelegate(
                targetSong: song,
                displayedSongs: $displayedSongs,
                draggingSong: $draggingSong,
                commitMove: commitMove
            )
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteSong(song)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .timelineListRow()
    }

    private func gapRow(_ gap: SetlistRecognitionGap) -> some View {
        MissingCard(
            startTime: gap.startTime,
            endTime: gap.endTime,
            action: gapAction
        )
        .id(gap.id)
        .timelineListRow()
    }

    private func gaps(before song: SetlistSong) -> [SetlistRecognitionGap] {
        guard let storageID = song.storageID else { return [] }
        return gaps.filter { $0.followingSongStorageID == storageID }
    }

    private var trailingGaps: [SetlistRecognitionGap] {
        gaps.filter { $0.followingSongStorageID == nil }
    }

    private var timelineHeight: CGFloat {
        let itemCount = songs.count + gaps.count + (activeGapStartTime == nil ? 0 : 1)
        guard itemCount > 0 else { return 0 }

        let songsHeight = CGFloat(songs.count) * rowHeight
        let gapsHeight = CGFloat(gaps.count + (activeGapStartTime == nil ? 0 : 1)) * gapHeight
        let spacingHeight = CGFloat(itemCount - 1) * rowSpacing
        return songsHeight + gapsHeight + spacingHeight
    }

    private func dragIdentifier(for song: SetlistSong) -> String {
        song.storageID?.uuidString ?? "preview-\(song.id)"
    }

    private func commitMove(_ draggedSong: SetlistSong, finalIndex: Int) {
        guard
            let sourceIndex = songs.firstIndex(of: draggedSong),
            sourceIndex != finalIndex
        else {
            return
        }

        let destination = finalIndex > sourceIndex ? finalIndex + 1 : finalIndex
        moveSongs(songs, IndexSet(integer: sourceIndex), destination)
    }

    private func scroll<ID: Hashable>(
        to id: ID,
        using proxy: ScrollViewProxy
    ) {
        Task { @MainActor in
            await Task.yield()
            withAnimation(.snappy) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }
}

private extension View {
    func timelineListRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

