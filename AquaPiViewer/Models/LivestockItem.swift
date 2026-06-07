import Foundation

struct LivestockItem: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var count: Int
    var note: String
}

struct LivestockSummary {
    let speciesCount: Int
    let totalCount: Int

    var displayText: String {
        if speciesCount == 0 && totalCount == 0 {
            return "生体未登録"
        }

        return "生体 \(speciesCount)種 / \(totalCount)匹"
    }
}
