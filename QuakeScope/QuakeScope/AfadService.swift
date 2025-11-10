import Foundation
import CoreLocation


private struct AfadItem: Decodable {
    let eventID: String
    let location: String?
    let latitude: String
    let longitude: String
    let depth: String?
    let magnitude: String?
    let date: String
}


private func parseAfadDate(_ s: String) -> Date? {
    let posix = Locale(identifier: "en_US_POSIX")
    let utc   = TimeZone(secondsFromGMT: 0)!

    
    do {
        let f = DateFormatter()
        f.locale = posix
        f.timeZone = utc
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = f.date(from: s) { return d }
    }

    
    do {
        let f = DateFormatter()
        f.locale = posix
        f.timeZone = utc
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = f.date(from: s) { return d }
    }

    
    do {
        let iso = ISO8601DateFormatter()
        iso.timeZone = utc
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
    }

    return nil
}

final class AfadService {

    func fetch(lastHours: Int = 24, minMag: Double = 0.0, limit: Int = 300) async throws -> [Earthquake] {
        let now = Date()
        let from = now.addingTimeInterval(-Double(lastHours) * 3600)

        // AFAD parametreleri UTC "yyyy-MM-dd HH:mm:ss"
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var comps = URLComponents(string: "https://deprem.afad.gov.tr/apiv2/event/filter")!
        comps.queryItems = [
            .init(name: "start", value: df.string(from: from)),
            .init(name: "end", value: df.string(from: now)),
            .init(name: "limit", value: String(limit)),
            .init(name: "orderby", value: "timedesc")
        ]

        var req = URLRequest(url: comps.url!)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("QuakeScope iOS", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        
        let rawItems = try JSONDecoder().decode([AfadItem].self, from: data)

       
        let quakes: [Earthquake] = rawItems.compactMap { e in
            guard
                let lat  = Double(e.latitude),
                let lon  = Double(e.longitude),
                let time = parseAfadDate(e.date)   // ← artık gerçek tarih
            else { return nil }

            let mag = Double(e.magnitude ?? "") ?? 0.0
            if mag < minMag { return nil }

            let place = (e.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            return Earthquake(
                id: e.eventID,
                coord: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                magnitude: mag,
                place: place.isEmpty ? String(format: "Lat %.2f, Lon %.2f", lat, lon) : place,
                time: time,
                url: nil
            )
        }

        return quakes.sorted { $0.time > $1.time }
    }
}
