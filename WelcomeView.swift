import SwiftUI

// Main Welcome View Structure
struct WelcomeView: View {
    @State private var showMainApp = false
    @State private var animateContent = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Simple white background (only change from original)
                Color.white
                    .ignoresSafeArea()
                
                // Content Layer
                VStack(spacing: 0) {
                    Spacer(minLength: geometry.size.height * 0.05)
                    AppHeader(animate: animateContent)
                        .padding(.bottom, 30)
                    FeatureCards(animate: animateContent, geometry: geometry)
                        .padding(.horizontal, 20)
                    Spacer()
                    StartButton(animate: animateContent) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showMainApp = true
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 15 : 30)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                     withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        animateContent = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showMainApp) {
                ContentView()
                 // Pass environment objects if necessary
            }
        }
    }
}

// MARK: - Subviews

// App Logo and Title Header (Changed icon to running man)
struct AppHeader: View {
    let animate: Bool
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 45, weight: .bold))
                .foregroundColor(.green)
                .padding(18)
                .background(.ultraThinMaterial, in: Circle())
                .offset(y: animate ? 0 : -30)
                .opacity(animate ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animate)
            Text("Routes")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.primary)
                .offset(y: animate ? 0 : -20)
                .opacity(animate ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animate)
            Text("Your personal route generator")
                .font(.system(.callout))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .offset(y: animate ? 0 : -20)
                .opacity(animate ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: animate)
        }
    }
}

// Feature Cards Section
struct FeatureCards: View {
    let animate: Bool
    let geometry: GeometryProxy
    let cardInfo: [(icon: String, title: String, description: String, color: Color)] = [
        ("map.fill", "Custom Distance", "Create routes perfectly matched to your target mileage", .blue),
        ("road.lanes", "Various Terrains", "Choose from roads, trails, or mixed terrain routes", .blue),
        ("mountain.2.fill", "Elevation Control", "Set your elevation preference from flat to hilly", .teal)
    ]
    var body: some View {
        VStack(spacing: 15) {
            ForEach(0..<cardInfo.count, id: \.self) { index in
                FeatureCard(
                    icon: cardInfo[index].icon,
                    title: cardInfo[index].title,
                    description: cardInfo[index].description,
                    color: cardInfo[index].color,
                    delay: 0.4 + Double(index) * 0.1
                )
                .offset(x: animate ? 0 : -geometry.size.width / 2)
                .opacity(animate ? 1 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.4 + Double(index) * 0.1), value: animate)
            }
        }
    }
}

// Individual Feature Card Component
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let delay: Double
    @State private var appear = false
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.headline))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(.subheadline))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(15)
        .background(.thinMaterial) // Using Material for better blending
        .cornerRadius(12)
    }
}

// Start Button Component
struct StartButton: View {
    let animate: Bool
    let action: () -> Void
    let accentColor: Color = .blue
    var body: some View {
        Button(action: action) {
            Text("Start Running")
                .font(.system(.title3))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(accentColor)
                .cornerRadius(12)
                .shadow(color: accentColor.opacity(0.2), radius: 5, x: 0, y: 3)
        }
        .offset(y: animate ? 0 : 50)
        .opacity(animate ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7), value: animate)
    }
}
