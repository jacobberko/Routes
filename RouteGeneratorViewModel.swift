import Foundation
import MapKit
import SwiftUI

@MainActor
class RouteGeneratorViewModel: ObservableObject {
    private var mapService = AppleMapService()
    private var lastTargetDistance: Double? = nil

    @Published var targetDistance: Double = 3.0
    @Published var preferences = RoutePreferences()
    @Published var isGeneratingRoute = false
    @Published var generatedRoutes: [RunRoute] = []
    @Published var currentRouteIndex: Int? = nil
    @Published var savedRoutes: [RunRoute] = []
    @Published var errorMessage: String?

    @Published var showingError = false
    @Published var showingPreferences = false
    
    private var currentRouteTask: Task<Void, Never>?
    private var rateLimitedUntil: Date?

    var currentDisplayedRoute: RunRoute? {
        guard let index = currentRouteIndex, generatedRoutes.indices.contains(index) else {
            return nil
        }
        return generatedRoutes[index]
    }

    var canShowPreviousRoute: Bool {
        guard let index = currentRouteIndex else { return false }
        return index > 0
    }

    var canShowNextRoute: Bool {
        guard let index = currentRouteIndex else { return false }
        return index < generatedRoutes.count - 1
    }

    init() {
        loadSavedRoutes()
        loadPreferences()
    }
    
    deinit {
        currentRouteTask?.cancel()
    }

    func generateRoute(from location: CLLocationCoordinate2D?) async {
        // Check if we're rate limited
        if let rateLimitTime = rateLimitedUntil, rateLimitTime > Date() {
            let remainingSeconds = Int(rateLimitTime.timeIntervalSinceNow)
            showError("Too many requests. Please wait \(remainingSeconds) seconds and try again.")
            return
        }
        
        // Cancel any existing route generation task
        currentRouteTask?.cancel()
        
        // Reset state
        mapService = AppleMapService()
        isGeneratingRoute = true
        errorMessage = nil
        showingError = false
        
        // Check if target distance changed - if so, clear all routes
        if targetDistance != lastTargetDistance {
            generatedRoutes.removeAll()
            currentRouteIndex = nil
            lastTargetDistance = targetDistance
        }
        
        guard let startLocation = location else {
            showError("Unable to determine your location. Please enable location services.")
            return
        }

        // Create a new task for this route generation
        currentRouteTask = Task {
            do {
                // Generate only ONE route at a time
                let route = try await mapService.generateRoute(
                    from: startLocation,
                    targetDistance: targetDistance,
                    preferences: preferences
                )
                
                if Task.isCancelled {
                    return
                }
                
                // Add the new route to our collection
                self.generatedRoutes.append(route)
                
                // Update the current index to show the new route
                self.currentRouteIndex = self.generatedRoutes.count - 1
                
                self.isGeneratingRoute = false
                
            } catch let error as RouteGenError {
                if !Task.isCancelled {
                    switch error {
                    case .rateLimited:
                        // Set rate limit timeout
                        self.rateLimitedUntil = Date().addingTimeInterval(60)
                        self.showError("Too many requests. Please wait 60 seconds and try again.")
                    case .invalidDistance:
                        self.showError("Unable to generate a route matching your requested distance. Try adjusting the distance or starting location.")
                    default:
                        self.showError(error.localizedDescription)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    print("Route generation error: \(error)")
                    self.showError("Failed to generate route. Please try again.")
                }
            }
        }
    }
    
    func loadSavedRoute(_ route: RunRoute) {
        // Check if this route is already in our generated routes
        if !generatedRoutes.contains(where: { $0.id == route.id }) {
            // Clear existing routes if loading a saved route with different distance
            if route.distance != targetDistance {
                generatedRoutes.removeAll()
                targetDistance = route.distance
                lastTargetDistance = route.distance
            }
            generatedRoutes.append(route)
        }
        
        // Find and set the index
        if let index = generatedRoutes.firstIndex(where: { $0.id == route.id }) {
            currentRouteIndex = index
        }
    }
    
    func cancelRouteGeneration() {
        currentRouteTask?.cancel()
        isGeneratingRoute = false
    }

    func showPreviousRoute() {
        guard canShowPreviousRoute, let index = currentRouteIndex else { return }
        currentRouteIndex = index - 1
    }

    func showNextRoute() {
        guard canShowNextRoute, let index = currentRouteIndex else { return }
        currentRouteIndex = index + 1
    }

    func saveCurrentRoute() {
        guard var route = currentDisplayedRoute else { return }

        // Generate a more descriptive name
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        let routeTypeStr = route.routeType.rawValue
        let suggestedName = "\(String(format: "%.1f", route.distance))mi \(routeTypeStr) - \(dateFormatter.string(from: Date()))"
        route.name = suggestedName

        // Check if already saved
        if !savedRoutes.contains(where: { $0.id == route.id }) {
            savedRoutes.append(route)
            saveToDisk()
        }
    }

    func toggleFavorite(for routeId: UUID) {
        if let index = savedRoutes.firstIndex(where: { $0.id == routeId }) {
            savedRoutes[index].isFavorite.toggle()
            saveToDisk()
        }
    }

    func deleteRoute(at indices: IndexSet) {
        savedRoutes.remove(atOffsets: indices)
        saveToDisk()
    }

    func shareRoute(_ route: RunRoute) -> URL? {
        let gpxString = route.toGPX()
        let fileName = "\(route.name.replacingOccurrences(of: " ", with: "_").filter { $0.isLetter || $0.isNumber || $0 == "_" }).gpx"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try gpxString.write(to: tempURL, atomically: true, encoding: .utf8)
            print("GPX file created at: \(tempURL.path)")
            return tempURL
        } catch {
            print("Error creating GPX file: \(error)")
            return nil
        }
    }
    
    func clearGeneratedRoutes() {
        generatedRoutes.removeAll()
        currentRouteIndex = nil
    }

    func showError(_ message: String) {
        errorMessage = message
        showingError = true
        isGeneratingRoute = false
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(savedRoutes)
            UserDefaults.standard.set(data, forKey: "savedRoutes")
        } catch {
            print("Error saving routes: \(error)")
        }
    }

    private func loadSavedRoutes() {
        guard let data = UserDefaults.standard.data(forKey: "savedRoutes") else { return }

        do {
            savedRoutes = try JSONDecoder().decode([RunRoute].self, from: data)
        } catch {
            print("Error loading saved routes: \(error)")
        }
    }

    func loadPreferences() {
        preferences = RoutePreferences.loadFromUserDefaults()
    }

    func savePreferences() {
        preferences.saveToUserDefaults()
    }
}
