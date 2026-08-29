import SwiftUI

struct EditableSongList<Footer: View>: View {
    let songs: [SetlistSong]
    let footer: Footer
    var maximumVisibleRows: Int?
    var fillsAvailableHeight: Bool
    var automaticallyScrollsToLatest: Bool
    var deleteSong: (SetlistSong) -> Void = { _ in }
    var moveSongs: ([SetlistSong], IndexSet, Int) -> Void = { _, _, _ in }

    @State private var displayedSongs: [SetlistSong]
    @State private var reorderSession = SongReorderSession()
    @State private var songRowCenters: [String: CGFloat] = [:]

    private let rowHeight: CGFloat = 48
    private let rowSpacing = SetlistSpacing.small

    init(
        songs: [SetlistSong],
        maximumVisibleRows: Int? = nil,
        fillsAvailableHeight: Bool = false,
        automaticallyScrollsToLatest: Bool = false,
        deleteSong: @escaping (SetlistSong) -> Void = { _ in },
        moveSongs: @escaping ([SetlistSong], IndexSet, Int) -> Void = { _, _, _ in },
        @ViewBuilder footer: () -> Footer
    ) {
        self.songs = songs
        self.footer = footer()
        self.maximumVisibleRows = maximumVisibleRows
        self.fillsAvailableHeight = fillsAvailableHeight
        self.automaticallyScrollsToLatest = automaticallyScrollsToLatest
        self.deleteSong = deleteSong
        self.moveSongs = moveSongs
        _displayedSongs = State(initialValue: songs)
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            List {
                ForEach(displayedSongs, id: \.stableID) { song in
                    SongRow(
                        song: song,
                        accessory: .handle,
                        reorderChanged: { value in
                            updateReorder(
                                of: song,
                                locationY: value.location.y
                            )
                        },
                        reorderEnded: finishReorder
                    )
                    .id(song.stableID)
                    .measuresSongRowCenter(id: song.stableID)
                    .contentShape(Rectangle())
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteSong(song)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                footer
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .listRowSpacing(rowSpacing)
            .contentMargins(.vertical, 0, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: fillsAvailableHeight ? nil : listHeight)
            .frame(maxHeight: fillsAvailableHeight ? .infinity : nil)
            .environment(\.defaultMinListRowHeight, rowHeight)
            .onPreferenceChange(SongRowCenterPreferenceKey.self) { centers in
                songRowCenters = centers
            }
            .onChange(of: songs) { oldSongs, newSongs in
                guard newSongs != displayedSongs else { return }
                displayedSongs = newSongs

                guard
                    automaticallyScrollsToLatest,
                    newSongs.count > oldSongs.count,
                    let latestSongID = newSongs.last?.stableID
                else {
                    return
                }

                Task { @MainActor in
                    await Task.yield()
                    withAnimation(.snappy) {
                        scrollProxy.scrollTo(latestSongID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var listHeight: CGFloat {
        guard !displayedSongs.isEmpty else { return 0 }
        let visibleRowCount = min(
            displayedSongs.count,
            maximumVisibleRows ?? displayedSongs.count
        )
        return CGFloat(visibleRowCount) * rowHeight
            + CGFloat(visibleRowCount - 1) * rowSpacing
    }

    private func updateReorder(
        of song: SetlistSong,
        locationY: CGFloat
    ) {
        guard let transition = reorderSession.transition(
            for: song,
            locationY: locationY,
            displayedSongs: displayedSongs,
            rowCenters: songRowCenters
        ) else {
            return
        }

        withAnimation(.snappy) {
            displayedSongs.move(
                fromOffsets: transition.offsets,
                toOffset: transition.destination
            )
        }
    }

    private func finishReorder() {
        guard let move = reorderSession.finish(
            displayedSongs: displayedSongs
        ) else {
            return
        }
        moveSongs(move.songs, move.offsets, move.destination)
    }
}

extension EditableSongList where Footer == EmptyView {
    init(
        songs: [SetlistSong],
        maximumVisibleRows: Int? = nil,
        fillsAvailableHeight: Bool = false,
        automaticallyScrollsToLatest: Bool = false,
        deleteSong: @escaping (SetlistSong) -> Void = { _ in },
        moveSongs: @escaping ([SetlistSong], IndexSet, Int) -> Void = { _, _, _ in }
    ) {
        self.init(
            songs: songs,
            maximumVisibleRows: maximumVisibleRows,
            fillsAvailableHeight: fillsAvailableHeight,
            automaticallyScrollsToLatest: automaticallyScrollsToLatest,
            deleteSong: deleteSong,
            moveSongs: moveSongs
        ) {
            EmptyView()
        }
    }
}

#Preview("Editable song list") {
    EditableSongList(songs: Array(SetlistSong.sampleSongs.prefix(5)))
        .padding()
        .background(SetlistColor.backgroundCanvas)
        .preferredColorScheme(.dark)
}
