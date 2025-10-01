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
        let toRemove = existing.filter { a in !annotations.contains(where: { $0 === a }) }
        uiView.removeAnnotations(toRemove)

        let toAdd = annotations.filter { a in !existing.contains(where: { $0 === a }) }
        uiView.addAnnotations(toAdd)

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
                    let id = "bird-")
                    var v = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    if v == nil {
                        v = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                    } else {
                        v?.annotation = annotation
                    }
                    if let v = v {
                        parent.coordinator.configureAnnotationView(v, for: bird)
                    }
                    return v
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
