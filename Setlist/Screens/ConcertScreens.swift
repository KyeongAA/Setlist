import SwiftUI

enum ConcertToolbarMode {
    case detail
    case edit
    case complete
}

struct ConcertToolbar: ToolbarContent {
    let mode: ConcertToolbarMode
    var leadingAction: () -> Void = {}
    var trailingAction: () -> Void = {}

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        switch mode {
        case .detail, .complete:
            ToolbarItem(placement: .topBarLeading) {
                Button("뒤로", systemImage: "chevron.backward", action: leadingAction)
                    .labelStyle(.iconOnly)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(trailingTitle, action: trailingAction)
            }
        case .edit:
            ToolbarItem(placement: .cancellationAction) {
                Button("취소", action: leadingAction)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("완료", action: trailingAction)
            }
        }
    }

    private var trailingTitle: String {
        switch mode {
        case .detail: "편집"
        case .edit: "완료"
        case .complete: "저장"
        }
    }
}

struct ConcertDetailScreen: View {
    @State private var isSpotifyPresented = false

    var concertName = "index_00"
    var artist = "WOODZ"
    var photoData: Data?
    var placeholderType = 1
    var songs: [SetlistSong] = SetlistSong.sampleSongs
    var spotifyExportTracks: [SpotifyExportTrack] = []
    var goBack: () -> Void = {}
    var edit: () -> Void = {}
    var openSpotify: () -> Void = {}

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                SetlistColor.backgroundCanvas
                    .ignoresSafeArea()

                PosterOverlay(
                    photoData: photoData,
                    placeholderType: placeholderType
                )
                    .ignoresSafeArea(edges: [.top, .horizontal])

                ScrollView {
                    VStack(spacing: 0) {
                        HStack(alignment: .center, spacing: 0) {
                            VStack(alignment: .leading, spacing: SetlistSpacing.small) {
                                Text(concertName)
                                    .setlistTextStyle(.headingTitle)
                                    .foregroundStyle(SetlistColor.textPrimary)

                                Text(artist)
                                    .setlistTextStyle(.headingSection)
                                    .foregroundStyle(SetlistColor.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            SpotifyButton(action: presentSpotifyExport)
                        }
                        .padding(.top, 201)

                        LazyVStack(spacing: SetlistSpacing.small) {
                            ForEach(songs) { song in
                                SongRow(song: song)
                            }
                        }
                        .padding(.top, 28)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, SetlistSpacing.medium)
                    .padding(.top, SetlistSpacing.xs)
                    .padding(.bottom, SetlistSpacing.large)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ConcertToolbar(
                    mode: .detail,
                    leadingAction: goBack,
                    trailingAction: edit
                )
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .spotifyExportSheet(
            isPresented: $isSpotifyPresented,
            playlistName: playlistName,
            tracks: spotifyExportTracks
        )
    }

    private var playlistName: String {
        artist.isEmpty ? concertName : "\(concertName)  · \(artist)"
    }

    private func presentSpotifyExport() {
        isSpotifyPresented = true
        openSpotify()
    }
}

struct ConcertEditScreen: View {
    @State private var concertName: String
    @State private var artist: String
    @State private var isSearchPresented = false

    var photoData: Data?
    var placeholderType: Int
    var songs: [SetlistSong] = SetlistSong.sampleSongs
    var cancel: () -> Void = {}
    var complete: (String, String) -> Void = { _, _ in }
    var savePhoto: (Data) -> Void = { _ in }
    var addSong: () -> Void = {}
    var addSpotifyTrack: (SpotifyTrack) -> Void = { _ in }
    var deleteSong: (SetlistSong) -> Void = { _ in }
    var moveSongs: ([SetlistSong], IndexSet, Int) -> Void = { _, _, _ in }

    init(
        concertName: String = "",
        artist: String = "",
        photoData: Data? = nil,
        placeholderType: Int = 1,
        songs: [SetlistSong] = SetlistSong.sampleSongs,
        cancel: @escaping () -> Void = {},
        complete: @escaping (String, String) -> Void = { _, _ in },
        savePhoto: @escaping (Data) -> Void = { _ in },
        addSong: @escaping () -> Void = {},
        addSpotifyTrack: @escaping (SpotifyTrack) -> Void = { _ in },
        deleteSong: @escaping (SetlistSong) -> Void = { _ in },
        moveSongs: @escaping ([SetlistSong], IndexSet, Int) -> Void = { _, _, _ in }
    ) {
        _concertName = State(initialValue: concertName)
        _artist = State(initialValue: artist)
        self.photoData = photoData
        self.placeholderType = placeholderType
        self.songs = songs
        self.cancel = cancel
        self.complete = complete
        self.savePhoto = savePhoto
        self.addSong = addSong
        self.addSpotifyTrack = addSpotifyTrack
        self.deleteSong = deleteSong
        self.moveSongs = moveSongs
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                SetlistColor.backgroundCanvas
                    .ignoresSafeArea()

                PosterOverlay(
                    photoData: photoData,
                    placeholderType: placeholderType
                )
                    .ignoresSafeArea(edges: [.top, .horizontal])

                ScrollView {
                    VStack(spacing: 0) {
                        PhotoPickerButton(title: "사진 수정", savePhoto: savePhoto)
                            .padding(.top, 126)

                        VStack(spacing: SetlistSpacing.xs) {
                            FormTextField(
                                text: $concertName,
                                placeholder: "공연명",
                                state: .normal
                            )
                            FormTextField(
                                text: $artist,
                                placeholder: "아티스트 또는 설명",
                                state: .normal
                            )
                        }
                        .padding(.top, SetlistSpacing.large)

                        EditableSongList(
                            songs: songs,
                            deleteSong: deleteSong,
                            moveSongs: moveSongs
                        )
                        .padding(.top, SetlistSpacing.large)

                        SmallButton(title: "곡 추가", showsPlus: true, action: presentSearch)
                            .padding(.top, SetlistSpacing.large)
                            .padding(.bottom, SetlistSpacing.large)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, SetlistSpacing.large)
                    .padding(.top, SetlistSpacing.xs)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ConcertToolbar(
                    mode: .edit,
                    leadingAction: cancel,
                    trailingAction: {
                        complete(concertName, artist)
                    }
                )
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .searchSheet(
            isPresented: $isSearchPresented,
            addSpotifyTrack: addSpotifyTrack
        )
    }

    private func presentSearch() {
        isSearchPresented = true
        addSong()
    }
}

enum ConcertCompleteMetadataState {
    case empty
    case filled
}

struct ConcertCompleteScreen: View {
    let metadataState: ConcertCompleteMetadataState
    @State private var concertName: String
    @State private var artist: String
    @State private var isSearchPresented = false

    var photoData: Data?
    var placeholderType: Int
    var songs: [SetlistSong] = SetlistSong.sampleSongs
    var recognitionGaps: [SetlistRecognitionGap] = []
    var goBack: () -> Void = {}
    var save: (String, String) -> Void = { _, _ in }
    var savePhoto: (Data) -> Void = { _ in }
    var addSong: () -> Void = {}
    var addSpotifyTrack: (SpotifyTrack) -> Void = { _ in }
    var deleteSong: (SetlistSong) -> Void = { _ in }
    var moveSongs: ([SetlistSong], IndexSet, Int) -> Void = { _, _, _ in }

    init(
        metadataState: ConcertCompleteMetadataState,
        concertName: String = "index_00",
        artist: String = "WOODZ",
        photoData: Data? = nil,
        placeholderType: Int = 1,
        songs: [SetlistSong] = SetlistSong.sampleSongs,
        recognitionGaps: [SetlistRecognitionGap] = [],
        goBack: @escaping () -> Void = {},
        save: @escaping (String, String) -> Void = { _, _ in },
        savePhoto: @escaping (Data) -> Void = { _ in },
        addSong: @escaping () -> Void = {},
        addSpotifyTrack: @escaping (SpotifyTrack) -> Void = { _ in },
        deleteSong: @escaping (SetlistSong) -> Void = { _ in },
        moveSongs: @escaping ([SetlistSong], IndexSet, Int) -> Void = { _, _, _ in }
    ) {
        self.metadataState = metadataState
        _concertName = State(initialValue: concertName)
        _artist = State(initialValue: artist)
        self.photoData = photoData
        self.placeholderType = placeholderType
        self.songs = songs
        self.recognitionGaps = recognitionGaps
        self.goBack = goBack
        self.save = save
        self.savePhoto = savePhoto
        self.addSong = addSong
        self.addSpotifyTrack = addSpotifyTrack
        self.deleteSong = deleteSong
        self.moveSongs = moveSongs
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                SetlistColor.backgroundCanvas
                    .ignoresSafeArea()

                PosterOverlay(
                    photoData: photoData,
                    placeholderType: placeholderType
                )
                    .ignoresSafeArea(edges: [.top, .horizontal])

                ScrollView {
                    VStack(spacing: 0) {
                        PhotoPickerButton(
                            title: photoData == nil ? "사진 추가" : "사진 수정",
                            savePhoto: savePhoto
                        )
                            .padding(.top, 126)

                        VStack(spacing: SetlistSpacing.xs) {
                            FormTextField(
                                text: $concertName,
                                placeholder: "공연명",
                                state: metadataState == .filled ? .completed : .normal
                            )
                            FormTextField(
                                text: $artist,
                                placeholder: "아티스트 또는 설명",
                                state: metadataState == .filled ? .completed : .normal
                            )
                        }
                        .padding(.top, SetlistSpacing.large)

                        if recognitionGaps.isEmpty {
                            EditableSongList(
                                songs: songs,
                                deleteSong: deleteSong,
                                moveSongs: moveSongs
                            )
                            .padding(.top, 28)
                        } else {
                            Text("확인이 필요한 구간 \(recognitionGaps.count)개")
                                .setlistTextStyle(.utilityStatus)
                                .foregroundStyle(SetlistColor.semanticWarningContent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 28)

                            EditableSongList(
                                songs: Array(songs.prefix(3)),
                                deleteSong: deleteSong,
                                moveSongs: moveSongs
                            )
                            .padding(.top, SetlistSpacing.medium)

                            VStack(spacing: SetlistSpacing.small) {
                                ForEach(recognitionGaps) { gap in
                                    MissingCard(
                                        startTime: gap.startTime,
                                        endTime: gap.endTime,
                                        action: presentSearch
                                    )
                                }
                            }
                            .padding(.top, SetlistSpacing.large)

                            EditableSongList(
                                songs: Array(songs.dropFirst(3)),
                                deleteSong: deleteSong,
                                moveSongs: moveSongs
                            )
                            .padding(.top, SetlistSpacing.large)
                        }

                        SmallButton(title: "곡 추가", showsPlus: true, action: presentSearch)
                            .padding(.top, SetlistSpacing.large)
                            .padding(.bottom, 78)
                    }
                    .padding(.horizontal, SetlistSpacing.large)
                    .padding(.top, SetlistSpacing.xs)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ConcertToolbar(
                    mode: .complete,
                    leadingAction: goBack,
                    trailingAction: {
                        save(concertName, artist)
                    }
                )
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .searchSheet(
            isPresented: $isSearchPresented,
            addSpotifyTrack: addSpotifyTrack
        )
    }

    private func presentSearch() {
        isSearchPresented = true
        addSong()
    }
}

#Preview("Concert · Detail") {
    ConcertDetailScreen()
        .environmentObject(SpotifySession())
}

#Preview("Concert · Edit") {
    ConcertEditScreen()
        .environmentObject(SpotifySession())
}

#Preview("Concert · Complete · Empty metadata") {
    ConcertCompleteScreen(metadataState: .empty)
        .environmentObject(SpotifySession())
}

#Preview("Concert · Complete · Filled metadata") {
    ConcertCompleteScreen(metadataState: .filled)
        .environmentObject(SpotifySession())
}
