import SwiftUI

// MARK: - Roster Management View
struct RosterManagementView: View {
    @Binding var team: TeamData
    @Binding var selectedPosition: String
    @StateObject private var masterDataLoader = MasterDataLoader.shared
    @State private var refreshTrigger = UUID()
    // Optional performance/UI tuning for hub sheet
    var unitFilterMode: Bool = false        // When true, use Offense/Defense toggle instead of per-position chips
    var showSalaryInCells: Bool = true      // When false, grid cells omit salary text
    var embedInScrollView: Bool = true      // Avoid nested scroll views when parent already scrolls
    private let debugLogs = false           // Toggle to enable verbose logging locally
    
    // Phase 4: Add league context for player detail navigation
    let leagueId: UUID?
    // Whether to include an "All" chip (hide in team creation flow)
    var includeAllChip: Bool = true
    
    init(team: Binding<TeamData>, selectedPosition: Binding<String>, leagueId: UUID? = nil, includeAllChip: Bool = true, unitFilterMode: Bool = false, showSalaryInCells: Bool = true, embedInScrollView: Bool = true) {
        self._team = team
        self._selectedPosition = selectedPosition
        self.leagueId = leagueId
        self.includeAllChip = includeAllChip
        self.unitFilterMode = unitFilterMode
        self.showSalaryInCells = showSalaryInCells
        self.embedInScrollView = embedInScrollView
    }
    
    private var positions: [String] {
        let basePositions = ["Overview"]
        let madddenPositionOrder = ["QB", "RB", "FB", "WR", "TE", "LT", "LG", "C", "RG", "RT", "MLB", "ROLB", "LOLB", "EDGE", "DE", "DT", "CB", "SS", "FS", "K", "P"]
        
        let realPlayers = masterDataLoader.getPlayers(for: team.logoName)
        
        if !realPlayers.isEmpty {
            let realPositions = Set(realPlayers.map { $0.position })
            let orderedPositions = madddenPositionOrder.filter { realPositions.contains($0) }
            return basePositions + orderedPositions
        } else {
            return basePositions + madddenPositionOrder
        }
    }
    
    private var filteredPlayers: [PlayerData] {
        // Use hybrid approach: edited player data first, then master data fallback
        let playersToUse = getTeamPlayers()
        
        if selectedPosition == "Overview" {
            return [] // Return empty for overview - we'll show the overview cards instead
        } else {
            return playersToUse.filter { $0.position == selectedPosition }.sorted { 
                if $0.overall != $1.overall {
                    return $0.overall > $1.overall
                }
                return $0.fullName < $1.fullName // Stable tie-breaker
            }
        }
    }
    
    var body: some View {
        Group {
            if embedInScrollView {
                ScrollView {
                    contentStack
                }
                .scrollClipDisabled()
                .scrollTargetBehavior(.viewAligned)
                .scrollBounceBehavior(.basedOnSize)
            } else {
                contentStack
            }
        }
        .onAppear {
            // If we're hiding the "All" chip, default to the first available position instead of "Overview"
            if unitFilterMode {
                if selectedPosition != "OFFENSE" && selectedPosition != "DEFENSE" {
                    selectedPosition = "OFFENSE"
                }
            } else if !includeAllChip && selectedPosition == "Overview" {
                let available = positions.dropFirst()
                if let first = available.first { selectedPosition = first }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .playerDataDidChange)) { notification in
            // Check if this notification is for our team
            if let teamLogoName = notification.userInfo?["teamLogoName"] as? String,
               teamLogoName == team.logoName {
                if debugLogs {
                    print("🔄 RosterManagementView: Received player data change notification for \(teamLogoName)")
                    print("   League ID context: \(leagueId?.uuidString ?? "nil")")
                }
                
                // Don't refresh if a player detail view is currently open for this team
                if PlayerDetailViewStateManager.shared.isPlayerDetailViewOpen,
                   let openTeam = PlayerDetailViewStateManager.shared.openPlayerDetailInfo?.teamLogoName,
                   openTeam == teamLogoName {
                    if debugLogs { print("🔒 RosterManagementView: Skipping roster refresh - player detail view is open for \(teamLogoName)") }
                    return
                }
                
                // Add small delay to ensure file operations are complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if debugLogs { print("🔄 RosterManagementView: Executing delayed refresh for \(teamLogoName)") }
                    refreshPlayerData()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PlayerReleased"))) { notification in
            // Check if this notification is for our team
            if let teamLogoName = notification.userInfo?["teamLogoName"] as? String,
               teamLogoName == team.logoName {
                if debugLogs { print("🚫 RosterManagementView: Player released from \(teamLogoName) - refreshing roster immediately") }
                
                // Immediate refresh since the player detail view is already dismissed
                refreshPlayerData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MasterDataLoaded"))) { _ in
            // Master data has finished loading - refresh empty cached data and reload if needed
            if debugLogs { print("🔄 RosterManagementView: Master data loaded - checking if refresh needed for \(team.logoName)") }
            PlayerDataManager.shared.refreshEmptyCachedTeams()
            
            let currentPlayers = getTeamPlayers()
            if currentPlayers.isEmpty {
                if debugLogs { print("🔄 RosterManagementView: Still no players after cache refresh - forcing view refresh for \(team.logoName)") }
                refreshPlayerData()
            }
        }
    }

    // Extracted stack to avoid nested ScrollView gesture conflicts
    private var contentStack: some View {
        // Compute players once per render to avoid repeated cache hits/logs
        let players = getTeamPlayers()
        return VStack(spacing: 12) {
            rosterHeaderSummary(players)
            if unitFilterMode {
                hubChips
            } else {
                positionChips
            }
            rosterGrid(players)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - New Header Summary (like Training Camp header)
    private func rosterHeaderSummary(_ players: [PlayerData]) -> some View {
        let totalPlayers = players.count
        // Show cap using CSV APY when available, computed off the top 53 players
        let top53 = Array(players.sorted { $0.overall > $1.overall }.prefix(53))
        let csvMap: [String: Int] = {
            if let csvURL = ContractImporter.locateCSV() {
                let rosters = ContractImporter.buildRosters(from: csvURL)
                if let csvPlayers = rosters[team.logoName] {
                    var m: [String: Int] = [:]
                    m.reserveCapacity(csvPlayers.count)
                    for p in csvPlayers {
                        m[p.playerId] = p.actualSalary ?? p.estimatedSalary
                    }
                    return m
                }
            }
            return [:]
        }()
        let salarySpent = top53.reduce(0) { total, p in
            let apy = csvMap[p.playerId] ?? p.actualSalary ?? p.estimatedSalary
            return total + apy
        }
        // Allow negative cap space display during team selection
        let capSpace = NFLCapData.salaryCap - salarySpent
        let counts = Dictionary(grouping: players) { $0.position }.mapValues { $0.count }
        let teamOveralls = calculateTeamOveralls(players: players)
        
        return VStack(spacing: 12) {
            // Overalls row centered and prominent
            HStack(spacing: 24) {
                HStack(spacing: 6) { Image(systemName: "bolt.fill"); Text("Off \(teamOveralls.offense)") }
                    .font(.system(size: 16, weight: .semibold))
                HStack(spacing: 6) { Image(systemName: "shield.fill"); Text("Def \(teamOveralls.defense)") }
                    .font(.system(size: 16, weight: .semibold))
                HStack(spacing: 6) { Image(systemName: "chart.bar.fill"); Text("OVR \(teamOveralls.overall)") }
                    .font(.system(size: 17, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            // Players / Cap Spent / Cap Space centered
            HStack(spacing: 24) {
                VStack(spacing: 4) { Image(systemName: "person.3"); Text("Players"); Text("\(totalPlayers)").font(.headline) }
                VStack(spacing: 4) { Image(systemName: "banknote"); Text("Cap Spent"); Text("\(formatCurrency(salarySpent))").font(.headline).foregroundStyle(.green) }
                VStack(spacing: 4) { Image(systemName: "creditcard"); Text("Cap Space"); Text("\(formatCapSpaceValue(capSpace))").font(.headline) }
            }
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .font(.caption)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            // Aligned positions grid
            positionsGrid(from: counts)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .roundedBackground(.ultraThinMaterial, radius: Corner.large)
        .id(refreshTrigger)
    }

    private func formatCapSpaceValue(_ cap: Int) -> String {
        if cap >= 0 { return formatCurrency(cap) }
        let absVal = abs(cap)
        let compact = formatCurrency(absVal)
        // formatCurrency returns strings like $334.718M or $250k; prefix with minus
        return "-\(compact)"
    }

    private func positionCountsLine(from counts: [String: Int]) -> String { "" }

    private func positionsGrid(from counts: [String: Int]) -> some View {
        let canonical = ["QB","RB","FB","WR","TE","LT","LG","C","RG","RT","MLB","ROLB","LOLB","EDGE","DE","DT","CB","SS","FS","K","P"]
        var items: [(String, Int)] = canonical.compactMap { pos in
            let c = counts[pos] ?? 0
            return c > 0 ? (pos, c) : nil
        }
        // Align as 3 rows x 6 columns (18 max). Keep canonical ordering and trim extras.
        if items.count > 18 { items = Array(items.prefix(18)) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .center), count: 6)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items, id: \.0) { (pos, c) in
                HStack(spacing: 4) {
                    Text(pos)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(c)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Chips (same style as Training Camp)
    private var positionChips: some View {
        // Positions-only by default. Include OFFENSE/DEFENSE chips only when unitFilterMode is enabled.
        var chipPositions: [String] = []
        if includeAllChip { chipPositions.append("All") }
        if unitFilterMode { chipPositions += ["OFFENSE", "DEFENSE"] }
        chipPositions += Array(positions.dropFirst())
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chipPositions, id: \.self) { pos in
                    let isSelected = (selectedPosition == pos) || (includeAllChip && pos == "All" && selectedPosition == "Overview")
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if pos == "All" { selectedPosition = "Overview" } else { selectedPosition = pos }
                        }
                    }) {
                        Text(pos)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSelected ? Color(.systemBackground) : Color.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(isSelected ? Color.primary : Color(.secondarySystemBackground))
                            )
                    }
                    // Ensure the whole chip surface is tappable on the button itself (not only the label)
                    .contentShape(RoundedRectangle(cornerRadius: 20))
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: isSelected)
                    .accessibilityLabel("Filter by \(pos)")
                }
            }
            .padding(.horizontal, 8)
            // Bring chips above any neighboring content to avoid accidental hit-test occlusion
            .zIndex(1)
        }
    }

    // MARK: - Offense / Defense Toggle (Hub performance mode)
    private var hubChips: some View {
        // Hub sheet chips: OFFENSE, DEFENSE, then every position.
        let base = ["OFFENSE", "DEFENSE"]
        let positionList = Array(positions.dropFirst())
        let chips = base + positionList
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { pos in
                    let isSelected = selectedPosition == pos
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedPosition = pos
                        }
                    }) {
                        Text(pos)
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
                    .accessibilityLabel("Filter by \(pos)")
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private struct ToggleChip: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                Text(title)
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

    // MARK: - Grid (4 across like Training Camp)
    private func rosterGrid(_ players: [PlayerData]) -> some View {
        let filtered: [PlayerData]
        if unitFilterMode {
            let offensivePositions = ["QB","RB","FB","WR","TE","LT","LG","C","RG","RT"]
            let defensivePositions = ["MLB","ROLB","LOLB","EDGE","DE","DT","CB","SS","FS"]
            if selectedPosition == "OFFENSE" {
                filtered = players.filter { offensivePositions.contains($0.position) }
            } else if selectedPosition == "DEFENSE" {
                filtered = players.filter { defensivePositions.contains($0.position) }
            } else {
                // If a specific position chip was selected in the hub, filter by that position
                filtered = players.filter { $0.position == selectedPosition }
            }
        } else {
            if selectedPosition == "Overview" || (includeAllChip && selectedPosition == "All") {
                filtered = players
            } else {
                filtered = players.filter { $0.position == selectedPosition }
            }
        }
        // Stable sort by (position -> overall desc -> lastName asc -> firstName asc)
        let positionRank: [String: Int] = [
            "QB": 1, "RB": 2, "FB": 3, "WR": 4, "TE": 5,
            "LT": 6, "LG": 7, "C": 8, "RG": 9, "RT": 10,
            "MLB": 11, "ROLB": 12, "LOLB": 13, "EDGE": 14, "DE": 15, "DT": 16,
            "CB": 17, "SS": 18, "FS": 19, "K": 20, "P": 21
        ]
        let sorted = filtered.sorted { lhs, rhs in
            if lhs.position != rhs.position {
                return (positionRank[lhs.position] ?? 99) < (positionRank[rhs.position] ?? 99)
            }
            if lhs.overall != rhs.overall { return lhs.overall > rhs.overall }
            if unitFilterMode == false { // preserve original TeamManagement sorting
                if lhs.estimatedSalary != rhs.estimatedSalary { return lhs.estimatedSalary > rhs.estimatedSalary }
            }
            if lhs.lastName != rhs.lastName { return lhs.lastName < rhs.lastName }
            return lhs.firstName < rhs.firstName
        }
        let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 10, alignment: .top), count: 4)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(sorted, id: \.id) { p in
                if unitFilterMode {
                    NavigationLink(destination:
                                    PlayerDetailView_Refactored(
                                        player: p,
                                        teamLogoName: team.logoName,
                                        leagueId: leagueId,
                                        isEditable: true,
                                        leagueManager: nil
                                    )
                    ) {
                        RosterGridCell(
                            player: p,
                            showSalary: showSalaryInCells,
                            teamPrimaryHex: team.primaryColor,
                            teamSecondaryHex: team.secondaryColor
                        )
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    RosterGridCell(
                        player: p,
                        showSalary: showSalaryInCells,
                        teamPrimaryHex: team.primaryColor,
                        teamSecondaryHex: team.secondaryColor
                    )
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
        }
    }
    
    // Legacy rosterHeader no longer used
    private var rosterHeader: some View {
        // Center the title + dropdown inline, and overlay right-side status so centering never shifts
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Text(selectedPosition == "Overview" ? "Team Overview" : "Team Roster")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                positionFilterDropdown
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .overlay(alignment: .trailing) {
            if masterDataLoader.isLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if selectedPosition != "Overview" {
                Text("\(filteredPlayers.count) Players")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Position Filter Dropdown
    private var positionFilterDropdown: some View {
        Menu {
            // Overview section
            Section("Team Analysis") {
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
                                .foregroundColor(Color(hex: team.primaryColor))
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
                    .foregroundColor(Color(hex: team.primaryColor))
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(Color(hex: team.primaryColor))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: team.primaryColor).opacity(0.4), lineWidth: 1)
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
                        .foregroundColor(Color(hex: team.primaryColor))
                }
            }
        }
    }

    
    // MARK: - Legacy Position Filter (Fallback)
    private var positionFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(positions, id: \.self) { position in
                    filterButton(for: position)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func filterButton(for position: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedPosition = position
            }
        }) {
            Text(position)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(adaptiveTextColor(for: position))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedPosition == position ? adaptiveSelectionColor : adaptiveBackgroundColor)
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectedPosition == position)
    }
    
    // MARK: - Adaptive Colors for Dark Mode Support
    private func adaptiveTextColor(for position: String) -> Color {
        selectedPosition == position ? .white : .primary
    }
    
    private var adaptiveSelectionColor: Color {
        Color(hex: team.primaryColor)
    }
    
    private var adaptiveBackgroundColor: Color {
        Color(.systemGray5) // Adapts to light/dark mode automatically
    }
    
    private var teamOverviewContent: some View {
        let teamPlayers = getTeamPlayers()
        let teamOveralls = calculateTeamOveralls(players: teamPlayers)
        let topPlayers = getTopPlayers(players: teamPlayers)
        
        if debugLogs {
            print("📊 \(team.logoName) Team Overalls: Offense: \(teamOveralls.offense), Defense: \(teamOveralls.defense), Overall: \(teamOveralls.overall) (Players: \(teamPlayers.count))")
        }
        
        return VStack(alignment: .leading, spacing: 24) {
            // Team Overalls Section
            TeamOverallsCard(
                teamOveralls: teamOveralls,
                teamColor: team.primaryColor
            )
            
            // Top Players Section
            TopPlayersCard(
                players: topPlayers,
                teamColor: team.primaryColor
            )
            
            // Team Stats Section removed per request
        }
        .id(refreshTrigger) // Force refresh when trigger changes
    }
    
    private var playerList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredPlayers) { player in
                OptimizedPlayerRow(
                    player: OptimizedPlayerRow.PlayerRowData(
                        id: "\(player.firstName)_\(player.lastName)_\(player.number)",
                        name: player.fullName,
                        position: player.position,
                        number: player.number,
                        overall: player.overall,
                        age: player.age
                    ),
                    teamColor: team.primaryColor,
                    teamLogoName: team.logoName,
                    leagueId: leagueId,
                    onPlayerUpdated: {
                        refreshPlayerData()
                    }
                )
            }
        }
        .id(refreshTrigger)
    }

    // MARK: - Grid Cell
    private struct RosterGridCell: View {
        let player: PlayerData
        var showSalary: Bool = true
        // Inject team colors so we can theme the cell
        var teamPrimaryHex: String = ""
        var teamSecondaryHex: String = ""
        var body: some View {
            ZStack(alignment: .topLeading) {
                let bg = teamPrimaryHex.isEmpty ? Color(.secondarySystemBackground) : Color(hex: teamPrimaryHex)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                VStack(alignment: .center, spacing: 4) {
                    // Always render first/last on separate lines for readability
                    Text(player.firstName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(player.lastName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(teamSecondaryHex.isEmpty ? .white : Color(hex: teamSecondaryHex))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    // Jersey number (compact so names fit)
                    Text("\(player.number)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(teamSecondaryHex.isEmpty ? .white : Color(hex: teamSecondaryHex))

                    // Position
                    Text(player.position)
                        .font(.caption)
                        .foregroundColor(.white)

                    // Overall (compact)
                    Text("OVR \(player.overall)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    // Optional salary (hidden in Hub sheet)
                    if showSalary {
                        Text(formatCurrency(player.estimatedSalary))
                            .font(.caption2)
                            .foregroundColor(.green)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .multilineTextAlignment(.center)
                .padding(10)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // MARK: - Phase 6: Updated to use hybrid data loading
    private func getTeamPlayers() -> [PlayerData] {
        if debugLogs {
            print("🔍 RosterManagementView.getTeamPlayers() for \(team.logoName)")
            print("   League ID: \(leagueId?.uuidString ?? "nil")")
            print("   Refresh trigger: \(refreshTrigger)")
        }
        
        // If we have a league context, use the regular method
        if let leagueId = leagueId {
            let players = PlayerDataManager.shared.getPlayers(for: team.logoName, leagueId: leagueId)
            if debugLogs { print("   Loaded \(players.count) players from PlayerDataManager for league") }
            
            if !players.isEmpty {
                if debugLogs { print("   ✅ Using \(players.count) players from PlayerDataManager") }
                return players
            } else {
                if debugLogs { print("   ⚠️ Falling back to team.players (\(team.players.count) players)") }
                return team.players
            }
        } else {
            // No league context - use balanced players for team selection
            if debugLogs { print("   📊 Using balanced players for team selection (targeting 60 players)") }
            let players = PlayerDataManager.shared.getBalancedPlayersForTeamSelection(for: team.logoName)
            if debugLogs { print("   ✅ Using \(players.count) balanced players for team selection") }
            return players
        }
    }
    
    private func calculateTeamOveralls(players: [PlayerData]) -> (offense: Int, defense: Int, overall: Int) {
        // For team selection (no league context), check cache first to ensure consistency
        if leagueId == nil {
            if let cachedRatings = PlayerDataManager.shared.getCachedTeamOverallRatings(for: team.logoName) {
                if debugLogs { print("📊 📋 Using cached team overall ratings for \(team.logoName): O:\(cachedRatings.offense) D:\(cachedRatings.defense) Overall:\(cachedRatings.overall)") }
                return cachedRatings
            }
        }
        
        let offensivePositions = ["QB", "RB", "FB", "WR", "TE", "LT", "LG", "C", "RG", "RT"]
        let defensivePositions = ["MLB", "ROLB", "LOLB", "EDGE", "DE", "DT", "CB", "SS", "FS"]
        
        let offensivePlayers = players.filter { offensivePositions.contains($0.position) }
        let defensivePlayers = players.filter { defensivePositions.contains($0.position) }
        
        // Calculate raw unit ratings first
        let rawOffenseRating = calculateEnhancedUnitRating(players: offensivePlayers, isOffense: true)
        let rawDefenseRating = calculateEnhancedUnitRating(players: defensivePlayers, isOffense: false)
        
        // Apply consistent normalization to both unit ratings to bring them to realistic ranges
        let offenseOverall = normalizeUnitRating(Double(rawOffenseRating), players: offensivePlayers, teamName: team.logoName)
        let defenseOverall = normalizeUnitRating(Double(rawDefenseRating), players: defensivePlayers, teamName: team.logoName)
        
        // Calculate special teams rating
        let specialTeamsPlayers = players.filter { ["K", "P"].contains($0.position) }
        let specialTeamsRating = calculateSpecialTeamsRating(players: specialTeamsPlayers)
        
        // Team overall is now a logical combination of the unit ratings
        // Weight the units (Offense: 45%, Defense: 45%, Special Teams: 10%)
        let rawTeamRating = (Double(offenseOverall) * 0.45) + (Double(defenseOverall) * 0.45) + (specialTeamsRating * 0.10)
        
        // Minor adjustment for team overall (should be close to weighted average)
        let teamOverall = Int(round(rawTeamRating))
        
        let finalRatings = (offenseOverall, defenseOverall, teamOverall)
        
        // Cache the ratings for team selection to ensure consistency
        if leagueId == nil {
            PlayerDataManager.shared.cacheTeamOverallRatings(for: team.logoName, ratings: finalRatings)
        }
        
        return finalRatings
    }
    
    /// Normalizes unit ratings (offense/defense) to realistic NFL ranges with increased variance
    private func normalizeUnitRating(_ rawRating: Double, players: [PlayerData], teamName: String) -> Int {
        // Expanded range for more variance (70-95 instead of 75-95)
        let minUnitRating = 70.0
        let maxUnitRating = 95.0
        
        // Calculate depth and quality factors for this unit
        let sortedPlayers = players.sorted { $0.overall > $1.overall }
        let topPlayers = Array(sortedPlayers.prefix(min(8, sortedPlayers.count))) // Top 8 for unit
        let topPlayerAverage = topPlayers.isEmpty ? rawRating : Double(topPlayers.map { $0.overall }.reduce(0, +)) / Double(topPlayers.count)
        
        // More aggressive combination to increase variance
        let enhancedRating = (rawRating * 0.6) + (topPlayerAverage * 0.4)
        
        // Apply team-specific adjustments to create proper variance
        let teamAdjustment = getTeamStrengthAdjustment(teamName: teamName)
        let adjustedRating = enhancedRating + teamAdjustment
        
        // Add variance amplification based on team strength
        let strengthMultiplier = calculateStrengthMultiplier(enhancedRating: adjustedRating)
        let amplifiedRating = adjustedRating * strengthMultiplier
        
        // Wider normalization range for more spread
        let normalizedValue = (amplifiedRating - 60.0) / 35.0 // Wider range for more variance
        let clampedValue = max(0.0, min(1.0, normalizedValue))
        
        let finalRating = minUnitRating + (clampedValue * (maxUnitRating - minUnitRating))
        
        return Int(round(finalRating))
    }
    
    /// Calculates a strength multiplier to amplify differences between good and bad teams
    private func calculateStrengthMultiplier(enhancedRating: Double) -> Double {
        // Amplify the differences - make good teams better and bad teams worse
        if enhancedRating >= 85 {
            return 1.15  // Elite teams get a boost
        } else if enhancedRating >= 80 {
            return 1.08  // Good teams get moderate boost
        } else if enhancedRating >= 75 {
            return 1.02  // Average teams stay roughly the same
        } else if enhancedRating >= 70 {
            return 0.95  // Below average teams get slightly penalized
        } else {
            return 0.88  // Bad teams get more heavily penalized
        }
    }
    
    private func normalizeTeamRating(_ rawRating: Double, allPlayers: [PlayerData]) -> Int {
        // Optimized for 60-player rosters - calculate team depth and talent variance
        let sortedPlayers = allPlayers.sorted { $0.overall > $1.overall }
        
        // Adjusted for 60-player rosters: use more starters/key players (top 28 instead of 22)
        let topPlayersCount = min(28, sortedPlayers.count) // Increased for 60-player rosters
        let topPlayers = Array(sortedPlayers.prefix(topPlayersCount))
        
        // Calculate additional factors optimized for 60-player rosters
        let topPlayerAverage = topPlayers.isEmpty ? rawRating : Double(topPlayers.map { $0.overall }.reduce(0, +)) / Double(topPlayers.count)
        let depthQuality = calculateDepthQuality60Player(allPlayers: allPlayers)
        let talentVariance = calculateTalentVariance60Player(allPlayers: allPlayers)
        
        // Adjusted weights for 60-player rosters - emphasize top talent more due to smaller roster
        let enhancedRating = (rawRating * 0.45) + (topPlayerAverage * 0.40) + (depthQuality * 0.10) + (talentVariance * 0.05)
        
        // Apply team-specific adjustments based on recent performance and known strengths
        let teamAdjustment = getTeamStrengthAdjustment(teamName: team.logoName)
        let finalEnhancedRating = enhancedRating + teamAdjustment
        
        // Adjusted range mapping for 60-player rosters - raised to realistic NFL levels
        let minRating = 78.0  // Raised floor to realistic NFL minimum
        let maxRating = 94.0  // Raised ceiling to allow elite teams to shine
        let normalizedValue = (finalEnhancedRating - 60.0) / 30.0 // Adjusted base and range for higher ratings
        let clampedValue = max(0.0, min(1.0, normalizedValue))
        
        let finalRating = minRating + (clampedValue * (maxRating - minRating))
        
        return Int(round(finalRating))
    }
    
    private func getTeamStrengthAdjustment(teamName: String) -> Double {
        // Enhanced team-specific adjustments with increased variance to spread teams out
        // More aggressive adjustments to prevent clustering in the middle
        switch teamName {
        // Elite Tier - Super Bowl Champions & Perennial Contenders (88-95 range)
        case "Philadelphia": return 12.0  // Super Bowl winners - elite across the board
        case "KansasCity": return 11.0    // Mahomes + championship pedigree
        case "Buffalo": return 10.0      // Josh Allen + consistently elite
        case "SanFrancisco": return 9.5  // Elite roster construction
        
        // Very Strong Tier - Playoff Contenders (85-89 range)
        case "Baltimore": return 8.5     // Lamar + strong defense
        case "Cincinnati": return 8.0    // Burrow + elite receiving corps
        case "Miami": return 7.0         // High-powered offense
        case "Dallas": return 6.5        // Talented but inconsistent
        case "Detroit": return 6.0       // Rising with good coaching
        
        // Good Tier - Solid Teams (82-85 range)
        case "GreenBay": return 5.0      // Solid with good QB play
        case "Seattle": return 4.5       // Consistent playoff team
        case "Minnesota": return 4.0     // Good roster, coaching
        case "LAN": return 3.5           // Rams with McVay
        case "Jacksonville": return 3.0  // Young team improving
        
        // Average Tier - Middle of Pack (78-82 range)
        case "Pittsburgh": return 2.0    // Solid but aging
        case "Cleveland": return 1.5     // Inconsistent talent
        case "Indianapolis": return 0.5  // Rebuilding mode
        case "Atlanta": return 0.0       // Middle of the pack
        case "TampaBay": return -0.5     // Post-Brady transition
        case "LasVegas": return -1.0     // Underachieving
        case "LAA": return -1.5          // Chargers - talented but disappointing
        case "NewOrleans": return -2.0   // Saints - aging roster
        case "NYN": return -2.5          // Giants - limited talent
        
        // Below Average Tier - Rebuilding Teams (72-76 range)
        case "Houston": return -3.5      // Young team, still building
        case "Tennessee": return -4.0    // Down year, roster issues
        case "NYA": return -4.5          // Jets - disappointing with talent
        case "Denver": return -5.0       // Inconsistent, QB questions
        case "NewEngland": return -5.5   // Post-Brady struggles
        case "Washington": return -6.0   // Rebuilding, limited talent
        
        // Poor Tier - Bottom Feeders (68-72 range)
        case "Chicago": return -7.0      // Rebuilding, picked 10th overall
        case "Carolina": return -8.0     // Panthers - major rebuild
        case "Arizona": return -9.0      // Cardinals - bottom tier roster
        
        default: return 0.0              // Unknown team
        }
    }
    
    private func calculateDepthQuality(allPlayers: [PlayerData]) -> Double {
        // Measure how good the depth players are (positions 23-53)
        let sortedPlayers = allPlayers.sorted { $0.overall > $1.overall }
        let depthPlayers = Array(sortedPlayers.dropFirst(22))
        
        if depthPlayers.isEmpty { return 70.0 }
        
        let depthAverage = Double(depthPlayers.map { $0.overall }.reduce(0, +)) / Double(depthPlayers.count)
        return depthAverage
    }
    
    private func calculateTalentVariance(allPlayers: [PlayerData]) -> Double {
        // Enhanced talent variance - rewards teams with elite players more heavily
        let overalls = allPlayers.map { Double($0.overall) }
        let average = overalls.reduce(0, +) / Double(overalls.count)
        
        // Count elite players (90+) and penalize teams with too many low-rated players
        let elitePlayers = overalls.filter { $0 >= 90.0 }.count
        let lowRatedPlayers = overalls.filter { $0 < 70.0 }.count
        
        // Calculate standard variance
        let variance = overalls.reduce(0) { sum, overall in
            sum + pow(overall - average, 2)
        } / Double(overalls.count)
        
        // Enhanced bonus system
        let baseVariance = sqrt(variance) * 2.0
        let eliteBonus = Double(elitePlayers) * 1.5  // Big bonus for elite players
        let lowRatedPenalty = Double(lowRatedPlayers) * -0.8  // Penalty for too many low players
        
        return baseVariance + eliteBonus + lowRatedPenalty
    }
    
    private func calculateEnhancedUnitRating(players: [PlayerData], isOffense: Bool) -> Int {
        guard !players.isEmpty else { return 75 } // Raised base minimum
        
        // Enhanced position weights - QB impact increased significantly
        let positionWeights: [String: Double] = isOffense ? [
            "QB": 4.5,      // Quarterback has massive impact on team success
            "LT": 2.5, "RT": 2.2,  // Tackle protection crucial
            "WR": 2.0,      // Primary receivers
            "RB": 1.8,      // Running game impact
            "TE": 1.5,      // Versatile weapon
            "C": 1.4,       // Center of the line
            "LG": 1.2, "RG": 1.2,  // Guards
            "FB": 0.9       // Fullback (less common)
        ] : [
            "CB": 2.5,      // Cover elite receivers
            "EDGE": 2.3,    // Pass rush game-changer
            "MLB": 2.0,     // Run defense/coverage anchor
            "DE": 1.8,      // Pass rush/run stop
            "SS": 1.6, "FS": 1.6,  // Safety coverage
            "DT": 1.5,      // Interior rush/run stop
            "ROLB": 1.4, "LOLB": 1.4  // Outside linebackers
        ]
        
        // Group players by position and get top players at each position
        let playersByPosition = Dictionary(grouping: players) { $0.position }
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        for (position, positionPlayers) in playersByPosition {
            let weight = positionWeights[position] ?? 1.0
            let sortedPlayers = positionPlayers.sorted { $0.overall > $1.overall }
            
            // Take top players at each position (starter + some depth)
            let playersToConsider = Array(sortedPlayers.prefix(min(3, sortedPlayers.count)))
            
            // Weight starters more heavily than backups
            for (index, player) in playersToConsider.enumerated() {
                let depthMultiplier = index == 0 ? 1.0 : (index == 1 ? 0.6 : 0.3)
                let playerWeight = weight * depthMultiplier
                
                weightedSum += Double(player.overall) * playerWeight
                totalWeight += playerWeight
            }
        }
        
        let unitRating = totalWeight > 0 ? weightedSum / totalWeight : 75.0 // Raised fallback
        return Int(round(unitRating))
    }
    
    private func calculateSpecialTeamsRating(players: [PlayerData]) -> Double {
        let kickers = players.filter { $0.position == "K" }
        let punters = players.filter { $0.position == "P" }
        
        let kickerRating = kickers.isEmpty ? 78.0 : Double(kickers.max { $0.overall < $1.overall }?.overall ?? 78)
        let punterRating = punters.isEmpty ? 78.0 : Double(punters.max { $0.overall < $1.overall }?.overall ?? 78)
        
        return (kickerRating + punterRating) / 2.0
    }
    
    private func getTopPlayers(players: [PlayerData]) -> [PlayerData] {
        return players.sorted { $0.overall > $1.overall }.prefix(5).map { $0 }
    }
    
    // MARK: - Refresh Management
    private func refreshPlayerData() {
        if debugLogs { print("🔄 Refreshing player data for \(team.logoName)") }
        
        // Clear the PlayerDataManager cache specifically for this team
        PlayerDataManager.shared.clearCacheForTeam(teamLogoName: team.logoName, leagueId: leagueId)
        
        // Trigger view refresh by changing the refresh trigger
        // This will cause filteredPlayers and teamOverviewContent to recalculate 
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.refreshTrigger = UUID()
            }
            if debugLogs { print("🔄 Refresh trigger updated: \(self.refreshTrigger)") }
        }
    }
    
    // Start League button removed here to ensure only one CTA lives at the bottom of the roster page.
    
    /// Optimized depth quality calculation for 60-player rosters
    private func calculateDepthQuality60Player(allPlayers: [PlayerData]) -> Double {
        let sortedPlayers = allPlayers.sorted { $0.overall > $1.overall }
        
        // For 60-player rosters, consider depth in tiers
        let tier1Count = min(12, sortedPlayers.count) // Elite starters
        let tier2Count = min(20, sortedPlayers.count) // Quality depth
        let tier3Count = min(35, sortedPlayers.count) // Serviceable players
        
        let tier1Players = Array(sortedPlayers.prefix(tier1Count))
        let tier2Players = Array(sortedPlayers.prefix(tier2Count).dropFirst(tier1Count))
        let tier3Players = Array(sortedPlayers.prefix(tier3Count).dropFirst(tier2Count))
        
        // Calculate weighted depth score with higher base values
        let tier1Average = tier1Players.isEmpty ? 75.0 : Double(tier1Players.map { $0.overall }.reduce(0, +)) / Double(tier1Players.count)
        let tier2Average = tier2Players.isEmpty ? 70.0 : Double(tier2Players.map { $0.overall }.reduce(0, +)) / Double(tier2Players.count)
        let tier3Average = tier3Players.isEmpty ? 65.0 : Double(tier3Players.map { $0.overall }.reduce(0, +)) / Double(tier3Players.count)
        
        // Weight tiers appropriately for 60-player rosters
        let depthScore = (tier1Average * 0.5) + (tier2Average * 0.3) + (tier3Average * 0.2)
        
        // Normalize to 0-15 range for higher impact
        return (depthScore - 65.0) / 2.0
    }
    
    /// Optimized talent variance calculation for 60-player rosters
    private func calculateTalentVariance60Player(allPlayers: [PlayerData]) -> Double {
        guard allPlayers.count >= 10 else { return 0.0 }
        
        let overalls = allPlayers.map { Double($0.overall) }
        let average = overalls.reduce(0, +) / Double(overalls.count)
        let variance = overalls.map { pow($0 - average, 2) }.reduce(0, +) / Double(overalls.count)
        
        // Count elite and low-rated players adjusted for 60-player rosters
        let elitePlayers = allPlayers.filter { $0.overall >= 85 }.count
        let lowRatedPlayers = allPlayers.filter { $0.overall <= 55 }.count
        
        // Adjusted bonus system for 60-player rosters
        let baseVariance = sqrt(variance) * 1.8  // Slightly reduced impact
        let eliteBonus = Double(elitePlayers) * 1.2  // Reduced bonus for elite players
        let lowRatedPenalty = Double(lowRatedPlayers) * -0.6  // Reduced penalty
        
        return baseVariance + eliteBonus + lowRatedPenalty
    }
} 