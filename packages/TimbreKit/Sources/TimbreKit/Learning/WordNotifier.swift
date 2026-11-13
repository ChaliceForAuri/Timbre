import Foundation
import UserNotifications

/// The morning notification (GDR-0027, property 3): one pending request,
/// replaced whenever the Library changes, for the next firing time. Off by
/// default and asks for permission only when turned on. A local
/// notification is the system's own; nothing is sent anywhere.
final class WordNotifier {

    static let identifier = "word-of-the-day"

    enum Authorization: Equatable, Sendable {
        case notAsked
        case granted
        case denied
    }

    private let center = UNUserNotificationCenter.current()
    private let responder = Responder()

    /// Opens the card when the notification is tapped.
    var onOpen: (@MainActor () -> Void)? {
        get { responder.onOpen }
        set { responder.onOpen = newValue }
    }

    init() {
        center.delegate = responder
    }

    func authorization() async -> Authorization {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: .notAsked
        case .authorized, .provisional, .ephemeral: .granted
        case .denied: .denied
        @unknown default: .denied
        }
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func schedule(title: String, body: String, at fire: Date, calendar: Calendar = .current) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }

    /// A menu bar app counts as active all day, so the banner is shown even
    /// then; a tap opens the card.
    private final class Responder: NSObject, UNUserNotificationCenterDelegate {

        var onOpen: (@MainActor () -> Void)?

        nonisolated func userNotificationCenter(
            _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
        ) async {
            await MainActor.run { self.onOpen?() }
        }

        nonisolated func userNotificationCenter(
            _ center: UNUserNotificationCenter, willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            [.banner, .sound]
        }
    }
}
