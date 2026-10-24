import Foundation
import Testing
@testable import kboScore

@MainActor
struct AccessibilityPresentationTests {
    @Test func liveGameAnnouncesScoreCountsAndOccupiedBases() throws {
        let label = HomeHeroGamePresentation.accessibilityLabel(for: try summary(status: .live))
        #expect(label.contains("원정 점수 2, 홈 점수 3"))
        #expect(label.contains("3회 초"))
        #expect(label.contains("볼 2, 스트라이크 1, 아웃 1"))
        #expect(label.contains("1루, 3루 주자 있음"))
    }

    @Test func unknownLiveCountsAreNotAnnouncedAsZero() throws {
        let label = HomeHeroGamePresentation.accessibilityLabel(for: try summary(status: .rainDelay, missingSituation: true))
        #expect(label.contains("볼 정보 없음, 스트라이크 정보 없음, 아웃 정보 없음"))
        #expect(!label.contains("주자 없음"))
        #expect(HomeHeroGamePresentation.basesAccessibilityLabel(for: RunnerState(first: false, second: false, third: false)) == "주자 없음")
    }

    @Test func upcomingAndFinishedGamesDoNotAnnounceStaleCounts() throws {
        let upcoming = HomeHeroGamePresentation.accessibilityLabel(for: try summary(status: .upcoming))
        #expect(upcoming.contains("원정 선발 김투수"))
        #expect(!upcoming.contains("원정 점수"))
        for status in [GameStatus.upcoming, .final, .cancelled] {
            let label = HomeHeroGamePresentation.accessibilityLabel(for: try summary(status: status))
            #expect(!label.contains("스트라이크"))
            #expect(!label.contains("주자 있음"))
        }
        let final = HomeHeroGamePresentation.accessibilityLabel(for: try summary(status: .final))
        #expect(final.contains("원정 점수 2, 홈 점수 3"))
    }

    private func summary(status: GameStatus, missingSituation: Bool = false) throws -> GameSummary {
        let teams = MockKBOData.makeBootstrap().teams
        return GameSummary(
            id: UUID(), scheduledStart: Date(timeIntervalSince1970: 1_777_366_200), venue: "잠실",
            awayTeam: try #require(teams.first { $0.id == "doosan" }),
            homeTeam: try #require(teams.first { $0.id == "lg" }),
            awayScore: 2, homeScore: 3, status: status, inningText: "Top 3",
            recentEvent: nil, isMyTeamGame: true,
            awayStartingPitcherName: "김투수", homeStartingPitcherName: "임찬규",
            currentPitcherName: nil, currentBatterName: nil,
            bases: missingSituation ? nil : RunnerState(first: true, second: false, third: true),
            baseRunners: nil, balls: missingSituation ? nil : 2,
            strikes: missingSituation ? nil : 1, outs: missingSituation ? nil : 1
        )
    }
}
