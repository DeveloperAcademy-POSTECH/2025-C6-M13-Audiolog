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
                "Recap",
                systemImage: "star.fill",
                value: "Recap"
            ) {
                NavigationStack {
                    RecapView()
                }
            }
            
            Tab(
                "Search",
                systemImage: "magnifyingglass",
                value: "Search",
                role: .search
            ) {
                NavigationStack {
                    SearchView(searchQuery: searchText)
                }
                .searchable(text: $searchText, prompt: "Search")
                .searchFocused($isSearchFocused)
            }
        }
        .tabViewBottomAccessory {
            BottomAccessory()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard audioPlayer.current != nil else { return }
                    isPresentingPlayerSheet = true
                }
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onEnded { value in
                            if value.translation.height < -20 {
                                guard audioPlayer.current != nil else { return }
                                isPresentingPlayerSheet = true
                            }
                        }
                )
        }
        .sheet(isPresented: $isPresentingPlayerSheet) {
            AudioPlayerView()
        }
        .environment(audioPlayer)
    }
}
