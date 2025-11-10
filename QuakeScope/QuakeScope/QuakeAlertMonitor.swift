import Foundation
import CoreLocation
import Combine

@MainActor
final class QuakeAlertMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let loc = CLLocationManager()
    private var lastNotifiedIDs = Set<String>()
    private let afad = AfadService()

    // KALICI anahtar
    private let enabledKey = "AlertsEnabled"

    @Published var isActive = false

    override init() {
        super.init()
        loc.delegate = self

        // Uygulama açılınca kalıcı durumdan geri yükle
        let wasEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        if wasEnabled {
            // izni daha önce aldıysan direkt başlat; emin olmak istersen ContentView'da Notifier.requestAuthorization() da çağıracağız
            start(save: false) // kaydı tekrar yazmasın
        }
    }

    // start/stop: kalıcıya yaz
    func start(save: Bool = true) {
        guard !isActive else { return }
        isActive = true
        if save { UserDefaults.standard.set(true, forKey: enabledKey) }

        loc.requestWhenInUseAuthorization()
        loc.startUpdatingLocation()
        Task { await self.tick() }
    }

    func stop(save: Bool = true) {
        guard isActive else { return }
        isActive = false
        if save { UserDefaults.standard.set(false, forKey: enabledKey) }

        loc.stopUpdatingLocation()
    }

    private func scheduleNextTick() {
        guard isActive else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 600) { [weak self] in
            Task { await self?.tick() }
        }
    }

    private func currentCoord() -> CLLocationCoordinate2D? { loc.location?.coordinate }

    private func distKm(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let d = CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        return d / 1000.0
    }

    private func loadSettings() -> AlertSettings { SettingsStore.load() }

    private func shouldNotify(quake: Earthquake, user: CLLocationCoordinate2D, settings: AlertSettings) -> (Bool, Double) {
        let dkm = distKm(user, quake.coord)
        let ok = quake.magnitude >= settings.minMag && dkm <= settings.radiusKm
        return (ok, dkm)
    }

    private func markNotified(_ id: String) { lastNotifiedIDs.insert(id) }

    func tick() async {
        defer { scheduleNextTick() }
        guard isActive, let user = currentCoord() else { return }
        let settings = loadSettings()

        do {
            let quakes = try await afad.fetch(lastHours: 3, minMag: 0.0, limit: 300)
            for q in quakes where !lastNotifiedIDs.contains(q.id) {
                let (ok, dkm) = shouldNotify(quake: q, user: user, settings: settings)
                if ok {
                    Notifier.notify(quake: q, distanceKm: dkm)
                    markNotified(q.id)
                }
            }
        } catch {
            print("Alert tick error:", error)
        }
    }
}
