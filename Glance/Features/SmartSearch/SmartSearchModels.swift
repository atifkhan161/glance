import Foundation

enum QuickSearchState: Equatable {
    case idle
    case searching
    case results([ExaResult])
    case error(String)
}
