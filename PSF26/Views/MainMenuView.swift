import SwiftUI

struct ActiveLeague: Identifiable, Equatable {
    let id = UUID()
    let teamName: String
    let logoName: String
    let customLogoData: Data?
    let league: League?
    
    init(teamName: String, logoName: String, customLogoData: Data?, league: League? = nil) {
        self.teamName = teamName
        self.logoName = logoName
        self.customLogoData = customLogoData
        self.league = league
    }
    
    static func == (lhs: ActiveLeague, rhs: ActiveLeague) -> Bool {
        return lhs.id == rhs.id
    }
}

struct MainMenuView: View {
    @State private var logoOpacity = 0.0
    @State private var logoOffset: CGFloat = 0
    @State private var settingsOpacity = 0.0
    @State private var loadLeagueOpacity = 0.0
    @State private var createLeagueOpacity = 0.0
    @State private var animationComplete = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showingSettings = false
    @State private var showingCreateLeague = false
    @State private var showingLoadLeague = false
    @State private var activeLeague: ActiveLeague? = nil
    @StateObject private var coreLeagueManager = CoreLeagueManager.shared
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Image("gradient-background")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                    
                    // Logo positioned behind scrollable content
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: logoSize(scrollOffset: scrollOffset, screenWidth: geometry.size.width),
                            height: logoSize(scrollOffset: scrollOffset, screenWidth: geometry.size.width)
                        )
                        .opacity(logoDisplayOpacity(scrollOffset: scrollOffset, baseOpacity: logoOpacity))
                        .position(
                            x: geometry.size.width / 2,
                            y: logoYPosition(scrollOffset: scrollOffset, screenHeight: geometry.size.height)
                        )
                        .allowsHitTesting(false)
                    
                    // ScrollView positioned above logo in ZStack
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Top spacer for initial button positioning
                            Color.clear
                                .frame(height: geometry.size.height * 0.5)
                            
                            VStack(spacing: 16) {
                                // Create New League Button
                                Button(action: {
                                    showingCreateLeague = true
                                }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(.white)
                                        
                                        Text("Create New League")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.white)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 16)
                                }
                                .frame(width: logoWidth(geometry: geometry))
                                .glassEffect(.regular.interactive())
                                .opacity(createLeagueOpacity)
                                
                                // Load League Button
                                Button(action: {
                                    showingLoadLeague = true
                                }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(.white)
                                        
                                        Text("Load League")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.white)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 16)
                                }
                                .frame(width: logoWidth(geometry: geometry))
                                .glassEffect(.regular.interactive())
                                .opacity(loadLeagueOpacity)
                                
                                NavigationLink {
                                    SettingsView()
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "gearshape.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(.white)
                                        
                                        Text("Settings")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.white)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 16)
                                }
                                .frame(width: logoWidth(geometry: geometry))
                                .glassEffect(.regular.interactive())
                                .opacity(settingsOpacity)
                            }
                            .opacity(animationComplete ? 1.0 : 0.0)
                            .position(x: geometry.size.width / 2, y: 0)
                            .offset(y: 120)
                            
                            // Bottom spacer for scroll content
                            Color.clear
                                .frame(height: 400)
                        }
                        .background(
                            GeometryReader { scrollGeometry in
                                Color.clear
                                    .onChange(of: scrollGeometry.frame(in: .global).minY) { _, newValue in
                                        // Only track upward scrolling (positive offset)
                                        let offset = max(0, -newValue)
                                        scrollOffset = offset
                                    }
                            }
                        )
                    }
                }
            }
            .onAppear {
                startAnimation()
            }
            .sheet(isPresented: $showingCreateLeague) {
                CreateLeagueView()
            }
            .sheet(isPresented: $showingLoadLeague) {
                LoadLeagueView()
            }
            .fullScreenCover(item: $activeLeague) { activeLeague in
                FadeInPresenting(style: .soft) {
                    if let league = activeLeague.league {
                        LeagueHubView(league: league)
                    } else {
                        LeagueHubView(
                            teamName: activeLeague.teamName,
                            teamLogoName: activeLeague.logoName,
                            customLogoData: activeLeague.customLogoData
                        )
                    }
                }
            }
            .onChange(of: coreLeagueManager.shouldDismissToHub) { _, shouldDismiss in
                if shouldDismiss {
                    guard activeLeague == nil else { return }
                    activeLeague = coreLeagueManager.pendingLeague
                    DispatchQueue.main.async {
                        showingCreateLeague = false
                        showingLoadLeague = false
                        coreLeagueManager.reset()
                    }
                }
            }
            .onChange(of: coreLeagueManager.pendingLeague) { _, newLeague in
                // Handle league loading from LoadLeagueView
                if newLeague != nil && !coreLeagueManager.shouldDismissToHub {
                    // Present first for seamless transition, then dismiss the load sheet beneath.
                    guard activeLeague == nil else { return }
                    activeLeague = newLeague
                    DispatchQueue.main.async {
                        showingLoadLeague = false
                        coreLeagueManager.reset()
                    }
                }
            }
        }
    }

    private func logoWidth(geometry: GeometryProxy) -> CGFloat {
        let width = geometry.size.width - 40
        return max(200, min(width, 500)) // Ensure minimum width of 200 and maximum of 500
    }
    
    private func logoSize(scrollOffset: CGFloat, screenWidth: CGFloat) -> CGFloat {
        let baseSize: CGFloat = min(screenWidth - 40, 500)
        let minSize: CGFloat = 100
        
        // Only shrink based on upward scroll
        let scrollFactor: CGFloat = min(scrollOffset / 200, 1)
        let currentSize = baseSize - (baseSize - minSize) * scrollFactor
        
        return max(minSize, currentSize)
    }
    
    private func logoDisplayOpacity(scrollOffset: CGFloat, baseOpacity: Double) -> Double {
        let scrollFactor: Double = min(Double(scrollOffset) / 250, 1)
        let currentOpacity = baseOpacity * (1 - scrollFactor * 0.7)
        
        return max(0.2, currentOpacity)
    }
    
    private func logoYPosition(scrollOffset: CGFloat, screenHeight: CGFloat) -> CGFloat {
        let centerY: CGFloat = screenHeight / 2
        let finalY: CGFloat = centerY + logoOffset
        
        // Minimal position adjustment - only move up slightly
        let scrollAdjustment: CGFloat = scrollOffset * 0.1
        
        return finalY - scrollAdjustment
    }
    
    private func startAnimation() {
        // Step 1: Fade in logo at exact center
        withAnimation(.easeIn(duration: 1.5)) {
            logoOpacity = 1.0
        }
        
        // Step 2: Move logo up from center to final position
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 1.5)) {
                logoOffset = -200
            }
            
            // Step 3: Mark animation as complete and fade in buttons
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                animationComplete = true
                
                // Fade in buttons from bottom to top
                withAnimation(.easeOut(duration: 0.8)) {
                    settingsOpacity = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.8)) {
                        loadLeagueOpacity = 1.0
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeOut(duration: 0.8)) {
                        createLeagueOpacity = 1.0
                    }
                }
            }
        }
    }
}

#Preview {
    MainMenuView()
}
