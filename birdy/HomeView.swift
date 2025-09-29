import SwiftUI
import MapKit

struct Landmark: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct HomeView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    private let landmarks = [
        Landmark(name: "Apple Park (example)", coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902))
    ]

    var body: some View {
        NavigationView {
            Map(coordinateRegion: $region, annotationItems: landmarks) { landmark in
                // Simple marker for each landmark
                MapMarker(coordinate: landmark.coordinate, tint: .red)
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: centerOnFirstLandmark) {
                        Image(systemName: "location.fill")
                    }
                }
            }
        }
    }

    private func centerOnFirstLandmark() {
        guard let first = landmarks.first else { return }
        region.center = first.coordinate
    }
}

#Preview {
    HomeView()
}
