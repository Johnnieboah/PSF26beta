import Foundation

// MARK: - Coordinator Models
struct OffensiveCoordinator: Identifiable, Codable, Equatable {
    // FIX: Make id mutable for proper Codable support
    let id: UUID
    let firstName: String
    let lastName: String
    let overallRating: Int
    let offensiveScheme: String
    let experience: Int
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    // Custom initializer
    init(firstName: String, lastName: String, overallRating: Int, offensiveScheme: String, experience: Int) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.overallRating = overallRating
        self.offensiveScheme = offensiveScheme
        self.experience = experience
    }
    
    // Equatable implementation
    static func == (lhs: OffensiveCoordinator, rhs: OffensiveCoordinator) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Performance Optimization Support
    static func placeholder() -> OffensiveCoordinator {
        return OffensiveCoordinator(
            firstName: "Placeholder",
            lastName: "OC",
            overallRating: 50,
            offensiveScheme: "Pro Style",
            experience: 0
        )
    }
}

struct DefensiveCoordinator: Identifiable, Codable, Equatable {
    // FIX: Make id mutable for proper Codable support
    let id: UUID
    let firstName: String
    let lastName: String
    let overallRating: Int
    let defensiveScheme: String
    let experience: Int
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    // Custom initializer
    init(firstName: String, lastName: String, overallRating: Int, defensiveScheme: String, experience: Int) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.overallRating = overallRating
        self.defensiveScheme = defensiveScheme
        self.experience = experience
    }
    
    // Equatable implementation
    static func == (lhs: DefensiveCoordinator, rhs: DefensiveCoordinator) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Performance Optimization Support
    static func placeholder() -> DefensiveCoordinator {
        return DefensiveCoordinator(
            firstName: "Placeholder",
            lastName: "DC",
            overallRating: 50,
            defensiveScheme: "4-3 Base",
            experience: 0
        )
    }
}

// MARK: - Coach Model
struct Coach: Identifiable, Codable, Equatable {
    // FIX: Make id mutable for proper Codable support
    let id: UUID
    let firstName: String
    let lastName: String
    let overallRating: Int
    let offensiveScheme: String
    let defensiveScheme: String
    let experience: Int // Years of coaching experience
    let offensiveCoordinator: OffensiveCoordinator
    let defensiveCoordinator: DefensiveCoordinator
    var record = TeamRecord() // Track coaching record in current league
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    // Custom initializer
    init(firstName: String, lastName: String, overallRating: Int, offensiveScheme: String, defensiveScheme: String, experience: Int, offensiveCoordinator: OffensiveCoordinator, defensiveCoordinator: DefensiveCoordinator) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.overallRating = overallRating
        self.offensiveScheme = offensiveScheme
        self.defensiveScheme = defensiveScheme
        self.experience = experience
        self.offensiveCoordinator = offensiveCoordinator
        self.defensiveCoordinator = defensiveCoordinator
        self.record = TeamRecord()
    }
    
    // Equatable implementation
    static func == (lhs: Coach, rhs: Coach) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Calculate scheme matching bonus
    var schemeMatchingBonus: Double {
        var bonus = 0.0
        
        // Offensive scheme matching bonus
        if offensiveScheme == offensiveCoordinator.offensiveScheme {
            bonus += 0.03 // 3% bonus for matching offensive schemes
        }
        
        // Defensive scheme matching bonus
        if defensiveScheme == defensiveCoordinator.defensiveScheme {
            bonus += 0.03 // 3% bonus for matching defensive schemes
        }
        
        // Perfect match bonus (both sides match)
        if offensiveScheme == offensiveCoordinator.offensiveScheme && 
           defensiveScheme == defensiveCoordinator.defensiveScheme {
            bonus += 0.02 // Additional 2% for perfect coordination (8% total)
        }
        
        return bonus
    }
    
    // MARK: - Performance Optimization Support
    static func placeholder() -> Coach {
        return Coach(
            firstName: "Placeholder",
            lastName: "Coach",
            overallRating: 50,
            offensiveScheme: "Pro Style",
            defensiveScheme: "4-3 Base",
            experience: 0,
            offensiveCoordinator: OffensiveCoordinator.placeholder(),
            defensiveCoordinator: DefensiveCoordinator.placeholder()
        )
    }
}

// MARK: - League Team Model
struct LeagueTeam: Identifiable, Codable, Equatable {
    // FIX: Make id mutable for proper Codable support
    let id: UUID
    let logoName: String
    let name: String
    let conference: String
    let division: String
    let primaryColor: String
    let secondaryColor: String
    var players: [PlayerData]
    let overallRating: Int
    var coach: Coach // Make coach mutable so we can update their record
    var record = TeamRecord()
    var divisionRank: Int = 1
    
    // Custom initializer
    init(logoName: String, name: String, conference: String, division: String, primaryColor: String, secondaryColor: String, players: [PlayerData], overallRating: Int, coach: Coach) {
        self.id = UUID()
        self.logoName = logoName
        self.name = name
        self.conference = conference
        self.division = division
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.players = players
        self.overallRating = overallRating
        self.coach = coach
        self.record = TeamRecord()
        self.divisionRank = 1
    }
    
    // Equatable implementation
    static func == (lhs: LeagueTeam, rhs: LeagueTeam) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Performance Optimization Support
    static func placeholder() -> LeagueTeam {
        return LeagueTeam(
            logoName: "",
            name: "Placeholder Team",
            conference: "",
            division: "",
            primaryColor: "",
            secondaryColor: "",
            players: [],
            overallRating: 0,
            coach: Coach.placeholder()
        )
    }
    
    // MARK: - Conversion Methods
    static func createFromTeamData(_ teamData: TeamData) -> LeagueTeam {
        let colors = TeamColorMapping.getColors(for: teamData.logoName)
        let leagueManager = LeagueManager()
        
        return LeagueTeam(
            logoName: teamData.logoName,
            name: TeamData.getTeamDisplayName(teamData.logoName),
            conference: leagueManager.getConferenceForTeam(teamData.logoName),
            division: leagueManager.getDivisionForTeam(teamData.logoName),
            primaryColor: colors.primary,
            secondaryColor: colors.secondary,
            players: teamData.players,
            overallRating: leagueManager.getTeamOverall(players: teamData.players),
            coach: leagueManager.getCoachForTeam(teamData.logoName)
        )
    }
    
    var asTeamData: TeamData {
        TeamData.createTeamFromData(name: logoName)
    }
}

// MARK: - Team Record Model
struct TeamRecord: Codable, Equatable, Hashable {
    var wins: Int = 0
    var losses: Int = 0
    var ties: Int = 0
    
    var gamesPlayed: Int {
        wins + losses + ties
    }
    
    var winPercentage: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return Double(wins) / Double(gamesPlayed)
    }
    
    var description: String {
        return "\(wins)-\(losses)" + (ties > 0 ? "-\(ties)" : "")
    }
}

// MARK: - Game Result Model
struct GameResult: Identifiable, Codable, Equatable {
    // FIX: Make id mutable for proper Codable support
    let id: UUID
    var week: Int
    let homeTeam: LeagueTeam
    let awayTeam: LeagueTeam
    var homeScore: Int = 0
    var awayScore: Int = 0
    var isCompleted: Bool = false
    
    // Enhanced stats for advanced simulation
    var detailedStats: DetailedGameStats?
    var playByPlaySummary: [String]? = []  // Make optional for backward compatibility
    var gameLength: TimeInterval? = 0  // Make optional for backward compatibility
    var scoringPlays: [ScoringPlay] = []
    
    // Default initializer
    init(week: Int, homeTeam: LeagueTeam, awayTeam: LeagueTeam) {
        self.id = UUID()
        self.week = week
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeScore = 0
        self.awayScore = 0
        self.isCompleted = false
    }
    
    // Custom initializer with ID
    init(id: UUID, week: Int, homeTeam: LeagueTeam, awayTeam: LeagueTeam) {
        self.id = id
        self.week = week
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeScore = 0
        self.awayScore = 0
        self.isCompleted = false
    }
    
    // Equatable implementation
    static func == (lhs: GameResult, rhs: GameResult) -> Bool {
        return lhs.id == rhs.id
    }
    
    var winningTeam: LeagueTeam? {
        guard isCompleted else { return nil }
        if homeScore > awayScore {
            return homeTeam
        } else if awayScore > homeScore {
            return awayTeam
        }
        return nil // Tie
    }
    
    // Computed properties for enhanced stats display
    var totalYards: (home: Int, away: Int) {
        guard let stats = detailedStats else { return (0, 0) }
        return (stats.homeTeamStats.totalYards, stats.awayTeamStats.totalYards)
    }
    
    var turnovers: (home: Int, away: Int) {
        guard let stats = detailedStats else { return (0, 0) }
        return (stats.homeTeamStats.turnovers, stats.awayTeamStats.turnovers)
    }
    
    var timeOfPossession: (home: String, away: String) {
        guard let stats = detailedStats else { return ("30:00", "30:00") }
        return (stats.homeTimeOfPossession, stats.awayTimeOfPossession)
    }
}

extension GameResult {
    static func placeholderForBlock() -> GameResult {
        let emptyCoach = Coach.placeholder()
        let emptyTeam = LeagueTeam(logoName: "", name: "", conference: "", division: "", primaryColor: "", secondaryColor: "", players: [], overallRating: 0, coach: emptyCoach)
        return GameResult(id: UUID(), week: 0, homeTeam: emptyTeam, awayTeam: emptyTeam)
    }
}

// MARK: - Detailed Game Statistics
struct DetailedGameStats: Codable {
    let homeTeamStats: TeamGameStats
    let awayTeamStats: TeamGameStats
    let totalPlays: Int
    let gameLength: TimeInterval
    let bigPlays: Int // 20+ yard plays
    let scoringDrives: Int
    
    var homeTimeOfPossession: String {
        let minutes = Int(homeTeamStats.timeOfPossession) / 60
        let seconds = Int(homeTeamStats.timeOfPossession) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var awayTimeOfPossession: String {
        let minutes = Int(awayTeamStats.timeOfPossession) / 60
        let seconds = Int(awayTeamStats.timeOfPossession) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Team Game Statistics
struct TeamGameStats: Codable {
    // Passing Stats
    var passingYards: Int = 0
    var passingAttempts: Int = 0
    var passingCompletions: Int = 0
    var passingTouchdowns: Int = 0
    var interceptions: Int = 0
    var sacks: Int = 0
    var sacksAllowed: Int = 0
    
    // Rushing Stats
    var rushingYards: Int = 0
    var rushingAttempts: Int = 0
    var rushingTouchdowns: Int = 0
    var fumbles: Int = 0
    var fumblesLost: Int = 0
    
    // General Stats
    var totalYards: Int = 0
    var firstDowns: Int = 0
    var thirdDownAttempts: Int = 0
    var thirdDownConversions: Int = 0
    var fourthDownAttempts: Int = 0
    var fourthDownConversions: Int = 0
    var redZoneAttempts: Int = 0
    var redZoneScores: Int = 0
    var penalties: Int = 0
    var penaltyYards: Int = 0
    var turnovers: Int = 0
    var timeOfPossession: TimeInterval = 0
    
    // Kicking Stats
    var fieldGoalAttempts: Int = 0
    var fieldGoalsMade: Int = 0
    var extraPointAttempts: Int = 0
    var extraPointsMade: Int = 0
    var punts: Int = 0
    var puntYards: Int = 0
    
    // Computed properties
    var completionPercentage: Double {
        guard passingAttempts > 0 else { return 0.0 }
        return Double(passingCompletions) / Double(passingAttempts) * 100.0
    }
    
    var thirdDownPercentage: Double {
        guard thirdDownAttempts > 0 else { return 0.0 }
        return Double(thirdDownConversions) / Double(thirdDownAttempts) * 100.0
    }
    
    var redZonePercentage: Double {
        guard redZoneAttempts > 0 else { return 0.0 }
        return Double(redZoneScores) / Double(redZoneAttempts) * 100.0
    }
    
    var fieldGoalPercentage: Double {
        guard fieldGoalAttempts > 0 else { return 0.0 }
        return Double(fieldGoalsMade) / Double(fieldGoalAttempts) * 100.0
    }
}

// MARK: - Scoring Play
struct ScoringPlay: Codable, Identifiable {
    let id = UUID()
    let quarter: Int
    let time: String
    let team: String
    let playType: String
    let description: String
    let points: Int
    let homeScore: Int
    let awayScore: Int
    
    // Exclude id from Codable to avoid warning about immutable property with initial value
    private enum CodingKeys: String, CodingKey {
        case quarter, time, team, playType, description, points, homeScore, awayScore
    }
}

// MARK: - League Gameplay Settings
struct LeagueGameplaySettings {
    var difficulty: GameDifficulty
    var autoSave: Bool
    var autoSetDepthChart: Bool
    var autoFillTeam: Bool
    var injuriesEnabled: Bool
    var salaryCapEnabled: Bool
    var acceleratedClock: Bool
    var gameSpeed: GameSpeed
    
    static func defaultSettings() -> LeagueGameplaySettings {
        return LeagueGameplaySettings(
            difficulty: .pro,
            autoSave: true,
            autoSetDepthChart: true,
            autoFillTeam: false,
            injuriesEnabled: true,
            salaryCapEnabled: true,
            acceleratedClock: false,
            gameSpeed: .normal
        )
    }
}

enum GameDifficulty: String, CaseIterable {
    case rookie = "Rookie"
    case semiPro = "Semi-Pro"
    case pro = "Pro"
    case hallOfFame = "Hall of Fame"
}

enum GameSpeed: String, CaseIterable {
    case slow = "Slow"
    case normal = "Normal"
    case fast = "Fast"
}

// MARK: - Comprehensive Player Statistics
struct PlayerSeasonStats: Codable, Identifiable {
    let id = UUID()
    let playerId: String // firstName_lastName_jerseyNum
    let playerName: String
    let position: String
    let teamLogoName: String
    
    // Passing Stats (QB primarily)
    var passingAttempts: Int = 0
    var passingCompletions: Int = 0
    var passingYards: Int = 0
    var passingTouchdowns: Int = 0
    var interceptions: Int = 0
    var sacks: Int = 0
    var qbRating: Double = 0.0
    var longestPass: Int = 0
    
    // Rushing Stats (RB, QB, WR, etc.)
    var rushingAttempts: Int = 0
    var rushingYards: Int = 0
    var rushingTouchdowns: Int = 0
    var fumbles: Int = 0
    var longestRush: Int = 0
    
    // Receiving Stats (WR, TE, RB)
    var receptions: Int = 0
    var receivingYards: Int = 0
    var receivingTouchdowns: Int = 0
    var droppedPasses: Int = 0
    var longestReception: Int = 0
    
    // Defensive Stats
    var tackles: Int = 0
    var assistedTackles: Int = 0
    var sacksMade: Int = 0
    var interceptionsDefense: Int = 0
    var passesDefended: Int = 0
    var forcedFumbles: Int = 0
    var fumbleRecoveries: Int = 0
    var defensiveTouchdowns: Int = 0
    var safeties: Int = 0
    
    // Kicking Stats (K)
    var fieldGoalAttempts: Int = 0
    var fieldGoalsMade: Int = 0
    var extraPointAttempts: Int = 0
    var extraPointsMade: Int = 0
    var longestFieldGoal: Int = 0
    
    // Punting Stats (P)
    var punts: Int = 0
    var puntYards: Int = 0
    var longestPunt: Int = 0
    var puntsInside20: Int = 0
    
    // Return Stats
    var kickoffReturns: Int = 0
    var kickoffReturnYards: Int = 0
    var kickoffReturnTouchdowns: Int = 0
    var puntReturns: Int = 0
    var puntReturnYards: Int = 0
    var puntReturnTouchdowns: Int = 0
    
    // Games played
    var gamesPlayed: Int = 0
    
    // Computed properties for advanced stats
    var completionPercentage: Double {
        guard passingAttempts > 0 else { return 0.0 }
        return Double(passingCompletions) / Double(passingAttempts) * 100.0
    }
    
    var yardsPerAttempt: Double {
        guard passingAttempts > 0 else { return 0.0 }
        return Double(passingYards) / Double(passingAttempts)
    }
    
    var yardsPerCarry: Double {
        guard rushingAttempts > 0 else { return 0.0 }
        return Double(rushingYards) / Double(rushingAttempts)
    }
    
    var yardsPerReception: Double {
        guard receptions > 0 else { return 0.0 }
        return Double(receivingYards) / Double(receptions)
    }
    
    var fieldGoalPercentage: Double {
        guard fieldGoalAttempts > 0 else { return 0.0 }
        return Double(fieldGoalsMade) / Double(fieldGoalAttempts) * 100.0
    }
    
    var averagePuntYards: Double {
        guard punts > 0 else { return 0.0 }
        return Double(puntYards) / Double(punts)
    }
    
    var totalTouchdowns: Int {
        return passingTouchdowns + rushingTouchdowns + receivingTouchdowns + defensiveTouchdowns + kickoffReturnTouchdowns + puntReturnTouchdowns
    }
    
    /// Phase 5: Converts PlayerSeasonStats to PlayerData for player detail view
    func toPlayerData() -> PlayerData {
        // Extract name components from playerName
        let nameComponents = playerName.components(separatedBy: " ")
        let firstName = nameComponents.first ?? ""
        let lastName = nameComponents.count > 1 ? nameComponents.dropFirst().joined(separator: " ") : ""
        
        // Calculate overall rating based on performance (rough estimation)
        let estimatedOverall = calculateEstimatedOverall()
        
        return PlayerData(
            firstName: firstName,
            lastName: lastName,
            position: position,
            number: extractJerseyNumber(),
            overall: estimatedOverall,
            age: 25 // Default age since not stored in season stats
        )
    }
    
    private func calculateEstimatedOverall() -> Int {
        // Basic overall calculation based on stats performance
        // This is a rough estimation for display purposes
        switch position {
        case "QB":
            let yardsPer = Double(passingYards) / max(1.0, Double(gamesPlayed))
            let tdPer = Double(passingTouchdowns) / max(1.0, Double(gamesPlayed))
            let completion = completionPercentage
            return min(99, max(70, Int(70 + (yardsPer / 15) + (tdPer * 3) + (completion / 5))))
        case "RB", "FB":
            let yardsPer = Double(rushingYards) / max(1.0, Double(gamesPlayed))
            let tdPer = Double(rushingTouchdowns) / max(1.0, Double(gamesPlayed))
            return min(99, max(70, Int(70 + (yardsPer / 8) + (tdPer * 5))))
        case "WR", "TE":
            let yardsPer = Double(receivingYards) / max(1.0, Double(gamesPlayed))
            let tdPer = Double(receivingTouchdowns) / max(1.0, Double(gamesPlayed))
            return min(99, max(70, Int(70 + (yardsPer / 10) + (tdPer * 4))))
        default: // Defensive players
            let tacklesPer = Double(tackles) / max(1.0, Double(gamesPlayed))
            let sacksPer = Double(sacksMade) / max(1.0, Double(gamesPlayed))
            return min(99, max(70, Int(70 + (tacklesPer / 0.8) + (sacksPer * 10))))
        }
    }
    
    private func extractJerseyNumber() -> Int {
        // Extract jersey number from playerId (format: firstName_lastName_jerseyNum)
        let components = playerId.components(separatedBy: "_")
        if let jerseyString = components.last, let jerseyNumber = Int(jerseyString) {
            return jerseyNumber
        }
        return 1 // Default fallback
    }
    
    private enum CodingKeys: String, CodingKey {
        case playerId, playerName, position, teamLogoName
        case passingAttempts, passingCompletions, passingYards, passingTouchdowns, interceptions, sacks, qbRating, longestPass
        case rushingAttempts, rushingYards, rushingTouchdowns, fumbles, longestRush
        case receptions, receivingYards, receivingTouchdowns, droppedPasses, longestReception
        case tackles, assistedTackles, sacksMade, interceptionsDefense, passesDefended, forcedFumbles, fumbleRecoveries, defensiveTouchdowns, safeties
        case fieldGoalAttempts, fieldGoalsMade, extraPointAttempts, extraPointsMade, longestFieldGoal
        case punts, puntYards, longestPunt, puntsInside20
        case kickoffReturns, kickoffReturnYards, kickoffReturnTouchdowns, puntReturns, puntReturnYards, puntReturnTouchdowns
        case gamesPlayed
    }
}

// MARK: - Team Season Statistics
struct TeamSeasonStats: Codable, Identifiable {
    let id = UUID()
    let teamLogoName: String
    
    // Offensive Team Stats
    var totalOffensiveYards: Int = 0
    var totalPassingYards: Int = 0
    var totalRushingYards: Int = 0
    var totalPoints: Int = 0
    var totalTouchdowns: Int = 0
    var totalFirstDowns: Int = 0
    var thirdDownAttempts: Int = 0
    var thirdDownConversions: Int = 0
    var redZoneAttempts: Int = 0
    var redZoneScores: Int = 0
    var totalPenalties: Int = 0
    var totalPenaltyYards: Int = 0
    var totalTurnovers: Int = 0
    var timeOfPossession: TimeInterval = 0
    
    // Defensive Team Stats
    var totalYardsAllowed: Int = 0
    var passingYardsAllowed: Int = 0
    var rushingYardsAllowed: Int = 0
    var pointsAllowed: Int = 0
    var sacksAllowed: Int = 0
    var interceptionsForced: Int = 0
    var fumblesForced: Int = 0
    var defensiveTouchdowns: Int = 0
    var safeties: Int = 0
    
    // Special Teams Stats
    var fieldGoalsAttempted: Int = 0
    var fieldGoalsMade: Int = 0
    var extraPointsAttempted: Int = 0
    var extraPointsMade: Int = 0
    var totalPunts: Int = 0
    var totalPuntYards: Int = 0
    
    // Games played
    var gamesPlayed: Int = 0
    
    // Computed properties
    var yardsPerGame: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return Double(totalOffensiveYards) / Double(gamesPlayed)
    }
    
    var pointsPerGame: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return Double(totalPoints) / Double(gamesPlayed)
    }
    
    var yardsAllowedPerGame: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return Double(totalYardsAllowed) / Double(gamesPlayed)
    }
    
    var pointsAllowedPerGame: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return Double(pointsAllowed) / Double(gamesPlayed)
    }
    
    var thirdDownPercentage: Double {
        guard thirdDownAttempts > 0 else { return 0.0 }
        return Double(thirdDownConversions) / Double(thirdDownAttempts) * 100.0
    }
    
    var redZonePercentage: Double {
        guard redZoneAttempts > 0 else { return 0.0 }
        return Double(redZoneScores) / Double(redZoneAttempts) * 100.0
    }
    
    var fieldGoalPercentage: Double {
        guard fieldGoalsAttempted > 0 else { return 0.0 }
        return Double(fieldGoalsMade) / Double(fieldGoalsAttempted) * 100.0
    }
    
    private enum CodingKeys: String, CodingKey {
        case teamLogoName
        case totalOffensiveYards, totalPassingYards, totalRushingYards, totalPoints, totalTouchdowns, totalFirstDowns
        case thirdDownAttempts, thirdDownConversions, redZoneAttempts, redZoneScores, totalPenalties, totalPenaltyYards, totalTurnovers, timeOfPossession
        case totalYardsAllowed, passingYardsAllowed, rushingYardsAllowed, pointsAllowed, sacksAllowed, interceptionsForced, fumblesForced, defensiveTouchdowns, safeties
        case fieldGoalsAttempted, fieldGoalsMade, extraPointsAttempted, extraPointsMade, totalPunts, totalPuntYards
        case gamesPlayed
    }
}

// MARK: - Game Player Statistics (for individual game tracking)
struct GamePlayerStats: Codable, Identifiable {
    let id = UUID()
    let gameId: UUID
    let playerId: String
    let playerName: String
    let position: String
    let teamLogoName: String
    let week: Int
    
    // Game-specific stats (same structure as season stats but for one game)
    var passingAttempts: Int = 0
    var passingCompletions: Int = 0
    var passingYards: Int = 0
    var passingTouchdowns: Int = 0
    var interceptions: Int = 0
    var rushingAttempts: Int = 0
    var rushingYards: Int = 0
    var rushingTouchdowns: Int = 0
    var receptions: Int = 0
    var receivingYards: Int = 0
    var receivingTouchdowns: Int = 0
    var tackles: Int = 0
    var sacksMade: Int = 0
    var interceptionsDefense: Int = 0
    var passesDefended: Int = 0
    var forcedFumbles: Int = 0
    var fumbleRecoveries: Int = 0
    var fieldGoalAttempts: Int = 0
    var fieldGoalsMade: Int = 0
    var extraPointAttempts: Int = 0
    var extraPointsMade: Int = 0
    var punts: Int = 0
    var puntYards: Int = 0
    // ... other stats as needed
    
    // Custom decoder to handle missing fields in older save files
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        gameId = try container.decode(UUID.self, forKey: .gameId)
        playerId = try container.decode(String.self, forKey: .playerId)
        playerName = try container.decode(String.self, forKey: .playerName)
        position = try container.decode(String.self, forKey: .position)
        teamLogoName = try container.decode(String.self, forKey: .teamLogoName)
        week = try container.decode(Int.self, forKey: .week)
        
        // Optional fields with defaults (handles missing fields in older saves)
        passingAttempts = try container.decodeIfPresent(Int.self, forKey: .passingAttempts) ?? 0
        passingCompletions = try container.decodeIfPresent(Int.self, forKey: .passingCompletions) ?? 0
        passingYards = try container.decodeIfPresent(Int.self, forKey: .passingYards) ?? 0
        passingTouchdowns = try container.decodeIfPresent(Int.self, forKey: .passingTouchdowns) ?? 0
        interceptions = try container.decodeIfPresent(Int.self, forKey: .interceptions) ?? 0
        rushingAttempts = try container.decodeIfPresent(Int.self, forKey: .rushingAttempts) ?? 0
        rushingYards = try container.decodeIfPresent(Int.self, forKey: .rushingYards) ?? 0
        rushingTouchdowns = try container.decodeIfPresent(Int.self, forKey: .rushingTouchdowns) ?? 0
        receptions = try container.decodeIfPresent(Int.self, forKey: .receptions) ?? 0
        receivingYards = try container.decodeIfPresent(Int.self, forKey: .receivingYards) ?? 0
        receivingTouchdowns = try container.decodeIfPresent(Int.self, forKey: .receivingTouchdowns) ?? 0
        tackles = try container.decodeIfPresent(Int.self, forKey: .tackles) ?? 0
        sacksMade = try container.decodeIfPresent(Int.self, forKey: .sacksMade) ?? 0
        interceptionsDefense = try container.decodeIfPresent(Int.self, forKey: .interceptionsDefense) ?? 0
        passesDefended = try container.decodeIfPresent(Int.self, forKey: .passesDefended) ?? 0
        forcedFumbles = try container.decodeIfPresent(Int.self, forKey: .forcedFumbles) ?? 0
        fumbleRecoveries = try container.decodeIfPresent(Int.self, forKey: .fumbleRecoveries) ?? 0
        fieldGoalAttempts = try container.decodeIfPresent(Int.self, forKey: .fieldGoalAttempts) ?? 0
        fieldGoalsMade = try container.decodeIfPresent(Int.self, forKey: .fieldGoalsMade) ?? 0
        extraPointAttempts = try container.decodeIfPresent(Int.self, forKey: .extraPointAttempts) ?? 0
        extraPointsMade = try container.decodeIfPresent(Int.self, forKey: .extraPointsMade) ?? 0
        punts = try container.decodeIfPresent(Int.self, forKey: .punts) ?? 0
        puntYards = try container.decodeIfPresent(Int.self, forKey: .puntYards) ?? 0
    }
    
    // Default initializer
    init(gameId: UUID, playerId: String, playerName: String, position: String, teamLogoName: String, week: Int) {
        self.gameId = gameId
        self.playerId = playerId
        self.playerName = playerName
        self.position = position
        self.teamLogoName = teamLogoName
        self.week = week
    }
    
    private enum CodingKeys: String, CodingKey {
        case gameId, playerId, playerName, position, teamLogoName, week
        case passingAttempts, passingCompletions, passingYards, passingTouchdowns, interceptions
        case rushingAttempts, rushingYards, rushingTouchdowns
        case receptions, receivingYards, receivingTouchdowns
        case tackles, sacksMade, interceptionsDefense, passesDefended, forcedFumbles, fumbleRecoveries
        case fieldGoalAttempts, fieldGoalsMade, extraPointAttempts, extraPointsMade, punts, puntYards
    }
}

// MARK: - Season History Data Models
struct SeasonHistory: Codable, Identifiable, Hashable {
    let seasonYear: Int
    let completedDate: Date
    
    // Computed property for Identifiable conformance
    var id: Int { seasonYear }
    
    // Champions
    let superBowlWinner: String
    let superBowlRunnerUp: String
    let afcChampion: String
    let nfcChampion: String
    
    // Division Champions
    let afcEast: String
    let afcNorth: String
    let afcSouth: String
    let afcWest: String
    let nfcEast: String
    let nfcNorth: String
    let nfcSouth: String
    let nfcWest: String
    
    // Stat Leaders
    let passingYardsLeader: StatLeader
    let rushingYardsLeader: StatLeader
    let receivingYardsLeader: StatLeader
    let passingTouchdownsLeader: StatLeader
    let rushingTouchdownsLeader: StatLeader
    let receivingTouchdownsLeader: StatLeader
    let tacklesLeader: StatLeader
    let sacksLeader: StatLeader
    let interceptionsLeader: StatLeader
    
    // User team info
    let userTeamRecord: TeamRecord
    let userTeamFinalRank: Int
}

struct StatLeader: Codable, Hashable {
    let playerName: String
    let teamLogoName: String
    let position: String
    let statValue: Int
    let statDescription: String // "3,421 yards", "24 TDs", etc.
}
