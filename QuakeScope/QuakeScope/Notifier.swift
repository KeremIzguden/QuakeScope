import UserNotifications

enum Notifier {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let ok = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return ok
        } catch { return false }
    }

    static func notify(quake: Earthquake, distanceKm: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Yakınınızda Deprem (M\(String(format: "%.1f", quake.magnitude)))"
        content.body  = "\(quake.place) – \(String(format: "%.0f", distanceKm)) km uzakta • \(quake.time.formatted(date: .omitted, time: .shortened))"
        content.sound = .default

        let req = UNNotificationRequest(identifier: "eq-\(quake.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
