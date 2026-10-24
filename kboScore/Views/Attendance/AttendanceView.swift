import SwiftUI

struct AttendanceView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let dashboard = appModel.attendanceDashboard
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppScreenHeader(title: "직관 기록", subtitle: "우리 팀과 함께한 나의 야구")
                    if appModel.settings.favoriteTeamID == nil {
                        EmptyStateView(systemImage: "person.crop.circle.badge.questionmark", title: "응원팀을 선택해주세요", message: "응원팀 경기의 직관 기록을 모아 보여드립니다.")
                    } else {
                        overallSummary(dashboard.overall)
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(spacing: 12) {
                                sideSummary("홈", icon: "house", summary: dashboard.home)
                                sideSummary("원정", icon: "airplane", summary: dashboard.away)
                            }
                        } else {
                            HStack(spacing: 12) {
                                sideSummary("홈", icon: "house", summary: dashboard.home)
                                sideSummary("원정", icon: "airplane", summary: dashboard.away)
                            }
                        }
                        if !dashboard.hasGames {
                            EmptyStateView(systemImage: "ticket", title: "직관 기록 없음", message: "경기 상세에서 직관한 경기로 표시하면 이곳에 기록됩니다.")
                        } else {
                            records("예정된 직관", records: dashboard.upcomingGames)
                            records("지난 직관", records: dashboard.pastGames)
                            Text("경기를 선택하면 상세 기록을 볼 수 있어요.")
                                .font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
            .dashboardScreen()
            .navigationDestination(for: String.self) { GameDetailView(gameIdentity: $0) }
            .task { await appModel.refreshAttendanceRecordsFromServer() }
        }
    }

    private func overallSummary(_ summary: AttendanceRecordSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("전체 기록").font(.caption.weight(.semibold))
                    .foregroundStyle(StadiumPalette.app.tint)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(StadiumPalette.app.tabBarSelectionSurface, in: Capsule())
                Spacer()
                Text(appModel.favoriteTeam?.identity.displayName ?? "")
                    .font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
            }
            Text("나의 직관 성적").font(.subheadline.weight(.semibold))
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) { overallMetrics(summary) }
            } else {
                HStack(spacing: 8) { overallMetrics(summary) }
            }
        }.cardSurface(padding: 16, cornerRadius: 22)
    }

    @ViewBuilder private func overallMetrics(_ summary: AttendanceRecordSummary) -> some View {
        AppMetric(value: summary.gamesText, label: "전체 직관")
        AppMetric(value: "\(summary.wins)승 \(summary.losses)패", label: "\(summary.draws)무")
        AppMetric(value: summary.winPercentageText, label: "직관 승률", highlighted: true)
    }

    private func sideSummary(_ title: String, icon: String, summary: AttendanceRecordSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(StadiumPalette.app.textSecondary)
                Text(title).font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Text(summary.gamesText).font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
            }
            Text(summary.recordText).font(.caption).lineLimit(1).minimumScaleFactor(0.75)
            HStack {
                Text("승률").font(.caption2).foregroundStyle(StadiumPalette.app.textSecondary)
                Spacer()
                Text(summary.winPercentageText).font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(StadiumPalette.app.tint)
            }
        }.frame(maxWidth: .infinity).cardSurface(padding: 14, cornerRadius: 18)
    }

    @ViewBuilder private func records(_ title: String, records: [AttendanceGameRecord]) -> some View {
        if !records.isEmpty {
            AppSectionTitle(title: title, detail: "\(records.count)경기")
            VStack(spacing: 0) {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    if index > 0 { Rectangle().fill(StadiumPalette.app.ghostBorder).frame(height: 1) }
                    NavigationLink(value: record.gameIdentity) {
                        AttendanceGameRecordRow(record: record)
                    }.buttonStyle(.plain)
                }
            }.cardSurface(padding: 16, cornerRadius: 20)
        }
    }
}

private struct AttendanceGameRecordRow: View {
    let record: AttendanceGameRecord

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(record.side.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(record.isUpcomingAttendance ? StadiumPalette.app.tint : StadiumPalette.app.textSecondary)
                        .padding(.horizontal, record.isUpcomingAttendance ? 10 : 0)
                        .padding(.vertical, 4)
                        .background(record.isUpcomingAttendance ? StadiumPalette.app.tabBarSelectionSurface : .clear, in: Capsule())
                    Text(record.matchupText).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                }
                Text("\(record.gameDate.formatted(.dateTime.month().day().weekday())) · \(record.stadium)")
                    .font(.caption).foregroundStyle(StadiumPalette.app.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            if !record.isUpcomingAttendance {
                VStack(alignment: .trailing, spacing: 8) {
                    Text(record.scoreText).font(.headline).monospacedDigit()
                    Text(resultText).font(.caption)
                }.foregroundStyle(record.result == .win ? StadiumPalette.app.tint : StadiumPalette.app.textPrimary)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
        }.padding(.vertical, 8)
    }

    private var resultText: String {
        switch record.result {
        case .win: "승"
        case .loss: "패"
        case .tie: "무"
        case nil: record.gameStatus.title
        }
    }
}

#Preview { AttendanceView().environment(AppModel.previewModel()) }
