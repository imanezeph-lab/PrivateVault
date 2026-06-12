import Foundation

struct Folder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    let dateCreated: Date

    init(id: UUID = UUID(), name: String, icon: String = "folder", dateCreated: Date = Date()) {
        self.id = id
        self.name = name
        self.icon = icon
        self.dateCreated = dateCreated
    }
}
