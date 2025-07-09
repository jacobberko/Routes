import Foundation

struct RoutePreferences: Codable {
    var preferredRouteTypes: [RunRoute.RouteType] = [.road]
    var preferredElevation: ElevationPreference = .mixed
    var startFromCurrentLocation: Bool = true
    var customStartLocation: LocationCoordinate?
    
    enum ElevationPreference: String, Codable, CaseIterable {
        case flat = "Flat"
        case hilly = "Hilly"
        case mixed = "Mixed"
        
        var description: String {
            switch self {
            case .flat:
                return "Minimal elevation change"
            case .hilly:
                return "Significant hills"
            case .mixed:
                return "Moderate elevation"
            }
        }
    }
}

// Extension for preference storage
extension RoutePreferences {
    static func loadFromUserDefaults() -> RoutePreferences {
        guard let data = UserDefaults.standard.data(forKey: "routePreferences") else {
            return RoutePreferences()
        }
        
        do {
            return try JSONDecoder().decode(RoutePreferences.self, from: data)
        } catch {
            print("Error decoding route preferences: \(error)")
            return RoutePreferences()
        }
    }
    
    func saveToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: "routePreferences")
        } catch {
            print("Error saving route preferences: \(error)")
        }
    }
}

// Extension to get descriptive text for route types
extension RunRoute.RouteType {
    var description: String {
        switch self {
        case .road:
            return "Primarily paved surfaces"
        case .trail:
            return "Parks and nature paths"
        case .mixed:
            return "Combination of both"
        }
    }
    
    var iconName: String {
        switch self {
        case .road:
            return "road.lanes"
        case .trail:
            return "leaf.fill"
        case .mixed:
            return "arrow.triangle.branch"
        }
    }
}
