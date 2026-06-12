import Foundation

enum MediaType: String, Codable, CaseIterable {
    case image
    case video
    case gif
    case file

    var icon: String {
        switch self {
        case .image: "photo"
        case .video: "video"
        case .gif: "play.rectangle"
        case .file: "doc"
        }
    }
}

struct MediaItem: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String
    let type: MediaType
    let dateAdded: Date
    let fileSize: Int64

    var fileURL: URL {
        FileStorageService.shared.directory.appendingPathComponent(fileName)
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    init(
        id: UUID = UUID(),
        fileName: String,
        type: MediaType,
        dateAdded: Date = Date(),
        fileSize: Int64 = 0
    ) {
        self.id = id
        self.fileName = fileName
        self.type = type
        self.dateAdded = dateAdded
        self.fileSize = fileSize
    }
}
