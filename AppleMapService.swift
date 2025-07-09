//
//  AppleMapService.swift
//  Routes‑C
//
//  Out‑and‑Back route generator – May 2025
//
//  Improved Algorithm:
//  - Better distance matching with tighter tolerance
//  - Multiple waypoint support for smoother loops
//  - Rate limit detection and handling
//  - Trail/Road preference support
//

import Foundation
import MapKit
import CoreLocation

enum RouteGenError: Error, LocalizedError {
    case noRouteFound
    case allAttemptsFailed
    case rateLimited
    case invalidDistance

    var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "Couldn't find a path for that segment."
        case .allAttemptsFailed:
            return "Unable to build a route after several tries."
        case .rateLimited:
            return "Too many requests. Please wait 60 seconds and try again."
        case .invalidDistance:
            return "Could not generate a route for the requested distance."
        }
    }
}

final class AppleMapService {
    
    // Improved parameters
    private let maxTries = 8
    private let tolerance = 0.3       // ±0.3 miles (much tighter)
    private let maxTolerancePercent = 0.15  // 15% of target distance
    
    // Rate limiting tracking
    private static var lastRequestTime: Date?
    private static let minRequestInterval: TimeInterval = 1.0  // 1 second between requests
    
    func generateRoute(from start: CLLocationCoordinate2D,
                       targetDistance miles: Double,
                       preferences: RoutePreferences) async throws -> RunRoute {
        
        // Use dynamic tolerance based on distance
        let dynamicTolerance = min(tolerance, miles * maxTolerancePercent)
        
        var bestRoute: RunRoute?
        var bestDelta = Double.greatestFiniteMagnitude
        var attempts = 0
        
        // Try different strategies based on distance
        let strategies: [(name: String, waypoints: Int)] = miles < 2 ?
            [("triangle", 2), ("square", 3)] :
            [("square", 3), ("pentagon", 4), ("triangle", 2)]
        
        strategyLoop: for strategy in strategies {
            for attempt in 0..<maxTries {
                attempts += 1
                
                do {
                    // Check rate limiting
                    try await enforceRateLimit()
                    
                    // Generate waypoints for this strategy
                    let waypoints = generateWaypoints(
                        from: start,
                        targetDistance: miles,
                        numberOfPoints: strategy.waypoints,
                        attempt: attempt
                    )
                    
                    // Build the complete route
                    let route = try await buildRoute(
                        from: start,
                        through: waypoints,
                        preferences: preferences
                    )
                    
                    let delta = abs(route.distance - miles)
                    
                    if delta < bestDelta {
                        bestRoute = route
                        bestDelta = delta
                        
                        // If within tolerance, we're done
                        if delta <= dynamicTolerance {
                            break strategyLoop
                        }
                    }
                    
                } catch let error as NSError {
                    // Check for rate limiting error
                    if error.domain == "MKErrorDomain" && (error.code == 3 || error.code == 4) {
                        throw RouteGenError.rateLimited
                    }
                    // Continue trying other options
                    continue
                }
            }
        }
        
        guard let route = bestRoute else {
            throw RouteGenError.allAttemptsFailed
        }
        
        // Check if the best route is still too far off
        if bestDelta > miles * 0.3 {  // More than 30% off
            throw RouteGenError.invalidDistance
        }
        
        return route
    }
    
    // MARK: - Private Methods
    
    private func generateWaypoints(from start: CLLocationCoordinate2D,
                                   targetDistance: Double,
                                   numberOfPoints: Int,
                                   attempt: Int) -> [CLLocationCoordinate2D] {
        
        var waypoints: [CLLocationCoordinate2D] = []
        
        // Estimate radius for each leg
        let estimatedPerimeter = targetDistance
        let radius = estimatedPerimeter / (2.5 * Double(numberOfPoints + 1))
        
        // Add some variation based on attempt number
        let radiusVariation = 1.0 + (Double(attempt) * 0.15)
        let adjustedRadius = radius * radiusVariation
        
        // Generate waypoints in a roughly circular pattern
        let angleStep = (2 * .pi) / Double(numberOfPoints)
        let startAngle = Double.random(in: 0..<(2 * .pi))
        
        for i in 0..<numberOfPoints {
            // Add some randomness to prevent perfect circles
            let angleVariation = Double.random(in: -0.3...0.3)
            let angle = startAngle + (Double(i) * angleStep) + angleVariation
            
            // Vary the radius slightly for each point
            let radiusJitter = Double.random(in: 0.8...1.2)
            let pointRadius = adjustedRadius * radiusJitter
            
            let waypoint = offset(from: start, miles: pointRadius, bearing: angle)
            waypoints.append(waypoint)
        }
        
        return waypoints
    }
    
    private func buildRoute(from start: CLLocationCoordinate2D,
                            through waypoints: [CLLocationCoordinate2D],
                            preferences: RoutePreferences) async throws -> RunRoute {
        
        var allCoordinates: [CLLocationCoordinate2D] = []
        var totalDistance: Double = 0
        var totalElevationGain: Double = 0
        
        // Build route: start -> waypoint1 -> waypoint2 -> ... -> start
        var currentPoint = start
        let allPoints = waypoints + [start]  // Add start at end to close loop
        
        for nextPoint in allPoints {
            let (coords, distance, elevation) = try await routeSegment(
                from: currentPoint,
                to: nextPoint,
                preferences: preferences
            )
            
            // Avoid duplicate coordinates at connection points
            if allCoordinates.isEmpty {
                allCoordinates.append(contentsOf: coords)
            } else {
                allCoordinates.append(contentsOf: coords.dropFirst())
            }
            
            totalDistance += distance
            totalElevationGain += elevation
            currentPoint = nextPoint
        }
        
        return RunRoute(
            name: String(format: "Loop %.1f mi", totalDistance),
            distance: totalDistance,
            startLocation: LocationCoordinate(coordinate: start),
            routePoints: allCoordinates.map { LocationCoordinate(coordinate: $0) },
            elevationGain: totalElevationGain,
            routeType: preferences.preferredRouteTypes.first ?? .road
        )
    }
    
    private func routeSegment(from: CLLocationCoordinate2D,
                              to: CLLocationCoordinate2D,
                              preferences: RoutePreferences) async throws -> (coords: [CLLocationCoordinate2D], miles: Double, elevationGain: Double) {
        
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        req.transportType = .walking
        req.requestsAlternateRoutes = true  // Get alternatives to choose from
        
        let response = try await MKDirections(request: req).calculate()
        
        // Choose the best route based on preferences
        let selectedRoute = selectBestRoute(from: response.routes, preferences: preferences)
        
        guard let route = selectedRoute else {
            throw RouteGenError.noRouteFound
        }
        
        // Estimate elevation gain (Apple Maps doesn't provide this directly)
        let estimatedElevationGain = route.distance * 0.01  // Rough estimate: 1% grade average
        
        return (
            route.polyline.coordinates(),
            route.distance / 1609.34,
            estimatedElevationGain
        )
    }
    
    private func selectBestRoute(from routes: [MKRoute], preferences: RoutePreferences) -> MKRoute? {
        // If only one route, return it
        if routes.count == 1 {
            return routes.first
        }
        
        // Try to select based on preferences
        // Note: Apple Maps doesn't give us direct trail/road info, but we can make educated guesses
        // Longer routes often include more parks/trails
        
        if preferences.preferredRouteTypes.contains(.trail) {
            // Prefer longer routes as they might include more trails
            return routes.max(by: { $0.distance < $1.distance })
        } else if preferences.preferredRouteTypes.contains(.road) {
            // Prefer shorter, more direct routes
            return routes.min(by: { $0.distance < $1.distance })
        } else {
            // Mixed: choose middle option if available
            return routes.sorted(by: { $0.distance < $1.distance })[routes.count / 2]
        }
    }
    
    private func enforceRateLimit() async throws {
        if let lastTime = Self.lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastTime)
            if timeSinceLastRequest < Self.minRequestInterval {
                let waitTime = Self.minRequestInterval - timeSinceLastRequest
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        Self.lastRequestTime = Date()
    }
    
    private func offset(from coord: CLLocationCoordinate2D,
                        miles: Double,
                        bearing: Double) -> CLLocationCoordinate2D {
        let R = 3958.8  // Earth radius in miles
        let d = miles / R
        let lat1 = coord.latitude * .pi / 180
        let lon1 = coord.longitude * .pi / 180
        
        let lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(d) * cos(lat1),
                                cos(d) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
}

private extension MKPolyline {
    func coordinates() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
