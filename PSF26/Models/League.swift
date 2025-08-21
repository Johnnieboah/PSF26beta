import Foundation
import SwiftUI
import Combine

// MARK: - Codable Support Structures
struct PlayoffGameResult: Codable, Equatable {
    let winnerLogoName: String
    let loserLogoName: String
}

// NEW: Bracket Manager persistence structures
struct BracketMatchup: Codable, Equatable {
    let homeTeamLogoName: String
    let awayTeamLogoName: String
    let week: Int
    let round: Int // PlayoffRound.rawValue
    let homeTeamSeed: Int
    let awayTeamSeed: Int
}

struct BracketResult: Codable, Equatable {
    let winnerLogoName: String
    let loserLogoName: String
    let week: Int
    let homeScore: Int
    let awayScore: Int
}

struct League: Codable, Identifiable, Equatable {
    let id: UUID
    let createdDate: Date
    var lastPlayedDate: Date
    
    // Team Information
    let teamName: String
    let teamLogoName: String
    let customLogoData: Data?
    
    // League Settings
    let difficulty: String
    let autoSave: Bool
    let autoSetDepthChart: Bool
    let autoFillTeam: Bool
    let injuriesEnabled: Bool
    let salaryCapEnabled: Bool
    let gameSpeed: String
    
    // League Progress
    var currentWeek: Int
    var wins: Int
    var losses: Int
    var ties: Int
    
    // Training Camp State
    var isInTrainingCamp: Bool
    var trainingCampCompleted: Bool
    
    // Complete League State (NEW) - Optional for backward compatibility
    var allTeams: [LeagueTeam]?
    var completedGames: [GameResult]?
    var upcomingGames: [GameResult]?
    var gameResults: [String: GameResult]?
    
    // Season Statistics (NEW) - Optional for backward compatibility
    var playerSeasonStats: [String: PlayerSeasonStats]?
    var teamSeasonStats: [String: TeamSeasonStats]?
    var gamePlayerStats: [String: [GamePlayerStats]]?  // UUID as String for Codable
    
    // Playoff data (NEW) - Optional for backward compatibility - Fixed for Codable
    var playoffResults: [Int: [PlayoffGameResult]]?
    var playoffTeamLogoNames: [String]?
    
    // NEW: Bracket Manager persistence data
    var bracketHistory: [Int: [BracketMatchup]]?
    var bracketResults: [Int: [BracketResult]]?
    
    // NEW: Season History - Optional for backward compatibility
    var completedSeasons: [SeasonHistory]? = []
    var currentSeasonNumber: Int? = nil // Made optional for backwards compatibility
    
    // Save slot information
    var saveSlotNumber: Int?
    
    init(
        teamName: String,
        teamLogoName: String,
        customLogoData: Data? = nil,
        difficulty: String = "Pro",
        autoSave: Bool = true,
        autoSetDepthChart: Bool = true,
        autoFillTeam: Bool = false,
        injuriesEnabled: Bool = true,
        salaryCapEnabled: Bool = true,
        gameSpeed: String = "Normal"
    ) {
        self.id = UUID()
        self.createdDate = Date()
        self.lastPlayedDate = Date()
        
        self.teamName = teamName
        self.teamLogoName = teamLogoName
        self.customLogoData = customLogoData
        
        self.difficulty = difficulty
        self.autoSave = autoSave
        self.autoSetDepthChart = autoSetDepthChart
        self.autoFillTeam = autoFillTeam
        self.injuriesEnabled = injuriesEnabled
        self.salaryCapEnabled = salaryCapEnabled
        self.gameSpeed = gameSpeed
        
        self.currentWeek = 0  // Start at Week 0 for training camp
        self.wins = 0
        self.losses = 0
        self.ties = 0
        
        // Initialize training camp state
        self.isInTrainingCamp = true
        self.trainingCampCompleted = false
        
        // Initialize new fields
        self.allTeams = []
        self.completedGames = []
        self.upcomingGames = []
        self.gameResults = [:]
    }
    
    var record: String {
        "\(wins)-\(losses)" + (ties > 0 ? "-\(ties)" : "")
    }
    
    /// Checks if the user needs to complete training camp roster cuts
    func needsTrainingCampCuts() -> Bool {
        return isInTrainingCamp && !trainingCampCompleted
    }
    
    /// Marks training camp as completed
    mutating func completeTrainingCamp() {
        trainingCampCompleted = true
        isInTrainingCamp = false
    }
    
    // MARK: - Equatable Conformance
    static func == (lhs: League, rhs: League) -> Bool {
        return lhs.id == rhs.id &&
               lhs.teamName == rhs.teamName &&
               lhs.teamLogoName == rhs.teamLogoName &&
               lhs.currentWeek == rhs.currentWeek &&
               lhs.wins == rhs.wins &&
               lhs.losses == rhs.losses &&
               lhs.ties == rhs.ties
        // Note: We compare only essential fields for equality, not the large stats dictionaries
        // This is intentional as stats are secondary data that shouldn't affect league identity
    }
}

// MARK: - Observable League Wrapper
@MainActor
class ObservableLeague: ObservableObject {
    @Published private var league: League
    
    init(league: League) {
        self.league = league
    }
    
    // MARK: - Computed Properties
    var id: UUID { league.id }
    var createdDate: Date { league.createdDate }
    var lastPlayedDate: Date { 
        get { league.lastPlayedDate }
        set { 
            league.lastPlayedDate = newValue
            objectWillChange.send()
        }
    }
    
    var teamName: String { league.teamName }
    var teamLogoName: String { league.teamLogoName }
    var customLogoData: Data? { league.customLogoData }
    
    var difficulty: String { league.difficulty }
    var autoSave: Bool { league.autoSave }
    var autoSetDepthChart: Bool { league.autoSetDepthChart }
    var autoFillTeam: Bool { league.autoFillTeam }
    var injuriesEnabled: Bool { league.injuriesEnabled }
    var salaryCapEnabled: Bool { league.salaryCapEnabled }
    var gameSpeed: String { league.gameSpeed }
    
    // Training Camp State
    var isInTrainingCamp: Bool {
        get { league.isInTrainingCamp }
        set {
            league.isInTrainingCamp = newValue
            objectWillChange.send()
        }
    }
    
    var trainingCampCompleted: Bool {
        get { league.trainingCampCompleted }
        set {
            league.trainingCampCompleted = newValue
            objectWillChange.send()
        }
    }
    
    var currentWeek: Int { 
        get { league.currentWeek }
        set { 
            league.currentWeek = newValue
            objectWillChange.send()
        }
    }
    
    var wins: Int { 
        get { league.wins }
        set { 
            league.wins = newValue
            objectWillChange.send()
        }
    }
    
    var losses: Int { 
        get { league.losses }
        set { 
            league.losses = newValue
            objectWillChange.send()
        }
    }
    
    var ties: Int { 
        get { league.ties }
        set { 
            league.ties = newValue
            objectWillChange.send()
        }
    }
    
    var saveSlotNumber: Int? { 
        get { league.saveSlotNumber }
        set { 
            league.saveSlotNumber = newValue
            objectWillChange.send()
        }
    }
    
    var completedSeasons: [SeasonHistory]? {
        get { league.completedSeasons }
        set {
            league.completedSeasons = newValue
            objectWillChange.send()
        }
    }
    
    var currentSeasonNumber: Int {
        get { league.currentSeasonNumber ?? 1 } // Default to 1 for backwards compatibility
        set {
            league.currentSeasonNumber = newValue
            objectWillChange.send()
        }
    }
    
    var record: String { league.record }
    
    // MARK: - Methods
    func getLeague() -> League {
        return league
    }
    
    func updateRecord(wins: Int, losses: Int, ties: Int) {
        self.wins = wins
        self.losses = losses
        self.ties = ties
        self.lastPlayedDate = Date()
    }
    
    func advanceWeek() {
        self.currentWeek += 1
        self.lastPlayedDate = Date()
    }
    
    func save(from leagueManager: LeagueManager? = nil) throws {
        // Update the last played date before saving
        league.lastPlayedDate = Date()
        
        // Sync complete league state from manager if provided
        if let manager = leagueManager {
            print("💾 Syncing complete league state before save...")
            league.allTeams = manager.allTeams
            league.completedGames = manager.completedGames
            league.upcomingGames = manager.upcomingGames
            league.currentWeek = manager.currentWeek
            
            // Sync season statistics
            league.playerSeasonStats = manager.playerSeasonStats
            league.teamSeasonStats = manager.teamSeasonStats
            
            // Convert UUID keys to String for Codable compatibility
            var gamePlayerStatsStringKeys: [String: [GamePlayerStats]] = [:]
            for (uuid, stats) in manager.gamePlayerStats {
                gamePlayerStatsStringKeys[uuid.uuidString] = stats
            }
            league.gamePlayerStats = gamePlayerStatsStringKeys
            
            // Also sync user team record from league manager
            if let userTeam = manager.userTeam,
               let userLeagueTeam = manager.allTeams.first(where: { $0.logoName == userTeam.logoName }) {
                league.wins = userLeagueTeam.record.wins
                league.losses = userLeagueTeam.record.losses
                league.ties = userLeagueTeam.record.ties
            }
            
            // Capture game results from shared manager
            league.gameResults = GlobalGameResultsManager.shared.getAllGameResults()
            
            // Sync playoff data using bracket manager (single source of truth)
            league.playoffTeamLogoNames = manager.playoffTeams.map { $0.logoName }
            
            // Sync bracket history and results from bracket manager
            league.bracketHistory = manager.bracketHistory
            league.bracketResults = manager.bracketResults
            
            let playerStatsCount = manager.playerSeasonStats.count
            let teamStatsCount = manager.teamSeasonStats.count
            let bracketResultsCount = manager.bracketResults.values.flatMap { $0 }.count
            print("💾 Synced: \(league.allTeams?.count ?? 0) teams, \(league.completedGames?.count ?? 0) completed games, \(playerStatsCount) player stats, \(teamStatsCount) team stats, \(bracketResultsCount) bracket results, User record: \(league.wins)-\(league.losses)")
        }
        
        try LeagueStorageManager.shared.saveLeague(league)
    }
    
    // MARK: - Training Camp Methods
    
    func needsTrainingCampCuts() -> Bool {
        return league.needsTrainingCampCuts()
    }
    
    func completeTrainingCamp() {
        league.completeTrainingCamp()
        objectWillChange.send()
    }
} 