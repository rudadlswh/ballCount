//
//  BrandStyles.swift
//  kboScore
//  기능 설명: 팀 브랜드 색상과 경기장 테마 스타일을 SwiftUI에서 사용하도록 정의합니다.
//  사용자가 경기 상태와 설정을 빠르게 이해하도록 도메인 상태를 화면 구조에 직접 매핑합니다.
//  SwiftUI 상태 갱신, 접근성, 작은 화면 레이아웃에서 정보가 겹치지 않도록 표시 조건을 제한합니다.
//  TODO : 반복되는 화면 조각은 재사용 가능한 컴포넌트로 분리하고 미리보기 케이스를 보강합니다.
//
//  Created by Codex on 3/25/26.
//

import SwiftUI

// KBOLivePalette 열거형는 KBOLivePalette 타입의 역할과 값을 정의합니다.
enum KBOLivePalette {
    static let primary = StadiumPalette.app.tint
    static let secondary = StadiumPalette.app.tint
    static let background = StadiumPalette.app.background
    static let live = StadiumPalette.app.tint
    static let upcoming = Color.blue
    static let final = Color.secondary
    static let weather = Color.orange
    static let cancellation = Color.secondary
}

// 홈 유니폼의 로고색·포인트색을 공통 팔레트에서 가져옵니다.
enum DoosanPalette {
    static let primary = StadiumPalette.doosan.primary
    static let secondary = StadiumPalette.doosan.secondary
    static let tint = StadiumPalette.doosan.tint
    static let secondaryTint = StadiumPalette.doosan.secondaryTint
    static let statusRed = Color.red
    static let background = StadiumPalette.app.background
    static let sectionBackground = Color(.secondarySystemGroupedBackground)
    static let elevatedCard = Color(.secondarySystemGroupedBackground)
    static let elevatedCardStrong = Color(.tertiarySystemGroupedBackground)
    static let recessedSurface = Color(.tertiarySystemGroupedBackground)
    static let glassSurface = Color(.secondarySystemGroupedBackground)
    static let navigationSurface = Color(.systemBackground)
    static let tabBarSurface = Color(.systemBackground)
    static let tabBarSelectionSurface = Color(.secondarySystemBackground)
    static let bellControlSurface = Color(.secondarySystemBackground)
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let ghostBorder = Color(.separator)
    static let ambientShadow = Color.clear
    static let weather = Color.orange
}

extension AppModel {
    var favoriteStadiumPalette: StadiumPalette? {
        .app
    }

    var isStadiumFavoriteSelected: Bool {
        favoriteStadiumPalette != nil
    }
}

extension GameStatus {
    var tintColor: Color {
        switch self {
        case .live:
            KBOLivePalette.live
        case .upcoming:
            KBOLivePalette.upcoming
        case .final:
            KBOLivePalette.final
        case .rainDelay:
            KBOLivePalette.weather
        case .cancelled:
            KBOLivePalette.cancellation
        }
    }

    var cardBackgroundColor: Color {
        switch self {
        case .live:
            KBOLivePalette.live.opacity(0.08)
        case .upcoming:
            KBOLivePalette.upcoming.opacity(0.06)
        case .final:
            KBOLivePalette.final.opacity(0.06)
        case .rainDelay:
            KBOLivePalette.weather.opacity(0.10)
        case .cancelled:
            KBOLivePalette.cancellation.opacity(0.08)
        }
    }

    var doosanTintColor: Color {
        switch self {
        case .live:
            DoosanPalette.statusRed
        case .upcoming:
            DoosanPalette.secondaryTint
        case .final:
            DoosanPalette.textSecondary.opacity(0.86)
        case .rainDelay:
            DoosanPalette.weather
        case .cancelled:
            DoosanPalette.statusRed
        }
    }

    var doosanCardBackgroundColor: Color {
        switch self {
        case .live:
            DoosanPalette.elevatedCardStrong
        case .upcoming:
            DoosanPalette.elevatedCard
        case .final:
            DoosanPalette.sectionBackground
        case .rainDelay:
            DoosanPalette.elevatedCardStrong
        case .cancelled:
            DoosanPalette.sectionBackground
        }
    }

    // stadiumTintColor 메서드는 이 타입의 주요 동작을 수행합니다.
    func stadiumTintColor(_ palette: StadiumPalette) -> Color {
        tintColor
    }

    // stadiumCardBackgroundColor 메서드는 이 타입의 주요 동작을 수행합니다.
    func stadiumCardBackgroundColor(_ palette: StadiumPalette) -> Color {
        switch self {
        case .live:
            palette.elevatedCardStrong
        case .upcoming:
            palette.elevatedCard
        case .final:
            palette.sectionBackground
        case .rainDelay:
            palette.elevatedCardStrong
        case .cancelled:
            palette.sectionBackground
        }
    }
}

extension NotificationType {
    var tintColor: Color {
        switch self {
        case .scoreChange, .leadChange, .onBase, .inningChange:
            KBOLivePalette.primary
        case .gameStart:
            Color.gray
        case .gameEnd:
            Color(red: 0.59, green: 0.42, blue: 0.02)
        case .rainDelay:
            KBOLivePalette.live
        }
    }

    var doosanTintColor: Color {
        switch self {
        case .scoreChange, .leadChange, .onBase, .inningChange:
            DoosanPalette.tint
        case .gameStart:
            DoosanPalette.secondaryTint
        case .gameEnd:
            DoosanPalette.textSecondary
        case .rainDelay:
            DoosanPalette.weather
        }
    }

    // stadiumTintColor 메서드는 이 타입의 주요 동작을 수행합니다.
    func stadiumTintColor(_ palette: StadiumPalette) -> Color {
        switch self {
        case .scoreChange, .leadChange, .onBase, .inningChange:
            palette.tint
        case .gameStart:
            palette.secondaryTint
        case .gameEnd:
            palette.textSecondary
        case .rainDelay:
            palette.weather
        }
    }

    var systemImage: String {
        switch self {
        case .scoreChange:
            "chart.line.uptrend.xyaxis"
        case .onBase:
            "figure.baseball"
        case .gameStart:
            "play.circle.fill"
        case .leadChange:
            "arrow.left.arrow.right.circle.fill"
        case .gameEnd:
            "flag.fill"
        case .inningChange:
            "arrow.triangle.2.circlepath.circle.fill"
        case .rainDelay:
            "cloud.rain.fill"
        }
    }
}

// CardSurface 구조체는 CardSurface 타입의 역할과 값을 정의합니다.
struct CardSurface: ViewModifier {
    let padding: CGFloat
    let cornerRadius: CGFloat
    let fillColor: Color?
    let showsGhostBorder: Bool
    let uniformPalette: StadiumPalette?

    // body 메서드는 SwiftUI 화면의 본문 구성을 반환합니다.
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(fillColor ?? StadiumPalette.app.elevatedCard,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if showsGhostBorder {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(StadiumPalette.app.ghostBorder, lineWidth: 1)
                }
            }
    }
}

// LG의 핀스트라이프는 낮은 불투명도로만 넣어 경기 정보가 먼저 보이게 합니다.
struct HomeUniformTexture: View {
    @Environment(\.colorScheme) private var colorScheme
    let palette: StadiumPalette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.primary.opacity(0.04), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            if palette.id == "lg", colorScheme == .light {
                Canvas { context, size in
                    var stripes = Path()
                    for x in stride(from: CGFloat(10), through: size.width, by: 18) {
                        stripes.move(to: CGPoint(x: x, y: 0))
                        stripes.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    context.stroke(stripes, with: .color(palette.secondaryTint.opacity(0.045)), lineWidth: 0.6)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func dashboardScreen() -> some View {
        background(StadiumPalette.app.background.ignoresSafeArea())
            .foregroundStyle(StadiumPalette.app.textPrimary)
            .tint(StadiumPalette.app.tint)
            .toolbar(.hidden, for: .navigationBar)
    }

    // cardSurface 메서드는 이 타입의 주요 동작을 수행합니다.
    func cardSurface(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 20,
        fillColor: Color? = nil,
        showsGhostBorder: Bool = false,
        uniformPalette: StadiumPalette? = nil
    ) -> some View {
        modifier(
            CardSurface(
                padding: padding,
                cornerRadius: cornerRadius,
                fillColor: fillColor,
                showsGhostBorder: showsGhostBorder,
                uniformPalette: uniformPalette
            )
        )
    }

    // doosanNavigationChrome 메서드는 이 타입의 주요 동작을 수행합니다.
    func doosanNavigationChrome(isEnabled: Bool) -> some View {
        modifier(DoosanNavigationChromeModifier(isEnabled: isEnabled))
    }

    // doosanInlineNavigationTitle 메서드는 이 타입의 주요 동작을 수행합니다.
    func doosanInlineNavigationTitle(isEnabled: Bool) -> some View {
        modifier(DoosanInlineNavigationTitleModifier(isEnabled: isEnabled))
    }

    // stadiumNavigationChrome 메서드는 이 타입의 주요 동작을 수행합니다.
    func stadiumNavigationChrome(_ palette: StadiumPalette?) -> some View {
        modifier(StadiumNavigationChromeModifier(palette: palette))
    }
}

struct AppScreenHeader: View {
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 30.0
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: titleSize, weight: .bold))
                    .foregroundStyle(StadiumPalette.app.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(StadiumPalette.app.textSecondary)
            }
            Spacer(minLength: 0)
            NotificationsToolbarButton()
        }
        .padding(.top, 6)
        .padding(.bottom, 4)

    }
}

struct FavoriteTeamBadge: View {
    let teamID: String?
    var body: some View {
        Text(teamID?.prefix(1).uppercased() ?? "B")
            .font(.system(size: 19, weight: .heavy))
            .foregroundStyle(Color(red: 243/255, green: 240/255, blue: 226/255))
            .frame(width: 34, height: 34)
            .background(Color(red: 16/255, green: 28/255, blue: 45/255), in: RoundedRectangle(cornerRadius: 11))
            .drawingGroup()
            .accessibilityHidden(true)
    }
}

struct AppSegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button {
                    selection = option.0
                } label: {
                    Text(option.1)
                        .font(.subheadline.weight(selection == option.0 ? .semibold : .regular))
                        .foregroundStyle(selection == option.0 ? StadiumPalette.app.textPrimary : StadiumPalette.app.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(selection == option.0 ? StadiumPalette.app.elevatedCard : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option.0 ? .isSelected : [])
            }
        }
        .padding(4)
        .background(StadiumPalette.app.recessedSurface, in: Capsule())
    }
}

struct AppSectionTitle: View {
    let title: String
    var detail: String = ""
    var body: some View {
        HStack {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            Spacer()
            Text(detail).font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
        }
    }
}

struct AppMetric: View {
    let value: String
    let label: String
    var highlighted = false
    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(highlighted ? StadiumPalette.app.tint : StadiumPalette.app.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// StadiumNavigationChromeModifier 구조체는 SwiftUI 뷰 스타일과 동작을 재사용 가능한 형태로 적용합니다.
private struct StadiumNavigationChromeModifier: ViewModifier {
    let palette: StadiumPalette?

    // body 메서드는 SwiftUI 화면의 본문 구성을 반환합니다.
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.automatic, for: .navigationBar)
    }
}

// DoosanNavigationChromeModifier 구조체는 SwiftUI 뷰 스타일과 동작을 재사용 가능한 형태로 적용합니다.
private struct DoosanNavigationChromeModifier: ViewModifier {
    let isEnabled: Bool

    // body 메서드는 SwiftUI 화면의 본문 구성을 반환합니다.
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.automatic, for: .navigationBar)
    }
}

// DoosanInlineNavigationTitleModifier 구조체는 SwiftUI 뷰 스타일과 동작을 재사용 가능한 형태로 적용합니다.
private struct DoosanInlineNavigationTitleModifier: ViewModifier {
    let isEnabled: Bool

    // body 메서드는 SwiftUI 화면의 본문 구성을 반환합니다.
    func body(content: Content) -> some View {
        if isEnabled {
            content.navigationBarTitleDisplayMode(.inline)
        } else {
            content
        }
    }
}

// BasesDiamondView 구조체는 화면에 표시되는 SwiftUI 뷰 구성을 담당합니다.
struct BasesDiamondView: View {
    let bases: RunnerState

    var body: some View {
        ZStack {
            DiamondBase(isFilled: bases.second)
                .offset(y: -16)
            DiamondBase(isFilled: bases.first)
                .offset(x: 16)
            DiamondBase(isFilled: bases.third)
                .offset(x: -16)
            DiamondBase(isFilled: false)
                .offset(y: 16)
        }
        .frame(width: 68, height: 68)
    }
}

// DiamondBase 구조체는 DiamondBase 타입의 역할과 값을 정의합니다.
private struct DiamondBase: View {
    @Environment(AppModel.self) private var appModel
    let isFilled: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(borderColor, lineWidth: lineWidth)
            )
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(45))
    }

    private var fillColor: Color {
        if let stadiumPalette = appModel.favoriteStadiumPalette {
            return isFilled ? stadiumPalette.tint : stadiumPalette.recessedSurface
        }
        return isFilled ? KBOLivePalette.primary : Color(.systemBackground)
    }

    private var borderColor: Color {
        if let stadiumPalette = appModel.favoriteStadiumPalette {
            return stadiumPalette.secondaryTint.opacity(0.45)
        }
        return KBOLivePalette.primary.opacity(0.35)
    }

    private var lineWidth: CGFloat {
        appModel.isStadiumFavoriteSelected ? 0.75 : 1
    }
}
