//
//  NotificationsView.swift
//  kboScore
//
//  Created by Codex on 3/25/26.
//

import SwiftUI

struct NotificationsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let palette = notificationPalette

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let statusMessage = appModel.statusMessage(for: .notifications) {
                        NotificationsStatusBannerView(message: statusMessage, palette: palette)
                    }

                    if !appModel.filteredNotifications.isEmpty {
                        Text("최근 알림")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(NotificationListFilter.allCases) { filter in
                                NotificationsFilterChip(
                                    title: filter.rawValue,
                                    isSelected: appModel.notificationFilter == filter,
                                    palette: palette,
                                    action: { appModel.notificationFilter = filter }
                                )
                            }
                        }
                        .padding(.horizontal, 1)
                    }

                    if appModel.filteredNotifications.isEmpty {
                        NotificationsEmptyStateView(
                            systemImage: "bell.slash",
                            title: "알림이 없습니다",
                            message: "선택한 조건에 맞는 알림 내역이 없습니다.",
                            palette: palette
                        )
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(appModel.filteredNotifications) { item in
                                NotificationSwipeToDeleteRow {
                                    appModel.deleteNotification(item.id)
                                } content: {
                                    if let gameIdentity = item.preferredGameNavigationIdentity {
                                        NavigationLink {
                                            GameDetailView(gameIdentity: gameIdentity)
                                                .task {
                                                    appModel.markNotificationRead(item.id)
                                                }
                                        } label: {
                                            NotificationCardView(item: item)
                                        }
                                        .buttonStyle(.plain)
                                        .simultaneousGesture(TapGesture().onEnded {
                                            _ = appModel.notificationGameDetailNavigationIdentity(for: item)
                                        })
                                    } else {
                                        Button {
                                            _ = appModel.notificationGameDetailNavigationIdentity(for: item)
                                            appModel.markNotificationRead(item.id)
                                        } label: {
                                            NotificationCardView(item: item)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background {
                LinearGradient(
                    colors: [palette.background, palette.sectionBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .navigationTitle("알림")
            .modifier(NotificationsNavigationBarModifier(palette: palette))
            .refreshable {
                await appModel.refreshNotifications()
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(palette.background)
    }

    private var notificationPalette: StadiumPalette {
        appModel.favoriteStadiumPalette ?? .doosan
    }
}

private struct NotificationSwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: Content
    @State private var isRevealed = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("삭제", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 76)
                    .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Color.red, in: RoundedRectangle(cornerRadius: 16))

            content
                .offset(x: max(-76, min(0, (isRevealed ? -76 : 0) + dragOffset)))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            withAnimation(.easeOut(duration: 0.2)) {
                                isRevealed = value.translation.width < -40 ||
                                    (isRevealed && value.translation.width < 40)
                                dragOffset = 0
                            }
                        }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct NotificationsNavigationBarModifier: ViewModifier {
    let palette: StadiumPalette

    func body(content: Content) -> some View {
        content
            .toolbarColorScheme(palette.usesLightForegroundStyle ? .light : .dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(palette.navigationSurface, for: .navigationBar)
    }
}

private struct NotificationsFilterChip: View {
    let title: String
    let isSelected: Bool
    let palette: StadiumPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : palette.textSecondary)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(
                    Capsule()
                        .fill(isSelected ? DoosanPalette.primary : palette.elevatedCardStrong)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? DoosanPalette.primary.opacity(0.65) : palette.ghostBorder, lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct NotificationsEmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    let palette: StadiumPalette

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(palette.textSecondary)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .cardSurface(fillColor: palette.sectionBackground, showsGhostBorder: true)
    }
}

private struct NotificationsStatusBannerView: View {
    let message: String
    let palette: StadiumPalette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondary)

            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.textSecondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.sectionBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.ghostBorder, lineWidth: 0.75)
        )
    }
}

#Preview {
    NotificationsView()
        .environment(AppModel.previewModel())
}
