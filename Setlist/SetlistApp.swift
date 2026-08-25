//
//  SetlistApp.swift
//  Setlist
//
//  Created by Kyeonga Kim on 8/21/26.
//

import SwiftUI
import SwiftData

@main
struct SetlistApp: App {
    @StateObject private var spotifySession = SpotifySession()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ConcertRecord.self,
            SongRecord.self,
            RecognitionGapRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(spotifySession)
        }
        .modelContainer(sharedModelContainer)
    }
}
