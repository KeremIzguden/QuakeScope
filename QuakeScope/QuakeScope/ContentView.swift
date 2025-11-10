import SwiftUI
import MapKit
import Combine
import CoreLocation


enum DataSource: String, CaseIterable, Identifiable {
    case usgs = "USGS"
    case afad = "AFAD"
    case kandilli = "Kandilli"
    var id: String { rawValue }
}


enum HoursWindow: Int, CaseIterable, Identifiable {
    case h1 = 1, h3 = 3, h7 = 7, h24 = 24
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .h1:  return "1s"
        case .h3:  return "3s"
        case .h7:  return "7s"
        case .h24: return "24s"
        }
    }
}


@MainActor
final class QuakeViewModel: ObservableObject {
    @Published var quakes: [Earthquake] = []
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.0, longitude: 35.0),
        span: MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 15)
    )
    @Published var isLoading = false
    @Published var error: String?

    @Published var source: DataSource = .usgs
    @Published var hours: HoursWindow = .h24

    private let service = QuakeService()
    private let afadService = AfadService()
    private let kandilliService = KandilliService()

    private var loadTask: Task<Void, Never>?

    func load() async {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            isLoading = true
            defer { isLoading = false }

            do {
                let list: [Earthquake]
                switch source {
                case .usgs:
                    let feed: QuakeFeed = (hours == .h1) ? .lastHour : .lastDay
                    let fetched = try await service.fetch(feed, minMag: 0.0)
                    list = applyHoursFilter(to: fetched)

                case .afad:
                    let fetched = try await afadService.fetch(
                        lastHours: hours.rawValue,
                        minMag: 0.0,
                        limit: 300
                    )
                    list = fetched
                    region = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 39.0, longitude: 35.0),
                        span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)
                    )

                case .kandilli:
                    let fetched = try await kandilliService.fetch(limit: 100)
                    list = applyHoursFilter(to: fetched)
                    region = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 39.0, longitude: 35.0),
                        span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)
                    )
                }

                quakes = list.sorted { $0.time > $1.time }
                error = nil
            } catch {
                #if DEBUG
                print("Load error:", error)
                #endif
                self.error = "Veri alınamadı. \(error.localizedDescription)"
                self.quakes = []
            }
        }
        await loadTask?.value
    }

    private func applyHoursFilter(to items: [Earthquake]) -> [Earthquake] {
        let cutoff = Date().addingTimeInterval(-Double(hours.rawValue) * 3600)
        return items.filter { $0.time >= cutoff }
    }
}

// Görünüm
struct ContentView: View {
    @StateObject var vm = QuakeViewModel()
    @StateObject var loc = LocationManager()
    @StateObject var alertMonitor = QuakeAlertMonitor() // 🔔 bildirim izleyicisi

    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.0, longitude: 35.0),
        span: MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 15)
    ))
    @State private var didZoomToUser = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                // HARİTA
                Map(position: $mapPosition) {
                    UserAnnotation()
                    ForEach(vm.quakes) { q in
                        Annotation("", coordinate: q.coord) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.25))
                                    .frame(width: size(for: q.magnitude), height: size(for: q.magnitude))
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                }
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .onAppear { loc.request() }
                .onReceive(loc.$coordinate.compactMap { $0 }) { c in
                    guard !didZoomToUser else { return }
                    didZoomToUser = true
                    mapPosition = .region(MKCoordinateRegion(
                        center: c,
                        span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)
                    ))
                }

                // FİLTRE ÇUBUĞU
                VStack(spacing: 8) {
                    Picker("Kaynak", selection: $vm.source) {
                        ForEach(DataSource.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Saat", selection: $vm.hours) {
                        ForEach(HoursWindow.allCases) { w in
                            Text(w.title).tag(w)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .onChange(of: vm.source) { _, _ in Task { await vm.load() } }
                .onChange(of: vm.hours) { _, _ in Task { await vm.load() } }

                // LİSTE
                List(vm.quakes) { q in
                    NavigationLink {
                        EarthquakeDetailView(eq: q)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("M\(String(format: "%.1f", q.magnitude))")
                                    .font(.headline)
                                    .foregroundStyle(.red)
                                Text(q.place).font(.headline).lineLimit(1)
                            }
                            Text(q.time.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await vm.load() }
            }
            .navigationTitle("QuakeScope")
            .toolbar {
                // Sol: Konuma ortala
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let c = loc.coordinate {
                            mapPosition = .region(MKCoordinateRegion(
                                center: c,
                                span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)
                            ))
                        } else {
                            loc.request()
                        }
                    } label: { Image(systemName: "location") }
                }

                // Sağ: Menü (🔔 bildirim + yenile)
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(alertMonitor.isActive ? "Uyarıları Durdur" : "Uyarıları Başlat") {
                            if alertMonitor.isActive {
                                alertMonitor.stop()
                            } else {
                                Task {
                                    _ = await Notifier.requestAuthorization()
                                    alertMonitor.start()
                                }
                            }
                        }

                        NavigationLink("Uyarı Ayarları") {
                            AlertSettingsView()
                        }

                        Divider()
                        if vm.isLoading {
                            Label("Yükleniyor...", systemImage: "arrow.clockwise")
                        } else {
                            Button("Yenile") { Task { await vm.load() } }
                        }
                    } label: {
                        Image(systemName: "bell.badge")
                    }
                }
            }
            .task {
                await vm.load()
                if !alertMonitor.isActive, UserDefaults.standard.bool(forKey: "AlertsEnabled") {
                    _ = await Notifier.requestAuthorization()
                    alertMonitor.start()
                }
            }

        }
    }

    private func size(for mag: Double) -> CGFloat {
        max(16, CGFloat(mag) * 8)
    }
}
