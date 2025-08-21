import Foundation
import Combine

// MARK: - Optimized Master Data Loader
@MainActor
class MasterDataLoader: ObservableObject {
    @Published var isDataLoaded = false
    @Published var isLoading = false
    @Published var loadingProgress: Double = 0.0
    @Published var teams: [String: MasterTeamData] = [:]
    @Published var errorMessage: String?
    @Published var freeAgents: [MasterPlayer] = []  // Add free agents array
    
    static let shared = MasterDataLoader()
    
    // Fast lookup caches
    private var teamsByShortName: [String: MasterTeamData] = [:]
    private var allTeamNames: [String] = []
    private var playersByTeam: [String: [MasterPlayer]] = [:]
    
    private init() {
        Task {
            await loadMasterDataAsync()
        }
    }
    
    /// Optimized async load of master data with roster/schedule overrides
    func loadMasterDataAsync() async {
        isLoading = true
        loadingProgress = 0.0
        
        // Load and process data efficiently on background thread (no throws)
        let cleanedData = await Task.detached { () async -> [String: MasterTeamData] in
                // 1) Base: load combined master for schedule fallback
                guard let baseURL = Bundle.main.url(forResource: "2025Master", withExtension: "json") else {
                    // If not present, start from empty
                    return [String: MasterTeamData]()
                }
                let baseData = (try? Data(contentsOf: baseURL)) ?? Data()
                var baseMaster = (try? JSONDecoder().decode([String: MasterTeamData].self, from: baseData)) ?? [:]

                // 2) Optional roster override (Roster2025.json) → replace players per team
                if let rosterURL = Bundle.main.url(forResource: "Roster2025", withExtension: "json"),
                   let rosterData = try? Data(contentsOf: rosterURL),
                   let roster = try? JSONDecoder().decode([String: [MasterPlayer]].self, from: rosterData) {
                    for (teamName, players) in roster {
                        if var entry = baseMaster[teamName] {
                            entry.players = players
                            baseMaster[teamName] = entry
                        } else if teamName == "Free Agent" {
                            // Carry free agents even if not in base schedule
                            baseMaster[teamName] = MasterTeamData(players: players, schedule: [])
                        }
                    }
                }

                // 3) Optional: merge CSV rosters (authoritative) into master players
                let csvRosters: [String: [PlayerData]]? = {
                    if let url = ContractImporter.locateCSV() {
                        return ContractImporter.buildRosters(from: url)
                    }
                    return nil
                }()
                if let csvRosters {
                    // Map of short team key -> full display name used in baseMaster
                    let shortToFull: [String: String] = [
                        "KansasCity": "Kansas City Chiefs",
                        "SanFrancisco": "San Francisco 49ers",
                        "Miami": "Miami Dolphins",
                        "Dallas": "Dallas Cowboys",
                        "Chicago": "Chicago Bears",
                        "Detroit": "Detroit Lions",
                        "GreenBay": "Green Bay Packers",
                        "Minnesota": "Minnesota Vikings",
                        "NYN": "New York Giants",
                        "Philadelphia": "Philadelphia Eagles",
                        "Washington": "Washington Commanders",
                        "Atlanta": "Atlanta Falcons",
                        "Carolina": "Carolina Panthers",
                        "NewOrleans": "New Orleans Saints",
                        "TampaBay": "Tampa Bay Buccaneers",
                        "Arizona": "Arizona Cardinals",
                        "LAN": "Los Angeles Rams",
                        "Seattle": "Seattle Seahawks",
                        "Baltimore": "Baltimore Ravens",
                        "Cincinnati": "Cincinnati Bengals",
                        "Cleveland": "Cleveland Browns",
                        "Pittsburgh": "Pittsburgh Steelers",
                        "Buffalo": "Buffalo Bills",
                        "NewEngland": "New England Patriots",
                        "NYA": "New York Jets",
                        "Houston": "Houston Texans",
                        "Indianapolis": "Indianapolis Colts",
                        "Jacksonville": "Jacksonville Jaguars",
                        "Tennessee": "Tennessee Titans",
                        "Denver": "Denver Broncos",
                        "LasVegas": "Las Vegas Raiders",
                        "LAA": "Los Angeles Chargers"
                    ]
                    for (short, csvPlayers) in csvRosters {
                        if short == "Free Agent" { continue }
                        let full = shortToFull[short] ?? short
                        guard let existing = baseMaster[full] else { continue }
                        // Convert CSV PlayerData → MasterPlayer (preserve APY as actualSalary in dollars)
                        let converted: [MasterPlayer] = csvPlayers.map { MasterPlayer.makeFromCSV(player: $0, teamFullName: full) }
                        baseMaster[full] = MasterTeamData(players: converted, schedule: existing.schedule)
                    }
                }

                // 4) Optional schedule overrides (kickoff time / neutral site)
                if let overridesURL = Bundle.main.url(forResource: "2025ScheduleOverrides", withExtension: "json"),
                   let overridesData = try? Data(contentsOf: overridesURL) {
                    let decoder = JSONDecoder()
                    let overrides = (try? decoder.decode([MasterGameOverride].self, from: overridesData)) ?? []
                    let overrideMap = Dictionary(uniqueKeysWithValues: overrides.map { ($0.pairKey, $0) })
                    for (teamName, teamData) in baseMaster {
                        let updatedSchedule: [MasterGame] = teamData.schedule.map { game in
                            let key = MasterGameOverride.makePairKey(week: game.week, a: game.awayTeamRealName, b: game.homeTeamRealName)
                            if let ov = overrideMap[key] {
                                return MasterGame(
                                    week: game.week,
                                    awayTeamRealName: game.awayTeamRealName,
                                    homeTeamRealName: game.homeTeamRealName,
                                    neutralSiteLocation: ov.neutralSiteLocation ?? game.neutralSiteLocation,
                                    kickoffISO8601: ov.kickoffISO8601
                                )
                            } else {
                                return game
                            }
                        }
                        baseMaster[teamName] = MasterTeamData(players: teamData.players, schedule: updatedSchedule)
                    }
                }

                // 5) Validate and clean (avoid capturing mutable var across actors)
                let snapshot = baseMaster
                return await MainActor.run {
                    self.loadingProgress = 0.8
                    return self.validateAndCleanData(snapshot)
                }
        }.value
        
        // Update UI on main thread
        self.teams = cleanedData
        
        // Load free agents from the "Free Agent" team if it exists
        if let freeAgentTeam = cleanedData["Free Agent"] {
            self.freeAgents = freeAgentTeam.players.sorted { Int($0.overall) ?? 0 > Int($1.overall) ?? 0 }
        }
        
        // Build caches BEFORE marking data as loaded
        self.buildOptimizedCaches(cleanedData)
        
        self.loadingProgress = 1.0
        self.isDataLoaded = true
        self.isLoading = false
        
        print("✅ Master data loaded successfully: \(cleanedData.count) teams")
        print("🚀 Optimized caches built for instant team access")
        print("👥 Free agents loaded: \(self.freeAgents.count) players")
        
        // Log performance metrics
        self.logPerformanceMetrics(cleanedData)
        
        // Audit team roster sizes
        self.auditTeamRosterSizes(cleanedData)
        
        // Notify that master data is now available
        NotificationCenter.default.post(name: NSNotification.Name("MasterDataLoaded"), object: nil)
    }
    
    /// Build optimized lookup caches for O(1) access
    private func buildOptimizedCaches(_ data: [String: MasterTeamData]) {
        // Build short name to team data mapping
        let teamMapping: [String: String] = [
            "KansasCity": "Kansas City Chiefs",
            "SanFrancisco": "San Francisco 49ers", 
            "Miami": "Miami Dolphins",
            "Dallas": "Dallas Cowboys",
            "Chicago": "Chicago Bears",
            "Detroit": "Detroit Lions",
            "GreenBay": "Green Bay Packers",
            "Minnesota": "Minnesota Vikings",
            "NYN": "New York Giants",
            "Philadelphia": "Philadelphia Eagles",
            "Washington": "Washington Commanders",
            "Atlanta": "Atlanta Falcons",
            "Carolina": "Carolina Panthers",
            "NewOrleans": "New Orleans Saints",
            "TampaBay": "Tampa Bay Buccaneers",
            "Arizona": "Arizona Cardinals",
            "LAN": "Los Angeles Rams",
            "Seattle": "Seattle Seahawks",
            "Baltimore": "Baltimore Ravens",
            "Cincinnati": "Cincinnati Bengals",
            "Cleveland": "Cleveland Browns",
            "Pittsburgh": "Pittsburgh Steelers",
            "Buffalo": "Buffalo Bills",
            "NewEngland": "New England Patriots",
            "NYA": "New York Jets",
            "Houston": "Houston Texans",
            "Indianapolis": "Indianapolis Colts",
            "Jacksonville": "Jacksonville Jaguars",
            "Tennessee": "Tennessee Titans",
            "Denver": "Denver Broncos",
            "LasVegas": "Las Vegas Raiders",
            "LAA": "Los Angeles Chargers"
        ]
        
        // Build fast lookup caches
        teamsByShortName.removeAll()
        playersByTeam.removeAll()
        allTeamNames.removeAll()
        
        for (shortName, fullName) in teamMapping {
            if let teamData = data[fullName] {
                teamsByShortName[shortName] = teamData
                playersByTeam[shortName] = teamData.players
                allTeamNames.append(shortName)
                print("✅ Cached \(shortName) -> \(fullName) (\(teamData.players.count) players)")
            } else {
                print("❌ Missing team data for \(shortName) -> \(fullName)")
                print("   Available keys: \(Array(data.keys).prefix(5).sorted()) (showing first 5)")
            }
        }
        
        // Sort team names for consistent ordering
        allTeamNames.sort()
    }
    
    /// Get team data instantly by short name - O(1) lookup
    func getTeamData(for shortName: String) -> MasterTeamData? {
        return teamsByShortName[shortName]
    }
    
    /// Get players for a team instantly - O(1) lookup  
    func getPlayers(for shortName: String) -> [MasterPlayer] {
        // If data isn't loaded yet, return empty array and let the caller handle it
        guard isDataLoaded else {
            print("⚠️ getPlayers(for: \"\(shortName)\") called but data not loaded yet (isDataLoaded: \(isDataLoaded), isLoading: \(isLoading))")
            return []
        }
        
        if shortName == "Free Agent" {
            return freeAgents.sorted { Int($0.overall) ?? 0 > Int($1.overall) ?? 0 }
        }
        
        return playersByTeam[shortName] ?? []
    }
    
    /// Get players for a team, waiting for data to load if necessary
    func getPlayersAsync(for shortName: String) async -> [MasterPlayer] {
        // Wait for data to be loaded if it's currently loading
        while isLoading && !isDataLoaded {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // If still not loaded after waiting, return empty array
        guard isDataLoaded else {
            print("⚠️ Master data failed to load for \(shortName)")
            return []
        }
        
        return getPlayers(for: shortName)
    }
    
    /// Get all available team names (short names) - pre-sorted
    func getAvailableTeams() -> [String] {
        var teams = allTeamNames
        // Add Free Agent team if it has players
        if !freeAgents.isEmpty {
            teams.append("Free Agent")
        }
        return teams.sorted()
    }
    
    /// Get team schedule with proper home/away context
    func getSchedule(for shortName: String) -> [GameWithContext] {
        guard let teamData = teamsByShortName[shortName],
              let fullTeamName = getFullTeamName(for: shortName) else {
            return []
        }
        
        var scheduleGames = teamData.schedule.map { game in
            let isHome = game.homeTeamRealName == fullTeamName
            let opponent = isHome ? game.awayTeamRealName : game.homeTeamRealName
            
            return GameWithContext(
                week: game.week,
                opponent: opponent,
                isHome: isHome,
                neutralSite: game.neutralSiteLocation
            )
        }
        
        // Add missing Chiefs vs Cowboys game for Week 13
        if shortName == "KansasCity" {
            // Chiefs are missing week 13 - they play @ Cowboys
            scheduleGames.append(GameWithContext(
                week: 13,
                opponent: "Dallas Cowboys",
                isHome: false,
                neutralSite: nil
            ))
        } else if shortName == "Dallas" {
            // Cowboys are missing week 13 - they host Chiefs
            scheduleGames.append(GameWithContext(
                week: 13,
                opponent: "Kansas City Chiefs",
                isHome: true,
                neutralSite: nil
            ))
        }
        
        // Add missing Miami vs Jets game for Week 14
        if shortName == "Miami" {
            // Miami is missing week 14 - they play @ Jets
            scheduleGames.append(GameWithContext(
                week: 14,
                opponent: "New York Jets",
                isHome: false,
                neutralSite: nil
            ))
        } else if shortName == "NYA" {
            // Jets are missing week 14 - they host Miami
            scheduleGames.append(GameWithContext(
                week: 14,
                opponent: "Miami Dolphins",
                isHome: true,
                neutralSite: nil
            ))
        }
        
        return scheduleGames.sorted { $0.week < $1.week }
    }
    
    /// Get full team name from short name
    private func getFullTeamName(for shortName: String) -> String? {
        let teamMapping: [String: String] = [
            "KansasCity": "Kansas City Chiefs",
            "SanFrancisco": "San Francisco 49ers",
            "Miami": "Miami Dolphins",
            "Dallas": "Dallas Cowboys",
            "Chicago": "Chicago Bears",
            "Detroit": "Detroit Lions",
            "GreenBay": "Green Bay Packers",
            "Minnesota": "Minnesota Vikings",
            "NYN": "New York Giants",
            "Philadelphia": "Philadelphia Eagles",
            "Washington": "Washington Commanders",
            "Atlanta": "Atlanta Falcons",
            "Carolina": "Carolina Panthers",
            "NewOrleans": "New Orleans Saints",
            "TampaBay": "Tampa Bay Buccaneers",
            "Arizona": "Arizona Cardinals",
            "LAN": "Los Angeles Rams",
            "Seattle": "Seattle Seahawks",
            "Baltimore": "Baltimore Ravens",
            "Cincinnati": "Cincinnati Bengals",
            "Cleveland": "Cleveland Browns",
            "Pittsburgh": "Pittsburgh Steelers",
            "Buffalo": "Buffalo Bills",
            "NewEngland": "New England Patriots",
            "NYA": "New York Jets",
            "Houston": "Houston Texans",
            "Indianapolis": "Indianapolis Colts",
            "Jacksonville": "Jacksonville Jaguars",
            "Tennessee": "Tennessee Titans",
            "Denver": "Denver Broncos",
            "LasVegas": "Las Vegas Raiders",
            "LAA": "Los Angeles Chargers"
        ]
        
        return teamMapping[shortName]
    }
    
    /// Log performance metrics
    private func logPerformanceMetrics(_ data: [String: MasterTeamData]) {
        let totalPlayers = data.values.reduce(0) { $0 + $1.players.count }
        let totalGames = data.values.reduce(0) { $0 + $1.schedule.count }
        let cacheSize = teamsByShortName.count
        
        print("📊 Performance Metrics:")
        print("   Teams loaded: \(data.count)")
        print("   Total players: \(totalPlayers)")
        print("   Total games: \(totalGames)")
        print("   Cache entries: \(cacheSize)")
        print("   Memory footprint: ~\(String(format: "%.1f", Double(totalPlayers * 500) / 1024 / 1024))MB")
        print("   Lookup performance: O(1) for all team operations")
    }
    
    /// Audit team roster sizes to ensure consistency
    private func auditTeamRosterSizes(_ data: [String: MasterTeamData]) {
        print("📊 Master Data Roster Audit:")
        
        var teamCounts: [String: Int] = [:]
        var totalTeams = 0
        var teamsWithInsufficientPlayers = 0
        var minPlayers = Int.max
        var maxPlayers = 0
        
        for (teamName, teamData) in data {
            // Skip Free Agent team from audit
            if teamName == "Free Agent" {
                continue
            }
            
            let playerCount = teamData.players.count
            teamCounts[teamName] = playerCount
            totalTeams += 1
            
            if playerCount < 50 {
                teamsWithInsufficientPlayers += 1
                print("   ⚠️ \(teamName): \(playerCount) players (insufficient)")
            }
            
            minPlayers = min(minPlayers, playerCount)
            maxPlayers = max(maxPlayers, playerCount)
        }
        
        print("   📈 Total NFL Teams: \(totalTeams)")
        print("   📈 Min Players: \(minPlayers)")
        print("   📈 Max Players: \(maxPlayers)")
        print("   📈 Teams with <50 players: \(teamsWithInsufficientPlayers)")
        
        if teamsWithInsufficientPlayers > 0 {
            print("   ⚠️ Some teams have insufficient players - PlayerDataManager will balance to 60")
            print("   💡 Consider updating your 2025Master.json file with complete rosters for these teams")
        } else {
            print("   ✅ All teams have sufficient players for balancing")
        }
    }

    // MARK: - Free Agent Management
    
    func removePlayerFromFreeAgents(_ player: MasterPlayer) {
        freeAgents.removeAll { $0.id == player.id }
    }

    // MARK: - Data Validation (Optimized)
    
    /// Validate and clean the loaded data
    private func validateAndCleanData(_ rawData: [String: MasterTeamData]) -> [String: MasterTeamData] {
        var cleanedData: [String: MasterTeamData] = [:]
        
        print("🧹 Starting data validation for \(rawData.count) teams")
        
        for (teamName, teamData) in rawData {
            // Clean team name
            let cleanTeamName = teamName.trimmingCharacters(in: .whitespacesAndNewlines)
            

            
            // Keep Free Agent team regardless of size
            if cleanTeamName == "Free Agent" {
                print("📋 Loading '\(cleanTeamName)' team with \(teamData.players.count) players")
            }
            
            // Clean and validate players
            var cleanedPlayers: [MasterPlayer] = []
            var usedJerseyNumbers: Set<Int> = []
            
            // Process all players and handle jersey number conflicts
            var filteredCount = 0
            for player in teamData.players {
                // Skip players with invalid basic data
                guard !player.firstName.isEmpty && !player.lastName.isEmpty else { 
                    filteredCount += 1
                    continue 
                }
                
                // Clean and standardize position
                let cleanedPosition = cleanAndStandardizePosition(player.position)
                guard !cleanedPosition.isEmpty else { 
                    filteredCount += 1
                    continue 
                }
                
                // Handle jersey numbers - check for conflicts and assign appropriately
                let cleanedJerseyNum: String
                if let existingNum = Int(player.jerseyNum), existingNum > 0 && existingNum <= 99 {
                    // Check if this number is already used by another player on this team
                    if usedJerseyNumbers.contains(existingNum) {
                        // Number conflict! Assign a new number
                        let assignedNumber = assignJerseyNumber(for: cleanedPosition, usedNumbers: &usedJerseyNumbers)
                        cleanedJerseyNum = String(assignedNumber)
                    } else {
                        // Number is available, keep it
                        usedJerseyNumbers.insert(existingNum)
                        cleanedJerseyNum = player.jerseyNum
                    }
                } else {
                    // Invalid or missing jersey number, assign a new one
                    let assignedNumber = assignJerseyNumber(for: cleanedPosition, usedNumbers: &usedJerseyNumbers)
                    cleanedJerseyNum = String(assignedNumber)
                }
                
                // Create cleaned player with updated position and jersey number
                var cleanedPlayer = player
                cleanedPlayer.position = cleanedPosition
                cleanedPlayer.jerseyNum = cleanedJerseyNum
                
                cleanedPlayers.append(cleanedPlayer)
            }
            
            // Create cleaned team data
            let cleanedTeamData = MasterTeamData(
                players: cleanedPlayers,
                schedule: teamData.schedule
            )
            
            cleanedData[cleanTeamName] = cleanedTeamData
            
            // Debug logging for teams with insufficient players
            if cleanedPlayers.count < 50 {
                print("🔍 DEBUG: \(cleanTeamName) - Original: \(teamData.players.count) players, Cleaned: \(cleanedPlayers.count) players, Filtered: \(filteredCount)")
                print("   📋 Sample players: \(cleanedPlayers.prefix(3).map { "\($0.firstName) \($0.lastName) (\($0.position))" })")
            }

        }
        
        print("🧹 Data validation complete. \(cleanedData.count) teams processed")
        
        return cleanedData
    }
    
    /// Clean and standardize position names
    private func cleanAndStandardizePosition(_ rawPosition: String) -> String {
        // Handle multi-position players (take first position)
        let firstPosition = rawPosition.components(separatedBy: "/").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? rawPosition
        
        // Position mapping from various formats to standardized positions
        let positionMapping: [String: String] = [
            // Quarterback
            "QB": "QB", "QUARTERBACK": "QB",
            
            // Running Backs
            "RB": "RB", "RUNNINGBACK": "RB", "RUNNING BACK": "RB", "HB": "RB", "HALFBACK": "RB",
            "FB": "FB", "FULLBACK": "FB",
            
            // Receivers
            "WR": "WR", "WIDE RECEIVER": "WR", "WIDERECEIVER": "WR", "RECEIVER": "WR",
            "TE": "TE", "TIGHT END": "TE", "TIGHTEND": "TE",
            
            // Offensive Line
            "LT": "LT", "LEFT TACKLE": "LT", "LEFTTACKLE": "LT",
            "LG": "LG", "LEFT GUARD": "LG", "LEFTGUARD": "LG",
            "C": "C", "CENTER": "C",
            "RG": "RG", "RIGHT GUARD": "RG", "RIGHTGUARD": "RG",
            "RT": "RT", "RIGHT TACKLE": "RT", "RIGHTTACKLE": "RT",
            "T": "LT", "TACKLE": "LT", "G": "LG", "GUARD": "LG", // Default assignments
            "OL": "C", "OFFENSIVE LINE": "C", "OFFENSIVELINE": "C",
            
            // Defensive Line
            "DT": "DT", "DEFENSIVE TACKLE": "DT", "DEFENSIVETACKLE": "DT", "NT": "DT", "NOSE TACKLE": "DT",
            "DE": "DE", "DEFENSIVE END": "DE", "DEFENSIVEEND": "DE",
            "DL": "DT", "DEFENSIVE LINE": "DT", "DEFENSIVELINE": "DT",
            "LE": "DE", "LEFT END": "DE", "RE": "DE", "RIGHT END": "DE",
            
            // Linebackers
            "ROLB": "ROLB", "RIGHT OUTSIDE LINEBACKER": "ROLB", "RIGHT OLB": "ROLB",
            "MLB": "MLB", "MIDDLE LINEBACKER": "MLB", "MIDDLELINEBACKER": "MLB", "ILB": "MLB",
            "LOLB": "LOLB", "LEFT OUTSIDE LINEBACKER": "LOLB", "LEFT OLB": "LOLB",
            "EDGE": "EDGE", "EDGE RUSHER": "EDGE", "EDGERUSHER": "EDGE",
            "OLB": "ROLB", "OUTSIDE LINEBACKER": "ROLB", "OUTSIDELINEBACKER": "ROLB",
            "LB": "MLB", "LINEBACKER": "MLB",
            
            // Defensive Backs
            "CB": "CB", "CORNERBACK": "CB", "CORNER": "CB",
            "SS": "SS", "STRONG SAFETY": "SS", "STRONGSAFETY": "SS",
            "FS": "FS", "FREE SAFETY": "FS", "FREESAFETY": "FS",
            "S": "SS", "SAFETY": "SS", "SAF": "SS",
            "DB": "CB", "DEFENSIVE BACK": "CB", "DEFENSIVEBACK": "CB",
            
            // Special Teams
            "K": "K", "KICKER": "K", "PK": "K", "PLACEKICKER": "K",
            "P": "P", "PUNTER": "P", "PUNT": "P",
            "LS": "C", "LONG SNAPPER": "C", "LONGSNAPPER": "C" // Assign to C since no LS in your list
        ]
        
        let upperPosition = firstPosition.uppercased()
        return positionMapping[upperPosition] ?? "WR" // Default to WR if unknown
    }
    
    /// Assign appropriate jersey number based on position
    private func assignJerseyNumber(for position: String, usedNumbers: inout Set<Int>) -> Int {
        // NFL jersey number ranges by position
        let positionRanges: [String: [Int]] = [
            "QB": Array(1...19),
            "RB": Array(20...49),
            "FB": Array(20...49),
            "WR": Array(10...19) + Array(80...89),
            "TE": Array(80...89),
            "LT": Array(70...79),
            "LG": Array(60...79),
            "C": Array(50...79),
            "RG": Array(60...79),
            "RT": Array(70...79),
            "DT": Array(50...79) + Array(90...99),
            "DE": Array(50...79) + Array(90...99),
            "ROLB": Array(40...59) + Array(90...99),
            "MLB": Array(40...59) + Array(90...99),
            "LOLB": Array(40...59) + Array(90...99),
            "EDGE": Array(40...59) + Array(90...99),
            "CB": Array(20...49),
            "SS": Array(20...49),
            "FS": Array(20...49),
            "K": Array(1...19),
            "P": Array(1...19)
        ]
        
        let availableNumbers = positionRanges[position] ?? Array(1...99)
        
        // Find first available number in the position's range
        for number in availableNumbers {
            if !usedNumbers.contains(number) {
                usedNumbers.insert(number)
                return number
            }
        }
        
        // If all position numbers are taken, find any available number from 1-99
        for number in 1...99 {
            if !usedNumbers.contains(number) {
                usedNumbers.insert(number)
                return number
            }
        }
        
        // Fallback for edge cases
        var fallbackNumber = 100
        while usedNumbers.contains(fallbackNumber) {
            fallbackNumber += 1
            if fallbackNumber > 999 { break }
        }
        
        usedNumbers.insert(fallbackNumber)
        return fallbackNumber
    }
}

// MARK: - Supporting Types

enum DataLoadError: Error {
    case fileNotFound
    case decodingFailed
    case validationFailed
}

struct GameWithContext: Identifiable {
    let week: Int
    let opponent: String
    let isHome: Bool
    let neutralSite: String?
    
    var id: String {
        "\(week)_\(opponent)"
    }
    
    var locationText: String {
        if let neutralSite = neutralSite {
            return "@ \(neutralSite)"
        }
        return isHome ? "vs" : "@"
    }
}

// MARK: - Master Data Models (Unchanged)
struct MasterTeamData: Codable {
    var players: [MasterPlayer]
    let schedule: [MasterGame]
}

struct MasterPlayer: Codable, Identifiable {
    private let _firstName: String
    private let _lastName: String
    var position: String
    let team: String
    private let _college: String
    let age: String
    let overall: String
    let height: String
    let weight: String
    let handedness: String
    var jerseyNum: String
    let yearsPro: String
    let history: [String] // Usually empty
    let attributes: MasterPlayerAttributes
    let actualSalary: Int?
    
    // Custom coding keys to map the raw JSON fields
    enum CodingKeys: String, CodingKey {
        case _firstName = "firstName"
        case _lastName = "lastName"
        case position, team
        case _college = "college"
        case age, overall, height, weight, handedness, jerseyNum, yearsPro, history, attributes, actualSalary
    }
    
    // Cleaned up computed properties
    var firstName: String {
        cleanPlayerName(_firstName)
    }
    
    var lastName: String {
        cleanPlayerName(_lastName)
    }
    
    var college: String {
        cleanCollegeName(_college)
    }
    
    var id: String {
        "\(firstName)_\(lastName)_\(jerseyNum)"
    }
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var ageInt: Int {
        return Int(age) ?? 25
    }
    
    var overallInt: Int {
        return Int(overall) ?? 50
    }
    
    // Clean up player names by removing unwanted characters
    private func cleanPlayerName(_ name: String) -> String {
        var cleaned = name
        
        // Remove leading/trailing quotes and whitespace
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Enhanced cleaning patterns - be more aggressive with malformed data
        // Pattern 1: Remove anything with years (4 digits) and everything after
        cleaned = cleaned.replacingOccurrences(of: #"\s*\d{4}.*$"#, with: "", options: .regularExpression)
        
        // Pattern 2: Remove any parentheses content and everything after
        cleaned = cleaned.replacingOccurrences(of: #"\s*\([^)]*.*$"#, with: "", options: .regularExpression)
        
        // Pattern 3: Remove trailing parenthesis without opening
        cleaned = cleaned.replacingOccurrences(of: #"\s*\).*$"#, with: "", options: .regularExpression)
        
        // Pattern 4: Remove NFL suffix patterns (Jr, Sr, III, etc.) and everything after
        cleaned = cleaned.replacingOccurrences(of: #"\s*(Jr\.?|Sr\.?|III|II|IV|V).*$"#, with: "", options: .regularExpression)
        
        // Pattern 5: Remove any non-alphabetic characters at the end (except apostrophes and hyphens in names)
        cleaned = cleaned.replacingOccurrences(of: #"[^\w\s\-\']+.*$"#, with: "", options: .regularExpression)
        
        // Pattern 6: Remove any trailing numbers or special characters
        cleaned = cleaned.replacingOccurrences(of: #"\s*\d+.*$"#, with: "", options: .regularExpression)
        
        // Pattern 7: Keep only valid name characters (letters, spaces, apostrophes, hyphens)
        cleaned = cleaned.replacingOccurrences(of: #"[^\w\s\-\']"#, with: "", options: .regularExpression)
        
        // Clean up extra whitespace after all replacements
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        // Validate the result - ensure it contains only valid name characters
        let validNamePattern = #"^[A-Za-z\s\-\']+$"#
        let isValid = cleaned.range(of: validNamePattern, options: .regularExpression) != nil
        if !isValid {
            // If the cleaned name is still invalid, extract only the first valid word
            let words = cleaned.components(separatedBy: .whitespacesAndNewlines)
            for word in words {
                let cleanWord = word.replacingOccurrences(of: #"[^\w\-\']"#, with: "", options: .regularExpression)
                if !cleanWord.isEmpty && cleanWord.range(of: #"^[A-Za-z\-\']+$"#, options: .regularExpression) != nil {
                    cleaned = cleanWord
                    break
                }
            }
        }
        
        // Final validation - if still empty or invalid, use fallback names
        if cleaned.isEmpty || cleaned.count < 2 {
            // Generate a fallback name based on the original string hash
            let fallbackNames = ["John", "Mike", "Chris", "David", "Ryan", "Alex", "Matt", "Josh", "Nick", "Tom"]
            let hash = abs(name.hashValue)
            return fallbackNames[hash % fallbackNames.count]
        }
        
        // Capitalize first letter of each word
        cleaned = cleaned.capitalized
        
        return cleaned
    }
    
    // Clean up college names
    private func cleanCollegeName(_ college: String) -> String {
        var cleaned = college
        
        // Remove quotes
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
        
        // Clean up whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle empty college
        if cleaned.isEmpty {
            return "Unknown"
        }
        
        return cleaned
    }
}

// Convenience factory for building master players from CSV PlayerData
extension MasterPlayer {
    nonisolated(unsafe) static func makeFromCSV(player p: PlayerData, teamFullName: String) -> MasterPlayer {
        // Build a minimal attribute set (all nil) – attributes can be enriched later
        let attrs = MasterPlayerAttributes(
            speed: nil, agility: nil, awareness: nil, strength: nil, stamina: nil, injury: nil,
            carrying: nil, trucking: nil, catching: nil, breakTackle: nil, jukeMove: nil, spinMove: nil, stiffArm: nil, acceleration: nil, changeOfDirection: nil,
            throwPower: nil, throwAccuracyShort: nil, throwAccuracyMid: nil, throwAccuracyDeep: nil, throwOnTheRun: nil, throwUnderPressure: nil, playAction: nil,
            tackle: nil, blockShedding: nil, zoneCoverage: nil, manCoverage: nil, pursuit: nil, finesseMoves: nil, powerMoves: nil, press: nil, jumping: nil,
            passBlock: nil, runBlock: nil, impactBlocking: nil,
            kickPower: nil, kickAccuracy: nil,
            release: nil, catchInTraffic: nil, spectacularCatch: nil,
            shortRouteRunning: nil, mediumRouteRunning: nil, deepRouteRunning: nil,
            playRecognition: nil, toughness: nil, hitPower: nil, bCVision: nil, passBlockPower: nil, runBlockPower: nil, passBlockFinesse: nil, runBlockFinesse: nil
        )
        // Use memberwise initializer inside type scope
        return MasterPlayer(
            _firstName: p.firstName,
            _lastName: p.lastName,
            position: p.position,
            team: teamFullName,
            _college: "",
            age: String(p.age),
            overall: String(p.overall),
            height: String(p.height),
            weight: "0",
            handedness: "Right",
            jerseyNum: String(p.number),
            yearsPro: String(max(0, p.age - 22)),
            history: [],
            attributes: attrs,
            actualSalary: p.actualSalary
        )
    }
}

struct MasterPlayerAttributes: Codable {
    // Core attributes
    let speed: Int?
    let agility: Int?
    let awareness: Int?
    let strength: Int?
    let stamina: Int?
    let injury: Int?
    
    // Position-specific attributes (optional)
    let carrying: Int?
    let trucking: Int?
    let catching: Int?
    let breakTackle: Int?
    let jukeMove: Int?
    let spinMove: Int?
    let stiffArm: Int?
    let acceleration: Int?
    let changeOfDirection: Int?
    
    // Quarterback attributes
    let throwPower: Int?
    let throwAccuracyShort: Int?
    let throwAccuracyMid: Int?
    let throwAccuracyDeep: Int?
    let throwOnTheRun: Int?
    let throwUnderPressure: Int?
    let playAction: Int?
    
    // Defensive attributes
    let tackle: Int?
    let blockShedding: Int?
    let zoneCoverage: Int?
    let manCoverage: Int?
    let pursuit: Int?
    let finesseMoves: Int?
    let powerMoves: Int?
    let press: Int?
    let jumping: Int?
    
    // Offensive line attributes
    let passBlock: Int?
    let runBlock: Int?
    let impactBlocking: Int?
    
    // Special teams attributes
    let kickPower: Int?
    let kickAccuracy: Int?
    
    // Receiving attributes
    let release: Int?
    let catchInTraffic: Int?
    let spectacularCatch: Int?
    
    // Route running (newer format)
    let shortRouteRunning: Int?
    let mediumRouteRunning: Int?
    let deepRouteRunning: Int?
    
    // Additional attributes
    let playRecognition: Int?
    let toughness: Int?
    let hitPower: Int?
    let bCVision: Int?
    let passBlockPower: Int?
    let runBlockPower: Int?
    let passBlockFinesse: Int?
    let runBlockFinesse: Int?
}

struct MasterGame: Codable, Identifiable {
    let week: Int
    let awayTeamRealName: String
    let homeTeamRealName: String
    let neutralSiteLocation: String?
    let kickoffISO8601: String?
    
    var id: String {
        "\(week)_\(awayTeamRealName)_vs_\(homeTeamRealName)"
    }
}

// MARK: - Schedule Overrides Support Types
nonisolated struct MasterGameOverride: Codable {
    let week: Int
    let awayTeamRealName: String
    let homeTeamRealName: String
    let neutralSiteLocation: String?
    let kickoffISO8601: String?
    
    // Order-agnostic pairing key so overrides apply regardless of per-team perspective
    var pairKey: String { Self.makePairKey(week: week, a: awayTeamRealName, b: homeTeamRealName) }
    
    static func makePairKey(week: Int, a: String, b: String) -> String {
        let pair = [a, b].sorted()
        return "\(week)_\(pair[0])_\(pair[1])"
    }
}
