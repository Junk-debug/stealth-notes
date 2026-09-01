import Foundation

struct Note: Identifiable, Equatable {
    var name: String
    var text: String
    var id: String { name }
}
