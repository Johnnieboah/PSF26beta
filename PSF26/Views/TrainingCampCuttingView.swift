import SwiftUI

struct TrainingCampCuttingView: View {
    @ObservedObject var leagueManager: LeagueManager
    @Binding var currentLeague: ObservableLeague
    @State private var validation: TeamCuttingValidation?
    @State private var selectedPlayers: Set<UUID> = []
    @State private var showingConfirmation = false
    @State private var showingSuccessAlert = false
    @State private var cutPlayersCount = 0
    @State private var refreshTrigger = false
    @Environment(\.dismiss) private var dismiss
    @State private var lockMessage: String? = nil
    @State private var showingLockAlert = false
    @State private var lockAlertMessage: String = ""
    private let minRosterCount: Int = 45
    private let targetCampCount: Int = 65
    
    // MARK: - Filtering
    enum CutFilter: Hashable {
        case recommended
        case selectedOnly
        case position(String)
        
        var title: String {
            switch self {
            case .recommended: return "Recommended"
            case .selectedOnly: return "Selected"
            case .position(let p): return p
            }
        }
    }
    
    @State private var selectedFilter: CutFilter = .recommended
    // TeamManagementView-style positions order
    private func rosterPositions(for team: LeagueTeam) -> [String] {
        // canonical order used across app
        let maddenOrder = [
            "QB", "RB", "FB", "WR", "TE",
            "LT", "LG", "C", "RG", "RT",
            "MLB", "ROLB", "LOLB", "EDGE", "DE", "DT",
            "CB", "SS", "FS",
            "K", "P"
        ]
        let realPositions = Set(team.players.map { $0.position })
        let ordered = maddenOrder.filter { realPositions.contains($0) }
        return ordered.isEmpty ? maddenOrder : ordered
    }
    
    var userTeam: LeagueTeam? { leagueManager.userTeam }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                headerSection
                // Removed ValidationStatusView per training camp UX
                filterMenuSection
                // Keep header anchored by pushing content to top using a spacer if list is empty
                if let team = userTeam, (filteredPlayers(for: team) ?? []).isEmpty {
                    Spacer(minLength: 0)
                } else {
                    playerListSection
                }
            }
            .navigationBarHidden(true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                print("🔧 TrainingCampCuttingView appeared")
                validateTeam()
            }
            .onChange(of: userTeam?.players.count, initial: false) { _, _ in
                validateTeam()
            }
            .onChange(of: currentLeague.trainingCampCompleted, initial: false) { _, completed in
                if completed {
                    // Training camp completed, dismiss the view
                    print("🔧 Training camp completed, dismissing view")
                    dismiss()
                }
            }

            .id(refreshTrigger) // Force refresh when team data changes
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: autoSelectCuts) {
                        HStack(spacing: 8) {
                            Image(systemName: "circle.grid.2x2.topleft.checkmark.filled")
                            Text("Auto Select Cuts")
                        }
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(minWidth: 0)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Auto Select Cuts")
                    Spacer()
                    Button {
                        print("🔧 Confirm Cuts button pressed")
                        showingConfirmation = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("Confirm Cuts")
                            Text("(\(selectedPlayers.count))").bold()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApplySelection() || selectedPlayers.isEmpty)
                }
            }
            .alert("Confirm Roster Cuts", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Confirm", role: .destructive) {
                    print("🔧 Confirm cuts alert confirmed")
                    Task {
                        await executeCuts()
                    }
                }
            } message: {
                Text("Are you sure you want to cut these \(selectedPlayers.count) players? This action cannot be undone.")
            }
            .alert("Roster Cuts Complete", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    print("🔧 Success alert OK button pressed")
                    dismiss()
                }
            } message: {
                Text("Successfully cut \(cutPlayersCount) players. They have been added to the free agent pool.")
            }
            .alert("Selection Locked", isPresented: $showingLockAlert) {
                Button("OK") { showingLockAlert = false }
            } message: {
                Text(lockAlertMessage)
            }
        }
    }

    // MARK: - Extracted subviews to simplify type-checking
    @ViewBuilder private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Training Camp Roster Cuts")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            if let team = userTeam {
                Text("Manage \(team.name) roster (min 45, target 65)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Label("Current: \(team.players.count)", systemImage: "person.3")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label("Need: \(remainingToTarget(for: team, target: targetCampCount))", systemImage: "scissors")
                        .foregroundStyle(.orange)
                    Spacer()
                    Label("Selected: \(selectedPlayers.count)", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
                SavingsSummaryView(
                    team: team,
                    selectedPlayers: selectedPlayers,
                    minRosterCount: minRosterCount,
                    lockMessage: lockMessage
                )
                // Cap penalty preview hidden for this screen per spec
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .roundedBackground(.ultraThinMaterial, radius: Corner.large)
    }

    @ViewBuilder private var filterMenuSection: some View {
        if let team = userTeam {
            CutsPositionFilter(selected: $selectedFilter, positions: rosterPositions(for: team))
                .padding(.top, -4)
        }
    }

    @ViewBuilder private var playerListSection: some View {
        if let team = userTeam {
            PlayerCuttingGrid(
                team: team,
                selectedPlayers: $selectedPlayers,
                validation: validation,
                playersOverride: filteredPlayers(for: team),
                positionsOrder: rosterPositions(for: team),
                onToggleAttempt: { player in attemptToggle(player: player) },
                onCutNow: { _ in }
            )
        }
    }

    // Removed duplicate bottom action row (toolbar now owns the controls)
    
    private func validateTeam() {
        print("🔧 validateTeam() called")
        guard let team = userTeam else { 
            print("🔧 No user team in validateTeam")
            return 
        }
        print("🔧 Validating team: \(team.name) with \(team.players.count) players")
        validation = TrainingCampManager.validateTeamCanMakeCuts(team: team)
    }
    
    private func autoSelectCuts() {
        guard let team = userTeam else { return }
        // How many players must be cut to reach training camp target (65)
        let need = max(0, team.players.count - targetCampCount)
        guard need > 0 else {
            selectedPlayers.removeAll()
            return
        }

        // Start from recommended cuts when available, then fill with next best eligible
        var newSelection: [UUID] = []
        let currentSelected = selectedPlayers

        // Helper: check if we can add a player without violating constraints
        func canAdd(_ player: PlayerData) -> Bool {
            // Temporarily include this player in selection and reuse existing validation rules
            // Total count after selecting this player
            let futureCount = team.players.count - (newSelection.count + currentSelected.count + 1)
            if futureCount < minRosterCount { return false }
            // Per-position minimum: at least 1 remains in every position present
            var counts: [String: Int] = [:]
            for p in team.players {
                if currentSelected.contains(p.id) || newSelection.contains(p.id) || p.id == player.id { continue }
                counts[p.position, default: 0] += 1
            }
            if (counts[player.position] ?? 0) < 1 { return false }
            return true
        }

        // 1) Add recommended cuts first
        if let validation {
            for p in validation.recommendedCuts {
                if newSelection.count >= need { break }
                if currentSelected.contains(p.id) { continue }
                if canAdd(p) { newSelection.append(p.id) }
            }
        }

        // 2) If still short, pick additional candidates by lowest overall, then lowest salary, then oldest
        if newSelection.count < need {
            let already = Set(currentSelected).union(newSelection)
            let sorted = team.players
                .filter { !already.contains($0.id) }
                .sorted { lhs, rhs in
                    if lhs.overall != rhs.overall { return lhs.overall < rhs.overall }
                    if lhs.estimatedSalary != rhs.estimatedSalary { return lhs.estimatedSalary < rhs.estimatedSalary }
                    return lhs.age > rhs.age
                }
            for p in sorted {
                if newSelection.count >= need { break }
                if canAdd(p) { newSelection.append(p.id) }
            }
        }

        selectedPlayers = Set(newSelection)
        print("🪄 Auto-selected \(selectedPlayers.count)/\(need) players to reach \(targetCampCount)")
    }

    private func filteredPlayers(for team: LeagueTeam) -> [PlayerData]? {
        switch selectedFilter {
        case .recommended:
            guard let validation else { return [] }
            let ids = Set(validation.recommendedCuts.map { $0.id })
            return team.players.filter { ids.contains($0.id) }
        case .selectedOnly:
            return team.players.filter { selectedPlayers.contains($0.id) }
        case .position(let pos):
            return team.players.filter { $0.position == pos }
        }
    }

    private var selectedFilterLabel: String { selectedFilter.title }
    
    private func executeCuts() async {
        print("🔧 executeCuts() called")
        print("🔧 Selected players count: \(selectedPlayers.count)")
        guard let team = userTeam else { 
            print("🔧 No user team found")
            return 
        }
        print("🔧 Team found: \(team.name) with \(team.players.count) players")
        
        // Get the players being cut
        let cutPlayers = team.players.filter { selectedPlayers.contains($0.id) }
        await performCut(cutPlayers)
    }

    private func performCut(_ cutPlayers: [PlayerData]) async {
        guard let team = userTeam else { return }
        
        // Remove selected players from the team
        print("🔧 Looking for team in allTeams...")
        print("🔧 Team name: \(team.name)")
        print("🔧 All teams count: \(leagueManager.allTeams.count)")
        print("🔧 All team names: \(leagueManager.allTeams.map { $0.name })")
        
        if let teamIndex = leagueManager.allTeams.firstIndex(where: { $0.logoName == team.logoName }) {
            print("🔧 Found team index: \(teamIndex)")
            print("🔧 Before cut: \(leagueManager.allTeams[teamIndex].players.count) players")
            
            // Update the team roster
            let cutIds = Set(cutPlayers.map { $0.id })
            leagueManager.allTeams[teamIndex].players = team.players.filter { player in
                !cutIds.contains(player.id)
            }
            
            print("🔧 After cut: \(leagueManager.allTeams[teamIndex].players.count) players")
            
            // Update the user team reference
            leagueManager.userTeam = leagueManager.allTeams[teamIndex]
            print("🔧 Updated userTeam: \(leagueManager.userTeam?.name ?? "nil") with \(leagueManager.userTeam?.players.count ?? 0) players")
            print("🔧 userTeam players: \(leagueManager.userTeam?.players.map { "\($0.firstName) \($0.lastName)" } ?? [])")
            
            // Save the updated roster to file system (background, atomic)
            do {
                let leagueId = currentLeague.getLeague().id
                let players = leagueManager.allTeams[teamIndex].players.map { player in
                    EditablePlayerData(
                        id: player.id,
                        firstName: player.firstName,
                        lastName: player.lastName,
                        position: player.position,
                        number: player.number,
                        age: player.age,
                        college: "Unknown",
                        height: "6'0\"",
                        weight: "200",
                        yearsPro: 1,
                        teamLogoName: team.logoName,
                        leagueId: leagueId,
                        isEdited: false,
                        lastModified: Date(),
                        speed: 70, agility: 70, awareness: 70, strength: 70, stamina: 70, injury: 70,
                        carrying: 70, trucking: 70, catching: 70, breakTackle: 70, jukeMove: 70, spinMove: 70, stiffArm: 70,
                        acceleration: 70, changeOfDirection: 70,
                        throwPower: 70, throwAccuracyShort: 70, throwAccuracyMid: 70, throwAccuracyDeep: 70,
                        throwOnTheRun: 70, throwUnderPressure: 70, playAction: 70,
                        tackle: 70, blockShedding: 70, zoneCoverage: 70, manCoverage: 70, pursuit: 70,
                        finesseMoves: 70, powerMoves: 70, press: 70, jumping: 70, playRecognition: 70, hitPower: 70,
                        toughness: 70,
                        passBlock: 70, runBlock: 70, impactBlocking: 70, passBlockPower: 70, runBlockPower: 70,
                        passBlockFinesse: 70, runBlockFinesse: 70,
                        release: 70, catchInTraffic: 70, spectacularCatch: 70, shortRouteRunning: 70,
                        mediumRouteRunning: 70, deepRouteRunning: 70,
                        kickPower: 70, kickAccuracy: 70,
                        bCVision: 70,
                        salary: player.estimatedSalary,
                        contract: nil,
                        isRookiePlayer: false,
                        draftPickNumber: nil,
                        draftYearValue: nil,
                        contractYearsLeft: 0,
                        overall: player.overall
                    )
                }
                _ = try await PlayerDataManager.shared.writePlayersToDisk(
                    players: players,
                    leagueId: leagueId,
                    teamLogoName: team.logoName
                )
                print("📝 Saved updated roster with \(players.count) players for \(team.name)")
                // Ensure any views reload fresh data
                PlayerDataManager.shared.clearCacheForTeam(teamLogoName: team.logoName, leagueId: leagueId)
                NotificationCenter.default.post(name: .playerDataDidChange, object: nil, userInfo: ["teamLogoName": team.logoName])
            } catch {
                print("❌ Failed to save updated roster: \(error)")
            }
            
            
            
            // Add cut players to free agent pool
            if let freeAgentTeamIndex = leagueManager.allTeams.firstIndex(where: { $0.logoName == "Free Agent" }) {
                // Add cut players directly to free agent team
                leagueManager.allTeams[freeAgentTeamIndex].players.append(contentsOf: cutPlayers)
                print("📋 Added \(cutPlayers.count) players to free agent pool")
                
                // Save free agent roster to file system (background, atomic)
                do {
                    let leagueId = currentLeague.getLeague().id
                    let players = leagueManager.allTeams[freeAgentTeamIndex].players.map { player in
                        EditablePlayerData(
                            id: player.id,
                            firstName: player.firstName,
                            lastName: player.lastName,
                            position: player.position,
                            number: player.number,
                            age: player.age,
                            college: "Unknown",
                            height: "6'0\"",
                            weight: "200",
                            yearsPro: 1,
                            teamLogoName: "Free Agent",
                            leagueId: leagueId,
                            isEdited: false,
                            lastModified: Date(),
                            speed: 70, agility: 70, awareness: 70, strength: 70, stamina: 70, injury: 70,
                            carrying: 70, trucking: 70, catching: 70, breakTackle: 70, jukeMove: 70, spinMove: 70, stiffArm: 70,
                            acceleration: 70, changeOfDirection: 70,
                            throwPower: 70, throwAccuracyShort: 70, throwAccuracyMid: 70, throwAccuracyDeep: 70,
                            throwOnTheRun: 70, throwUnderPressure: 70, playAction: 70,
                            tackle: 70, blockShedding: 70, zoneCoverage: 70, manCoverage: 70, pursuit: 70,
                            finesseMoves: 70, powerMoves: 70, press: 70, jumping: 70, playRecognition: 70, hitPower: 70,
                            toughness: 70,
                            passBlock: 70, runBlock: 70, impactBlocking: 70, passBlockPower: 70, runBlockPower: 70,
                            passBlockFinesse: 70, runBlockFinesse: 70,
                            release: 70, catchInTraffic: 70, spectacularCatch: 70, shortRouteRunning: 70,
                            mediumRouteRunning: 70, deepRouteRunning: 70,
                            kickPower: 70, kickAccuracy: 70,
                            bCVision: 70,
                            salary: player.estimatedSalary,
                            contract: nil,
                            isRookiePlayer: false,
                            draftPickNumber: nil,
                            draftYearValue: nil,
                            contractYearsLeft: 0,
                            overall: player.overall
                        )
                    }
                    _ = try await PlayerDataManager.shared.writePlayersToDisk(
                        players: players,
                        leagueId: leagueId,
                        teamLogoName: "Free Agent"
                    )
                    print("📝 Saved updated Free Agent roster with \(players.count) players")
                    // Clear cache and notify after FA pool updated
                    PlayerDataManager.shared.clearCacheForTeam(teamLogoName: "Free Agent", leagueId: leagueId)
                    NotificationCenter.default.post(name: .playerDataDidChange, object: nil, userInfo: ["teamLogoName": "Free Agent"])
                } catch {
                    print("❌ Failed to save Free Agent roster: \(error)")
                }
            }
            
            print("✂️ User cut \(cutPlayers.count) players from \(team.name)")
            
            // Keep Training Camp open; season start will close it. Maintain flag.
            leagueManager.isInTrainingCamp = true
            
            // Clear selections
            selectedPlayers.removeAll()
            
            // Re-validate and refresh recommended list from updated team
            validateTeam()
            if let team = leagueManager.userTeam {
                // Force refresh of grid/recommendations
                refreshTrigger.toggle()
                // Update validation after data save as well
                validation = TrainingCampManager.validateTeamCanMakeCuts(team: team)
            }
            
            // Store the count for the alert
            cutPlayersCount = cutPlayers.count
            
            // Trigger refresh
            refreshTrigger.toggle()
            
            // Show success alert
            print("🔧 Setting showingSuccessAlert = true")
            showingSuccessAlert = true
        } else {
            print("🔧 ERROR: Team not found in allTeams!")
            print("🔧 Team name: \(team.name)")
            print("🔧 All team names: \(leagueManager.allTeams.map { $0.name })")
        }
    }

    // MARK: - Selection & Constraints
    private func remainingToTarget(for team: LeagueTeam, target: Int) -> Int {
        let remaining = max(0, (team.players.count - target) - selectedPlayers.count)
        return remaining
    }

    private func projectedPositionCounts(for team: LeagueTeam) -> [String: Int] {
        var counts: [String: Int] = [:]
        for p in team.players {
            if selectedPlayers.contains(p.id) { continue }
            counts[p.position, default: 0] += 1
        }
        return counts
    }

    private func canApplySelection() -> Bool {
        guard let team = userTeam else { return false }
        // Total minimum check
        let futureCount = team.players.count - selectedPlayers.count
        if futureCount < minRosterCount { return false }
        // Per-position minimum: at least 1 player remains in every position present
        let counts = projectedPositionCounts(for: team)
        // If any position would be 0, invalid
        return !counts.values.contains(where: { $0 == 0 })
    }

    private func canSelect(player: PlayerData) -> (allowed: Bool, reason: String?) {
        guard let team = userTeam else { return (false, "No team") }
        // If already selected, always allow deselection
        if selectedPlayers.contains(player.id) { return (true, nil) }
        // Total count after selecting this player
        let futureCount = team.players.count - (selectedPlayers.count + 1)
        if futureCount < minRosterCount {
            return (false, "Cannot go under \(minRosterCount) players")
        }
        // Position minimum: at least 1 remains in this position
        let counts = projectedPositionCounts(for: team)
        let remainingAtPos = (counts[player.position] ?? 0) - 1
        if remainingAtPos < 1 {
            return (false, "Must keep at least 1 \(player.position)")
        }
        return (true, nil)
    }

    private func attemptToggle(player: PlayerData) {
        if selectedPlayers.contains(player.id) {
            selectedPlayers.remove(player.id)
            lockMessage = nil
            return
        }
        let res = canSelect(player: player)
        if res.allowed {
            selectedPlayers.insert(player.id)
            lockMessage = nil
        } else {
            lockMessage = res.reason
            lockAlertMessage = res.reason ?? "Selection is locked for this player."
            showingLockAlert = true
        }
    }

    private func attemptImmediateCut(player: PlayerData) async {
        let res = canSelect(player: player)
        if res.allowed, let team = userTeam,
           let full = team.players.first(where: { $0.id == player.id }) {
            await performCut([full])
            lockMessage = nil
        } else {
            lockMessage = res.reason
        }
    }
    
    // MARK: - File System Operations
    private func saveUpdatedRosterToFile(team: LeagueTeam) async {
        do {
            // Convert PlayerData to EditablePlayerData
            let editablePlayers = team.players.map { player in
                EditablePlayerData(
                    id: player.id,
                    firstName: player.firstName,
                    lastName: player.lastName,
                    position: player.position,
                    number: player.number,
                    age: player.age,
                    college: "Unknown",
                    height: "6'0\"",
                    weight: "200",
                    yearsPro: 1,
                    teamLogoName: team.logoName,
                    leagueId: currentLeague.getLeague().id,
                    isEdited: false,
                    lastModified: Date(),
                    speed: 70,
                    agility: 70,
                    awareness: 70,
                    strength: 70,
                    stamina: 70,
                    injury: 70,
                    carrying: 70,
                    trucking: 70,
                    catching: 70,
                    breakTackle: 70,
                    jukeMove: 70,
                    spinMove: 70,
                    stiffArm: 70,
                    acceleration: 70,
                    changeOfDirection: 70,
                    throwPower: 70,
                    throwAccuracyShort: 70,
                    throwAccuracyMid: 70,
                    throwAccuracyDeep: 70,
                    throwOnTheRun: 70,
                    throwUnderPressure: 70,
                    playAction: 70,
                    tackle: 70,
                    blockShedding: 70,
                    zoneCoverage: 70,
                    manCoverage: 70,
                    pursuit: 70,
                    finesseMoves: 70,
                    powerMoves: 70,
                    press: 70,
                    jumping: 70,
                    playRecognition: 70,
                    hitPower: 70,
                    toughness: 70,
                    passBlock: 70,
                    runBlock: 70,
                    impactBlocking: 70,
                    passBlockPower: 70,
                    runBlockPower: 70,
                    passBlockFinesse: 70,
                    runBlockFinesse: 70,
                    release: 70,
                    catchInTraffic: 70,
                    spectacularCatch: 70,
                    shortRouteRunning: 70,
                    mediumRouteRunning: 70,
                    deepRouteRunning: 70,
                    kickPower: 70,
                    kickAccuracy: 70,
                    bCVision: 70,
                    salary: player.estimatedSalary,
                    contract: nil,
                    isRookiePlayer: false,
                    draftPickNumber: nil,
                    draftYearValue: nil,
                    contractYearsLeft: 0,
                    overall: player.overall
                )
            }
            
            // Save directly to file system
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let playersDirectory = documentsURL.appendingPathComponent("Players")
            
            // Ensure the directory exists
            if !FileManager.default.fileExists(atPath: playersDirectory.path) {
                try FileManager.default.createDirectory(at: playersDirectory, withIntermediateDirectories: true)
            }
            
            let fileURL = playersDirectory.appendingPathComponent("league_\(currentLeague.getLeague().id.uuidString)_\(team.logoName).json")
            
            // Encode and save the updated roster
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(editablePlayers)
            try data.write(to: fileURL)
            
            print("📝 Saved updated roster with \(editablePlayers.count) players for \(team.name)")
        } catch {
            print("❌ Failed to save updated roster: \(error)")
        }
    }
}

// MARK: - FilterBar
// Matches TeamManagementView chip style & spacing
// TeamManagementView-style filter chips + added "Recommended" and "Selected"
private struct CutsPositionFilter: View {
    @Binding var selected: TrainingCampCuttingView.CutFilter
    let positions: [String] // includes "Overview" then full position list
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(for: "Recommended", value: .recommended)
                filterChip(for: "Selected", value: .selectedOnly)
                ForEach(positions, id: \.self) { position in
                    filterChip(for: position, value: .position(position))
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func filterChip(for label: String, value: TrainingCampCuttingView.CutFilter) -> some View {
        let isSelected = selected == value
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selected = value
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color(.systemBackground) : Color.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.primary : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Savings & Lock Banner
private struct SavingsSummaryView: View {
    let team: LeagueTeam
    let selectedPlayers: Set<UUID>
    let minRosterCount: Int
    let lockMessage: String?
    
    private var savings: Int {
        team.players.filter { selectedPlayers.contains($0.id) }
            .reduce(0) { $0 + $1.estimatedSalary }
    }
    
    private var projectedCount: Int {
        team.players.count - selectedPlayers.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label("Potential Savings: $\(savings.formatted())", systemImage: "banknote")
                    .foregroundStyle(.green)
                Spacer()
                Label("Projected Roster: \(projectedCount)", systemImage: "person.2")
                    .foregroundStyle(projectedCount < minRosterCount ? .red : .secondary)
            }
            .font(.footnote)
            if let lockMessage, !lockMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").foregroundStyle(.red)
                    Text(lockMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .transition(.opacity)
            }
        }
        .padding(10)
        .roundedBackground(.ultraThinMaterial, radius: Corner.medium)
    }
}

struct ValidationStatusView: View {
    let validation: TeamCuttingValidation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: validation.canMakeCuts ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(validation.canMakeCuts ? .green : .red)
                Text(validation.canMakeCuts ? "Ready for Cuts" : "Cap Penalty Preview")
                    .font(.headline)
                    .foregroundColor(validation.canMakeCuts ? .green : .orange)
            }
            // We keep the container, but label focuses on savings now; details are live in header summary
        }
        .padding(12)
        .roundedBackground(.ultraThinMaterial, radius: Corner.medium)
    }
}

// MARK: - Cap Penalty Preview (header)
private struct CapPenaltyView: View {
    let team: LeagueTeam
    let selectedPlayers: Set<UUID>
    let leagueId: UUID
    
    // Realistic dead money estimate using PlayerContract when available (Training Camp is post-June 1)
    private var estimatedPenalty: Int {
        let selected = team.players.filter { selectedPlayers.contains($0.id) }
        return selected.reduce(0) { acc, p in acc + deadCapForPlayer(p) }
    }
    
    var body: some View {
        if !selectedPlayers.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Cap Penalty (post‑June 1)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                    Spacer()
                }
                HStack(spacing: 12) {
                    Text("This Year Dead Cap: \(formatCurrency(currentYearDead))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Next Year: \(formatCurrency(nextYearDead))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("This Year Savings: \(formatCurrency(thisYearSavings))")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(10)
            .roundedBackground(.ultraThinMaterial, radius: Corner.medium)
        }
    }
    
    private var currentYearDead: Int {
        totalDeadInfo.current
    }
    private var nextYearDead: Int {
        totalDeadInfo.next
    }
    private var thisYearSavings: Int {
        totalDeadInfo.savings
    }
    
    private var totalDeadInfo: (current: Int, next: Int, savings: Int) {
        let selected = team.players.filter { selectedPlayers.contains($0.id) }
        var current = 0, next = 0, savings = 0
        for p in selected {
            if let calc = deadMoneyCalcForPlayer(p) {
                current += max(calc.currentYearHit, 0)
                next += max(calc.nextYearHit, 0)
                savings += max(calc.capSavings, 0)
            }
        }
        return (current, next, savings)
    }

    // MARK: - Helpers to source contract from EditablePlayerData on disk
    private func deadCapForPlayer(_ player: PlayerData) -> Int {
        if let calc = deadMoneyCalcForPlayer(player) {
            return max(calc.currentYearHit, 0)
        }
        return 0
    }
    private func deadMoneyCalcForPlayer(_ player: PlayerData) -> DeadMoneyCalculation? {
        do {
            let roster = try PlayerDataManager.shared.loadPlayersFromFile(leagueId: leagueId, teamLogoName: team.logoName)
            if let editable = roster.first(where: { $0.firstName == player.firstName && $0.lastName == player.lastName && $0.number == player.number }),
               let contract = editable.contract {
                return contract.calculateDeadMoney(isPostJune1: true)
            }
        } catch {
            // ignore and treat as zero
        }
        return nil
    }
}

struct PlayerCuttingList: View {
    let team: LeagueTeam
    @Binding var selectedPlayers: Set<UUID>
    let validation: TeamCuttingValidation?
    // Optional override list from filter
    let playersOverride: [PlayerData]?
    let positionsOrder: [String]
    let onToggleAttempt: (PlayerData) -> Void
    let onCutNow: (PlayerData) -> Void
    
    // Cache-friendly state (rebuilt on appear and when inputs change)
    @State private var cachedSortedPlayers: [PlayerData] = []
    @State private var cachedGroupedPlayers: [String: [PlayerData]] = [:]
    @State private var cachedOrderedPositions: [String] = []
    @State private var recommendedIdSet: Set<UUID> = []

    @State private var salaryStrings: [UUID: String] = [:]
    @State private var overallStrings: [UUID: String] = [:]
    @State private var positionLineStrings: [UUID: String] = [:]

    var body: some View {
        List {
            ForEach(cachedOrderedPositions, id: \.self) { position in
                Section(position) {
                    ForEach(cachedGroupedPlayers[position] ?? [], id: \.id) { player in
                        PlayerCuttingRow(
                            player: player,
                            isSelected: selectedPlayers.contains(player.id),
                            isRecommended: recommendedIdSet.contains(player.id),
                            onToggle: { onToggleAttempt(player) },
                            onCutNow: { onCutNow(player) }
                        )
                        .environment(\.formattedSalary, salaryStrings[player.id] ?? formatCurrency(player.estimatedSalary))
                        .environment(\.formattedOverall, overallStrings[player.id] ?? "OVR: \(player.overall)")
                        .environment(\.formattedPositionLine, positionLineStrings[player.id] ?? "\(player.position) • #\(player.number)")
                    }
                }
            }
        }
        .transaction { txn in txn.animation = nil }
        .onAppear { rebuildCaches() }
        .onChange(of: team.players.map { $0.id }.hashValue) { _, _ in rebuildCaches() }
        .onChange(of: playersOverride?.map { $0.id }.hashValue ?? 0) { _, _ in rebuildCaches() }
        .onChange(of: validation?.recommendedCuts.map { $0.id }.hashValue ?? 0) { _, _ in rebuildCaches() }
    }
    
    private func rebuildCaches() {
        let base: [PlayerData] = playersOverride ?? team.players
        // Sort once
        let sorted = base.sorted { lhs, rhs in
            if lhs.position != rhs.position { return lhs.position < rhs.position }
            if lhs.overall != rhs.overall { return lhs.overall < rhs.overall }
            return lhs.estimatedSalary > rhs.estimatedSalary
        }
        cachedSortedPlayers = sorted
        // Group once
        let grouped = Dictionary(grouping: sorted) { $0.position }
        cachedGroupedPlayers = grouped
        // Order positions once
        let keys = Set(grouped.keys)
        let presentOrdered = positionsOrder.filter { keys.contains($0) }
        let leftovers = grouped.keys.filter { !positionsOrder.contains($0) }.sorted()
        cachedOrderedPositions = presentOrdered + leftovers
        // Precompute recommended set
        if let validation {
            recommendedIdSet = Set(validation.recommendedCuts.map { $0.id })
        } else {
            recommendedIdSet = []
        }
        // Precompute formatted strings once
        salaryStrings = Dictionary(uniqueKeysWithValues: base.map { player in
            let display = player.actualSalary ?? player.estimatedSalary
            return (player.id, formatCurrency(display))
        })
        overallStrings = Dictionary(uniqueKeysWithValues: base.map { ($0.id, "OVR: \($0.overall)") })
        positionLineStrings = Dictionary(uniqueKeysWithValues: base.map { ($0.id, "\($0.position) • #\($0.number)") })
    }
    
    // toggle handled by parent for validation
}

struct PlayerCuttingRow: View {
    let player: PlayerData
    let isSelected: Bool
    let isRecommended: Bool
    let onToggle: () -> Void
    let onCutNow: () -> Void
    @Environment(\.formattedSalary) private var formattedSalary: String
    @Environment(\.formattedOverall) private var formattedOverall: String
    @Environment(\.formattedPositionLine) private var formattedPositionLine: String
    
    var body: some View {
        HStack {
            Button {
                onToggle()
            } label: {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .red : .gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(player.fullName)
                                .font(.headline)
                            
                            if isRecommended {
                                Text("RECOMMENDED")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: Corner.xSmall, style: .continuous)
                                            .fill(Color.orange.opacity(0.15))
                                    )
                            }
                        }
                        
                        HStack {
                            Text(formattedPositionLine)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(formattedOverall)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(formattedSalary)
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    // Hide per-row cut button for performance; tap row to select instead
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle()) // ensure immediate pressable area
        }
        .contentShape(Rectangle())
    }
}

// Environment hook for years-remaining lookup
private struct YearsRemainingCacheKey: EnvironmentKey {
    static let defaultValue: ((PlayerData) -> Int?)? = nil
}
extension EnvironmentValues {
    var yearsRemainingCacheProvider: ((PlayerData) -> Int?)? {
        get { self[YearsRemainingCacheKey.self] }
        set { self[YearsRemainingCacheKey.self] = newValue }
    }
}

// MARK: - Grid Version (2 rows of rounded-square buttons)
struct PlayerCuttingGrid: View {
    let team: LeagueTeam
    @Binding var selectedPlayers: Set<UUID>
    let validation: TeamCuttingValidation?
    let playersOverride: [PlayerData]?
    let positionsOrder: [String]
    let onToggleAttempt: (PlayerData) -> Void
    let onCutNow: (PlayerData) -> Void
    // Needed to read contract info from disk for years-remaining cache
    private var currentLeagueId: UUID? {
        nil
    }

    // Cached data for perf
    @State private var displayPlayers: [PlayerData] = []
    @State private var recommendedIdSet: Set<UUID> = []
    @State private var salaryStrings: [UUID: String] = [:]
    @State private var overallStrings: [UUID: String] = [:]
    @State private var positionLineStrings: [UUID: String] = [:]
    @State private var yearsRemainingCache: [UUID: Int] = [:]

    var body: some View {
        // Guarantee 4-across layout using a fixed 4-column LazyVGrid
        let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 10, alignment: .top), count: 4)
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(displayPlayers, id: \.id) { player in
                let isSelected = selectedPlayers.contains(player.id)
                let isRecommended = recommendedIdSet.contains(player.id)
                PlayerCuttingGridCell(
                    player: player,
                    isSelected: isSelected,
                    isRecommended: isRecommended,
                    formattedSalary: salaryStrings[player.id] ?? formatCurrency(player.estimatedSalary),
                    formattedOverall: overallStrings[player.id] ?? "OVR: \(player.overall)",
                    formattedPositionLine: positionLineStrings[player.id] ?? "\(player.position) • #\(player.number)",
                    onToggle: { onToggleAttempt(player) }
                )
                .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .padding(.horizontal, 8)
        .transaction { txn in txn.animation = nil }
        .onAppear { rebuildCaches() }
        .onChange(of: team.players.map { $0.id }.hashValue) { _, _ in rebuildCaches() }
        .onChange(of: playersOverride?.map { $0.id }.hashValue ?? 0) { _, _ in rebuildCaches() }
        .onChange(of: validation?.recommendedCuts.map { $0.id }.hashValue ?? 0) { _, _ in rebuildCaches() }
        .environment(\.yearsRemainingCacheProvider, { p in yearsRemainingCache[p.id] })
    }

    private func rebuildCaches() {
        let base: [PlayerData] = playersOverride ?? team.players
        // Sort by position (canonical order) then OVR desc, then salary desc
        // positionRank previously used for mixed sort; no longer needed with pure overall priority
        // Sort best-to-least overall, then by salary, then name
        displayPlayers = base.sorted { lhs, rhs in
            if lhs.overall != rhs.overall { return lhs.overall > rhs.overall }
            if lhs.estimatedSalary != rhs.estimatedSalary { return lhs.estimatedSalary > rhs.estimatedSalary }
            if lhs.lastName != rhs.lastName { return lhs.lastName < rhs.lastName }
            return lhs.firstName < rhs.firstName
        }
        if let validation { recommendedIdSet = Set(validation.recommendedCuts.map { $0.id }) } else { recommendedIdSet = [] }
        salaryStrings = Dictionary(uniqueKeysWithValues: base.map { player in
            let display = player.actualSalary ?? player.estimatedSalary
            return (player.id, formatCurrency(display))
        })
        overallStrings = Dictionary(uniqueKeysWithValues: base.map { ($0.id, "OVR: \($0.overall)") })
        positionLineStrings = Dictionary(uniqueKeysWithValues: base.map { ($0.id, "\($0.position) • #\($0.number)") })
        // Prime years-remaining cache from disk (best-effort, non-blocking)
        yearsRemainingCache.removeAll()
        if let lid = currentLeagueId {
            Task { @MainActor in
                do {
                    let roster = try PlayerDataManager.shared.loadPlayersFromFile(leagueId: lid, teamLogoName: team.logoName)
                    var local: [UUID: Int] = [:]
                    for p in base {
                        if let e = roster.first(where: { $0.firstName == p.firstName && $0.lastName == p.lastName && $0.number == p.number }), let c = e.contract?.yearsRemaining {
                            local[p.id] = c
                        }
                    }
                    yearsRemainingCache = local
                } catch {
                    // ignore
                }
            }
        }
    }
}

private struct PlayerCuttingGridCell: View {
    let player: PlayerData
    let isSelected: Bool
    let isRecommended: Bool
    let formattedSalary: String
    let formattedOverall: String
    let formattedPositionLine: String
    let onToggle: () -> Void
    @Environment(\.yearsRemainingCacheProvider) private var yearsProvider

    var body: some View {
        Button(action: onToggle) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isSelected ? Color.accentColor : (isRecommended ? Color.orange : Color.secondary.opacity(0.25)),
                                lineWidth: isSelected ? 2 : (isRecommended ? 2 : 1)
                            )
                    )
                    .shadow(radius: isSelected ? 2 : 1)
                VStack(alignment: .center, spacing: 6) {
                    // Name: first on top, last below, both centered
                    Text(player.firstName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(player.lastName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 2)

                    // Position • #
                    Text(formattedPositionLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    // Overall
                    Text(formattedOverall)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    // Salary
                    Text(formattedSalary)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    // Contract years remaining (if available)
                    // Years remaining (from cache primed by grid)
                    if let yr = yearsProvider?(player) ?? nil {
                        Text("\(yr) yr\(yr == 1 ? "" : "s") left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .multilineTextAlignment(.center)
                .padding(10)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

#Preview {
    TrainingCampCuttingView(
        leagueManager: LeagueManager(),
        currentLeague: .constant(ObservableLeague(league: League(teamName: "Chicago Bears", teamLogoName: "Chicago")))
    )
} 