import Foundation
import SwiftUI

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
