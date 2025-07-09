import SwiftUI

struct ContentView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeViewModel: RouteGeneratorViewModel
    
    var body: some View {
        // Now directly shows RouteGeneratorView instead of a TabView
        RouteGeneratorView()
            .onAppear {
                // Handle location permissions
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestPermission()
                }
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(LocationManager())
            .environmentObject(RouteGeneratorViewModel())
    }
}
