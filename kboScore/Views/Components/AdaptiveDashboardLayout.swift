import SwiftUI

private extension EnvironmentValues {
    @Entry var dashboardUsesColumns = false
}

/// Measure the current safe area, so folding and window resizing update the layout.
// TODO: Validate partially folded safe areas and vertical bars in the iPhone Duo simulator.
struct DashboardScrollView<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var maximumWidth: CGFloat = 1_120
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content
                    .frame(maxWidth: maximumWidth)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .environment(\.dashboardUsesColumns,
                         min(geometry.size.width, maximumWidth) >= 760 && !dynamicTypeSize.isAccessibilitySize)
        }
    }
}

/// AnyLayout preserves child state when the two columns become a single column.
struct DashboardColumns<Primary: View, Secondary: View>: View {
    @Environment(\.dashboardUsesColumns) private var usesColumns
    var allowsColumns = true
    var spacing: CGFloat = 18
    @ViewBuilder var primary: Primary
    @ViewBuilder var secondary: Secondary

    var body: some View {
        let layout = usesColumns && allowsColumns
            ? AnyLayout(HStackLayout(alignment: .top, spacing: spacing))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
        layout {
            primary.frame(maxWidth: .infinity, alignment: .topLeading)
            secondary.frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

#Preview("접힌 화면", traits: .fixedLayout(width: 390, height: 600)) {
    DashboardScrollView {
        DashboardColumns {
            Text("경기 점수").frame(height: 160).cardSurface()
        } secondary: {
            Text("시즌 기록").frame(height: 240).cardSurface()
        }
        .padding(22)
    }
}

#Preview("펼친 화면", traits: .fixedLayout(width: 900, height: 600)) {
    DashboardScrollView {
        DashboardColumns {
            Text("경기 점수").frame(height: 160).cardSurface()
        } secondary: {
            Text("시즌 기록").frame(height: 240).cardSurface()
        }
        .padding(22)
    }
}
