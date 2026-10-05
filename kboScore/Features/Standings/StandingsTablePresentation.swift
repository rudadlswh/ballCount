//
//  StandingsTablePresentation.swift
//  kboScore
//  기능 설명: 순위표 셀의 문구, 색상, 접근성 표현을 구성합니다.
//  KBO 순위 산정 규칙과 홈 화면 대체 요약에 필요한 계산을 화면 코드에서 분리합니다.
//  완료되지 않은 경기, 취소 경기, 동률, 원정/홈 득실 계산이 순위에 잘못 반영되지 않도록 제한합니다.
//  TODO : 실제 KBO 동률 규정 변경이나 포스트시즌 확률 로직 개선 시 계산 기준을 갱신합니다.
//
//  Created by Codex on 6/8/26.
//

import CoreGraphics
import Foundation

// StandingsTableMetrics 구조체는 StandingsTableMetrics 타입의 역할과 값을 정의합니다.
struct StandingsTableMetrics {
    let textScale: CGFloat
    let availableWidth: CGFloat

    init(textScale: CGFloat, availableWidth: CGFloat = 0) {
        self.textScale = textScale
        self.availableWidth = availableWidth
    }

    var rowHeight: CGFloat { 40 * textScale }
    var horizontalPadding: CGFloat { 12 * textScale }
    var spacing: CGFloat { 8 * textScale }
    var rankWidth: CGFloat { 20 * textScale }
    var movementWidth: CGFloat { 14 * textScale }
    var rankMovementWidth: CGFloat { 40 * textScale }
    var teamColumnWidth: CGFloat { 56 * textScale }
    var gamesWidth: CGFloat { 30 * textScale * statsScale }
    var countWidth: CGFloat { 26 * textScale * statsScale }
    var percentageWidth: CGFloat { 43 * textScale * statsScale }
    var gamesBehindWidth: CGFloat { 43 * textScale * statsScale }
    var streakWidth: CGFloat { 64 * textScale * statsScale }
    var accentWidth: CGFloat { (availableWidth > 0 ? availableWidth : width) / 2 }

    var pinnedWidth: CGFloat {
        horizontalPadding + rankMovementWidth + teamColumnWidth + spacing * 2
    }

    private var statsScale: CGFloat {
        max(1, (availableWidth - pinnedWidth - spacing * 6 - horizontalPadding) / (254 * textScale))
    }

    var statsContentWidth: CGFloat {
        gamesWidth + countWidth * 3 + percentageWidth + gamesBehindWidth +
            streakWidth + spacing * 6 + horizontalPadding
    }

    var width: CGFloat { pinnedWidth + statsContentWidth }
}

extension TeamIdentity {
    var standingsDisplayName: String {
        switch id {
        case "lg":
            "LG"
        case "kt":
            "KT"
        case "ssg":
            "SSG"
        case "samsung":
            "삼성"
        case "kia":
            "KIA"
        case "hanwha":
            "한화"
        case "nc":
            "NC"
        case "doosan":
            "두산"
        case "lotte":
            "롯데"
        case "kiwoom":
            "키움"
        default:
            shortLabel
        }
    }
}

extension TeamStandingsSnapshot {
    var broadcastWinPercentageText: String {
        if winPercentageText.hasPrefix("0.") {
            return String(winPercentageText.dropFirst())
        }
        return winPercentageText
    }

    // gamesBehindText 메서드는 이 타입의 주요 동작을 수행합니다.
    func gamesBehindText(leader: TeamStandingsSnapshot?) -> String {
        if let precomputedGamesBehind {
            guard precomputedGamesBehind > 0 else { return "-" }
            if precomputedGamesBehind.rounded(.towardZero) == precomputedGamesBehind {
                return String(format: "%.0f", precomputedGamesBehind)
            }
            return String(format: "%.1f", precomputedGamesBehind)
        }
        guard let leader else { return "-" }
        guard rank != leader.rank else { return "-" }

        let gamesBehind = Double((leader.wins - wins) + (losses - leader.losses)) / 2
        guard gamesBehind > 0 else { return "-" }

        if gamesBehind.rounded(.towardZero) == gamesBehind {
            return String(format: "%.0f", gamesBehind)
        }
        return String(format: "%.1f", gamesBehind)
    }
}
