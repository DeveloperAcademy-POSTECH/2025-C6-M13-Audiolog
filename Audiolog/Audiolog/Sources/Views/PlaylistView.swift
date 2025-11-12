//
//  PlaylistView.swift
//  Audiolog
//
//  Created by Sean Cho on 11/12/25.
//

import SwiftData
import SwiftUI

struct PlaylistView: View {
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext

    let recordings: [Recording]
    let thumbnailName: String
    let playlistTitle: String

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    HStack(spacing: 20) {
                        Image(thumbnailName)
                            .resizable()
                            .cornerRadius(15)
                            .frame(width: 80, height: 80)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(playlistTitle)
                                .font(.body.weight(.semibold))
                                .foregroundColor(.lbl1)

                            Text("\(recordings.count)개")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.lbl2)
                        }

                        Spacer()

                        Button {
                            audioPlayer.setPlaylist(recordings)
                            audioPlayer.load(recordings[0])
                            audioPlayer.play()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "play.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12)

                                Text("재생")
                                    .font(.footnote.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                        }
                        .frame(width: 71, height: 38)
                        .glassEffect(.regular.tint(.main))
                    }
                    .listRowBackground(
                        Rectangle().fill(.clear).frame(height: 80)
                    )
                    .listRowSeparator(.hidden)

                    ForEach(recordings) { item in
                        HStack {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(
                                        item.isTitleGenerated
                                            && !item.title.isEmpty
                                            ? item.title : "제목 생성중.."
                                    )
                                    .font(.callout)
                                    .foregroundStyle(
                                        item.isTitleGenerated ? .lbl1 : .lbl3
                                    )
                                    .lineLimit(1)

                                    HStack(spacing: 8) {
                                        Text(
                                            item.createdAt.formatted(
                                                "M월 d일 EEEE, a h:mm"
                                            )
                                        )
                                        Text("·")
                                        Text(item.formattedDuration)
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                audioPlayer.setPlaylist(recordings)
                                audioPlayer.load(item)
                                audioPlayer.play()
                            }

                            Button {
                                toggleFavorite(item)
                            } label: {
                                Image(
                                    uiImage: UIImage(
                                        named: item.isFavorite
                                            ? "FavoriteOn" : "FavoriteOff"
                                    )!
                                )
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.listBg)
                        )
                        .listRowSeparator(.hidden)
                        .padding(5)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                toggleFavorite(item)
                            } label: {
                                VStack {
                                    Image(
                                        systemName: item.isFavorite
                                            ? "star.slash" : "star.fill"
                                    )
                                    Text(item.isFavorite ? "해제" : "즐겨찾기")
                                }
                            }
                            .tint(.main)
                        }
                        .tag(item.id)
                    }
                }
                .padding(.horizontal, 20)
                .listStyle(.plain)
                .listRowSpacing(10)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
        .background(.bg1)
    }

    private func toggleFavorite(_ item: Recording) {
        item.isFavorite.toggle()
        do { try modelContext.save() } catch {
            logger.log(
                "[ArchiveView] favorite save failed: \(String(describing: error))"
            )
        }
    }
}
