import Foundation

struct FileSearchResult: Identifiable {
    let id = UUID()
    let path: String
    let relativePath: String

    var fileName: String {
        (path as NSString).lastPathComponent
    }
}

struct GrepSearchResult: Identifiable {
    let id = UUID()
    let path: String
    let relativePath: String
    let lineNumber: Int
    let lineContent: String
    let matchRanges: [Range<String.Index>]

    var fileName: String {
        (path as NSString).lastPathComponent
    }
}
