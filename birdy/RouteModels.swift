import Foundation
import CoreLocation

// Codable wrapper for storing coordinates in UserDefaults
struct CodableCoordinate: Codable {
    let lat: Double
    let lon: Double

    init(_ c: CLLocationCoordinate2D) {
        lat = c.latitude
        lon = c.longitude
    }

    var clLocationCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}

struct SavedRoute: Codable, Identifiable {
    let id: UUID
    let name: String
    let coords: [CodableCoordinate]
    let date: Date

    init(name: String, coords: [CLLocationCoordinate2D]) {
        self.id = UUID()
        self.name = name
        self.coords = coords.map { CodableCoordinate($0) }
        self.date = Date()
    }

    var coordinates: [CLLocationCoordinate2D] { coords.map { $0.clLocationCoordinate } }
}
