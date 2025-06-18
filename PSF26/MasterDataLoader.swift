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
    
    /// Async load the 2025Master.json data for optimal performance
    func loadMasterDataAsync() async {
        isLoading = true
        loadingProgress = 0.0
        
        do {
            // Load data on background thread
            let cleanedData = try await withCheckedThrowingContinuation { continuation in
                Task.detached {
                    do {
                        await MainActor.run { self.loadingProgress = 0.1 }
                        
                        guard let url = Bundle.main.url(forResource: "2025Master", withExtension: "json") else {
                            throw DataLoadError.fileNotFound
                        }
                        
                        await MainActor.run { self.loadingProgress = 0.2 }
                        
                        let data = try Data(contentsOf: url)
                        await MainActor.run { self.loadingProgress = 0.4 }
                        
                        let masterData = try JSONDecoder().decode([String: MasterTeamData].self, from: data)
                        await MainActor.run { self.loadingProgress = 0.6 }
                        
                        // Validate and clean the loaded data - this is not async
                        let cleanedData = await MainActor.run { 
                            return self.validateAndCleanData(masterData)
                        }
                        await MainActor.run { self.loadingProgress = 0.8 }
                        
                        continuation.resume(returning: cleanedData)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Update UI on main thread
            self.teams = cleanedData
            self.buildOptimizedCaches(cleanedData)
            self.loadingProgress = 1.0
            self.isDataLoaded = true
            self.isLoading = false
            
            print("✅ Master data loaded successfully: \(cleanedData.count) teams")
            print("🚀 Optimized caches built for instant team access")
            
            // Log performance metrics
            self.logPerformanceMetrics(cleanedData)
            
        } catch {
            self.errorMessage = "Failed to load master data: \(error.localizedDescription)"
            self.isLoading = false
            print("❌ Failed to load master data: \(error)")
        }
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
        return playersByTeam[shortName] ?? []
    }
    
    /// Get all available team names (short names) - pre-sorted
    func getAvailableTeams() -> [String] {
        return allTeamNames
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

    // MARK: - Data Validation (Optimized)
    
    /// Validate and clean the loaded data
    private func validateAndCleanData(_ rawData: [String: MasterTeamData]) -> [String: MasterTeamData] {
        var cleanedData: [String: MasterTeamData] = [:]
        
        for (teamName, teamData) in rawData {
            // Clean team name
            let cleanTeamName = teamName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip Free Agent team if it has too many players (likely not a real team)
            if cleanTeamName == "Free Agent" && teamData.players.count > 100 {
                print("⚠️ Skipping '\(cleanTeamName)' team with \(teamData.players.count) players (likely not a real team)")
                continue
            }
            
            // Clean and validate players
            var cleanedPlayers: [MasterPlayer] = []
            var usedJerseyNumbers: Set<Int> = []
            
            // Process all players and handle jersey number conflicts
            for player in teamData.players {
                // Skip players with invalid basic data
                guard !player.firstName.isEmpty && !player.lastName.isEmpty else { continue }
                
                // Clean and standardize position
                let cleanedPosition = cleanAndStandardizePosition(player.position)
                guard !cleanedPosition.isEmpty else { continue }
                
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
        }
        
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
    let players: [MasterPlayer]
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
    
    // Custom coding keys to map the raw JSON fields
    enum CodingKeys: String, CodingKey {
        case _firstName = "firstName"
        case _lastName = "lastName"
        case position, team
        case _college = "college"
        case age, overall, height, weight, handedness, jerseyNum, yearsPro, history, attributes
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
        
        // Enhanced year removal patterns - catch ALL variations
        // Pattern 1: Years in parentheses like "(1995)" or " (1995)"
        cleaned = cleaned.replacingOccurrences(of: #"\s*\(\d{4}\).*$"#, with: "", options: .regularExpression)
        
        // Pattern 2: Years with just closing parenthesis like "1995)" or " 1995)"
        cleaned = cleaned.replacingOccurrences(of: #"\s*\d{4}\).*$"#, with: "", options: .regularExpression)
        
        // Pattern 3: Standalone years like "1995" or " 1995" - more aggressive
        cleaned = cleaned.replacingOccurrences(of: #"\s*\d{4}.*$"#, with: "", options: .regularExpression)
        
        // Pattern 4: Any 4-digit number (birth years, etc.)
        cleaned = cleaned.replacingOccurrences(of: #"\b\d{4}\b.*$"#, with: "", options: .regularExpression)
        
        // Pattern 5: Remove any trailing parenthesis content
        cleaned = cleaned.replacingOccurrences(of: #"\s*\([^)]*\).*$"#, with: "", options: .regularExpression)
        
        // Pattern 6: Remove any trailing parenthesis without content
        cleaned = cleaned.replacingOccurrences(of: #"\s*[\(\)]+.*$"#, with: "", options: .regularExpression)
        
        // Pattern 7: Remove NFL suffix patterns
        cleaned = cleaned.replacingOccurrences(of: #"\s*(Jr\.?|Sr\.?|III|II|IV).*$"#, with: "", options: .regularExpression)
        
        // Pattern 8: Remove any non-letter characters at the end except apostrophes and hyphens
        cleaned = cleaned.replacingOccurrences(of: #"[^\w\s\-\']+$"#, with: "", options: .regularExpression)
        
        // Clean up extra whitespace again after all replacements
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        // Handle empty names
        if cleaned.isEmpty {
            return name.isEmpty ? "Unknown" : name
        }
        
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
    
    var id: String {
        "\(week)_\(awayTeamRealName)_vs_\(homeTeamRealName)"
    }
}
