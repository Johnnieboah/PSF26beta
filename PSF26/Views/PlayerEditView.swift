import SwiftUI

// MARK: - Enhanced Player Edit View with Individual Attributes
struct PlayerEditView: View {
    @State private var editedPlayer: EditablePlayerData
    @State private var isSaving = false
    @State private var showingDiscardAlert = false
    @State private var errorMessage: String?
    
    let teamLogoName: String
    let leagueId: UUID
    let onPlayerUpdated: (EditablePlayerData) -> Void
    
    init(player: EditablePlayerData, teamLogoName: String, leagueId: UUID, onPlayerUpdated: @escaping (EditablePlayerData) -> Void) {
        self._editedPlayer = State(initialValue: player)
        self.teamLogoName = teamLogoName
        self.leagueId = leagueId
        self.onPlayerUpdated = onPlayerUpdated
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Information Section
                Section("Basic Information") {
                    HStack {
                        Text("First Name")
                        Spacer()
                        TextField("First Name", text: $editedPlayer.firstName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Last Name")
                        Spacer()
                        TextField("Last Name", text: $editedPlayer.lastName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Position")
                        Spacer()
                        Picker("Position", selection: $editedPlayer.position) {
                            ForEach(availablePositions, id: \.self) { position in
                                Text(position).tag(position)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    HStack {
                        Text("Jersey Number")
                        Spacer()
                        TextField("Number", value: $editedPlayer.number, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                }
                
                // Overall Rating Section (Calculated)
                Section("Overall Rating") {
                    HStack {
                        Text("Overall")
                            .font(.headline)
                        Spacer()
                        Text("\(editedPlayer.overall)")
                            .font(.headline)
                            .foregroundColor(getOverallColor(editedPlayer.overall))
                    }
                }
                
                // Physical Attributes Section
                Section("Physical Attributes") {
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("Age", value: $editedPlayer.age, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("Height", text: $editedPlayer.height)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Weight", text: $editedPlayer.weight)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // Core Physical Attributes
                    AttributeRow(title: "Speed", value: $editedPlayer.speed)
                    AttributeRow(title: "Agility", value: $editedPlayer.agility)
                    AttributeRow(title: "Strength", value: $editedPlayer.strength)
                    AttributeRow(title: "Stamina", value: $editedPlayer.stamina)
                    AttributeRow(title: "Injury", value: $editedPlayer.injury)
                    AttributeRow(title: "Acceleration", value: $editedPlayer.acceleration)
                    AttributeRow(title: "Jumping", value: $editedPlayer.jumping)
                    AttributeRow(title: "Toughness", value: $editedPlayer.toughness)
                }
                
                // Position-Specific Attributes Section
                Section(getPositionSpecificSectionTitle()) {
                    ForEach(getPositionSpecificAttributes(), id: \.title) { attribute in
                        AttributeRow(title: attribute.title, value: attribute.binding)
                    }
                }
                
                // Additional Attributes Section (Optional)
                Section("Additional Attributes") {
                    ForEach(getAllRemainingAttributes(), id: \.title) { attribute in
                        AttributeRow(title: attribute.title, value: attribute.binding)
                    }
                }
                
                // Background Section
                Section("Background") {
                    HStack {
                        Text("College")
                        Spacer()
                        TextField("College", text: $editedPlayer.college)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Years Pro")
                        Spacer()
                        TextField("Years", value: $editedPlayer.yearsPro, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                }
                
                // Metadata Section
                if editedPlayer.isEdited {
                    Section("Edit History") {
                        HStack {
                            Text("Last Modified")
                            Spacer()
                            Text(formatDate(editedPlayer.lastModified))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Status")
                            Spacer()
                            Label("Edited", systemImage: "pencil.circle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Edit Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onPlayerUpdated(editedPlayer)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await savePlayer()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Saving Player...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(16)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getPositionSpecificSectionTitle() -> String {
        switch editedPlayer.position {
        case "QB": return "Quarterback Attributes"
        case "RB", "FB": return "Running Back Attributes"
        case "WR": return "Wide Receiver Attributes"
        case "TE": return "Tight End Attributes"
        case "LT", "LG", "C", "RG", "RT": return "Offensive Line Attributes"
        case "DE", "DT": return "Defensive Line Attributes"
        case "MLB", "ROLB", "LOLB": return "Linebacker Attributes"
        case "CB": return "Cornerback Attributes"
        case "SS", "FS": return "Safety Attributes"
        case "K": return "Kicker Attributes"
        case "P": return "Punter Attributes"
        default: return "Position Attributes"
        }
    }
    
    private func getPositionSpecificAttributes() -> [AttributeBinding] {
        var attributes: [AttributeBinding] = []
        
        // Add awareness and play recognition first (universal)
        attributes.append(AttributeBinding(title: "Awareness", binding: $editedPlayer.awareness))
        attributes.append(AttributeBinding(title: "Play Recognition", binding: $editedPlayer.playRecognition))
        
        switch editedPlayer.position {
        case "QB":
            attributes.append(contentsOf: [
                AttributeBinding(title: "Throw Power", binding: $editedPlayer.throwPower),
                AttributeBinding(title: "Throw Accuracy Short", binding: $editedPlayer.throwAccuracyShort),
                AttributeBinding(title: "Throw Accuracy Mid", binding: $editedPlayer.throwAccuracyMid),
                AttributeBinding(title: "Throw Accuracy Deep", binding: $editedPlayer.throwAccuracyDeep),
                AttributeBinding(title: "Throw on the Run", binding: $editedPlayer.throwOnTheRun),
                AttributeBinding(title: "Throw Under Pressure", binding: $editedPlayer.throwUnderPressure),
                AttributeBinding(title: "Play Action", binding: $editedPlayer.playAction)
            ])
            
        case "RB", "FB":
            attributes.append(contentsOf: [
                AttributeBinding(title: "Carrying", binding: $editedPlayer.carrying),
                AttributeBinding(title: "Trucking", binding: $editedPlayer.trucking),
                AttributeBinding(title: "Break Tackle", binding: $editedPlayer.breakTackle),
                AttributeBinding(title: "Juke Move", binding: $editedPlayer.jukeMove),
                AttributeBinding(title: "Spin Move", binding: $editedPlayer.spinMove),
                AttributeBinding(title: "Stiff Arm", binding: $editedPlayer.stiffArm),
                AttributeBinding(title: "BC Vision", binding: $editedPlayer.bCVision),
                AttributeBinding(title: "Change of Direction", binding: $editedPlayer.changeOfDirection),
                AttributeBinding(title: "Catching", binding: $editedPlayer.catching)
            ])
            
        case "WR":
            attributes.append(contentsOf: [
                AttributeBinding(title: "Catching", binding: $editedPlayer.catching),
                AttributeBinding(title: "Catch in Traffic", binding: $editedPlayer.catchInTraffic),
                AttributeBinding(title: "Spectacular Catch", binding: $editedPlayer.spectacularCatch),
                AttributeBinding(title: "Release", binding: $editedPlayer.release),
                AttributeBinding(title: "Short Route Running", binding: $editedPlayer.shortRouteRunning),
                AttributeBinding(title: "Medium Route Running", binding: $editedPlayer.mediumRouteRunning),
                AttributeBinding(title: "Deep Route Running", binding: $editedPlayer.deepRouteRunning),
                AttributeBinding(title: "Change of Direction", binding: $editedPlayer.changeOfDirection)
            ])
            
        case "TE":
            attributes.append(contentsOf: [
                AttributeBinding(title: "Catching", binding: $editedPlayer.catching),
                AttributeBinding(title: "Catch in Traffic", binding: $editedPlayer.catchInTraffic),
                AttributeBinding(title: "Release", binding: $editedPlayer.release),
                AttributeBinding(title: "Short Route Running", binding: $editedPlayer.shortRouteRunning),
                AttributeBinding(title: "Medium Route Running", binding: $editedPlayer.mediumRouteRunning),
                AttributeBinding(title: "Pass Block", binding: $editedPlayer.passBlock),
                AttributeBinding(title: "Run Block", binding: $editedPlayer.runBlock),
                AttributeBinding(title: "Impact Blocking", binding: $editedPlayer.impactBlocking)
            ])
            
        case "LT", "LG", "C", "RG", "RT":
            attributes.append(contentsOf: [
                AttributeBinding(title: "Pass Block", binding: $editedPlayer.passBlock),
                AttributeBinding(title: "Run Block", binding: $editedPlayer.runBlock),
                AttributeBinding(title: "Impact Blocking", binding: $editedPlayer.impactBlocking),
                AttributeBinding(title: "Pass Block Power", binding: $editedPlayer.passBlockPower),
                AttributeBinding(title: "Run Block Power", binding: $editedPlayer.runBlockPower),
                AttributeBinding(title: "Pass Block Finesse", binding: $editedPlayer.passBlockFinesse),
                AttributeBinding(title: "Run Block Finesse", binding: $editedPlayer.runBlockFinesse)
            ])
            
        case "DE", "DT":
            attributes.append(contentsOf: [
                AttributeBinding(title: "Block Shedding", binding: $editedPlayer.blockShedding),
                AttributeBinding(title: "Power Moves", binding: $editedPlayer.powerMoves),
                AttributeBinding(title: "Finesse Moves", binding: $editedPlayer.finesseMoves),
                AttributeBinding(title: "Tackle", binding: $editedPlayer.tackle),
                AttributeBinding(title: "Pursuit", binding: $editedPlayer.pursuit),
                AttributeBinding(title: "Hit Power", binding: $editedPlayer.hitPower)
            ])
            
        case "MLB", "ROLB", "LOLB":
            attributes.append(contentsOf: [
                AttributeBinding(title: "Tackle", binding: $editedPlayer.tackle),
                AttributeBinding(title: "Block Shedding", binding: $editedPlayer.blockShedding),
                AttributeBinding(title: "Zone Coverage", binding: $editedPlayer.zoneCoverage),
                AttributeBinding(title: "Man Coverage", binding: $editedPlayer.manCoverage),
                AttributeBinding(title: "Pursuit", binding: $editedPlayer.pursuit),
                AttributeBinding(title: "Hit Power", binding: $editedPlayer.hitPower)
            ])
            
        case "CB":
            attributes.append(contentsOf: [
                AttributeBinding(title: "Man Coverage", binding: $editedPlayer.manCoverage),
                AttributeBinding(title: "Zone Coverage", binding: $editedPlayer.zoneCoverage),
                AttributeBinding(title: "Press", binding: $editedPlayer.press),
                AttributeBinding(title: "Pursuit", binding: $editedPlayer.pursuit),
                AttributeBinding(title: "Change of Direction", binding: $editedPlayer.changeOfDirection)
            ])
            
        case "SS", "FS":
            attributes.append(contentsOf: [
                AttributeBinding(title: "Zone Coverage", binding: $editedPlayer.zoneCoverage),
                AttributeBinding(title: "Man Coverage", binding: $editedPlayer.manCoverage),
                AttributeBinding(title: "Tackle", binding: $editedPlayer.tackle),
                AttributeBinding(title: "Hit Power", binding: $editedPlayer.hitPower),
                AttributeBinding(title: "Pursuit", binding: $editedPlayer.pursuit)
            ])
            
        case "K":
            attributes.append(contentsOf: [
                AttributeBinding(title: "Kick Power", binding: $editedPlayer.kickPower),
                AttributeBinding(title: "Kick Accuracy", binding: $editedPlayer.kickAccuracy)
            ])
            
        case "P":
            attributes.append(contentsOf: [
                AttributeBinding(title: "Kick Power", binding: $editedPlayer.kickPower),
                AttributeBinding(title: "Kick Accuracy", binding: $editedPlayer.kickAccuracy)
            ])
            
        default:
            // For unknown positions, show some general attributes
            attributes.append(contentsOf: [
                AttributeBinding(title: "Tackle", binding: $editedPlayer.tackle),
                AttributeBinding(title: "Catching", binding: $editedPlayer.catching)
            ])
        }
        
        return attributes
    }
    
    private func getAllRemainingAttributes() -> [AttributeBinding] {
        let positionSpecificTitles = Set(getPositionSpecificAttributes().map { $0.title })
        let alreadyShownTitles = Set(["Speed", "Agility", "Strength", "Stamina", "Injury", "Acceleration", "Jumping", "Toughness"])
        let excludedTitles = positionSpecificTitles.union(alreadyShownTitles)
        
        let allAttributes = [
            AttributeBinding(title: "Carrying", binding: $editedPlayer.carrying),
            AttributeBinding(title: "Trucking", binding: $editedPlayer.trucking),
            AttributeBinding(title: "Catching", binding: $editedPlayer.catching),
            AttributeBinding(title: "Break Tackle", binding: $editedPlayer.breakTackle),
            AttributeBinding(title: "Juke Move", binding: $editedPlayer.jukeMove),
            AttributeBinding(title: "Spin Move", binding: $editedPlayer.spinMove),
            AttributeBinding(title: "Stiff Arm", binding: $editedPlayer.stiffArm),
            AttributeBinding(title: "Change of Direction", binding: $editedPlayer.changeOfDirection),
            AttributeBinding(title: "Throw Power", binding: $editedPlayer.throwPower),
            AttributeBinding(title: "Throw Accuracy Short", binding: $editedPlayer.throwAccuracyShort),
            AttributeBinding(title: "Throw Accuracy Mid", binding: $editedPlayer.throwAccuracyMid),
            AttributeBinding(title: "Throw Accuracy Deep", binding: $editedPlayer.throwAccuracyDeep),
            AttributeBinding(title: "Throw on the Run", binding: $editedPlayer.throwOnTheRun),
            AttributeBinding(title: "Throw Under Pressure", binding: $editedPlayer.throwUnderPressure),
            AttributeBinding(title: "Play Action", binding: $editedPlayer.playAction),
            AttributeBinding(title: "Tackle", binding: $editedPlayer.tackle),
            AttributeBinding(title: "Block Shedding", binding: $editedPlayer.blockShedding),
            AttributeBinding(title: "Zone Coverage", binding: $editedPlayer.zoneCoverage),
            AttributeBinding(title: "Man Coverage", binding: $editedPlayer.manCoverage),
            AttributeBinding(title: "Pursuit", binding: $editedPlayer.pursuit),
            AttributeBinding(title: "Finesse Moves", binding: $editedPlayer.finesseMoves),
            AttributeBinding(title: "Power Moves", binding: $editedPlayer.powerMoves),
            AttributeBinding(title: "Press", binding: $editedPlayer.press),
            AttributeBinding(title: "Hit Power", binding: $editedPlayer.hitPower),
            AttributeBinding(title: "Pass Block", binding: $editedPlayer.passBlock),
            AttributeBinding(title: "Run Block", binding: $editedPlayer.runBlock),
            AttributeBinding(title: "Impact Blocking", binding: $editedPlayer.impactBlocking),
            AttributeBinding(title: "Pass Block Power", binding: $editedPlayer.passBlockPower),
            AttributeBinding(title: "Run Block Power", binding: $editedPlayer.runBlockPower),
            AttributeBinding(title: "Pass Block Finesse", binding: $editedPlayer.passBlockFinesse),
            AttributeBinding(title: "Run Block Finesse", binding: $editedPlayer.runBlockFinesse),
            AttributeBinding(title: "Release", binding: $editedPlayer.release),
            AttributeBinding(title: "Catch in Traffic", binding: $editedPlayer.catchInTraffic),
            AttributeBinding(title: "Spectacular Catch", binding: $editedPlayer.spectacularCatch),
            AttributeBinding(title: "Short Route Running", binding: $editedPlayer.shortRouteRunning),
            AttributeBinding(title: "Medium Route Running", binding: $editedPlayer.mediumRouteRunning),
            AttributeBinding(title: "Deep Route Running", binding: $editedPlayer.deepRouteRunning),
            AttributeBinding(title: "Kick Power", binding: $editedPlayer.kickPower),
            AttributeBinding(title: "Kick Accuracy", binding: $editedPlayer.kickAccuracy),
            AttributeBinding(title: "BC Vision", binding: $editedPlayer.bCVision),
            AttributeBinding(title: "Play Recognition", binding: $editedPlayer.playRecognition),
            AttributeBinding(title: "Awareness", binding: $editedPlayer.awareness)
        ]
        
        return allAttributes.filter { !excludedTitles.contains($0.title) }
    }
    
    private func savePlayer() async {
        isSaving = true
        
        do {
            try await PlayerDataManager.shared.updateEntirePlayer(editedPlayer)
            
            await MainActor.run {
                // Update the edited player object to reflect the save
                editedPlayer.isEdited = true
                editedPlayer.lastModified = Date()
                
                print("💾 PlayerEditView: Player saved successfully, notifying parent")
                
                // Notify parent view
                onPlayerUpdated(editedPlayer)
                print("💾 PlayerEditView: Parent notified of player update")
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = "Failed to save changes: \(error.localizedDescription)"
            }
        }
    }
    
    private func getOverallColor(_ overall: Int) -> Color {
        switch overall {
        case 90...99: return .purple
        case 80...89: return .blue
        case 70...79: return .green
        case 60...69: return .yellow
        default: return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var availablePositions: [String] {
        [
            "QB", "RB", "FB", "WR", "TE",
            "LT", "LG", "C", "RG", "RT",
            "DE", "DT", "MLB", "ROLB", "LOLB",
            "CB", "SS", "FS", "K", "P"
        ]
    }
}

// MARK: - Supporting Views

struct AttributeRow: View {
    let title: String
    @Binding var value: Int
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            TextField("Value", value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .frame(width: 50)
        }
    }
}

struct AttributeBinding {
    let title: String
    let binding: Binding<Int>
}

// MARK: - Preview
#Preview {
    NavigationStack {
        PlayerEditView(
            player: EditablePlayerData(
                id: UUID(),
                firstName: "John",
                lastName: "Doe",
                position: "QB",
                number: 12,
                age: 25,
                college: "Sample University",
                height: "6'3\"",
                weight: "225 lbs",
                yearsPro: 3,
                teamLogoName: "team1",
                leagueId: UUID(),
                isEdited: false,
                lastModified: Date(),
                speed: 75, agility: 80, awareness: 90, strength: 70, stamina: 85, injury: 60,
                carrying: 65, trucking: 70, catching: 75, breakTackle: 80, jukeMove: 85, spinMove: 75,
                stiffArm: 70, acceleration: 80, changeOfDirection: 85,
                throwPower: 90, throwAccuracyShort: 85, throwAccuracyMid: 80, throwAccuracyDeep: 75,
                throwOnTheRun: 80, throwUnderPressure: 85, playAction: 90,
                tackle: 50, blockShedding: 50, zoneCoverage: 50, manCoverage: 50, pursuit: 50,
                finesseMoves: 50, powerMoves: 50, press: 50, jumping: 70, playRecognition: 85,
                hitPower: 50, toughness: 80,
                passBlock: 50, runBlock: 50, impactBlocking: 50, passBlockPower: 50, runBlockPower: 50,
                passBlockFinesse: 50, runBlockFinesse: 50,
                release: 50, catchInTraffic: 50, spectacularCatch: 50, shortRouteRunning: 50,
                mediumRouteRunning: 50, deepRouteRunning: 50,
                kickPower: 50, kickAccuracy: 50, bCVision: 50,
                // Salary cap properties (using default values)
                salary: 0,
                contract: nil,
                isRookiePlayer: false,
                draftPickNumber: nil,
                draftYearValue: nil,
                contractYearsLeft: 0,
                // Overall rating for preview
                overall: 82
            ),
            teamLogoName: "team1",
            leagueId: UUID()
        ) { _ in }
    }
} 