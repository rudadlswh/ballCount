//
//  ContentView.swift
//  kboScore
//  기능 설명: 탭 기반 메인 화면 구성과 최상위 화면 전환을 담당합니다.
//  사용자가 경기 상태와 설정을 빠르게 이해하도록 도메인 상태를 화면 구조에 직접 매핑합니다.
//  SwiftUI 상태 갱신, 접근성, 작은 화면 레이아웃에서 정보가 겹치지 않도록 표시 조건을 제한합니다.
//  TODO : 반복되는 화면 조각은 재사용 가능한 컴포넌트로 분리하고 미리보기 케이스를 보강합니다.
//
//  Created by 조경민 on 3/25/26.
//

import SwiftUI

// ContentView 구조체는 화면에 표시되는 SwiftUI 뷰 구성을 담당합니다.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        Group {
            if appModel.shouldShowFavoriteTeamOnboarding {
                FavoriteTeamOnboardingView()
            } else {
                TabView(selection: $appModel.selectedTab) {
                    HomeView()
                        .tag(AppTab.home)
                        .tabItem {
                            Label("홈", systemImage: "house")
                        }

                    StandingsView()
                        .tag(AppTab.standings)
                        .tabItem {
                            Label("순위", systemImage: "list.number")
                        }

                    ScheduleView()
                        .tag(AppTab.schedule)
                        .tabItem {
                            Label("일정", systemImage: "calendar")
                        }

                    AttendanceView()
                        .tag(AppTab.attendance)
                        .tabItem {
                            Label("직관", systemImage: "ticket")
                        }

                    SettingsView()
                        .tag(AppTab.settings)
                        .tabItem {
                            Label("설정", systemImage: "gearshape")
                        }
                }
                .tint(StadiumPalette.app.tint)
            }
        }
        .task {
            await appModel.loadIfNeeded()
            await appModel.refreshAttendanceRecordsFromServer()
        }
        .sheet(
            isPresented: Binding(
                get: { appModel.isNotificationsPresented },
                set: { isPresented in
                    if !isPresented {
                        appModel.dismissNotifications()
                    }
                }
            )
        ) {
            NotificationsView()
        }
        .sheet(
            isPresented: Binding(
                get: { appModel.presentedGameIdentity != nil },
                set: { isPresented in
                    if !isPresented {
                        appModel.dismissPresentedGameDetail()
                    }
                }
            )
        ) {
            if let gameIdentity = appModel.presentedGameIdentity {
                NavigationStack {
                    GameDetailView(gameIdentity: gameIdentity)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("닫기", systemImage: "xmark") {
                                    appModel.dismissPresentedGameDetail()
                                }
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel.previewModel())
}
