import SwiftUI
import MapKit

struct RouteGeneratorView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeViewModel: RouteGeneratorViewModel

    @State private var isDistancePickerShowing = false
    @State private var showRouteOptions = false
    @State private var showingShareSheet = false
    @State private var shareURL: URL? = nil
    @State private var showingSavedRoutes = false

    var body: some View {
        ZStack {
            // Map View
            RouteMapView(route: routeViewModel.currentDisplayedRoute,
                         locationManager: locationManager)
                .edgesIgnoringSafeArea(.all)

            // Control overlay
            VStack {
                // Top controls
                HStack {
                    // Saved Routes
                    Button(action: { showingSavedRoutes = true }) {
                        HStack {
                            Image(systemName: "heart")
                            Text("Saved")
                                .font(.subheadline).fontWeight(.medium)
                        }
                        .padding(8)
                        .background(.thinMaterial)
                        .cornerRadius(8)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 8)

                    Spacer()

                    // Clear
                    if !routeViewModel.generatedRoutes.isEmpty {
                        Button(action: {
                            withAnimation { routeViewModel.clearGeneratedRoutes() }
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear")
                                    .font(.subheadline).fontWeight(.medium)
                            }
                            .padding(8)
                            .background(.thinMaterial)
                            .cornerRadius(8)
                        }
                        .padding(.trailing, 8)
                        .padding(.top, 8)
                    }

                    // Route options toggle
                    Button(action: { showRouteOptions.toggle() }) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text(routeOptionsLabel)
                                .font(.subheadline).fontWeight(.medium)
                        }
                        .padding(8)
                        .background(.thinMaterial)
                        .cornerRadius(8)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }

                Spacer()

                // Bottom control panel
                ZStack(alignment: .bottom) {
                    VStack(spacing: 16) {
                        // Distance
                        distanceSelector

                        // Route prefs
                        if showRouteOptions {
                            routeOptionsView
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .zIndex(1)
                        }

                        // Route navigation
                        if !routeViewModel.generatedRoutes.isEmpty {
                            routeNavigationControls
                                .padding(.bottom, 8)
                        }

                        // Generate
                        generateButton

                        // Route info
                        if let route = routeViewModel.currentDisplayedRoute {
                            routeInfoCard(route)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 8)
                    )
                    .padding()
                    .animation(.spring(response: 0.3, dampingFraction: 0.8),
                               value: showRouteOptions)
                }
            }

            // Loading overlay
            if routeViewModel.isGeneratingRoute {
                loadingOverlay
            }
        }
        .sheet(isPresented: $routeViewModel.showingPreferences) {
            PreferencesView().environmentObject(routeViewModel)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL { ShareSheetView(activityItems: [url]) }
        }
        .sheet(isPresented: $showingSavedRoutes) {
            SavedRoutesView().environmentObject(routeViewModel)
        }
        .alert(isPresented: $routeViewModel.showingError) {
            Alert(title: Text("Error"),
                  message: Text(routeViewModel.errorMessage ?? "Unknown error"),
                  dismissButton: .default(Text("OK")) {
                      routeViewModel.isGeneratingRoute = false
                  })
        }
    }

    // MARK: - Computed

    private var routeOptionsLabel: String {
        let rt = routeViewModel.preferences.preferredRouteTypes.first?.rawValue ?? "Road"
        let el = routeViewModel.preferences.preferredElevation.rawValue
        return "\(rt) • \(el)"
    }

    private func isRouteSaved(_ id: UUID) -> Bool {
        routeViewModel.savedRoutes.contains(where: { $0.id == id })
    }

    // MARK: - Components

    // Distance picker button with collapse chevron
    private var distanceSelector: some View {
        VStack(spacing: 4) {
            Text("Desired Distance")
                .font(.subheadline).foregroundColor(.secondary)

            Button { isDistancePickerShowing.toggle() } label: {
                HStack {
                    Text(String(format: "%.1f", routeViewModel.targetDistance) + " miles")
                        .font(.title2).fontWeight(.semibold)
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8).padding(.horizontal, 16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .overlay(
            Group {
                if showRouteOptions {
                    Button(action: {
                        withAnimation { showRouteOptions = false }
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.title2).foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                    .padding(.trailing, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            },
            alignment: .trailing
        )
        .sheet(isPresented: $isDistancePickerShowing) {
            DistancePickerView(distance: $routeViewModel.targetDistance,
                               isPresented: $isDistancePickerShowing)
        }
    }

    // Route options (type + elevation)
    private var routeOptionsView: some View {
        VStack(spacing: 16) {
            // Route type chips
            VStack(alignment: .leading, spacing: 8) {
                Text("ROUTE TYPE")
                    .font(.caption).foregroundColor(.secondary).padding(.leading, 4)

                HStack {
                    ForEach(RunRoute.RouteType.allCases, id: \.self) { t in
                        Button {
                            routeViewModel.preferences.preferredRouteTypes = [t]
                            routeViewModel.savePreferences()
                        } label: {
                            HStack {
                                if routeViewModel.preferences.preferredRouteTypes.contains(t) {
                                    Image(systemName: "checkmark").font(.caption)
                                }
                                Text(t.rawValue).font(.subheadline)
                            }
                            .padding(.vertical, 8).padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8).fill(
                                    routeViewModel.preferences.preferredRouteTypes.contains(t)
                                    ? Color.blue.opacity(0.2)
                                    : Color(.tertiarySystemBackground))
                            )
                            .foregroundColor(
                                routeViewModel.preferences.preferredRouteTypes.contains(t)
                                ? .blue : .primary)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)

            // Elevation chips
            VStack(alignment: .leading, spacing: 8) {
                Text("ELEVATION")
                    .font(.caption).foregroundColor(.secondary).padding(.leading, 4)

                HStack {
                    ForEach(RoutePreferences.ElevationPreference.allCases, id: \.self) { p in
                        Button {
                            routeViewModel.preferences.preferredElevation = p
                            routeViewModel.savePreferences()
                        } label: {
                            HStack {
                                if routeViewModel.preferences.preferredElevation == p {
                                    Image(systemName: "checkmark").font(.caption)
                                }
                                Text(p.rawValue).font(.subheadline)
                            }
                            .padding(.vertical, 8).padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8).fill(
                                    routeViewModel.preferences.preferredElevation == p
                                    ? Color.blue.opacity(0.2)
                                    : Color(.tertiarySystemBackground))
                            )
                            .foregroundColor(
                                routeViewModel.preferences.preferredElevation == p
                                ? .blue : .primary)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // Previous / next buttons
    private var routeNavigationControls: some View {
        HStack {
            Button { routeViewModel.showPreviousRoute() } label: {
                Image(systemName: "arrow.left.circle.fill").font(.title)
            }
            .disabled(!routeViewModel.canShowPreviousRoute)
            .opacity(routeViewModel.canShowPreviousRoute ? 1 : 0.3)

            Spacer()

            Text("Route \(routeViewModel.currentRouteIndex.map { $0 + 1 } ?? 1)"
                 + " of \(routeViewModel.generatedRoutes.count)")
                .font(.headline)

            Spacer()

            Button { routeViewModel.showNextRoute() } label: {
                Image(systemName: "arrow.right.circle.fill").font(.title)
            }
            .disabled(!routeViewModel.canShowNextRoute)
            .opacity(routeViewModel.canShowNextRoute ? 1 : 0.3)
        }
        .padding(.horizontal)
    }

    // Generate button
    private var generateButton: some View {
        Button {
            guard let loc = locationManager.location?.coordinate else {
                routeViewModel.showError("Unable to determine your location")
                return
            }
            Task { await routeViewModel.generateRoute(from: loc) }
        } label: {
            HStack {
                if routeViewModel.isGeneratingRoute {
                    ProgressView().progressViewStyle(
                        CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(routeViewModel.generatedRoutes.isEmpty
                     ? "Generate First Route" : "Generate Another Route")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).padding()
            .background(Color.blue).cornerRadius(12)
        }
        .disabled(routeViewModel.isGeneratingRoute)
    }

    // Route info card
    private func routeInfoCard(_ r: RunRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Route Details").font(.headline)
                    HStack {
                        Text(String(format: "%.2f", r.distance) + " miles")
                            .font(.subheadline).foregroundColor(.secondary)
                        let diff = abs(r.distance - routeViewModel.targetDistance)
                        if diff < 0.1 {
                            Label("Exact match", systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundColor(.green)
                        } else if diff < 0.3 {
                            Label("Close match", systemImage: "checkmark.circle")
                                .font(.caption).foregroundColor(.orange)
                        }
                    }
                }

                Spacer()

                Button { routeViewModel.saveCurrentRoute() } label: {
                    Image(systemName: isRouteSaved(r.id) ? "heart.fill" : "heart")
                        .font(.title2).foregroundColor(.pink)
                }
                .padding(.leading)

                Button {
                    if let url = routeViewModel.shareRoute(r) {
                        shareURL = url; showingShareSheet = true
                    } else {
                        routeViewModel.showError("Could not prepare route for sharing.")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up").font(.title2)
                }
            }

            Divider()

            HStack(spacing: 20) {
                RouteInfoItem(title: "Type",
                              value: r.routeType.rawValue,
                              icon: r.routeType.iconName)
                RouteInfoItem(title: "Elevation",
                              value: "\(Int(r.elevationGain))ft",
                              icon: "mountain.2.fill")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.top, 8)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.easeInOut, value: routeViewModel.currentRouteIndex)
    }

    // Dim / spinner overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("Generating your perfect route…")
                    .font(.headline).foregroundColor(.white)

                Text("This may take a few moments")
                    .font(.caption).foregroundColor(.white.opacity(0.8))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
            )
            .transition(.opacity)
        }
    }
}

// MARK: - Helper components

struct RouteInfoItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).foregroundColor(.blue).imageScale(.small)
                Text(title).font(.caption).foregroundColor(.secondary)
            }
            Text(value).font(.subheadline).fontWeight(.medium)
        }
    }
}

// MARK: - Distance Picker

struct DistancePickerView: View {
    @Binding var distance: Double
    @Binding var isPresented: Bool

    // Private state
    @State private var selectedDistance: Double
    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    @GestureState private var dragOffset: CGFloat = 0

    // Constants
    private let minDistance: Double = 0.5
    private let maxDistance: Double = 15.0
    private let tickStep: Double = 0.1
    private let wheelHeight: CGFloat = 300
    private let itemHeight: CGFloat = 60
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let accent = Color.blue

    private var values: [Double] {
        stride(from: minDistance, through: maxDistance, by: tickStep).map { $0 }
    }

    init(distance: Binding<Double>, isPresented: Binding<Bool>) {
        _distance = distance
        _isPresented = isPresented
        _selectedDistance = State(initialValue: distance.wrappedValue)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                Text(String(format: "%.1f", selectedDistance))
                    .font(.system(size: 76, weight: .light, design: .rounded))
                    .foregroundColor(accent)
                    .frame(height: 90)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: selectedDistance)

                Text("miles")
                    .font(.headline).foregroundColor(.secondary)
                    .padding(.bottom, 25)

                // Picker wheel
                ZStack {
                    // highlight
                    RoundedRectangle(cornerRadius: 16)
                        .fill(accent.opacity(0.15))
                        .frame(height: itemHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(accent, lineWidth: 2)
                        )
                        .padding(.horizontal, 40)
                        .allowsHitTesting(false)

                    GeometryReader { geo in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                Spacer(minLength: geo.size.height / 2 - itemHeight / 2)

                                ForEach(values.indices, id: \.self) { i in
                                    let val = values[i]
                                    Text(String(format: "%.1f", val))
                                        .font(.system(.title2, design: .rounded))
                                        .fontWeight(abs(val - selectedDistance) < 0.001 ? .bold : .regular)
                                        .foregroundColor(abs(val - selectedDistance) < 0.001 ? accent : .primary)
                                        .opacity(abs(val - selectedDistance) < 0.001 ? 1 : 0.7)
                                        .frame(height: itemHeight)
                                        .frame(maxWidth: .infinity)
                                }

                                Spacer(minLength: geo.size.height / 2 - itemHeight / 2)
                            }
                        }
                        .content.offset(y: scrollOffset + dragOffset)
                        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8),
                                   value: scrollOffset)
                        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8),
                                   value: dragOffset)
                    }

                    // Fades
                    VStack {
                        LinearGradient(gradient: Gradient(colors: [
                            Color(.systemBackground),
                            Color(.systemBackground).opacity(0)
                        ]), startPoint: .top, endPoint: .bottom)
                            .frame(height: wheelHeight / 3)
                        Spacer()
                        LinearGradient(gradient: Gradient(colors: [
                            Color(.systemBackground).opacity(0),
                            Color(.systemBackground)
                        ]), startPoint: .top, endPoint: .bottom)
                            .frame(height: wheelHeight / 3)
                    }
                    .allowsHitTesting(false)
                }
                .frame(height: wheelHeight)
                .clipped()
                .padding(.horizontal, 20)
                .contentShape(Rectangle()) // Entire box is draggable
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { v, state, _ in
                            state = v.translation.height
                            isDragging = true
                        }
                        .onChanged { v in
                            let total = scrollOffset + v.translation.height
                            let idx   = Int(round(total / -itemHeight))
                            let bounded = min(max(0, idx), values.count - 1)
                            let newVal = values[bounded]

                            if abs(newVal - selectedDistance) > 0.0001 {
                                selectedDistance = newVal
                                haptic.impactOccurred()
                            }
                        }
                        .onEnded { v in
                            isDragging = false
                            scrollOffset += v.translation.height
                            let idx = Int(round(scrollOffset / -itemHeight))
                            let bounded = min(max(0, idx), values.count - 1)

                            withAnimation(.spring()) {
                                scrollOffset = -CGFloat(bounded) * itemHeight
                                selectedDistance = values[bounded]
                            }
                            haptic.impactOccurred()
                        }
                )
                .onAppear {
                    if let i = values.firstIndex(where: { abs($0 - selectedDistance) < 0.001 }) {
                        scrollOffset = -CGFloat(i) * itemHeight
                    }
                }
                .onChange(of: selectedDistance) { newVal in
                    if !isDragging,
                       let i = values.firstIndex(where: { abs($0 - newVal) < 0.001 }) {
                        withAnimation(.spring()) {
                            scrollOffset = -CGFloat(i) * itemHeight
                        }
                    }
                }

                // Quick select buttons
                VStack(alignment: .leading) {
                    Text("Quick select")
                        .font(.subheadline).foregroundColor(.secondary)
                        .padding(.leading, 20)
                        .padding(.top, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach([1, 2, 3, 5, 7, 10], id: \.self) { v in
                                Button {
                                    withAnimation(.spring()) { selectedDistance = Double(v) }
                                    haptic.impactOccurred()
                                } label: {
                                    Text("\(v)mi")
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.medium)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(
                                            Capsule().fill(
                                                abs(selectedDistance - Double(v)) < 0.001
                                                ? accent
                                                : Color(.tertiarySystemBackground))
                                        )
                                        .foregroundColor(
                                            abs(selectedDistance - Double(v)) < 0.001
                                            ? .white : .primary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    }
                }

                Spacer()
            }
            .padding(.top, 20)
            .navigationBarTitle("Set Distance", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { isPresented = false },
                trailing: Button("Done") {
                    distance = selectedDistance
                    isPresented = false
                }
            )
        }
    }
}

// Preview
struct DistancePickerView_Previews: PreviewProvider {
    static var previews: some View {
        DistancePickerView(distance: .constant(3.0), isPresented: .constant(true))
    }
}
