import SwiftUI
import UniformTypeIdentifiers

struct EditableSongList<Footer: View>: View {
    let songs: [SetlistSong]
    let footer: Footer
    var maximumVisibleRows: Int?
    var fillsAvailableHeight: Bool
    var automaticallyScrollsToLatest: Bool
    var deleteSong: (SetlistSong) -> Void = { _ in }
    var moveSongs: ([SetlistSong], IndexSet, Int) -> Void = { _, _, _ in }

    @State private var displayedSongs: [SetlistSong]
    @State private var draggingSong: SetlistSong?

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
                        dragProvider: {
                            draggingSong = song
                            return NSItemProvider(
                                object: dragIdentifier(for: song) as NSString
                            )
                        }
                    )
                    .id(song.stableID)
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

    private func dragIdentifier(for song: SetlistSong) -> String {
        song.storageID?.uuidString ?? song.stableID
    }

    private func commitMove(_ draggedSong: SetlistSong, finalIndex: Int) {
        guard
            let sourceIndex = songs.firstIndex(where: {
                $0.stableID == draggedSong.stableID
            }),
            sourceIndex != finalIndex
        else {
            return
        }

        let destination = finalIndex > sourceIndex ? finalIndex + 1 : finalIndex
        moveSongs(songs, IndexSet(integer: sourceIndex), destination)
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

struct SongReorderDropDelegate: DropDelegate {
    let targetSong: SetlistSong
    @Binding var displayedSongs: [SetlistSong]
    @Binding var draggingSong: SetlistSong?
    let commitMove: (SetlistSong, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard
            let draggingSong,
            draggingSong.stableID != targetSong.stableID,
            let sourceIndex = displayedSongs.firstIndex(where: {
                $0.stableID == draggingSong.stableID
            }),
            let targetIndex = displayedSongs.firstIndex(where: {
                $0.stableID == targetSong.stableID
            })
        else {
            return
        }

        withAnimation(.snappy) {
            displayedSongs.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard
            let draggingSong,
            let finalIndex = displayedSongs.firstIndex(where: {
                $0.stableID == draggingSong.stableID
            })
        else {
            return false
        }

        commitMove(draggingSong, finalIndex)
        self.draggingSong = nil
        return true
    }
}

#Preview("Editable song list") {
    EditableSongList(songs: Array(SetlistSong.sampleSongs.prefix(5)))
        .padding()
        .background(SetlistColor.backgroundCanvas)
        .preferredColorScheme(.dark)
}
