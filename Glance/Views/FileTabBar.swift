import SwiftUI

struct FileTabBar: View {
    @ObservedObject var project: ProjectState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(project.openedFiles.enumerated()), id: \.offset) { index, filePath in
                    FileTab(
                        name: (filePath as NSString).lastPathComponent,
                        isActive: index == project.activeFileIndex,
                        onSelect: { project.activeFileIndex = index },
                        onClose: { project.closeFile(at: index) }
                    )
                }
                Spacer()
            }
        }
        .frame(height: 28)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct FileTab: View {
    let name: String
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .foregroundColor(isActive ? .primary : .secondary)

            if isHovering || isActive {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isActive ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .cornerRadius(3)
        .onTapGesture { onSelect() }
        .onHover { isHovering = $0 }
    }
}
