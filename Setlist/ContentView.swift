import SwiftUI
import SwiftData

private enum SetlistAppDestination: Equatable {
    case home
    case complete(UUID)
    case detail(UUID)
    case edit(UUID)
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ConcertRecord.eventDate, order: .reverse)
    private var concerts: [ConcertRecord]

    @StateObject private var recognizer = ShazamRecognitionService()
    @StateObject private var liveActivityManager = RecognitionLiveActivityManager()
    @State private var destination: SetlistAppDestination = .home
    @State private var presentedRecognitionID: UUID?
    @State private var didRestoreRecording = false

    var body: some View {
        screen
            .sheet(
                isPresented: recognitionSheetBinding,
                onDismiss: persistActiveRecognitionDuration
            ) {
                recognitionSheet
            }
            .onChange(of: recognizer.latestMatch) { _, match in
                guard let match, let recordingConcert else { return }
                let recognizedSongNumber = recordingConcert.orderedSongs.count + 1
                guard addRecognizedTrack(match, to: recordingConcert) else { return }
                if let gap = recognizer.confirmAcceptedMatch(at: match.recognitionTime) {
                    addRecognitionGap(gap, to: recordingConcert)
                }
                liveActivityManager.recognized(
                    songNumber: recognizedSongNumber,
                    title: match.title,
                    artist: match.artistName
                )
            }
            .onChange(of: recognizer.state) { _, state in
                synchronizeLiveActivity(with: state)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase != .active else { return }
                synchronizeLiveActivity(
                    with: recognizer.state,
                    allowsStarting: true
                )
            }
            .task {
                RecognitionControlBridge.shared.install { [weak recognizer] shouldListen in
                    await recognizer?.setListening(shouldListen)
                }
                restoreRecordingIfNeeded()
            }
    }

    @ViewBuilder
    private var screen: some View {
        switch destination {
        case .home:
            homeScreen

        case let .complete(concertID):
            if let concert = concert(withID: concertID) {
                ConcertCompleteScreen(
                    metadataState: metadataState(for: concert),
                    concertName: concert.title,
                    artist: concert.artistDescription,
                    photoData: concert.photoData,
                    placeholderType: concert.placeholderPosterType,
                    songs: concert.orderedSongs.map { SetlistSong(record: $0) },
                    recognitionGaps: recognitionTimelineGaps(for: concert),
                    goBack: {
                        destination = .home
                        presentedRecognitionID = concertID
                    },
                    save: { title, artist in
                        saveCompletedConcert(
                            concert,
                            title: title,
                            artist: artist
                        )
                    },
                    savePhoto: { data in
                        savePosterPhoto(data, to: concert)
                    },
                    addSpotifyTrack: { track in
                        addSpotifyTrack(track, to: concert)
                    },
                    deleteSong: { song in
                        deleteSong(song, from: concert)
                    },
                    moveSongs: { visibleSongs, offsets, destination in
                        moveSongs(
                            visibleSongs,
                            from: offsets,
                            to: destination,
                            in: concert
                        )
                    }
                )
            } else {
                unavailableConcertFallback
            }

        case let .detail(concertID):
            if let concert = concert(withID: concertID) {
                ConcertDetailScreen(
                    concertName: concert.title,
                    artist: concert.artistDescription,
                    photoData: concert.photoData,
                    placeholderType: concert.placeholderPosterType,
                    songs: concert.orderedSongs.map { SetlistSong(record: $0) },
                    spotifyExportTracks: concert.orderedSongs.map {
                        SpotifyExportTrack(
                            id: $0.id,
                            title: $0.title,
                            artistName: $0.artistName,
                            spotifyURI: $0.spotifyURI,
                            isrc: $0.isrc
                        )
                    },
                    goBack: {
                        destination = .home
                    },
                    edit: {
                        destination = .edit(concertID)
                    }
                )
            } else {
                unavailableConcertFallback
            }

        case let .edit(concertID):
            if let concert = concert(withID: concertID) {
                ConcertEditScreen(
                    concertName: concert.title,
                    artist: concert.artistDescription,
                    photoData: concert.photoData,
                    placeholderType: concert.placeholderPosterType,
                    songs: concert.orderedSongs.map { SetlistSong(record: $0) },
                    cancel: {
                        destination = .detail(concertID)
                    },
                    complete: { title, artist in
                        updateConcert(concert, title: title, artist: artist)
                    },
                    savePhoto: { data in
                        savePosterPhoto(data, to: concert)
                    },
                    addSpotifyTrack: { track in
                        addSpotifyTrack(track, to: concert)
                    },
                    deleteSong: { song in
                        deleteSong(song, from: concert)
                    },
                    moveSongs: { visibleSongs, offsets, destination in
                        moveSongs(
                            visibleSongs,
                            from: offsets,
                            to: destination,
                            in: concert
                        )
                    }
                )
            } else {
                unavailableConcertFallback
            }
        }
    }

    private var homeScreen: some View {
        HomeScreen(
            state: savedConcerts.isEmpty ? .empty : .recorded,
            concerts: savedConcerts.map { SetlistConcert(record: $0) },
            activeRecognitionState: activeMiniBarState,
            startRecognition: startRecognition,
            toggleRecognition: toggleActiveRecognition,
            openRecognition: openOrStartRecognition,
            openConcert: { concert in
                destination = .detail(concert.id)
            },
            deleteConcert: { concert in
                deleteConcert(concert)
            }
        )
    }

    @ViewBuilder
    private var recognitionSheet: some View {
        if
            let concertID = presentedRecognitionID,
            let concert = concert(withID: concertID)
        {
            RecognitionScreen(
                recognizer: recognizer,
                initialRecognitionDuration: concert.recognitionDuration,
                songs: concert.orderedSongs.map { SetlistSong(record: $0) },
                recognitionGaps: recognitionTimelineGaps(for: concert),
                addSpotifyTrack: { track in
                    addSpotifyTrack(track, to: concert)
                },
                deleteSong: { song in
                    deleteSong(song, from: concert)
                },
                moveSongs: { visibleSongs, offsets, destination in
                    moveSongs(
                        visibleSongs,
                        from: offsets,
                        to: destination,
                        in: concert
                    )
                },
                recognizedGap: { gap in
                    addRecognitionGap(gap, to: concert)
                },
                updateRecognitionDuration: { duration in
                    updateRecognitionDuration(duration, in: concert)
                },
                endRecognition: {
                    presentedRecognitionID = nil
                    destination = .complete(concertID)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }

    private var unavailableConcertFallback: some View {
        homeScreen
    }

    private var savedConcerts: [ConcertRecord] {
        concerts.filter { $0.status != .recording }
    }

    private var recordingConcert: ConcertRecord? {
        concerts.first { $0.status == .recording }
    }

    private var recognitionSheetBinding: Binding<Bool> {
        Binding(
            get: { presentedRecognitionID != nil },
            set: { isPresented in
                if !isPresented {
                    presentedRecognitionID = nil
                }
            }
        )
    }

    private var activeMiniBarState: MiniBarState? {
        guard recordingConcert != nil else { return nil }

        switch recognizer.state {
        case .preparing, .listening, .recovering:
            return .listening
        case .idle, .paused, .interrupted, .microphonePermissionDenied, .failed:
            return .paused
        }
    }

    private func concert(withID id: UUID) -> ConcertRecord? {
        concerts.first { $0.id == id }
    }

    private func metadataState(for concert: ConcertRecord) -> ConcertCompleteMetadataState {
        concert.title.isEmpty && concert.artistDescription.isEmpty ? .empty : .filled
    }

    private func restoreRecordingIfNeeded() {
        guard !didRestoreRecording else { return }
        didRestoreRecording = true

        if let recordingConcert {
            presentedRecognitionID = recordingConcert.id
        }
    }

    private func startRecognition() {
        if let recordingConcert {
            presentedRecognitionID = recordingConcert.id
            return
        }

        do {
            let concert = try ConcertStore(modelContext: modelContext).createConcert()
            presentedRecognitionID = concert.id
        } catch {
            assertionFailure("Failed to create concert: \(error)")
        }
    }

    private func openOrStartRecognition() {
        startRecognition()
    }

    private func toggleActiveRecognition() {
        guard let recordingConcert else { return }

        Task {
            await recognizer.toggleListening()
            updateRecognitionDuration(
                recognizer.elapsedDuration,
                in: recordingConcert
            )
        }
    }

    private func persistActiveRecognitionDuration() {
        guard let recordingConcert else { return }
        updateRecognitionDuration(
            recognizer.elapsedDuration,
            in: recordingConcert
        )
    }

    private func synchronizeLiveActivity(
        with state: ShazamRecognitionState,
        allowsStarting: Bool = false
    ) {
        guard let recordingConcert else {
            liveActivityManager.end()
            return
        }

        let nextSongNumber = recordingConcert.orderedSongs.count + 1

        switch state {
        case .listening:
            guard liveActivityManager.isActive || allowsStarting else { return }
            liveActivityManager.startOrResume(
                concertID: recordingConcert.id,
                nextSongNumber: nextSongNumber
            )
        case .paused, .interrupted:
            if liveActivityManager.isActive {
                liveActivityManager.pause(nextSongNumber: nextSongNumber)
            } else if allowsStarting {
                liveActivityManager.startPaused(
                    concertID: recordingConcert.id,
                    nextSongNumber: nextSongNumber
                )
            }
            updateRecognitionDuration(
                recognizer.elapsedDuration,
                in: recordingConcert
            )
        case .preparing, .recovering:
            break
        case .idle, .microphonePermissionDenied, .failed:
            liveActivityManager.end()
        }
    }

    private func saveCompletedConcert(
        _ concert: ConcertRecord,
        title: String,
        artist: String
    ) {
        concert.title = title
        concert.artistDescription = artist

        do {
            try ConcertStore(modelContext: modelContext).complete(concert)
            destination = .detail(concert.id)
        } catch {
            assertionFailure("Failed to complete concert: \(error)")
        }
    }

    private func deleteConcert(_ concertSummary: SetlistConcert) {
        guard let record = concert(withID: concertSummary.id) else { return }

        do {
            try ConcertStore(modelContext: modelContext).delete(record)
        } catch {
            assertionFailure("Failed to delete concert: \(error)")
        }
    }

    private func updateConcert(
        _ concert: ConcertRecord,
        title: String,
        artist: String
    ) {
        concert.title = title
        concert.artistDescription = artist

        do {
            try ConcertStore(modelContext: modelContext).save(concert)
            destination = .detail(concert.id)
        } catch {
            assertionFailure("Failed to update concert: \(error)")
        }
    }

    private func savePosterPhoto(
        _ data: Data,
        to concert: ConcertRecord
    ) {
        concert.photoData = data

        do {
            try ConcertStore(modelContext: modelContext).save(concert)
        } catch {
            assertionFailure("Failed to save poster photo: \(error)")
        }
    }

    private func addSpotifyTrack(
        _ track: SpotifyTrack,
        to concert: ConcertRecord
    ) {
        do {
            try ConcertStore(modelContext: modelContext).addSpotifySong(
                to: concert,
                title: track.name,
                artistName: track.artistName,
                albumName: track.album.name,
                artworkURLString: track.artworkURLString,
                durationMilliseconds: track.durationMilliseconds,
                isrc: track.externalIDs?.isrc,
                spotifyTrackID: track.id,
                spotifyURI: track.uri
            )
            refreshLiveActivitySongNumber(for: concert)
        } catch {
            assertionFailure("Failed to add Spotify track: \(error)")
        }
    }

    @discardableResult
    private func addRecognizedTrack(
        _ track: ShazamRecognizedTrack,
        to concert: ConcertRecord
    ) -> Bool {
        if let shazamID = track.shazamID,
           concert.orderedSongs.last?.shazamID == shazamID {
            return false
        }

        do {
            try ConcertStore(modelContext: modelContext).addRecognizedSong(
                to: concert,
                title: track.title,
                artistName: track.artistName,
                shazamID: track.shazamID,
                isrc: track.isrc,
                recognizedAt: track.recognizedAt,
                recognitionStartTime: nil,
                recognitionEndTime: track.recognitionTime
            )
            return true
        } catch {
            assertionFailure("Failed to add recognized track: \(error)")
            return false
        }
    }

    private func deleteSong(
        _ song: SetlistSong,
        from concert: ConcertRecord
    ) {
        guard
            let storageID = song.storageID,
            let record = concert.songs.first(where: { $0.id == storageID })
        else {
            return
        }

        do {
            try ConcertStore(modelContext: modelContext).remove(record, from: concert)
            refreshLiveActivitySongNumber(for: concert)
        } catch {
            assertionFailure("Failed to delete song: \(error)")
        }
    }

    private func moveSongs(
        _ visibleSongs: [SetlistSong],
        from offsets: IndexSet,
        to destination: Int,
        in concert: ConcertRecord
    ) {
        let visibleIDs = visibleSongs.compactMap(\.storageID)
        guard visibleIDs.count == visibleSongs.count else { return }

        var reorderedVisibleIDs = visibleIDs
        reorderedVisibleIDs.move(fromOffsets: offsets, toOffset: destination)

        let visibleIDSet = Set(visibleIDs)
        var reorderedConcertIDs = concert.orderedSongs.map(\.id)
        var replacementIndex = 0

        for index in reorderedConcertIDs.indices
        where visibleIDSet.contains(reorderedConcertIDs[index]) {
            reorderedConcertIDs[index] = reorderedVisibleIDs[replacementIndex]
            replacementIndex += 1
        }

        do {
            try ConcertStore(modelContext: modelContext).updateSongOrder(
                in: concert,
                orderedSongIDs: reorderedConcertIDs
            )
        } catch {
            assertionFailure("Failed to reorder songs: \(error)")
        }
    }

    private func addRecognitionGap(
        _ gap: ShazamRecognitionGap,
        to concert: ConcertRecord
    ) {
        do {
            try ConcertStore(modelContext: modelContext).addRecognitionGap(
                to: concert,
                startTime: gap.startTime,
                endTime: gap.endTime
            )
        } catch {
            assertionFailure("Failed to add recognition gap: \(error)")
        }
    }

    private func recognitionTimelineGaps(
        for concert: ConcertRecord
    ) -> [SetlistRecognitionGap] {
        let orderedSongs = concert.orderedSongs

        return concert.recognitionGaps
            .sorted { $0.startTime < $1.startTime }
            .map { gap in
                let followingSong = orderedSongs.first { song in
                    guard
                        song.source == .shazam,
                        let recognitionEndTime = song.recognitionEndTime
                    else {
                        return false
                    }
                    return recognitionEndTime >= gap.endTime
                }

                return SetlistRecognitionGap(
                    record: gap,
                    followingSongStorageID: followingSong?.id
                )
            }
    }

    private func updateRecognitionDuration(
        _ duration: TimeInterval,
        in concert: ConcertRecord
    ) {
        do {
            try ConcertStore(modelContext: modelContext).updateRecognitionDuration(
                duration,
                in: concert
            )
        } catch {
            assertionFailure("Failed to update recognition duration: \(error)")
        }
    }

    private func refreshLiveActivitySongNumber(for concert: ConcertRecord) {
        guard concert.status == .recording else { return }
        liveActivityManager.refresh(
            nextSongNumber: concert.orderedSongs.count + 1,
            isListening: recognizer.state == .listening
        )
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
        .modelContainer(
            for: [
                ConcertRecord.self,
                SongRecord.self,
                RecognitionGapRecord.self,
            ],
            inMemory: true
        )
        .environmentObject(SpotifySession())
}
