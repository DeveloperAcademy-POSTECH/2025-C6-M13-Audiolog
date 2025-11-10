import Foundation
import SwiftData

@Model
final class Recording {
    var id: UUID
    //    var filePath: String
    var fileURL: URL
    var title: String
    var isTitleGenerated: Bool
    var duration: TimeInterval
    var createdAt: Date
    var weather: String?
    var tags: [String]?
    var dialog: String?
    var isFavorite: Bool = false
    var location: String?
    var bgmTitle: String?
    var bgmArtist: String?

    init(
        id: UUID = UUID(),
        fileURL: URL,
        title: String = "",
        isTitleGenerated: Bool = false,
        duration: TimeInterval,
        createdAt: Date = .now,
        weather: String? = nil,
        tags: [String]? = nil,
        dialog: String? = nil,
        isFavorite: Bool = false,
        location: String? = nil,
        bgmTitle: String? = nil,
        bgmArtist: String? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.title = title
        self.isTitleGenerated = isTitleGenerated
        self.duration = duration
        self.createdAt = createdAt
        self.weather = weather
        self.tags = tags
        self.dialog = dialog
        self.isFavorite = isFavorite
        self.location = location
        self.bgmTitle = bgmTitle
        self.bgmArtist = bgmArtist
    }
}

extension Recording {
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
