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
    @State private var isPresentingPlayerSheet: Bool = false

    var body: some View {
        TabView(selection: $currentTab) {
            Tab(
                "Record",
                systemImage: "microphone",
                value: "Record"
            ) {
                RecordView()
            }

            Tab(
                "Archive",
                systemImage: "rectangle.split.2x2.fill",
                value: "Archive"
            ) {
                ArchiveView()
            }

            Tab(
                "Recap",
                systemImage: "star.fill",
                value: "Recap"
            ) {
                RecapView()
            }

            Tab(
                "Search",
                systemImage: "magnifyingglass",
                value: "Search",
                role: .search
            ) {
                SearchView()
            }
        }
        .tabViewBottomAccessory {
            BottomAccessory()
                .contentShape(Rectangle())
                .onTapGesture {
                    presentPlayerSheet()
                }
        }
        .sheet(isPresented: $isPresentingPlayerSheet) {
            AudioPlayerView()
        }
        .environment(audioPlayer)
    }

    private func presentPlayerSheet() {
        guard audioPlayer.current != nil else { return }
        isPresentingPlayerSheet = true
    }
}
