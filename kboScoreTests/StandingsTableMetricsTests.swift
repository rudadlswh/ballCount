import CoreGraphics
import Testing
@testable import kboScore

@MainActor
struct StandingsTableMetricsTests {
    @Test(arguments: [CGFloat(1), 1.35, 1.8, 2.4])
    func wideTableFitsEveryColumnWithoutOverflow(textScale: CGFloat) {
        let minimumWidth = StandingsTableMetrics(textScale: textScale).width
        for width in [minimumWidth, minimumWidth + 1, 700 * textScale, 1_120 * textScale] {
            let metrics = StandingsTableMetrics(textScale: textScale, availableWidth: width)
            #expect(abs(metrics.width - width) < 0.001)
        }
    }

    @Test func narrowTableKeepsReadableColumnWidths() {
        let minimum = StandingsTableMetrics(textScale: 1)
        let compact = StandingsTableMetrics(textScale: 1, availableWidth: 320)
        #expect(compact.width == minimum.width)
        #expect(compact.width > compact.availableWidth)
    }
}
