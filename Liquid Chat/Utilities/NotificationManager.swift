//
//  NotificationManager.swift
//  Liquid Chat
//
//  UNUserNotificationCenter delegate: click-to-focus and inline reply
//

import AppKit
import UserNotifications

/// Handles interaction with delivered notifications: clicking one focuses the
/// channel it came from, and the Reply action sends a message without opening
/// the app.
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    static let messageCategoryID = "IRC_MESSAGE"
    static let replyActionID = "IRC_REPLY"

    private weak var chatState: ChatState?

    /// Install as the notification-center delegate and register the message
    /// category with its inline-reply action. Call once at launch.
    func configure(chatState: ChatState) {
        self.chatState = chatState

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let replyAction = UNTextInputNotificationAction(
            identifier: Self.replyActionID,
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Message"
        )
        let messageCategory = UNNotificationCategory(
            identifier: Self.messageCategoryID,
            actions: [replyAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([messageCategory])
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // ChatState already suppresses notifications for the visible channel,
        // so anything that reaches here should be shown.
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let serverHostname = userInfo["server"] as? String
        let channelName = userInfo["channel"] as? String
        let replyText = (response as? UNTextInputNotificationResponse)?.userText
        let isReply = response.actionIdentifier == Self.replyActionID

        Task { @MainActor in
            defer { completionHandler() }
            guard let serverHostname, let channelName else { return }

            if isReply, let replyText, !replyText.isEmpty {
                self.chatState?.sendReply(replyText, toChannelNamed: channelName, onServerHostname: serverHostname)
            } else {
                self.chatState?.focusChannel(named: channelName, onServerHostname: serverHostname)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
