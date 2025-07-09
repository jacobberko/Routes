import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var routeViewModel: RouteGeneratorViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Local copy for editing
    @State private var preferences: RoutePreferences
    
    init() {
        // Create a copy of preferences for editing
        _preferences = State(initialValue: RoutePreferences())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ROUTE TYPE")) {
                    ForEach(RunRoute.RouteType.allCases, id: \.self) { routeType in
                        Toggle(routeType.rawValue, isOn: Binding(
                            get: {
                                preferences.preferredRouteTypes.contains(routeType)
                            },
                            set: { isOn in
                                if isOn {
                                    if !preferences.preferredRouteTypes.contains(routeType) {
                                        preferences.preferredRouteTypes.append(routeType)
                                    }
                                } else {
                                    preferences.preferredRouteTypes.removeAll { $0 == routeType }
                                    
                                    // Ensure at least one type is selected
                                    if preferences.preferredRouteTypes.isEmpty {
                                        preferences.preferredRouteTypes = [.road]
                                    }
                                }
                            }
                        ))
                    }
                }
                
                Section(header: Text("ELEVATION PREFERENCE")) {
                    Picker("Elevation", selection: $preferences.preferredElevation) {
                        ForEach(RoutePreferences.ElevationPreference.allCases, id: \.self) { preference in
                            Text(preference.rawValue).tag(preference)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("START LOCATION")) {
                    Toggle("Start from current location", isOn: $preferences.startFromCurrentLocation)
                    
                    if !preferences.startFromCurrentLocation {
                        Text("Custom location selection coming soon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(footer: Text("Routes will use these preferences when generating new routes.")) {
                    Button(action: {
                        // Reset to defaults
                        preferences = RoutePreferences()
                    }) {
                        Text("Reset to Defaults")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Preferences")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    routeViewModel.preferences = preferences
                    routeViewModel.savePreferences()
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                // Load the current preferences when view appears
                preferences = routeViewModel.preferences
            }
        }
    }
}
