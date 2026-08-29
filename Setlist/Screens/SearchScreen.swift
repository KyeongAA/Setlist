import SwiftUI

enum SetlistSearchScreenState {
    case recent
    case focused
    case results
}

struct SearchScreen: View {
    @State private var state: SetlistSearchScreenState
    @State private var query: String
    @State private var tracks: [SpotifyTrack]
    @State private var recentQueries: [String] = []
    @State private var nextOffset = 0
    @State private var canLoadMore = false
    @State private var isLoadingMore = false
    @State private var visibleLastTrackID: String?
    @State private var searchTask: Task<Void, Never>?

    let searchTracks: (String, Int, Int) async throws -> [SpotifyTrack]
    var addSpotifyTrack: (SpotifyTrack) -> Void = { _ in }

    private let recentSearchHistory = RecentSearchHistory()
    private let pageSize = 8

    init(
        state: SetlistSearchScreenState = .recent,
        query: String = "",
        tracks: [SpotifyTrack] = [],
        searchTracks: @escaping (String, Int, Int) async throws -> [SpotifyTrack] = { _, _, _ in [] },
        addSpotifyTrack: @escaping (SpotifyTrack) -> Void = { _ in }
    ) {
        _state = State(initialValue: state)
        _query = State(initialValue: query)
        _tracks = State(initialValue: tracks)
        self.searchTracks = searchTracks
        self.addSpotifyTrack = addSpotifyTrack
    }

    var body: some View {
        ZStack {
            SetlistColor.backgroundCanvas
                .ignoresSafeArea()

            switch state {
            case .recent:
                recentContent
            case .focused:
                focusedContent
            case .results:
                resultsContent
            }
        }
        .onAppear {
            recentQueries = recentSearchHistory.load()
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            SheetHandle()

            Text("곡 추가")
                .setlistTextStyle(.headingSection)
                .foregroundStyle(SetlistColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, SetlistSpacing.large)
        }
        .padding(.horizontal, SetlistSpacing.large)
        .padding(.top, SetlistSpacing.small)
    }

    private var recentContent: some View {
        VStack(spacing: 0) {
            sheetHeader

            searchBar(state: .normal)
                .padding(.top, SetlistSpacing.small)

            Text("최근 검색")
                .setlistTextStyle(.utilityStatus)
                .foregroundStyle(SetlistColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SetlistSpacing.large)
                .padding(.top, 38)

            if !recentQueries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: SetlistSpacing.small) {
                        ForEach(recentQueries, id: \.self) { recentQuery in
                            Chip(title: recentQuery) {
                                query = recentQuery
                                submitSearch(recentQuery)
                            }
                        }
                    }
                    .padding(.horizontal, SetlistSpacing.medium)
                }
                .frame(height: 36)
                .padding(.top, SetlistSpacing.small)
            }

            Spacer(minLength: 0)
        }
    }

    private var focusedContent: some View {
        VStack(spacing: 0) {
            searchBar(state: .focused)
                .padding(.top, 80)

            Text("셋리스트에 곡을 직접 추가해보세요")
                .setlistTextStyle(.utilityStatus)
                .foregroundStyle(SetlistColor.textTertiary)
                .padding(.top, SetlistMargin.extraLarge)

            Spacer(minLength: 0)
        }
    }

    private var resultsContent: some View {
        VStack(spacing: 0) {
            sheetHeader

            searchBar(state: .filled)
                .padding(.top, SetlistSpacing.small)

            Text("검색 결과 \(tracks.count)곡")
                .setlistTextStyle(.utilityStatus)
                .foregroundStyle(SetlistColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SetlistSpacing.large)
                .padding(.top, SetlistSpacing.large)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        SongRow(
                            song: SetlistSong(
                                id: index + 1,
                                title: track.name,
                                artist: track.artistName
                            ),
                            accessory: .add,
                            action: {
                                recordRecentSearch(query)
                                addSpotifyTrack(track)
                            }
                        )
                        .onAppear {
                            if track.id == tracks.last?.id {
                                visibleLastTrackID = track.id
                            }
                        }
                        .onDisappear {
                            if visibleLastTrackID == track.id {
                                visibleLastTrackID = nil
                            }
                        }
                    }
                }
                .padding(.horizontal, SetlistSpacing.large)
                .padding(.top, SetlistSpacing.xs)
            }
            .scrollIndicators(.hidden)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        guard value.translation.height < -12 else { return }
                        Task {
                            await loadNextPageIfNeeded()
                        }
                    }
            )
        }
    }

    private func searchBar(state: SearchBarState) -> some View {
        SearchBar(
            text: $query,
            state: state,
            clearAction: {
                searchTask?.cancel()
                tracks = []
                self.state = .focused
            },
            focusChanged: { isFocused in
                if query.isEmpty {
                    self.state = isFocused ? .focused : .recent
                }
            },
            submit: {
                submitSearch(query)
            }
        )
    }

    private func submitSearch(_ submittedQuery: String) {
        let trimmedQuery = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        query = trimmedQuery
        recordRecentSearch(trimmedQuery)
        searchTask?.cancel()
        searchTask = Task {
            await search(trimmedQuery)
        }
    }

    private func recordRecentSearch(_ query: String) {
        recentQueries = recentSearchHistory.record(query)
    }

    private func search(_ submittedQuery: String) async {
        do {
            let results = try await searchTracks(submittedQuery, pageSize, 0)
            try Task.checkCancellation()
            guard query.trimmingCharacters(in: .whitespacesAndNewlines) == submittedQuery else {
                return
            }
            tracks = results
            nextOffset = results.count
            canLoadMore = results.count == pageSize
            isLoadingMore = false
            visibleLastTrackID = nil
            state = .results
        } catch is CancellationError {
            return
        } catch {
            guard query.trimmingCharacters(in: .whitespacesAndNewlines) == submittedQuery else {
                return
            }
            tracks = []
            nextOffset = 0
            canLoadMore = false
            isLoadingMore = false
            visibleLastTrackID = nil
            state = .results
        }
    }

    private func loadNextPageIfNeeded() async {
        guard visibleLastTrackID == tracks.last?.id,
              canLoadMore,
              !isLoadingMore else {
            return
        }

        let requestedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedQuery.isEmpty else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let results = try await searchTracks(requestedQuery, pageSize, nextOffset)
            try Task.checkCancellation()

            guard query.trimmingCharacters(in: .whitespacesAndNewlines) == requestedQuery else {
                return
            }

            nextOffset += results.count
            let existingIDs = Set(tracks.map(\.id))
            let newTracks = results.filter { !existingIDs.contains($0.id) }
            tracks.append(contentsOf: newTracks)
            canLoadMore = results.count == pageSize && !newTracks.isEmpty
        } catch is CancellationError {
            return
        } catch {
            canLoadMore = false
        }
    }
}

#Preview("Search · Recent") {
    SearchScreen(state: .recent)
}

#Preview("Search · Focused") {
    SearchScreen(state: .focused)
}

#Preview("Search · Results") {
    SearchScreen(
        state: .results,
        query: "에스파",
        tracks: SpotifyTrack.previewTracks
    )
}
