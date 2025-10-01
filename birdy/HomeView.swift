import SwiftUI
import MapKit
import CoreLocation
import UIKit

// Lightweight location provider to request permission and publish the last known coordinate.
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = CLLocationManager.authorizationStatus()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        DispatchQueue.main.async {
            self.lastLocation = loc.coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // ignore for now
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }
}

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
    let comName: String?
    let sciName: String?
    let coordinate: CLLocationCoordinate2D
    var imageURL: URL?
    var isRoutePoint: Bool = false

    var displayName: String {
        return comName ?? sciName ?? "Unknown"
    }
}

// Use shared route models in RouteModels.swift

struct Cluster: Identifiable {
    let id = UUID()
    var members: [BirdAnnotation]
    var coordinate: CLLocationCoordinate2D {
        // average coordinate of members
        let lat = members.map { $0.coordinate.latitude }.reduce(0, +) / Double(members.count)
        let lon = members.map { $0.coordinate.longitude }.reduce(0, +) / Double(members.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

enum Ecosystem {
    case rainforest, tundra, desert, temperateForest, grassland, wetland, mangrove
}

// Return a LinearGradient appropriate for each ecosystem.
private func gradientForEcosystem(_ eco: Ecosystem) -> LinearGradient {
    switch eco {
    case .rainforest:
        return LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.85), Color.green.opacity(0.55)]), startPoint: .top, endPoint: .bottom)
    case .tundra:
        return LinearGradient(gradient: Gradient(colors: [Color(.systemGray6).opacity(0.95), Color.blue.opacity(0.25)]), startPoint: .top, endPoint: .bottom)
    case .desert:
        return LinearGradient(gradient: Gradient(colors: [Color.yellow.opacity(0.95), Color.orange.opacity(0.5)]), startPoint: .top, endPoint: .bottom)
    case .temperateForest:
        return LinearGradient(gradient: Gradient(colors: [Color.brown.opacity(0.7), Color.green.opacity(0.45)]), startPoint: .top, endPoint: .bottom)
    case .grassland:
        return LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.6), Color.yellow.opacity(0.35)]), startPoint: .top, endPoint: .bottom)
    case .wetland:
        return LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.85), Color.green.opacity(0.25)]), startPoint: .top, endPoint: .bottom)
    case .mangrove:
        return LinearGradient(gradient: Gradient(colors: [Color.teal.opacity(0.8), Color.green.opacity(0.45)]), startPoint: .top, endPoint: .bottom)
    }
}

// Programmatic pixel tile (rows x cols grid). Lightweight and vector-based.
struct PixelArtTile: View {
    let pixels: [[Color]]
    let pixelSpacing: CGFloat

    var body: some View {
        GeometryReader { geo in
            let rows = pixels.count
            let cols = pixels.first?.count ?? 0
            if rows == 0 || cols == 0 {
                EmptyView()
            } else {
                let cellW = geo.size.width / CGFloat(cols)
                let cellH = geo.size.height / CGFloat(rows)
                ZStack {
                    ForEach(0..<rows, id: \.self) { r in
                        ForEach(0..<cols, id: \.self) { c in
                            pixels[r][c]
                                .frame(width: cellW - pixelSpacing, height: cellH - pixelSpacing)
                                .position(x: CGFloat(c) * cellW + cellW / 2, y: CGFloat(r) * cellH + cellH / 2)
                        }
                    }
                }
            }
        }
    }
}

// Tile a PixelArtTile horizontally to fill the stripe width.
struct PixelStripe: View {
    let pixels: [[Color]]
    let tileSize: CGSize
    let pixelSpacing: CGFloat

    var body: some View {
        GeometryReader { geo in
            let count = max(1, Int(ceil(geo.size.width / tileSize.width)))
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { _ in
                    PixelArtTile(pixels: pixels, pixelSpacing: pixelSpacing)
                        .frame(width: tileSize.width, height: tileSize.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// Example 4x4 patterns for ecosystems. Tweak colors as you like.
private func patternForEcosystem(_ eco: Ecosystem) -> [[Color]] {
    switch eco {
    case .rainforest:
        // 8x8 tile: canopy with trunk in center columns
        let gDark = Color.green.opacity(0.95)
        let gMid = Color.green.opacity(0.8)
        let gLight = Color.green.opacity(0.6)
        let trunk = Color.brown.opacity(0.95)
        return [
            [gMid, gDark, gDark, gDark, gDark, gDark, gDark, gMid],
            [gDark, gDark, gMid, gMid, gMid, gMid, gDark, gDark],
            [gMid, gLight, gMid, gMid, gMid, gMid, gLight, gMid],
            [gLight, gMid, gLight, trunk, trunk, gLight, gMid, gLight],
            [gLight, gMid, gLight, trunk, trunk, gLight, gMid, gLight],
            [gMid, gLight, gMid, gMid, gMid, gMid, gLight, gMid],
            [gDark, gMid, gDark, gMid, gMid, gDark, gMid, gDark],
            [gMid, gDark, gMid, gDark, gDark, gMid, gDark, gMid]
        ]
    case .tundra:
        return [
            [Color.white, Color(.systemGray6), Color.white, Color.blue.opacity(0.12)],
            [Color(.systemGray6), Color.white, Color.blue.opacity(0.08), Color.white],
            [Color.white, Color.blue.opacity(0.1), Color(.systemGray6), Color.white],
            [Color.blue.opacity(0.12), Color.white, Color(.systemGray6), Color.white]
        ]
    case .desert:
        return [
            [Color.yellow.opacity(0.98), Color.orange.opacity(0.9), Color.yellow.opacity(0.95), Color.orange.opacity(0.85)],
            [Color.orange.opacity(0.8), Color.yellow.opacity(0.95), Color.orange.opacity(0.7), Color.yellow.opacity(0.9)],
            [Color.yellow.opacity(0.95), Color.orange.opacity(0.85), Color.yellow.opacity(0.9), Color.orange.opacity(0.8)],
            [Color.orange.opacity(0.75), Color.yellow.opacity(0.95), Color.orange.opacity(0.85), Color.yellow.opacity(0.9)]
        ]
    case .temperateForest:
        return [
            [Color.brown.opacity(0.8), Color.green.opacity(0.55), Color.brown.opacity(0.7), Color.green.opacity(0.45)],
            [Color.green.opacity(0.5), Color.brown.opacity(0.7), Color.green.opacity(0.6), Color.brown.opacity(0.6)],
            [Color.brown.opacity(0.7), Color.green.opacity(0.55), Color.brown.opacity(0.8), Color.green.opacity(0.5)],
            [Color.green.opacity(0.6), Color.brown.opacity(0.65), Color.green.opacity(0.5), Color.brown.opacity(0.7)]
        ]
    case .grassland:
        return [
            [Color.green.opacity(0.7), Color.yellow.opacity(0.35), Color.green.opacity(0.6), Color.yellow.opacity(0.4)],
            [Color.yellow.opacity(0.4), Color.green.opacity(0.65), Color.yellow.opacity(0.35), Color.green.opacity(0.6)],
            [Color.green.opacity(0.65), Color.yellow.opacity(0.35), Color.green.opacity(0.7), Color.yellow.opacity(0.35)],
            [Color.yellow.opacity(0.4), Color.green.opacity(0.6), Color.yellow.opacity(0.35), Color.green.opacity(0.65)]
        ]
    case .wetland:
        return [
            [Color.blue.opacity(0.9), Color.green.opacity(0.3), Color.blue.opacity(0.8), Color.green.opacity(0.25)],
            [Color.green.opacity(0.25), Color.blue.opacity(0.85), Color.green.opacity(0.3), Color.blue.opacity(0.8)],
            [Color.blue.opacity(0.85), Color.green.opacity(0.28), Color.blue.opacity(0.9), Color.green.opacity(0.3)],
            [Color.green.opacity(0.3), Color.blue.opacity(0.8), Color.green.opacity(0.25), Color.blue.opacity(0.85)]
        ]
    case .mangrove:
        return [
            [Color.teal.opacity(0.9), Color.green.opacity(0.45), Color.teal.opacity(0.8), Color.green.opacity(0.4)],
            [Color.green.opacity(0.4), Color.teal.opacity(0.85), Color.green.opacity(0.45), Color.teal.opacity(0.8)],
            [Color.teal.opacity(0.85), Color.green.opacity(0.42), Color.teal.opacity(0.9), Color.green.opacity(0.45)],
            [Color.green.opacity(0.45), Color.teal.opacity(0.8), Color.green.opacity(0.4), Color.teal.opacity(0.85)]
        ]
    }
}

private func clusterAnnotations(from annotations: [BirdAnnotation], thresholdMeters: CLLocationDistance) -> [Cluster] {
    var clusters: [Cluster] = []
    for ann in annotations {
        let annLoc = CLLocation(latitude: ann.coordinate.latitude, longitude: ann.coordinate.longitude)
        var added = false
        for i in 0..<clusters.count {
            let centroid = clusters[i].coordinate
            let cLoc = CLLocation(latitude: centroid.latitude, longitude: centroid.longitude)
            if cLoc.distance(from: annLoc) <= thresholdMeters {
                clusters[i].members.append(ann)
                added = true
                break
            }
        }
        if !added {
            clusters.append(Cluster(members: [ann]))
        }
    }
    return clusters
}

// For a cluster, compute species -> representative BirdAnnotation and sort by decreasing frequency
private func clusterSpeciesCounts(_ members: [BirdAnnotation]) -> [(String, BirdAnnotation)] {
    var map: [String: BirdAnnotation] = [:]
    var counts: [String: Int] = [:]
    for m in members {
        let key = (m.sciName ?? m.comName ?? "").lowercased()
        counts[key, default: 0] += 1
        // keep a representative that has an image if possible
        if map[key] == nil || (map[key]?.imageURL == nil && m.imageURL != nil) {
            map[key] = m
        }
    }
    // Sort by count descending
    let sorted = counts.keys.sorted { (a, b) -> Bool in
        return (counts[a] ?? 0) > (counts[b] ?? 0)
    }
    return sorted.compactMap { k in
        if let rep = map[k] { return (k, rep) }
        return nil
    }
}

// Compute packed positions for a small set of circles.
// Places the largest circle at center and arranges others on a ring.
private func packedPositions(forSizes sizes: [CGFloat], padding: CGFloat = 4) -> [CGPoint] {
    guard !sizes.isEmpty else { return [] }
    // sizes assumed sorted descending (largest first)
    let radii = sizes.map { $0 / 2 }
    if sizes.count == 1 { return [CGPoint.zero] }

    let largest = sizes[0]
    let maxOtherRadius = radii.dropFirst().max() ?? 0
    let ringRadius = largest / 2 + maxOtherRadius + padding
    let countOnRing = sizes.count - 1

    var pts: [CGPoint] = []
    pts.append(.zero)
    for i in 0..<countOnRing {
        let angle = Double(i) * (2.0 * Double.pi / Double(max(1, countOnRing)))
        let x = CGFloat(cos(angle)) * ringRadius
        let y = CGFloat(sin(angle)) * ringRadius
        pts.append(CGPoint(x: x, y: y))
    }
    return pts
}

// Small view to render packed cluster icons — extracted to help the compiler type-check.
struct ClusterPackedView: View {
    let entries: [(String, BirdAnnotation)]
    let sizes: [CGFloat]
    let offsets: [CGPoint]

    var body: some View {
        ZStack {
            ForEach(0..<entries.count, id: \ .self) { idx in
                let rep = entries[idx].1
                let size = sizes[idx]
                let pos = offsets[idx]
                Group {
                    if let url = rep.imageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: size, height: size)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: size, height: size)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                    .shadow(radius: 1)
                            case .failure:
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: size, height: size)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: size, height: size)
                    }
                }
                .offset(x: pos.x, y: pos.y)
            }
        }
    }
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
    @State private var speciesFrequency: [String: Int] = [:]
    @StateObject private var locationProvider = LocationProvider()
    @State private var filterMode: FilterMode = .all
    @State private var searchText: String = ""
    @State private var searchResults: [BirdAnnotation] = []
    @State private var showResults: Bool = false
    @State private var selectedAnnotationID: UUID? = nil
    @State private var currentRouteCoords: [CLLocationCoordinate2D]? = nil
    @EnvironmentObject var routesStore: RoutesStore

    enum FilterMode: String, CaseIterable, Identifiable {
        case all = "All"
        case rareSingles = "Rare"

        var id: String { rawValue }
    }

    // Simple heuristic to map coordinates to a terrestrial ecosystem
    private var currentEcosystem: Ecosystem {
        let lat = region.center.latitude
        let absLat = abs(lat)
        if absLat <= 23.5 {
            return .rainforest
        }
        if absLat >= 60 {
            return .tundra
        }
        if absLat >= 23.5 && absLat < 40 {
            return .desert
        }
        if absLat >= 40 && absLat < 60 {
            return .temperateForest
        }
        return .grassland
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // cluster annotations for visual grouping and render cluster icons
                // adapt threshold based on zoom level: one degree latitude ~111km
                let metersPerLatDegree = 111_000.0
                let visibleMeters = region.span.latitudeDelta * metersPerLatDegree
                // use a small fraction of visible height as clustering radius; clamp to [8, 2000]
                let adaptiveThreshold = max(8.0, min(2000.0, visibleMeters * 0.001))
                let allClusters = clusterAnnotations(from: annotations, thresholdMeters: adaptiveThreshold)
                // Apply filter layers
                let clusters: [Cluster] = {
                    switch filterMode {
                    case .all:
                        return allClusters
                    case .rareSingles:
                        // compute global species frequency and find the minimum frequency
                        let globalCounts = speciesFrequency
                        guard !globalCounts.isEmpty else { return [] }
                        let minFreq = globalCounts.values.min() ?? 0
                        // keep clusters that are single-member and whose species frequency == minFreq
                        return allClusters.filter { c in
                            if c.members.count != 1 { return false }
                            let key = (c.members[0].sciName ?? c.members[0].comName ?? "").lowercased()
                            return (globalCounts[key] ?? Int.max) == minFreq
                        }
                    }
                }()

                // Build the annotations list by combining clusters and route points so all MapAnnotations are inside Map's closure.
                let displayAnnotations: [Cluster] = {
                    var list = clusters
                    if let coords = currentRouteCoords, coords.count >= 2 {
                            let startAnn = BirdAnnotation(comName: "Start", sciName: nil, coordinate: coords.first!, imageURL: nil, isRoutePoint: true)
                            let endAnn = BirdAnnotation(comName: "End", sciName: nil, coordinate: coords.last!, imageURL: nil, isRoutePoint: true)
                            list.append(Cluster(members: [startAnn]))
                            list.append(Cluster(members: [endAnn]))
                    }
                    return list
                }()

                // Build MKAnnotation objects for clusters and route dots
                let mkAnnotations: [BirdMKAnnotation] = displayAnnotations.flatMap { cluster in
                    cluster.members.map { m in
                        BirdMKAnnotation(id: m.id, coordinate: m.coordinate, title: m.displayName, imageURL: m.imageURL, isRoutePoint: m.isRoutePoint)
                    }
                }

                // Build polyline overlay if route coords exist (use computed let so it's allowed inside ViewBuilder)
                let overlays: [MKOverlay] = {
                    var arr: [MKOverlay] = []
                    if let coords = currentRouteCoords, coords.count >= 2 {
                        let pts = coords.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                        let poly = MKPolyline(coordinates: pts, count: pts.count)
                        arr.append(poly)
                    }
                    return arr
                }()

                MKMapViewWrapper(region: $region, annotations: mkAnnotations, overlays: overlays)
                // route rendering is handled by building `displayAnnotations` passed into the Map above

                // decorative top border (tiled pixel-art) roughly the thickness of the Dynamic Island
                let dynamicIslandHeight: CGFloat = 54
                PixelStripe(pixels: patternForEcosystem(currentEcosystem), tileSize: CGSize(width: 54, height: dynamicIslandHeight - 8), pixelSpacing: 1)
                    .frame(height: dynamicIslandHeight)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .shadow(radius: 2)
                // Top overlays: combined search (center) and filter picker (right)
                HStack(alignment: .top, spacing: 12) {
                    Spacer(minLength: 12)

                    // Centered search area. Constrain width so it won't collide with the picker on small screens.
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("Search bird name…", text: $searchText, onCommit: {
                                performSearch()
                            })
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 320)

                            Button(action: { performSearch() }) {
                                Image(systemName: "magnifyingglass")
                                    .padding(8)
                            }
                        }

                        if showResults {
                            ScrollView(.vertical) {
                                VStack(spacing: 0) {
                                    ForEach(searchResults) { r in
                                        HStack {
                                            Button(action: { goToAnnotation(r) }) {
                                                HStack {
                                                    Text(r.displayName)
                                                        .foregroundColor(.primary)
                                                    Spacer()
                                                }
                                                .padding(8)
                                            }
                                            .background(Color(.systemBackground).opacity(0.95))

                                            // Route button: compute directions from user location to this annotation
                                            Button(action: {
                                                requestRoute(to: r)
                                            }) {
                                                Image(systemName: "car.fill")
                                                    .padding(8)
                                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue))
                                                    .foregroundColor(.white)
                                            }
                                            .padding(.leading, 6)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 220)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: 420)

                    Spacer()

                    // Picker (top-right)
                    Picker("Filter", selection: $filterMode) {
                        ForEach(FilterMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                    .padding(.trailing, 12)
                }
                .padding(.top, dynamicIslandHeight + 8)
                // Debug overlay (bottom-left) — shows counts to help diagnose disappearing icons
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("anns: \(annotations.count)")
                                .font(.caption2)
                                .foregroundColor(.white)
                            Text("clusters: \(allClusters.count)")
                                .font(.caption2)
                                .foregroundColor(.white)
                            Text(String(format: "thresh: %.0f m", adaptiveThreshold))
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(.leading, 12)
                        .padding(.bottom, 12)
                        Spacer()
                    }
                }
            }
            // In-app explanation / permission card
            if locationProvider.authorizationStatus == .notDetermined {
                VStack(spacing: 12) {
                    Text("Enable Location")
                        .font(.headline)
                    Text("Allow location access so we can show nearby bird observations and center the map on your position.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Button("Not now") {
                            // dismiss by setting a non-notDetermined state is not available; just do nothing and let system handle
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))

                        Button("Allow") {
                            locationProvider.requestPermission()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue))
                        .foregroundColor(.white)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 6))
                .padding(.horizontal, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if locationProvider.authorizationStatus == .denied {
                VStack(spacing: 8) {
                    Text("Location Disabled")
                        .font(.headline)
                    Text("Location access is disabled. Open Settings to enable location for this app.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue))
                    .foregroundColor(.white)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 6))
                .padding(.horizontal, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .alert(item: $errorMessage) { msg in
            Alert(title: Text("Error"), message: Text(msg), dismissButton: .default(Text("OK")))
        }
        // Floating center-on-me button
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        if let coord = locationProvider.lastLocation {
                            withAnimation {
                                region.center = coord
                                region.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            }
                        } else {
                            // request a fresh location if we don't have one yet
                            locationProvider.requestLocation()
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                            .padding(14)
                            .background(Circle().fill(Color.blue))
                            .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        )
        .onAppear {
            // load birds when view appears
            scheduleLoadBirds()
            locationProvider.requestPermission() // request location permission so the map can show the blue dot
        }
        .onChange(of: region) { _ in
            // debounce region changes to avoid rapid API calls while panning/zooming
            scheduleLoadBirds()
        }
        .onChange(of: routesStore.selectedRouteID) { id in
            guard let id = id, let saved = routesStore.savedRoutes.first(where: { $0.id == id }) else {
                // clear route if nothing selected
                self.currentRouteCoords = nil
                return
            }
            let coords = saved.coordinates
            guard !coords.isEmpty else { return }
            // set current route coords so overlay is drawn
            withAnimation {
                self.currentRouteCoords = coords
                // compute bounding box
                let lats = coords.map { $0.latitude }
                let lons = coords.map { $0.longitude }
                let minLat = lats.min() ?? coords[0].latitude
                let maxLat = lats.max() ?? coords[0].latitude
                let minLon = lons.min() ?? coords[0].longitude
                let maxLon = lons.max() ?? coords[0].longitude
                let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0, longitude: (minLon + maxLon) / 2.0)
                // add padding
                let latDelta = max(0.01, (maxLat - minLat) * 1.4)
                let lonDelta = max(0.01, (maxLon - minLon) * 1.4)
                self.region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
            }
        }
    }

    // MARK: - Routing & Persistence

    private func requestRoute(to ann: BirdAnnotation) {
        // If we have a last known location, use it; otherwise request one and bail for now.
        guard let fromCoord = locationProvider.lastLocation else {
            locationProvider.requestLocation()
            // Optionally inform the user to try again after location is available
            return
        }

        computeDirections(from: fromCoord, to: ann.coordinate) { coords in
            guard let coords = coords, coords.count > 1 else { return }
            DispatchQueue.main.async {
                self.currentRouteCoords = coords
                // Save route with a simple name into the shared store
                let name = ann.displayName
                routesStore.addRoute(name: name, coords: coords)
            }
        }
    }

    private func computeDirections(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, completion: @escaping ([CLLocationCoordinate2D]?) -> Void) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let dirs = MKDirections(request: request)
        dirs.calculate { resp, err in
            if let route = resp?.routes.first {
                let coords = route.polyline.coordinates()
                completion(coords)
            } else {
                completion(nil)
            }
        }
    }


    private func performSearch() {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else {
            searchResults = []
            showResults = false
            return
        }
        // match against common and scientific names
        let matches = annotations.filter { ann in
            let name = (ann.comName ?? ann.sciName ?? "").lowercased()
            return name.contains(q)
        }
        searchResults = matches
        showResults = !matches.isEmpty
    }

    private func goToAnnotation(_ ann: BirdAnnotation) {
        withAnimation {
            region.center = ann.coordinate
            region.span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        }
        // optionally, use user location to find a nearby occurrence if multiple exist — for now center on the annotation
        showResults = false
        selectedAnnotationID = ann.id
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
                var freq: [String: Int] = [:]
                for o in obs {
                    if let lat = o.lat, let lng = o.lng {
                        let a = BirdAnnotation(comName: o.comName, sciName: o.sciName, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), imageURL: nil)
                        anns.append(a)
                        // build local frequency by species key (prefer sciName)
                        let key = (o.sciName ?? o.comName ?? "").lowercased()
                        if !key.isEmpty {
                            freq[key, default: 0] += 1
                        }
                    }
                }

                // Group overlapping annotations by rounded coordinates (to ~11m using 4 decimals)
                func coordKey(_ c: CLLocationCoordinate2D) -> String {
                    func round(_ v: Double, decimals: Int) -> Double {
                        let factor = pow(10.0, Double(decimals))
                        return (v * factor).rounded() / factor
                    }
                    return "\(round(c.latitude, decimals: 4))_\(round(c.longitude, decimals: 4))"
                }

                var grouped: [String: [BirdAnnotation]] = [:]
                for a in anns {
                    let k = coordKey(a.coordinate)
                    grouped[k, default: []].append(a)
                }

                // For each group, pick the rarest species (lowest frequency). If tied, prefer scientific name.
                var filtered: [BirdAnnotation] = []
                for (_, group) in grouped {
                    if group.count == 1 {
                        filtered.append(group[0])
                    } else {
                        let sorted = group.sorted { lhs, rhs in
                            let lkey = (lhs.sciName ?? lhs.comName ?? "").lowercased()
                            let rkey = (rhs.sciName ?? rhs.comName ?? "").lowercased()
                            let lf = freq[lkey] ?? 0
                            let rf = freq[rkey] ?? 0
                            if lf != rf { return lf < rf }
                            // tie-breaker: prefer species with scientific name available
                            if (lhs.sciName != nil) != (rhs.sciName != nil) { return lhs.sciName != nil }
                            return (lhs.comName ?? "") < (rhs.comName ?? "")
                        }
                        if let pick = sorted.first { filtered.append(pick) }
                    }
                }

                DispatchQueue.main.async {
                    self.speciesFrequency = freq
                    self.annotations = filtered
                    self.isLoading = false
                }

                // For each remaining annotation, try to fetch a Wikimedia image URL.
                // Prefer scientific name (sciName) when available, fall back to common name (comName).
                for ann in filtered {
                    func assignImage(url: URL) {
                        DispatchQueue.main.async {
                            if let i = self.annotations.firstIndex(where: { $0.id == ann.id }) {
                                self.annotations[i].imageURL = url
                            }
                        }
                        // prefetch image into the map wrapper's cache so annotation view shows immediately
                        URLSession.shared.dataTask(with: url) { data, _, _ in
                            if let data = data, let img = UIImage(data: data) {
                                MKMapViewWrapper.Coordinator.imageCache.setObject(img, forKey: url as NSURL)
                            }
                        }.resume()
                    }

                    if let sci = ann.sciName, !sci.isEmpty {
                        WikimediaClient.fetchImageURL(for: sci) { res in
                            switch res {
                            case .success(let url):
                                assignImage(url: url)
                            case .failure:
                                // try common name if scientific lookup failed
                                if let com = ann.comName, !com.isEmpty {
                                    WikimediaClient.fetchImageURL(for: com) { res2 in
                                        if case .success(let url2) = res2 { assignImage(url: url2) }
                                    }
                                }
                            }
                        }
                    } else if let com = ann.comName, !com.isEmpty {
                        WikimediaClient.fetchImageURL(for: com) { res in
                            if case .success(let url) = res { assignImage(url: url) }
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

// MKPolyline coordinate extractor
extension MKPolyline {
    func coordinates() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: Int(self.pointCount))
        self.getCoordinates(&coords, range: NSRange(location: 0, length: self.pointCount))
        return coords
    }
}

#Preview {
    HomeView()
}
