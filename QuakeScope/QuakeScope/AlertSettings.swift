import SwiftUI

struct AlertSettings: Codable {
    var radiusKm: Double = 150   // yarıçap
    var minMag: Double = 3.0     // bildirim eşiği
}

enum SettingsStore {
    static let key = "AlertSettings"
    static func load() -> AlertSettings {
        if let d = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode(AlertSettings.self, from: d) { return s }
        return AlertSettings()
    }
    static func save(_ s: AlertSettings) {
        if let d = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }
}

struct AlertSettingsView: View {
    @State private var s = SettingsStore.load()
    var onSaved: (() -> Void)?

    var body: some View {
        Form {
            Section("Bildirim Eşiği") {
                Stepper(value: $s.radiusKm, in: 25...500, step: 25) {
                    Text("Yarıçap: \(Int(s.radiusKm)) km")
                }
                Stepper(value: $s.minMag, in: 0...7, step: 0.1) {
                    Text("Min. büyüklük: \(String(format: "%.1f", s.minMag))")
                }
            }
            Section {
                Button("Kaydet") {
                    SettingsStore.save(s)
                    onSaved?()
                }
            }
        }
        .navigationTitle("Deprem Uyarı Ayarları")
    }
}
