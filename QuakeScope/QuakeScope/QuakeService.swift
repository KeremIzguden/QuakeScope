import Foundation
import CoreLocation

// USGS GeoJSON modelleri (özet)
struct USGSFeatureCollection: Decodable {
    let features: [USGSFeature]
}
struct USGSFeature: Decodable {
    let id: String
    let properties: USGSProperties
    let geometry: USGSGemoetry
}
struct USGSProperties: Decodable {
    let mag: Double?
    let place: String?
    let time: Double? // epoch ms
    let url: String?
}
struct USGSGemoetry: Decodable {
    let coordinates: [Double] // [lon, lat, depth]
}

// Uygulamada kullanacağımız sade model
struct Earthquake: Identifiable {
    let id: String
    let coord: CLLocationCoordinate2D
    let magnitude: Double
    let place: String
    let time: Date
    let url: URL?
}

enum QuakeFeed: String, CaseIterable, Identifiable {
    case lastHour = "all_hour"
    case lastDay  = "all_day"
    case lastWeek = "all_week"
    var id: String { rawValue }
    
    var url: URL {
        URL(string: "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/\(rawValue).geojson")!
    }
}

final class QuakeService {
    func fetch(_ feed: QuakeFeed = .lastDay, minMag: Double = 0.0) async throws -> [Earthquake] {
        let (data, _) = try await URLSession.shared.data(from: feed.url)
        let fc = try JSONDecoder().decode(USGSFeatureCollection.self, from: data)
        let quakes: [Earthquake] = fc.features.compactMap { f in
            guard f.geometry.coordinates.count >= 2 else { return nil }
            let lon = f.geometry.coordinates[0]
            let lat = f.geometry.coordinates[1]
            let mag = f.properties.mag ?? 0
            guard mag >= minMag else { return nil }
            let place = f.properties.place ?? "Bilinmiyor"
            let epoch = (f.properties.time ?? 0) / 1000.0
            let date = Date(timeIntervalSince1970: epoch)
            let url = f.properties.url.flatMap(URL.init(string:))
            return Earthquake(
                id: f.id,
                coord: .init(latitude: lat, longitude: lon),
                magnitude: mag,
                place: place,
                time: date,
                url: url
            )
        }
        // büyükten küçüğe sırala
        return quakes.sorted { $0.magnitude > $1.magnitude }
    }
}
