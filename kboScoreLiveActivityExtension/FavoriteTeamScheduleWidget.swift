//
//  FavoriteTeamScheduleWidget.swift
//  kboScoreLiveActivityExtension
//  기능 설명: 마이팀 일정 위젯의 타임라인과 화면 구성을 담당합니다.
//  사용자가 경기 상태와 설정을 빠르게 이해하도록 도메인 상태를 화면 구조에 직접 매핑합니다.
//  SwiftUI 상태 갱신, 접근성, 작은 화면 레이아웃에서 정보가 겹치지 않도록 표시 조건을 제한합니다.
//  TODO : 반복되는 화면 조각은 재사용 가능한 컴포넌트로 분리하고 미리보기 케이스를 보강합니다.
//

import SwiftUI
import WidgetKit

// FavoriteTeamScheduleWidgetV2 구조체는 FavoriteTeamScheduleWidgetV2 타입의 역할과 값을 정의합니다.
struct FavoriteTeamScheduleWidgetV2: Widget {
    static let kind = FavoriteTeamScheduleWidgetShared.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: FavoriteTeamScheduleWidgetV2Provider()
        ) { entry in
            FavoriteTeamScheduleWidgetV2EntryView(entry: entry)
        }
        .configurationDisplayName("응원팀 일정")
        .description("응원팀 월간 일정을 홈 화면에서 확인합니다.")
        .supportedFamilies([.systemLarge])
    }
}

// FavoriteTeamScheduleWidgetV2Provider 구조체는 FavoriteTeamScheduleWidgetV2Provider 타입의 역할과 값을 정의합니다.
private struct FavoriteTeamScheduleWidgetV2Provider: TimelineProvider {
    // placeholder 메서드는 이 타입의 주요 동작을 수행합니다.
    func placeholder(in context: Context) -> FavoriteTeamScheduleWidgetV2Entry {
        .placeholder(date: Date())
    }

    // getSnapshot 메서드는 이 타입의 주요 동작을 수행합니다.
    func getSnapshot(in context: Context, completion: @escaping (FavoriteTeamScheduleWidgetV2Entry) -> Void) {
        if context.isPreview {
            completion(.preview(date: Date()))
            return
        }
        completion(makeEntry(date: Date()))
    }

    // getTimeline 메서드는 이 타입의 주요 동작을 수행합니다.
    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoriteTeamScheduleWidgetV2Entry>) -> Void) {
        let entry = makeEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .after(entry.refreshAfter)))
    }

    // makeEntry 메서드는 화면이나 도메인 모델에 필요한 값을 생성합니다.
    private func makeEntry(date: Date) -> FavoriteTeamScheduleWidgetV2Entry {
        let loadState = FavoriteTeamScheduleWidgetShared.loadState()
        logLoadedState(loadState)

        guard let favoriteTeamID = loadState.favoriteTeamID, favoriteTeamID.isEmpty == false else {
            return FavoriteTeamScheduleWidgetV2Entry(
                date: date,
                refreshAfter: date.addingTimeInterval(60 * 30),
                content: .noFavorite
            )
        }

        guard let snapshot = loadState.snapshot, snapshot.teamID == favoriteTeamID else {
            let reason = loadState.issue?.fallbackText ?? "일정 데이터를 불러올 수 없습니다"
            return FavoriteTeamScheduleWidgetV2Entry(
                date: date,
                refreshAfter: date.addingTimeInterval(60 * 30),
                content: .unavailable(reason)
            )
        }

        guard FavoriteTeamScheduleWidgetSnapshotMonthPolicy.isCurrentMonth(snapshot: snapshot, now: date) else {
            print(
                "[WidgetSchedule] staleSnapshot ignored snapshotMonth=\(Self.widgetMonthKey(for: snapshot.displayedMonth)) " +
                "currentMonth=\(Self.widgetMonthKey(for: date)) favoriteTeam=\(favoriteTeamID)"
            )
            return FavoriteTeamScheduleWidgetV2Entry(
                date: date,
                refreshAfter: date.addingTimeInterval(60 * 30),
                content: .unavailable("이번 달 일정 데이터를 불러올 수 없습니다")
            )
        }

        return FavoriteTeamScheduleWidgetV2Entry(
            date: date,
            refreshAfter: max(snapshot.refreshAfter, date.addingTimeInterval(60 * 15)),
            content: .content(snapshot)
        )
    }

    // logLoadedState 메서드는 위젯이 공유 저장소에서 읽은 일정 상태를 기록합니다.
    private func logLoadedState(_ loadState: FavoriteTeamScheduleWidgetSharedLoadState) {
        let snapshot = loadState.snapshot
        let monthKey = snapshot.map { Self.widgetMonthKey(for: $0.displayedMonth) } ?? "nil"
        let loadedCount = snapshot?.days.reduce(0) { partialResult, day in
            partialResult + (day.isInDisplayedMonth ? day.gameCount : 0)
        } ?? 0
        print(
            "[WidgetSchedule] load month=\(monthKey) " +
            "favoriteTeam=\(loadState.favoriteTeamID ?? "nil") " +
            "snapshotTeam=\(snapshot?.teamID ?? "nil") " +
            "loadedCount=\(loadedCount)"
        )
    }

    // widgetMonthKey 메서드는 KST 기준 yyyyMM 월 키를 만듭니다.
    private static func widgetMonthKey(for date: Date) -> String {
        FavoriteTeamScheduleWidgetSnapshotMonthPolicy.monthKey(for: date)
    }
}

// FavoriteTeamScheduleWidgetV2Entry 구조체는 FavoriteTeamScheduleWidgetV2Entry 타입의 역할과 값을 정의합니다.
private struct FavoriteTeamScheduleWidgetV2Entry: TimelineEntry {
// Content 열거형는 Content 타입의 역할과 값을 정의합니다.
    enum Content {
        case placeholder(FavoriteTeamScheduleWidgetSnapshot)
        case noFavorite
        case unavailable(String)
        case content(FavoriteTeamScheduleWidgetSnapshot)
    }

    let date: Date
    let refreshAfter: Date
    let content: Content

    // placeholder 메서드는 이 타입의 주요 동작을 수행합니다.
    static func placeholder(date: Date) -> FavoriteTeamScheduleWidgetV2Entry {
        FavoriteTeamScheduleWidgetV2Entry(
            date: date,
            refreshAfter: date.addingTimeInterval(60 * 30),
            content: .placeholder(FavoriteTeamScheduleWidgetV2Preview.sampleSnapshot(referenceDate: date))
        )
    }

    // preview 메서드는 이 타입의 주요 동작을 수행합니다.
    static func preview(date: Date) -> FavoriteTeamScheduleWidgetV2Entry {
        FavoriteTeamScheduleWidgetV2Entry(
            date: date,
            refreshAfter: date.addingTimeInterval(60 * 30),
            content: .content(FavoriteTeamScheduleWidgetV2Preview.sampleSnapshot(referenceDate: date))
        )
    }
}

// FavoriteTeamScheduleWidgetV2EntryView 구조체는 화면에 표시되는 SwiftUI 뷰 구성을 담당합니다.
private struct FavoriteTeamScheduleWidgetV2EntryView: View {
    let entry: FavoriteTeamScheduleWidgetV2Entry

    var body: some View {
        switch entry.content {
        case .placeholder(let snapshot):
            FavoriteTeamSchedulePlaceholderView(snapshot: snapshot)
        default:
            FavoriteTeamScheduleContentView(entry: entry)
                .unredacted()
        }
    }
}

private enum ScheduleWidgetDateFormat {
    static func dayNumber(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return String(calendar.component(.day, from: date))
    }
    static let monthDay = Date.FormatStyle(locale: Locale(identifier: "ko_KR"), timeZone: TimeZone(identifier: "Asia/Seoul")!).month().day()
    static let updated = Date.FormatStyle(locale: Locale(identifier: "ko_KR"), timeZone: TimeZone(identifier: "Asia/Seoul")!).month(.twoDigits).day(.twoDigits).hour().minute()
}

// 배경은 WidgetKit이 제거할 수 있게 분리하고, 콘텐츠 여백은 시스템에 맡깁니다.
private struct FavoriteTeamSchedulePlaceholderView: View {
    let snapshot: FavoriteTeamScheduleWidgetSnapshot

    var body: some View {
        FavoriteTeamScheduleCalendarView(snapshot: snapshot)
            .redacted(reason: .placeholder)
            .containerBackground(for: .widget) { StadiumPalette.app.background }
    }
}

private struct FavoriteTeamScheduleContentView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: FavoriteTeamScheduleWidgetV2Entry

    var body: some View {
        Group {
            switch entry.content {
            case .noFavorite:
                FavoriteTeamScheduleMessageView(
                    title: "응원팀을 선택해 주세요",
                    message: "앱 설정에서 응원팀을 선택하면 월간 일정을 확인할 수 있어요.",
                    symbol: "baseball"
                )
            case .unavailable:
                FavoriteTeamScheduleMessageView(
                    title: "일정을 확인해 주세요",
                    message: "앱을 열어 이번 달 일정을 새로 불러와 주세요.",
                    symbol: "calendar.badge.exclamationmark"
                )
            case .content(let snapshot):
                FavoriteTeamScheduleCalendarView(snapshot: snapshot)
            case .placeholder:
                EmptyView()
            }
        }
        .containerBackground(for: .widget) {
            renderingMode == .fullColor ? StadiumPalette.app.background : Color.clear
        }
    }
}

private struct FavoriteTeamScheduleMessageView: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .widgetAccentable()
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct FavoriteTeamScheduleCalendarView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let snapshot: FavoriteTeamScheduleWidgetSnapshot

    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private var isFullColor: Bool { renderingMode == .fullColor }
    private var primary: Color { isFullColor ? StadiumPalette.app.textPrimary : .primary }
    private var secondary: Color { isFullColor ? StadiumPalette.app.textSecondary : .secondary }
    private var weeks: [[FavoriteTeamScheduleWidgetSnapshot.Day]] {
        stride(from: 0, to: snapshot.days.count, by: 7).map {
            Array(snapshot.days[$0..<min($0 + 7, snapshot.days.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            HStack(spacing: 3) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(index == 0 && isFullColor ? StadiumPalette.app.tint : secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 3) {
                ForEach(weeks.indices, id: \.self) { index in
                    HStack(spacing: 3) {
                        ForEach(weeks[index]) { day in
                            FavoriteTeamScheduleDayCell(day: day)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
            HStack {
                Text(snapshot.state == .emptySchedule ? "표시할 일정이 없습니다" : "홈 · 원정 / 승 · 패 · 무")
                Spacer(minLength: 4)
                Text("갱신 " + snapshot.generatedAt.formatted(ScheduleWidgetDateFormat.updated))
                    .accessibilityLabel("업데이트 \(snapshot.generatedAt.formatted(ScheduleWidgetDateFormat.updated))")
            }
            .font(.system(size: 10))
            .foregroundStyle(secondary)
        }
        .foregroundStyle(primary)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.teamName) · 경기 일정")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(secondary)
                    .lineLimit(1)
                Text(snapshot.monthTitle)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            Text(snapshot.monthSummaryText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isFullColor ? StadiumPalette.app.tint : .primary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background {
                    Capsule().fill(isFullColor ? StadiumPalette.app.tabBarSelectionSurface : Color.primary.opacity(0.12))
                }
                .widgetAccentable()
        }
    }
}

private struct FavoriteTeamScheduleDayCell: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let day: FavoriteTeamScheduleWidgetSnapshot.Day
    private var isFullColor: Bool { renderingMode == .fullColor }
    private var accent: Color { isFullColor ? StadiumPalette.app.tint : .primary }
    private var secondary: Color { isFullColor ? StadiumPalette.app.textSecondary : .secondary }
    private var opponent: String {
        guard day.gameCount > 0 else { return "" }
        return TeamIdentity.catalog[day.opponentTeamID ?? ""]?.shortLabel ?? "경기"
    }
    private var detail: String {
        guard day.gameCount > 0 else { return "" }
        if day.dominantStatus == .cancelled { return "취소" }
        if day.dominantStatus == .rainDelay { return "우천" }
        let role = day.favoriteTeamIsHome.map { $0 ? "홈" : "원정" }
        let result = day.favoriteTeamResult.map {
            switch $0 { case .win: "승"; case .loss: "패"; case .tie: "무" }
        }
        let status = result ?? (day.dominantStatus == .live ? "LIVE" : nil)
        return [role, status, day.gameCount > 1 ? "\(day.gameCount)경기" : nil].compactMap { $0 }.joined(separator: "·")
    }

    var body: some View {
        VStack(spacing: 1) {
            Text(ScheduleWidgetDateFormat.dayNumber(day.date))
                .font(.system(size: 13, weight: day.isToday ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(day.isToday ? accent : (isFullColor ? StadiumPalette.app.textPrimary : .primary))
            Text(opponent.isEmpty ? " " : opponent)
                .font(.system(size: 11, weight: .semibold))
            Text(detail.isEmpty ? " " : detail)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if day.isToday {
                RoundedRectangle(cornerRadius: 9)
                    .fill(accent.opacity(isFullColor ? 0.10 : 0.12))
                    .widgetAccentable()
            }
        }
        .overlay {
            if day.isToday {
                RoundedRectangle(cornerRadius: 9).strokeBorder(accent, lineWidth: 1)
                    .widgetAccentable()
            }
        }
        .opacity(day.isInDisplayedMonth ? 1 : 0.35)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.isToday ? "오늘, " : "")\(day.date.formatted(ScheduleWidgetDateFormat.monthDay)), \(day.gameCount == 0 ? "경기 없음" : opponent + ", " + detail)")
    }
}

// FavoriteTeamScheduleWidgetV2Preview 열거형는 FavoriteTeamScheduleWidgetV2Preview 타입의 역할과 값을 정의합니다.
private enum FavoriteTeamScheduleWidgetV2Preview {
    // sampleSnapshot 메서드는 이 타입의 주요 동작을 수행합니다.
    static func sampleSnapshot(referenceDate: Date) -> FavoriteTeamScheduleWidgetSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        calendar.firstWeekday = 1
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate
        let monthInterval = calendar.dateInterval(of: .month, for: monthStart) ?? DateInterval(start: monthStart, duration: 60 * 60 * 24 * 30)
        let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) ?? monthInterval
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthInterval.start) ?? monthInterval.start
        let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthEnd) ?? monthInterval

        var days: [FavoriteTeamScheduleWidgetSnapshot.Day] = []
        var cursor = firstWeek.start
        var offset = 0
        while cursor < lastWeek.end {
            let isInMonth = calendar.isDate(cursor, equalTo: monthStart, toGranularity: .month)
            let isToday = calendar.isDate(cursor, inSameDayAs: referenceDate)
            let sampleGame: (count: Int, teamID: String?, result: FavoriteTeamScheduleWidgetTeamResult?, status: FavoriteTeamScheduleWidgetGameStatus?)?
            let sampleHomeGame: Bool?
            switch offset {
            case 9:
                sampleGame = (1, "hanwha", .win, .final)
                sampleHomeGame = true
            case 13:
                sampleGame = (1, "doosan", nil, .upcoming)
                sampleHomeGame = false
            case 18:
                sampleGame = (2, "samsung", .loss, .final)
                sampleHomeGame = true
            default:
                sampleGame = nil
                sampleHomeGame = nil
            }

            days.append(
                FavoriteTeamScheduleWidgetSnapshot.Day(
                    date: cursor,
                    isInDisplayedMonth: isInMonth,
                    isToday: isToday,
                    gameCount: sampleGame?.count ?? 0,
                    dominantStatus: sampleGame?.status,
                    opponentTeamID: sampleGame?.teamID,
                    favoriteTeamIsHome: sampleHomeGame,
                    favoriteTeamResult: sampleGame?.result
                )
            )
            offset += 1
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? lastWeek.end
        }

        return FavoriteTeamScheduleWidgetSnapshot(
            generatedAt: referenceDate,
            refreshAfter: referenceDate.addingTimeInterval(60 * 60 * 6),
            teamID: "lotte",
            teamName: "롯데 자이언츠",
            teamShortName: "롯데",
            displayedMonth: monthStart,
            monthTitle: {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ko_KR")
                formatter.calendar = calendar
                formatter.dateFormat = "yyyy년 M월"
                return formatter.string(from: monthStart)
            }(),
            monthSummaryText: "이달 경기 4",
            state: .ready,
            days: days
        )
    }
}

private extension FavoriteTeamScheduleWidgetSharedLoadIssue {
    var fallbackText: String {
        switch self {
        case .appGroupUnavailable:
            "공유 컨테이너에 접근할 수 없습니다"
        case .noSharedFile:
            "공유 일정 파일이 없습니다"
        case .fileReadFailed, .fileDecodeFailed:
            "공유 일정 데이터를 읽을 수 없습니다"
        }
    }
}

// FavoriteTeamLockScreenScheduleWidget 구조체는 잠금화면 전용 응원팀 일정 위젯을 정의합니다.
struct FavoriteTeamLockScreenScheduleWidget: Widget {
    static let kind = "FavoriteTeamLockScreenScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: FavoriteTeamScheduleWidgetV2Provider()
        ) { entry in
            FavoriteTeamLockScreenScheduleView(entry: entry)
        }
        .configurationDisplayName("응원팀 가까운 일정")
        .description("응원팀의 가까운 경기 일정을 잠금화면에서 확인합니다.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// FavoriteTeamLockScreenScheduleView 구조체는 가까운 5일과 상대팀을 달력 형태로 표시합니다.
private struct FavoriteTeamLockScreenScheduleView: View {
    let entry: FavoriteTeamScheduleWidgetV2Entry

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    var body: some View {
        Group {
            switch entry.content {
            case .placeholder(let snapshot), .content(let snapshot):
                schedule(snapshot)
            case .noFavorite:
                message("응원팀을 선택해 주세요")
            case .unavailable:
                message("일정 데이터를 불러올 수 없습니다")
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private func schedule(_ snapshot: FavoriteTeamScheduleWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(snapshot.teamShortName) · 가까운 일정")
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            HStack(spacing: 0) {
                ForEach(nearbyDays(in: snapshot)) { day in
                    VStack(spacing: 2) {
                        Text(ScheduleWidgetDateFormat.dayNumber(day.date))
                            .font(.caption.weight(isToday(day) ? .bold : .medium))
                            .foregroundStyle(isToday(day) ? .primary : .secondary)
                            .underline(isToday(day))

                        if let opponentName = opponentName(for: day) {
                            Text(opponentName)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        } else {
                            Color.clear
                                .frame(height: 12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(isToday(day) ? "오늘" : day.date.formatted(ScheduleWidgetDateFormat.monthDay)), \(opponentName(for: day) ?? "경기 없음")")
                }
            }
        }
    }

    private func nearbyDays(in snapshot: FavoriteTeamScheduleWidgetSnapshot) -> [FavoriteTeamScheduleWidgetSnapshot.Day] {
        let days = snapshot.days.sorted { $0.date < $1.date }
        guard days.count > 5 else { return days }

        let todayIndex = days.firstIndex(where: isToday) ?? 0
        let startIndex = min(max(todayIndex - 2, 0), days.count - 5)
        return Array(days[startIndex..<(startIndex + 5)])
    }

    private func isToday(_ day: FavoriteTeamScheduleWidgetSnapshot.Day) -> Bool {
        calendar.isDate(day.date, inSameDayAs: entry.date)
    }

    private func opponentName(for day: FavoriteTeamScheduleWidgetSnapshot.Day) -> String? {
        guard day.gameCount > 0, let teamID = day.opponentTeamID else { return nil }
        return TeamIdentity.catalog[teamID]?.shortLabel
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// FavoriteTeamNextGameCircularWidget 구조체는 가장 가까운 응원팀 경기 한 건을 표시합니다.
struct FavoriteTeamNextGameCircularWidget: Widget {
    static let kind = "FavoriteTeamNextGameCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: FavoriteTeamScheduleWidgetV2Provider()
        ) { entry in
            FavoriteTeamNextGameCircularView(entry: entry)
        }
        .configurationDisplayName("응원팀 다음 경기")
        .description("응원팀의 가장 가까운 다음 경기를 잠금화면에서 확인합니다.")
        .supportedFamilies([.accessoryCircular])
    }
}

// FavoriteTeamNextGameCircularView 구조체는 다음 경기 상대팀과 날짜를 원형 영역에 표시합니다.
private struct FavoriteTeamNextGameCircularView: View {
    let entry: FavoriteTeamScheduleWidgetV2Entry

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Group {
                switch entry.content {
                case .placeholder(let snapshot), .content(let snapshot):
                    if let game = nextGame(in: snapshot) {
                        let opponent = TeamIdentity.catalog[game.opponentTeamID ?? ""]?.shortLabel ?? "경기"
                        VStack(spacing: 1) {
                            Text(opponent)
                                .font(.system(size: 16, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text(dateLabel(for: game.date))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("다음 경기, \(opponent), \(dateLabel(for: game.date))")
                    } else {
                        emptyLabel("경기 없음")
                    }
                case .noFavorite:
                    emptyLabel("응원팀 없음")
                case .unavailable:
                    emptyLabel("확인 필요")
                }
            }
        }
        .multilineTextAlignment(.center)
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private func nextGame(in snapshot: FavoriteTeamScheduleWidgetSnapshot) -> FavoriteTeamScheduleWidgetSnapshot.Day? {
        let today = calendar.startOfDay(for: entry.date)
        return snapshot.days
            .filter {
                $0.gameCount > 0
                    && calendar.startOfDay(for: $0.date) >= today
                    && $0.dominantStatus != .final
                    && $0.dominantStatus != .cancelled
            }
            .min { $0.date < $1.date }
    }

    private func dateLabel(for date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: entry.date) {
            return "오늘"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: entry.date),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "내일"
        }
        let components = calendar.dateComponents([.month, .day], from: date)
        return "\(components.month ?? 0)/\(components.day ?? 0)"
    }

    private func emptyLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .minimumScaleFactor(0.75)
    }
}

#Preview("월간 일정 · 4/5/6주", as: .systemLarge) {
    FavoriteTeamScheduleWidgetV2()
} timeline: {
    FavoriteTeamScheduleWidgetV2Entry.preview(date: ISO8601DateFormatter().date(from: "2026-02-13T09:00:00Z")!)
    FavoriteTeamScheduleWidgetV2Entry.preview(date: ISO8601DateFormatter().date(from: "2026-10-02T09:00:00Z")!)
    FavoriteTeamScheduleWidgetV2Entry.preview(date: ISO8601DateFormatter().date(from: "2026-08-15T09:00:00Z")!)
}

#Preview("응원팀 미선택 · 일정 불러오기", as: .systemLarge) {
    FavoriteTeamScheduleWidgetV2()
} timeline: {
    FavoriteTeamScheduleWidgetV2Entry(date: Date(), refreshAfter: Date(), content: .noFavorite)
    FavoriteTeamScheduleWidgetV2Entry(date: Date(), refreshAfter: Date(), content: .unavailable("미리보기"))
}

#Preview(as: .accessoryRectangular) {
    FavoriteTeamLockScreenScheduleWidget()
} timeline: {
    FavoriteTeamScheduleWidgetV2Entry.preview(date: Date())
}

#Preview(as: .accessoryCircular) {
    FavoriteTeamNextGameCircularWidget()
} timeline: {
    FavoriteTeamScheduleWidgetV2Entry.preview(date: Date())
}
