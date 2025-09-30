import SwiftUI
import MapKit
import CoreLocation

// Make MKCoordinateRegion equatable for use with SwiftUI's onChange(of:)
// Use a tolerance-based comparison to avoid noisy updates from tiny floating
// point changes when the user pans/zooms the map.
extension MKCoordinateRegion: Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        // Consider centers equal if they're within this many meters
        let centerToleranceMeters: CLLocationDistance = 50 // 50 meters

        let lhsLoc = CLLocation(latitude: lhs.center.latitude, longitude: lhs.center.longitude)
        let rhsLoc = CLLocation(latitude: rhs.center.latitude, longitude: rhs.center.longitude)
        let centerDistance = lhsLoc.distance(from: rhsLoc)
        guard centerDistance <= centerToleranceMeters else { return false }

        // For span deltas, use a small epsilon (absolute difference)
        let spanEpsilon = 0.001
        if abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta) > spanEpsilon { return false }
        if abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta) > spanEpsilon { return false }

        return true
    }
}

struct BirdAnnotation: Identifiable {
    let id = UUID()
    let speciesName: String
    let coordinate: CLLocationCoordinate2D
    var imageURL: URL?
}

struct HomeView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )

    @State private var annotations: [BirdAnnotation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingLoadWorkItem: DispatchWorkItem?

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                Map(coordinateRegion: $region, annotationItems: annotations) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        VStack {
                            if let url = item.imageURL {
                                // show wikipedia image as circular thumbnail
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 48, height: 48)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 48, height: 48)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                            .shadow(radius: 2)
                                    case .failure:
                                        // fallback marker when image cannot load
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 20, height: 20)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 20, height: 20)
                            }

                            // optional label (small)
                            Text(item.speciesName)
                                .font(.caption2)
                                .fixedSize()
                                .padding(.top, 2)
                        }
                        .onTapGesture {
                            // future: show detail sheet
                        }
                    }
                }
            }
            .navigationTitle("Home")
            .alert(item: $errorMessage) { msg in
                Alert(title: Text("Error"), message: Text(msg), dismissButton: .default(Text("OK")))
            }
        }
        .onAppear {
            // load birds when view appears
            scheduleLoadBirds()
        }
        .onChange(of: region) { _ in
            // debounce region changes to avoid rapid API calls while panning/zooming
            scheduleLoadBirds()
        }
    }

    private func loadBirdsInView() {
        isLoading = true
        errorMessage = nil

        let center = region.center
        EbirdClient.fetchRecentObservations(lat: center.latitude, lng: center.longitude, dist: 50, maxResults: 50) { result in
            switch result {
            case .failure(let err):
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = err.localizedDescription
                }
            case .success(let obs):
                // Map observations to annotations
                var anns: [BirdAnnotation] = []
                for o in obs {
                    if let lat = o.lat, let lng = o.lng {
                        let name = o.comName ?? o.sciName ?? "Unknown"
                        let a = BirdAnnotation(speciesName: name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), imageURL: nil)
                        anns.append(a)
                    }
                }

                DispatchQueue.main.async {
                    self.annotations = anns
                    self.isLoading = false
                }

                // For each annotation, try to fetch a Wikimedia image URL
                for (idx, ann) in anns.enumerated() {
                    WikimediaClient.fetchImageURL(for: ann.speciesName) { res in
                        switch res {
                        case .failure:
                            break
                        case .success(let url):
                            DispatchQueue.main.async {
                                // find the annotation in the array and assign url
                                if let i = self.annotations.firstIndex(where: { $0.id == ann.id }) {
                                    self.annotations[i].imageURL = url
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func scheduleLoadBirds(delay: TimeInterval = 0.8) {
        // cancel existing scheduled work
        pendingLoadWorkItem?.cancel()

        let work = DispatchWorkItem {
            loadBirdsInView()
        }
        pendingLoadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

// Simple helper to show alerts using a String as Identifiable
extension String: Identifiable {
    public var id: String { self }
}

#Preview {
    HomeView()
}
