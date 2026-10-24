//
//  SettingsView.swift
//  kboScore
//
//  Created by Codex on 3/25/26.
//

import SwiftUI
import SafariServices

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    private static let notificationPreferenceRows: [(title: String, keyPath: WritableKeyPath<NotificationPreferences, Bool>)] = [
        ("경기 시작 알림", \.gameStartEnabled),
        ("점수 변경 알림", \.scoreChangeEnabled),
        ("리드 변경 알림", \.leadChangeEnabled),
        ("경기 종료 알림", \.gameEndEnabled),
        ("출루 알림", \.onBaseEnabled),
        ("이닝 교체 알림", \.inningChangeEnabled),
        ("상대팀 알림 끄기", \.favoriteTeamOnlyEnabled),
        ("지고 있을 때 알림 끄기", \.muteWhenLosingEnabled),
        ("우천/취소", \.rainDelay)
    ]

    var body: some View {
        @Bindable var model = appModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AppScreenHeader(title: "설정", subtitle: "응원도, 화면도 나에게 맞게")
                    NavigationLink {
                        FavoriteTeamSelectionView(selection: $model.settings.favoriteTeamID, fallbackPalette: .app)
                    } label: {
                        HStack(spacing: 12) {
                            FavoriteTeamBadge(teamID: appModel.settings.favoriteTeamID)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("응원 팀").font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
                                Text(currentFavoriteTeamDisplayName(appModel: appModel)).font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.subheadline).foregroundStyle(StadiumPalette.app.textSecondary)
                        }.cardSurface(padding: 14, cornerRadius: 18)
                    }.buttonStyle(.plain).accessibilityIdentifier("favoriteTeamSelection")

                    AppSectionTitle(title: "화면 모드")
                    VStack(alignment: .leading, spacing: 12) {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(spacing: 8) { appearanceButtons }
                        } else {
                            HStack(spacing: 6) { appearanceButtons }
                        }
                        Text("모든 응원 팀에 같은 라이트·다크 테마를 적용해요.")
                            .font(.caption2).foregroundStyle(StadiumPalette.app.textSecondary)
                    }.cardSurface(padding: 14)

                    AppSectionTitle(title: "알림")
                    VStack(spacing: 0) {
                        NavigationLink {
                            notificationSettings
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "bell").foregroundStyle(StadiumPalette.app.textSecondary)
                                Text("경기 알림 설정")
                                Spacer()
                                Text(appModel.notificationAuthorizationStatus.rawValue).font(.caption).foregroundStyle(StadiumPalette.app.tint)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Rectangle().fill(StadiumPalette.app.ghostBorder).frame(height: 1)
                        HStack {
                            Text("조용한 시간")
                            Spacer()
                            Text(appModel.settings.quietHours.description).font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
                        }.frame(minHeight: 44)
                    }.font(.subheadline).cardSurface(padding: 16)

                    AppSectionTitle(title: "라이브 액티비티")
                    VStack(spacing: 0) {
                        Toggle("잠금화면에서 경기 보기", isOn: $model.settings.liveActivitiesEnabled).frame(minHeight: 44)
                        Rectangle().fill(StadiumPalette.app.ghostBorder).frame(height: 1)
                        Toggle("경기 시작 시 자동 시작", isOn: $model.settings.liveActivityAutoStartEnabled).frame(minHeight: 44)
                    }.font(.subheadline).tint(StadiumPalette.app.primary).cardSurface(padding: 16)

                    AppSectionTitle(title: "정보")
                    VStack(spacing: 16) {
                        InfoRow(title: "데이터 출처", value: "KBO 공식 기록")
                        PrivacyPolicyRow(url: privacyPolicyURL)
                        InfoRow(title: "앱 버전", value: appVersion)
                    }.font(.subheadline).cardSurface(padding: 16)
                }.padding(.horizontal, 22).padding(.bottom, 18)
            }
            .dashboardScreen()
            .task { await appModel.refreshNotificationAuthorizationStatus() }
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder private var appearanceButtons: some View {
        ForEach(AppearanceOption.allCases) { option in
            let selected = appModel.settings.appearance == option
            Button {
                appModel.settings.appearance = option
            } label: {
                VStack(spacing: 7) {
                    AppearancePhonePreview(option: option)
                    Text(option.rawValue).font(.caption.weight(.semibold))
                        .foregroundStyle(selected ? StadiumPalette.app.tint : StadiumPalette.app.textPrimary)
                    Text(option == .system ? "기기 설정" : option == .light ? "아이보리" : "네이비")
                        .font(.caption2).foregroundStyle(StadiumPalette.app.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 108)
                .background(selected ? StadiumPalette.app.tabBarSelectionSurface : StadiumPalette.app.recessedSurface,
                            in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 14).strokeBorder(StadiumPalette.app.tint, lineWidth: 1)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(StadiumPalette.app.primary)
                            .padding(6)
                    }
                }
            }.buttonStyle(.plain)
                .accessibilityIdentifier("appearance.\(option.id)")
                .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    private var notificationSettings: some View {
        Form {
            Section("경기 알림") { notificationPreferenceToggles(appModel: appModel, palette: .app) }
            Section("기기 권한") {
                InfoRow(title: "권한 상태", value: appModel.notificationAuthorizationStatus.rawValue)
                Button("알림 권한 요청") { Task { await appModel.requestNotificationAuthorization() } }
            }.listRowBackground(StadiumPalette.app.elevatedCard)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumPalette.app.background)
        .tint(StadiumPalette.app.primary)
        .navigationTitle("경기 알림 설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var appVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(shortVersion) (\(build))"
    }

    private var privacyPolicyURL: URL {
        let candidates = [
            ProcessInfo.processInfo.environment["KBO_BACKEND_BASE_URL"],
            Bundle.main.object(forInfoDictionaryKey: "KBOBackendBaseURL") as? String
        ]

        for candidate in candidates {
            guard let baseURL = normalizedBackendBaseURL(from: candidate),
                  let url = URL(string: "privacy", relativeTo: baseURL)?.absoluteURL else {
                continue
            }
            return url
        }

        return URL(string: "https://kboscore-back.onrender.com/privacy")!
    }

    private func normalizedBackendBaseURL(from rawValue: String?) -> URL? {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              rawValue.isEmpty == false,
              rawValue.contains("$(") == false,
              var components = URLComponents(string: rawValue),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false else {
            return nil
        }

        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = trimmedPath.isEmpty ? "/" : "/\(trimmedPath)/"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    @ViewBuilder
    private func notificationPreferenceToggles(appModel: AppModel, palette: StadiumPalette? = nil) -> some View {
        ForEach(Self.notificationPreferenceRows.indices, id: \.self) { index in
            let row = Self.notificationPreferenceRows[index]
            if let palette {
                Toggle(row.title, isOn: notificationPreferenceBinding(row.keyPath, appModel: appModel))
                    .settingsRowStyle(palette)
            } else {
                Toggle(row.title, isOn: notificationPreferenceBinding(row.keyPath, appModel: appModel))
            }
        }
    }

    private func currentFavoriteTeamDisplayName(appModel: AppModel) -> String {
        guard let favoriteTeamID = appModel.settings.favoriteTeamID else {
            return "미설정"
        }
        return appModel.teams.first(where: { $0.id == favoriteTeamID })?.identity.displayName
            ?? Team.displayName(
                forTeamID: favoriteTeamID,
                fallback: TeamIdentity.catalog[favoriteTeamID]?.shortLabel ?? favoriteTeamID
            )
    }

    private func notificationPreferenceBinding(
        _ keyPath: WritableKeyPath<NotificationPreferences, Bool>,
        appModel: AppModel
    ) -> Binding<Bool> {
        Binding {
            appModel.settings.notificationPreferences[keyPath: keyPath]
        } set: { newValue in
            var settings = appModel.settings
            settings.notificationPreferences[keyPath: keyPath] = newValue
            appModel.settings = settings
        }
    }
}

private struct FavoriteTeamSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    @Binding var selection: String?
    let fallbackPalette: StadiumPalette

    private var palette: StadiumPalette {
        appModel.favoriteStadiumPalette ?? fallbackPalette
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("응원 팀 선택")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(palette.textPrimary)

                Text("마이팀, 일정, 알림에서 기준 팀으로 사용됩니다.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)

                VStack(spacing: 8) {
                    if let selectedTeamID = selection,
                       appModel.teams.contains(where: { $0.id == selectedTeamID }) == false {
                        teamSelectionRow(
                            title: Team.displayName(
                                forTeamID: selectedTeamID,
                                fallback: TeamIdentity.catalog[selectedTeamID]?.shortLabel ?? selectedTeamID
                            ),
                            subtitle: "현재 선택된 팀",
                            team: nil,
                            value: selectedTeamID
                        )
                    }

                    ForEach(appModel.teams) { team in
                        teamSelectionRow(
                            title: team.identity.displayName,
                            subtitle: team.shortName,
                            team: team,
                            value: team.id
                        )
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background {
            palette.background
            .ignoresSafeArea()
        }
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle("응원 팀 선택")
        .navigationBarTitleDisplayMode(.inline)
        .doosanInlineNavigationTitle(isEnabled: true)
        .stadiumNavigationChrome(palette)
        .tint(palette.tint)
    }

    private func teamSelectionRow(
        title: String,
        subtitle: String,
        team: Team?,
        value: String?
    ) -> some View {
        let isSelected = selection == value

        return Button {
            selection = value
            dismiss()
        } label: {
            HStack(spacing: 12) {
                if team == nil {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(isSelected ? palette.tint : palette.textSecondary)
                        .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isSelected ? palette.tint : palette.textSecondary.opacity(0.75))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? palette.elevatedCardStrong : palette.elevatedCard)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? palette.tint.opacity(0.35) : palette.ghostBorder, lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct InfoRow: View {
    @Environment(AppModel.self) private var appModel
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title) {
            Text(value).foregroundStyle(StadiumPalette.app.textSecondary)
        }
    }
}

private struct PrivacyPolicyRow: View {
    @Environment(AppModel.self) private var appModel
    let url: URL

    var body: some View {
        NavigationLink {
            PrivacyPolicySafariView(url: url)
                .ignoresSafeArea()
                .toolbar(.visible, for: .navigationBar)
                .navigationTitle("개인정보 처리방침")
                .navigationBarTitleDisplayMode(.inline)
        } label: {
            HStack {
                Text("개인정보 처리방침")
                    .foregroundStyle(appModel.favoriteStadiumPalette?.textPrimary ?? .primary)
                Spacer()
            }
        }
        .accessibilityLabel("개인정보 처리방침")
        .accessibilityHint("개인정보 처리방침 페이지를 엽니다")
    }
}

private struct PrivacyPolicySafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private extension View {
    func settingsRowStyle(_ palette: StadiumPalette) -> some View {
        listRowBackground(palette.elevatedCard)
            .foregroundStyle(palette.textPrimary)
    }
}

#Preview {
    SettingsView()
        .environment(AppModel.previewModel())
}

private struct AppearancePhonePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let option: AppearanceOption
    private var dark: Bool { option == .dark || (option == .system && colorScheme == .dark) }
    private func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    var body: some View {
        VStack(spacing: 4) {
            Capsule().fill(color(dark ? 0xF3F0E2 : 0x101C2D)).frame(width: 15, height: 3)
            RoundedRectangle(cornerRadius: 4).fill(color(dark ? 0x16263A : 0xFCFAF3)).frame(height: 15)
            RoundedRectangle(cornerRadius: 3).fill(color(0xC9273A)).frame(height: 8)
        }.padding(5).frame(width: 39, height: 48)
            .background(color(dark ? 0x0B1524 : 0xF3F0E2), in: RoundedRectangle(cornerRadius: 7))
            .accessibilityHidden(true)
    }
}
