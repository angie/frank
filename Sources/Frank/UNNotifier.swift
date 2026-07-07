import FrankCore
import UserNotifications

struct UNNotifier: UserNotifier {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func post(_ content: NotificationContent) async {
        let notification = UNMutableNotificationContent()
        notification.title = content.title
        notification.body = content.body
        notification.userInfo = ["url": content.url.absoluteString]

        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: notification, trigger: nil)
        )
    }
}
