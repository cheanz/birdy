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

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // cluster annotations for visual grouping and render cluster icons
                let clusters = clusterAnnotations(from: annotations, thresholdMeters: 50)

                Map(coordinateRegion: $region, annotationItems: clusters) { cluster in
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

                // decorative top border roughly the thickness of the Dynamic Island
                // non-interactive so it doesn't block map gestures
                let dynamicIslandHeight: CGFloat = 54
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(.systemBackground).opacity(0.7), Color(.systemGray4).opacity(0.25)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
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
