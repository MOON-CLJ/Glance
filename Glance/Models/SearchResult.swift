import Foundation
import SwiftUI

// MARK: - Search Options

enum CaseSensitivity {
    case smart        // --smart-case（默认：全小写忽略大小写，含大写则敏感）
    case sensitive    // --case-sensitive
    case insensitive  // --ignore-case
}

struct SearchOptions: Equatable {
    var caseSensitivity: CaseSensitivity = .smart
    var wholeWord: Bool = false
    var regex: Bool = false       // false = --fixed-strings（字面量匹配）
    var fileType: String = ""     // rg --type，如 "swift"、"go"
    var fileGlob: String = ""     // rg --glob，如 "*.swift"

    static func == (lhs: SearchOptions, rhs: SearchOptions) -> Bool {
        lhs.caseSensitivity == rhs.caseSensitivity &&
        lhs.wholeWord == rhs.wholeWord &&
        lhs.regex == rhs.regex &&
        lhs.fileType == rhs.fileType &&
        lhs.fileGlob == rhs.fileGlob
    }
}

extension CaseSensitivity: Equatable {}

// MARK: - Common file types for picker

struct FileTypeOption: Identifiable {
    let id: String   // rg --type value，空字符串表示 Any
    let label: String
}

let commonFileTypes: [FileTypeOption] = [
    FileTypeOption(id: "",         label: "Any"),
    FileTypeOption(id: "swift",    label: "Swift"),
    FileTypeOption(id: "go",       label: "Go"),
    FileTypeOption(id: "ts",       label: "TypeScript"),
    FileTypeOption(id: "js",       label: "JavaScript"),
    FileTypeOption(id: "py",       label: "Python"),
    FileTypeOption(id: "rust",     label: "Rust"),
    FileTypeOption(id: "java",     label: "Java"),
    FileTypeOption(id: "kotlin",   label: "Kotlin"),
    FileTypeOption(id: "cpp",      label: "C/C++"),
    FileTypeOption(id: "css",      label: "CSS"),
    FileTypeOption(id: "html",     label: "HTML"),
    FileTypeOption(id: "json",     label: "JSON"),
    FileTypeOption(id: "yaml",     label: "YAML"),
    FileTypeOption(id: "markdown", label: "Markdown"),
    FileTypeOption(id: "sh",       label: "Shell"),
    FileTypeOption(id: "ruby",     label: "Ruby"),
]

// MARK: - Result models

struct SearchResultBase {
    let path: String
    let relativePath: String

    var fileName: String {
        (path as NSString).lastPathComponent
    }
}

struct FileSearchResult: Identifiable, SearchResultProtocol {
    let id = UUID()
    let base: SearchResultBase

    var path: String { base.path }
    var relativePath: String { base.relativePath }
    var fileName: String { base.fileName }
}

struct GrepSearchResult: Identifiable, SearchResultProtocol {
    let id = UUID()
    let base: SearchResultBase
    let lineNumber: Int
    let lineContent: String

    var path: String { base.path }
    var relativePath: String { base.relativePath }
    var fileName: String { base.fileName }
}

protocol SearchResultProtocol {
    var path: String { get }
    var relativePath: String { get }
    var fileName: String { get }
}

enum SearchSelection {
    static func binding<T: Identifiable>(for results: [T], selectedIndex: Int, onSelect: @escaping (Int) -> Void) -> Binding<T.ID?> where T.ID: Hashable {
        Binding(
            get: { results.indices.contains(selectedIndex) ? results[selectedIndex].id : nil },
            set: { newId in
                if let idx = results.firstIndex(where: { $0.id == newId }) {
                    onSelect(idx)
                }
            }
        )
    }
}

@ViewBuilder
func searchField(_ placeholder: String, icon: String, query: Binding<String>, onSubmit: @escaping () -> Void) -> some View {
    HStack {
        Image(systemName: icon)
            .foregroundColor(.secondary)
        TextField(placeholder, text: query)
            .textFieldStyle(.plain)
            .font(.system(size: 16))
            .onSubmit { onSubmit() }
    }
    .padding(12)
    .background(Color(nsColor: .controlBackgroundColor))
}

extension View {
    func searchKeyboardHandling(selectedIndex: Binding<Int>, resultCount: Int, onClose: @escaping () -> Void) -> some View {
        self
            .onKeyPress(.upArrow) {
                if selectedIndex.wrappedValue > 0 { selectedIndex.wrappedValue -= 1 }
                return .handled
            }
            .onKeyPress(.downArrow) {
                if selectedIndex.wrappedValue < resultCount - 1 { selectedIndex.wrappedValue += 1 }
                return .handled
            }
            .onKeyPress(.escape) {
                onClose()
                return .handled
            }
    }
}
