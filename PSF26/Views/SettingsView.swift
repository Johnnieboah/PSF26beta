import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("enableSoundEffects") private var enableSoundEffects = true
    @AppStorage("enableGameCenterSync") private var enableGameCenterSync = true
    @AppStorage("enableiCloudSync") private var enableiCloudSync = true
    @State private var showingResetAlert = false
    @State private var showingAboutView = false
    
    var body: some View {
        NavigationStack {
            List {
                // Appearance Section
                Section {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        HStack(spacing: 16) {
                            Image(systemName: mode.systemImage)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.primary)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.displayName)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if appearanceMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appearanceMode = mode
                            updateAppearance()
                        }
                    }
                } header: {
                    Text("Appearance")
                        .font(.headline)
                        .foregroundStyle(.primary)
                } footer: {
                    Text("Choose how PSF26 appears on your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Game Settings Section
                Section {
                    // Haptic Feedback Toggle
                    Toggle(isOn: $enableHapticFeedback) {
                        HStack(spacing: 16) {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Haptic Feedback")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                Text("Feel vibrations during gameplay")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Sound Effects Toggle
                    Toggle(isOn: $enableSoundEffects) {
                        HStack(spacing: 16) {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sound Effects")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                Text("Play sounds during interactions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                } header: {
                    Text("Game Experience")
                        .font(.headline)
                        .foregroundStyle(.primary)
                } footer: {
                    Text("Customize how you experience PSF26 gameplay.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Sync & Storage Section
                Section {
                    // Game Center Sync Toggle
                    Toggle(isOn: $enableGameCenterSync) {
                        HStack(spacing: 16) {
                            Image(systemName: "gamecontroller")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.green)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Game Center Sync")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                Text("Sync achievements and leaderboards")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // iCloud Sync Toggle  
                    Toggle(isOn: $enableiCloudSync) {
                        HStack(spacing: 16) {
                            Image(systemName: "icloud")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("iCloud Sync")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                Text("Keep leagues synced across devices")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                } header: {
                    Text("Sync & Storage")
                        .font(.headline)
                        .foregroundStyle(.primary)
                } footer: {
                    Text("Your data stays private and secure with Apple's encryption.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // About & Support Section
                Section {
                    // About Button
                    NavigationLink {
                        AboutView()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("About PSF26")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                Text("Version, credits, and information")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Reset Data Button
                    Button {
                        showingResetAlert = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.red)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset All Data")
                                    .font(.body)
                                    .foregroundStyle(.red)
                                
                                Text("Permanently delete all leagues and settings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    
                } header: {
                    Text("About & Support")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(colorScheme)
        .alert("Reset All Data", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will permanently delete all your leagues, saves, and settings. This action cannot be undone.")
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
    
    private func updateAppearance() {
        // Apply appearance changes safely
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = {
                        switch appearanceMode {
                        case .light: return .light
                        case .dark: return .dark
                        case .system: return .unspecified
                        }
                    }()
                }
            }
        }
    }
    
    private func resetAllData() {
        // Reset UserDefaults safely
        DispatchQueue.main.async {
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
                UserDefaults.standard.synchronize()
            }
            
            // Reset appearance to system default
            appearanceMode = .system
            updateAppearance()
        }
    }
}

// MARK: - Appearance Mode Enum
enum AppearanceMode: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "Automatic"
        }
    }
    
    var description: String {
        switch self {
        case .light: return "Always use light appearance"
        case .dark: return "Always use dark appearance"
        case .system: return "Match system setting"
        }
    }
    
    var systemImage: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 20) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                    
                    VStack(spacing: 8) {
                        Text("PSF26")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary)
                        
                        Text("Pure Sim Football XXVI")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .listRowBackground(Color.clear)
            
            Section {
                InfoRow(icon: "person.crop.circle", title: "Developer", value: "Your Studio Name")
                InfoRow(icon: "calendar", title: "Release Year", value: "2025")
                InfoRow(icon: "gamecontroller", title: "Category", value: "Sports Simulation")
                InfoRow(icon: "star", title: "Built for", value: "iOS 26+")
            } header: {
                Text("Information")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            Section {
                Link(destination: URL(string: "https://developer.apple.com/support/")!) {
                    InfoRow(icon: "questionmark.circle", title: "Support", value: "Get Help", showChevron: true)
                }
                
                Link(destination: URL(string: "https://www.apple.com/legal/privacy/")!) {
                    InfoRow(icon: "hand.raised", title: "Privacy Policy", value: "Learn More", showChevron: true)
                }
                
            } header: {
                Text("Support")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let showChevron: Bool
    
    init(icon: String, title: String, value: String, showChevron: Bool = false) {
        self.icon = icon
        self.title = title
        self.value = value
        self.showChevron = showChevron
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
}
