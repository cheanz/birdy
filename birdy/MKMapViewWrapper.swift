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
    }

    private func regionsEqual(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
        let centerTol: CLLocationDistance = 50
        let aLoc = CLLocation(latitude: a.center.latitude, longitude: a.center.longitude)
        let bLoc = CLLocation(latitude: b.center.latitude, longitude: b.center.longitude)
        return aLoc.distance(from: bLoc) <= centerTol && abs(a.span.latitudeDelta - b.span.latitudeDelta) < 0.001 && abs(a.span.longitudeDelta - b.span.longitudeDelta) < 0.001
    }
}
