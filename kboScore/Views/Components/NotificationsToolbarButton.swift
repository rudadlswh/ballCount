//
//  NotificationsToolbarButton.swift
//  kboScore
//  기능 설명: 상단 툴바에서 알림 화면 진입 버튼을 제공합니다.
//  사용자가 경기 상태와 설정을 빠르게 이해하도록 도메인 상태를 화면 구조에 직접 매핑합니다.
//  SwiftUI 상태 갱신, 접근성, 작은 화면 레이아웃에서 정보가 겹치지 않도록 표시 조건을 제한합니다.
//  TODO : 반복되는 화면 조각은 재사용 가능한 컴포넌트로 분리하고 미리보기 케이스를 보강합니다.
//
//  Created by Codex on 3/26/26.
//

import SwiftUI

// NotificationsToolbarButton 구조체는 NotificationsToolbarButton 타입의 역할과 값을 정의합니다.
struct NotificationsToolbarButton: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        notificationButton
    }

    private var notificationButton: some View {
        Button {
            appModel.presentNotifications()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(StadiumPalette.app.textPrimary)

                notificationBadge(
                    count: appModel.unreadNotificationsCount,
                    background: StadiumPalette.app.primary,
                    xOffset: 10,
                    yOffset: -8
                )
            }
            .frame(minWidth: 44, minHeight: 44)
            .background(StadiumPalette.app.bellControlSurface, in: Circle())
        }
        .accessibilityLabel("알림")
        .accessibilityValue(notificationAccessibilityValue(unreadCount: appModel.unreadNotificationsCount))
    }
}

@ViewBuilder
private func notificationBadge(count: Int, background: Color, xOffset: CGFloat, yOffset: CGFloat) -> some View {
    if count > 0 {
        Text(notificationBadgeText(for: count))
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(background, in: Capsule())
            .offset(x: xOffset, y: yOffset)
    }
}

private func notificationBadgeText(for count: Int) -> String {
    count > 99 ? "99+" : "\(count)"
}

private func notificationAccessibilityValue(unreadCount: Int) -> String {
    unreadCount > 0 ? "읽지 않은 알림 \(unreadCount)개" : "새 알림 없음"
}

extension View {
    // notificationsToolbarButton 메서드는 이 타입의 주요 동작을 수행합니다.
    func notificationsToolbarButton() -> some View {
        modifier(NotificationsToolbarButtonModifier())
    }
}

// NotificationsToolbarButtonModifier 구조체는 SwiftUI 뷰 스타일과 동작을 재사용 가능한 형태로 적용합니다.
private struct NotificationsToolbarButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NotificationsToolbarButton()
                }
            }
    }
}
