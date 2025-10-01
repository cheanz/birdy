import Foundation
import CoreLocation

final class RoutesStore: ObservableObject {
    @Published var savedRoutes: [SavedRoute] = []
    @Published var selectedRouteID: UUID? = nil // when set, views may show the route

    private let key = "birdy_saved_routes"

    init() {
        load()
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key) {
            if let routes = try? JSONDecoder().decode([SavedRoute].self, from: data) {
                self.savedRoutes = routes
                return
            }
        }
        self.savedRoutes = []
    }

    func save() {
        if let data = try? JSONEncoder().encode(savedRoutes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func addRoute(name: String, coords: [CLLocationCoordinate2D]) {
        let r = SavedRoute(name: name, coords: coords)
        savedRoutes.append(r)
        save()
    }

    func deleteRoute(id: UUID) {
        savedRoutes.removeAll { $0.id == id }
        save()
        if selectedRouteID == id { selectedRouteID = nil }
    }
}
