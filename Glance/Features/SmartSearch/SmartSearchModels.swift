import Foundation

enum SmartSearchTab: String, CaseIterable {
    case quickSearch = "Quick Search"
    case deepResearch = "Deep Research"
}

enum QuickSearchState: Equatable {
    case idle
    case searching
    case results([ExaResult])
    case error(String)
}

enum DeepResearchState: Equatable {
    case idle
    case generatingSubQueries
    case searching(current: Int, total: Int)
    case synthesizing
    case saving
    case complete(ResearchFile)
    case error(String)
}

struct ResearchFile: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let query: String
    let date: Date
    let sourceCount: Int
    let fileName: String

    init(id: UUID = UUID(), query: String, date: Date = Date(), sourceCount: Int, fileName: String) {
        self.id = id
        self.query = query
        self.date = date
        self.sourceCount = sourceCount
        self.fileName = fileName
    }
}

struct SubQueryResponse: Codable {
    let queries: [String]
}
