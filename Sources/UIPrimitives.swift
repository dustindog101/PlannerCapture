import SwiftUI

struct AppearanceTokens {
    static let paneCornerRadius: CGFloat = 12
    static let panePadding: CGFloat = 12
    static let rowVerticalCompact: CGFloat = 2
    static let rowVerticalRegular: CGFloat = 6
}

struct LayoutPaneState {
    var showLeftPane: Bool = true
    var showRightPane: Bool = true
}

struct SelectionState {
    var selectedNavigationID: String?
    var selectedTaskID: String?
}

struct PaneContainer<Content: View>: View {
    let material: Material
    let content: Content

    init(material: Material, @ViewBuilder content: () -> Content) {
        self.material = material
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppearanceTokens.panePadding)
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: AppearanceTokens.paneCornerRadius, style: .continuous))
    }
}

struct SectionHeaderChip: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text("\(count)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
            Spacer()
        }
    }
}

struct StatusBadgeChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
    }
}
