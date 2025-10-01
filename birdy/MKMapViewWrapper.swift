import SwiftUI
import MapKit

struct MKMapViewWrapper: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var annotations: [MKAnnotation]
    var overlays: [MKOverlay]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.setRegion(region, animated: false)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // update region
        if !regionsEqual(uiView.region, region) {
            uiView.setRegion(region, animated: true)
        }

        // sync annotations
        let existing = uiView.annotations.filter { !($0 is MKUserLocation) }

        // stable key for annotations: use BirdMKAnnotation.id when available, otherwise pointer identity
        func key(for ann: MKAnnotation) -> String {
            if let b = ann as? BirdMKAnnotation { return "bird:\(b.id.uuidString)" }
            // fallback to pointer identity
            let ptr = Unmanaged.passUnretained(ann as AnyObject).toOpaque()
            return "obj:\(ptr)"
        }

        let existingKeys = Set(existing.map { key(for: $0) })
        let newKeys = Set(annotations.map { key(for: $0) })

        // Build maps for updating existing annotations in place
        var existingMap: [String: MKAnnotation] = [:]
        for e in existing { existingMap[key(for: e)] = e }
        var newMap: [String: MKAnnotation] = [:]
        for n in annotations { newMap[key(for: n)] = n }

        // Update properties of existing BirdMKAnnotation instances from new data (title, imageURL)
        let intersection = existingKeys.intersection(newKeys)
        for k in intersection {
            if let existingAnn = existingMap[k] as? BirdMKAnnotation, let newAnn = newMap[k] as? BirdMKAnnotation {
                // copy mutable properties
                existingAnn.title = newAnn.title
                existingAnn.imageURL = newAnn.imageURL
                // refresh view if visible
                if let view = uiView.view(for: existingAnn) as? BirdAnnotationView {
                    view.configure(with: existingAnn)
                } else if let view = uiView.view(for: existingAnn) {
                    // fallback for generic annotation views
                    parent.coordinator.configureAnnotationView(view, for: existingAnn)
                }
            }
        }

        let toRemove = existing.filter { !newKeys.contains(key(for: $0)) }
        if !toRemove.isEmpty { uiView.removeAnnotations(toRemove) }

        let toAdd = annotations.filter { !existingKeys.contains(key(for: $0)) }
        if !toAdd.isEmpty { uiView.addAnnotations(toAdd) }

        // overlays
        uiView.removeOverlays(uiView.overlays)
        uiView.addOverlays(overlays)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MKMapViewWrapper
        init(_ p: MKMapViewWrapper) { parent = p }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let poly = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: poly)
                r.strokeColor = UIColor.systemBlue
                r.lineWidth = 4
                r.alpha = 0.9
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

            func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
                if annotation is MKUserLocation { return nil }
                if let bird = annotation as? BirdMKAnnotation {
                    // Route points use a small flag view
                    if bird.isRoutePoint {
                        let id = "route-flag"
                        var v = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                        if v == nil {
                            v = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                        } else {
                            v?.annotation = annotation
                        }
                        if let v = v {
                            configureAnnotationView(v, for: bird)
                        }
                        return v
                    }

                    // Bird annotation: use a custom view that shows image + label underneath
                    let id = "bird"
                    var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? BirdAnnotationView
                    if view == nil {
                        view = BirdAnnotationView(annotation: annotation, reuseIdentifier: id)
                    } else {
                        view?.annotation = annotation
                    }
                    if let view = view {
                        view.configure(with: bird)
                    }
                    return view
                }
                return nil
            }
    }

    private func regionsEqual(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
        let centerTol: CLLocationDistance = 50
        let aLoc = CLLocation(latitude: a.center.latitude, longitude: a.center.longitude)
        let bLoc = CLLocation(latitude: b.center.latitude, longitude: b.center.longitude)
        return aLoc.distance(from: bLoc) <= centerTol && abs(a.span.latitudeDelta - b.span.latitudeDelta) < 0.001 && abs(a.span.longitudeDelta - b.span.longitudeDelta) < 0.001
    }
}

// Custom MKAnnotation subclass that carries image URL and route flag
public class BirdMKAnnotation: NSObject, MKAnnotation {
    public let id: UUID
    public dynamic var coordinate: CLLocationCoordinate2D
    public var title: String?
    public var imageURL: URL?
    public var isRoutePoint: Bool = false

    public init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D, title: String? = nil, imageURL: URL? = nil, isRoutePoint: Bool = false) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
        self.imageURL = imageURL
        self.isRoutePoint = isRoutePoint
    }
}

extension MKMapViewWrapper.Coordinator {
    // image cache shared across coordinators
    static let imageCache = NSCache<NSURL, UIImage>()

    private func loadImage(for url: URL, into view: MKAnnotationView) {
        if let cached = Self.imageCache.object(forKey: url as NSURL) {
            DispatchQueue.main.async {
                view.image = cached
                view.setNeedsLayout()
            }
            return
        }

        URLSession.shared.dataTask(with: url) { data, resp, err in
            guard let data = data, let img = UIImage(data: data) else { return }
            // circular crop and border
            let size = CGSize(width: 48, height: 48)
            UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(ovalIn: rect).addClip()
            img.draw(in: rect)
            let circ = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            if let circ = circ {
                Self.imageCache.setObject(circ, forKey: url as NSURL)
                DispatchQueue.main.async {
                    view.image = circ
                    view.layer.cornerRadius = size.width / 2
                    view.clipsToBounds = true
                    view.layer.borderColor = UIColor.white.cgColor
                    view.layer.borderWidth = 2
                    view.setNeedsLayout()
                }
            }
        }.resume()
    }

    // Expose helper that the coordinator can call from delegate
    func configureAnnotationView(_ view: MKAnnotationView, for bird: BirdMKAnnotation) {
        if bird.isRoutePoint {
            let flag = UIImage(systemName: "flag.fill")?.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
            view.image = flag
            view.frame.size = CGSize(width: 22, height: 22)
        } else if let url = bird.imageURL {
            // placeholder
            view.image = UIImage(systemName: "photo")
            view.frame.size = CGSize(width: 48, height: 48)
            view.layer.cornerRadius = 24
            view.clipsToBounds = true
            // async load
            loadImage(for: url, into: view)
        } else {
            // default bird pin
            view.image = UIImage(systemName: "bird")?.withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
            view.frame.size = CGSize(width: 32, height: 32)
        }
        view.canShowCallout = true
    }
}

// Custom MKAnnotationView that shows a circular image and a label below it.
class BirdAnnotationView: MKAnnotationView {
    private let imageView = UIImageView()
    private let label = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 24
        imageView.clipsToBounds = true
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 2
        imageView.frame = CGRect(x: 0, y: 0, width: 48, height: 48)
        addSubview(imageView)

        label.font = UIFont.systemFont(ofSize: 11)
        label.textAlignment = .center
        label.textColor = .label
        label.frame = CGRect(x: -40, y: 50, width: 128, height: 16)
        addSubview(label)

        // adjust frame to include label area
        self.frame = CGRect(x: 0, y: 0, width: 48, height: 68)
        centerOffset = CGPoint(x: 0, y: -34)
    }

    func configure(with bird: BirdMKAnnotation) {
        label.text = bird.title
        if let url = bird.imageURL {
            if let cached = MKMapViewWrapper.Coordinator.imageCache.object(forKey: url as NSURL) {
                imageView.image = cached
            } else {
                imageView.image = UIImage(systemName: "photo")
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    guard let data = data, let img = UIImage(data: data) else { return }
                    DispatchQueue.main.async {
                        MKMapViewWrapper.Coordinator.imageCache.setObject(img, forKey: url as NSURL)
                        self.imageView.image = img
                    }
                }.resume()
            }
        } else {
            imageView.image = UIImage(systemName: "bird")
        }
    }
}
