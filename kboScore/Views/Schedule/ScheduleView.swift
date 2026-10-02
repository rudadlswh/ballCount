//
//  ScheduleView.swift
//  kboScore
//  기능 설명: 월별/일별 경기 일정 화면과 경기 선택 흐름을 구성합니다.
//  사용자가 경기 상태와 설정을 빠르게 이해하도록 도메인 상태를 화면 구조에 직접 매핑합니다.
//  SwiftUI 상태 갱신, 접근성, 작은 화면 레이아웃에서 정보가 겹치지 않도록 표시 조건을 제한합니다.
//  TODO : 반복되는 화면 조각은 재사용 가능한 컴포넌트로 분리하고 미리보기 케이스를 보강합니다.
//
//  Created by Codex on 3/26/26.
//

import SwiftUI

// ScheduleDayResultAppearance 열거형는 ScheduleDayResultAppearance 타입의 역할과 값을 정의합니다.
enum ScheduleDayResultAppearance: Equatable, Sendable {
    case win
    case loss
    case draw
    case neutral

    // from 메서드는 이 타입의 주요 동작을 수행합니다.
    static func from(dominantStatus: GameStatus?, favoriteTeamResult: TeamGameResult?) -> ScheduleDayResultAppearance {
        guard dominantStatus == .final, let favoriteTeamResult else {
            return .neutral
        }
        switch favoriteTeamResult {
        case .win:
            return .win
        case .loss:
            return .loss
        case .tie:
            return .draw
        }
    }
}

// ScheduleGameDetailRoute 구조체는 ScheduleGameDetailRoute 타입의 역할과 값을 정의합니다.
struct ScheduleGameDetailRoute: Hashable {
    let stableIdentity: String
    let initialGame: GameDetail

    // 이 초기화 메서드는 인스턴스 생성에 필요한 값을 설정합니다.
    init(game: GameDetail) {
        stableIdentity = game.stableDetailIdentity
        initialGame = game
    }

    // == 메서드는 이 타입의 주요 동작을 수행합니다.
    static func == (lhs: ScheduleGameDetailRoute, rhs: ScheduleGameDetailRoute) -> Bool {
        lhs.stableIdentity == rhs.stableIdentity
    }

    // hash 메서드는 조건을 평가해 참/거짓 결과를 반환합니다.
    func hash(into hasher: inout Hasher) {
        hasher.combine(stableIdentity)
    }
}

// ScheduleView 구조체는 화면에 표시되는 SwiftUI 뷰 구성을 담당합니다.
struct ScheduleView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = ScheduleViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.isDisplayedMonthAvailable,
                       let statusMessage = viewModel.statusMessage {
                        DataStatusBannerView(message: statusMessage)
                    }

                    ScheduleCalendarCardView(
                        viewModel: viewModel
                    )
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
            .dashboardScreen()
            .refreshable {
                await viewModel.refreshDisplayedMonth(appModel: appModel)
            }
            .task(id: scheduleTaskID) {
                await viewModel.loadDisplayedMonth(appModel: appModel)
                await viewModel.refreshLiveScoresIfNeeded(appModel: appModel)
            }
            .task(id: livePollingTaskID) {
                await runLiveScorePollingLoop()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await viewModel.refreshLiveScoresIfNeeded(appModel: appModel)
                }
            }
            .navigationDestination(for: String.self) { gameIdentity in
                GameDetailView(gameIdentity: gameIdentity)
            }
            .navigationDestination(for: ScheduleGameDetailRoute.self) { route in
                GameDetailView(stableIdentity: route.stableIdentity, initialGame: route.initialGame)
            }
        }
    }

    private var scheduleTaskID: String {
        "\(viewModel.scheduleFilter.rawValue)-\(appModel.settings.favoriteTeamID ?? "none")-\(viewModel.displayedMonthKey.yearMonthText)-\(appModel.schedulePostReconciliationRefreshGeneration)"
    }

    private var livePollingTaskID: String {
        "\(scenePhase)-\(viewModel.scheduleFilter.rawValue)-\(viewModel.selectedDate.timeIntervalSince1970)-\(viewModel.displayedMonthKey.yearMonthText)-\(appModel.settings.favoriteTeamID ?? "none")"
    }

    private func runLiveScorePollingLoop() async {
        guard scenePhase == .active else { return }
        await viewModel.refreshLiveScoresIfNeeded(appModel: appModel)
        while !Task.isCancelled, viewModel.shouldPollLiveScores(appModel: appModel) {
            do {
                try await Task.sleep(nanoseconds: 30_000_000_000)
            } catch {
                return
            }
            await viewModel.refreshLiveScoresIfNeeded(appModel: appModel)
        }
    }
}

// ScheduleCalendarCardView 구조체는 화면에 표시되는 SwiftUI 뷰 구성을 담당합니다.
private struct ScheduleCalendarCardView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var calendarDayWidth = 44.0
    @ObservedObject var viewModel: ScheduleViewModel

    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppScreenHeader(title: "일정", subtitle: "우리 팀의 다음 경기를 놓치지 않도록")
            AppSegmentedControl(selection: $viewModel.scheduleFilter, options: ScheduleFilter.allCases.map { ($0, $0.rawValue) })

            if isDisplayedMonthAvailable {
                VStack(alignment: .leading, spacing: 12) {
                HStack {
                    monthNavigationButton(systemName: "chevron.left", targetMonth: previousAvailableMonth)

                    Spacer()

                    VStack(spacing: 2) {
                        Text(appModel.calendarMonthTitle(for: viewModel.displayedMonth))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(appModel.favoriteStadiumPalette?.textPrimary ?? .primary)
                        Text(viewModel.scheduleFilter == .myTeam ? (appModel.favoriteTeam?.displayName ?? monthSummaryText) : monthSummaryText)
                            .font(.caption2)
                            .foregroundStyle(appModel.favoriteStadiumPalette?.textSecondary ?? .secondary)
                    }

                    Spacer()

                    monthNavigationButton(systemName: "chevron.right", targetMonth: nextAvailableMonth)
                }

                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView(.horizontal) {
                        calendarGrid.frame(width: calendarDayWidth * 7 + 36)
                    }
                    Text("달력을 좌우로 밀어 날짜를 확인하세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    calendarGrid
                }

                if viewModel.isLoadingDisplayedMonth {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("공식 월간 일정 불러오는 중")
                            .font(.caption)
                            .foregroundStyle(appModel.favoriteStadiumPalette?.textSecondary ?? .secondary)
                    }
                } else if let statusMessage = viewModel.statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(appModel.favoriteStadiumPalette?.textSecondary ?? .secondary)
                }


                Rectangle().fill(StadiumPalette.app.ghostBorder).frame(height: 1)
                HStack {
                    Text("오늘 \(Calendar.current.component(.day, from: Date()))일")
                        .foregroundStyle(StadiumPalette.app.tint)
                    Spacer()
                    Text("날짜를 선택해 경기 확인").foregroundStyle(StadiumPalette.app.textSecondary)
                }.font(.caption2)
                }.cardSurface(padding: 16, cornerRadius: 22)

                switch viewModel.selectedGamesContentState {
                case .initialLoading:
                    ScheduleLoadingPlaceholderView(
                        title: selectedDayTitle,
                        message: "일정을 불러오는 중입니다"
                    )
                case .loadedEmpty:
                    EmptyStateView(
                        systemImage: "calendar",
                        title: selectedDayTitle,
                        message: emptyMessage
                    )
                case .loaded:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(selectedDayTitle)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(appModel.favoriteStadiumPalette?.textPrimary ?? .primary)
                            Spacer()
                            Text("경기 \(selectedGames.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(appModel.favoriteStadiumPalette?.textPrimary ?? appModel.currentTheme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    appModel.favoriteStadiumPalette?.winDayFill ?? appModel.currentTheme.chipBackground,
                                    in: Capsule()
                                )
                        }

                        ForEach(selectedGames) { game in
                            NavigationLink(value: ScheduleGameDetailRoute(game: game)) {
                                ScheduleGameRow(
                                    game: game,
                                    favoriteTeamID: appModel.settings.favoriteTeamID,
                                    filter: viewModel.scheduleFilter,
                                    onAttendanceToggle: {
                                        appModel.toggleGameAttendance(for: game)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else if viewModel.isLoadingDisplayedMonth {
                ScheduleLoadingPlaceholderView(
                    title: emptyMonthTitle,
                    message: "일정을 불러오는 중입니다"
                )
            } else if viewModel.hasAvailableMonths {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("경기 있는 달로 이동 중")
                        .font(.caption)
                        .foregroundStyle(appModel.favoriteStadiumPalette?.textSecondary ?? .secondary)
                }
            } else {
                EmptyStateView(
                    systemImage: "calendar",
                    title: emptyMonthTitle,
                    message: emptyMonthMessage
                )
            }
        }

    }

    private var calendarDays: [MyTeamCalendarDay] {
        viewModel.calendarDays
    }

    private var selectedGames: [GameDetail] {
        viewModel.selectedDateGames
    }

    private var selectedDayTitle: String {
        viewModel.selectedDate.formatted(.dateTime.year().month().day().weekday(.wide))
    }

    private var monthSummaryText: String {
        viewModel.monthGameCount == 0 ? "등록 경기 없음" : "이달 경기 \(viewModel.monthGameCount)"
    }

    private var isDisplayedMonthAvailable: Bool {
        viewModel.isDisplayedMonthAvailable
    }

    private var previousAvailableMonth: Date? {
        viewModel.previousAvailableMonth
    }

    private var nextAvailableMonth: Date? {
        viewModel.nextAvailableMonth
    }

    private var emptyMonthTitle: String {
        if viewModel.scheduleFilter == .myTeam, appModel.settings.favoriteTeamID == nil {
            return "응원 팀을 선택해 주세요"
        }
        return "표시할 일정이 없습니다"
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(symbol == "일" ? StadiumPalette.app.tint : StadiumPalette.app.textSecondary)
                    .frame(maxWidth: .infinity)
            }

            ForEach(calendarDays) { day in
                Button {
                    viewModel.selectDate(
                        day.date,
                        favoriteTeamID: appModel.settings.favoriteTeamID,
                        attendedGameKeys: appModel.attendedGameKeys
                    )
                    Task {
                        await viewModel.refreshLiveScoresIfNeeded(appModel: appModel)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(dayNumberText(for: day.date))
                            .font(.caption.weight(isSelected(day) ? .bold : .medium))
                            .foregroundStyle(dayNumberColor(for: day))
                            .lineLimit(1)
                            .fixedSize()

                        dayMarker(for: day)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(dayBackground(for: day), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(dayTodayBorderColor(for: day), lineWidth: day.isToday ? (appModel.isStadiumFavoriteSelected ? 0.75 : 1) : 0)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(daySelectionBorderColor(for: day), lineWidth: isSelected(day) ? (appModel.isStadiumFavoriteSelected ? 1.4 : 2) : 0)
                    )
                    .overlay(alignment: .topTrailing) {
                        if day.hasAttendedGame {
                            ScheduleAttendanceAppIcon(size: 12)
                                .padding(3)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dayAccessibilityLabel(for: day))
                .accessibilityAddTraits(isSelected(day) ? .isSelected : [])
            }
        }
    }

    private var emptyMonthMessage: String {
        if viewModel.scheduleFilter == .myTeam, appModel.settings.favoriteTeamID == nil {
            return "응원 팀을 선택하면 경기 있는 달만 일정에 표시됩니다."
        }
        return "현재 일정 데이터에 경기 있는 달이 없습니다."
    }

    private var emptyMessage: String {
        if viewModel.scheduleFilter == .myTeam, appModel.settings.favoriteTeamID == nil {
            return "응원 팀을 선택하면 마이팀 일정이 표시됩니다."
        }
        return "선택한 날짜에는 등록된 경기가 없습니다."
    }

    private func monthNavigationButton(systemName: String, targetMonth: Date?) -> some View {
        Button {
            guard let targetMonth else { return }
            viewModel.changeDisplayedMonth(
                to: targetMonth,
                favoriteTeamID: appModel.settings.favoriteTeamID,
                attendedGameKeys: appModel.attendedGameKeys
            )
        } label: {
            Image(systemName: systemName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(appModel.favoriteStadiumPalette?.secondaryTint ?? appModel.currentTheme.accent)
                .frame(width: 44, height: 44)
                .background(
                    Color.clear,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .opacity(targetMonth == nil ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(targetMonth == nil)
        .accessibilityLabel(systemName == "chevron.left" ? "이전 달" : "다음 달")
    }

    @ViewBuilder
    private func dayMarker(for day: MyTeamCalendarDay) -> some View {
        if let opponentName = opponentMarkerText(for: day) {
            Text(opponentName)
                .font(.system(size: 9))
                .foregroundStyle(markerColor(for: day))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, minHeight: 18)
        } else if viewModel.scheduleFilter == .myTeam {
            Color.clear.frame(height: 18)
        } else {
            ZStack {
                Circle()
                    .fill(markerColor(for: day))
                    .frame(width: day.gameCount > 1 ? 18 : 6, height: day.gameCount > 1 ? 18 : 6)
                    .opacity(day.hasGames ? 1 : 0.12)

                if day.gameCount > 1 {
                    Text("\(day.gameCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            dayGameCountBadgeColor(for: day),
                            in: Capsule()
                        )
                }
            }
            .frame(height: 18)
        }
    }

    private func opponentMarkerText(for day: MyTeamCalendarDay) -> String? {
        guard viewModel.scheduleFilter == .myTeam,
              let opponentTeam = day.opponentTeam else {
            return nil
        }
        return shortOpponentName(for: opponentTeam)
    }

    private func shortOpponentName(for team: Team) -> String {
        switch team.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "samsung":
            return "삼성"
        case "doosan":
            return "두산"
        case "hanwha":
            return "한화"
        case "lotte":
            return "롯데"
        case "kiwoom":
            return "키움"
        default:
            break
        }

        for candidate in [team.shortName, team.displayName, team.name, team.id] {
            let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedCandidate.isEmpty == false {
                return trimmedCandidate
            }
        }
        return team.id
    }

    // isSelected 메서드는 조건을 평가해 참/거짓 결과를 반환합니다.
    private func isSelected(_ day: MyTeamCalendarDay) -> Bool {
        Calendar(identifier: .gregorian).isDate(day.date, inSameDayAs: viewModel.selectedDate)
    }

    // dayNumberColor 메서드는 이 타입의 주요 동작을 수행합니다.
    private func dayNumberColor(for day: MyTeamCalendarDay) -> Color {
        if isSelected(day) {
            return Color.white
        }
        if let palette = appModel.favoriteStadiumPalette {
            return day.isInDisplayedMonth ? palette.textPrimary : palette.textSecondary.opacity(0.6)
        }
        return day.isInDisplayedMonth ? .primary : .secondary.opacity(0.6)
    }

    // markerColor 메서드는 전달된 값을 반영하고 내부 저장 상태를 갱신합니다.
    private func markerColor(for day: MyTeamCalendarDay) -> Color {
        isSelected(day) ? .white : StadiumPalette.app.textSecondary
    }

    // dayResultAppearance 메서드는 이 타입의 주요 동작을 수행합니다.
    private func dayResultAppearance(for day: MyTeamCalendarDay) -> ScheduleDayResultAppearance {
        ScheduleDayResultAppearance.from(
            dominantStatus: day.dominantStatus,
            favoriteTeamResult: day.favoriteTeamResult
        )
    }

    // dayGameCountBadgeColor 메서드는 이 타입의 주요 동작을 수행합니다.
    private func dayGameCountBadgeColor(for day: MyTeamCalendarDay) -> Color {
        switch dayResultAppearance(for: day) {
        case .win:
            return KBOLivePalette.upcoming
        case .loss:
            return KBOLivePalette.live
        case .draw:
            return KBOLivePalette.final
        case .neutral:
            if let palette = appModel.favoriteStadiumPalette {
                return palette.recessedSurface
            }
            return appModel.currentTheme.chipBackground
        }
    }

    // dayBackground 메서드는 이 타입의 주요 동작을 수행합니다.
    private func dayBackground(for day: MyTeamCalendarDay) -> Color {
        isSelected(day) ? StadiumPalette.app.primary : .clear
    }

    // dayTodayBorderColor 메서드는 이 타입의 주요 동작을 수행합니다.
    private func dayTodayBorderColor(for day: MyTeamCalendarDay) -> Color {
        if let palette = appModel.favoriteStadiumPalette {
            return day.isToday ? palette.secondaryTint.opacity(0.85) : .clear
        }
        return day.isToday ? KBOLivePalette.upcoming.opacity(0.9) : .clear
    }

    // daySelectionBorderColor 메서드는 이 타입의 주요 동작을 수행합니다.
    private func daySelectionBorderColor(for day: MyTeamCalendarDay) -> Color {
        if let palette = appModel.favoriteStadiumPalette {
            return isSelected(day) ? palette.tint : .clear
        }
        return isSelected(day) ? appModel.currentTheme.accent : .clear
    }

    private func dayAccessibilityLabel(for day: MyTeamCalendarDay) -> String {
        let dateText = day.date.formatted(.dateTime.month().day())
        let gameText = day.gameCount > 0 ? "경기 \(day.gameCount)개" : "경기 없음"
        return day.hasAttendedGame ? "\(dateText), \(gameText), 직관 경기 있음" : "\(dateText), \(gameText)"
    }

    private func dayNumberText(for date: Date) -> String {
        let day = Calendar(identifier: .gregorian).component(.day, from: date)
        return "\(day)"
    }
}

// ScheduleLoadingPlaceholderView 구조체는 화면에 표시되는 SwiftUI 뷰 구성을 담당합니다.
private struct ScheduleLoadingPlaceholderView: View {
    @Environment(AppModel.self) private var appModel
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.regular)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(appModel.favoriteStadiumPalette?.textPrimary ?? .primary)
            Text(message)
                .font(.caption)
                .foregroundStyle(appModel.favoriteStadiumPalette?.textSecondary ?? .secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 104)
        .padding(.vertical, 8)
    }
}

// DoosanScheduleFilterControl 구조체는 DoosanScheduleFilterControl 타입의 역할과 값을 정의합니다.

// ScheduleGameRow 구조체는 ScheduleGameRow 타입의 역할과 값을 정의합니다.
private struct ScheduleGameRow: View {
    @Environment(AppModel.self) private var appModel
    let game: GameDetail
    let favoriteTeamID: String?
    let filter: ScheduleFilter
    let onAttendanceToggle: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(homeAwayLabel).font(.caption2.weight(.semibold))
                            .foregroundStyle(StadiumPalette.app.tint)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(StadiumPalette.app.tabBarSelectionSurface, in: Capsule())
                        Text(titleText).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                    }
                    Text("\(KBOInningFormatter.korean(game.inningText) ?? game.scheduledStart.formatted(date: .omitted, time: .shortened)) · \(game.venue)")
                        .font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
                    if appModel.isGameAttended(game) {
                        Button(action: onAttendanceToggle) { Label("직관 해제", systemImage: "checkmark.circle.fill") }
                            .font(.caption).buttonStyle(.plain).frame(minHeight: 44)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(status: game.status)
                    if game.status.isLiveLike || game.status == .final {
                        Text("\(game.awayScore.map(String.init) ?? "–") : \(game.homeScore.map(String.init) ?? "–")")
                            .font(.title2.weight(.bold)).monospacedDigit().foregroundStyle(StadiumPalette.app.tint)
                    }
                }
            }
            Text("경기 상세 보기").font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(StadiumPalette.app.recessedSurface, in: RoundedRectangle(cornerRadius: 14))
        }.cardSurface(padding: 16, cornerRadius: 20)
    }

    private var titleText: String {
        "\(game.awayTeam.identity.shortLabel) vs \(game.homeTeam.identity.shortLabel)"
    }

    private var homeAwayLabel: String {
        if filter == .myTeam, let favoriteTeamID {
            if game.awayTeam.id == favoriteTeamID {
                return "원정"
            }
            if game.homeTeam.id == favoriteTeamID {
                return "홈"
            }
        }
        return "리그"
    }
}

// ScheduleAttendanceBadge 구조체는 직관 표시 배지를 렌더링합니다.
private struct ScheduleAttendanceBadge: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        HStack(spacing: 4) {
            ScheduleAttendanceAppIcon(size: 12)
            Text("직관 경기")
                .font(.caption2.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(appModel.favoriteStadiumPalette?.textPrimary ?? appModel.currentTheme.accent)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            appModel.favoriteStadiumPalette?.elevatedCardStrong ?? appModel.currentTheme.chipBackground,
            in: Capsule()
        )
        .accessibilityLabel("직관 경기")
    }
}

// ScheduleAttendanceAppIcon 구조체는 앱 아이콘을 작은 직관 마커로 표시합니다.
private struct ScheduleAttendanceAppIcon: View {
    let size: CGFloat

    var body: some View {
        Image("AttendanceAppIcon")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: max(2, size * 0.22), style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: max(2, size * 0.22), style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.16), radius: 1, y: 0.5)
    }
}



#Preview {
    ScheduleView()
        .environment(AppModel.previewModel())
}
