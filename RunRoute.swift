import Foundation
import MapKit
import CoreLocation

struct RunRoute: Identifiable, Codable {
    var id = UUID()
    var name: String
    var distance: Double // in miles
    var startLocation: LocationCoordinate
    var routePoints: [LocationCoordinate]
    var elevationGain: Double
    var routeType: RouteType
    var isFavorite: Bool = false
    var createdDate: Date = Date()
    
    enum RouteType: String, Codable, CaseIterable {
        case road = "Road"
        case trail = "Trail"
        case mixed = "Mixed"
    }
}

// Make CLLocationCoordinate2D codable for storage
struct LocationCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// Helper extensions
extension RunRoute {
    // Sample route for preview
    static var sample: RunRoute {
        RunRoute(
            name: "Morning Loop",
            distance: 3.2,
            startLocation: LocationCoordinate(latitude: 37.7749, longitude: -122.4194),
            routePoints: [
                LocationCoordinate(latitude: 37.7749, longitude: -122.4194),
                LocationCoordinate(latitude: 37.7750, longitude: -122.4195),
                LocationCoordinate(latitude: 37.7752, longitude: -122.4198),
                LocationCoordinate(latitude: 37.7756, longitude: -122.4200),
                LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
            ],
            elevationGain: 125,
            routeType: .mixed
        )
    }
}

extension RunRoute {
    func toGPX() -> String {
        var gpxString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Routes-C App"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(self.name.escapedForXML())</name>
            <desc>Distance: \(String(format: "%.2f", self.distance)) miles, Elevation Gain: \(Int(self.elevationGain)) ft, Type: \(self.routeType.rawValue)</desc>
            <time>\(self.createdDate.ISO8601Format())</time>
          </metadata>
          <trk>
            <name>\(self.name.escapedForXML())</name>
            <trkseg>
        """

        for point in self.routePoints { //
            // Note: GPX typically includes elevation and timestamp per point if available.
            // We don't store elevation per point, so we'll omit the <ele> tag for now.
            gpxString += """
                  <trkpt lat="\(point.latitude)" lon="\(point.longitude)"></trkpt>\n
            """ //
        }

        gpxString += """
            </trkseg>
          </trk>
        </gpx>
        """
        return gpxString
    }
}

// Helper to escape characters for XML content
extension String {
    func escapedForXML() -> String {
        return self.replacingOccurrences(of: "&", with: "&amp;")
                   .replacingOccurrences(of: "<", with: "&lt;")
                   .replacingOccurrences(of: ">", with: "&gt;")
                   .replacingOccurrences(of: "\"", with: "&quot;")
                   .replacingOccurrences(of: "'", with: "&apos;")
    }
}

