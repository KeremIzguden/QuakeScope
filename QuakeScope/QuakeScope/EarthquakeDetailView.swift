import SwiftUI
import MapKit
import CoreLocation

struct EarthquakeDetailView: View {
    let eq: Earthquake

    @State private var mapPos: MapCameraPosition

    init(eq: Earthquake) {
        self.eq = eq
        _mapPos = State(initialValue:
            .region(MKCoordinateRegion(
                center: eq.coord,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            ))
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(eq.place.isEmpty ? "Deprem" : eq.place)
                        .font(.title2).bold().lineLimit(2)
                    Spacer()
                    Text(String(format: "M%.1f", eq.magnitude))
                        .font(.title2).bold()
                        .foregroundStyle(magColor(eq.magnitude))
                }.padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Label(eq.time.formatted(date: .abbreviated, time: .shortened),
                          systemImage: "clock")
                    let utc = eq.time.converted(to: TimeZone(secondsFromGMT: 0)!)
                    Text("UTC: \(utc.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Label(String(format: "Lat %.5f, Lon %.5f", eq.coord.latitude, eq.coord.longitude),
                          systemImage: "mappin.and.ellipse")
                }.padding(.horizontal)

                Map(position: $mapPos) {
                    Marker(eq.place.isEmpty ? "Deprem" : eq.place, coordinate: eq.coord)
                        .tint(magColor(eq.magnitude))
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                VStack(spacing: 10) {
                    Button { openInMaps(eq.coord, name: eq.place) } label: {
                        Label("Haritada Aç (Apple Maps)", systemImage: "map")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
        }
        .navigationTitle("Deprem Detayı")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func magColor(_ m: Double) -> Color {
        switch m { case ..<3: .green; case 3..<5: .orange; default: .red }
    }
    private func openInMaps(_ c: CLLocationCoordinate2D, name: String) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: c))
        item.name = name.isEmpty ? "Deprem Konumu" : name
        item.openInMaps()
    }
}

private extension Date {
    func converted(to tz: TimeZone) -> Date {
        let delta = tz.secondsFromGMT(for: self) - TimeZone.current.secondsFromGMT(for: self)
        return addingTimeInterval(TimeInterval(-delta))
    }
}
