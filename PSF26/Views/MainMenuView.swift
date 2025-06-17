import SwiftUI

struct MainMenuView: View {
    @State private var logoOpacity = 0.0
    @State private var logoOffset: CGFloat = 0
    @State private var settingsOpacity = 0.0
    @State private var loadLeagueOpacity = 0.0
    @State private var createLeagueOpacity = 0.0
    @State private var animationComplete = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Image("gradient-background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                
                ZStack {
                    // Logo - absolutely positioned in center, then moves up
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(geometry.size.width - 60, 400), 
                               height: min(geometry.size.width - 60, 400))
                        .opacity(logoOpacity)
                        .position(
                            x: geometry.size.width / 2,
                            y: (geometry.size.height / 2) + logoOffset
                        )
                    
                    // Buttons - only show after animation
                    if animationComplete {
                        VStack(spacing: 16) {
                            // Create New League Button
                            Button(action: {
                                // Action for create new league
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.white)
                                    
                                    Text("Create New League")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                            }
                            .glassEffect(.regular.interactive())
                            .opacity(createLeagueOpacity)
                            
                            // Load League Button
                            Button(action: {
                                // Action for load league
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.white)
                                    
                                    Text("Load League")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                            }
                            .glassEffect(.regular.interactive())
                            .opacity(loadLeagueOpacity)
                            
                            // Settings Button
                            Button(action: {
                                // Action for settings
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.white)
                                    
                                    Text("Settings")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                            }
                            .glassEffect(.regular.interactive())
                            .opacity(settingsOpacity)
                        }
                        .padding(.horizontal, 40)
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height - geometry.safeAreaInsets.bottom - 180
                        )
                    }
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Step 1: Fade in logo at exact center
        withAnimation(.easeIn(duration: 1.5)) {
            logoOpacity = 1.0
        }
        
        // Step 2: Move logo up from center to final position
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 1.5)) {
                logoOffset = -200 // Move up from center
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
