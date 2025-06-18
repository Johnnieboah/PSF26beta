import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var teamLogo: UIImage?
    @State private var showingImageError = false
    @State private var imageErrorMessage = ""
    
    // Team Settings
    @State private var primaryColor: Color = .blue
    @State private var secondaryColor: Color = .red
    @State private var thirdColor: Color = .white
    
    // Gameplay Settings
    @State private var difficulty: GameDifficulty = .pro
    @State private var autoSave: Bool = true
    @State private var salaryCapEnabled: Bool = true
    @State private var injuriesEnabled: Bool = true
    @State private var tradeDeadlineWeek: Int = 10
    @State private var autoSetDepthChart: Bool = true
    @State private var autoFillTeam: Bool = false
    @State private var acceleratedClock: Bool = false
    @State private var gameSpeed: GameSpeed = .normal
    
    enum GameDifficulty: String, CaseIterable {
        case rookie = "Rookie"
        case pro = "Pro"
        case allPro = "All-Pro"
        case allMadden = "All-Madden"
        
        var description: String {
            switch self {
            case .rookie: return "Easy gameplay, forgiving AI"
            case .pro: return "Balanced difficulty"
            case .allPro: return "Challenging gameplay"
            case .allMadden: return "Maximum difficulty"
            }
        }
    }
    
    enum GameSpeed: String, CaseIterable {
        case slow = "Slow"
        case normal = "Normal"
        case fast = "Fast"
        
        var description: String {
            switch self {
            case .slow: return "Detailed animations"
            case .normal: return "Standard pace"
            case .fast: return "Quick simulations"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Team Customization Section
                    teamCustomizationSection
                    
                    // Gameplay Settings Section
                    gameplaySettingsSection
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Image Error", isPresented: $showingImageError) {
            Button("OK") { }
        } message: {
            Text(imageErrorMessage)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadSelectedImage(from: newItem)
            }
        }
    }
    
    // MARK: - Team Customization Section
    private var teamCustomizationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "Team Customization",
                icon: "paintbrush.fill",
                color: .blue
            )
            
            VStack(spacing: 16) {
                // Team Logo Upload
                teamLogoSection
                
                // Team Colors
                teamColorsSection
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var teamLogoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Team Logo")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                // Current Logo Display
                Group {
                    if let teamLogo = teamLogo {
                        Image(uiImage: teamLogo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 80, height: 80)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.secondary.opacity(0.3), lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Label("Choose Image", systemImage: "photo.on.rectangle")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.blue, in: RoundedRectangle(cornerRadius: 8))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("• Max size: 512x512 pixels")
                        Text("• PNG format only")
                        Text("• Square aspect ratio recommended")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    private var teamColorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Team Colors")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                colorPickerRow(
                    title: "Primary Color",
                    description: "Main team color for uniforms and UI",
                    color: $primaryColor
                )
                
                colorPickerRow(
                    title: "Secondary Color",
                    description: "Accent color for details and highlights",
                    color: $secondaryColor
                )
                
                colorPickerRow(
                    title: "Third Color",
                    description: "Additional color for trim and text",
                    color: $thirdColor
                )
            }
            
            // Color Preview
            HStack(spacing: 12) {
                Text("Preview:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(primaryColor)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .fill(secondaryColor)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .fill(thirdColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Spacer()
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Gameplay Settings Section
    private var gameplaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "Gameplay Settings",
                icon: "gamecontroller.fill",
                color: .green
            )
            
            VStack(spacing: 16) {
                // Difficulty Settings
                difficultySection
                
                Divider()
                
                // Game Features
                gameFeaturesSection
                
                Divider()
                
                // League Settings
                leagueSettingsSection
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Game Difficulty")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(GameDifficulty.allCases, id: \.self) { level in
                    difficultyOption(level)
                }
            }
        }
    }
    
    private var gameFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Game Features")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                toggleSetting(
                    title: "Auto Save",
                    description: "Automatically save progress after each game",
                    isOn: $autoSave,
                    icon: "externaldrive.fill"
                )
                
                toggleSetting(
                    title: "Accelerated Clock",
                    description: "Faster game simulations and animations",
                    isOn: $acceleratedClock,
                    icon: "clock.arrow.circlepath"
                )
                
                pickerSetting(
                    title: "Game Speed",
                    description: "Controls simulation and animation speed",
                    selection: $gameSpeed,
                    options: GameSpeed.allCases,
                    icon: "speedometer"
                )
            }
        }
    }
    
    private var leagueSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Team Settings")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                toggleSetting(
                    title: "Auto Set Depth Chart",
                    description: "Automatically organize players by overall rating",
                    isOn: $autoSetDepthChart,
                    icon: "chart.bar.fill"
                )
                
                toggleSetting(
                    title: "Auto Fill Team",
                    description: "Automatically fill empty roster spots with free agents",
                    isOn: $autoFillTeam,
                    icon: "person.3.sequence.fill"
                )
                
                toggleSetting(
                    title: "Salary Cap",
                    description: "Enable salary cap restrictions for teams",
                    isOn: $salaryCapEnabled,
                    icon: "dollarsign.circle.fill"
                )
                
                toggleSetting(
                    title: "Player Injuries",
                    description: "Players can get injured during games",
                    isOn: $injuriesEnabled,
                    icon: "cross.case.fill"
                )
                
                stepperSetting(
                    title: "Trade Deadline",
                    description: "Week when trading ends",
                    value: $tradeDeadlineWeek,
                    range: 8...12,
                    suffix: "Week",
                    icon: "arrow.left.arrow.right.circle.fill"
                )
            }
        }
    }
    
    // MARK: - Helper Views
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private func colorPickerRow(title: String, description: String, color: Binding<Color>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ColorPicker("", selection: color)
                .frame(width: 40, height: 30)
        }
        .padding(.vertical, 4)
    }
    
    private func difficultyOption(_ level: GameDifficulty) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                difficulty = level
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: difficulty == level ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(difficulty == level ? .green : .secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(difficulty == level ? .green.opacity(0.1) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func toggleSetting(title: String, description: String, isOn: Binding<Bool>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .tint(.blue)
        }
        .padding(.vertical, 4)
    }
    
    private func stepperSetting<T: Strideable>(
        title: String,
        description: String,
        value: Binding<T>,
        range: ClosedRange<T>,
        suffix: String,
        icon: String
    ) -> some View where T.Stride: SignedInteger {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Stepper(
                "\(value.wrappedValue) \(suffix)",
                value: value,
                in: range
            )
            .labelsHidden()
            
            Text("\(value.wrappedValue) \(suffix)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
    
    private func pickerSetting<T: CaseIterable & Hashable & RawRepresentable>(
        title: String,
        description: String,
        selection: Binding<T>,
        options: T.AllCases,
        icon: String
    ) -> some View where T.RawValue == String {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                ForEach(Array(options), id: \.self) { option in
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if selection.wrappedValue == option {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selection.wrappedValue.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Image Processing
    private func loadSelectedImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    showImageError("Unable to load image data")
                }
                return
            }
            
            guard let image = UIImage(data: data) else {
                await MainActor.run {
                    showImageError("Invalid image format")
                }
                return
            }
            
            // Check if it's a PNG
            guard data.starts(with: [0x89, 0x50, 0x4E, 0x47]) else {
                await MainActor.run {
                    showImageError("Please select a PNG image")
                }
                return
            }
            
            // Check dimensions
            let maxSize: CGFloat = 512
            if image.size.width > maxSize || image.size.height > maxSize {
                await MainActor.run {
                    showImageError("Image must be 512x512 pixels or smaller")
                }
                return
            }
            
            // Process and resize image if needed
            let processedImage = await processImage(image)
            
            await MainActor.run {
                self.teamLogo = processedImage
            }
            
        } catch {
            await MainActor.run {
                showImageError("Error loading image: \(error.localizedDescription)")
            }
        }
    }
    
    private func processImage(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let targetSize = CGSize(width: 512, height: 512)
                
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                let processedImage = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: targetSize))
                }
                
                continuation.resume(returning: processedImage)
            }
        }
    }
    
    private func showImageError(_ message: String) {
        imageErrorMessage = message
        showingImageError = true
        selectedPhotoItem = nil
    }
    
    // MARK: - Settings Management
    private func saveSettings() {
        // TODO: Implement settings persistence
        print("Settings saved:")
        print("- Difficulty: \(difficulty.rawValue)")
        print("- Auto Save: \(autoSave)")
        print("- Auto Set Depth Chart: \(autoSetDepthChart)")
        print("- Auto Fill Team: \(autoFillTeam)")
        print("- Salary Cap: \(salaryCapEnabled)")
        print("- Injuries: \(injuriesEnabled)")
        print("- Trade Deadline: Week \(tradeDeadlineWeek)")
        print("- Team Colors: Primary \(primaryColor), Secondary \(secondaryColor), Third \(thirdColor)")
        
        if let teamLogo = teamLogo {
            print("- Custom team logo uploaded: \(teamLogo.size)")
        }
    }
}

#Preview {
    SettingsView()
}
