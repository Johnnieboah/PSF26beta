import Foundation
import Combine

// MARK: - Notification Names
extension Notification.Name {
    static let playerDataDidChange = Notification.Name("playerDataDidChange")
}

// MARK: - Player Detail View State Manager
class PlayerDetailViewStateManager: ObservableObject {
    static let shared = PlayerDetailViewStateManager()
    
    let objectWillChange = ObservableObjectPublisher()
    
    private(set) var isPlayerDetailViewOpen = false {
        willSet {
            if newValue != isPlayerDetailViewOpen {
                objectWillChange.send()
            }
        }
    }
    
    private(set) var openPlayerDetailInfo: (teamLogoName: String, playerId: String)? {
        willSet {
            if newValue?.teamLogoName != openPlayerDetailInfo?.teamLogoName ||
               newValue?.playerId != openPlayerDetailInfo?.playerId {
                objectWillChange.send()
            }
        }
    }
    
    private var stateUpdateTask: Task<Void, Never>?
    
    private init() {}
    
    func setPlayerDetailOpen(teamLogoName: String, playerId: String) {
        // Cancel any pending state update
        stateUpdateTask?.cancel()
        
        // Don't reopen if already open for this player
        if isPlayerDetailViewOpen,
           let currentInfo = openPlayerDetailInfo,
           currentInfo.teamLogoName == teamLogoName,
           currentInfo.playerId == playerId {
            print("🔒 PlayerDetailViewStateManager: Already open for \(playerId)")
            return
        }
        
        // Update state immediately
        isPlayerDetailViewOpen = true
        openPlayerDetailInfo = (teamLogoName, playerId)
        print("🔒 PlayerDetailViewStateManager: Player detail opened for \(playerId) on \(teamLogoName)")
    }
    
    func setPlayerDetailClosed() {
        // Cancel any pending state update
        stateUpdateTask?.cancel()
        
        // Create a new task for state update
        stateUpdateTask = Task { @MainActor in
            // Don't close if already closed
            if !isPlayerDetailViewOpen {
                print("🔓 PlayerDetailViewStateManager: Already closed")
                return
            }
            
            // Small delay to allow for view transitions
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            guard !Task.isCancelled else { return }
            
            isPlayerDetailViewOpen = false
            openPlayerDetailInfo = nil
            print("🔓 PlayerDetailViewStateManager: Player detail closed")
        }
    }
}

// MARK: - Player Data Manager for File-Based Storage
@MainActor
class PlayerDataManager {
    static let shared = PlayerDataManager()
    // Toggle to enable verbose PlayerDataManager logs during debugging only
    static var verboseLogs: Bool = false
    
    private var playersDirectory: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let playersDir = documentsDirectory.appendingPathComponent("Players")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: playersDir.path) {
            try? FileManager.default.createDirectory(at: playersDir, withIntermediateDirectories: true)
        }
        
        return playersDir
    }
    
    private var playerCache: [String: [PlayerData]] = [:]
    private var lastCacheKey: String?
    
    // MARK: - Team Overall Rating Cache
    private var teamOverallCache: [String: (offense: Int, defense: Int, overall: Int)] = [:]
    
    private init() {}
    
    // MARK: - Cache Management
    
    /// Clears the entire cache - use sparingly
    func clearCache() {
        if Self.verboseLogs { print("🧹 Starting memory optimization") }
        playerCache.removeAll()
        teamOverallCache.removeAll()
        lastCacheKey = nil
        if Self.verboseLogs { print("✅ Memory optimization completed") }
    }
    
    /// Clears the cache for a specific team and league combination
    func clearCacheForTeam(teamLogoName: String, leagueId: UUID? = nil) {
        let cacheKey = getCacheKey(leagueId: leagueId, teamLogoName: teamLogoName)
        playerCache.removeValue(forKey: cacheKey)
        if Self.verboseLogs { print("🧹 Cleared cache for \(teamLogoName) (key: \(cacheKey))") }
    }
    
    /// Clears all cache entries
    func clearAllCache() {
        playerCache.removeAll()
        teamOverallCache.removeAll()
        if Self.verboseLogs { print("🧹 Cleared all player cache entries and team overall caches") }
    }
    
    /// Clears balanced roster cache for a specific team
    func clearBalancedRosterCache(for teamLogoName: String) {
        let balancedCacheKey = "\(teamLogoName)_balanced"
        playerCache.removeValue(forKey: balancedCacheKey)
        print("🧹 Cleared balanced roster cache for \(teamLogoName)")
    }
    
    /// Forces a refresh for teams that have empty cached data when master data becomes available
    func refreshEmptyCachedTeams() {
        guard MasterDataLoader.shared.isDataLoaded else {
            print("🔄 Master data not loaded yet - cannot refresh empty cached teams")
            return
        }
        
        var refreshedCount = 0
        for (cacheKey, players) in playerCache {
            // If the cached data is empty and this is for team selection (no league ID in key)
            if players.isEmpty && !cacheKey.contains("_") {
                let teamLogoName = cacheKey
                print("🔄 Refreshing empty cache for \(teamLogoName)")
                
                // Clear the empty cache entry
                playerCache.removeValue(forKey: cacheKey)
                
                // Clear team overall cache for this team since roster is changing
                clearTeamOverallCache(for: teamLogoName)
                
                // Force reload the data (this will now find the master data)
                let _ = getPlayers(for: teamLogoName, leagueId: nil, forceRefresh: true)
                refreshedCount += 1
            }
        }
        
        print("🔄 Refreshed \(refreshedCount) empty cached teams")
    }
    
    // MARK: - Cache Management
    
    /// Updates the cache for a specific team
    private func updateCacheForTeam(leagueId: UUID?, teamLogoName: String, players: [PlayerData]) {
        let cacheKey = getCacheKey(leagueId: leagueId, teamLogoName: teamLogoName)
        playerCache[cacheKey] = players
        if Self.verboseLogs { print("🔄 Cache updated for \(teamLogoName)") }
    }
    
    private func getCacheKey(leagueId: UUID?, teamLogoName: String) -> String {
        if let leagueId = leagueId {
            return "\(leagueId.uuidString)_\(teamLogoName)"
        }
        return teamLogoName
    }
    
    // MARK: - League Player Data Creation
    
    /// Creates and saves player data files for a league from master data
    func createLeaguePlayerData(leagueId: UUID, teamLogoName: String, isTrainingCamp: Bool = false) async throws {
        print("👥 Creating player data files for league \(leagueId.uuidString)")
        
        // Clear team overall cache for this team when creating league data
        // This ensures fresh calculations based on actual league rosters
        clearTeamOverallCache(for: teamLogoName)
        
        // Use CSV rosters as the only data source if available
        var finalPlayers: [EditablePlayerData] = []
        if let csvURL = ContractImporter.locateCSV() {
            let csvRosters = ContractImporter.buildRosters(from: csvURL)
            if let players = csvRosters[teamLogoName] {
                finalPlayers = players.map { p in
                    // Convert PlayerData → EditablePlayerData for persistence
                    createBasicEditablePlayerData(from: p, teamLogoName: teamLogoName)
                }
            }
        }
        
        // If CSV didn’t provide this team, fallback to master data (rare)
        if finalPlayers.isEmpty {
            // Load players from master data (wait for data to be loaded)
            let masterPlayers = await MasterDataLoader.shared.getPlayersAsync(for: teamLogoName)
            if masterPlayers.isEmpty { throw PlayerDataError.noMasterDataFound }
            let editablePlayers = masterPlayers.map { convertMasterPlayerToEditablePlayerData(masterPlayer: $0, teamLogoName: teamLogoName, leagueId: leagueId) }
            finalPlayers = editablePlayers
        }
        
        // Save to file (keep CSV roster counts intact; do not trim to 60)
        try savePlayersToFile(leagueId: leagueId, teamLogoName: teamLogoName, players: finalPlayers)
        
        // Clear cache for this team to ensure fresh data is loaded
        clearCacheForTeam(teamLogoName: teamLogoName, leagueId: leagueId)
        
        print("👥 ✅ Created player data file for \(teamLogoName): \(finalPlayers.count) players")
    }
    
    // MARK: - Phase 2: Roster Size Auditing and Balancing
    
    /// Audits current roster sizes and reports statistics
    private func auditAndBalanceRosterSizes(teamNames: [String]) {
        print("📊 Phase 2: Auditing roster sizes across all teams...")
        
        var rosterSizes: [String: Int] = [:]
        var totalPlayers = 0
        var minSize = Int.max
        var maxSize = 0
        
        // Audit current sizes from master data (before balancing)
        for teamName in teamNames {
            if teamName == "Free Agent" { continue } // Skip free agents
            
            let players = MasterDataLoader.shared.getPlayers(for: teamName)
            let size = players.count
            rosterSizes[teamName] = size
            totalPlayers += size
            minSize = min(minSize, size)
            maxSize = max(maxSize, size)
        }
        
        let nflTeamCount = teamNames.count - (teamNames.contains("Free Agent") ? 1 : 0)
        let averageSize = Double(totalPlayers) / Double(nflTeamCount)
        
        print("📊 Master Data Roster Size Analysis (Before Balancing):")
        print("   📈 Total NFL Teams: \(nflTeamCount)")
        print("   📈 Average Roster Size: \(String(format: "%.1f", averageSize))")
        print("   📈 Minimum Roster Size: \(minSize)")
        print("   📈 Maximum Roster Size: \(maxSize)")
        print("   📈 Target Size (Training Camp): 60")
        
        // Show teams that will need balancing
        let teamsNeedingPlayers = rosterSizes.filter { $0.value < 60 }.sorted { $0.value < $1.value }
        let teamsWithExcess = rosterSizes.filter { $0.value > 60 }.sorted { $0.value > $1.value }
        
        if !teamsNeedingPlayers.isEmpty {
            print("📊 Teams that will need players added (< 60):")
            for (team, size) in teamsNeedingPlayers {
                print("   🔴 \(team): \(size) players (will add \(60 - size))")
            }
        }
        
        if !teamsWithExcess.isEmpty {
            print("📊 Teams that will be trimmed (> 60):")
            for (team, size) in teamsWithExcess {
                print("   🟡 \(team): \(size) players (will trim \(size - 60))")
            }
        }
        
        let alreadyBalancedTeams = rosterSizes.filter { $0.value == 60 }.count
        print("📊 Teams already at target size (60 players): \(alreadyBalancedTeams)/\(nflTeamCount)")
        print("📊 Note: All teams will be balanced to exactly 60 players during training camp setup")
    }
    
    /// Audits roster sizes after balancing to verify all teams have exactly 60 players
    private func auditPostBalancingRosterSizes(teamNames: [String], leagueId: UUID) {
        print("📊 Phase 2: Post-Balancing Roster Size Verification...")
        
        var rosterSizes: [String: Int] = [:]
        var totalPlayers = 0
        var teamsAtTarget = 0
        var teamsNotAtTarget: [String] = []
        
        // Audit actual balanced roster sizes
        for teamName in teamNames {
            if teamName == "Free Agent" { continue } // Skip free agents
            
            do {
                let players = try loadPlayersFromFile(leagueId: leagueId, teamLogoName: teamName)
                let size = players.count
                rosterSizes[teamName] = size
                totalPlayers += size
                
                if size == 60 {
                    teamsAtTarget += 1
                } else {
                    teamsNotAtTarget.append("\(teamName): \(size) players")
                }
            } catch {
                print("📊 ❌ Failed to audit \(teamName): \(error)")
                teamsNotAtTarget.append("\(teamName): Error loading data")
            }
        }
        
        let nflTeamCount = teamNames.count - (teamNames.contains("Free Agent") ? 1 : 0)
        let averageSize = Double(totalPlayers) / Double(nflTeamCount)
        
        print("📊 Post-Balancing Roster Size Analysis:")
        print("   📈 Total NFL Teams: \(nflTeamCount)")
        print("   📈 Average Roster Size: \(String(format: "%.1f", averageSize))")
        print("   📈 Teams at Target (60 players): \(teamsAtTarget)/\(nflTeamCount)")
        
        if !teamsNotAtTarget.isEmpty {
            print("📊 Teams NOT at target size:")
            for team in teamsNotAtTarget {
                print("   🔴 \(team)")
            }
        } else {
            print("📊 ✅ All teams successfully balanced to 60 players!")
        }
    }
    
    /// Balances a team's roster to exactly 60 players for training camp
    private func balanceRosterTo60Players(players: [EditablePlayerData], teamLogoName: String, leagueId: UUID) -> [EditablePlayerData] {
        let currentCount = players.count
        let targetCount = 60
        
        if currentCount == targetCount {
            print("   ✅ \(teamLogoName): Already balanced at \(currentCount) players")
            return players
        } else if currentCount > targetCount {
            // Trim excess players (keep the best ones)
            let trimmedPlayers = trimRosterToSize(players: players, targetSize: targetCount)
            print("   ✂️ \(teamLogoName): Trimmed from \(currentCount) to \(trimmedPlayers.count) players")
            return trimmedPlayers
        } else {
            // Add players to reach 60
            let playersNeeded = targetCount - currentCount
            let expandedPlayers = expandRosterToSize(players: players, targetSize: targetCount, teamLogoName: teamLogoName, leagueId: leagueId)
            print("   ➕ \(teamLogoName): Expanded from \(currentCount) to \(expandedPlayers.count) players (added \(playersNeeded))")
            return expandedPlayers
        }
    }
    
    /// Balances a team's roster to exactly 53 players for regular season
    private func balanceRosterTo53Players(players: [EditablePlayerData], teamLogoName: String, leagueId: UUID) -> [EditablePlayerData] {
        let currentCount = players.count
        let targetCount = 53
        
        if currentCount == targetCount {
            print("   ✅ \(teamLogoName): Already balanced at \(currentCount) players")
            return players
        } else if currentCount > targetCount {
            // Trim excess players (keep the best ones)
            let trimmedPlayers = trimRosterToSize(players: players, targetSize: targetCount)
            print("   ✂️ \(teamLogoName): Trimmed from \(currentCount) to \(trimmedPlayers.count) players")
            return trimmedPlayers
        } else {
            // Add players to reach 53
            let playersNeeded = targetCount - currentCount
            let expandedPlayers = expandRosterToSize(players: players, targetSize: targetCount, teamLogoName: teamLogoName, leagueId: leagueId)
            print("   ➕ \(teamLogoName): Expanded from \(currentCount) to \(expandedPlayers.count) players (added \(playersNeeded))")
            return expandedPlayers
        }
    }
    
    /// Trims roster to target size while maintaining position balance
    private func trimRosterToSize(players: [EditablePlayerData], targetSize: Int) -> [EditablePlayerData] {
        guard players.count > targetSize else { return players }
        
        let idealDistribution = getIdealPositionDistribution()
        var result: [EditablePlayerData] = []
        
        // Group players by position and sort each group by overall rating
        let playersByPosition = Dictionary(grouping: players) { $0.position }
            .mapValues { $0.sorted { $0.overall > $1.overall } }
        
        // First, ensure we have minimum essential players at critical positions
        let criticalPositions = ["QB", "K", "P"] // Must have at least 1 of each
        for position in criticalPositions {
            if let positionPlayers = playersByPosition[position], !positionPlayers.isEmpty {
                result.append(positionPlayers[0]) // Take the best player at this position
            }
        }
        
        // Then fill based on ideal distribution, taking best available at each position
        for (position, idealCount) in idealDistribution.sorted(by: { $0.value > $1.value }) {
            guard let positionPlayers = playersByPosition[position] else { continue }
            
            let currentCount = result.filter { $0.position == position }.count
            let needed = min(idealCount - currentCount, positionPlayers.count - currentCount)
            
            if needed > 0 && result.count + needed <= targetSize {
                let startIndex = currentCount
                let endIndex = min(startIndex + needed, positionPlayers.count)
                result.append(contentsOf: positionPlayers[startIndex..<endIndex])
            }
        }
        
        // If we still have room, fill with best remaining players
        let remainingPlayers = players.filter { player in
            !result.contains { $0.id == player.id }
        }.sorted { $0.overall > $1.overall }
        
        let remainingSlots = targetSize - result.count
        if remainingSlots > 0 {
            result.append(contentsOf: remainingPlayers.prefix(remainingSlots))
        }
        
        // Debug logging for position distribution
        let finalDistribution = Dictionary(grouping: result) { $0.position }
            .mapValues { $0.count }
            .sorted { $0.key < $1.key }
        print("🏈 Trimmed roster position distribution: \(finalDistribution.map { "\($0.key):\($0.value)" }.joined(separator: ", "))")
        
        return result
    }
    
    /// Expands roster to target size by generating additional players
    private func expandRosterToSize(players: [EditablePlayerData], targetSize: Int, teamLogoName: String, leagueId: UUID) -> [EditablePlayerData] {
        let playersNeeded = targetSize - players.count
        guard playersNeeded > 0 else { return players }
        
        // Analyze current roster composition to generate appropriate players
        let positionCounts = Dictionary(grouping: players, by: { $0.position })
            .mapValues { $0.count }
        
        // Generate additional players based on typical NFL roster needs
        var additionalPlayers: [EditablePlayerData] = []
        let targetPositionDistribution = getIdealPositionDistribution()
        
        // Calculate which positions need more players
        var positionsToAdd: [String] = []
        for (position, idealCount) in targetPositionDistribution {
            let currentCount = positionCounts[position] ?? 0
            let needed = max(0, idealCount - currentCount)
            for _ in 0..<needed {
                positionsToAdd.append(position)
            }
        }
        
        // If we still need more players, add depth players deterministically
        var depthIndex = 0
        while positionsToAdd.count < playersNeeded {
            // Add realistic depth positions prioritized by NFL importance
            let depthPositions = ["WR", "CB", "EDGE", "RB", "LT", "MLB", "DE", "TE", "DT", "SS"]
            let teamSeed = abs(teamLogoName.hashValue)
            let positionIndex = (teamSeed + depthIndex) % depthPositions.count
            positionsToAdd.append(depthPositions[positionIndex])
            depthIndex += 1
        }
        
        // Generate the needed players
        for i in 0..<playersNeeded {
            let position = positionsToAdd[i]
            let generatedPlayer = generateAdditionalPlayer(
                position: position,
                teamLogoName: teamLogoName,
                leagueId: leagueId,
                existingPlayers: players + additionalPlayers
            )
            additionalPlayers.append(generatedPlayer)
        }
        
        let finalRoster = players + additionalPlayers
        
        // Debug logging for position distribution
        let finalDistribution = Dictionary(grouping: finalRoster) { $0.position }
            .mapValues { $0.count }
            .sorted { $0.key < $1.key }
        print("🏈 Expanded roster position distribution: \(finalDistribution.map { "\($0.key):\($0.value)" }.joined(separator: ", "))")
        
        return finalRoster
    }
    
    /// Returns ideal position distribution for a 60-player training camp roster
    /// Based on realistic NFL training camp roster composition
    private func getIdealPositionDistribution() -> [String: Int] {
        return [
            // Offense (30 players)
            "QB": 3,     // Starter + 2 backups (critical position)
            "RB": 4,     // 2 starters + 2 backups 
            "FB": 1,     // Fullback (specialist)
            "WR": 6,     // 3 starters + 3 depth (reduced from 10)
            "TE": 3,     // 1 starter + 2 backups
            "LT": 2, "LG": 2, "C": 2, "RG": 2, "RT": 2,  // O-line depth (10 total)
            
            // Defense (28 players)
            "DE": 4,     // 2 starters + 2 backups
            "DT": 4,     // 2 starters + 2 backups
            "MLB": 3,    // 1 starter + 2 backups
            "ROLB": 2, "LOLB": 2,  // Outside linebackers
            "CB": 5,     // 2 starters + 3 depth (reduced from 8)
            "SS": 2, "FS": 2,  // Safeties
            "EDGE": 4,   // Edge rushers (important in modern NFL)
            
            // Special Teams (2 players)
            "K": 1,      // Kicker
            "P": 1       // Punter
        ]
        // Total: 3+4+1+6+3+10+4+4+3+2+2+5+2+2+4+1+1 = 57 players
        // Remaining 3 slots will be filled by depth positions in expandRosterToSize
    }
    
    /// Generates an additional player for roster expansion
    private func generateAdditionalPlayer(position: String, teamLogoName: String, leagueId: UUID, existingPlayers: [EditablePlayerData]) -> EditablePlayerData {
        // Get used jersey numbers
        let usedNumbers = Set(existingPlayers.map { $0.number })
        
        // Generate deterministic seed based on team name, position, and existing player count
        let teamSeed = abs(teamLogoName.hashValue)
        let positionSeed = abs(position.hashValue)
        let playerCountSeed = existingPlayers.count
        let combinedSeed = teamSeed &+ positionSeed &+ playerCountSeed
        
        // Generate position-appropriate jersey number deterministically
        let positionRanges: [String: [Int]] = [
            "QB": Array(1...19),
            "RB": Array(20...49),
            "FB": Array(20...49),
            "WR": Array(10...19) + Array(80...89),
            "TE": Array(80...89),
            "LT": Array(70...79), "LG": Array(60...79), "C": Array(50...79), "RG": Array(60...79), "RT": Array(70...79),
            "DT": Array(50...79) + Array(90...99),
            "DE": Array(50...79) + Array(90...99),
            "ROLB": Array(40...59) + Array(90...99), "MLB": Array(40...59) + Array(90...99), "LOLB": Array(40...59) + Array(90...99),
            "EDGE": Array(40...59) + Array(90...99),
            "CB": Array(20...49), "SS": Array(20...49), "FS": Array(20...49),
            "K": Array(1...19), "P": Array(1...19)
        ]
        
        let availableNumbers = positionRanges[position] ?? Array(1...99)
        var jerseyNumber = 0
        
        // Try position-appropriate numbers first
        for number in availableNumbers {
            if !usedNumbers.contains(number) {
                jerseyNumber = number
                break
            }
        }
        
        // If no position-appropriate number available, find any available number
        if jerseyNumber == 0 {
            for number in 1...99 {
                if !usedNumbers.contains(number) {
                    jerseyNumber = number
                    break
                }
            }
        }
        
        // Final fallback (should rarely happen)
        if jerseyNumber == 0 {
            jerseyNumber = 100
        }
        
        // Generate realistic names deterministically with larger pool
        let firstNames = [
            "Marcus", "Jaylen", "DeAndre", "Cameron", "Tyler", "Jordan", "Brandon", "Isaiah", "Antonio", "Xavier",
            "Malik", "Darius", "Terrell", "Jamal", "Andre", "Kevin", "Michael", "Chris", "David", "Robert",
            "James", "William", "Charles", "Anthony", "Joshua", "Daniel", "Matthew", "Ryan", "Aaron", "Justin",
            "Corey", "Derek", "Eric", "Frank", "George", "Harold", "Ivan", "Jacob", "Keith", "Larry",
            "Nathan", "Oscar", "Patrick", "Quincy", "Raymond", "Samuel", "Timothy", "Victor", "Walter", "Zachary"
        ]
        let lastNames = [
            "Johnson", "Williams", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor", "Anderson", "Jackson",
            "Thompson", "White", "Harris", "Martin", "Garcia", "Martinez", "Robinson", "Clark", "Rodriguez", "Lewis",
            "Lee", "Walker", "Hall", "Allen", "Young", "Hernandez", "King", "Wright", "Lopez", "Hill",
            "Scott", "Green", "Adams", "Baker", "Gonzalez", "Nelson", "Carter", "Mitchell", "Perez", "Roberts",
            "Turner", "Phillips", "Campbell", "Parker", "Evans", "Edwards", "Collins", "Stewart", "Sanchez", "Morris"
        ]
        
        // Generate unique name by checking existing players
        let existingNames = Set(existingPlayers.map { "\($0.firstName) \($0.lastName)" })
        var firstName: String
        var lastName: String
        var fullName: String
        var nameAttempts = 0
        
        repeat {
            let firstNameIndex = abs(combinedSeed &+ nameAttempts) % firstNames.count
            let lastNameIndex = abs(combinedSeed &+ nameAttempts &+ 1) % lastNames.count
            firstName = firstNames[firstNameIndex]
            lastName = lastNames[lastNameIndex]
            fullName = "\(firstName) \(lastName)"
            nameAttempts += 1
                 } while existingNames.contains(fullName) && nameAttempts < 100
        
        // Debug logging for generated players
        print("🏈 Generated player: \(firstName) \(lastName) #\(jerseyNumber) (\(position)) for \(teamLogoName)")
        
        // Generate consistent attributes based on name hash
        let playerSeed = hashPlayerName(firstName, lastName)
        func generateAttribute(base: Int = 65, importance: Double = 1.0) -> Int {
            let attributeSeed = playerSeed &+ Int(importance * 1000)
            let pseudoRandom = (attributeSeed &* 9301 &+ 49297) % 233280
            let normalizedValue = Double(pseudoRandom) / 233280.0
            let adjustedBase = Int(Double(base) * importance)
            let variation = Int((normalizedValue - 0.5) * 20) // Smaller variation for generated players
            return max(45, min(80, adjustedBase + variation)) // Lower ceiling for generated players
        }
        
        // Generate age deterministically (typically younger for depth players)
        let age = 22 + (abs(combinedSeed &+ 2) % 7) // Age 22-28
        
        return EditablePlayerData(
            id: UUID(),
            firstName: firstName,
            lastName: lastName,
            position: position,
            number: jerseyNumber,
            age: age,
            college: "State University", // Generic college
            height: "6'0\"", // Generic height
            weight: "200", // Generic weight
            yearsPro: max(0, age - 22),
            teamLogoName: teamLogoName,
            leagueId: leagueId,
            isEdited: false,
            lastModified: Date(),
            // Core attributes
            speed: generateAttribute(base: 65, importance: 1.0),
            agility: generateAttribute(base: 65, importance: 1.0),
            awareness: generateAttribute(base: 65, importance: 1.0),
            strength: generateAttribute(base: 65, importance: 1.0),
            stamina: generateAttribute(base: 70, importance: 1.0),
            injury: generateAttribute(base: 75, importance: 1.0),
            // Offensive attributes
            carrying: generateAttribute(base: 60, importance: 1.0),
            trucking: generateAttribute(base: 60, importance: 1.0),
            catching: generateAttribute(base: 60, importance: 1.0),
            breakTackle: generateAttribute(base: 60, importance: 1.0),
            jukeMove: generateAttribute(base: 60, importance: 1.0),
            spinMove: generateAttribute(base: 60, importance: 1.0),
            stiffArm: generateAttribute(base: 60, importance: 1.0),
            acceleration: generateAttribute(base: 65, importance: 1.0),
            changeOfDirection: generateAttribute(base: 65, importance: 1.0),
            // Quarterback attributes
            throwPower: generateAttribute(base: 55, importance: 1.0),
            throwAccuracyShort: generateAttribute(base: 55, importance: 1.0),
            throwAccuracyMid: generateAttribute(base: 55, importance: 1.0),
            throwAccuracyDeep: generateAttribute(base: 55, importance: 1.0),
            throwOnTheRun: generateAttribute(base: 55, importance: 1.0),
            throwUnderPressure: generateAttribute(base: 55, importance: 1.0),
            playAction: generateAttribute(base: 55, importance: 1.0),
            // Defensive attributes
            tackle: generateAttribute(base: 60, importance: 1.0),
            blockShedding: generateAttribute(base: 60, importance: 1.0),
            zoneCoverage: generateAttribute(base: 60, importance: 1.0),
            manCoverage: generateAttribute(base: 60, importance: 1.0),
            pursuit: generateAttribute(base: 60, importance: 1.0),
            finesseMoves: generateAttribute(base: 60, importance: 1.0),
            powerMoves: generateAttribute(base: 60, importance: 1.0),
            press: generateAttribute(base: 60, importance: 1.0),
            jumping: generateAttribute(base: 65, importance: 1.0),
            playRecognition: generateAttribute(base: 60, importance: 1.0),
            hitPower: generateAttribute(base: 60, importance: 1.0),
            toughness: generateAttribute(base: 65, importance: 1.0),
            // Offensive line attributes
            passBlock: generateAttribute(base: 60, importance: 1.0),
            runBlock: generateAttribute(base: 60, importance: 1.0),
            impactBlocking: generateAttribute(base: 60, importance: 1.0),
            passBlockPower: generateAttribute(base: 60, importance: 1.0),
            runBlockPower: generateAttribute(base: 60, importance: 1.0),
            passBlockFinesse: generateAttribute(base: 60, importance: 1.0),
            runBlockFinesse: generateAttribute(base: 60, importance: 1.0),
            // Receiving attributes
            release: generateAttribute(base: 60, importance: 1.0),
            catchInTraffic: generateAttribute(base: 60, importance: 1.0),
            spectacularCatch: generateAttribute(base: 60, importance: 1.0),
            shortRouteRunning: generateAttribute(base: 60, importance: 1.0),
            mediumRouteRunning: generateAttribute(base: 60, importance: 1.0),
            deepRouteRunning: generateAttribute(base: 60, importance: 1.0),
            // Special teams attributes
            kickPower: generateAttribute(base: 55, importance: 1.0),
            kickAccuracy: generateAttribute(base: 55, importance: 1.0),
            // Additional attributes
            bCVision: generateAttribute(base: 60, importance: 1.0),
            // Salary cap properties (using default values)
            salary: 0,
            contract: nil,
            isRookiePlayer: false,
            draftPickNumber: nil,
            draftYearValue: nil,
            contractYearsLeft: 0,
            // Calculate overall for generated players (lower range)
            overall: 45 + (abs(combinedSeed) % 25) // Range 45-70 for generated players
        )
    }
    
    /// Creates player data files for all teams in a league
    func createAllTeamsPlayerData(leagueId: UUID, isTrainingCamp: Bool = false) async throws {
        print("👥 Creating player data files for all teams in league \(leagueId.uuidString) (Training Camp: \(isTrainingCamp))")
        
        // Clear all cache to ensure fresh data is loaded
        clearAllCache()
        
        // Clear all team overall caches to ensure fresh calculations for league play
        clearAllTeamOverallCache()
        
        // Force delete existing player data files for this league to ensure clean slate
        deleteExistingPlayerDataFiles(leagueId: leagueId)
        
        let allTeamNames = MasterDataLoader.shared.getAvailableTeams()
        print("👥 Teams to process: \(allTeamNames)")
        
        // Skip auditing/balancing; respect imported roster sizes
        
        var successCount = 0
        
        for teamName in allTeamNames {
            do {
                print("👥 Processing team: \(teamName)")
                try await createLeaguePlayerData(leagueId: leagueId, teamLogoName: teamName, isTrainingCamp: isTrainingCamp)
                successCount += 1
                if teamName == "Free Agent" {
                    print("📦 ✅ Free Agent team data created successfully")
                }
            } catch {
                print("👥 ⚠️ Failed to create player data for \(teamName): \(error)")
                if teamName == "Free Agent" {
                    print("📦 ❌ Failed to create Free Agent team data")
                }
            }
        }
        
        print("👥 ✅ Created player data files for \(successCount)/\(allTeamNames.count) teams")
        
        // Skip post-balancing audit
    }
    
    /// Forces recreation of player data files for an existing league
    func forceRecreatePlayerData(leagueId: UUID, isTrainingCamp: Bool = false) async throws {
        print("🔄 Force recreating player data files for league \(leagueId.uuidString)")
        
        // Clear all cache
        clearAllCache()
        
        // Delete existing files
        deleteExistingPlayerDataFiles(leagueId: leagueId)
        
        // Recreate all player data
        try await createAllTeamsPlayerData(leagueId: leagueId, isTrainingCamp: isTrainingCamp)
        
        print("🔄 ✅ Force recreation complete")
    }
    
    // MARK: - File Operations
    
    private func getPlayerDataFilePath(leagueId: UUID, teamLogoName: String) -> URL {
        return playersDirectory.appendingPathComponent("league_\(leagueId.uuidString)_\(teamLogoName).json")
    }
    
    /// Deletes all existing player data files for a specific league
    private func deleteExistingPlayerDataFiles(leagueId: UUID) {
        print("🗑️ Deleting existing player data files for league \(leagueId.uuidString)")
        
        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(at: playersDirectory, includingPropertiesForKeys: nil)
            
            let leagueFiles = files.filter { $0.lastPathComponent.hasPrefix("league_\(leagueId.uuidString)_") }
            
            for file in leagueFiles {
                try fileManager.removeItem(at: file)
                print("🗑️ Deleted: \(file.lastPathComponent)")
            }
            
            print("🗑️ Deleted \(leagueFiles.count) existing player data files")
        } catch {
            print("🗑️ ⚠️ Error deleting existing player data files: \(error)")
        }
    }
    
    private func savePlayersToFile(leagueId: UUID, teamLogoName: String, players: [EditablePlayerData]) throws {
        let fileURL = getPlayerDataFilePath(leagueId: leagueId, teamLogoName: teamLogoName)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(players)
        try data.write(to: fileURL)
    }
    
    // MARK: - Data Loading
    
    /// Loads player data from file for a specific team in a league
    func loadPlayersFromFile(leagueId: UUID, teamLogoName: String) throws -> [EditablePlayerData] {
        let fileURL = getPlayerDataFilePath(leagueId: leagueId, teamLogoName: teamLogoName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw PlayerDataError.fileNotFound
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([EditablePlayerData].self, from: data)
    }
    
    /// Checks if player data file exists for a team in a league
    func playerDataExists(leagueId: UUID, teamLogoName: String) -> Bool {
        let fileURL = getPlayerDataFilePath(leagueId: leagueId, teamLogoName: teamLogoName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    // MARK: - Player Data Access
    
    /// Gets players for a team, using cache when available
    func getPlayers(for teamLogoName: String, leagueId: UUID? = nil, forceRefresh: Bool = false) -> [PlayerData] {
        let cacheKey = getCacheKey(leagueId: leagueId, teamLogoName: teamLogoName)
        
        // Check cache first (unless force refresh is requested)
        if !forceRefresh, let cachedPlayers = playerCache[cacheKey] {
            if Self.verboseLogs {
                print("👥 📋 Loaded \(cachedPlayers.count) players from cache for \(teamLogoName) (cache key: \(cacheKey))")
            }
            return cachedPlayers
        }
        
        // If we're in training camp and the cached data has wrong number of players, force refresh
        if let cachedPlayers = playerCache[cacheKey], 
           let leagueId = leagueId,
           cachedPlayers.count != 60 && cachedPlayers.count != 53 {
            print("👥 ⚠️ Cached data has wrong roster size (\(cachedPlayers.count) players) - forcing refresh")
            clearCacheForTeam(teamLogoName: teamLogoName, leagueId: leagueId)
        }

        var resultPlayers: [PlayerData] = []
        
        // Try loading from file if league context is available
        if let leagueId = leagueId {
            do {
                let editablePlayers = try loadPlayersFromFile(leagueId: leagueId, teamLogoName: teamLogoName)
                resultPlayers = editablePlayers.map { $0.toPlayerData() }
                if Self.verboseLogs { print("👥 📄 Loaded \(resultPlayers.count) players from file for \(teamLogoName)") }
            } catch {
                print("👥 ❌ Failed to load players from file: \(error)")
            }
        }
        
        // Fallback to master data if no players found
        if resultPlayers.isEmpty {
            // Check if there's a balanced roster from team selection that we can use
            let balancedCacheKey = "\(teamLogoName)_balanced"
            if let balancedPlayers = playerCache[balancedCacheKey] {
                print("👥 🔄 Using balanced roster from team selection for league creation: \(teamLogoName) (\(balancedPlayers.count) players)")
                resultPlayers = balancedPlayers
            }
            
            // For team selection (no league context), check if master data is loaded
            if resultPlayers.isEmpty && leagueId == nil && !MasterDataLoader.shared.isDataLoaded {
                print("👥 ⏳ Master data not loaded yet for team selection - returning empty array without caching")
                // Don't cache empty results when master data isn't ready
                // Post notification to trigger UI refresh when data becomes available
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: NSNotification.Name("MasterDataLoaded"), object: nil)
                }
                return []
            }
            
            if resultPlayers.isEmpty {
                let masterPlayers = MasterDataLoader.shared.getPlayers(for: teamLogoName)
                if !masterPlayers.isEmpty {
                resultPlayers = masterPlayers.map { player in
                    PlayerData(
                        firstName: player.firstName,
                        lastName: player.lastName,
                        position: player.position,
                        number: Int(player.jerseyNum) ?? 1,
                        overall: player.overallInt,
                        age: player.ageInt,
                        actualSalary: player.actualSalary
                    )
                }
                if Self.verboseLogs { print("👥 📊 Loaded \(resultPlayers.count) players from master data for \(teamLogoName)") }
                
                // If this is for team selection (no leagueId), ensure we have a reasonable number of players
                if leagueId == nil && resultPlayers.count < 50 {
                    if Self.verboseLogs {
                        print("👥 ⚠️ Master data for \(teamLogoName) has only \(resultPlayers.count) players - this may be incomplete")
                        print("   📋 Real players found: \(resultPlayers.prefix(3).map { "\($0.firstName) \($0.lastName) (\($0.position))" })")
                        print("   🔧 Will expand roster using PlayerDataManager.getBalancedPlayersForTeamSelection()")
                    }
                }
                } else {
                    if Self.verboseLogs { print("👥 ⚠️ No player data found for \(teamLogoName)") }
                }
            }
        }
        
        // Only cache the result if we have actual data or if master data is loaded
        // This prevents caching empty results when master data isn't ready yet
        if !resultPlayers.isEmpty || MasterDataLoader.shared.isDataLoaded {
            updateCacheForTeam(leagueId: leagueId, teamLogoName: teamLogoName, players: resultPlayers)
        } else {
            if Self.verboseLogs { print("👥 🚫 Not caching empty result for \(teamLogoName) - master data not loaded yet") }
        }
        
        return resultPlayers
    }
    
    /// Gets players for team selection without altering roster size
    /// Keeps full roster (e.g., 74 from CSV/master) for selection display
    func getBalancedPlayersForTeamSelection(for teamLogoName: String) -> [PlayerData] {
        let balancedCacheKey = "\(teamLogoName)_balanced"
        if let cached = playerCache[balancedCacheKey] {
            print("👥 📋 Using cached selection roster for \(teamLogoName) (\(cached.count) players)")
            return cached
        }

        // STRICT: Use CSV rosters ONLY for selection
        var players: [PlayerData] = []
        if let csvURL = ContractImporter.locateCSV() {
            let csvRosters = ContractImporter.buildRosters(from: csvURL)
            if let csvPlayers = csvRosters[teamLogoName] {
                players = csvPlayers
            }
        }

        print("👥 📊 Team selection: \(teamLogoName) using \(players.count) players (no trimming)")
        playerCache[balancedCacheKey] = players
        print("👥 💾 Cached selection roster for \(teamLogoName)")
        return players
    }
    
    /// Creates a basic EditablePlayerData from PlayerData with default attribute values
    private func createBasicEditablePlayerData(from player: PlayerData, teamLogoName: String) -> EditablePlayerData {
        let tempLeagueId = UUID() // Temporary ID for team selection
        
        // Generate consistent attributes based on player name
        let playerSeed = hashPlayerName(player.firstName, player.lastName)
        func generateAttribute(base: Int = 70, importance: Double = 1.0) -> Int {
            let attributeSeed = playerSeed &+ Int(importance * 1000)
            let pseudoRandom = (attributeSeed &* 9301 &+ 49297) % 233280
            let normalizedValue = Double(pseudoRandom) / 233280.0
            let adjustedBase = Int(Double(base) * importance)
            let variation = Int((normalizedValue - 0.5) * 20)
            return max(40, min(95, adjustedBase + variation))
        }
        
        return EditablePlayerData(
            id: player.id,
            firstName: player.firstName,
            lastName: player.lastName,
            position: player.position,
            number: player.number,
            age: player.age,
            college: "State University",
            height: "6'0\"",
            weight: "200",
            yearsPro: max(0, player.age - 22),
            teamLogoName: teamLogoName,
            leagueId: tempLeagueId,
            isEdited: false,
            lastModified: Date(),
            // Core attributes
            speed: generateAttribute(base: 70, importance: 1.0),
            agility: generateAttribute(base: 70, importance: 1.0),
            awareness: generateAttribute(base: 70, importance: 1.0),
            strength: generateAttribute(base: 70, importance: 1.0),
            stamina: generateAttribute(base: 75, importance: 1.0),
            injury: generateAttribute(base: 80, importance: 1.0),
            // Offensive attributes
            carrying: generateAttribute(base: 65, importance: 1.0),
            trucking: generateAttribute(base: 65, importance: 1.0),
            catching: generateAttribute(base: 65, importance: 1.0),
            breakTackle: generateAttribute(base: 65, importance: 1.0),
            jukeMove: generateAttribute(base: 65, importance: 1.0),
            spinMove: generateAttribute(base: 65, importance: 1.0),
            stiffArm: generateAttribute(base: 65, importance: 1.0),
            acceleration: generateAttribute(base: 70, importance: 1.0),
            changeOfDirection: generateAttribute(base: 70, importance: 1.0),
            // Quarterback attributes
            throwPower: generateAttribute(base: 60, importance: 1.0),
            throwAccuracyShort: generateAttribute(base: 60, importance: 1.0),
            throwAccuracyMid: generateAttribute(base: 60, importance: 1.0),
            throwAccuracyDeep: generateAttribute(base: 60, importance: 1.0),
            throwOnTheRun: generateAttribute(base: 60, importance: 1.0),
            throwUnderPressure: generateAttribute(base: 60, importance: 1.0),
            playAction: generateAttribute(base: 60, importance: 1.0),
            // Defensive attributes
            tackle: generateAttribute(base: 65, importance: 1.0),
            blockShedding: generateAttribute(base: 65, importance: 1.0),
            zoneCoverage: generateAttribute(base: 65, importance: 1.0),
            manCoverage: generateAttribute(base: 65, importance: 1.0),
            pursuit: generateAttribute(base: 65, importance: 1.0),
            finesseMoves: generateAttribute(base: 65, importance: 1.0),
            powerMoves: generateAttribute(base: 65, importance: 1.0),
            press: generateAttribute(base: 65, importance: 1.0),
            jumping: generateAttribute(base: 65, importance: 1.0),
            playRecognition: generateAttribute(base: 65, importance: 1.0),
            hitPower: generateAttribute(base: 65, importance: 1.0),
            toughness: generateAttribute(base: 70, importance: 1.0),
            // Offensive line attributes
            passBlock: generateAttribute(base: 65, importance: 1.0),
            runBlock: generateAttribute(base: 65, importance: 1.0),
            impactBlocking: generateAttribute(base: 65, importance: 1.0),
            passBlockPower: generateAttribute(base: 65, importance: 1.0),
            runBlockPower: generateAttribute(base: 65, importance: 1.0),
            passBlockFinesse: generateAttribute(base: 65, importance: 1.0),
            runBlockFinesse: generateAttribute(base: 65, importance: 1.0),
            // Receiving attributes
            release: generateAttribute(base: 65, importance: 1.0),
            catchInTraffic: generateAttribute(base: 65, importance: 1.0),
            spectacularCatch: generateAttribute(base: 65, importance: 1.0),
            shortRouteRunning: generateAttribute(base: 65, importance: 1.0),
            mediumRouteRunning: generateAttribute(base: 65, importance: 1.0),
            deepRouteRunning: generateAttribute(base: 65, importance: 1.0),
            // Special teams attributes
            kickPower: generateAttribute(base: 60, importance: 1.0),
            kickAccuracy: generateAttribute(base: 60, importance: 1.0),
            // Additional attributes
            bCVision: generateAttribute(base: 65, importance: 1.0),
            // Salary and contract (defaults)
            salary: player.actualSalary ?? 0,
            contract: nil,
            isRookiePlayer: false,
            draftPickNumber: nil,
            draftYearValue: nil,
            contractYearsLeft: 0,
            // Use the original player's overall rating
            overall: player.overall
        )
    }
    
    // MARK: - Player Editing
    
    /// Updates a player's data and saves to file
    func updatePlayer(leagueId: UUID, teamLogoName: String, playerId: UUID, updates: PlayerDataUpdates) throws {
        var players = try loadPlayersFromFile(leagueId: leagueId, teamLogoName: teamLogoName)
        
        guard let playerIndex = players.firstIndex(where: { $0.id == playerId }) else {
            throw PlayerDataError.playerNotFound
        }
        
        // Apply updates
        players[playerIndex].applyUpdates(updates)
        
        // Save back to file
        try savePlayersToFile(leagueId: leagueId, teamLogoName: teamLogoName, players: players)
        
        // Update cache with converted PlayerData
        let updatedPlayerData = players.map { $0.toPlayerData() }
        updateCacheForTeam(leagueId: leagueId, teamLogoName: teamLogoName, players: updatedPlayerData)
        
        print("👥 ✅ Updated player \(players[playerIndex].fullName) in \(teamLogoName)")
    }
    
    /// Updates an entire player's data and saves to file
    func updateEntirePlayer(_ player: EditablePlayerData) async throws {
        var players = try loadPlayersFromFile(leagueId: player.leagueId, teamLogoName: player.teamLogoName)
        
        // Find player by number and position
        if let index = players.firstIndex(where: { existingPlayer in
            existingPlayer.number == player.number &&
            existingPlayer.position == player.position
        }) {
            // Update the player
            players[index] = player
            
            // Save to file
            try savePlayersToFile(
                leagueId: player.leagueId,
                teamLogoName: player.teamLogoName,
                players: players
            )
            
            // Update cache with converted PlayerData
            let updatedPlayerData = players.map { $0.toPlayerData() }
            updateCacheForTeam(leagueId: player.leagueId, teamLogoName: player.teamLogoName, players: updatedPlayerData)
            
            // Post notification
            NotificationCenter.default.post(
                name: .playerDataDidChange,
                object: nil,
                userInfo: [
                    "teamLogoName": player.teamLogoName,
                    "playerId": "\(player.firstName)_\(player.lastName)_\(player.number)"
                ]
            )
            
            print("👥 ✅ Updated entire player data for \(player.firstName) \(player.lastName)")
        } else {
            throw PlayerDataError.playerNotFound
        }
    }
    
    // MARK: - Cleanup
    
    /// Removes all player data files for a league
    func deleteLeaguePlayerData(leagueId: UUID) throws {
        let allTeamNames = MasterDataLoader.shared.getAvailableTeams()
        
        for teamName in allTeamNames {
            let fileURL = getPlayerDataFilePath(leagueId: leagueId, teamLogoName: teamName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
        
        print("👥 🗑️ Deleted all player data files for league \(leagueId.uuidString)")
    }
    
    // MARK: - Phase 6: System Validation & Optimization
    
    /// Validates the hybrid data system performance and provides health metrics
    func validateSystemHealth() -> SystemHealthReport {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var report = SystemHealthReport()
        
        // Check file system health
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let playersDir = documentsURL.appendingPathComponent("Players")
        
        if FileManager.default.fileExists(atPath: playersDir.path) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: playersDir, includingPropertiesForKeys: [.fileSizeKey])
                report.playerDataFilesCount = contents.count
                
                let totalSize = contents.compactMap { url in
                    try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
                }.reduce(0, +)
                
                report.totalStorageUsed = totalSize
                report.fileSystemHealthy = true
            } catch {
                report.fileSystemHealthy = false
                report.errors.append("File system error: \(error.localizedDescription)")
            }
        }
        
        // Test hybrid loading performance
        let testTeams = ["KansasCity", "Dallas", "Buffalo"] // Sample teams
        var hybridLoadTimes: [Double] = []
        
        for teamName in testTeams {
            let loadStart = CFAbsoluteTimeGetCurrent()
            let _ = getPlayers(for: teamName, leagueId: nil as UUID?) // Test with no league ID (master data fallback)
            let loadTime = CFAbsoluteTimeGetCurrent() - loadStart
            hybridLoadTimes.append(loadTime)
        }
        
        report.averageLoadTime = hybridLoadTimes.reduce(0, +) / Double(hybridLoadTimes.count)
        report.performanceHealthy = report.averageLoadTime < 0.1 // Should load in under 100ms
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        report.validationTime = totalTime
        
        // Log performance metrics
        print("🔍 Phase 6 System Health Report:")
        print("   📁 Player data files: \(report.playerDataFilesCount)")
        print("   💾 Storage used: \(String(format: "%.1f", Double(report.totalStorageUsed) / 1024 / 1024))MB")
        print("   ⚡ Average load time: \(String(format: "%.3f", report.averageLoadTime))s")
        print("   ✅ File system healthy: \(report.fileSystemHealthy)")
        print("   ⚡ Performance healthy: \(report.performanceHealthy)")
        print("   🕐 Validation completed in: \(String(format: "%.3f", totalTime))s")
        
        if !report.errors.isEmpty {
            print("   ⚠️ Errors found:")
            for error in report.errors {
                print("      - \(error)")
            }
        }
        
        return report
    }
    
    /// Optimizes the player data system by cleaning up orphaned files and optimizing storage
    func optimizeSystem(leagueIds: [UUID]) throws {
        print("🧹 Phase 6: Optimizing player data system...")
        
        let playersDir = playersDirectory
        guard FileManager.default.fileExists(atPath: playersDir.path) else {
            print("🧹 No player data directory found - system is clean")
            return
        }
        
        let allFiles = try FileManager.default.contentsOfDirectory(at: playersDir, includingPropertiesForKeys: nil)
        let playerDataFiles = allFiles.filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("league_") }
        
        var orphanedFiles: [URL] = []
        var totalCleaned = 0
        
        // Check for orphaned files (leagues that no longer exist)
        for file in playerDataFiles {
            let filename = file.lastPathComponent
            if let leagueIdString = extractLeagueId(from: filename),
               let leagueUUID = UUID(uuidString: leagueIdString) {
                if !leagueIds.contains(leagueUUID) {
                    orphanedFiles.append(file)
                }
            }
        }
        
        // Clean up orphaned files
        for orphanedFile in orphanedFiles {
            do {
                try FileManager.default.removeItem(at: orphanedFile)
                totalCleaned += 1
                print("🧹 Removed orphaned file: \(orphanedFile.lastPathComponent)")
            } catch {
                print("🧹 ⚠️ Failed to remove orphaned file \(orphanedFile.lastPathComponent): \(error)")
            }
        }
        
        print("🧹 ✅ System optimization complete:")
        print("   🗑️ Removed \(totalCleaned) orphaned files")
        print("   📁 \(playerDataFiles.count - totalCleaned) active files remaining")
    }
    
    private func extractLeagueId(from filename: String) -> String? {
        // Extract league ID from filename format: "league_UUID_TEAMNAME.json"
        let components = filename.components(separatedBy: "_")
        if components.count >= 2 {
            return components[1]
        }
        return nil
    }
    
    /// Generates a consistent hash value from a player's name for deterministic attribute generation
    private func hashPlayerName(_ firstName: String, _ lastName: String) -> Int {
        let fullName = "\(firstName)\(lastName)".lowercased()
        var hash = 5381
        for char in fullName.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(char)
        }
        return abs(hash)
    }
    
    /// Validates and cleans player names to ensure they contain only valid characters
    private func validatePlayerName(_ name: String) -> String {
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove any non-alphabetic characters except apostrophes and hyphens
        cleaned = cleaned.replacingOccurrences(of: #"[^\w\s\-\']"#, with: "", options: .regularExpression)
        
        // Remove any numbers
        cleaned = cleaned.replacingOccurrences(of: #"\d+"#, with: "", options: .regularExpression)
        
        // Clean up extra whitespace
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate final result
        let validNamePattern = #"^[A-Za-z\s\-\']+$"#
        if cleaned.isEmpty || cleaned.count < 2 || cleaned.range(of: validNamePattern, options: .regularExpression) == nil {
            // Generate fallback name based on original string
            let fallbackNames = ["John", "Mike", "Chris", "David", "Ryan", "Alex", "Matt", "Josh", "Nick", "Tom"]
            let hash = abs(name.hashValue)
            return fallbackNames[hash % fallbackNames.count]
        }
        
        return cleaned.capitalized
    }
    
    // MARK: - Team Overall Rating Cache Management
    
    /// Gets cached team overall ratings for team selection (ensures consistency)
    func getCachedTeamOverallRatings(for teamLogoName: String) -> (offense: Int, defense: Int, overall: Int)? {
        return teamOverallCache[teamLogoName]
    }
    
    /// Caches team overall ratings for consistent display during team selection
    func cacheTeamOverallRatings(for teamLogoName: String, ratings: (offense: Int, defense: Int, overall: Int)) {
        teamOverallCache[teamLogoName] = ratings
        print("📊 💾 Cached team overall ratings for \(teamLogoName): O:\(ratings.offense) D:\(ratings.defense) Overall:\(ratings.overall)")
    }
    
    /// Clears team overall rating cache for a specific team
    func clearTeamOverallCache(for teamLogoName: String) {
        teamOverallCache.removeValue(forKey: teamLogoName)
        print("🧹 Cleared team overall cache for \(teamLogoName)")
    }
    
    /// Clears all team overall rating caches
    func clearAllTeamOverallCache() {
        teamOverallCache.removeAll()
        print("🧹 Cleared all team overall rating caches")
    }

    // MARK: - Async File IO (Batched/Background)

    /// Writes a team's editable players file to disk off the main thread, atomically.
    /// - Parameters:
    ///   - players: Array of EditablePlayerData to persist
    ///   - leagueId: League identifier used in filename
    ///   - teamLogoName: Team key used in filename
    /// - Returns: The file URL written to
    func writePlayersToDisk(players: [EditablePlayerData], leagueId: UUID, teamLogoName: String) async throws -> URL {
        let playersDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Players")

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: playersDirectory.path) {
            try FileManager.default.createDirectory(at: playersDirectory, withIntermediateDirectories: true)
        }

        let fileURL = playersDirectory.appendingPathComponent("league_\(leagueId.uuidString)_\(teamLogoName).json")

        // Encode on a background thread
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let encoded = try encoder.encode(players)
                    continuation.resume(returning: encoded)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        // Write on a background thread atomically
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try data.write(to: fileURL, options: [.atomic])
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return fileURL
    }
}

// MARK: - Enhanced Player Data Model
struct EditablePlayerData: Codable, Identifiable {
    let id: UUID
    var firstName: String
    var lastName: String
    var position: String
    var number: Int
    var age: Int
    var college: String
    var height: String
    var weight: String
    var yearsPro: Int
    var teamLogoName: String
    let leagueId: UUID
    var isEdited: Bool
    var lastModified: Date
    
    // Individual Attributes
    // Core attributes
    var speed: Int
    var agility: Int
    var awareness: Int
    var strength: Int
    var stamina: Int
    var injury: Int
    
    // Offensive attributes
    var carrying: Int
    var trucking: Int
    var catching: Int
    var breakTackle: Int
    var jukeMove: Int
    var spinMove: Int
    var stiffArm: Int
    var acceleration: Int
    var changeOfDirection: Int
    
    // Quarterback attributes
    var throwPower: Int
    var throwAccuracyShort: Int
    var throwAccuracyMid: Int
    var throwAccuracyDeep: Int
    var throwOnTheRun: Int
    var throwUnderPressure: Int
    var playAction: Int
    
    // Defensive attributes
    var tackle: Int
    var blockShedding: Int
    var zoneCoverage: Int
    var manCoverage: Int
    var pursuit: Int
    var finesseMoves: Int
    var powerMoves: Int
    var press: Int
    var jumping: Int
    var playRecognition: Int
    var hitPower: Int
    var toughness: Int
    
    // Offensive line attributes
    var passBlock: Int
    var runBlock: Int
    var impactBlocking: Int
    var passBlockPower: Int
    var runBlockPower: Int
    var passBlockFinesse: Int
    var runBlockFinesse: Int
    
    // Receiving attributes
    var release: Int
    var catchInTraffic: Int
    var spectacularCatch: Int
    var shortRouteRunning: Int
    var mediumRouteRunning: Int
    var deepRouteRunning: Int
    
    // Special teams attributes
    var kickPower: Int
    var kickAccuracy: Int
    
    // Additional attributes
    var bCVision: Int
    
    // Salary Cap Properties
    var salary: Int = 0
    var contract: PlayerContract?
    var isRookiePlayer: Bool = false
    var draftPickNumber: Int?
    var draftYearValue: Int?
    var contractYearsLeft: Int = 0
    
    // Overall rating (stored from master data, not calculated)
    var overall: Int
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    

    
    /// Converts to legacy PlayerData for compatibility
    func toPlayerData() -> PlayerData {
        return PlayerData(
            firstName: firstName,
            lastName: lastName,
            position: position,
            number: number,
            overall: overall,
            age: age,
            actualSalary: salary > 0 ? salary : nil
        )
    }
    
    /// Applies updates and marks as edited
    mutating func applyUpdates(_ updates: PlayerDataUpdates) {
        if let firstName = updates.firstName { self.firstName = firstName }
        if let lastName = updates.lastName { self.lastName = lastName }
        if let position = updates.position { self.position = position }
        if let number = updates.number { self.number = number }
        if let age = updates.age { self.age = age }
        if let college = updates.college { self.college = college }
        if let height = updates.height { self.height = height }
        if let weight = updates.weight { self.weight = weight }
        if let yearsPro = updates.yearsPro { self.yearsPro = yearsPro }
        
        // Individual Attributes
        if let speed = updates.speed { self.speed = speed }
        if let agility = updates.agility { self.agility = agility }
        if let awareness = updates.awareness { self.awareness = awareness }
        if let strength = updates.strength { self.strength = strength }
        if let stamina = updates.stamina { self.stamina = stamina }
        if let injury = updates.injury { self.injury = injury }
        if let carrying = updates.carrying { self.carrying = carrying }
        if let trucking = updates.trucking { self.trucking = trucking }
        if let catching = updates.catching { self.catching = catching }
        if let breakTackle = updates.breakTackle { self.breakTackle = breakTackle }
        if let jukeMove = updates.jukeMove { self.jukeMove = jukeMove }
        if let spinMove = updates.spinMove { self.spinMove = spinMove }
        if let stiffArm = updates.stiffArm { self.stiffArm = stiffArm }
        if let acceleration = updates.acceleration { self.acceleration = acceleration }
        if let changeOfDirection = updates.changeOfDirection { self.changeOfDirection = changeOfDirection }
        if let throwPower = updates.throwPower { self.throwPower = throwPower }
        if let throwAccuracyShort = updates.throwAccuracyShort { self.throwAccuracyShort = throwAccuracyShort }
        if let throwAccuracyMid = updates.throwAccuracyMid { self.throwAccuracyMid = throwAccuracyMid }
        if let throwAccuracyDeep = updates.throwAccuracyDeep { self.throwAccuracyDeep = throwAccuracyDeep }
        if let throwOnTheRun = updates.throwOnTheRun { self.throwOnTheRun = throwOnTheRun }
        if let throwUnderPressure = updates.throwUnderPressure { self.throwUnderPressure = throwUnderPressure }
        if let playAction = updates.playAction { self.playAction = playAction }
        if let tackle = updates.tackle { self.tackle = tackle }
        if let blockShedding = updates.blockShedding { self.blockShedding = blockShedding }
        if let zoneCoverage = updates.zoneCoverage { self.zoneCoverage = zoneCoverage }
        if let manCoverage = updates.manCoverage { self.manCoverage = manCoverage }
        if let pursuit = updates.pursuit { self.pursuit = pursuit }
        if let finesseMoves = updates.finesseMoves { self.finesseMoves = finesseMoves }
        if let powerMoves = updates.powerMoves { self.powerMoves = powerMoves }
        if let press = updates.press { self.press = press }
        if let jumping = updates.jumping { self.jumping = jumping }
        if let playRecognition = updates.playRecognition { self.playRecognition = playRecognition }
        if let hitPower = updates.hitPower { self.hitPower = hitPower }
        if let toughness = updates.toughness { self.toughness = toughness }
        if let passBlock = updates.passBlock { self.passBlock = passBlock }
        if let runBlock = updates.runBlock { self.runBlock = runBlock }
        if let impactBlocking = updates.impactBlocking { self.impactBlocking = impactBlocking }
        if let passBlockPower = updates.passBlockPower { self.passBlockPower = passBlockPower }
        if let runBlockPower = updates.runBlockPower { self.runBlockPower = runBlockPower }
        if let passBlockFinesse = updates.passBlockFinesse { self.passBlockFinesse = passBlockFinesse }
        if let runBlockFinesse = updates.runBlockFinesse { self.runBlockFinesse = runBlockFinesse }
        if let release = updates.release { self.release = release }
        if let catchInTraffic = updates.catchInTraffic { self.catchInTraffic = catchInTraffic }
        if let spectacularCatch = updates.spectacularCatch { self.spectacularCatch = spectacularCatch }
        if let shortRouteRunning = updates.shortRouteRunning { self.shortRouteRunning = shortRouteRunning }
        if let mediumRouteRunning = updates.mediumRouteRunning { self.mediumRouteRunning = mediumRouteRunning }
        if let deepRouteRunning = updates.deepRouteRunning { self.deepRouteRunning = deepRouteRunning }
        if let kickPower = updates.kickPower { self.kickPower = kickPower }
        if let kickAccuracy = updates.kickAccuracy { self.kickAccuracy = kickAccuracy }
        if let bCVision = updates.bCVision { self.bCVision = bCVision }
        
        self.isEdited = true
        self.lastModified = Date()
    }
}

// MARK: - Update Structure
struct PlayerDataUpdates {
    var firstName: String?
    var lastName: String?
    var position: String?
    var number: Int?
    var age: Int?
    var college: String?
    var height: String?
    var weight: String?
    var yearsPro: Int?
    
    // Individual Attributes
    var speed: Int?
    var agility: Int?
    var awareness: Int?
    var strength: Int?
    var stamina: Int?
    var injury: Int?
    var carrying: Int?
    var trucking: Int?
    var catching: Int?
    var breakTackle: Int?
    var jukeMove: Int?
    var spinMove: Int?
    var stiffArm: Int?
    var acceleration: Int?
    var changeOfDirection: Int?
    var throwPower: Int?
    var throwAccuracyShort: Int?
    var throwAccuracyMid: Int?
    var throwAccuracyDeep: Int?
    var throwOnTheRun: Int?
    var throwUnderPressure: Int?
    var playAction: Int?
    var tackle: Int?
    var blockShedding: Int?
    var zoneCoverage: Int?
    var manCoverage: Int?
    var pursuit: Int?
    var finesseMoves: Int?
    var powerMoves: Int?
    var press: Int?
    var jumping: Int?
    var playRecognition: Int?
    var hitPower: Int?
    var toughness: Int?
    var passBlock: Int?
    var runBlock: Int?
    var impactBlocking: Int?
    var passBlockPower: Int?
    var runBlockPower: Int?
    var passBlockFinesse: Int?
    var runBlockFinesse: Int?
    var release: Int?
    var catchInTraffic: Int?
    var spectacularCatch: Int?
    var shortRouteRunning: Int?
    var mediumRouteRunning: Int?
    var deepRouteRunning: Int?
    var kickPower: Int?
    var kickAccuracy: Int?
    var bCVision: Int?
}

// MARK: - Errors
enum PlayerDataError: Error, LocalizedError {
    case noMasterDataFound
    case fileNotFound
    case playerNotFound
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .noMasterDataFound:
            return "No master player data found for team"
        case .fileNotFound:
            return "Player data file not found"
        case .playerNotFound:
            return "Player not found in data file"
        case .saveFailed:
            return "Failed to save player data"
        }
    }
}

// MARK: - Phase 6: System Health Report Model
struct SystemHealthReport {
    var playerDataFilesCount: Int = 0
    var totalStorageUsed: Int = 0
    var averageLoadTime: Double = 0.0
    var fileSystemHealthy: Bool = false
    var performanceHealthy: Bool = false
    var validationTime: Double = 0.0
    var errors: [String] = []
    
    var overallHealthy: Bool {
        return fileSystemHealthy && performanceHealthy && errors.isEmpty
    }
}

// MARK: - Helper Functions for Master Data Conversion

extension PlayerDataManager {
    /// Converts a MasterPlayer to EditablePlayerData with consistent attribute generation
    private func convertMasterPlayerToEditablePlayerData(masterPlayer: MasterPlayer, teamLogoName: String, leagueId: UUID) -> EditablePlayerData {
        // Generate consistent attributes based on player name and position
        // This ensures the same player always has the same attributes
        let playerSeed = hashPlayerName(masterPlayer.firstName, masterPlayer.lastName)
        
        func generateConsistentAttribute(base: Int = 75, importance: Double = 1.0, seed: Int) -> Int {
            // Use player name hash + attribute type to generate consistent values
            let attributeSeed = seed &+ Int(importance * 1000)
            let pseudoRandom = (attributeSeed &* 9301 &+ 49297) % 233280
            let normalizedValue = Double(pseudoRandom) / 233280.0 // 0.0 to 1.0
            
            // Generate value in range 40-95 with position-based importance
            let adjustedBase = Int(Double(base) * importance)
            let variation = Int((normalizedValue - 0.5) * 30) // -15 to +15 variation
            return max(40, min(95, adjustedBase + variation))
        }
        
        return EditablePlayerData(
            id: UUID(),
            firstName: validatePlayerName(masterPlayer.firstName),
            lastName: validatePlayerName(masterPlayer.lastName),
            position: masterPlayer.position,
            number: Int(masterPlayer.jerseyNum) ?? 1,
            age: masterPlayer.ageInt,
            college: masterPlayer.college,
            height: masterPlayer.height,
            weight: masterPlayer.weight,
            yearsPro: Int(masterPlayer.yearsPro) ?? 0,
            teamLogoName: teamLogoName,
            leagueId: leagueId,
            isEdited: false,
            lastModified: Date(),
            // Generate consistent attributes based on player name and position
            speed: masterPlayer.attributes.speed ?? generateConsistentAttribute(
                base: 75, 
                importance: masterPlayer.position == "RB" || masterPlayer.position == "WR" ? 1.2 : 0.9,
                seed: playerSeed &+ 1
            ),
            agility: masterPlayer.attributes.agility ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "RB" || masterPlayer.position == "WR" ? 1.1 : 0.9,
                seed: playerSeed &+ 2
            ),
            awareness: masterPlayer.attributes.awareness ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "QB" ? 1.3 : 1.0,
                seed: playerSeed &+ 3
            ),
            strength: masterPlayer.attributes.strength ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position.contains("T") || masterPlayer.position.contains("G") || masterPlayer.position == "C" ? 1.2 : 0.9,
                seed: playerSeed &+ 4
            ),
            stamina: masterPlayer.attributes.stamina ?? generateConsistentAttribute(base: 75, seed: playerSeed &+ 5),
            injury: masterPlayer.attributes.injury ?? generateConsistentAttribute(base: 75, seed: playerSeed &+ 6),
            carrying: masterPlayer.attributes.carrying ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "RB" ? 1.2 : 0.8,
                seed: playerSeed &+ 7
            ),
            trucking: masterPlayer.attributes.trucking ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "RB" ? 1.1 : 0.8,
                seed: playerSeed &+ 8
            ),
            catching: masterPlayer.attributes.catching ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "WR" || masterPlayer.position == "TE" ? 1.3 : 0.7,
                seed: playerSeed &+ 9
            ),
            breakTackle: masterPlayer.attributes.breakTackle ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "RB" ? 1.2 : 0.8,
                seed: playerSeed &+ 10
            ),
            jukeMove: masterPlayer.attributes.jukeMove ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "RB" ? 1.1 : 0.8,
                seed: playerSeed &+ 11
            ),
            spinMove: masterPlayer.attributes.spinMove ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "RB" ? 1.1 : 0.8,
                seed: playerSeed &+ 12
            ),
            stiffArm: masterPlayer.attributes.stiffArm ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "RB" ? 1.1 : 0.8,
                seed: playerSeed &+ 13
            ),
            acceleration: masterPlayer.attributes.acceleration ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "RB" || masterPlayer.position == "WR" ? 1.2 : 0.9,
                seed: playerSeed &+ 14
            ),
            changeOfDirection: masterPlayer.attributes.changeOfDirection ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "RB" || masterPlayer.position == "WR" ? 1.1 : 0.9,
                seed: playerSeed &+ 15
            ),
            throwPower: masterPlayer.attributes.throwPower ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "QB" ? 1.3 : 0.5,
                seed: playerSeed &+ 16
            ),
            throwAccuracyShort: masterPlayer.attributes.throwAccuracyShort ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "QB" ? 1.2 : 0.5,
                seed: playerSeed &+ 17
            ),
            throwAccuracyMid: masterPlayer.attributes.throwAccuracyMid ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "QB" ? 1.2 : 0.5,
                seed: playerSeed &+ 18
            ),
            throwAccuracyDeep: masterPlayer.attributes.throwAccuracyDeep ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "QB" ? 1.1 : 0.5,
                seed: playerSeed &+ 19
            ),
            throwOnTheRun: masterPlayer.attributes.throwOnTheRun ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "QB" ? 1.1 : 0.5,
                seed: playerSeed &+ 20
            ),
            throwUnderPressure: masterPlayer.attributes.throwUnderPressure ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "QB" ? 1.2 : 0.5,
                seed: playerSeed &+ 21
            ),
            playAction: masterPlayer.attributes.playAction ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "QB" ? 1.0 : 0.5,
                seed: playerSeed &+ 22
            ),
            tackle: masterPlayer.attributes.tackle ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position.contains("LB") || masterPlayer.position == "SS" ? 1.2 : masterPlayer.position.contains("D") ? 1.0 : 0.6,
                seed: playerSeed &+ 23
            ),
            blockShedding: masterPlayer.attributes.blockShedding ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "DE" || masterPlayer.position == "DT" ? 1.2 : 0.8,
                seed: playerSeed &+ 24
            ),
            zoneCoverage: masterPlayer.attributes.zoneCoverage ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "CB" || masterPlayer.position == "FS" ? 1.3 : 0.7,
                seed: playerSeed &+ 25
            ),
            manCoverage: masterPlayer.attributes.manCoverage ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "CB" ? 1.3 : 0.7,
                seed: playerSeed &+ 26
            ),
            pursuit: masterPlayer.attributes.pursuit ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position.contains("LB") ? 1.1 : 0.9,
                seed: playerSeed &+ 27
            ),
            finesseMoves: masterPlayer.attributes.finesseMoves ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "DE" || masterPlayer.position == "EDGE" ? 1.2 : 0.8,
                seed: playerSeed &+ 28
            ),
            powerMoves: masterPlayer.attributes.powerMoves ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "DT" ? 1.2 : 0.8,
                seed: playerSeed &+ 29
            ),
            press: masterPlayer.attributes.press ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "CB" ? 1.1 : 0.8,
                seed: playerSeed &+ 30
            ),
            jumping: masterPlayer.attributes.jumping ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "WR" || masterPlayer.position == "CB" ? 1.1 : 0.9,
                seed: playerSeed &+ 31
            ),
            playRecognition: masterPlayer.attributes.playRecognition ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position.contains("LB") || masterPlayer.position == "QB" ? 1.2 : 1.0,
                seed: playerSeed &+ 32
            ),
            hitPower: masterPlayer.attributes.hitPower ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "SS" || masterPlayer.position.contains("LB") ? 1.2 : 0.8,
                seed: playerSeed &+ 33
            ),
            toughness: masterPlayer.attributes.toughness ?? generateConsistentAttribute(base: 75, seed: playerSeed &+ 34),
            passBlock: masterPlayer.attributes.passBlock ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position.contains("T") || masterPlayer.position.contains("G") || masterPlayer.position == "C" ? 1.3 : 0.6,
                seed: playerSeed &+ 35
            ),
            runBlock: masterPlayer.attributes.runBlock ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position.contains("T") || masterPlayer.position.contains("G") || masterPlayer.position == "C" ? 1.2 : 0.6,
                seed: playerSeed &+ 36
            ),
            impactBlocking: masterPlayer.attributes.impactBlocking ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position.contains("T") || masterPlayer.position.contains("G") || masterPlayer.position == "C" ? 1.1 : 0.6,
                seed: playerSeed &+ 37
            ),
            passBlockPower: masterPlayer.attributes.passBlockPower ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position.contains("T") || masterPlayer.position.contains("G") || masterPlayer.position == "C" ? 1.2 : 0.6,
                seed: playerSeed &+ 38
            ),
            runBlockPower: masterPlayer.attributes.runBlockPower ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position.contains("T") || masterPlayer.position.contains("G") || masterPlayer.position == "C" ? 1.2 : 0.6,
                seed: playerSeed &+ 39
            ),
            passBlockFinesse: masterPlayer.attributes.passBlockFinesse ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position.contains("T") || masterPlayer.position.contains("G") || masterPlayer.position == "C" ? 1.1 : 0.6,
                seed: playerSeed &+ 40
            ),
            runBlockFinesse: masterPlayer.attributes.runBlockFinesse ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position.contains("T") || masterPlayer.position.contains("G") || masterPlayer.position == "C" ? 1.1 : 0.6,
                seed: playerSeed &+ 41
            ),
            release: masterPlayer.attributes.release ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "WR" || masterPlayer.position == "TE" ? 1.2 : 0.7,
                seed: playerSeed &+ 42
            ),
            catchInTraffic: masterPlayer.attributes.catchInTraffic ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "WR" || masterPlayer.position == "TE" ? 1.2 : 0.7,
                seed: playerSeed &+ 43
            ),
            spectacularCatch: masterPlayer.attributes.spectacularCatch ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "WR" ? 1.1 : 0.7,
                seed: playerSeed &+ 44
            ),
            shortRouteRunning: masterPlayer.attributes.shortRouteRunning ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "WR" || masterPlayer.position == "TE" ? 1.2 : 0.7,
                seed: playerSeed &+ 45
            ),
            mediumRouteRunning: masterPlayer.attributes.mediumRouteRunning ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "WR" || masterPlayer.position == "TE" ? 1.2 : 0.7,
                seed: playerSeed &+ 46
            ),
            deepRouteRunning: masterPlayer.attributes.deepRouteRunning ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "WR" ? 1.2 : 0.7,
                seed: playerSeed &+ 47
            ),
            kickPower: masterPlayer.attributes.kickPower ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "K" || masterPlayer.position == "P" ? 1.3 : 0.5,
                seed: playerSeed &+ 48
            ),
            kickAccuracy: masterPlayer.attributes.kickAccuracy ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "K" ? 1.3 : 0.5,
                seed: playerSeed &+ 49
            ),
            bCVision: masterPlayer.attributes.bCVision ?? generateConsistentAttribute(
                base: 75,
                importance: masterPlayer.position == "RB" ? 1.2 : 0.8,
                seed: playerSeed &+ 50
            ),
            // Salary cap properties (using default values)
            salary: 0,
            contract: nil,
            isRookiePlayer: false,
            draftPickNumber: nil,
            draftYearValue: nil,
            contractYearsLeft: 0,
            // Use the overall rating from master data instead of calculating it
            overall: Int(masterPlayer.overall) ?? 75
        )
    }
} 