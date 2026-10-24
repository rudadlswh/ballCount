//
//  NotificationsView.swift
//  kboScore
//
//  Created by Codex on 3/25/26.
//

import SwiftUI

struct NotificationsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let palette = notificationPalette

        NavigationStack {
            List {
                Section {
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
                                FilterChip(
                                    title: filter.rawValue,
                                    isSelected: appModel.notificationFilter == filter,
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
                        ForEach(appModel.filteredNotifications) { item in
                                Group {
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
                                .swipeActions(edge: .trailing) {
                                    Button("삭제", systemImage: "trash", role: .destructive) {
                                        appModel.deleteNotification(item.id)
                                    }
                                }
                                .accessibilityAction(named: "삭제") {
                                    appModel.deleteNotification(item.id)
                                }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background {
                palette.background
                .ignoresSafeArea()
            }
            .navigationTitle("알림")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기", systemImage: "xmark") { dismiss() }
                }
            }
            .refreshable {
                await appModel.refreshNotifications()
            }
        }
        .presentationBackground(palette.background)
    }

    private var notificationPalette: StadiumPalette {
        appModel.favoriteStadiumPalette ?? .doosan
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
                .foregroundStyle(palette.secondaryTint)

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
