import SwiftUI

struct SavedRoutesView: View {
    @EnvironmentObject var routeViewModel: RouteGeneratorViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteConfirmation = false
    @State private var routeToDelete: IndexSet?
    
    var body: some View {
        NavigationView {
            Group {
                if routeViewModel.savedRoutes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "heart")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 10)
                        
                        Text("No Saved Routes")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Routes you save will appear here")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    List {
                        ForEach(routeViewModel.savedRoutes) { route in
                            SavedRouteRow(route: route)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Load the selected route into the view model
                                    routeViewModel.loadSavedRoute(route)
                                    // Dismiss the sheet
                                    presentationMode.wrappedValue.dismiss()
                                }
                        }
                        .onDelete { indexSet in
                            routeToDelete = indexSet
                            showingDeleteConfirmation = true
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Saved Routes")
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert(isPresented: $showingDeleteConfirmation) {
                Alert(
                    title: Text("Delete Route"),
                    message: Text("Are you sure you want to delete this route?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let indexSet = routeToDelete {
                            routeViewModel.deleteRoute(at: indexSet)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

struct SavedRouteRow: View {
    let route: RunRoute
    @EnvironmentObject var routeViewModel: RouteGeneratorViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name)
                    .font(.headline)
                
                Text("\(String(format: "%.2f", route.distance)) miles • \(route.routeType.rawValue)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                routeViewModel.toggleFavorite(for: route.id)
            }) {
                Image(systemName: route.isFavorite ? "star.fill" : "star")
                    .foregroundColor(route.isFavorite ? .yellow : .gray)
                    .imageScale(.large)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 8)
    }
}
