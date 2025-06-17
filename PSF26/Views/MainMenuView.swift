import SwiftUI

struct MainMenuView: View {
    @State private var logoOpacity = 0.0
    @State private var logoY: CGFloat = 0
    @State private var button1Opacity = 0.0
    @State private var button2Opacity = 0.0
    @State private var button3Opacity = 0.0
    @State private var button1Y: CGFloat = 0
    @State private var button2Y: CGFloat = 0
    @State private var button3Y: CGFloat = 0
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            // Gradient background - full screen
            Image("gradient-background", bundle: .main)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            // Logo - centered and full size
            GeometryReader { geometry in
                let margin: CGFloat = 40
                let logoSize = min(geometry.size.width - (margin * 2), geometry.size.height - (margin * 2))
                
                let centerY = geometry.size.height / 2
                let topY = geometry.safeAreaInsets.top + logoSize/2 - 70
                
                // Button positioning calculations - moved up for scope access
                let buttonSpacing: CGFloat = 20
                let buttonWidth: CGFloat = min(geometry.size.width * 0.8, 300)
                let buttonHeight: CGFloat = 50
                
                let logoFinalBottom = topY + logoSize/2
                let finalButton1Y = logoFinalBottom + 40
                let finalButton2Y = finalButton1Y + buttonHeight + buttonSpacing
                let finalButton3Y = finalButton2Y + buttonHeight + buttonSpacing
                
                Image("AppLogo", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoSize, height: logoSize)
                    .opacity(logoOpacity)
                    .position(x: geometry.size.width / 2, y: logoY == 0 ? centerY : logoY)
                    .onAppear {
                        // First: fade in at center
                        withAnimation(.easeIn(duration: 1.5)) {
                            logoOpacity = 1.0
                        }
                        
                        // Second: after fade-in, move to top
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeInOut(duration: 2.0)) {
                                logoY = topY
                            }
                            
                            // Buttons slide up and fade in from bottom to top as logo moves up
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    button3Opacity = 1.0
                                    button3Y = finalButton3Y
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    button2Opacity = 1.0
                                    button2Y = finalButton2Y
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    button1Opacity = 1.0
                                    button1Y = finalButton1Y
                                }
                            }
                        }
                    }
                
                // Set initial positions off-screen if not yet animated
                let currentButton1Y = button1Y == 0 ? geometry.size.height + 100 : button1Y
                let currentButton2Y = button2Y == 0 ? geometry.size.height + 100 : button2Y
                let currentButton3Y = button3Y == 0 ? geometry.size.height + 100 : button3Y
                
                // iOS 26 Liquid Glass Button Container for performance and morphing
                GlassEffectContainer(spacing: 20.0) {
                    // Button 1 - Primary Action with tint
                    Button {
                        // Action
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .symbolEffect(.bounce, value: button1Opacity)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                            Text("New League")
                                .font(.title3.weight(.semibold))
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        }
                        .foregroundColor(.white)
                        .frame(width: buttonWidth, height: buttonHeight)
                    }
                    .glassEffect(.regular.tint(.blue.opacity(0.3)).interactive())
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .hoverEffect(.lift)
                    .sensoryFeedback(.selection, trigger: button1Opacity)
                    .opacity(button1Opacity)
                    .position(x: geometry.size.width / 2, y: currentButton1Y)
                    
                    // Button 2 - Secondary Action
                    Button {
                        // Action
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "tray.and.arrow.down.fill")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .symbolEffect(.bounce, value: button2Opacity)
                            Text("Load Save")
                                .font(.title3.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(width: buttonWidth, height: buttonHeight)
                    }
                    .glassEffect(.regular.interactive())
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .hoverEffect(.lift)
                    .sensoryFeedback(.selection, trigger: button2Opacity)
                    .opacity(button2Opacity)
                    .position(x: geometry.size.width / 2, y: currentButton2Y)
                    
                    // Button 3 - Tertiary Action
                    Button {
                        showingSettings = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .symbolEffect(.bounce, value: button3Opacity)
                            Text("Settings")
                                .font(.title3.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(width: buttonWidth, height: buttonHeight)
                    }
                    .glassEffect(.regular.interactive())
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .hoverEffect(.lift)
                    .sensoryFeedback(.selection, trigger: button3Opacity)
                    .opacity(button3Opacity)
                    .position(x: geometry.size.width / 2, y: currentButton3Y)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    MainMenuView()
} 
