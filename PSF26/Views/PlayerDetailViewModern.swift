import SwiftUI

// MARK: - Refactored Player Detail View using extracted components
struct PlayerDetailView_Refactored: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var detailViewState = PlayerDetailViewStateManager.shared
    @State private var editablePlayer: EditablePlayerData?
    @State private var showingEditSheet = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentPlayer: PlayerData
    @State private var selectedMainTab: MainTab = .bio
    @State private var isUpdating = false
    @State private var showingContractNegotiation = false
    @State private var contractOffers: [ContractNegotiationManager.ContractOffer] = []
    @State private var negotiationResult: ContractNegotiationManager.NegotiationResult?
    @State private var negotiationAttempts = 0
    @State private var maxNegotiationAttempts = 3
    @State private var showingContractResultAlert = false
    @State private var contractResultTitle = ""
    @State private var contractResultMessage = ""
    @State private var showingPlayerReleaseOptions = false
    @State private var releaseOptions: [PlayerReleaseManager.ReleaseOption] = []
    @StateObject private var restructureManager = PlayerRestructureManager()
    @State private var contractData: PlayerContract?
    
    let teamLogoName: String
    let leagueId: UUID?
    let isEditable: Bool
    let leagueManager: LeagueManager?
    
    // Player ID for tracking
    private var playerId: String {
        "\(currentPlayer.firstName)_\(currentPlayer.lastName)_\(currentPlayer.number)"
    }
    
    enum MainTab: String, CaseIterable {
        case bio = "Bio"
        case stats = "Stats"
    }
    
    init(player: PlayerData, teamLogoName: String, leagueId: UUID? = nil, isEditable: Bool = true, leagueManager: LeagueManager? = nil) {
        self._currentPlayer = State(initialValue: player)
        self.teamLogoName = teamLogoName
        self.leagueId = leagueId
        self.isEditable = isEditable && leagueId != nil
        self.leagueManager = leagueManager
    }
    
    var body: some View {
        TabView(selection: $selectedMainTab) {
            // Bio Tab (Default) - Using extracted components
            bioTabContent
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Bio")
                }
                .tag(MainTab.bio)
            
            // Stats Tab
            statsTabContent
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Stats")
                }
                .tag(MainTab.stats)
        }
        .navigationTitle("\(currentPlayer.firstName) \(currentPlayer.lastName)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("📱 PlayerDetailView appeared for \(currentPlayer.firstName) \(currentPlayer.lastName)")
            detailViewState.setPlayerDetailOpen(teamLogoName: teamLogoName, playerId: playerId)
            
            // Load the editable player data if we have a league ID
            if let leagueId = leagueId {
                Task {
                    await loadEditablePlayerData(leagueId: leagueId)
                }
            }
        }
        .onDisappear {
            print("📱 PlayerDetailView disappeared for \(currentPlayer.firstName) \(currentPlayer.lastName)")
            detailViewState.setPlayerDetailClosed()
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                PlayerEditView(
                    player: editablePlayer!,
                    teamLogoName: teamLogoName,
                    leagueId: leagueId ?? UUID()
                ) { updatedPlayer in
                    print("🔄 PlayerDetailView: Received updated player data")
                    self.editablePlayer = updatedPlayer
                    self.currentPlayer = updatedPlayer.toPlayerData()
                    showingEditSheet = false
                }
            }
        }
        .sheet(isPresented: $showingContractNegotiation) {
            ContractNegotiationView(
                player: currentPlayer,
                teamLogoName: teamLogoName,
                offers: contractOffers,
                negotiationAttempts: 0,
                maxNegotiationAttempts: 3,
                onOfferSelected: handleContractOfferSelected
            )
        }
        .sheet(isPresented: $showingPlayerReleaseOptions) {
            PlayerReleaseOptionsView(
                player: currentPlayer,
                releaseOptions: releaseOptions,
                onReleaseSelected: { releaseType in
                    handlePlayerReleaseSelected(releaseType)
                }
            )
        }
        .alert(contractResultTitle, isPresented: $showingContractResultAlert) {
            Button("OK") {
                showingContractResultAlert = false
                
                // Refresh contract data after negotiation
                if let leagueId = leagueId {
                    Task {
                        await loadContractData(leagueId: leagueId)
                    }
                }
            }
        } message: {
            Text(contractResultMessage)
        }
    }
    
    // MARK: - Bio Tab Content using extracted components
    private var bioTabContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Player Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(currentPlayer.firstName) \(currentPlayer.lastName)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Text(currentPlayer.position)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    Text("Team: \(teamLogoName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Basic Info Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Basic Information")
                        .font(.headline)
                    HStack {
                        Text("Age: \(currentPlayer.age)")
                        Spacer()
                        Text("Overall: \(currentPlayer.overall)")
                    }
                    HStack {
                        Text("Height: \(currentPlayer.height)\"")
                        Spacer()
                        Text("Number: #\(currentPlayer.number)")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Salary & Contract Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contract Information")
                        .font(.headline)
                    Text("Salary: $\(currentPlayer.actualSalary ?? 0, specifier: "%.0f")")
                        .font(.subheadline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Contract Management Buttons
                if isEditable {
                    VStack(spacing: 12) {
                        Button("Negotiate Contract") {
                            handleContractNegotiation()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Release Player") {
                            handlePlayerRelease()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Edit Button
                if isEditable && editablePlayer != nil {
                    Button(action: {
                        showingEditSheet = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Player")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isUpdating)
                }
            }
            .padding()
        }
        .refreshable {
            if let leagueId = leagueId {
                await loadEditablePlayerData(leagueId: leagueId)
            }
        }
    }
    
    // MARK: - Stats Tab Content
    private var statsTabContent: some View {
        PlayerStatsMainView(
            player: currentPlayer,
            teamLogoName: teamLogoName,
            leagueId: leagueId,
            leagueManager: leagueManager,
            editablePlayer: editablePlayer
        )
    }
    
    // MARK: - Helper Methods
    private func loadEditablePlayerData(leagueId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let editablePlayers = try PlayerDataManager.shared.loadPlayersFromFile(
                leagueId: leagueId,
                teamLogoName: teamLogoName
            )
            
            await MainActor.run {
                // Find the editable player data
                if let foundEditablePlayer = editablePlayers.first(where: { editablePlayer in
                    editablePlayer.firstName == currentPlayer.firstName &&
                    editablePlayer.lastName == currentPlayer.lastName &&
                    editablePlayer.number == currentPlayer.number
                }) {
                    editablePlayer = foundEditablePlayer
                }
                self.isLoading = false
                
                // Also load contract data
                Task {
                    await loadContractData(leagueId: leagueId)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load player data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func loadContractData(leagueId: UUID) async {
        // Contract data loading disabled - ContractManager doesn't have shared instance
        print("Contract data loading not implemented")
    }
    
    private func createDefaultEditablePlayer() -> EditablePlayerData? {
        // EditablePlayerData only has Codable initializer, cannot create default
        return nil
    }
    
    // MARK: - Contract Management Actions
    private func handleContractNegotiation() {
        // Contract negotiation disabled - ContractNegotiationManager doesn't have shared instance
        contractResultTitle = "Feature Unavailable"
        contractResultMessage = "Contract negotiation not available in this version"
        showingContractResultAlert = true
    }
    
    private func handleContractOfferSelected(_ offer: ContractNegotiationManager.ContractOffer) {
        // Contract negotiation disabled
        showingContractNegotiation = false
        contractResultTitle = "Feature Unavailable"
        contractResultMessage = "Contract negotiation not available in this version"
        showingContractResultAlert = true
    }
    
    private func handlePlayerRelease() {
        // Player release disabled - PlayerReleaseManager doesn't have shared instance
        contractResultTitle = "Feature Unavailable"
        contractResultMessage = "Player release not available in this version"
        showingContractResultAlert = true
    }
    
    private func handlePlayerReleaseSelected(_ releaseType: PlayerReleaseManager.ReleaseType) {
        // Player release disabled - PlayerReleaseManager doesn't have shared instance
        showingPlayerReleaseOptions = false
        contractResultTitle = "Feature Unavailable"
        contractResultMessage = "Player release not available in this version"
        showingContractResultAlert = true
    }
}

// MARK: - Preview
struct PlayerDetailView_Refactored_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PlayerDetailView_Refactored(
                player: PlayerData.samplePlayer,
                teamLogoName: "KC",
                leagueId: UUID(),
                isEditable: true,
                leagueManager: nil
            )
        }
    }
}
