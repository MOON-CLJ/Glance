import SwiftUI

struct ProjectTabBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(appState.projects.enumerated()), id: \.element.id) { index, project in
                    ProjectTab(
                        name: project.name,
                        isActive: index == appState.activeProjectIndex,
                        onSelect: { appState.activeProjectIndex = index },
                        onClose: { appState.closeProject(at: index) }
                    )
                }

                // 添加目录按钮
                Button(action: { appState.addFolder() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Add folder (Cmd+O)")

                Spacer()
            }
        }
        .frame(height: 32)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct ProjectTab: View {
    let name: String
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder.fill")
                .font(.system(size: 10))
                .foregroundColor(isActive ? .accentColor : .secondary)

            Text(name)
                .font(.system(size: 12))
                .lineLimit(1)

            if isHovering || isActive {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .cornerRadius(4)
        .onTapGesture { onSelect() }
        .onHover { isHovering = $0 }
    }
}
