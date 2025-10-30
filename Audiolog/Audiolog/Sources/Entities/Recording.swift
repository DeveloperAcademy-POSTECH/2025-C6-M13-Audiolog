import Foundation
import SwiftData

@Model
final class Recording {
    /// Unique identifier for the recording.
    var id: UUID
    /// Title of the recording.
    var title: String
    /// File system path of the recording file.
    var filePath: String
    /// Duration of the recording in seconds.
    var duration: TimeInterval
    /// Date when the recording was created.
    var createdAt: Date

    /// The file URL constructed from the file path.
    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    /// Designated initializer for all properties.
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - title: Title of the recording.
    ///   - filePath: File system path to the recording.
    ///   - duration: Duration in seconds.
    ///   - createdAt: Creation date.
    init(
        id: UUID,
        title: String,
        filePath: String,
        duration: TimeInterval,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.filePath = filePath
        self.duration = duration
        self.createdAt = createdAt
    }

    /// Convenience initializer using a file URL and duration.
    /// - Parameters:
    ///   - fileURL: URL of the recording file.
    ///   - duration: Duration in seconds.
    ///   - title: Optional title, defaults to file name without extension.
    convenience init(fileURL: URL, duration: TimeInterval, title: String? = nil)
    {
        let now = Date()
        let title = now.formatted("MM월 dd일 HH시 mm분 EEEE")
        self.init(
            id: UUID(),
            title: title,
            filePath: fileURL.path,
            duration: duration,
            createdAt: now
        )
    }
}

extension Recording {
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
