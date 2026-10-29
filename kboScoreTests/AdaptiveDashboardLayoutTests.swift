import SwiftUI
import Testing
import UIKit
@testable import kboScore

@MainActor
struct AdaptiveDashboardLayoutTests {
    @Test func resizingPreservesChildrenAndLargeTextUsesOneColumn() async throws {
        let probe = LayoutProbe()
        let host = UIHostingController(rootView: content(probe: probe, textSize: .large))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let container = UIViewController()
        container.addChild(host)
        container.view.addSubview(host.view)
        host.didMove(toParent: container)
        window.rootViewController = container
        window.isHidden = false
        defer { window.isHidden = true }

        try await resize(host, to: 390) { probe.hasFrames && probe.secondary.minY >= probe.primary.maxY }
        let identities = probe.identities
        #expect(identities.count == 2)

        try await resize(host, to: 900) { probe.hasFrames && probe.secondary.minX >= probe.primary.maxX }
        #expect(abs(probe.primary.minY - probe.secondary.minY) < 1)
        #expect(probe.identities == identities)

        try await resize(host, to: 1_400) {
            probe.hasFrames && probe.primary.width > 500 && probe.secondary.minX >= probe.primary.maxX
        }
        #expect(probe.secondary.maxX - probe.primary.minX <= 1_120)

        try await resize(host, to: 390) { probe.hasFrames && probe.secondary.minY >= probe.primary.maxY }
        #expect(probe.identities == identities)

        host.rootView = content(probe: probe, textSize: .accessibility3)
        try await resize(host, to: 900) {
            probe.hasFrames && probe.primary.width > 700 && probe.secondary.minY >= probe.primary.maxY
        }
        #expect(probe.identities == identities)
    }

    private func content(probe: LayoutProbe, textSize: DynamicTypeSize) -> some View {
        DashboardScrollView {
            DashboardColumns {
                ProbeColumn(name: "primary", probe: probe)
            } secondary: {
                ProbeColumn(name: "secondary", probe: probe)
            }
            .padding(22)
        }
        .coordinateSpace(name: "dashboard")
        .environment(\.dynamicTypeSize, textSize)
    }

    private func resize<Content: View>(
        _ host: UIHostingController<Content>, to width: CGFloat, until isReady: () -> Bool
    ) async throws {
        host.view.frame = CGRect(x: 0, y: 0, width: width, height: 800)
        for _ in 0..<50 {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(20))
            if isReady() { return }
        }
        Issue.record("대시보드가 너비 \(width)에 맞게 배치되지 않았습니다.")
    }
}

@MainActor
private final class LayoutProbe {
    var primary: CGRect = .null
    var secondary: CGRect = .null
    var identities: [String: UUID] = [:]
    var hasFrames: Bool { !primary.isNull && !secondary.isNull }
}

private struct ProbeColumn: View {
    let name: String
    let probe: LayoutProbe
    @State private var identity = UUID()

    var body: some View {
        Text(name)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("dashboard")) } action: { frame in
                probe.identities[name] = identity
                if name == "primary" { probe.primary = frame } else { probe.secondary = frame }
            }
    }
}
