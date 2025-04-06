import MapKit

// Web Mercator Projection:
// https://en.wikipedia.org/wiki/Web_Mercator_projection
//
// Google Maps Mechanics:
// https://cfis.savagexi.com/2006/05/03/google-maps-deconstructed
// https://cfis.savagexi.com/2006/05/05/google-maps-revisited
// https://cfis.savagexi.com/2006/06/30/mouse-coordinates-to-lat-long
//
// MKMapView Specifics:
// https://medium.com/@dmytrobabych/getting-actual-rotation-and-zoom-level-for-mapkit-mkmapview-e7f03f430aa9

internal extension MKMapView {
    private enum Mercator {
        /// In order to make this zoom level behave similar to google-maps, we'll be using its tile-width of 256 points.
        static let tileWidth: Double = 256.0
    }

    var zoomLevel: Double {
        return zoom(coordinateSpan: region.span, rotation: camera.heading, mapSize: bounds.size, edgeInset: layoutMargins)
    }

    func setCenterCoordinate(_ centerCoordinate: CLLocationCoordinate2D, zoomLevel: Double, animated: Bool) {
        // keep zoom level in range between min and max allowed
        let zoomLevel = zoomLevel.inRange(min: MapZoomLevel.minZoomLevel, max: MapZoomLevel.maxZoomLevel)
        // calculate span needed to grab requested zoom level, including safe area insets.
        //
        // when new region is set, `camera.heading` is set to zero by the MKMapView, that's why rotation angle is also zero here,
        // otherwise it would calculate span for larger area to wrap rotated rectangle and once applied, map would need to zoom-out
        // to fit that rectangle, breaking desired zoom level.
        // so we need to re-apply desired heading after setting new region anyways, which preserves given zoom automatically :)
        let span = coordinateSpan(
            zoomLevel: zoomLevel,
            rotation: .zero,
            mapSize: bounds.size,
            edgeInset: layoutMargins
        )
        // finally create and apply calculated region
        let region = MKCoordinateRegion(center: centerCoordinate, span: span)
        setRegion(region, animated: animated)
    }

    private func zoom(
        coordinateSpan: MKCoordinateSpan,
        rotation: CLLocationDirection,
        mapSize: CGSize,
        edgeInset: UIEdgeInsets
    ) -> Double {
        let rotationRad = rotation.radians
        // There can be some area, taken into consideration by MapKit, but not actually used by us.
        // i.e. status bar, notch or custom paddings.
        let activeHeight = Double(mapSize.height - (edgeInset.top + edgeInset.bottom))
        let activeWidth = Double(mapSize.width - (edgeInset.left + edgeInset.right))
        // When MKMapView is rotated, its region does not correspond to the screen size.
        // In reality it corresponds to the size of a rectangle, required to be rendered to cover all the screen after rotation.
        // TL;DR region for rotated map is bigger than region for the static screen.
        //
        // Knowing rotation angle, rotated region and screen size, we can calculate normal region (non-rotated).
        let rotatedLngDelta = coordinateSpan.longitudeDelta
        let normLngDelta = rotatedLngDelta * activeWidth / (activeWidth * cos(rotationRad) + activeHeight * sin(rotationRad))
        // Latitude changes nonlinearly in (Web)Mercator projection, so we can ignore its delta.
        // We only need longitude delta, because it has linear dependency on its projection for any latitude.
        return log2(360 * activeWidth / (normLngDelta * Mercator.tileWidth))
    }

    func coordinateSpan(
        zoomLevel: Double,
        rotation: CLLocationDirection,
        mapSize: CGSize,
        edgeInset: UIEdgeInsets
    ) -> MKCoordinateSpan {
        let rotationRad = rotation.radians
        // There can be some area, taken into consideration by MapKit, but not actually used by us.
        // i.e. status bar, notch or custom paddings.
        let activeHeight = Double(mapSize.height - (edgeInset.top + edgeInset.bottom))
        let activeWidth = Double(mapSize.width - (edgeInset.left + edgeInset.right))
        // When MKMapView is rotated, its region does not correspond to the screen size.
        // In reality it corresponds to the size of a rectangle, required to be rendered to cover all the screen after rotation.
        // TL;DR region for rotated map is bigger than region for the static screen.
        //
        // Knowing rotation angle, region and screen size, we can calculate rotated region for needed zoom level.
        let normLngDelta = 360 / pow(2, zoomLevel) * (activeWidth / Mercator.tileWidth)
        let rotatedRegionWidth = activeWidth * cos(rotationRad) + (activeHeight * sin(rotationRad))
        let rotatedLngDelta = rotatedRegionWidth / (activeWidth / normLngDelta)
        // Latitude changes nonlinearly in (Web)Mercator projection, so we can ignore its delta.
        // We only need longitude delta, because it has linear dependency on its projection for any latitude.
        //
        // MKMapView will set its own latitude anyway to fit both lat and long deltas, after span is applied.
        // And passing zero latitude delta fits any map dimension, no matter what vertical insets are.
        return MKCoordinateSpan(
            latitudeDelta: .zero,
            longitudeDelta: rotatedLngDelta.isNaN ? .zero : rotatedLngDelta
        )
    }
}

extension CLLocationDirection {
    var radians: Double {
        var rotationAngle = self
        if rotationAngle > 270 {
            rotationAngle = 360 - rotationAngle
        } else if rotationAngle > 90 {
            rotationAngle = fabs(rotationAngle - 180)
        }
        return rotationAngle * (.pi / 180)
    }
}
