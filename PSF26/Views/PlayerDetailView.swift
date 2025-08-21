import SwiftUI

// MARK: - Player Detail View
struct PlayerDetailView: View {
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
            // Bio Tab (Default)
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
                    player: editablePlayer ?? createDefaultEditablePlayer(),
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
                negotiationAttempts: negotiationAttempts,
                maxNegotiationAttempts: maxNegotiationAttempts,
                onOfferSelected: { offer in
                    handleOfferSelection(offer)
                }
            )
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
        .alert(contractResultTitle, isPresented: $showingContractResultAlert) {
            Button("OK") {
                showingContractResultAlert = false
                contractResultTitle = ""
                contractResultMessage = ""
            }
        } message: {
            Text(contractResultMessage)
        }
        .sheet(isPresented: $showingPlayerReleaseOptions) {
            PlayerReleaseOptionsView(
                player: currentPlayer,
                releaseOptions: releaseOptions,
                onReleaseSelected: { releaseType in
                    showingPlayerReleaseOptions = false
                    Task {
                        await executePlayerRelease(releaseType: releaseType)
                    }
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .playerDataDidChange)) { notification in
            // Check if this notification is for our team and player
            if let teamLogoName = notification.userInfo?["teamLogoName"] as? String,
               let playerId = notification.userInfo?["playerId"] as? String,
               teamLogoName == self.teamLogoName {
                print("🔄 PlayerDetailView: Received player data change notification for \(teamLogoName)")
                
                // Refresh the player data if it matches our player
                if let leagueId = self.leagueId {
                    Task {
                        await refreshPlayerData(leagueId: leagueId, playerId: playerId)
                    }
                }
            }
        }
    }
    
    private func handlePlayerUpdate(_ updatedPlayer: EditablePlayerData) {
        isUpdating = true
        self.editablePlayer = updatedPlayer
        self.currentPlayer = updatedPlayer.toPlayerData()
        showingEditSheet = false
        
        // Reset updating flag after a delay to allow state to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isUpdating = false
        }
    }
    
    // MARK: - Bio Tab Content
    private var bioTabContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Player Header
                playerHeaderSection
                
                // Basic Info Card
                basicInfoCard
                
                // Salary & Contract Card
                salaryContractCard
                
                // Player History & Notes (if available)
                if isEditable {
                    editableInfoCard
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color(UIColor.systemGroupedBackground))
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
    
    // MARK: - Player Header Section
    private var playerHeaderSection: some View {
        VStack(spacing: 16) {
            // Player Name & Number
            VStack(spacing: 8) {
                Text("#\(currentPlayer.number)")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.primary)
                
                Text(currentPlayer.fullName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(currentPlayer.position)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(getPositionColor(currentPlayer.position).opacity(0.2))
                    .clipShape(Capsule())
            }
            
            // Overall Rating
            VStack(spacing: 4) {
                Text("OVERALL")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("\(currentPlayer.overall)")
                    .font(.system(size: 48, weight: .black))
                    .foregroundColor(getOverallColor(currentPlayer.overall))
            }
            
            // Team Logo
            Image(teamLogoName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.primary.opacity(0.05),
                    Color.primary.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Basic Info Card
    private var basicInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                InfoItem(title: "Position", value: currentPlayer.position)
                InfoItem(title: "Age", value: "\(currentPlayer.age)")
                InfoItem(title: "Jersey #", value: "#\(currentPlayer.number)")
                InfoItem(title: "Overall", value: "\(currentPlayer.overall)")
            }
            
            // Enhanced info if we have editable data
            if let editablePlayer = editablePlayer {
                Divider()
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    InfoItem(title: "Height", value: editablePlayer.height)
                    InfoItem(title: "Weight", value: editablePlayer.weight)
                    InfoItem(title: "College", value: editablePlayer.college)
                    InfoItem(title: "Years Pro", value: "\(editablePlayer.yearsPro)")
                }
                
                if editablePlayer.isEdited {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.orange)
                        Text("Player data has been modified")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Last modified: \(formatDate(editablePlayer.lastModified))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Salary & Contract Card
    private var salaryContractCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                
                Text("Salary & Contract")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Current Salary
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Current Salary")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatSalary(getSalaryForDisplay()))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Contract Details Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ContractInfoItem(
                        title: "Contract Type",
                        value: getContractType(),
                        icon: "doc.text"
                    )
                    
                    ContractInfoItem(
                        title: "Years Remaining",
                        value: "\(getContractYearsRemaining())",
                        icon: "calendar"
                    )
                    
                    ContractInfoItem(
                        title: "Guaranteed Money",
                        value: getGuaranteedMoneyText(),
                        icon: "shield.checkered"
                    )
                    
                    ContractInfoItem(
                        title: "Dead Cap if Released",
                        value: getDeadCapText(),
                        icon: "exclamationmark.triangle.fill"
                    )
                    
                    if isRookieContract() {
                        ContractInfoItem(
                            title: "Draft Pick",
                            value: getDraftPickText(),
                            icon: "star"
                        )
                        
                        ContractInfoItem(
                            title: "5th Year Option",
                            value: hasFifthYearOption() ? "Available" : "N/A",
                            icon: "plus.circle"
                        )
                    }
                }
                
                // Contract Status
                contractStatusIndicator
                
                // Salary Comparison
                if let editablePlayer = editablePlayer {
                    salaryComparisonSection(editablePlayer: editablePlayer)
                }
                
                // Contract Management Buttons
                if isEditable {
                    contractManagementButtons
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var contractStatusIndicator: some View {
        HStack {
            Image(systemName: getContractStatusIcon())
                .foregroundColor(getContractStatusColor())
            
            Text(getContractStatusText())
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(getContractStatusColor())
            
            Spacer()
            
            if getContractYearsRemaining() <= 1 {
                Text("Expiring Soon")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(getContractStatusColor().opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func salaryComparisonSection(editablePlayer: EditablePlayerData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Position Market")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Position Average")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatSalary(getPositionAverageSalary()))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Market Rank")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(getMarketRankText())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(getMarketRankColor())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
    
    // MARK: - Contract Management Buttons
    private var contractManagementButtons: some View {
        VStack(spacing: 12) {
            Text("Contract Management")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                // Re-structure/Re-sign Button
                Button(action: {
                    handleContractNegotiation()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: getContractYearsRemaining() <= 1 ? "signature" : "arrow.2.squarepath")
                            .font(.title3)
                        Text(getContractYearsRemaining() <= 1 ? "Re-sign" : "Re-structure")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(canNegotiateContract() ? .blue : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background((canNegotiateContract() ? Color.blue : Color.gray).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(!canNegotiateContract())
                
                // Release Button
                Button(action: {
                    handlePlayerRelease()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "person.badge.minus")
                            .font(.title3)
                        Text("Release")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                // Trade Button
                Button(action: {
                    // TODO: Implement trade logic
                    print("Trade tapped")
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.title3)
                        Text("Trade")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Contract Negotiation Functions
    
    private func handleContractNegotiation() {
        print("💼 Starting contract negotiation for \(currentPlayer.firstName) \(currentPlayer.lastName)")
        
        // Get current season and week from league manager
        let currentSeason = getCurrentSeason()
        let currentWeek = getCurrentWeek()
        
        // Check if player can negotiate
        let negotiationStatus = ContractNegotiationManager.canPlayerNegotiate(
            player: currentPlayer,
            currentSeason: currentSeason,
            currentWeek: currentWeek
        )
        
        if negotiationStatus != .available {
            // Show lockout message
            if let message = ContractNegotiationManager.getNegotiationStatusMessage(
                player: currentPlayer,
                currentSeason: currentSeason,
                currentWeek: currentWeek
            ) {
                showNegotiationLockedAlert(message: message)
                return
            }
        }
        
        // Get the team for negotiation
        let team: LeagueTeam
        if let leagueManager = leagueManager, let userTeam = leagueManager.userTeam {
            team = userTeam
        } else {
            team = createMockTeam()
        }
        
        // Determine negotiation type based on contract status
        let yearsRemaining = getContractYearsRemaining()
        let negotiationType: ContractNegotiationManager.NegotiationType = yearsRemaining <= 1 ? .resign : .restructure
        
        print("💼 Negotiation type: \(negotiationType), Years remaining: \(yearsRemaining)")
        
        // Generate contract offers
        contractOffers = ContractNegotiationManager.generateContractOffers(
            player: currentPlayer,
            team: team,
            negotiationType: negotiationType
        )
        
        print("💼 Generated \(contractOffers.count) contract offers")
        for (index, offer) in contractOffers.enumerated() {
            print("   Offer \(index + 1): \(offer.type) - \(ContractNegotiationManager.formatCurrency(offer.yearlyValue))/year")
        }
        
        // Show negotiation view
        showingContractNegotiation = true
    }
    
    private func showNegotiationLockedAlert(message: String) {
        let alert = UIAlertController(
            title: "Contract Negotiation Unavailable",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var topController = rootViewController
            while let presentedController = topController.presentedViewController {
                topController = presentedController
            }
            
            topController.present(alert, animated: true)
        }
    }
    
    private func getCurrentSeason() -> Int {
        // Get current season from league manager or default to 1
        return leagueManager?.currentSeasonNumber ?? 1
    }
    
    private func getCurrentWeek() -> Int {
        // Get current week from league manager or default to 1
        return leagueManager?.currentWeek ?? 1
    }
    
    private func canNegotiateContract() -> Bool {
        let currentSeason = getCurrentSeason()
        let currentWeek = getCurrentWeek()
        
        let status = ContractNegotiationManager.canPlayerNegotiate(
            player: currentPlayer,
            currentSeason: currentSeason,
            currentWeek: currentWeek
        )
        
        return status == .available
    }
    
    private func createMockTeam() -> LeagueTeam {
        // Create a mock team for testing purposes
        let mockPlayers = [currentPlayer] // Include the current player
        
        // Create a mock coach
        let mockOffensiveCoordinator = OffensiveCoordinator(
            firstName: "OC",
            lastName: "Mock",
            overallRating: 70,
            offensiveScheme: "Balanced",
            experience: 3
        )
        
        let mockDefensiveCoordinator = DefensiveCoordinator(
            firstName: "DC",
            lastName: "Mock",
            overallRating: 70,
            defensiveScheme: "3-4",
            experience: 3
        )
        
        let mockCoach = Coach(
            firstName: "Mock",
            lastName: "Coach",
            overallRating: 75,
            offensiveScheme: "Balanced",
            defensiveScheme: "3-4",
            experience: 5,
            offensiveCoordinator: mockOffensiveCoordinator,
            defensiveCoordinator: mockDefensiveCoordinator
        )
        
        return LeagueTeam(
            logoName: teamLogoName,
            name: TeamData.getTeamDisplayName(teamLogoName),
            conference: "NFC",
            division: "North",
            primaryColor: TeamColorMapping.getColors(for: teamLogoName).primary,
            secondaryColor: TeamColorMapping.getColors(for: teamLogoName).secondary,
            players: mockPlayers,
            overallRating: 75,
            coach: mockCoach
        )
    }
    
    private func handleOfferSelection(_ offer: ContractNegotiationManager.ContractOffer) {
        print("💼 Offer selected: \(offer.type)")
        
        // Increment negotiation attempts
        negotiationAttempts += 1
        let isLastAttempt = negotiationAttempts >= maxNegotiationAttempts
        
        // Use the same team logic as in handleContractNegotiation
        let team: LeagueTeam
        if let leagueManager = leagueManager, let userTeam = leagueManager.userTeam {
            team = userTeam
        } else {
            team = createMockTeam()
        }
        
        let result = ContractNegotiationManager.negotiateContract(
            offer: offer,
            player: currentPlayer,
            team: team,
            attemptNumber: negotiationAttempts,
            isLastAttempt: isLastAttempt
        )
        
        negotiationResult = result
        showingContractNegotiation = false
        
        // Handle the negotiation result
        Task {
            await handleNegotiationResult(result, offer: offer)
        }
    }
    
    private func handleNegotiationResult(_ result: ContractNegotiationManager.NegotiationResult, offer: ContractNegotiationManager.ContractOffer) async {
        if result.accepted, let newContract = result.newContract {
            // Save the contract to the player
            do {
                guard let leagueId = leagueId else {
                    print("❌ No league ID available for contract saving")
                    showContractResultAlert(result)
                    return
                }
                
                let currentSeason = getCurrentSeason()
                
                try await ContractNegotiationManager.saveContractToPlayer(
                    player: currentPlayer,
                    contract: newContract,
                    leagueId: leagueId,
                    teamLogoName: teamLogoName,
                    currentSeason: currentSeason,
                    negotiationType: offer.negotiationType
                )
                
                // Update local player data
                await MainActor.run {
                    applyNewContract(newContract)
                    // Reset negotiation attempts on successful signing
                    negotiationAttempts = 0
                }
                
                print("✅ Contract successfully saved and applied")
                
            } catch {
                print("❌ Failed to save contract: \(error)")
                // Still show the result but indicate there was a save issue
            }
        } else if !result.accepted && result.isLastAttempt {
            // Player rejected final offer - lock them out from further negotiations
            print("🔒 Player \(currentPlayer.fullName) rejected final offer - locking out from negotiations")
            
            let currentSeason = getCurrentSeason()
            ContractNegotiationManager.recordContractRejection(
                player: currentPlayer, 
                season: currentSeason, 
                originalNegotiationType: offer.negotiationType
            )
            
            // Reset negotiation attempts since player is now locked out
            await MainActor.run {
                negotiationAttempts = 0
            }
        }
        
        // Show the result message
        showContractResultAlert(result)
    }
    
    private func applyNewContract(_ newContract: PlayerContract) {
        print("📝 Applying new contract to \(currentPlayer.firstName) \(currentPlayer.lastName)")
        print("💰 Contract Value: \(formatSalary(newContract.totalValue))")
        print("🛡️ Guaranteed: \(formatSalary(newContract.totalGuaranteed))")
        print("📅 Years: \(newContract.yearsRemaining)")
        
        // Update the editable player's contract
        if editablePlayer != nil {
            editablePlayer!.contract = newContract
            editablePlayer!.contractYearsLeft = newContract.yearsRemaining
            editablePlayer!.salary = newContract.currentYearSalary
            print("✅ Contract applied to editablePlayer")
        }
        
        print("🔄 Contract application completed")
    }
    
    @MainActor
    private func showContractResultAlert(_ result: ContractNegotiationManager.NegotiationResult) {
        let playerName = "\(currentPlayer.firstName) \(currentPlayer.lastName)"
        
        print("🗣️ Showing contract result for \(playerName)")
        print("✅ Accepted: \(result.accepted)")
        print("💬 Player Response: \(result.playerResponse)")
        
        let title: String
        let message: String
        
        if result.accepted {
            title = "Contract Accepted! 🎉"
            var contractDetails = ""
            if let newContract = result.newContract {
                contractDetails = "\n\nNew Contract Details:"
                contractDetails += "\n• Total Value: \(formatSalary(newContract.totalValue))"
                contractDetails += "\n• Annual Value: \(formatSalary(newContract.currentYearSalary))"
                contractDetails += "\n• Guaranteed: \(formatSalary(newContract.totalGuaranteed))"
                contractDetails += "\n• Contract Length: \(newContract.yearsRemaining) years"
            }
            message = "\(playerName): \"\(result.playerResponse)\"\(contractDetails)"
        } else {
            if result.isLastAttempt {
                title = "Player Entering Free Agency"
                message = "\(playerName): \"\(result.playerResponse)\"\n\nThis player is no longer available for contract negotiations."
            } else {
                title = "Contract Rejected (Attempt \(result.attemptNumber)/\(maxNegotiationAttempts))"
                message = "\(playerName): \"\(result.playerResponse)\"\n\nYou have \(maxNegotiationAttempts - result.attemptNumber) attempts remaining."
            }
        }
        
        print("📱 Alert Title: \(title)")
        print("📱 Alert Message: \(message)")
        
        // Use SwiftUI alert instead of UIKit for better integration
        contractResultTitle = title
        contractResultMessage = message
        showingContractResultAlert = true
    }
    
    private func showFreeAgencyAlert() {
        let playerName = "\(currentPlayer.firstName) \(currentPlayer.lastName)"
        let title = "Player Unavailable"
        let message = "\(playerName) has already decided to test free agency after \(maxNegotiationAttempts) failed negotiation attempts.\n\nThis player is no longer available for contract negotiations."
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func showRestructureRefusalAlert(response: String) {
        let playerName = "\(currentPlayer.firstName) \(currentPlayer.lastName)"
        let title = "Restructure Declined"
        let message = "\(playerName): \"\(response)\"\n\nThis player is not interested in restructuring their contract at this time. You can try again later in the season."
        
        print("🚫 Player refused restructure: \(playerName)")
        print("💬 Player Response: \(response)")
        print("📱 Showing refusal alert - NOT opening negotiation menu")
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Use the same robust alert presentation method as contract results
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Find the top-most view controller
            var topController = rootViewController
            while let presentedController = topController.presentedViewController {
                topController = presentedController
            }
            
            print("📱 Presenting restructure refusal alert from: \(type(of: topController))")
            topController.present(alert, animated: true) {
                print("📱 Restructure refusal alert presented successfully")
            }
        } else {
            print("❌ Could not find window or root view controller for restructure refusal alert")
        }
    }
    
    private func showResignRefusalAlert(response: String) {
        let playerName = "\(currentPlayer.firstName) \(currentPlayer.lastName)"
        let title = "Re-sign Declined"
        let message = "\(playerName): \"\(response)\"\n\nThis player has decided not to re-sign with the team at this time."
        
        print("🚫 Player refused re-sign: \(playerName)")
        print("💬 Player Response: \(response)")
        print("📱 Showing re-sign refusal alert - NOT opening negotiation menu")
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Use the same robust alert presentation method as contract results
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Find the top-most view controller
            var topController = rootViewController
            while let presentedController = topController.presentedViewController {
                topController = presentedController
            }
            
            print("📱 Presenting re-sign refusal alert from: \(type(of: topController))")
            topController.present(alert, animated: true) {
                print("📱 Re-sign refusal alert presented successfully")
            }
        } else {
            print("❌ Could not find window or root view controller for re-sign refusal alert")
        }
    }
    
    // MARK: - Editable Info Card
    private var editableInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("League Management")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "pencil.and.outline")
                        .foregroundColor(.blue)
                    Text("Edit player information")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    loadEditablePlayerData()
                }
                
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.orange)
                    Text("View edit history")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Functions
    
    private func loadEditablePlayerData() {
        guard let leagueId = leagueId else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let editablePlayers = try PlayerDataManager.shared.loadPlayersFromFile(
                    leagueId: leagueId,
                    teamLogoName: teamLogoName
                )
                
                await MainActor.run {
                    print("🔍 PlayerDetailView: Looking for player - Name: '\(currentPlayer.firstName) \(currentPlayer.lastName)', Number: \(currentPlayer.number), Position: '\(currentPlayer.position)'")
                    print("🔍 Available players in file: \(editablePlayers.count)")
                    
                    // Find the matching player by number and position (more stable than name)
                    self.editablePlayer = editablePlayers.first { editablePlayer in
                        editablePlayer.number == currentPlayer.number &&
                        editablePlayer.position == currentPlayer.position
                    }
                    
                    if let found = self.editablePlayer {
                        print("🔍 ✅ Found player by number+position: \(found.firstName) \(found.lastName)")
                        showingEditSheet = true
                    } else {
                        print("🔍 ❌ Player not found in editable data")
                        errorMessage = "Could not find player data for editing"
                    }
                    
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to load player data: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func getPositionColor(_ position: String) -> Color {
        switch position {
        case "QB": return .red
        case "RB", "FB": return .green
        case "WR", "TE": return .blue
        case "LT", "LG", "C", "RG", "RT": return .orange
        case "DE", "DT", "EDGE": return .purple
        case "MLB", "ROLB", "LOLB": return .pink
        case "CB", "SS", "FS": return .yellow
        case "K", "P": return .gray
        default: return .gray
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
    
    private func createDefaultEditablePlayer() -> EditablePlayerData {
        return EditablePlayerData(
            id: UUID(),
            firstName: currentPlayer.firstName,
            lastName: currentPlayer.lastName,
            position: currentPlayer.position,
            number: currentPlayer.number,
            age: currentPlayer.age,
            college: "Unknown",
            height: "6'0\"",
            weight: "200 lbs",
            yearsPro: max(0, currentPlayer.age - 22),
            teamLogoName: teamLogoName,
            leagueId: leagueId ?? UUID(),
            isEdited: false,
            lastModified: Date(),
            // Default individual attributes
            speed: 50, agility: 50, awareness: 50, strength: 50, stamina: 50, injury: 50,
            carrying: 50, trucking: 50, catching: 50, breakTackle: 50, jukeMove: 50, spinMove: 50,
            stiffArm: 50, acceleration: 50, changeOfDirection: 50,
            throwPower: 50, throwAccuracyShort: 50, throwAccuracyMid: 50, throwAccuracyDeep: 50,
            throwOnTheRun: 50, throwUnderPressure: 50, playAction: 50,
            tackle: 50, blockShedding: 50, zoneCoverage: 50, manCoverage: 50, pursuit: 50,
            finesseMoves: 50, powerMoves: 50, press: 50, jumping: 50, playRecognition: 50,
            hitPower: 50, toughness: 50,
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
            // Use the current player's overall rating
            overall: currentPlayer.overall
        )
    }
    
    /// Refreshes player data from the latest saved data without closing the view
    private func refreshPlayerData(leagueId: UUID, playerId: String) async {
        print("🔄 PlayerDetailView: Refreshing player data for \(playerId)")
        
        do {
            let editablePlayers = try PlayerDataManager.shared.loadPlayersFromFile(
                leagueId: leagueId,
                teamLogoName: teamLogoName
            )
            
            await MainActor.run {
                // Find the updated player data
                if let updatedEditablePlayer = editablePlayers.first(where: { editablePlayer in
                    editablePlayer.firstName == currentPlayer.firstName &&
                    editablePlayer.lastName == currentPlayer.lastName &&
                    editablePlayer.number == currentPlayer.number
                }) {
                    // Update both the editable and current player data
                    self.editablePlayer = updatedEditablePlayer
                    self.currentPlayer = updatedEditablePlayer.toPlayerData()
                    print("🔄 PlayerDetailView: Successfully refreshed player data for \(updatedEditablePlayer.firstName) \(updatedEditablePlayer.lastName)")
                } else {
                    print("🔄 PlayerDetailView: Could not find updated player data for \(currentPlayer.firstName) \(currentPlayer.lastName) #\(currentPlayer.number)")
                }
            }
        } catch {
            print("🔄 PlayerDetailView: Failed to refresh player data: \(error)")
        }
    }
    
    /// Loads the editable player data on view appear
    private func loadEditablePlayerData(leagueId: UUID) async {
        print("📂 Loading editable player data for \(currentPlayer.firstName) \(currentPlayer.lastName)")
        
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
                    self.editablePlayer = foundEditablePlayer
                    print("📂 Successfully loaded editable player data for \(foundEditablePlayer.firstName) \(foundEditablePlayer.lastName)")
                    if foundEditablePlayer.contract != nil {
                        print("💰 Player has contract information")
                    } else {
                        print("❌ Player has no contract information")
                    }
                } else {
                    print("📂 Could not find editable player data for \(currentPlayer.firstName) \(currentPlayer.lastName)")
                }
            }
        } catch {
            print("📂 Failed to load editable player data: \(error)")
        }
    }
    
    // MARK: - Salary & Contract Helper Functions
    
    private func getSalaryForDisplay() -> Int {
        if let editablePlayer = editablePlayer {
            return editablePlayer.currentSalary
        } else {
            return currentPlayer.estimatedSalary
        }
    }
    
    private func formatSalary(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    private func getContractType() -> String {
        if isRookieContract() {
            return "Rookie"
        } else {
            return "Veteran"
        }
    }
    
    private func isRookieContract() -> Bool {
        // Simple heuristic: players 22-23 years old with high ratings might be rookies
        return currentPlayer.age <= 23 && (currentPlayer.age - 22) <= 1
    }
    
    private func getContractYearsRemaining() -> Int {
        if let editablePlayer = editablePlayer {
            return editablePlayer.contractYearsRemaining
        }
        
        // Estimate based on age if no contract data available
        let yearsInLeague = max(0, currentPlayer.age - 22)
        let estimatedContractLength = 4
        let yearsIntoContract = yearsInLeague % estimatedContractLength
        return max(1, estimatedContractLength - yearsIntoContract)
    }
    
    private func getDraftPickText() -> String {
        if let pick = estimateDraftPick() {
            return "#\(pick)"
        }
        return "Est. #\(Int.random(in: 1...257))"
    }
    
    private func estimateDraftPick() -> Int? {
        guard isRookieContract() else { return nil }
        
        let overall = currentPlayer.overall
        let position = currentPlayer.position
        
        // High-value positions get drafted earlier
        let positionAdjustment: Int
        switch position {
        case "QB": positionAdjustment = 20
        case "LT", "DE", "EDGE": positionAdjustment = 15
        case "WR", "CB": positionAdjustment = 10
        case "RB", "TE": positionAdjustment = 5
        default: positionAdjustment = 0
        }
        
        let adjustedRating = overall + positionAdjustment
        
        // Convert to draft pick (higher rating = earlier pick)
        switch adjustedRating {
        case 95...: return Int.random(in: 1...10)
        case 90...94: return Int.random(in: 11...32)
        case 85...89: return Int.random(in: 33...64)
        case 80...84: return Int.random(in: 65...100)
        case 75...79: return Int.random(in: 101...150)
        default: return Int.random(in: 151...257)
        }
    }
    
    private func hasFifthYearOption() -> Bool {
        guard isRookieContract() else { return false }
        if let pick = estimateDraftPick() {
            return pick <= 32 // First round picks only
        }
        return false
    }
    
    private func getContractStatusText() -> String {
        let yearsLeft = getContractYearsRemaining()
        if yearsLeft <= 1 {
            return "Contract expires after this season"
        } else if yearsLeft == 2 {
            return "Extension eligible"
        } else {
            return "Contract secure"
        }
    }
    
    private func getContractStatusIcon() -> String {
        let yearsLeft = getContractYearsRemaining()
        if yearsLeft <= 1 {
            return "exclamationmark.triangle.fill"
        } else if yearsLeft == 2 {
            return "clock.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private func getContractStatusColor() -> Color {
        let yearsLeft = getContractYearsRemaining()
        if yearsLeft <= 1 {
            return .orange
        } else if yearsLeft == 2 {
            return .blue
        } else {
            return .green
        }
    }
    
    private func getPositionAverageSalary() -> Int {
        // Estimate average salary for this position
        let baseSalary = 2_800_000.0
        let positionMultiplier = SalaryCapManager.getPositionMultiplier(position: currentPlayer.position)
        return Int(baseSalary * positionMultiplier)
    }
    
    private func getMarketRankText() -> String {
        let playerSalary = getSalaryForDisplay()
        let positionAverage = getPositionAverageSalary()
        
        let ratio = Double(playerSalary) / Double(positionAverage)
        
        switch ratio {
        case 1.5...: return "Elite"
        case 1.2...1.49: return "Above Avg"
        case 0.8...1.19: return "Average"
        case 0.5...0.79: return "Below Avg"
        default: return "Minimum"
        }
    }
    
    private func getMarketRankColor() -> Color {
        let playerSalary = getSalaryForDisplay()
        let positionAverage = getPositionAverageSalary()
        
        let ratio = Double(playerSalary) / Double(positionAverage)
        
        switch ratio {
        case 1.5...: return .purple
        case 1.2...1.49: return .green
        case 0.8...1.19: return .blue
        case 0.5...0.79: return .orange
        default: return .red
        }
    }
    
    private func getGuaranteedMoneyText() -> String {
        if let editablePlayer = editablePlayer,
           let contract = editablePlayer.contract {
            let percentage = Int(contract.guaranteedPercentage * 100)
            return "\(formatSalary(contract.totalGuaranteed)) (\(percentage)%)"
        } else {
            // Estimate guaranteed money for display
            let estimatedSalary = getSalaryForDisplay()
            let estimatedGuaranteed = Int(Double(estimatedSalary) * 0.4) // Assume 40% guaranteed
            return "\(formatSalary(estimatedGuaranteed)) (~40%)"
        }
    }
    
    private func getDeadCapText() -> String {
        if let editablePlayer = editablePlayer,
           let contract = editablePlayer.contract {
            let deadMoneyCalc = contract.calculateDeadMoney(isPostJune1: false)
            
            if deadMoneyCalc.capSavings > 0 {
                return "\(formatSalary(deadMoneyCalc.totalDeadMoney)) (Save \(formatSalary(deadMoneyCalc.capSavings)))"
            } else {
                return "\(formatSalary(deadMoneyCalc.totalDeadMoney)) (No savings)"
            }
        } else {
            // Estimate dead cap for display based on realistic contract structure
            let estimatedSalary = getSalaryForDisplay()
            let yearsRemaining = getContractYearsRemaining()
            
            // More realistic dead cap estimation
            // Assume 50% of remaining contract value is guaranteed (typical for veterans)
            // Rookies typically have 100% guaranteed contracts
            let isLikelyRookie = currentPlayer.age <= 25
            let guaranteedPercentage = isLikelyRookie ? 0.8 : 0.4
            
            // Calculate total remaining contract value
            let totalRemainingValue = estimatedSalary * yearsRemaining
            let estimatedDeadCap = Int(Double(totalRemainingValue) * guaranteedPercentage)
            
            return "\(formatSalary(estimatedDeadCap)) (~est.)"
        }
    }
    
    private func handlePlayerRelease() {
        print("🚫 Player release initiated for \(currentPlayer.firstName) \(currentPlayer.lastName)")
        print("🔍 Current player details: firstName='\(currentPlayer.firstName)', lastName='\(currentPlayer.lastName)', number=\(currentPlayer.number), position='\(currentPlayer.position)'")
        
        // Debug: Check editablePlayer state
        if let editablePlayer = editablePlayer {
            print("✅ Found editablePlayer: \(editablePlayer.firstName) \(editablePlayer.lastName)")
            print("🔍 Editable player details: firstName='\(editablePlayer.firstName)', lastName='\(editablePlayer.lastName)', number=\(editablePlayer.number), position='\(editablePlayer.position)'")
            if let contract = editablePlayer.contract {
                print("✅ Found contract: \(contract.yearsRemaining) years, $\(contract.currentYearSalary)/year")
                // Generate release options using the new system
                releaseOptions = PlayerReleaseManager.generateReleaseOptions(for: currentPlayer, contract: contract)
                showingPlayerReleaseOptions = true
            } else {
                print("❌ EditablePlayer has no contract")
                // Player has no contract data - show simple release confirmation
                showSimpleReleaseConfirmation()
            }
        } else {
            print("❌ No editablePlayer found")
            // Player has no contract data - show simple release confirmation
            showSimpleReleaseConfirmation()
        }
    }
    
    private func showSimpleReleaseConfirmation() {
        let playerName = "\(currentPlayer.firstName) \(currentPlayer.lastName)"
        
        let alert = UIAlertController(
            title: "Release Player",
            message: "Are you sure you want to release \(playerName)? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Release", style: .destructive) { _ in
            Task {
                await self.executePlayerRelease(releaseType: .immediate)
            }
        })
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var topController = rootViewController
            while let presentedController = topController.presentedViewController {
                topController = presentedController
            }
            
            topController.present(alert, animated: true)
        }
    }
    
    private func executePlayerRelease(releaseType: PlayerReleaseManager.ReleaseType) async {
        guard let leagueId = leagueId else {
            showReleaseErrorAlert(error: "League ID not available")
            return
        }
        
        // Debug: Compare data sources before release
        await debugPlayerDataSources(leagueId: leagueId)
        
        do {
            // Show financial warning before release if player has a contract
            if let editablePlayer = editablePlayer, let contract = editablePlayer.contract {
                let deadMoneyCalc = contract.calculateDeadMoney(isPostJune1: releaseType == .postJune1)
                let warningShown = await showFinancialWarning(deadMoneyCalc: deadMoneyCalc, releaseType: releaseType)
                if !warningShown {
                    return // User cancelled
                }
            }
            
            try await PlayerReleaseManager.releasePlayer(
                player: currentPlayer,
                releaseType: releaseType,
                leagueId: leagueId,
                teamLogoName: teamLogoName
            )
            
            // Player successfully released - dismiss this view immediately
            await MainActor.run {
                // Post notification to refresh roster views
                NotificationCenter.default.post(
                    name: NSNotification.Name("PlayerReleased"),
                    object: nil,
                    userInfo: [
                        "playerName": "\(currentPlayer.firstName) \(currentPlayer.lastName)",
                        "teamLogoName": teamLogoName,
                        "leagueId": leagueId.uuidString
                    ]
                )
                
                // Dismiss the view
                dismiss()
            }
            
        } catch let error as PlayerReleaseError {
            switch error {
            case .belowMinimumRoster:
                showMinimumRosterAlert()
            default:
                showReleaseErrorAlert(error: error.localizedDescription)
            }
        } catch {
            showReleaseErrorAlert(error: error.localizedDescription)
        }
    }
    
    private func debugPlayerDataSources(leagueId: UUID) async {
        print("🔍 DEBUG: Comparing player data sources")
        print("🎯 Target player: \(currentPlayer.firstName) \(currentPlayer.lastName) #\(currentPlayer.number)")
        
        // Check what we have in editablePlayer (UI data)
        if let editablePlayer = editablePlayer {
            print("📱 UI editablePlayer: '\(editablePlayer.firstName)' '\(editablePlayer.lastName)' #\(editablePlayer.number)")
        } else {
            print("📱 UI editablePlayer: nil")
        }
        
        // Check what PlayerDataManager returns (fresh from file)
        do {
            let freshPlayers = try PlayerDataManager.shared.loadPlayersFromFile(
                leagueId: leagueId,
                teamLogoName: teamLogoName
            )
            
            print("💾 Fresh from file: \(freshPlayers.count) players")
            
            // Look for our target player in fresh data
            if let foundPlayer = freshPlayers.first(where: {
                $0.firstName == currentPlayer.firstName &&
                $0.lastName == currentPlayer.lastName &&
                $0.number == currentPlayer.number
            }) {
                print("💾 Found in fresh data: '\(foundPlayer.firstName)' '\(foundPlayer.lastName)' #\(foundPlayer.number)")
            } else {
                print("💾 NOT found in fresh data")
                // Show first few players for comparison
                print("💾 First 3 players in fresh data:")
                for (i, p) in freshPlayers.prefix(3).enumerated() {
                    print("   \(i+1). '\(p.firstName)' '\(p.lastName)' #\(p.number)")
                }
            }
        } catch {
            print("💾 Error loading fresh data: \(error)")
        }
    }
    
    @MainActor
    private func showFinancialWarning(deadMoneyCalc: DeadMoneyCalculation, releaseType: PlayerReleaseManager.ReleaseType) async -> Bool {
        return await withCheckedContinuation { continuation in
            let releaseTypeText = releaseType == .postJune1 ? "Post-June 1" : "Immediate"
            let playerName = "\(currentPlayer.firstName) \(currentPlayer.lastName)"
            
            let alert = UIAlertController(
                title: "⚠️ Financial Impact",
                message: """
                Releasing \(playerName) (\(releaseTypeText)) will result in:
                
                💰 Dead Money: $\(formatCurrency(deadMoneyCalc.totalDeadMoney))
                📊 Cap Savings: $\(formatCurrency(deadMoneyCalc.capSavings))
                
                \(deadMoneyCalc.isPostJune1 ? "This Year: $\(formatCurrency(deadMoneyCalc.currentYearHit))\nNext Year: $\(formatCurrency(deadMoneyCalc.nextYearHit))" : "All dead money hits this year's cap.")
                
                This action cannot be undone.
                """,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            
            alert.addAction(UIAlertAction(title: "Release Player", style: .destructive) { _ in
                continuation.resume(returning: true)
            })
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(alert, animated: true)
            }
        }
    }
    
    @MainActor
    private func showMinimumRosterAlert() {
        let alert = UIAlertController(
            title: "🚫 Cannot Release Player",
            message: "Your team is at or below the minimum roster size (45 players). You must sign additional players before releasing anyone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
    

    
    private func showReleaseErrorAlert(error: String) {
        let alert = UIAlertController(
            title: "Release Failed",
            message: "Failed to release player: \(error)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var topController = rootViewController
            while let presentedController = topController.presentedViewController {
                topController = presentedController
            }
            
            topController.present(alert, animated: true)
        }
    }
}

// MARK: - Player Stats Main View
struct PlayerStatsMainView: View {
    let player: PlayerData
    let teamLogoName: String
    let leagueId: UUID?
    let leagueManager: LeagueManager?
    let editablePlayer: EditablePlayerData?
    @State private var selectedStatsTab: StatsTab = .season
    
    // Generate player ID to match LeagueManager format
    private var playerId: String {
        "\(player.firstName)_\(player.lastName)_\(player.number)"
    }
    
    private var playerSeasonStats: PlayerSeasonStats? {
        leagueManager?.getPlayerSeasonStats(playerId: playerId)
    }
    
    private var playerGameStats: [GamePlayerStats] {
        guard let leagueManager = leagueManager else { return [] }
        
        var gameStats: [GamePlayerStats] = []
        for (_, statsArray) in leagueManager.gamePlayerStats {
            for stat in statsArray {
                if stat.playerId == playerId {
                    gameStats.append(stat)
                }
            }
        }
        
        // Sort by week (ascending for chronological order)
        return gameStats.sorted { $0.week < $1.week }
    }
    
    enum StatsTab: String, CaseIterable {
        case season = "Season"
        case career = "Career"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Stats Header
            statsHeaderSection
            
            // Sub-tabs for Season/Career
            Picker("Stats Type", selection: $selectedStatsTab) {
                Text("Season").tag(StatsTab.season)
                Text("Career").tag(StatsTab.career)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Stats Content
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedStatsTab {
                    case .season:
                        seasonStatsContent
                    case .career:
                        careerStatsContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Stats Header Section
    private var statsHeaderSection: some View {
        VStack(spacing: 12) {
            // Player Quick Info
            HStack(spacing: 16) {
                Image(teamLogoName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(player.firstName) \(player.lastName)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text("#\(player.number)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(player.position)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Games Played
                if let stats = playerSeasonStats {
                    VStack(spacing: 2) {
                        Text("\(stats.gamesPlayed)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text("Games")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            
            Divider()
        }
    }
    
    // MARK: - Season Stats Content (Weekly Breakdown)
    private var seasonStatsContent: some View {
        VStack(spacing: 20) {
            if playerGameStats.isEmpty {
                noStatsView
            } else {
                // Season Overview Card
                if let stats = playerSeasonStats {
                    seasonOverviewCard(stats: stats)
                }
                
                // Weekly Game-by-Game Table
                weeklyGameStatsTable
                
                // Season Totals Card
                if let stats = playerSeasonStats {
                    seasonTotalsCard(stats: stats)
                }
            }
        }
    }
    
    // MARK: - Career Stats Content (Per Season)
    private var careerStatsContent: some View {
        VStack(spacing: 20) {
            // Career Overview Card
            VStack(alignment: .leading, spacing: 16) {
                Text("Career Overview")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                VStack(spacing: 16) {
                    // Career Stats Summary
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(playerSeasonStats?.gamesPlayed ?? 0)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("Games")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Position-specific career highlight
                        if let stats = playerSeasonStats {
                            PositionStatsView(stats: stats, position: player.position)
                        }
                        
                        Spacer()
                    }
                    
                    // Career Background
                    VStack(alignment: .leading, spacing: 12) {
                        if let editableData = editablePlayer {
                            CareerBackgroundView(player: editableData)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Career History Card
            if let editableData = editablePlayer {
                CareerHistoryView(
                    player: editableData,
                    teamLogoName: teamLogoName,
                    playerNumber: player.number
                )
            }
            
            // Season-by-Season Table
            careerSeasonStatsTable
        }
    }
    
    // MARK: - Position Stats View
    private struct PositionStatsView: View {
        let stats: PlayerSeasonStats
        let position: String
        
        var body: some View {
            Group {
                switch position {
                case "QB":
                    VStack {
                        Text("\(stats.passingYards)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Pass Yards")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(stats.passingTouchdowns)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Pass TDs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                case "RB", "FB":
                    VStack {
                        Text("\(stats.rushingYards)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Rush Yards")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(stats.rushingTouchdowns)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Rush TDs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                case "WR", "TE":
                    VStack {
                        Text("\(stats.receivingYards)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Rec Yards")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(stats.receivingTouchdowns)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Rec TDs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                case "K":
                    VStack {
                        Text("\(stats.fieldGoalsMade)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("FG Made")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text(String(format: "%.1f%%", stats.fieldGoalPercentage))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("FG %")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                default:
                    VStack {
                        Text("\(stats.tackles)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Tackles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(stats.sacksMade)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Sacks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Career Background View
    private struct CareerBackgroundView: View {
        let player: EditablePlayerData
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "graduationcap.fill")
                        .foregroundColor(.blue)
                    Text(player.college)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    Text("\(player.yearsPro) Years Pro")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "ruler.fill")
                        .foregroundColor(.green)
                    Text("\(player.height) • \(player.weight)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    // MARK: - Career History View
    private struct CareerHistoryView: View {
        let player: EditablePlayerData
        let teamLogoName: String
        let playerNumber: Int
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Career History")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    // Current Team
                    HStack {
                        Image(teamLogoName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(TeamData.getTeamDisplayName(teamLogoName))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Current Team")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("#\(playerNumber)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Draft Info / College
                    HStack {
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.college)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("\(player.yearsPro) Years Experience")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Weekly Game Stats Table
    private var weeklyGameStatsTable: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Game-by-Game Statistics")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                // Header Row
                HStack {
                    Text("WEEK")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)
                    
                    // Position-specific header
                    Text(getPositionStatHeader())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("VALUE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray6))
                
                Divider()
                
                // Game Rows
                ForEach(playerGameStats, id: \.id) { gameStats in
                    gameStatsRow(gameStats: gameStats)
                }
            }
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Career Season Stats Table
    private var careerSeasonStatsTable: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Career Statistics by Season")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let stats = playerSeasonStats {
                VStack(spacing: 0) {
                    // Header Row
                    HStack {
                        Text("STATISTIC")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(getSeasonDisplayText(year: 2024, seasonNumber: 1))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 120, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))
                    
                    Divider()
                    
                    // Show same detailed stats as season totals
                    careerStatsRows(stats: stats)
                }
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                noStatsView
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Season Overview Card
    private func seasonOverviewCard(stats: PlayerSeasonStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(getSeasonDisplayText(year: 2024, seasonNumber: 1)) Overview")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                // Header Row
                HStack {
                    Text("CATEGORY")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("VALUE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray6))
                
                Divider()
                
                // Data Rows
                StatTableRow(title: "Games Played", value: "\(stats.gamesPlayed)", isHighlighted: true)
                StatTableRow(title: "Total Touchdowns", value: "\(stats.totalTouchdowns)", isHighlighted: true)
                
                // Position-specific key stat
                switch player.position {
                case "QB":
                    StatTableRow(title: "Passing Yards", value: "\(stats.passingYards)", isHighlighted: true)
                case "RB", "FB":
                    StatTableRow(title: "Rushing Yards", value: "\(stats.rushingYards)", isHighlighted: true)
                case "WR", "TE":
                    StatTableRow(title: "Receiving Yards", value: "\(stats.receivingYards)", isHighlighted: true)
                case "K":
                    StatTableRow(title: "Field Goals Made", value: "\(stats.fieldGoalsMade)", isHighlighted: true)
                default:
                    StatTableRow(title: "Total Tackles", value: "\(stats.tackles)", isHighlighted: true)
                }
            }
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Season Totals Card
    private func seasonTotalsCard(stats: PlayerSeasonStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Season Totals")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                // Header Row
                HStack {
                    Text("STATISTIC")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("TOTAL")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray6))
                
                Divider()
                
                // Data Rows
                switch player.position {
                case "QB":
                    StatTableRow(title: "Pass Attempts", value: "\(stats.passingAttempts)", isHighlighted: false)
                    StatTableRow(title: "Completions", value: "\(stats.passingCompletions)", isHighlighted: false)
                    StatTableRow(title: "Pass Yards", value: "\(stats.passingYards)", isHighlighted: true)
                    StatTableRow(title: "Pass TDs", value: "\(stats.passingTouchdowns)", isHighlighted: true)
                    StatTableRow(title: "Interceptions", value: "\(stats.interceptions)", isHighlighted: true)
                    StatTableRow(title: "Completion %", value: String(format: "%.1f%%", stats.completionPercentage), isHighlighted: false)
                case "RB", "FB":
                    StatTableRow(title: "Rush Attempts", value: "\(stats.rushingAttempts)", isHighlighted: false)
                    StatTableRow(title: "Rush Yards", value: "\(stats.rushingYards)", isHighlighted: true)
                    StatTableRow(title: "Rush TDs", value: "\(stats.rushingTouchdowns)", isHighlighted: true)
                    StatTableRow(title: "Yards/Carry", value: String(format: "%.1f", stats.yardsPerCarry), isHighlighted: false)
                    StatTableRow(title: "Receptions", value: "\(stats.receptions)", isHighlighted: false)
                    StatTableRow(title: "Receiving Yards", value: "\(stats.receivingYards)", isHighlighted: false)
                case "WR", "TE":
                    StatTableRow(title: "Receptions", value: "\(stats.receptions)", isHighlighted: true)
                    StatTableRow(title: "Receiving Yards", value: "\(stats.receivingYards)", isHighlighted: true)
                    StatTableRow(title: "Receiving TDs", value: "\(stats.receivingTouchdowns)", isHighlighted: true)
                    StatTableRow(title: "Yards/Reception", value: String(format: "%.1f", stats.yardsPerReception), isHighlighted: false)
                    StatTableRow(title: "Longest Reception", value: "\(stats.longestReception)", isHighlighted: false)
                    StatTableRow(title: "Dropped Passes", value: "\(stats.droppedPasses)", isHighlighted: false)
                case "K":
                    StatTableRow(title: "FG Attempts", value: "\(stats.fieldGoalAttempts)", isHighlighted: false)
                    StatTableRow(title: "FG Made", value: "\(stats.fieldGoalsMade)", isHighlighted: true)
                    StatTableRow(title: "FG Percentage", value: String(format: "%.1f%%", stats.fieldGoalPercentage), isHighlighted: false)
                    StatTableRow(title: "XP Made", value: "\(stats.extraPointsMade)", isHighlighted: false)
                    StatTableRow(title: "Longest FG", value: "\(stats.longestFieldGoal)", isHighlighted: false)
                    StatTableRow(title: "XP Attempts", value: "\(stats.extraPointAttempts)", isHighlighted: false)
                default: // Defensive positions
                    StatTableRow(title: "Tackles", value: "\(stats.tackles)", isHighlighted: true)
                    StatTableRow(title: "Assisted Tackles", value: "\(stats.assistedTackles)", isHighlighted: false)
                    StatTableRow(title: "Sacks", value: "\(stats.sacksMade)", isHighlighted: true)
                    StatTableRow(title: "Interceptions", value: "\(stats.interceptionsDefense)", isHighlighted: true)
                    StatTableRow(title: "Passes Defended", value: "\(stats.passesDefended)", isHighlighted: false)
                    StatTableRow(title: "Forced Fumbles", value: "\(stats.forcedFumbles)", isHighlighted: false)
                }
            }
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Methods
    private func getSeasonDisplayText(year: Int, seasonNumber: Int) -> String {
        return "\(year) - Season \(toRomanNumeral(seasonNumber))"
    }
    
    private func toRomanNumeral(_ number: Int) -> String {
        let values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
        let numerals = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
        
        var result = ""
        var num = number
        
        for (index, value) in values.enumerated() {
            let count = num / value
            if count > 0 {
                result += String(repeating: numerals[index], count: count)
                num -= value * count
            }
        }
        
        return result
    }
    
    private func getPositionStatHeader() -> String {
        switch player.position {
        case "QB":
            return "STATISTIC"
        case "RB", "FB":
            return "STATISTIC"
        case "WR", "TE":
            return "STATISTIC"
        case "K":
            return "STATISTIC"
        default:
            return "STATISTIC"
        }
    }
    
    private func gameStatsRow(gameStats: GamePlayerStats) -> some View {
        VStack(spacing: 0) {
            // Main row with primary stat
            HStack {
                Text("Week \(gameStats.week)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(width: 50, alignment: .leading)
                
                Text(getPrimaryStatName())
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(getPrimaryStatValue(gameStats: gameStats))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(UIColor.separator))
                    .opacity(0.3),
                alignment: .bottom
            )
            
            // Additional stats for this week
            ForEach(getAdditionalStats(gameStats: gameStats), id: \.0) { stat in
                HStack {
                    Text("")
                        .frame(width: 50, alignment: .leading)
                    
                    Text(stat.0)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(stat.1)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(UIColor.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(UIColor.separator))
                        .opacity(0.2),
                    alignment: .bottom
                )
            }
        }
    }
    
    private func careerStatsRows(stats: PlayerSeasonStats) -> some View {
        Group {
            // Show same detailed stats as season totals card
            switch player.position {
            case "QB":
                CareerStatRow(title: "Games Played", value: "\(stats.gamesPlayed)", isHighlighted: true)
                CareerStatRow(title: "Pass Attempts", value: "\(stats.passingAttempts)", isHighlighted: false)
                CareerStatRow(title: "Completions", value: "\(stats.passingCompletions)", isHighlighted: false)
                CareerStatRow(title: "Pass Yards", value: "\(stats.passingYards)", isHighlighted: true)
                CareerStatRow(title: "Pass TDs", value: "\(stats.passingTouchdowns)", isHighlighted: true)
                CareerStatRow(title: "Interceptions", value: "\(stats.interceptions)", isHighlighted: true)
                CareerStatRow(title: "Completion %", value: String(format: "%.1f%%", stats.completionPercentage), isHighlighted: false)
                
            case "RB", "FB":
                CareerStatRow(title: "Games Played", value: "\(stats.gamesPlayed)", isHighlighted: true)
                CareerStatRow(title: "Rush Attempts", value: "\(stats.rushingAttempts)", isHighlighted: false)
                CareerStatRow(title: "Rush Yards", value: "\(stats.rushingYards)", isHighlighted: true)
                CareerStatRow(title: "Rush TDs", value: "\(stats.rushingTouchdowns)", isHighlighted: true)
                CareerStatRow(title: "Yards/Carry", value: String(format: "%.1f", stats.yardsPerCarry), isHighlighted: false)
                CareerStatRow(title: "Receptions", value: "\(stats.receptions)", isHighlighted: false)
                CareerStatRow(title: "Receiving Yards", value: "\(stats.receivingYards)", isHighlighted: false)
                
            case "WR", "TE":
                CareerStatRow(title: "Games Played", value: "\(stats.gamesPlayed)", isHighlighted: true)
                CareerStatRow(title: "Receptions", value: "\(stats.receptions)", isHighlighted: true)
                CareerStatRow(title: "Receiving Yards", value: "\(stats.receivingYards)", isHighlighted: true)
                CareerStatRow(title: "Receiving TDs", value: "\(stats.receivingTouchdowns)", isHighlighted: true)
                CareerStatRow(title: "Yards/Reception", value: String(format: "%.1f", stats.yardsPerReception), isHighlighted: false)
                CareerStatRow(title: "Longest Reception", value: "\(stats.longestReception)", isHighlighted: false)
                CareerStatRow(title: "Dropped Passes", value: "\(stats.droppedPasses)", isHighlighted: false)
                
            case "K":
                CareerStatRow(title: "Games Played", value: "\(stats.gamesPlayed)", isHighlighted: true)
                CareerStatRow(title: "FG Attempts", value: "\(stats.fieldGoalAttempts)", isHighlighted: false)
                CareerStatRow(title: "FG Made", value: "\(stats.fieldGoalsMade)", isHighlighted: true)
                CareerStatRow(title: "FG Percentage", value: String(format: "%.1f%%", stats.fieldGoalPercentage), isHighlighted: false)
                CareerStatRow(title: "XP Made", value: "\(stats.extraPointsMade)", isHighlighted: false)
                CareerStatRow(title: "Longest FG", value: "\(stats.longestFieldGoal)", isHighlighted: false)
                CareerStatRow(title: "XP Attempts", value: "\(stats.extraPointAttempts)", isHighlighted: false)
                
            default: // Defensive positions
                CareerStatRow(title: "Games Played", value: "\(stats.gamesPlayed)", isHighlighted: true)
                CareerStatRow(title: "Tackles", value: "\(stats.tackles)", isHighlighted: true)
                CareerStatRow(title: "Assisted Tackles", value: "\(stats.assistedTackles)", isHighlighted: false)
                CareerStatRow(title: "Sacks", value: "\(stats.sacksMade)", isHighlighted: true)
                CareerStatRow(title: "Interceptions", value: "\(stats.interceptionsDefense)", isHighlighted: true)
                CareerStatRow(title: "Passes Defended", value: "\(stats.passesDefended)", isHighlighted: false)
                CareerStatRow(title: "Forced Fumbles", value: "\(stats.forcedFumbles)", isHighlighted: false)
            }
        }
    }
    
    private func getPrimaryStatName() -> String {
        switch player.position {
        case "QB":
            return "Passing Yards"
        case "RB", "FB":
            return "Rushing Yards"
        case "WR", "TE":
            return "Receiving Yards"
        case "K":
            return "Field Goals"
        default:
            return "Tackles"
        }
    }
    
    private func getPrimaryStatValue(gameStats: GamePlayerStats) -> String {
        switch player.position {
        case "QB":
            return "\(gameStats.passingYards)"
        case "RB", "FB":
            return "\(gameStats.rushingYards)"
        case "WR", "TE":
            return "\(gameStats.receivingYards)"
        case "K":
            return "\(gameStats.fieldGoalsMade)/\(gameStats.fieldGoalAttempts)"
        default:
            return "\(gameStats.tackles)"
        }
    }
    
    private func getAdditionalStats(gameStats: GamePlayerStats) -> [(String, String)] {
        switch player.position {
        case "QB":
            return [
                ("Pass Attempts", "\(gameStats.passingAttempts)"),
                ("Completions", "\(gameStats.passingCompletions)"),
                ("Pass TDs", "\(gameStats.passingTouchdowns)"),
                ("Interceptions", "\(gameStats.interceptions)")
            ]
        case "RB", "FB":
            return [
                ("Rush Attempts", "\(gameStats.rushingAttempts)"),
                ("Rush TDs", "\(gameStats.rushingTouchdowns)"),
                ("Receptions", "\(gameStats.receptions)"),
                ("Receiving Yards", "\(gameStats.receivingYards)")
            ]
        case "WR", "TE":
            return [
                ("Receptions", "\(gameStats.receptions)"),
                ("Rec TDs", "\(gameStats.receivingTouchdowns)"),
                ("Yards/Reception", gameStats.receptions > 0 ? String(format: "%.1f", Double(gameStats.receivingYards) / Double(gameStats.receptions)) : "0.0")
            ]
        case "K":
            return [
                ("FG Percentage", gameStats.fieldGoalAttempts > 0 ? String(format: "%.1f%%", Double(gameStats.fieldGoalsMade) / Double(gameStats.fieldGoalAttempts) * 100) : "0.0%"),
                ("Extra Points", "\(gameStats.extraPointsMade)/\(gameStats.extraPointAttempts)")
            ]
        default:
            return [
                ("Sacks", "\(gameStats.sacksMade)"),
                ("Interceptions", "\(gameStats.interceptionsDefense)"),
                ("Passes Defended", "\(gameStats.passesDefended)")
            ]
        }
    }
    
    // MARK: - No Stats View
    private var noStatsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Statistics Available")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("This player hasn't recorded any statistics yet this season. Stats will appear after games are simulated.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stat Table Row Component
struct StatTableRow: View {
    let title: String
    let value: String
    let isHighlighted: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(isHighlighted ? .semibold : .medium)
                .foregroundColor(isHighlighted ? .blue : .primary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(UIColor.separator))
                .opacity(0.3),
            alignment: .bottom
        )
    }
}

    // MARK: - Career Stat Row Component  
struct CareerStatRow: View {
    let title: String
    let value: String
    let isHighlighted: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(isHighlighted ? .semibold : .medium)
                .foregroundColor(isHighlighted ? .blue : .primary)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(UIColor.separator))
                .opacity(0.3),
            alignment: .bottom
        )
    }
}

// MARK: - Contract Info Item Component
struct ContractInfoItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Info Item Component
struct InfoItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Contract Negotiation View

struct ContractNegotiationView: View {
    let player: PlayerData
    let teamLogoName: String
    let offers: [ContractNegotiationManager.ContractOffer]
    let negotiationAttempts: Int
    let maxNegotiationAttempts: Int
    let onOfferSelected: (ContractNegotiationManager.ContractOffer) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var negotiationType: ContractNegotiationManager.NegotiationType {
        offers.first?.negotiationType ?? .restructure
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Player Header
                    playerHeaderSection
                    
                    // Contract Offers
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Contract Offers")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                                                HStack {
                        Text("Balance team salary cap, player value, and risk of rejection")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if negotiationAttempts > 0 {
                            Text("Attempt \(negotiationAttempts + 1)/\(maxNegotiationAttempts)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(negotiationAttempts >= maxNegotiationAttempts - 1 ? .red : .orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                        }
                        .padding(.horizontal)
                        
                        ForEach(Array(offers.enumerated()), id: \.offset) { index, offer in
                            ContractOfferCard(
                                offer: offer,
                                onSelect: {
                                    onOfferSelected(offer)
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.top, 20)
            }
            .navigationTitle(ContractNegotiationManager.getContractTypeDescription(
                negotiationType: negotiationType,
                yearsRemaining: 1 // Simplified for now
            ))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var playerHeaderSection: some View {
        VStack(spacing: 16) {
            // Team Logo
            Image(teamLogoName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
            
            // Player Info
            VStack(spacing: 8) {
                Text("\(player.firstName) \(player.lastName)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text("#\(player.number)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(player.position)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(player.overall) OVR")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.primary.opacity(0.05),
                    Color.primary.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Contract Offer Card

struct ContractOfferCard: View {
    let offer: ContractNegotiationManager.ContractOffer
    let onSelect: () -> Void
    
    private var cardColor: Color {
        switch offer.type {
        case .high: return .green
        case .base: return .blue
        case .low: return .orange
        }
    }
    
    private var offerTitle: String {
        switch offer.type {
        case .high: return "Premium Offer"
        case .base: return "Market Value"
        case .low: return "Team-Friendly"
        }
    }
    
    private var guaranteedPercentage: Int {
        guard offer.totalValue > 0 else { return 0 }
        return Int((Double(offer.guaranteedMoney) / Double(offer.totalValue)) * 100)
    }
    
    private var potentialDeadCap: Int {
        return Int(Double(offer.guaranteedMoney) * 0.6)
    }
    
    private var acceptanceText: String {
        return offer.acceptanceChance == 1.0 ? "Guaranteed" : "Risk"
    }
    
    private var acceptanceColor: Color {
        return offer.acceptanceChance == 1.0 ? .green : .orange
    }
    
    private var chanceText: String {
        return "~\(Int(offer.acceptanceChance * 100))% chance"
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(offerTitle)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(offer.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Acceptance indicator
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(acceptanceText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(acceptanceColor)
                        
                        if offer.acceptanceChance < 1.0 {
                            Text(chanceText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Contract Details
                VStack(spacing: 12) {
                    contractDetailRow(
                        title: "Annual Value",
                        value: ContractNegotiationManager.formatCurrency(offer.yearlyValue)
                    )
                    
                    contractDetailRow(
                        title: "Total Value",
                        value: ContractNegotiationManager.formatCurrency(offer.totalValue)
                    )
                    
                    // Guaranteed Money - Make this prominent
                    HStack {
                        Text("Guaranteed Money")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(ContractNegotiationManager.formatCurrency(offer.guaranteedMoney))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            
                            Text("\(guaranteedPercentage)% guaranteed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    contractDetailRow(
                        title: "Contract Length",
                        value: "\(offer.contractLength) years"
                    )
                    
                    // Show potential dead cap impact
                    if offer.guaranteedMoney > 0 {
                        HStack {
                            Text("Potential Dead Cap")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("~\(ContractNegotiationManager.formatCurrency(potentialDeadCap))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                // Select Button
                HStack {
                    Spacer()
                    Text("Select Offer")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(cardColor)
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardColor.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func contractDetailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Player Release Options View

struct PlayerReleaseOptionsView: View {
    let player: PlayerData
    let releaseOptions: [PlayerReleaseManager.ReleaseOption]
    let onReleaseSelected: (PlayerReleaseManager.ReleaseType) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Player Header
                    playerHeaderSection
                    
                    // Warning Message
                    warningSection
                    
                    // Release Options
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Release Options")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        ForEach(Array(releaseOptions.enumerated()), id: \.offset) { index, option in
                            ReleaseOptionCard(
                                option: option,
                                onSelect: {
                                    onReleaseSelected(option.type)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Release Player")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var playerHeaderSection: some View {
        VStack(spacing: 16) {
            // Player Info
            VStack(spacing: 8) {
                Text("\(player.firstName) \(player.lastName)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text("#\(player.number)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(player.position)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(player.overall) OVR")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.red.opacity(0.1),
                    Color.red.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    private var warningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("Financial Impact Warning")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Releasing a player is permanent and cannot be undone.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !releaseOptions.isEmpty {
                    let totalDeadMoney = releaseOptions.map { $0.deadMoneyCalculation.totalDeadMoney }.max() ?? 0
                    let maxCapSavings = releaseOptions.map { $0.deadMoneyCalculation.capSavings }.max() ?? 0
                    
                    if totalDeadMoney > 0 {
                        HStack {
                            Text("⚠️ Dead Money Range:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            
                            Spacer()
                            
                            Text("Up to $\(formatCurrency(totalDeadMoney))")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if maxCapSavings > 0 {
                        HStack {
                            Text("💰 Max Cap Savings:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                            
                            Spacer()
                            
                            Text("$\(formatCurrency(maxCapSavings))")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text("Choose the option below that best fits your team's cap situation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    private func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}

// MARK: - Release Option Card

struct ReleaseOptionCard: View {
    let option: PlayerReleaseManager.ReleaseOption
    let onSelect: () -> Void
    
    private var cardColor: Color {
        return option.isRecommended ? .green : .red
    }
    
    private var recommendationText: String {
        return option.isRecommended ? "Recommended" : "Not Recommended"
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(option.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Recommendation indicator
                    Text(recommendationText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(cardColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(cardColor.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                // Financial Details
                VStack(spacing: 12) {
                    financialDetailRow(
                        title: "Dead Money",
                        value: formatCurrency(option.deadMoneyCalculation.totalDeadMoney),
                        color: .red
                    )
                    
                    if option.deadMoneyCalculation.isPostJune1 {
                        financialDetailRow(
                            title: "This Year Hit",
                            value: formatCurrency(option.deadMoneyCalculation.currentYearHit),
                            color: .orange
                        )
                        
                        financialDetailRow(
                            title: "Next Year Hit",
                            value: formatCurrency(option.deadMoneyCalculation.nextYearHit),
                            color: .orange
                        )
                    }
                    
                    financialDetailRow(
                        title: "Cap Savings",
                        value: formatCurrency(option.deadMoneyCalculation.capSavings),
                        color: option.deadMoneyCalculation.capSavings > 0 ? .green : .red
                    )
                }
                
                // Select Button
                HStack {
                    Spacer()
                    Text("Select Option")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(cardColor)
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardColor.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func financialDetailRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
    
    private func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Preview
struct PlayerDetailView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerDetailView(
            player: PlayerData(
                firstName: "Caleb",
                lastName: "Williams",
                position: "QB",
                number: 18,
                overall: 88,
                age: 22
            ),
            teamLogoName: "Chicago",
            leagueId: UUID(),
            isEditable: true,
            leagueManager: LeagueManager()
        )
    }
} 