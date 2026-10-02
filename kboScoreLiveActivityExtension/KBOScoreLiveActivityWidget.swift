//
//  KBOScoreLiveActivityWidget.swift
//  kboScoreLiveActivityExtension
//  기능 설명: KBO 경기 Live Activity와 다이내믹 아일랜드 UI를 렌더링합니다.
//  사용자가 경기 상태와 설정을 빠르게 이해하도록 도메인 상태를 화면 구조에 직접 매핑합니다.
//  SwiftUI 상태 갱신, 접근성, 작은 화면 레이아웃에서 정보가 겹치지 않도록 표시 조건을 제한합니다.
//  TODO : 반복되는 화면 조각은 재사용 가능한 컴포넌트로 분리하고 미리보기 케이스를 보강합니다.
//
//  Created by Codex on 3/26/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

// KBOScoreLiveActivityWidget 구조체는 KBOScoreLiveActivityWidget 타입의 역할과 값을 정의합니다.
struct KBOScoreLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FavoriteTeamGameActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            let game = BroadcastScoreboardGame(context: context)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandTeamView(
                        side: game.away,
                        alignment: .leading,
                        isBatting: game.battingSide == .away,
                        showsScore: game.isPreGame == false,
                        isFavorite: game.away.teamID == game.favoriteTeamID
                    )
                }

                DynamicIslandExpandedRegion(.trailing) {
                    DynamicIslandTeamView(
                        side: game.home,
                        alignment: .trailing,
                        isBatting: game.battingSide == .home,
                        showsScore: game.isPreGame == false,
                        isFavorite: game.home.teamID == game.favoriteTeamID
                    )
                }

                DynamicIslandExpandedRegion(.center) {
                    DynamicIslandStatusView(
                        inningText: game.inningText,
                        statusText: game.statusText
                    )
                }

                DynamicIslandExpandedRegion(.bottom) {
                    DynamicIslandBroadcastMetadataRow(game: game)
                }
            } compactLeading: {
                DynamicIslandCompactTeamView(side: game.away, alignment: .leading,
                                             showsScore: !game.isPreGame, isFavorite: game.away.teamID == game.favoriteTeamID)
            } compactTrailing: {
                DynamicIslandCompactTeamView(side: game.home, alignment: .trailing,
                                             showsScore: !game.isPreGame, isFavorite: game.home.teamID == game.favoriteTeamID)
            } minimal: {
                DynamicIslandMinimalView(game: game)
            }
            .keylineTint(dynamicIslandAccent)
        }
    }
}

// LockScreenLiveActivityView 구조체는 화면에 표시되는 SwiftUI 뷰 구성을 담당합니다.
private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<FavoriteTeamGameActivityAttributes>

    var body: some View {
        BroadcastScoreboardStrip(game: BroadcastScoreboardGame(context: context))
            .padding(.vertical, 6)
            .activityBackgroundTint(Color.black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)
    }
}

// BroadcastScoreboardGame 구조체는 BroadcastScoreboardGame 타입의 역할과 값을 정의합니다.
private struct BroadcastScoreboardGame {
    let away: BroadcastTeamSide
    let home: BroadcastTeamSide
    let inningText: String
    let statusText: String
    let batterText: String?
    let pitcherText: String?
    let metadataText: String?
    let battingSide: KBOLiveActivityOffenseSide?
    let baseState: BroadcastBaseState?
    let isPreGame: Bool
    let awayStartingPitcherName: String?
    let homeStartingPitcherName: String?
    let balls: Int?
    let strikes: Int?
    let outs: Int?
    let favoriteTeamID: String

    // 이 초기화 메서드는 인스턴스 생성에 필요한 값을 설정합니다.
    init(context: ActivityViewContext<FavoriteTeamGameActivityAttributes>) {
        let favorite = BroadcastTeamSide(
            roleLabel: context.attributes.isHomeGame ? "홈" : "원정",
            teamID: context.attributes.favoriteTeamID,
            teamName: context.attributes.favoriteTeamName,
            shortName: context.attributes.favoriteTeamShortName,
            scoreText: context.state.favoriteScoreText
        )
        let opponent = BroadcastTeamSide(
            roleLabel: context.attributes.isHomeGame ? "원정" : "홈",
            teamID: context.attributes.opponentTeamID,
            teamName: context.attributes.opponentTeamName,
            shortName: context.attributes.opponentTeamShortName,
            scoreText: context.state.opponentScoreText
        )

        away = context.attributes.isHomeGame ? opponent : favorite
        home = context.attributes.isHomeGame ? favorite : opponent
        isPreGame = context.state.isPreGame
        inningText = context.state.inningText
        statusText = context.state.summaryText
        batterText = context.state.isPreGame ? nil : context.state.currentBatterName
        pitcherText = context.state.isPreGame ? nil : context.state.currentPitcherName
        awayStartingPitcherName = context.attributes.isHomeGame ? context.state.opponentStartingPitcherName : context.state.favoriteStartingPitcherName
        homeStartingPitcherName = context.attributes.isHomeGame ? context.state.favoriteStartingPitcherName : context.state.opponentStartingPitcherName
        battingSide = KBOLiveActivityOffenseResolver.offenseSide(
            isPreGame: context.state.isPreGame,
            summaryText: context.state.summaryText,
            inningText: context.state.inningText
        )
        metadataText = Self.metadataText(
            inningText: context.state.inningText,
            statusText: context.state.summaryText,
            venue: context.attributes.venue
        )
        baseState = context.state.isPreGame ? nil : Self.baseState(
            first: context.state.runnerOnFirst,
            second: context.state.runnerOnSecond,
            third: context.state.runnerOnThird
        )
        balls = context.state.isPreGame ? nil : context.state.balls
        strikes = context.state.isPreGame ? nil : context.state.strikes
        outs = context.state.isPreGame ? nil : context.state.outs
        favoriteTeamID = context.attributes.favoriteTeamID
    }

    // metadataText 메서드는 이 타입의 주요 동작을 수행합니다.
    private static func metadataText(inningText: String, statusText: String, venue: String) -> String? {
        var parts: [String] = []
        if inningText.isEmpty == false && inningText != statusText {
            parts.append(inningText)
        }
        if venue.isEmpty == false {
            parts.append(venue)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // baseState 메서드는 이 타입의 주요 동작을 수행합니다.
    private static func baseState(first: Bool?, second: Bool?, third: Bool?) -> BroadcastBaseState? {
        guard first != nil || second != nil || third != nil else {
            return nil
        }

        return BroadcastBaseState(
            first: first ?? false,
            second: second ?? false,
            third: third ?? false
        )
    }

    // countText 메서드는 이 타입의 주요 동작을 수행합니다.
    private static func countText(balls: Int?, strikes: Int?, outs: Int?) -> String? {
        let parts = [
            KBOCountDisplay.balls(balls).map { "B \($0)" },
            KBOCountDisplay.strikes(strikes).map { "S \($0)" },
            KBOCountDisplay.outs(outs).map { "O \($0)" }
        ].compactMap { $0 }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var countText: String? {
        Self.countText(balls: balls, strikes: strikes, outs: outs)
    }

    var hasBroadcastMetadata: Bool {
        if isPreGame {
            return true
        }
        return batterText != nil || countText != nil || pitcherText != nil
    }

    var compactMetadataText: String? {
        [
            batterText.map { "B \($0)" },
            countText,
            pitcherText.map { "P \($0)" },
            metadataText
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nilIfEmpty
    }
}

// BroadcastBaseState 구조체는 화면이나 도메인 흐름에서 사용하는 상태 값을 표현합니다.
private struct BroadcastBaseState {
    let first: Bool
    let second: Bool
    let third: Bool
}

// BroadcastTeamSide 구조체는 BroadcastTeamSide 타입의 역할과 값을 정의합니다.
private struct BroadcastTeamSide {
    let roleLabel: String
    let teamID: String
    let teamName: String
    let shortName: String
    let scoreText: String

    var accent: Color {
        TeamIdentity.catalog[teamID]?.theme.accent ?? .white
    }
}

// ScoreboardAlignment 열거형는 ScoreboardAlignment 타입의 역할과 값을 정의합니다.
private enum ScoreboardAlignment {
    case leading
    case trailing

    var horizontal: HorizontalAlignment {
        switch self {
        case .leading:
            .leading
        case .trailing:
            .trailing
        }
    }

    var frame: Alignment {
        switch self {
        case .leading:
            .leading
        case .trailing:
            .trailing
        }
    }
}

// BroadcastScoreboardStrip 구조체는 BroadcastScoreboardStrip 타입의 역할과 값을 정의합니다.
private struct BroadcastScoreboardStrip: View {
    let game: BroadcastScoreboardGame

    var body: some View {
        VStack(spacing: 0) {
            BroadcastScoreboardMainRow(game: game)
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 9)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)

            BroadcastScoreboardMetadataRow(game: game)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 9)
        }
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
    }
}

// BroadcastScoreboardMainRow 구조체는 BroadcastScoreboardMainRow 타입의 역할과 값을 정의합니다.
private struct BroadcastScoreboardMainRow: View {
    let game: BroadcastScoreboardGame

    var body: some View {
        HStack(spacing: 8) {
            BroadcastTeamIdentityView(
                side: game.away,
                alignment: .leading,
                isBatting: game.battingSide == .away
            )

            if game.isPreGame == false {
                BroadcastScoreValue(scoreText: game.away.scoreText)
            }

            BroadcastGameStateHub(
                inningText: game.inningText,
                statusText: game.statusText,
                baseState: game.baseState
            )

            if game.isPreGame == false {
                BroadcastScoreValue(scoreText: game.home.scoreText)
            }

            BroadcastTeamIdentityView(
                side: game.home,
                alignment: .trailing,
                isBatting: game.battingSide == .home
            )
        }
        .frame(minHeight: 56)
    }
}

// BroadcastTeamIdentityView 구조체는 화면에 표시되는 SwiftUI 뷰 구성을 담당합니다.
private struct BroadcastTeamIdentityView: View {
    let side: BroadcastTeamSide
    let alignment: ScoreboardAlignment
    let isBatting: Bool

    var body: some View {
        HStack(spacing: 7) {
            if alignment == .leading {
                teamMark(isVisible: isBatting)
            }

            VStack(alignment: alignment.horizontal, spacing: 2) {
                Text(side.shortName)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .accessibilityLabel(side.teamName)

                HStack(spacing: 3) {
                    if isBatting {
                        Circle()
                            .fill(.white)
                            .frame(width: 5, height: 5)
                    }

                    Text(isBatting ? "\(side.roleLabel) 공격" : side.roleLabel)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(isBatting ? .white.opacity(0.82) : .white.opacity(0.54))
                }
            }

            if alignment == .trailing {
                teamMark(isVisible: isBatting)
            }
        }
        .padding(.horizontal, isBatting ? 5 : 0)
        .padding(.vertical, isBatting ? 4 : 0)
        .background {
            if isBatting {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment.frame)
    }

    @ViewBuilder
    private func teamMark(isVisible: Bool) -> some View {
        Rectangle()
            .fill(side.accent)
            .frame(width: 4, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .opacity(isVisible ? 1 : 0)
            .accessibilityHidden(isVisible == false)
    }
}

// BroadcastScoreValue 구조체는 BroadcastScoreValue 타입의 역할과 값을 정의합니다.
private struct BroadcastScoreValue: View {
    let scoreText: String

    var body: some View {
        Text(scoreText)
            .font(.system(size: 36, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .shadow(color: Color.black.opacity(0.36), radius: 2, y: 1)
            .frame(minWidth: 34)
    }
}

// BroadcastGameStateHub 구조체는 BroadcastGameStateHub 타입의 역할과 값을 정의합니다.
private struct BroadcastGameStateHub: View {
    let inningText: String
    let statusText: String
    let baseState: BroadcastBaseState?

    var body: some View {
        VStack(spacing: 3) {
            Text(primaryText)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.66)

            if let baseState {
                BroadcastBaseDiamond(baseState: baseState, size: 26)
            }

            if shouldShowStatus {
                Text(statusText)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(statusText == "LIVE" ? Color(red: 1, green: 0.36, blue: 0.36) : .white.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(width: 82)
        .frame(minHeight: 54)
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.08))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 1)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 1)
        }
    }

    private var primaryText: String {
        inningText.isEmpty ? statusText : inningText
    }

    private var shouldShowStatus: Bool {
        statusText.isEmpty == false && statusText != primaryText
    }
}

// BroadcastBaseDiamond 구조체는 BroadcastBaseDiamond 타입의 역할과 값을 정의합니다.
private struct BroadcastBaseDiamond: View {
    let baseState: BroadcastBaseState
    let size: CGFloat

    var body: some View {
        ZStack {
            base(isOccupied: baseState.second)
                .offset(y: -size * 0.26)
            base(isOccupied: baseState.first)
                .offset(x: size * 0.26)
            base(isOccupied: baseState.third)
                .offset(x: -size * 0.26)
            base(isOccupied: false)
                .offset(y: size * 0.26)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(accessibilityText)
    }

    // base 메서드는 이 타입의 주요 동작을 수행합니다.
    private func base(isOccupied: Bool) -> some View {
        RoundedRectangle(cornerRadius: size * 0.09, style: .continuous)
            .fill(isOccupied ? Color.white : Color.white.opacity(0.18))
            .frame(width: size * 0.24, height: size * 0.24)
            .rotationEffect(.degrees(45))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.09, style: .continuous)
                    .stroke(Color.white.opacity(isOccupied ? 0.90 : 0.26), lineWidth: 0.8)
                    .rotationEffect(.degrees(45))
            }
    }

    private var accessibilityText: String {
        let occupiedBases = [
            baseState.first ? "1루" : nil,
            baseState.second ? "2루" : nil,
            baseState.third ? "3루" : nil
        ].compactMap { $0 }

        if occupiedBases.isEmpty {
            return "주자 없음"
        }
        return "주자 \(occupiedBases.joined(separator: ", "))"
    }
}

// BroadcastScoreboardMetadataRow 구조체는 BroadcastScoreboardMetadataRow 타입의 역할과 값을 정의합니다.
private struct BroadcastScoreboardMetadataRow: View {
    let game: BroadcastScoreboardGame

    var body: some View {
        HStack(spacing: 8) {
            if game.isPreGame {
                BroadcastPlayerSlot(
                    label: "\(game.away.shortName) 선발",
                    text: game.awayStartingPitcherName ?? "선발 미정",
                    alignment: .leading
                )

                Text(game.metadataText ?? game.statusText)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                BroadcastPlayerSlot(
                    label: "\(game.home.shortName) 선발",
                    text: game.homeStartingPitcherName ?? "선발 미정",
                    alignment: .trailing
                )
            } else {
                BroadcastPlayerSlot(
                    label: "타자",
                    text: game.batterText,
                    alignment: .leading
                )

                BroadcastCountCluster(
                    balls: game.balls,
                    strikes: game.strikes,
                    outs: game.outs
                )

                BroadcastPlayerSlot(
                    label: "투수",
                    text: game.pitcherText,
                    alignment: .trailing
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 28)
        .accessibilityElement(children: .combine)
    }
}

// BroadcastPlayerSlot 구조체는 BroadcastPlayerSlot 타입의 역할과 값을 정의합니다.
private struct BroadcastPlayerSlot: View {
    let label: String
    let text: String?
    let alignment: ScoreboardAlignment

    var body: some View {
        Group {
            if let text {
                VStack(alignment: alignment.horizontal, spacing: 2) {
                    Text(label)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.50))

                    Text(text)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
            } else {
                Color.clear
                    .frame(height: 26)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment.frame)
    }
}

// BroadcastCountCluster 구조체는 BroadcastCountCluster 타입의 역할과 값을 정의합니다.
private struct BroadcastCountCluster: View {
    let balls: Int?
    let strikes: Int?
    let outs: Int?

    @ViewBuilder
    var body: some View {
        if metrics.isEmpty == false {
            HStack(spacing: 6) {
                ForEach(metrics) { metric in
                    HStack(spacing: 3) {
                        Text(metric.label)
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.56))

                        Text(String(metric.value))
                            .font(.caption2.weight(.black))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.09))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    private var metrics: [BroadcastCountMetric] {
        [
            KBOCountDisplay.balls(balls).map { BroadcastCountMetric(label: "B", value: $0) },
            KBOCountDisplay.strikes(strikes).map { BroadcastCountMetric(label: "S", value: $0) },
            KBOCountDisplay.outs(outs).map { BroadcastCountMetric(label: "O", value: $0) }
        ].compactMap { $0 }
    }
}

// BroadcastCountMetric 구조체는 BroadcastCountMetric 타입의 역할과 값을 정의합니다.
private struct BroadcastCountMetric: Identifiable {
    let label: String
    let value: Int

    var id: String { label }
}

private extension String {
    var nilIfEmpty: String? {
        if isEmpty {
            return nil
        }
        return self
    }
}

// Dynamic Island는 화면 모드와 관계없이 시스템의 검정 배경 위에 표시됩니다.
private let dynamicIslandAccent = Color(red: 1, green: 0.55, blue: 0.60)

private struct DynamicIslandCompactTeamView: View {
    let side: BroadcastTeamSide
    let alignment: ScoreboardAlignment
    let showsScore: Bool
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 3) {
            if alignment == .trailing && showsScore { score }
            Text(TeamIdentity.catalog[side.teamID]?.shortLabel ?? side.shortName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if alignment == .leading && showsScore { score }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsScore ? "\(side.teamName) \(side.scoreText)점" : side.teamName)
    }

    private var score: some View {
        Text(side.scoreText)
            .font(.system(size: 14, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(isFavorite ? dynamicIslandAccent : .white)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .layoutPriority(1)
    }
}

private struct DynamicIslandMinimalView: View {
    let game: BroadcastScoreboardGame

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "baseball.fill")
                .font(.system(size: game.isPreGame ? 16 : 9))
                .foregroundStyle(dynamicIslandAccent)
            if !game.isPreGame {
                Text("\(game.away.scoreText):\(game.home.scoreText)")
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(game.isPreGame ? "야구 경기 예정" : "\(game.away.teamName) \(game.away.scoreText)점, \(game.home.teamName) \(game.home.scoreText)점, \(game.inningText)")
    }
}

private struct DynamicIslandTeamView: View {
    let side: BroadcastTeamSide
    let alignment: ScoreboardAlignment
    let isBatting: Bool
    let showsScore: Bool
    let isFavorite: Bool

    var body: some View {
        VStack(alignment: alignment.horizontal, spacing: 3) {
            Text(TeamIdentity.catalog[side.teamID]?.shortLabel ?? side.shortName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if showsScore {
                Text(side.scoreText)
                    .font(.system(size: 32, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(isFavorite ? dynamicIslandAccent : .white)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            HStack(spacing: 4) {
                if isBatting {
                    Circle().fill(dynamicIslandAccent).frame(width: 4, height: 4)
                }
                Text(isBatting ? "\(side.roleLabel) · 공격" : side.roleLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment.frame)
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(side.teamName), \(side.roleLabel), \(showsScore ? side.scoreText + "점" : "경기 예정")\(isBatting ? ", 공격 중" : "")")
    }
}

private struct DynamicIslandStatusView: View {
    let inningText: String
    let statusText: String

    var body: some View {
        VStack(spacing: 4) {
            Text(inningText.isEmpty ? statusText : inningText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if !statusText.isEmpty && statusText != inningText && !inningText.isEmpty {
                Text(statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

private struct DynamicIslandBroadcastMetadataRow: View {
    let game: BroadcastScoreboardGame

    var body: some View {
        if game.isPreGame {
            HStack(spacing: 8) {
                DynamicIslandMetadataSlot(text: "\(game.away.shortName) \(game.awayStartingPitcherName ?? "선발 미정")", alignment: .leading)
                DynamicIslandMetadataSlot(text: "\(game.home.shortName) \(game.homeStartingPitcherName ?? "선발 미정")", alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    if let baseState = game.baseState {
                        BroadcastBaseDiamond(baseState: baseState, size: 22)
                    }
                    if let countText = game.countText {
                        Text(countText)
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .accessibilityLabel([KBOCountDisplay.balls(game.balls).map { "볼 \($0)" },
                                                 KBOCountDisplay.strikes(game.strikes).map { "스트라이크 \($0)" },
                                                 KBOCountDisplay.outs(game.outs).map { "아웃 \($0)" }].compactMap { $0 }.joined(separator: ", "))
                    }
                }
                if game.batterText != nil || game.pitcherText != nil {
                    HStack(spacing: 12) {
                        DynamicIslandMetadataSlot(text: game.batterText.map { "타자 \($0)" }, alignment: .leading)
                        DynamicIslandMetadataSlot(text: game.pitcherText.map { "투수 \($0)" }, alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }
}

// DynamicIslandMetadataSlot 구조체는 DynamicIslandMetadataSlot 타입의 역할과 값을 정의합니다.
private struct DynamicIslandMetadataSlot: View {
    let text: String?
    let alignment: ScoreboardAlignment

    var body: some View {
        Group {
            if let text {
                Text(text)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            } else {
                Color.clear
                    .frame(height: 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment.frame)
    }
}

#if DEBUG
private let islandPreviewAttributes = FavoriteTeamGameActivityAttributes(
    gameID: "00000000-0000-0000-0000-000000000123",
    favoriteTeamID: "lotte", favoriteTeamName: "롯데 자이언츠", favoriteTeamShortName: "롯데",
    opponentTeamID: "doosan", opponentTeamName: "두산 베어스", opponentTeamShortName: "두산",
    venue: "사직", isHomeGame: true
)

private extension FavoriteTeamGameActivityAttributes.ContentState {
    static func islandPreview(favoriteScore: String = "4", opponentScore: String = "2", hasDetails: Bool = true) -> Self {
        Self(isPreGame: false, favoriteScoreText: favoriteScore, opponentScoreText: opponentScore,
             inningText: "7회 말", summaryText: "LIVE",
             favoriteStartingPitcherName: nil, opponentStartingPitcherName: nil,
             balls: hasDetails ? 2 : nil, strikes: hasDetails ? 1 : nil, outs: hasDetails ? 1 : nil,
             runnerOnFirst: hasDetails ? true : nil, runnerOnSecond: hasDetails ? false : nil,
             runnerOnThird: hasDetails ? true : nil,
             currentBatterName: hasDetails ? "전준우" : nil, currentPitcherName: hasDetails ? "최승용" : nil)
    }
}

#Preview("경기 중 · 접힘", as: .dynamicIsland(.compact), using: islandPreviewAttributes) {
    KBOScoreLiveActivityWidget()
} contentStates: {
    FavoriteTeamGameActivityAttributes.ContentState.islandPreview()
    FavoriteTeamGameActivityAttributes.ContentState.islandPreview(favoriteScore: "10", opponentScore: "12")
}

#Preview("경기 중 · 펼침", as: .dynamicIsland(.expanded), using: islandPreviewAttributes) {
    KBOScoreLiveActivityWidget()
} contentStates: {
    FavoriteTeamGameActivityAttributes.ContentState.islandPreview()
    FavoriteTeamGameActivityAttributes.ContentState.islandPreview(favoriteScore: "10", opponentScore: "12")
    FavoriteTeamGameActivityAttributes.ContentState.islandPreview(hasDetails: false)
}

#Preview("경기 중 · 최소", as: .dynamicIsland(.minimal), using: islandPreviewAttributes) {
    KBOScoreLiveActivityWidget()
} contentStates: {
    FavoriteTeamGameActivityAttributes.ContentState.islandPreview()
    FavoriteTeamGameActivityAttributes.ContentState.islandPreview(favoriteScore: "10", opponentScore: "12")
}
#endif
