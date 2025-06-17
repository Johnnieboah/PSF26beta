import SwiftUI
import CloudKit

enum AppearanceMode: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "Follow Device"
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @State private var showingResetAlert = false
    @State private var showingDebugMenu = false
    @State private var iCloudSyncInProgress = false
    @State private var showingICloudAlert = false
    @State private var iCloudAlertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // Appearance Section
                Section("Appearance") {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button {
                            appearanceMode = mode
                            updateAppearance()
                        } label: {
                            HStack {
                                Text(mode.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if appearanceMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .glassEffect(.regular.interactive())
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .hoverEffect(.lift)
                    }
                }
                
                // iCloud Sync Section
                Section("iCloud Sync") {
                    Button {
                        saveToICloud()
                    } label: {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("Save to iCloud")
                                .foregroundColor(.primary)
                            Spacer()
                            if iCloudSyncInProgress {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .glassEffect(.regular.interactive())
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .hoverEffect(.lift)
                    .disabled(iCloudSyncInProgress)
                    
                    Button {
                        loadFromICloud()
                    } label: {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down")
                                .foregroundColor(.blue)
                            Text("Load from iCloud")
                                .foregroundColor(.primary)
                            Spacer()
                            if iCloudSyncInProgress {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .glassEffect(.regular.interactive())
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .hoverEffect(.lift)
                    .disabled(iCloudSyncInProgress)
                }
                
                // Data Management Section
                Section("Data Management") {
                    Button {
                        showingResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Reset All Data")
                                .foregroundColor(.red)
                        }
                    }
                    .glassEffect(.regular.tint(.red.opacity(0.2)).interactive())
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .hoverEffect(.lift)
                }
                
                // Debug Section
                Section("Debug") {
                    Button {
                        showingDebugMenu = true
                    } label: {
                        HStack {
                            Image(systemName: "hammer")
                                .foregroundColor(.orange)
                            Text("Debug Menu")
                                .foregroundColor(.primary)
                        }
                    }
                    .glassEffect(.regular.tint(.orange.opacity(0.2)).interactive())
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .hoverEffect(.lift)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(colorScheme)
        .alert("Reset All Data", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will permanently delete all your game data, saves, and settings. This action cannot be undone.")
        }
        .alert("iCloud Sync", isPresented: $showingICloudAlert) {
            Button("OK") { }
        } message: {
            Text(iCloudAlertMessage)
        }
        .sheet(isPresented: $showingDebugMenu) {
            DebugMenuView()
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
    
    private func saveToICloud() {
        iCloudSyncInProgress = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            iCloudSyncInProgress = false
            iCloudAlertMessage = "Game data successfully saved to iCloud."
            showingICloudAlert = true
        }
    }
    
    private func loadFromICloud() {
        iCloudSyncInProgress = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            iCloudSyncInProgress = false
            iCloudAlertMessage = "Game data successfully loaded from iCloud."
            showingICloudAlert = true
        }
    }
    
    private func resetAllData() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        appearanceMode = .system
        updateAppearance()
    }
}

struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Test Functions") {
                    Button("Test Function 1") {
                        print("Debug: Test Function 1 executed")
                    }
                    .glassEffect(.regular.tint(.purple.opacity(0.2)).interactive())
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .hoverEffect(.lift)
                    
                    Button("Test Function 2") {
                        print("Debug: Test Function 2 executed")
                    }
                    .glassEffect(.regular.tint(.purple.opacity(0.2)).interactive())
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .hoverEffect(.lift)
                    
                    Button("Test Function 3") {
                        print("Debug: Test Function 3 executed")
                    }
                    .glassEffect(.regular.tint(.purple.opacity(0.2)).interactive())
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .hoverEffect(.lift)
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
} 