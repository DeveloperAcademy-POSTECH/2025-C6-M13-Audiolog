//
//  RecapView.swift
//  Audiolog
//
//  Created by Sean Cho on 11/5/25.
//

import SwiftData
import SwiftUI

struct RecapView: View {
    @Query private var recordings: [Recording]

    private var recordingCollections: [String] {
        var tagToRecordingIDs: [String: Set<ObjectIdentifier>] = [:]
        for recording in recordings {
            let uniqueTags = Set(recording.tags ?? [])
            let id = ObjectIdentifier(recording as AnyObject)
            for tag in uniqueTags {
                tagToRecordingIDs[tag, default: []].insert(id)
            }
        }

        let popularTags =
            tagToRecordingIDs
            .filter { $0.value.count >= 3 }
            .map { $0.key }
            .sorted()
        return popularTags
    }

    var recapCategoryButtonWidth: CGFloat {
        (screenWidth - 60) / 2
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .foregroundColor(.sub)
                    .frame(width: 300, height: 300)
                    .cornerRadius(350)
                    .blur(radius: 160)
                    .offset(x: -100, y: -320)
                
                ScrollView(.vertical, showsIndicators: false) {
                    let columns = [
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20),
                    ]
                    LazyVGrid(columns: columns, spacing: 20) {
                        let thumbnailName = "Thumbnail0"
                        
                        NavigationLink {
                            let favoriteRecordings = recordings.filter {
                                ($0 as Recording).isFavorite == true
                            }
                            PlaylistView(
                                recordings: favoriteRecordings,
                                thumbnailName: thumbnailName,
                                playlistTitle: "즐겨찾기"
                            )
                        } label: {
                            ZStack {
                                Image(thumbnailName)
                                    .resizable()
                                    .cornerRadius(20)
                                    .frame(
                                        width: recapCategoryButtonWidth,
                                        height: recapCategoryButtonWidth
                                    )
                                Text("즐겨찾기")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        ForEach(recordingCollections, id: \.self) { tag in
                            let asciiSum = tag.unicodeScalars.map { Int($0.value) }.reduce(0, +)
                            let thumbnailName = "Thumbnail\(((asciiSum % 7) + 1))"
                            NavigationLink {
                                let filteredRecordings = recordings.filter {
                                    recording in
                                    guard let tags = recording.tags else {
                                        return false
                                    }
                                    return tags.contains(tag)
                                }
                                PlaylistView(
                                    recordings: filteredRecordings,
                                    thumbnailName: thumbnailName,
                                    playlistTitle: tag
                                )
                            } label: {
                                ZStack {
                                    Image(thumbnailName)
                                        .resizable()
                                        .cornerRadius(20)
                                        .frame(
                                            width: recapCategoryButtonWidth,
                                            height: recapCategoryButtonWidth
                                        )
                                    Text(tag)
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .overlay(alignment: .bottom) {
                    VStack {
                        Spacer()
                        MiniPlayerView()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 20)
                    .transition(.opacity)
                }
                .navigationTitle("추천 로그")
                .frame(maxWidth: .infinity)
            }
        }
        .background(.bg1)
    }
}
