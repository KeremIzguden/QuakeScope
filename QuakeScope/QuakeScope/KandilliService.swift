import Foundation
import CoreLocation

// Swagger'a göre sadeleştirilmiş modeller
private struct KandilliLiveResponse: Decodable {
    let result: [KandilliItem]
}
private struct KandilliItem: Decodable {
    let earthquake_id: String?
    let title: String?
    let mag: Double?
    let depth: Double?
    let date_time: String?
    let geojson: GeoJSONPoint?
}
private struct GeoJSONPoint: Decodable {
    let type: String
    let coordinates: [Double]
}

final class KandilliService {
    
    func fetch(limit: Int = 100) async throws -> [Earthquake] {
        let lim = max(1, min(100, limit))
        var comps = URLComponents(string: "https://api.orhanaydogdu.com.tr/deprem/kandilli/live")!
        comps.queryItems = [URLQueryItem(name: "limit", value: String(lim))]
        let url = comps.url!

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(KandilliLiveResponse.self, from: data)

        
        let df1 = DateFormatter()
        df1.locale = Locale(identifier: "tr_TR")
        df1.timeZone = .current
        df1.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let df2 = DateFormatter()
        df2.locale = Locale(identifier: "tr_TR")
        df2.timeZone = .current
        df2.dateFormat = "yyyy.MM.dd HH:mm:ss"

        
        let quakes: [Earthquake] = decoded.result.compactMap { it in
           
            guard
                let coords = it.geojson?.coordinates,
                coords.count >= 2
            else { return nil }

            let lon = coords[0]
            let lat = coords[1]

            
            let dateStr = it.date_time ?? ""
            let date = df1.date(from: dateStr) ?? df2.date(from: dateStr) ?? Date()

           
            return Earthquake(
                id: it.earthquake_id ?? UUID().uuidString,
                coord: .init(latitude: lat, longitude: lon),
                magnitude: it.mag ?? 0,
                place: it.title ?? "Kandilli",
                time: date,
                                
                url: nil
            )
        }

        return quakes.sorted { $0.magnitude > $1.magnitude }
    }
}
