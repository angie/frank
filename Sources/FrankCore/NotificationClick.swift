import Foundation

public enum NotificationClick {
    public static func url(from userInfo: [AnyHashable: Any]) -> URL? {
        guard let string = userInfo["url"] as? String, !string.isEmpty else { return nil }
        return URL(string: string)
    }
}
