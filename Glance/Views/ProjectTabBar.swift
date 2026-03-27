import SwiftUI

struct ProjectTabBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        WrappingHStack(alignment: .leading, spacing: .horizontal(4)) {
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
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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

            if isHovering {
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

// MARK: - WrappingHStack

enum WrappingHStackAlignment {
    case leading, center, trailing
}

enum WrappingHStackSpacing {
    case constant(CGFloat)
    case horizontal(CGFloat)
    case vertical(CGFloat)
    case both(horizontal: CGFloat, vertical: CGFloat)
}

struct WrappingHStack<Content: View>: View {
    let alignment: WrappingHStackAlignment
    let spacing: WrappingHStackSpacing
    let content: Content

    init(
        alignment: WrappingHStackAlignment = .leading,
        spacing: WrappingHStackSpacing = .constant(4),
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        WrappingHStackLayout(alignment: alignment, spacing: spacing) {
            content
        }
    }
}

private struct WrappingHStackLayout: Layout {
    let alignment: WrappingHStackAlignment
    let spacing: WrappingHStackSpacing

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, alignment: alignment, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, alignment: alignment, spacing: spacing)
        
        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: point.x + bounds.minX, y: point.y + bounds.minY), proposal: .unspecified)
        }
    }

    private struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, alignment: WrappingHStackAlignment, spacing: WrappingHStackSpacing) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            var lineWidths: [(startIndex: Int, endIndex: Int, width: CGFloat)] = []
            var currentLineStart = 0
            var currentLineWidth: CGFloat = 0
            
            let (hSpacing, vSpacing) = extractSpacing(spacing)

            for (index, subview) in subviews.enumerated() {
                let size = subview.sizeThatFits(.unspecified)
                
                if x > 0 && x + hSpacing + size.width > maxWidth {
                    lineWidths.append((currentLineStart, index - 1, currentLineWidth))
                    x = 0
                    y += lineHeight + vSpacing
                    lineHeight = 0
                    currentLineStart = index
                    currentLineWidth = 0
                }

                if x > 0 {
                    x += hSpacing
                }

                positions.append(CGPoint(x: x, y: y))
                x += size.width
                currentLineWidth += (positions.count > currentLineStart + 1 ? hSpacing : 0) + size.width
                lineHeight = max(lineHeight, size.height)
            }
            
            if currentLineStart < subviews.count {
                lineWidths.append((currentLineStart, subviews.count - 1, currentLineWidth))
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
            
            // Apply alignment
            for line in lineWidths {
                let lineWidth = line.width
                let offset: CGFloat
                
                switch alignment {
                case .leading:
                    offset = 0
                case .center:
                    offset = (maxWidth - lineWidth) / 2
                case .trailing:
                    offset = maxWidth - lineWidth
                }
                
                if offset > 0 {
                    for i in line.startIndex...line.endIndex {
                        positions[i].x += offset
                    }
                }
            }
            
            func extractSpacing(_ spacing: WrappingHStackSpacing) -> (horizontal: CGFloat, vertical: CGFloat) {
                switch spacing {
                case .constant(let value):
                    return (value, value)
                case .horizontal(let value):
                    return (value, 4)
                case .vertical(let value):
                    return (4, value)
                case .both(let h, let v):
                    return (h, v)
                }
            }
        }
    }
}
