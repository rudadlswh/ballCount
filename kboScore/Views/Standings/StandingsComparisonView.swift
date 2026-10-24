import SwiftUI

struct StandingsComparisonView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let season: Int

    @State private var selectedTeamIDs: [String] = []
    @State private var games: [GameDetail]?
    @State private var isLoading = false
    @State private var loadFailed = false

    private var selectedTeams: [Team] {
        selectedTeamIDs.compactMap { id in appModel.teams.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(String(season)) 정규시즌")
                        .font(.headline)
                    Text("상대전적을 비교할 두 팀을 선택하세요.")
                        .font(.subheadline)
                        .foregroundStyle(StadiumPalette.app.textSecondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 200 : 140))], spacing: 10) {
                        ForEach(appModel.teams) { team in
                            teamButton(team)
                        }
                    }

                    if isLoading {
                        ProgressView("상대전적을 불러오는 중")
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else if loadFailed {
                        VStack(spacing: 12) {
                            Text("상대전적을 불러오지 못했습니다.")
                            Button("다시 시도") { Task { await loadGames() } }
                                .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .cardSurface()
                    } else if let games, selectedTeams.count == 2 {
                        comparison(games: games, first: selectedTeams[0], second: selectedTeams[1])
                    } else {
                        Text("\(selectedTeamIDs.count)/2팀 선택")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(StadiumPalette.app.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 80)
                    }
                }
                .padding(22)
            }
            .background(StadiumPalette.app.background.ignoresSafeArea())
            .foregroundStyle(StadiumPalette.app.textPrimary)
            .navigationTitle("팀 비교")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .tint(StadiumPalette.app.tint)
            .task {
                if selectedTeamIDs.isEmpty,
                   let favoriteID = appModel.settings.favoriteTeamID,
                   appModel.teams.contains(where: { $0.id == favoriteID }) {
                    selectedTeamIDs = [favoriteID]
                }
                await loadGames()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func teamButton(_ team: Team) -> some View {
        let isSelected = selectedTeamIDs.contains(team.id)
        return Button {
            if isSelected {
                selectedTeamIDs.removeAll { $0 == team.id }
            } else if selectedTeamIDs.count < 2 {
                selectedTeamIDs.append(team.id)
            } else {
                selectedTeamIDs[1] = team.id
            }
        } label: {
            HStack(spacing: 8) {
                Text(team.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? StadiumPalette.app.tint : StadiumPalette.app.textSecondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(isSelected ? StadiumPalette.app.tabBarSelectionSurface : StadiumPalette.app.elevatedCard,
                        in: RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("comparisonTeam.\(team.id)")
    }

    @ViewBuilder
    private func comparison(games: [GameDetail], first: Team, second: Team) -> some View {
        let record = HeadToHeadRecord.make(games: games, firstTeamID: first.id, secondTeamID: second.id, season: season)
        VStack(alignment: .leading, spacing: 18) {
            Text("\(first.displayName) vs \(second.displayName)")
                .font(.title3.weight(.bold))
                .accessibilityIdentifier("comparisonMatchup")
            if record.gamesPlayed == 0 {
                Text("이번 시즌 두 팀의 종료된 정규시즌 경기가 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(StadiumPalette.app.textSecondary)
            } else {
                Text("총 \(record.gamesPlayed)경기")
                    .font(.subheadline)
                    .foregroundStyle(StadiumPalette.app.textSecondary)
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 16))
                    : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    AppMetric(value: "\(record.firstTeamWins)", label: "\(first.displayName) 승", highlighted: record.firstTeamWins > record.secondTeamWins)
                    AppMetric(value: "\(record.draws)", label: "무승부")
                    AppMetric(value: "\(record.secondTeamWins)", label: "\(second.displayName) 승", highlighted: record.secondTeamWins > record.firstTeamWins)
                }
                Text("\(first.displayName) 기준 \(record.firstTeamWins)승 \(record.secondTeamWins)패 \(record.draws)무")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("comparisonRecord")
            }
            Text("종료된 정규시즌 경기만 집계합니다.")
                .font(.caption)
                .foregroundStyle(StadiumPalette.app.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    @MainActor
    private func loadGames() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            let fetched = try await appModel.fetchTeamComparisonGames(season: season)
            try Task.checkCancellation()
            games = fetched
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
    }
}
