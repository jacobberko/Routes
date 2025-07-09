import SwiftUI
import MapKit

@main
struct RoutesApp: App {
    // Create shared instances of our view models and services
    @StateObject private var locationManager = LocationManager()
    @StateObject private var routeViewModel = RouteGeneratorViewModel()
    
    // Only use the AppStorage property - we don't need the extra State
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    
    var body: some Scene {
        WindowGroup {
            if !hasLaunchedBefore {
                WelcomeView()
                    .environmentObject(locationManager)
                    .environmentObject(routeViewModel)
                    .onDisappear {
                        // Set the flag when user dismisses welcome screen
                        hasLaunchedBefore = true
                    }
            } else {
                // The main app content view
                ContentView()
                    .environmentObject(locationManager)
                    .environmentObject(routeViewModel)
            }
        }
    }
}
