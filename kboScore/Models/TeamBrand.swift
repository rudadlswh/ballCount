//
//  TeamBrand.swift
//  kboScore
//  기능 설명: 팀별 색상, 이미지, 경기장 팔레트 등 브랜드 정보를 정의합니다.
//  KBO 경기와 팀 규칙을 화면·저장소와 분리된 값 모델로 표현해 계산과 비교 기준을 일관되게 유지합니다.
//  동명이인, 보류 경기, 취소 경기, 누락 점수처럼 원천 데이터가 불완전한 상황을 고려합니다.
//  TODO : 새 시즌 규칙이나 추가 지표가 생기면 모델 확장 지점을 명확히 분리합니다.
//
//  Created by Codex on 3/26/26.
//

import SwiftUI

struct StadiumPalette: Sendable {
    let id: String
    let primary: Color
    let secondary: Color
    let tint: Color
    let secondaryTint: Color
    let uniformSurface: Color
    let background: Color
    private let raisedSurface: Color

    // 모든 응원 팀에 동일한 시안의 라이트·다크 색상을 적용합니다.
    static let app = StadiumPalette()

    private init() {
        id = "app"
        primary = Color(hex: 0xC9273A)
        secondary = Color(hex: 0x101C2D, darkHex: 0xF3F0E2)
        tint = Color(hex: 0xB52336, darkHex: 0xFF8B98)
        secondaryTint = tint
        uniformSurface = Color(hex: 0xFCFAF3, darkHex: 0x16263A)
        background = Color(hex: 0xF3F0E2, darkHex: 0x0B1524)
        raisedSurface = Color(hex: 0xE8E6DC, darkHex: 0x223349)
    }

    private init(
        id: String, primaryHex: UInt32, secondaryHex: UInt32,
        lightPrimaryHex: UInt32? = nil, darkPrimaryHex: UInt32? = nil,
        lightSecondaryHex: UInt32? = nil, darkSecondaryHex: UInt32? = nil,
        uniformSurfaceHex: UInt32 = 0xFFFFFF,
        awaySurfaceHex: UInt32,
        awayPrimaryHex: UInt32,
        awaySecondaryHex: UInt32
    ) {
        self.id = id
        primary = Color(hex: primaryHex, darkHex: awayPrimaryHex)
        secondary = Color(hex: secondaryHex, darkHex: awaySecondaryHex)
        tint = Color(hex: primaryHex, lightHex: lightPrimaryHex, darkHex: darkPrimaryHex ?? awayPrimaryHex)
        secondaryTint = Color(hex: secondaryHex, lightHex: lightSecondaryHex, darkHex: darkSecondaryHex ?? awaySecondaryHex)
        uniformSurface = Color(hex: uniformSurfaceHex, darkHex: awaySurfaceHex)

        // 라이트는 홈 유니폼, 다크는 원정 유니폼의 바탕·로고·배색을 함께 전환합니다.
        // 화면용 원정 바탕은 유니폼의 색감을 유지하며 글자를 읽기 좋게 낮춘 명도입니다.
        func blend(_ base: UInt32, with color: UInt32, amount: Double) -> UInt32 {
            [16, 8, 0].reduce(UInt32(0)) { result, shift in
                let baseComponent = Double((base >> shift) & 0xFF)
                let teamComponent = Double((color >> shift) & 0xFF)
                let component = UInt32((baseComponent * (1 - amount) + teamComponent * amount).rounded())
                return result | (component << shift)
            }
        }
        background = Color(
            hex: blend(id == "lotte" ? 0xECE9DD : 0xF2F2F7, with: primaryHex, amount: 0.10),
            darkHex: blend(awaySurfaceHex, with: 0x000000, amount: 0.60)
        )
        raisedSurface = Color(
            hex: blend(uniformSurfaceHex, with: primaryHex, amount: 0.04),
            darkHex: blend(awaySurfaceHex, with: 0xFFFFFF, amount: 0.06)
        )
    }

    var statusRed: Color { .red }
    var sectionBackground: Color { uniformSurface }
    var elevatedCard: Color { uniformSurface }
    var elevatedCardStrong: Color { raisedSurface }
    var recessedSurface: Color { raisedSurface }
    var glassSurface: Color { uniformSurface }
    var navigationSurface: Color { uniformSurface }
    var tabBarSurface: Color { id == "app" ? Color(hex: 0xFCFAF3, darkHex: 0x1A2A3F) : uniformSurface }
    var tabBarSelectionSurface: Color { id == "app" ? Color(hex: 0xF1DDDA, darkHex: 0x3D2739) : raisedSurface }
    var bellControlSurface: Color { uniformSurface }
    var textPrimary: Color { id == "app" ? Color(hex: 0x101C2D, darkHex: 0xF3F0E2) : Color(.label) }
    var textSecondary: Color { id == "app" ? Color(hex: 0x646860, darkHex: 0xACB9CA) : Color(hex: 0x595960, darkHex: 0xCFD3DB) }
    var ghostBorder: Color { id == "app" ? Color(hex: 0xDEDCCD, darkHex: 0x2C3B4F) : secondaryTint.opacity(0.28) }
    var ambientShadow: Color { .clear }
    var weather: Color { .orange }
    var winDayFill: Color { tint.opacity(0.14) }
    var uniformTrim: LinearGradient {
        LinearGradient(colors: [primary, secondary], startPoint: .leading, endPoint: .trailing)
    }

    static let doosan = StadiumPalette(
        id: "doosan", primaryHex: 0xC92135, secondaryHex: 0x1A1D29,
        lightPrimaryHex: 0xB51A2D, darkSecondaryHex: 0xFF9CA5,
        awaySurfaceHex: 0x17233B, awayPrimaryHex: 0xFFFFFF, awaySecondaryHex: 0xC92135
    )
    static let hanwha = StadiumPalette(
        id: "hanwha", primaryHex: 0xEF5F18, secondaryHex: 0x161616,
        lightPrimaryHex: 0xAE3905, darkPrimaryHex: 0xFF9A59,
        awaySurfaceHex: 0x1C2938, awayPrimaryHex: 0xEF5F18, awaySecondaryHex: 0xFFFFFF
    )
    static let kia = StadiumPalette(
        id: "kia", primaryHex: 0x161616, secondaryHex: 0xD81F25,
        lightSecondaryHex: 0xB41219, darkSecondaryHex: 0xFFB0B5,
        awaySurfaceHex: 0x5C1825, awayPrimaryHex: 0xFFFFFF, awaySecondaryHex: 0x161616
    )
    static let kt = StadiumPalette(
        id: "kt", primaryHex: 0x0A0A0A, secondaryHex: 0xFFFFFF,
        lightSecondaryHex: 0x0A0A0A,
        awaySurfaceHex: 0x19191B, awayPrimaryHex: 0xFFFFFF, awaySecondaryHex: 0xFFFFFF
    )
    static let lg = StadiumPalette(
        id: "lg", primaryHex: 0xC3042F, secondaryHex: 0x161616,
        darkSecondaryHex: 0xFF92AD,
        awaySurfaceHex: 0x1F1F22, awayPrimaryHex: 0xFFFFFF, awaySecondaryHex: 0xC3042F
    )
    static let lotte = StadiumPalette(
        id: "lotte", primaryHex: 0xC9273A, secondaryHex: 0x101C2D,
        lightPrimaryHex: 0xAA161E, darkPrimaryHex: 0xFF8F9B,
        uniformSurfaceHex: 0xF3F0E2,
        awaySurfaceHex: 0x101C2D, awayPrimaryHex: 0xC9273A, awaySecondaryHex: 0xF3F0E2
    )
    static let nc = StadiumPalette(
        id: "nc", primaryHex: 0x173052, secondaryHex: 0xC7A079,
        darkPrimaryHex: 0xE4BD8D, lightSecondaryHex: 0x795633, darkSecondaryHex: 0xB9CEE8,
        awaySurfaceHex: 0x193654, awayPrimaryHex: 0xC7A079, awaySecondaryHex: 0x173052
    )
    static let kiwoom = StadiumPalette(
        id: "kiwoom", primaryHex: 0x570E29, secondaryHex: 0xC55E82,
        lightSecondaryHex: 0x9F355B, darkSecondaryHex: 0xFFB0CA,
        awaySurfaceHex: 0x570E29, awayPrimaryHex: 0xFFFFFF, awaySecondaryHex: 0xC55E82
    )
    static let samsung = StadiumPalette(
        id: "samsung", primaryHex: 0x17469F, secondaryHex: 0xFFFFFF,
        lightSecondaryHex: 0x17469F,
        awaySurfaceHex: 0x173F86, awayPrimaryHex: 0xFFFFFF, awaySecondaryHex: 0xFFFFFF
    )
    static let ssg = StadiumPalette(
        id: "ssg", primaryHex: 0xCE1524, secondaryHex: 0xF6CF25,
        lightPrimaryHex: 0xB60F1D, lightSecondaryHex: 0x755C00,
        awaySurfaceHex: 0x6D1524, awayPrimaryHex: 0xFFFFFF, awaySecondaryHex: 0xF6CF25
    )
}

private extension Color {
    // 유니폼 원색과 별개로, 작은 글자와 버튼에 쓰는 밝기를 표시 모드에 맞춥니다.
    init(hex: UInt32, lightHex: UInt32? = nil, darkHex: UInt32? = nil) {
        let light = lightHex ?? hex
        let dark = darkHex ?? hex
        self.init(uiColor: UIColor { traits in
            let resolved = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((resolved >> 16) & 0xFF) / 255,
                green: CGFloat((resolved >> 8) & 0xFF) / 255,
                blue: CGFloat(resolved & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

// TeamThemeMode 열거형는 TeamThemeMode 타입의 역할과 값을 정의합니다.
enum TeamThemeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case systemDefault = "시스템 기본"
    case favoriteTeam = "마이팀 테마 사용"

    var id: String { rawValue }
}

// TeamThemeID 열거형는 TeamThemeID 타입의 역할과 값을 정의합니다.
enum TeamThemeID: String, Codable, Sendable {
    case doosan
    case hanwha
    case kia
    case kiwoom
    case kt
    case lg
    case lotte
    case nc
    case samsung
    case ssg
    case neutral
}

// TeamTheme 구조체는 TeamTheme 타입의 역할과 값을 정의합니다.
struct TeamTheme: Sendable {
    let id: TeamThemeID
    let accent: Color
    let accentSecondary: Color
    let heroStart: Color
    let heroEnd: Color
    let chipBackground: Color
    let badgeBackground: Color
    let badgeForeground: Color
    let scoreboardBackground: Color
    let shadowTint: Color
    let uniformPalette: StadiumPalette?

    nonisolated static let neutral = TeamTheme(
        id: .neutral,
        accent: Color(hex: 0x1C47AB),
        accentSecondary: Color(hex: 0x6797FF),
        heroStart: Color(hex: 0x1C47AB),
        heroEnd: Color(hex: 0x6797FF),
        chipBackground: Color(hex: 0x1C47AB).opacity(0.12),
        badgeBackground: Color(.secondarySystemBackground),
        badgeForeground: Color(hex: 0x1C47AB),
        scoreboardBackground: Color(.secondarySystemBackground),
        shadowTint: Color(hex: 0x1C47AB).opacity(0.12),
        uniformPalette: nil
    )

    // 화면 모드에 따라 홈·원정 유니폼 색상을 같은 팔레트에서 해석합니다.
    nonisolated static func homeUniform(_ palette: StadiumPalette) -> TeamTheme {
        TeamTheme(
            id: TeamThemeID(rawValue: palette.id) ?? .neutral,
            accent: palette.tint,
            accentSecondary: palette.secondary,
            heroStart: palette.uniformSurface,
            heroEnd: palette.uniformSurface,
            chipBackground: palette.tint.opacity(0.08),
            badgeBackground: palette.uniformSurface,
            badgeForeground: palette.tint,
            scoreboardBackground: palette.uniformSurface,
            shadowTint: .clear,
            uniformPalette: palette
        )
    }

    // resolve 메서드는 입력 데이터를 판별하거나 정렬해 사용할 대상을 결정합니다.
    nonisolated static func resolve(for teamID: String?) -> TeamTheme {
        guard let identity = TeamIdentity.catalog[teamID ?? ""] else { return .neutral }
        return identity.theme
    }
}

// TeamIdentity 구조체는 TeamIdentity 타입의 역할과 값을 정의합니다.
struct TeamIdentity: Sendable {
    let id: String
    let displayName: String
    let shortLabel: String
    let monogram: String
    let homeHeroWatermarkLabel: String
    let themeID: TeamThemeID
    let theme: TeamTheme

    nonisolated static let catalog: [String: TeamIdentity] = [
        "doosan": TeamIdentity(
            id: "doosan",
            displayName: "두산 베어스",
            shortLabel: "두산",
            monogram: "두산",
            homeHeroWatermarkLabel: "Bears",
            themeID: .doosan,
            theme: .homeUniform(.doosan)
        ),
        "hanwha": TeamIdentity(
            id: "hanwha",
            displayName: "한화 이글스",
            shortLabel: "한화",
            monogram: "한화",
            homeHeroWatermarkLabel: "Eagles",
            themeID: .hanwha,
            theme: .homeUniform(.hanwha)
        ),
        "kia": TeamIdentity(
            id: "kia",
            displayName: "KIA 타이거즈",
            shortLabel: "기아",
            monogram: "KIA",
            homeHeroWatermarkLabel: "Tigers",
            themeID: .kia,
            theme: .homeUniform(.kia)
        ),
        "kiwoom": TeamIdentity(
            id: "kiwoom",
            displayName: "키움 히어로즈",
            shortLabel: "키움",
            monogram: "키움",
            homeHeroWatermarkLabel: "Heroes",
            themeID: .kiwoom,
            theme: .homeUniform(.kiwoom)
        ),
        "kt": TeamIdentity(
            id: "kt",
            displayName: "KT 위즈",
            shortLabel: "KT",
            monogram: "KT",
            homeHeroWatermarkLabel: "Wiz",
            themeID: .kt,
            theme: .homeUniform(.kt)
        ),
        "lg": TeamIdentity(
            id: "lg",
            displayName: "LG 트윈스",
            shortLabel: "LG",
            monogram: "LG",
            homeHeroWatermarkLabel: "Twins",
            themeID: .lg,
            theme: .homeUniform(.lg)
        ),
        "lotte": TeamIdentity(
            id: "lotte",
            displayName: "롯데 자이언츠",
            shortLabel: "롯데",
            monogram: "롯데",
            homeHeroWatermarkLabel: "Giants",
            themeID: .lotte,
            theme: .homeUniform(.lotte)
        ),
        "nc": TeamIdentity(
            id: "nc",
            displayName: "NC 다이노스",
            shortLabel: "NC",
            monogram: "NC",
            homeHeroWatermarkLabel: "Dinos",
            themeID: .nc,
            theme: .homeUniform(.nc)
        ),
        "samsung": TeamIdentity(
            id: "samsung",
            displayName: "삼성 라이온즈",
            shortLabel: "삼성",
            monogram: "삼성",
            homeHeroWatermarkLabel: "Lions",
            themeID: .samsung,
            theme: .homeUniform(.samsung)
        ),
        "ssg": TeamIdentity(
            id: "ssg",
            displayName: "SSG 랜더스",
            shortLabel: "SSG",
            monogram: "SSG",
            homeHeroWatermarkLabel: "Landers",
            themeID: .ssg,
            theme: .homeUniform(.ssg)
        )
    ]
}

extension Team {
    var identity: TeamIdentity {
        TeamIdentity.catalog[id] ?? TeamIdentity(
            id: id,
            displayName: name,
            shortLabel: shortName,
            monogram: markText,
            homeHeroWatermarkLabel: shortName,
            themeID: .neutral,
            theme: .neutral
        )
    }
}
