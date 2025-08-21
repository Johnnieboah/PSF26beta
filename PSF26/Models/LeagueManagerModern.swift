import Foundation
import SwiftUI
import Combine

// MARK: - Refactored League Manager using extracted managers
@MainActor
class LeagueManager_Refactored: ObservableObject {
    @Published var allTeams: [LeagueTeam] = []
    @Published var completedGames: [GameResult] = []
    @Published var upcomingGames: [GameResult] = []
    @Published var currentWeek: Int = 0
    @Published var userTeam: LeagueTeam?
    @Published var settings: LeagueGameplaySettings = .defaultSettings()
    @Published var latestUserGameResult: (week: Int, userScore: Int, opponentScore: Int, opponent: String)? = nil
    
    // Season tracking for contract negotiations
    @Published var currentSeasonNumber: Int = 1
    
    // Training camp status
    @Published var isInTrainingCamp: Bool = true
    
    // Phase 3: Store league ID for hybrid data loading
    var currentLeagueId: UUID?
    
    // Extracted managers
    private let teamSetupManager = TeamSetupManager()
    private let coreLeagueManager = CoreLeagueManager.shared
    private let gameplayManager = GameplayManager.shared
    
    var teamRecord: TeamRecord {
        guard let userTeam = userTeam else { return TeamRecord() }
        return getTeamRecord(for: userTeam.logoName)
    }
    
    private let masterDataLoader = MasterDataLoader.shared
    
    // MARK: - Statistics Tracking (delegated to existing manager)
    private lazy var statisticsManager = LeagueStatisticsManager(leagueManager: self)
    
    // Computed properties for backwards compatibility
    var playerSeasonStats: [String: PlayerSeasonStats] { statisticsManager.playerSeasonStats }
    var teamSeasonStats: [String: TeamSeasonStats] { statisticsManager.teamSeasonStats }
    var gamePlayerStats: [UUID: [GamePlayerStats]] { statisticsManager.gamePlayerStats }
    
    // Batch simulation mode to reduce UI updates
    private var isBatchSimulating = false
    private var batchModeEnabled = false
    private var pendingUIUpdates = false
    
    // MARK: - Performance Optimization - Object Pooling
    class GameResultPool {
        private var pool: [GameResult] = []
        private let maxPoolSize = 100
        
        func borrowGameResult() -> GameResult {
            if pool.isEmpty {
                return GameResult(
                    week: 0,
                    homeTeam: LeagueTeam.placeholder(),
                    awayTeam: LeagueTeam.placeholder()
                )
            } else {
                return pool.removeLast()
            }
        }
        
        func returnGameResult(_ result: GameResult) {
            guard pool.count < maxPoolSize else { return }
            
            // Reset the game result for reuse
            var resetResult = result
            resetResult.homeScore = 0
            resetResult.awayScore = 0
            resetResult.isCompleted = false
            
            pool.append(resetResult)
        }
    }
    
    private let gameResultPool = GameResultPool()
    
    // MARK: - Public Methods
    func getTeamRecord(for teamLogoName: String) -> TeamRecord {
        guard let team = allTeams.first(where: { $0.logoName == teamLogoName }) else {
            return TeamRecord()
        }
        return team.record
    }
    
    func getPlayoffTeams() -> [LeagueTeam] {
        // Use GameplayManager for playoff team determination
        let afcTeams = GameplayManager.shared.getConferenceStandings(teams: allTeams, conference: "ACFT")
        let nfcTeams = GameplayManager.shared.getConferenceStandings(teams: allTeams, conference: "NCFT")
        
        return Array(afcTeams.prefix(7)) + Array(nfcTeams.prefix(7))
    }
    
    // MARK: - League Setup using TeamSetupManager
    func setupLeague(selectedTeam: TeamData, settings: LeagueGameplaySettings, savedState: League? = nil, leagueId: UUID? = nil, isTrainingCamp: Bool = false) {
        // Convert TeamData to LeagueTeam using TeamSetupManager
        let coach = TeamSetupManager.generateCoachForTeam(teamName: selectedTeam.logoName)
        let colors = TeamColorMapping.getColors(for: selectedTeam.logoName)
        
        let userLeagueTeam = LeagueTeam(
            logoName: selectedTeam.logoName,
            name: TeamData.getTeamDisplayName(selectedTeam.logoName),
            conference: TeamSetupManager.getProperConference(for: selectedTeam.logoName).rawValue,
            division: TeamSetupManager.getProperDivision(for: selectedTeam.logoName).rawValue,
            primaryColor: colors.primary,
            secondaryColor: colors.secondary,
            players: selectedTeam.players,
            overallRating: TeamSetupManager.calculateTeamOverall(players: selectedTeam.players, teamName: selectedTeam.logoName),
            coach: coach
        )
        
        self.userTeam = userLeagueTeam
        self.settings = settings
        self.currentLeagueId = leagueId
        self.isInTrainingCamp = isTrainingCamp
        
        if let saved = savedState, 
           let savedTeams = saved.allTeams, !savedTeams.isEmpty {
            // RESTORE mode - load existing state
            print("🔄 Restoring league state from save...")
            self.allTeams = savedTeams
            self.completedGames = saved.completedGames ?? []
            self.upcomingGames = saved.upcomingGames ?? []
            self.currentWeek = saved.currentWeek
            
            // Restore training camp state from saved league
            self.isInTrainingCamp = saved.isInTrainingCamp
            
            // Restore game results to shared manager
            GlobalGameResultsManager.shared.restoreGameResults(saved.gameResults ?? [:])
            
            print("✅ League state restored: \(allTeams.count) teams, \(completedGames.count) completed games, Week \(currentWeek), Training Camp: \(isInTrainingCamp)")
        } else {
            // CREATE mode - build from scratch using extracted managers
            print("🆕 Creating new league from scratch...")
            
            // Create all NFL teams using TeamSetupManager
            allTeams = TeamSetupManager.createAllTeams(leagueId: leagueId, isTrainingCamp: isTrainingCamp)

            // Replace roster source: build 100% from PFL2025DATA.csv (ignore master data)
            if let csvURL = ContractImporter.locateCSV() {
                let csvRosters = ContractImporter.buildRosters(from: csvURL)
                for i in 0..<allTeams.count {
                    let key = allTeams[i].logoName
                    if let players = csvRosters[key] {
                        allTeams[i].players = players // keep 74 (or CSV count) as-is
                    }
                }
            }
            
            // Generate season schedule using CoreLeagueManager
            upcomingGames = coreLeagueManager.generateSeasonSchedule(teams: allTeams, masterDataLoader: masterDataLoader)
            
            // Recalculate all team overalls using TeamSetupManager
            TeamSetupManager.recalculateAllTeamOveralls(teams: &allTeams)
            
            // Initialize season statistics for all teams and players
            initializeSeasonStats()
            
            // Skip salary redistribution; use CSV APY directly as actualSalary
            
            // Do not trim or auto-adjust training camp rosters; keep CSV counts (often ~74)
            
            print("✅ League setup completed with \(allTeams.count) teams and \(upcomingGames.count) games")
        }
    }
    
    // MARK: - Training Camp Methods using TeamSetupManager
    func canUserTeamAdvanceFromTrainingCamp() -> (canAdvance: Bool, issues: [String]) {
        return TeamSetupManager.canUserTeamAdvanceFromTrainingCamp(userTeam: userTeam)
    }
    
    func executeAITeamTrainingCampCuts() {
        print("🤖 Executing AI team training camp cuts with cap compliance...")
        // CPU teams: enforce 53 and cap >= -$5M (capSlack = 5_000_000)
        for i in 0..<allTeams.count {
            if let user = userTeam?.logoName, allTeams[i].logoName == user { continue }
            var team = allTeams[i]
            let result = TrainingCampManager.enforceCapCompliance(team: &team, finalCount: 53, capSlack: 5_000_000)
            allTeams[i] = team
            #if DEBUG
            if !result.cuts.isEmpty {
                let names = result.cuts.prefix(5).map { "\($0.fullName) \($0.position)" }.joined(separator: ", ")
                print("🧮 AI GM cuts for \(team.logoName): \(result.cuts.count) players, savings $\(result.savings / 1_000_000)M (compliance: \(result.didComply)) e.g. \(names)")
            }
            #endif
        }
        print("🤖 AI team cuts complete")
    }
    
    // MARK: - Schedule Management using CoreLeagueManager
    func getGamesForWeek(_ week: Int) -> [GameResult] {
        return coreLeagueManager.getGamesForWeek(week, from: upcomingGames + completedGames)
    }
    
    func getGamesForTeam(_ teamLogoName: String) -> [GameResult] {
        return coreLeagueManager.getGamesForTeam(teamLogoName, from: upcomingGames + completedGames)
    }
    
    func getRemainingGamesForTeam(_ teamLogoName: String) -> [GameResult] {
        return coreLeagueManager.getRemainingGamesForTeam(teamLogoName, from: upcomingGames, currentWeek: currentWeek)
    }
    
    // MARK: - Playoff Management using PlayoffManager
    func setupPlayoffs() {
        print("🏈 Setting up playoffs...")
        
        // Sync user team record before determining playoffs
        syncUserTeamRecord()
        
        // Get playoff teams using PlayoffManager
        let playoffTeams = getPlayoffTeams()
        
        // Generate playoff schedule using CoreLeagueManager
        let playoffGames = coreLeagueManager.generatePlayoffSchedule(teams: playoffTeams, bracketManager: bracketManager)
        
        // Add playoff games to upcoming games
        upcomingGames.append(contentsOf: playoffGames)
        
        print("🏈 Playoffs setup complete with \(playoffGames.count) games")
    }
    
    // MARK: - Statistics Initialization
    private func initializeSeasonStats() {
        statisticsManager.initializeSeasonStats(for: allTeams)
    }
    
    // MARK: - Game Simulation (simplified - core logic remains)
    func simulateWeek(_ week: Int) {
        print("🏈 Starting simulation of week \(week)")
        
        enableBatchSimulation()
        defer { disableBatchSimulation() }
        
        let gamesToSimulate = upcomingGames.filter { $0.week == week && !$0.isCompleted }
        print("🏈 Found \(gamesToSimulate.count) games to simulate for week \(week)")
        
        guard !gamesToSimulate.isEmpty else {
            print("⚠️ No games to simulate for week \(week)")
            return
        }
        
        // Simulate games using the GameSimulationEngine
        let simulationEngine = GameSimulationEngine()
        
        for game in gamesToSimulate {
            let result = simulationEngine.simulateCompleteGame(
                homeTeam: game.homeTeam,
                awayTeam: game.awayTeam,
                week: week
            )
            
            // Update game result
            if let index = upcomingGames.firstIndex(where: { $0.id == game.id }) {
                upcomingGames[index] = result
                upcomingGames[index].isCompleted = true
            }
            
            // Move to completed games
            completedGames.append(result)
            
            // Update team records
            updateTeamRecords(with: result)
            
            // Track user team result
            if result.homeTeam.logoName == userTeam?.logoName || result.awayTeam.logoName == userTeam?.logoName {
                let isUserHome = result.homeTeam.logoName == userTeam?.logoName
                let userScore = isUserHome ? result.homeScore : result.awayScore
                let opponentScore = isUserHome ? result.awayScore : result.homeScore
                let opponentName = isUserHome ? result.awayTeam.name : result.homeTeam.name
                
                latestUserGameResult = (week: week, userScore: userScore, opponentScore: opponentScore, opponent: opponentName)
            }
        }
        
        // Remove completed games from upcoming
        upcomingGames.removeAll { game in
            completedGames.contains { $0.id == game.id }
        }
        
        // Update current week
        currentWeek = week
        
        print("✅ Week \(week) simulation complete")
    }
    
    // MARK: - Team Record Updates
    private func updateTeamRecords(with gameResult: GameResult) {
        // Update home team record
        if let homeTeamIndex = allTeams.firstIndex(where: { $0.logoName == gameResult.homeTeam.logoName }) {
            if gameResult.homeScore > gameResult.awayScore {
                allTeams[homeTeamIndex].record.wins += 1
            } else if gameResult.homeScore < gameResult.awayScore {
                allTeams[homeTeamIndex].record.losses += 1
            } else {
                allTeams[homeTeamIndex].record.ties += 1
            }
        }
        
        // Update away team record
        if let awayTeamIndex = allTeams.firstIndex(where: { $0.logoName == gameResult.awayTeam.logoName }) {
            if gameResult.awayScore > gameResult.homeScore {
                allTeams[awayTeamIndex].record.wins += 1
            } else if gameResult.awayScore < gameResult.homeScore {
                allTeams[awayTeamIndex].record.losses += 1
            } else {
                allTeams[awayTeamIndex].record.ties += 1
            }
        }
    }
    
    // MARK: - User Team Record Sync
    private func syncUserTeamRecord() {
        guard let userTeam = userTeam else {
            print("❌ No user team to sync")
            return
        }
        
        guard let userTeamIndex = allTeams.firstIndex(where: { $0.logoName == userTeam.logoName }) else {
            print("❌ Could not find user team \(userTeam.logoName) in allTeams array")
            return
        }
        
        let currentRecord = allTeams[userTeamIndex].record
        print("🔄 User team record before sync: \(currentRecord.wins)-\(currentRecord.losses)-\(currentRecord.ties)")
        
        // Get the user's record from completed games to ensure accuracy
        let userGames = completedGames.filter { game in
            game.homeTeam.logoName == userTeam.logoName || game.awayTeam.logoName == userTeam.logoName
        }
        
        var wins = 0
        var losses = 0
        var ties = 0
        
        for game in userGames {
            let isUserHome = game.homeTeam.logoName == userTeam.logoName
            let userScore = isUserHome ? game.homeScore : game.awayScore
            let opponentScore = isUserHome ? game.awayScore : game.homeScore
            
            if userScore > opponentScore {
                wins += 1
            } else if userScore < opponentScore {
                losses += 1
            } else {
                ties += 1
            }
        }
        
        // Update the record in allTeams array
        allTeams[userTeamIndex].record = TeamRecord(wins: wins, losses: losses, ties: ties)
        
        print("🔄 User team record after sync: \(wins)-\(losses)-\(ties)")
    }
    
    // MARK: - Batch Simulation Mode
    private func enableBatchSimulation() {
        batchModeEnabled = true
        pendingUIUpdates = false
        print("🚀 Batch simulation enabled")
    }
    
    private func disableBatchSimulation() {
        batchModeEnabled = false
        
        if pendingUIUpdates {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
            pendingUIUpdates = false
        }
        
        print("✅ Batch simulation disabled")
    }
    
    // MARK: - UI Update Management
    private func triggerUIUpdate() {
        if batchModeEnabled {
            pendingUIUpdates = true
        } else {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Legacy Methods (delegated to extracted managers)
    func getDivisionRecord(for team: LeagueTeam) -> TeamRecord {
        // This would need to be implemented based on completed games
        // For now, return the team's overall record
        return team.record
    }
    
    func getConferenceRecord(for team: LeagueTeam) -> TeamRecord {
        // This would need to be implemented based on completed games
        // For now, return the team's overall record
        return team.record
    }
    
    func getCommonGamesRecord(team1: LeagueTeam, team2: LeagueTeam) -> (team1WinPercentage: Double, team2WinPercentage: Double, totalGames: Int) {
        // This would need to be implemented based on completed games
        // For now, return placeholder values
        return (0.5, 0.5, 0)
    }
    
    // MARK: - Playoff Bracket Manager (using the one from LeagueManager)
    private var bracketManager = LeagueManager.PlayoffBracketManager()
}
