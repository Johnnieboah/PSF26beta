import SwiftUI
import Combine

struct FreeAgentView: View {
    @StateObject private var masterDataLoader = MasterDataLoader.shared
    @State private var selectedPosition: String = "Overview"
    @State private var refreshTrigger = UUID()
    @State private var showingSignConfirmation = false
    @State private var selectedPlayer: MasterPlayer?
    @Environment(\.dismiss) private var dismiss
    
    // New contract negotiation states
    @State private var showingContractOffers = false
    @State private var contractOffers: [FreeAgentSigningManager.FreeAgentOffer] = []
    @State private var showingSigningResult = false
    @State private var signingResultTitle = ""
    @State private var signingResultMessage = ""
    
    // Negotiation tracking (player ID -> attempt count)
    @State private var negotiationAttempts: [String: Int] = [:]
    
    @Binding var userTeam: LeagueTeam
    let leagueManager: LeagueManager
    
    private var positions: [String] {
        let basePositions = ["Overview"]
        let maddenPositionOrder = ["QB", "RB", "FB", "WR", "TE", "LT", "LG", "C", "RG", "RT", "MLB", "ROLB", "LOLB", "EDGE", "DE", "DT", "CB", "SS", "FS", "K", "P"]
        
        // Get free agents from the league's Free Agent team
        let freeAgents = getLeagueFreeAgents()
        
        if !freeAgents.isEmpty {
            let realPositions = Set(freeAgents.map { $0.position })
            let orderedPositions = maddenPositionOrder.filter { realPositions.contains($0) }
            return basePositions + orderedPositions
        } else {
            return basePositions + maddenPositionOrder
        }
    }
    
    private var filteredPlayers: [MasterPlayer] {
        // Get free agents from the league's Free Agent team
        let freeAgents = getLeagueFreeAgents()
        
        if selectedPosition == "Overview" {
            return Array(freeAgents.sorted { 
                if $0.overall != $1.overall {
                    return $0.overall > $1.overall
                }
                return $0.fullName < $1.fullName
            }.prefix(5)) // Top 5 free agents for overview
        } else {
            return freeAgents.filter { $0.position == selectedPosition }.sorted {
                if $0.overall != $1.overall {
                    return $0.overall > $1.overall
                }
                return $0.fullName < $1.fullName
            }
        }
    }
    
    // Helper method to get free agents from the league's Free Agent team
    private func getLeagueFreeAgents() -> [MasterPlayer] {
        // Don't refresh during view updates to avoid infinite loops
        // The data will be refreshed via onAppear and notification handlers
        
        // Get from league's Free Agent team
        if let freeAgentTeam = leagueManager.allTeams.first(where: { $0.logoName == "Free Agent" }) {
            print("📦 Found league Free Agent team with \(freeAgentTeam.players.count) players")
            
            // Convert PlayerData to MasterPlayer using the conversion method
            let convertedPlayers = freeAgentTeam.players.compactMap { convertPlayerDataToMasterPlayer($0) }
            if !convertedPlayers.isEmpty {
                print("📦 Using \(convertedPlayers.count) players from league Free Agent team")
                return convertedPlayers
            }
        }
        
        // Fallback to master data if league Free Agent team is empty or doesn't exist
        print("📦 Using master data for free agents")
        return masterDataLoader.getPlayers(for: "Free Agent")
    }
    
    // Async method to refresh free agent data outside of view updates
    private func refreshFreeAgentDataAsync() async {
        guard let leagueId = leagueManager.currentLeagueId else {
            print("📦 No league ID available for Free Agent refresh")
            return
        }
        
        do {
            // Load Free Agent players from file
            let freeAgentPlayers = try PlayerDataManager.shared.loadPlayersFromFile(
                leagueId: leagueId,
                teamLogoName: "Free Agent"
            )
            
            // Convert to PlayerData
            let playerData = freeAgentPlayers.map { $0.toPlayerData() }
            
            // Update the league manager's Free Agent team on main thread
            await MainActor.run {
                if let index = leagueManager.allTeams.firstIndex(where: { $0.logoName == "Free Agent" }) {
                    leagueManager.allTeams[index].players = playerData
                    print("📦 Updated league Free Agent team with \(playerData.count) players from file")
                } else {
                    print("📦 Free Agent team not found in league, this shouldn't happen")
                }
            }
            
        } catch {
            print("📦 Failed to load Free Agent team from file: \(error)")
        }
    }
    
    // Method to refresh the Free Agent team from file data (deprecated - use async version)
    private func refreshFreeAgentTeam() {
        // This method is no longer used to prevent infinite loops
        // Use refreshFreeAgentDataAsync() instead
        print("📦 refreshFreeAgentTeam() called but skipped to prevent loops")
    }
    
    // Helper method to convert PlayerData to MasterPlayer for UI compatibility
    private func convertPlayerDataToMasterPlayer(_ player: PlayerData) -> MasterPlayer? {
        // Create a JSON representation and decode it as MasterPlayer
        let playerDict: [String: Any] = [
            "firstName": player.firstName,
            "lastName": player.lastName,
            "position": player.position,
            "team": "Free Agent",
            "college": "",
            "age": String(player.age),
            "overall": String(player.overall),
            "height": "72",
            "weight": "200",
            "handedness": "R",
            "jerseyNum": String(player.number),
            "yearsPro": "1",
            "history": [],
            "attributes": [
                "speed": 50,
                "agility": 50,
                "awareness": 50,
                "strength": 50,
                "stamina": 50,
                "injury": 50,
                "carrying": 50,
                "trucking": 50,
                "catching": 50,
                "breakTackle": 50,
                "jukeMove": 50,
                "spinMove": 50,
                "stiffArm": 50,
                "acceleration": 50,
                "changeOfDirection": 50,
                "throwPower": 50,
                "throwAccuracyShort": 50,
                "throwAccuracyMid": 50,
                "throwAccuracyDeep": 50,
                "throwOnTheRun": 50,
                "throwUnderPressure": 50,
                "playAction": 50,
                "tackle": 50,
                "blockShedding": 50,
                "zoneCoverage": 50,
                "manCoverage": 50,
                "pursuit": 50,
                "finesseMoves": 50,
                "powerMoves": 50,
                "press": 50,
                "jumping": 50,
                "passBlock": 50,
                "runBlock": 50,
                "impactBlocking": 50,
                "kickPower": 50,
                "kickAccuracy": 50,
                "release": 50,
                "catchInTraffic": 50,
                "spectacularCatch": 50,
                "shortRouteRunning": 50,
                "mediumRouteRunning": 50,
                "deepRouteRunning": 50,
                "playRecognition": 50,
                "toughness": 50,
                "hitPower": 50,
                "bCVision": 50,
                "passBlockPower": 50,
                "runBlockPower": 50,
                "passBlockFinesse": 50,
                "runBlockFinesse": 50
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: playerDict)
            let decoder = JSONDecoder()
            return try decoder.decode(MasterPlayer.self, from: jsonData)
        } catch {
            print("📦 Failed to convert PlayerData to MasterPlayer: \(error)")
            return nil
        }
    }
    
    private var weakestPosition: (position: String, rating: Int)? {
        let positionRatings = userTeam.players.reduce(into: [String: Int]()) { dict, player in
            let position = player.position
            let overall = Int(player.overall)
            dict[position] = min(dict[position, default: 99], overall)
        }
        
        if let weakest = positionRatings.min(by: { $0.value < $1.value }) {
            return (position: weakest.key, rating: weakest.value)
        }
        return nil
    }
    
    // Enhanced salary information using actual team data
    private var teamSalaryInfo: (capSpace: Double, totalCap: Double, capSpent: Double, deadCap: Double) {
        let totalCap = Double(NFLCapData.salaryCap) / 1_000_000 // Convert to millions
        
        // Use actual team salary spending instead of static data
        let actualCapSpent = Double(userTeam.totalSalarySpending) / 1_000_000
        let actualCapSpace = Double(userTeam.capSpace) / 1_000_000
        
        // Estimate dead cap (simplified calculation - could be enhanced with real data)
        let deadCap = actualCapSpent * 0.08 // Assume ~8% of cap spending is dead money
        
        return (capSpace: actualCapSpace, totalCap: totalCap, capSpent: actualCapSpent, deadCap: deadCap)
    }
    
    private var capSpace: Double {
        return teamSalaryInfo.capSpace
    }
    
    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 0) {
                // Free Agent Content
                VStack(spacing: 20) {
                    freeAgentContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
            .id(refreshTrigger)
        .scrollClipDisabled()
        .scrollTargetBehavior(.viewAligned)
        .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Free Agents")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                refreshTrigger = UUID()
            }
            .onAppear {
                // Refresh free agent data when view appears
                Task {
                    await refreshFreeAgentDataAsync()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PlayerReleased"))) { notification in
                print("📦 FreeAgentView: Player released - refreshing free agent list")
                // Refresh the free agent data asynchronously
                Task {
                    await refreshFreeAgentDataAsync()
                    // Trigger UI refresh
                    refreshTrigger = UUID()
                }
            }
        }
        .alert(signingResultTitle, isPresented: $showingSigningResult) {
            Button("OK") {
                showingSigningResult = false
                signingResultTitle = ""
                signingResultMessage = ""
                // Refresh the view to update free agent list
                refreshTrigger = UUID()
            }
        } message: {
            Text(signingResultMessage)
        }
        .sheet(isPresented: $showingContractOffers) {
            if let selectedPlayer = selectedPlayer {
                FreeAgentContractOffersView(
                    player: selectedPlayer,
                    offers: contractOffers,
                    userTeam: userTeam,
                    leagueManager: leagueManager,
                    onOfferSelected: { offer in
                        showingContractOffers = false
                        handleContractOfferResponse(offer: offer, player: selectedPlayer)
                    }
                )
            }
        }
    }
    
    private var freeAgentContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            freeAgentContentHeader
            
            if selectedPosition == "Overview" {
                freeAgentOverview
            } else {
                playerList
            }
        }
        .id(refreshTrigger)
    }
    
    private var freeAgentHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.fill.badge.plus")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Free Agents")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if masterDataLoader.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Available Players")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("\(masterDataLoader.getPlayers(for: "Free Agent").count) Total")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: ColorPalettes.leagueSchedule,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
    
    private var freeAgentContentHeader: some View {
        HStack {
            Image(systemName: selectedPosition == "Overview" ? "chart.bar.fill" : "person.3.fill")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text(selectedPosition == "Overview" ? "Free Agents Overview" : "Available Players")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Position Filter Dropdown
            positionFilterDropdown
            
            Spacer()
            
            if selectedPosition != "Overview" {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(filteredPlayers.count) Players")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Position Filter Dropdown
    private var positionFilterDropdown: some View {
        Menu {
            // Overview section
            Section("Free Agent Analysis") {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedPosition = "Overview"
                    }
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                        Text("Overview")
                        Spacer()
                        if selectedPosition == "Overview" {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // Position sections
            Section("Offense") {
                ForEach(["QB", "RB", "FB", "WR", "TE", "LT", "LG", "C", "RG", "RT"], id: \.self) { position in
                    positionMenuButton(for: position)
                }
            }
            
            Section("Defense") {
                ForEach(["MLB", "ROLB", "LOLB", "EDGE", "DE", "DT", "CB", "SS", "FS"], id: \.self) { position in
                    positionMenuButton(for: position)
                }
            }
            
            Section("Special Teams") {
                ForEach(["K", "P"], id: \.self) { position in
                    positionMenuButton(for: position)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedPosition)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .sensoryFeedback(.selection, trigger: selectedPosition)
        .accessibilityLabel("Position Filter")
        .accessibilityValue(selectedPosition)
    }
    
    private func positionMenuButton(for position: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedPosition = position
            }
        } label: {
            HStack {
                Text(position)
                Spacer()
                if selectedPosition == position {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var freeAgentOverview: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Team Salary Information
            VStack(alignment: .leading, spacing: 16) {
                Text("Team Salary Cap Information")
                    .font(.title3)
                    .fontWeight(.bold)
                
                // Salary Cap Grid
                let salaryInfo = teamSalaryInfo
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    SalaryInfoCard(
                        title: "Total Cap",
                        value: "$\(String(format: "%.1f", salaryInfo.totalCap))M",
                        color: .blue
                    )
                    
                    SalaryInfoCard(
                        title: "Cap Spent",
                        value: "$\(String(format: "%.1f", salaryInfo.capSpent))M",
                        color: .orange
                    )
                    
                    SalaryInfoCard(
                        title: "Cap Space",
                        value: "$\(String(format: "%.1f", salaryInfo.capSpace))M",
                        color: salaryInfo.capSpace > 0 ? .green : .red
                    )
                    
                    SalaryInfoCard(
                        title: "Dead Cap",
                        value: "$\(String(format: "%.1f", salaryInfo.deadCap))M",
                        color: .red
                    )
                }
                
                // Roster Count and Cap Status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Roster Count")
                            .font(.headline)
                        HStack(spacing: 4) {
                        Text("\(userTeam.players.count)/\(leagueManager.isInTrainingCamp ? 60 : 53)")
                            .font(.title2)
                            .fontWeight(.bold)
                                .foregroundColor(
                                    userTeam.rosterStatus(isTrainingCamp: leagueManager.isInTrainingCamp) == .overLimit ? .red : 
                                    userTeam.rosterStatus(isTrainingCamp: leagueManager.isInTrainingCamp) == .nearFull ? .orange : 
                                    userTeam.rosterStatus(isTrainingCamp: leagueManager.isInTrainingCamp) == .full ? .green :
                                    .primary
                                )
                            
                            // Roster status indicator
                            if userTeam.rosterStatus(isTrainingCamp: leagueManager.isInTrainingCamp) == .overLimit {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            } else if userTeam.rosterStatus(isTrainingCamp: leagueManager.isInTrainingCamp) == .nearFull {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            } else if userTeam.rosterStatus(isTrainingCamp: leagueManager.isInTrainingCamp) == .full {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                        
                        // Roster status text
                        if userTeam.rosterStatus(isTrainingCamp: leagueManager.isInTrainingCamp) == .overLimit {
                            Text("OVER LIMIT")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        } else if userTeam.rosterStatus(isTrainingCamp: leagueManager.isInTrainingCamp) == .full {
                            Text("ROSTER COMPLETE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        } else if userTeam.rosterStatus(isTrainingCamp: leagueManager.isInTrainingCamp) == .nearFull {
                            Text("\(userTeam.availableRosterSpots(isTrainingCamp: leagueManager.isInTrainingCamp)) spots left")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("\(userTeam.availableRosterSpots(isTrainingCamp: leagueManager.isInTrainingCamp)) spots left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Cap Status Indicator
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Cap Status")
                            .font(.headline)
                        Text(NFLCapData.isOverCap(for: userTeam.logoName) ? "Over Cap" : "Under Cap")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(NFLCapData.isOverCap(for: userTeam.logoName) ? .red : .green)
                    }
                }
                
                // Weakest Position
                if let weakest = weakestPosition {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weakest Position")
                            .font(.headline)
                        HStack {
                            Text(weakest.position)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("(\(weakest.rating) OVR)")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            
            // Top Free Agents
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Available Free Agents")
                    .font(.title3)
                    .fontWeight(.bold)
                
                LazyVStack(spacing: 12) {
                    ForEach(filteredPlayers) { player in
                        FreeAgentPlayerRow(
                            player: player,
                            userTeam: userTeam,
                            leagueManager: leagueManager,
                            showingContractOffers: $showingContractOffers,
                            selectedPlayer: $selectedPlayer,
                            contractOffers: $contractOffers,
                            negotiationAttempts: $negotiationAttempts
                        )
                    }
                }
            }
        }
    }
    
    private var playerList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredPlayers) { player in
                FreeAgentPlayerRow(
                    player: player,
                    userTeam: userTeam,
                    leagueManager: leagueManager,
                    showingContractOffers: $showingContractOffers,
                    selectedPlayer: $selectedPlayer,
                    contractOffers: $contractOffers,
                    negotiationAttempts: $negotiationAttempts
                ) // Fixed compilation issue
            }
        }
    }
    
    // MARK: - Negotiation Tracking
    
    private func getPlayerNegotiationId(player: MasterPlayer) -> String {
        return "\(player.firstName)_\(player.lastName)_\(player.jerseyNum)"
    }
    
    private func getAttemptCount(for player: MasterPlayer) -> Int {
        let playerId = getPlayerNegotiationId(player: player)
        return negotiationAttempts[playerId] ?? 0
    }
    
    private func incrementAttemptCount(for player: MasterPlayer) {
        let playerId = getPlayerNegotiationId(player: player)
        negotiationAttempts[playerId] = getAttemptCount(for: player) + 1
    }
    
    private func canNegotiateWith(player: MasterPlayer) -> Bool {
        return getAttemptCount(for: player) < 3
    }
    
    private func resetNegotiationAttempts() {
        negotiationAttempts.removeAll()
        print("🔄 Negotiation attempts reset for new week")
    }
    
    // MARK: - Contract Offer Handling
    
    private func handleContractOfferResponse(offer: FreeAgentSigningManager.FreeAgentOffer, player: MasterPlayer) {
        // Convert MasterPlayer to PlayerData
        let playerData = PlayerData(
            firstName: player.firstName,
            lastName: player.lastName,
            position: player.position,
            number: Int(player.jerseyNum) ?? 1,
            overall: Int(player.overall) ?? 75,
            age: Int(player.age) ?? 25
        )
        
        // Process the signing
        let result = FreeAgentSigningManager.processFreAgentSigning(
            offer: offer,
            player: playerData,
            signingTeam: userTeam
        )
        
        if result.accepted {
            // Player accepted - add them to the team
            Task {
                let success = await addPlayerToTeam(player: playerData, contract: result.newContract!)
                
                await MainActor.run {
                    if success {
                        signingResultTitle = "✅ Signing Successful!"
                        signingResultMessage = "\(player.firstName) \(player.lastName) has signed with \(userTeam.name)!\n\n\"\(result.playerResponse)\""
                        
                        // Force refresh the free agent list and notify other views
                        Task {
                            await refreshFreeAgentDataAsync()
                            refreshTrigger = UUID()
                            
                            // Notify other views that player data has changed
                            NotificationCenter.default.post(
                                name: .playerDataDidChange,
                                object: nil,
                                userInfo: ["teamLogoName": userTeam.logoName]
                            )
                        }
                    } else {
                        signingResultTitle = "❌ Signing Failed"
                        signingResultMessage = "There was an error processing the signing. Please try again."
                    }
                    showingSigningResult = true
                }
            }
        } else {
            // Player rejected - increment attempt count
            incrementAttemptCount(for: player)
            
            let attemptCount = getAttemptCount(for: player)
            let remainingAttempts = 3 - attemptCount
            
            if remainingAttempts > 0 {
                signingResultTitle = "❌ Offer Declined"
                signingResultMessage = "\(player.firstName) \(player.lastName) declined the offer.\n\n\"\(result.playerResponse)\"\n\nYou have \(remainingAttempts) attempt(s) remaining."
            } else {
                signingResultTitle = "❌ Negotiations Ended"
                signingResultMessage = "\(player.firstName) \(player.lastName) has declined all offers and will not negotiate further until the week advances.\n\n\"\(result.playerResponse)\""
            }
            
            showingSigningResult = true
        }
    }
    
    private func addPlayerToTeam(player: PlayerData, contract: PlayerContract) async -> Bool {
        guard let leagueId = leagueManager.currentLeagueId else {
            print("❌ No league ID available for player signing")
            return false
        }
        
        print("✍️ Adding \(player.fullName) to \(userTeam.name)")
        
        do {
            // Load current team roster
            var teamPlayers = try PlayerDataManager.shared.loadPlayersFromFile(
                leagueId: leagueId,
                teamLogoName: userTeam.logoName
            )
            
            print("📋 Current roster size: \(teamPlayers.count)")
            
            // ✅ ENFORCE ROSTER LIMIT (60 for training camp, 53 for regular season)
            let maxRosterSize = leagueManager.isInTrainingCamp ? 60 : 53
            let rosterType = leagueManager.isInTrainingCamp ? "training camp" : "regular season"
            
            if teamPlayers.count >= maxRosterSize {
                print("❌ Cannot sign \(player.fullName) - roster is at maximum capacity (\(maxRosterSize)/\(maxRosterSize))")
                await MainActor.run {
                    signingResultTitle = "Roster Full"
                    signingResultMessage = "Cannot sign \(player.fullName). Your roster is at the maximum capacity of \(maxRosterSize) players for \(rosterType). You must release a player before signing new ones."
                    showingSigningResult = true
                }
                return false
            }
            
            // Get the MasterPlayer for attributes
            guard let masterPlayer = selectedPlayer else {
                print("❌ No selected player available for signing")
                return false
            }
            
            let attrs = masterPlayer.attributes
            
            // Generate realistic attributes based on the player's overall rating and position
            // This preserves the original overall rating instead of defaulting everything to 50
            let baseOverall = player.overall
            let attributeVariation = 10 // +/- variation from base
            
            func generateAttribute(base: Int, importance: Double = 1.0) -> Int {
                let adjustedBase = Int(Double(base) * importance)
                let variation = Int.random(in: -attributeVariation...attributeVariation)
                return max(40, min(99, adjustedBase + variation))
            }
            
            // Create EditablePlayerData with contract
            let newPlayer = EditablePlayerData(
                id: player.id,
                firstName: player.firstName,
                lastName: player.lastName,
                position: player.position,
                number: player.number,
                age: player.age,
                college: masterPlayer.college,
                height: masterPlayer.height,
                weight: masterPlayer.weight,
                yearsPro: Int(masterPlayer.yearsPro) ?? max(0, player.age - 22),
                teamLogoName: userTeam.logoName,
                leagueId: leagueId,
                isEdited: false,
                lastModified: Date(),
                // Generate realistic attributes based on overall rating and position
                speed: attrs.speed ?? generateAttribute(base: baseOverall, importance: player.position == "RB" || player.position == "WR" ? 1.2 : 0.9),
                agility: attrs.agility ?? generateAttribute(base: baseOverall, importance: player.position == "RB" || player.position == "WR" ? 1.1 : 0.9),
                awareness: attrs.awareness ?? generateAttribute(base: baseOverall, importance: player.position == "QB" ? 1.3 : 1.0),
                strength: attrs.strength ?? generateAttribute(base: baseOverall, importance: player.position.contains("T") || player.position.contains("G") || player.position == "C" ? 1.2 : 0.9),
                stamina: attrs.stamina ?? generateAttribute(base: baseOverall),
                injury: attrs.injury ?? generateAttribute(base: baseOverall),
                carrying: attrs.carrying ?? generateAttribute(base: baseOverall, importance: player.position == "RB" ? 1.2 : 0.8),
                trucking: attrs.trucking ?? generateAttribute(base: baseOverall, importance: player.position == "RB" ? 1.1 : 0.8),
                catching: attrs.catching ?? generateAttribute(base: baseOverall, importance: player.position == "WR" || player.position == "TE" ? 1.3 : 0.7),
                breakTackle: attrs.breakTackle ?? generateAttribute(base: baseOverall, importance: player.position == "RB" ? 1.2 : 0.8),
                jukeMove: attrs.jukeMove ?? generateAttribute(base: baseOverall, importance: player.position == "RB" ? 1.1 : 0.8),
                spinMove: attrs.spinMove ?? generateAttribute(base: baseOverall, importance: player.position == "RB" ? 1.1 : 0.8),
                stiffArm: attrs.stiffArm ?? generateAttribute(base: baseOverall, importance: player.position == "RB" ? 1.1 : 0.8),
                acceleration: attrs.acceleration ?? generateAttribute(base: baseOverall, importance: player.position == "RB" || player.position == "WR" ? 1.2 : 0.9),
                changeOfDirection: attrs.changeOfDirection ?? generateAttribute(base: baseOverall, importance: player.position == "RB" || player.position == "WR" ? 1.1 : 0.9),
                throwPower: attrs.throwPower ?? generateAttribute(base: baseOverall, importance: player.position == "QB" ? 1.3 : 0.5),
                throwAccuracyShort: attrs.throwAccuracyShort ?? generateAttribute(base: baseOverall, importance: player.position == "QB" ? 1.2 : 0.5),
                throwAccuracyMid: attrs.throwAccuracyMid ?? generateAttribute(base: baseOverall, importance: player.position == "QB" ? 1.2 : 0.5),
                throwAccuracyDeep: attrs.throwAccuracyDeep ?? generateAttribute(base: baseOverall, importance: player.position == "QB" ? 1.1 : 0.5),
                throwOnTheRun: attrs.throwOnTheRun ?? generateAttribute(base: baseOverall, importance: player.position == "QB" ? 1.1 : 0.5),
                throwUnderPressure: attrs.throwUnderPressure ?? generateAttribute(base: baseOverall, importance: player.position == "QB" ? 1.2 : 0.5),
                playAction: attrs.playAction ?? generateAttribute(base: baseOverall, importance: player.position == "QB" ? 1.0 : 0.5),
                tackle: attrs.tackle ?? generateAttribute(base: baseOverall, importance: player.position.contains("LB") || player.position == "SS" ? 1.2 : player.position.contains("D") ? 1.0 : 0.6),
                blockShedding: attrs.blockShedding ?? generateAttribute(base: baseOverall, importance: player.position == "DE" || player.position == "DT" ? 1.2 : 0.8),
                zoneCoverage: attrs.zoneCoverage ?? generateAttribute(base: baseOverall, importance: player.position == "CB" || player.position == "FS" ? 1.3 : 0.7),
                manCoverage: attrs.manCoverage ?? generateAttribute(base: baseOverall, importance: player.position == "CB" ? 1.3 : 0.7),
                pursuit: attrs.pursuit ?? generateAttribute(base: baseOverall, importance: player.position.contains("LB") ? 1.1 : 0.9),
                finesseMoves: attrs.finesseMoves ?? generateAttribute(base: baseOverall, importance: player.position == "DE" || player.position == "EDGE" ? 1.2 : 0.8),
                powerMoves: attrs.powerMoves ?? generateAttribute(base: baseOverall, importance: player.position == "DT" ? 1.2 : 0.8),
                press: attrs.press ?? generateAttribute(base: baseOverall, importance: player.position == "CB" ? 1.1 : 0.8),
                jumping: attrs.jumping ?? generateAttribute(base: baseOverall, importance: player.position == "WR" || player.position == "CB" ? 1.1 : 0.9),
                playRecognition: attrs.playRecognition ?? generateAttribute(base: baseOverall, importance: player.position.contains("LB") || player.position == "QB" ? 1.2 : 1.0),
                hitPower: attrs.hitPower ?? generateAttribute(base: baseOverall, importance: player.position == "SS" || player.position.contains("LB") ? 1.2 : 0.8),
                toughness: attrs.toughness ?? generateAttribute(base: baseOverall),
                passBlock: attrs.passBlock ?? generateAttribute(base: baseOverall, importance: player.position.contains("T") || player.position.contains("G") || player.position == "C" ? 1.3 : 0.6),
                runBlock: attrs.runBlock ?? generateAttribute(base: baseOverall, importance: player.position.contains("T") || player.position.contains("G") || player.position == "C" ? 1.2 : 0.6),
                impactBlocking: attrs.impactBlocking ?? generateAttribute(base: baseOverall, importance: player.position.contains("T") || player.position.contains("G") || player.position == "C" ? 1.1 : 0.6),
                passBlockPower: attrs.passBlockPower ?? generateAttribute(base: baseOverall, importance: player.position.contains("T") || player.position.contains("G") || player.position == "C" ? 1.2 : 0.6),
                runBlockPower: attrs.runBlockPower ?? generateAttribute(base: baseOverall, importance: player.position.contains("T") || player.position.contains("G") || player.position == "C" ? 1.2 : 0.6),
                passBlockFinesse: attrs.passBlockFinesse ?? generateAttribute(base: baseOverall, importance: player.position.contains("T") || player.position.contains("G") || player.position == "C" ? 1.1 : 0.6),
                runBlockFinesse: attrs.runBlockFinesse ?? generateAttribute(base: baseOverall, importance: player.position.contains("T") || player.position.contains("G") || player.position == "C" ? 1.1 : 0.6),
                release: attrs.release ?? generateAttribute(base: baseOverall, importance: player.position == "WR" || player.position == "TE" ? 1.2 : 0.7),
                catchInTraffic: attrs.catchInTraffic ?? generateAttribute(base: baseOverall, importance: player.position == "WR" || player.position == "TE" ? 1.2 : 0.7),
                spectacularCatch: attrs.spectacularCatch ?? generateAttribute(base: baseOverall, importance: player.position == "WR" ? 1.1 : 0.7),
                shortRouteRunning: attrs.shortRouteRunning ?? generateAttribute(base: baseOverall, importance: player.position == "WR" || player.position == "TE" ? 1.2 : 0.7),
                mediumRouteRunning: attrs.mediumRouteRunning ?? generateAttribute(base: baseOverall, importance: player.position == "WR" || player.position == "TE" ? 1.2 : 0.7),
                deepRouteRunning: attrs.deepRouteRunning ?? generateAttribute(base: baseOverall, importance: player.position == "WR" ? 1.2 : 0.7),
                kickPower: attrs.kickPower ?? generateAttribute(base: baseOverall, importance: player.position == "K" || player.position == "P" ? 1.3 : 0.5),
                kickAccuracy: attrs.kickAccuracy ?? generateAttribute(base: baseOverall, importance: player.position == "K" ? 1.3 : 0.5),
                bCVision: attrs.bCVision ?? generateAttribute(base: baseOverall, importance: player.position == "RB" ? 1.2 : 0.8),
                // Contract information
                salary: contract.currentYearSalary,
                contract: contract,
                isRookiePlayer: false,
                draftPickNumber: nil,
                draftYearValue: nil,
                contractYearsLeft: contract.yearsRemaining,
                // Use the player's overall rating
                overall: player.overall
            )
            
            // Add to team roster
            teamPlayers.append(newPlayer)
            print("📋 New roster size: \(teamPlayers.count)")
            
            // Save updated roster (background, atomic)
            _ = try await PlayerDataManager.shared.writePlayersToDisk(
                players: teamPlayers,
                leagueId: leagueId,
                teamLogoName: userTeam.logoName
            )
            
            // Remove from free agency
            let removalSuccess = await removePlayerFromFreeAgency(player: player, leagueId: leagueId)
            
            if removalSuccess {
                print("✅ \(player.fullName) successfully added to \(userTeam.name)")
                
                // Update the user team's players list
                await updateUserTeamRoster(with: newPlayer)
                
                return true
            } else {
                print("⚠️ Player added to team but not removed from free agency")
                return true // Still consider it a success
            }
            
        } catch {
            print("❌ Failed to add player to team: \(error)")
            return false
        }
    }
    
    private func saveUpdatedTeamRoster(players: [EditablePlayerData], leagueId: UUID, teamLogoName: String) async throws {
        let playersDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Players")
        
        let fileURL = playersDirectory.appendingPathComponent("league_\(leagueId.uuidString)_\(teamLogoName).json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(players)
        try data.write(to: fileURL)
        
        print("📝 Updated \(teamLogoName) roster saved with \(players.count) players")
    }
    
    private func removePlayerFromFreeAgency(player: PlayerData, leagueId: UUID) async -> Bool {
        do {
            var freeAgents = try PlayerDataManager.shared.loadPlayersFromFile(
                leagueId: leagueId,
                teamLogoName: "Free Agent"
            )
            
            print("📋 Free agents before removal: \(freeAgents.count)")
            let initialCount = freeAgents.count
            
            freeAgents.removeAll {
                $0.firstName == player.firstName &&
                $0.lastName == player.lastName &&
                $0.number == player.number
            }
            
            print("📋 Free agents after removal: \(freeAgents.count)")
            
                if freeAgents.count < initialCount {
                    _ = try await PlayerDataManager.shared.writePlayersToDisk(
                        players: freeAgents,
                        leagueId: leagueId,
                        teamLogoName: "Free Agent"
                    )
                print("📝 Removed \(player.fullName) from free agency")
                return true
            } else {
                print("⚠️ Player \(player.fullName) not found in free agency")
                return false
            }
            
        } catch {
            print("⚠️ Failed to remove player from free agency: \(error)")
            return false
        }
    }
    
    private func updateUserTeamRoster(with newPlayer: EditablePlayerData) async {
        await MainActor.run {
            guard let leagueId = leagueManager.currentLeagueId else {
                print("❌ No league ID available for team update")
                return
            }
            
            print("🔄 Starting team roster update for \(userTeam.logoName)")
            print("   Current roster size: \(userTeam.players.count)")
            
            // Clear the cache for this team to ensure fresh data is loaded
            PlayerDataManager.shared.clearCacheForTeam(teamLogoName: userTeam.logoName, leagueId: leagueId)
            print("   🧹 Cleared cache for \(userTeam.logoName)")
            
            // Instead of manually converting and adding, reload the team data from files
            // This ensures we get the most up-to-date data including contract information
            do {
                // Reload the team's players from file (this includes the newly signed player with contract)
                let updatedPlayers = try PlayerDataManager.shared.loadPlayersFromFile(
                    leagueId: leagueId,
                    teamLogoName: userTeam.logoName
                )
                
                print("   Loaded \(updatedPlayers.count) players from file")
                
                // Convert to PlayerData for the in-memory team representation
                let playerDataArray = updatedPlayers.map { $0.toPlayerData() }
                
                print("   Converted to \(playerDataArray.count) PlayerData objects")
                
                // Find the newly signed player to verify it's included
                let newlySignedPlayer = playerDataArray.first { player in
                    player.firstName == newPlayer.firstName && 
                    player.lastName == newPlayer.lastName &&
                    player.number == newPlayer.number
                }
                
                if let signedPlayer = newlySignedPlayer {
                    print("   ✅ Found newly signed player: \(signedPlayer.fullName)")
                    print("   💰 Player salary: $\(signedPlayer.actualSalary ?? 0) (estimated: $\(signedPlayer.estimatedSalary))")
                } else {
                    print("   ❌ Newly signed player not found in roster!")
                }
                
                // Update the userTeam's players array
                userTeam.players = playerDataArray
                
                // Also update the team in leagueManager.allTeams
                if let teamIndex = leagueManager.allTeams.firstIndex(where: { $0.logoName == userTeam.logoName }) {
                    leagueManager.allTeams[teamIndex].players = playerDataArray
                    print("   📋 Updated leagueManager team roster with \(playerDataArray.count) players")
                    
                    // Trigger updates on the leagueManager
                    leagueManager.objectWillChange.send()
                } else {
                    print("   ❌ Could not find team in leagueManager.allTeams")
                }
                
                print("   📋 Updated userTeam roster: \(userTeam.players.count) players")
                
                // Calculate and log salary cap info
                let totalSpending = userTeam.totalSalarySpending
                let capSpace = userTeam.capSpace
                print("   💰 Total salary spending: $\(totalSpending)")
                print("   💰 Salary cap space: $\(capSpace)")
                
                // Force UI refresh by updating the refresh trigger
                refreshTrigger = UUID()
                print("   🔄 UI refresh triggered")
                
                // Notify other views that player data has changed
                NotificationCenter.default.post(
                    name: .playerDataDidChange,
                    object: nil,
                    userInfo: ["teamLogoName": userTeam.logoName]
                )
                print("   📢 Posted playerDataDidChange notification")
                
            } catch {
                print("❌ Failed to reload team data after signing: \(error)")
                
                // Fallback: Add the player manually (without contract info)
            let playerData = PlayerData(
                firstName: newPlayer.firstName,
                lastName: newPlayer.lastName,
                position: newPlayer.position,
                number: newPlayer.number,
                overall: newPlayer.overall,
                    age: newPlayer.age,
                    actualSalary: newPlayer.salary > 0 ? newPlayer.salary : nil
            )
            
            userTeam.players.append(playerData)
            
            if let teamIndex = leagueManager.allTeams.firstIndex(where: { $0.logoName == userTeam.logoName }) {
                leagueManager.allTeams[teamIndex].players.append(playerData)
                    leagueManager.objectWillChange.send()
                    print("📋 Fallback: Updated leagueManager team roster")
            }
            
                print("📋 Fallback: Updated userTeam roster: \(userTeam.players.count) players")
                print("💰 Fallback: Updated salary cap space: $\(userTeam.capSpace)")
                
                // Force UI refresh
                refreshTrigger = UUID()
                
                // Notify other views that player data has changed
                NotificationCenter.default.post(
                    name: .playerDataDidChange,
                    object: nil,
                    userInfo: ["teamLogoName": userTeam.logoName]
                )
                print("   📢 Posted playerDataDidChange notification (fallback)")
            }
        }
    }
}

// MARK: - Free Agent Contract Offers View

struct FreeAgentContractOffersView: View {
    let player: MasterPlayer
    let offers: [FreeAgentSigningManager.FreeAgentOffer]
    let userTeam: LeagueTeam
    let leagueManager: LeagueManager
    let onOfferSelected: (FreeAgentSigningManager.FreeAgentOffer) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Player Header
                    playerHeaderSection
                    
                    // Contract Offers
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Contract Offers")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        ForEach(Array(offers.enumerated()), id: \.offset) { index, offer in
                            FreeAgentOfferCard(
                                offer: offer,
                                offerNumber: index + 1,
                                onSelect: {
                                    onOfferSelected(offer)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Sign \(player.firstName) \(player.lastName)")
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
                    Text("#\(player.jerseyNum)")
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
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("Age: \(player.age)")
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
                    Color.blue.opacity(0.1),
                    Color.blue.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Free Agent Offer Card

struct FreeAgentOfferCard: View {
    let offer: FreeAgentSigningManager.FreeAgentOffer
    let offerNumber: Int
    let onSelect: () -> Void
    
    private var cardColor: Color {
        switch offer.type {
        case .low: return .orange
        case .base: return .blue
        case .high: return .green
        }
    }
    
    private var offerTitle: String {
        switch offer.type {
        case .low: return "Offer \(offerNumber): League Minimum"
        case .base: return "Offer \(offerNumber): Competitive"
        case .high: return "Offer \(offerNumber): Player-Friendly"
        }
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
                    
                    // Acceptance chance indicator
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Acceptance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(offer.acceptanceChance * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(cardColor)
                    }
                }
                
                // Contract Details
                VStack(spacing: 12) {
                    contractDetailRow(
                        title: "Total Value",
                        value: FreeAgentSigningManager.formatCurrency(offer.totalValue)
                    )
                    
                    contractDetailRow(
                        title: "Annual Salary",
                        value: FreeAgentSigningManager.formatCurrency(offer.yearlyValue)
                    )
                    
                    contractDetailRow(
                        title: "Contract Length",
                        value: "\(offer.contractLength) years"
                    )
                    
                    contractDetailRow(
                        title: "Guaranteed Money",
                        value: FreeAgentSigningManager.formatCurrency(offer.guaranteedMoney)
                    )
                }
                
                // Select Button
                HStack {
                    Spacer()
                    Text("Make Offer")
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

struct PositionGroupCard: View {
    let title: String
    let players: [MasterPlayer]
    
    private var topPlayers: [MasterPlayer] {
        players.sorted { Int($0.overall) ?? 0 > Int($1.overall) ?? 0 }.prefix(3).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 4)
            
            Text("Available: \(players.count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !topPlayers.isEmpty {
                Text("Top Players:")
                    .font(.subheadline)
                    .padding(.top, 4)
                
                ForEach(topPlayers, id: \.id) { player in
                    Text("\(player.firstName) \(player.lastName) (\(player.overall))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct FreeAgentPlayerRow: View {
    let player: MasterPlayer
    let userTeam: LeagueTeam
    let leagueManager: LeagueManager
    @Binding var showingContractOffers: Bool
    @Binding var selectedPlayer: MasterPlayer?
    @Binding var contractOffers: [FreeAgentSigningManager.FreeAgentOffer]
    @Binding var negotiationAttempts: [String: Int]
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(player.firstName) \(player.lastName)")
                    .font(.headline)
                
                HStack {
                    Text(player.position)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("#\(player.jerseyNum)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(player.overall) OVR")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("Age: \(player.age)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                handlePlayerSigning()
            }) {
                Text(canNegotiateWith(player: player) ? "Sign" : "No Offers")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(canNegotiateWith(player: player) ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(!canNegotiateWith(player: player))
        }
        .padding(.vertical, 4)
    }
    
    private func getPlayerNegotiationId(player: MasterPlayer) -> String {
        return "\(player.firstName)_\(player.lastName)_\(player.jerseyNum)"
    }
    
    private func getAttemptCount(for player: MasterPlayer) -> Int {
        let playerId = getPlayerNegotiationId(player: player)
        return negotiationAttempts[playerId] ?? 0
    }
    
    private func canNegotiateWith(player: MasterPlayer) -> Bool {
        return getAttemptCount(for: player) < 3
    }
    
    private func handlePlayerSigning() {
        // Check if negotiations are still allowed
        guard canNegotiateWith(player: player) else {
            return
        }
        
        selectedPlayer = player
        
        // Convert MasterPlayer to PlayerData for contract generation
        let playerData = PlayerData(
            firstName: player.firstName,
            lastName: player.lastName,
            position: player.position,
            number: Int(player.jerseyNum) ?? 1,
            overall: Int(player.overall) ?? 75,
            age: Int(player.age) ?? 25
        )
        
        // Generate contract offers
        contractOffers = FreeAgentSigningManager.generateFreeAgentOffers(
            player: playerData,
            signingTeam: userTeam
        )
        
        showingContractOffers = true
    }
}

// MARK: - Salary Info Card Component
struct SalaryInfoCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1.5)
                )
        )
    }
}

#Preview {
    NavigationStack {
        FreeAgentView(userTeam: .constant(LeagueTeam(
            logoName: "Chicago",
            name: "Chicago Bears",
            conference: "NFC",
            division: "NFC North",
            primaryColor: "blue",
            secondaryColor: "orange",
            players: [],
            overallRating: 80,
            coach: Coach(
                firstName: "Test",
                lastName: "Coach",
                overallRating: 80,
                offensiveScheme: "Pro Style",
                defensiveScheme: "4-3 Base",
                experience: 5,
                offensiveCoordinator: OffensiveCoordinator(
                    firstName: "OC",
                    lastName: "Test",
                    overallRating: 75,
                    offensiveScheme: "Pro Style",
                    experience: 3
                ),
                defensiveCoordinator: DefensiveCoordinator(
                    firstName: "DC",
                    lastName: "Test",
                    overallRating: 75,
                    defensiveScheme: "4-3 Base",
                    experience: 3
                )
            )
        )), leagueManager: LeagueManager())
    }
} 
