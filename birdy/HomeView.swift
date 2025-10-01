import SwiftUI
import MapKit
import CoreLocation

// Lightweight location provider to request permission and publish the last known coordinate.
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocationCoordinate2D?

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

    var displayName: String {
        return comName ?? sciName ?? "Unknown"
    }
}

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
                let clusters = clusterAnnotations(from: annotations, thresholdMeters: 50)

                Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: clusters) { cluster in
                    MapAnnotation(coordinate: cluster.coordinate) {
                        VStack {
                            if cluster.members.count == 1 {
                                let item = cluster.members[0]
                                if let url = item.imageURL {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 48, height: 48)
                                        case .success(let image):
                                            let key = (item.sciName ?? item.comName ?? "").lowercased()
                                            let freq = speciesFrequency[key] ?? 0
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 48, height: 48)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(freq <= 1 ? Color.yellow : Color.white, lineWidth: freq <= 1 ? 3 : 2))
                                                .shadow(radius: 2)
                                        case .failure:
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

                                Text(item.displayName)
                                    .font(.caption2)
                                    .fixedSize()
                                    .padding(.top, 2)
                            } else {
                                // cluster: pick up to 5 species ranked by frequency within the cluster
                                let speciesGroups = clusterSpeciesCounts(cluster.members)
                                let top = Array(speciesGroups.prefix(5))
                                // sizes for icons by rank (largest to smallest)
                                let sizes: [CGFloat] = [44, 36, 28, 22, 16]
                                let usedSizes = Array(sizes.prefix(top.count))
                                let offsets = packedPositions(forSizes: usedSizes, padding: 6)

                                let entries = top
                                let view = ClusterPackedView(entries: entries, sizes: usedSizes, offsets: offsets)
                                view
                            }
                        }
                        .onTapGesture {
                            if cluster.members.count > 1 {
                                withAnimation {
                                    region.center = cluster.coordinate
                                    region.span = MKCoordinateSpan(latitudeDelta: max(region.span.latitudeDelta / 2, 0.001), longitudeDelta: max(region.span.longitudeDelta / 2, 0.001))
                                }
                            } else {
                                // future: show detail sheet for single bird
                            }
                        }
                    }
                }

                // decorative top border (tiled pixel-art) roughly the thickness of the Dynamic Island
                let dynamicIslandHeight: CGFloat = 54
                PixelStripe(pixels: patternForEcosystem(currentEcosystem), tileSize: CGSize(width: 54, height: dynamicIslandHeight - 8), pixelSpacing: 1)
                    .frame(height: dynamicIslandHeight)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .shadow(radius: 2)
            }
            .navigationBarHidden(true)
            .alert(item: $errorMessage) { msg in
                Alert(title: Text("Error"), message: Text(msg), dismissButton: .default(Text("OK")))
            }
        }
        .onAppear {
            // load birds when view appears
            scheduleLoadBirds()
            locationProvider.requestPermission() // request location permission so the map can show the blue dot
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

#Preview {
    HomeView()
}
