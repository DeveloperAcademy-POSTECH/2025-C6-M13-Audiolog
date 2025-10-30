//
//  AudiologView.swift
//  Audiolog
//
//  Created by Sean Cho on 10/27/25.
//

import SwiftData
import SwiftUI

struct AudiologView: View {
    @State private var audioPlayer = AudioPlayer()

    @State private var currentTab = "Record"
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var isPresentingPlayerSheet: Bool = false
    @State private var nowPlaying: Recording?

    var body: some View {
        TabView(selection: $currentTab) {
            Tab(
                "Record",
                systemImage: "microphone",
                value: "Record"
            ) {
                NavigationStack {
                    RecordView()
                }
            }

            Tab(
                "Archive",
                systemImage: "play.square.stack.fill",
                value: "Archive"
            ) {
                NavigationStack {
                    ArchiveView()
                }
            }

            Tab(
                "Search",
                systemImage: "magnifyingglass",
                value: "Search",
                role: .search
            ) {
                NavigationStack {
                    SearchView()
                }
                .searchable(text: $searchText, prompt: "Search")
                .searchFocused($isSearchFocused)
            }
        }
        .environment(audioPlayer)
    }
}
