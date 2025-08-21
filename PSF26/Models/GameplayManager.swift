import SwiftUI
import Combine
import Foundation

// MARK: - Gameplay Manager
/// Consolidated manager handling game results, playoffs, and simulation
@MainActor
class GameplayManager: ObservableObject {
    static let shared = GameplayManager()
    
    // Game Results State
    @Published private var gameResults: [String: GameResult] = [:]
    @Published var isSimulating = false
    @Published var simulationProgress: Double = 0.0
    @Published var isAdvancingWeek = false
    
    private var leagueManagers: [UUID: GameplayManager] = [:]
    private var currentLeagueId: UUID?
    
    private init() {}
    
    // MARK: - League Management
    func getManagerForLeague(_ leagueId: UUID) -> GameplayManager {
        if let manager = leagueManagers[leagueId] {
            return manager
        } else {
            let manager = GameplayManager()
            leagueManagers[leagueId] = manager
            return manager
        }
    }
    
    func switchToLeague(_ leagueId: UUID) {
        currentLeagueId = leagueId
        print("🔄 GameplayManager: Switched to league \(leagueId.uuidString)")
    }
    
    // MARK: - Game Result Storage
    func updateGameResult(_ result: GameResult) {
        let key = "\(result.week)_\(result.homeTeam.logoName)_\(result.awayTeam.logoName)"
        gameResults[key] = result
        
        // Minimal logging - only log for week 1 or user team games to prevent rate limiting
        // Most logging is handled by LeagueManager during batch operations
    }
    
    func getGameResult(week: Int, homeTeam: String, awayTeam: String) -> GameResult? {
        let key = "\(week)_\(homeTeam)_\(awayTeam)"
        return gameResults[key]
    }
    
    func getAllGameResults() -> [String: GameResult] {
        return gameResults
    }
    
    func restoreGameResults(_ results: [String: GameResult]) {
        gameResults = results
        print("📊 Restored \(results.count) game results")
    }
    
    func getGameResultForTeam(teamName: String, week: Int, opponent: String, isHome: Bool) -> GameResult? {
        print("🔍 Looking for game result:")
        print("   Team: \(teamName)")
        print("   Week: \(week)")
        print("   Opponent: \(opponent)")
        print("   Is Home: \(isHome)")
        
        // First, try to find the opponent's short name
        let opponentShortName = getOpponentShortName(opponent)
        print("   Opponent Short Name: \(opponentShortName)")
        
        // Try direct key lookup first
        if isHome {
            let key = "\(week)_\(teamName)_\(opponentShortName)"
            if let result = gameResults[key] {
                print("✅ Found home game result")
                return result
            }
        } else {
            let key = "\(week)_\(opponentShortName)_\(teamName)"
            if let result = gameResults[key] {
                print("✅ Found away game result")
                return result
            }
        }
        
        // Fallback: Search through all game results for this week
        for (_, result) in gameResults {
            if result.week == week {
                let homeTeamMatches = result.homeTeam.logoName == teamName
                let awayTeamMatches = result.awayTeam.logoName == teamName
                
                let opponentMatches = (result.homeTeam.logoName == opponentShortName && awayTeamMatches) ||
                                    (result.awayTeam.logoName == opponentShortName && homeTeamMatches)
                
                if (homeTeamMatches || awayTeamMatches) && opponentMatches {
                    print("✅ Found game result via fallback search")
                    return result
                }
            }
        }
        
        print("❌ No game result found")
        return nil
    }
    
    // MARK: - Playoff Management
    func getConferenceStandings(teams: [LeagueTeam], conference: String) -> [LeagueTeam] {
        // Get teams for the specified conference
        let conferenceTeams = teams.filter { $0.conference == conference }
        
        // Group teams by division
        let divisionTeams = Dictionary(grouping: conferenceTeams) { $0.division }
        
        // Get division winners (top team from each division)
        var divisionWinners: [LeagueTeam] = []
        var remainingTeams: [LeagueTeam] = []
        
        for (_, teams) in divisionTeams {
            let sortedDivisionTeams = sortTeamsByRecord(teams)
            if let winner = sortedDivisionTeams.first {
                divisionWinners.append(winner)
            }
            if sortedDivisionTeams.count > 1 {
                remainingTeams.append(contentsOf: sortedDivisionTeams.dropFirst())
            }
        }
        
        // Sort division winners by record
        let sortedDivisionWinners = sortTeamsByRecord(divisionWinners)
        
        // Sort remaining teams by record for wild card spots
        let sortedWildCardTeams = sortTeamsByRecord(remainingTeams)
        
        // Combine division winners (top 4 seeds) with wild card teams (seeds 5-7)
        return sortedDivisionWinners + sortedWildCardTeams.prefix(3)
    }
    
    private func sortTeamsByRecord(_ teams: [LeagueTeam]) -> [LeagueTeam] {
        teams.sorted(by: { (team1: LeagueTeam, team2: LeagueTeam) in
            // Calculate win percentages
            let winPct1 = calculateWinPercentage(team1.record.description)
            let winPct2 = calculateWinPercentage(team2.record.description)
            
            // If win percentages are different, sort by that
            if winPct1 != winPct2 {
                return winPct1 > winPct2
            }
            
            // If win percentages are the same, use tiebreakers
            // 1. Head-to-head (would need game results)
            // 2. Division record (if same division)
            // 3. Conference record
            // 4. Point differential
            // For now, just use team name as final tiebreaker for consistency
            return team1.name < team2.name
        })
    }
    
    private func calculateWinPercentage(_ record: String) -> Double {
        let components = record.split(separator: "-")
        guard components.count >= 2,
              let wins = Int(components[0]),
              let losses = Int(components[1]) else {
            return 0.0
        }
        
        let totalGames = wins + losses
        return totalGames > 0 ? Double(wins) / Double(totalGames) : 0.0
    }
    
    // MARK: - Simulation Management
    func startSeason(leagueManager: LeagueManager, currentLeague: ObservableLeague) async {
        isSimulating = true
        simulationProgress = 0.0
        
        // Simulate season start
        await simulateSeasonStart(leagueManager: leagueManager, currentLeague: currentLeague)
    }
    
    private func simulateSeasonStart(leagueManager: LeagueManager, currentLeague: ObservableLeague) async {
        // Generate initial schedule and matchups instantly
        simulationProgress = 1.0
        
        // Load real schedule data and set up first week
        let masterLoader = MasterDataLoader.shared
        
        // Wait for master data to load if it hasn't already (no artificial delay)
        while !masterLoader.isDataLoaded && masterLoader.isLoading {
            // Just wait for the next run loop iteration
            await Task.yield()
        }
        
        // Validate that user team has made required roster cuts using NEW simple gate
        let (canAdvance, issues) = leagueManager.canUserTeamAdvanceFromTrainingCamp()
        if !canAdvance {
            print("❌ Cannot advance from training camp (simple gate): \(issues.joined(separator: ", "))")
            isSimulating = false
            return
        }
        
        // Execute AI team training camp cuts
        leagueManager.executeAITeamTrainingCampCuts()
        
        // End training camp and advance to regular season
        // Update both manager and observable league so UI reflects the change immediately
        leagueManager.isInTrainingCamp = false
        currentLeague.isInTrainingCamp = false
        currentLeague.trainingCampCompleted = true
        
        // Move to Week 1 so the hub shows the first opponent and proper actions
        if leagueManager.currentWeek == 0 {
            leagueManager.currentWeek = 1
        }
        if currentLeague.currentWeek == 0 {
            currentLeague.currentWeek = 1
        }
        
        // Update the observable league (basic sync)
        // Note: ObservableLeague should be updated through its own methods
        
        // Complete simulation
        isSimulating = false
        print("✅ Season simulation complete!")
    }
    
    func advanceWeek(leagueManager: LeagueManager, currentLeague: ObservableLeague) async {
        guard !isAdvancingWeek else { return }
        
        isAdvancingWeek = true
        
        // Snapshot records before simulation to compute score deltas without a central results map
        let userLogo = currentLeague.teamLogoName
        let schedule = MasterDataLoader.shared.getSchedule(for: userLogo)
        let currentWk = leagueManager.currentWeek
        let currentGame = schedule.first { $0.week == currentWk }
        let oppFullName = currentGame?.opponent ?? ""
        let oppLogo = LeagueHubHelpers.getOpponentLogoName(oppFullName)
        let preUserRecord = leagueManager.getTeamRecord(for: userLogo)
        let preOppRecord = leagueManager.getTeamRecord(for: oppLogo)
        let preUserGames = preUserRecord.wins + preUserRecord.losses + preUserRecord.ties
        let preOppGames = preOppRecord.wins + preOppRecord.losses + preOppRecord.ties
        
        // Simulate all games for current week
        leagueManager.simulateWeek(leagueManager.currentWeek)
        
        // Sync observable league week so Hub/UI reflects the new state immediately
        if currentLeague.currentWeek != leagueManager.currentWeek {
            currentLeague.currentWeek = leagueManager.currentWeek
        }

        // Background weekly history snapshot (no UI impact)
        let historyResults = getAllGameResults()
        let leagueId = currentLeague.getLeague().id
        let weekNumber = leagueManager.currentWeek
        Task.detached(priority: .utility) {
            await LeagueStorageManager.shared.writeWeeklyHistorySnapshot(
                leagueId: leagueId,
                week: weekNumber,
                userTeamLogoName: userLogo,
                gameResults: historyResults
            )
        }

        // Lightweight Game Center reporting (non-blocking, authenticated only)
        let gc = GameCenterManager.shared
        if gc.isAuthenticated {
            Task { await gc.submitScore(leagueManager.currentWeek, to: .test) }
        }

        // Compute brief result overlay from teamSeasonStats delta if both teams played,
        // else handle BYE (single logo).
        await MainActor.run {
            // Post-sim records
            let postUserRecord = leagueManager.getTeamRecord(for: userLogo)
            let postOppRecord = leagueManager.getTeamRecord(for: oppLogo)
            let postUserGames = postUserRecord.gamesPlayed
            let postOppGames = postOppRecord.gamesPlayed
            
            // Determine if user had a bye: their gamesPlayed didn't increase
            let userPlayed = postUserGames > preUserGames
            let oppPlayed = postOppGames > preOppGames
            
            var overlayUserScore = 0
            var overlayOppScore = 0
            var isBye = false
            
            if userPlayed && oppPlayed,
               let userStats = leagueManager.getTeamSeasonStats(teamLogoName: userLogo),
               let oppStats = leagueManager.getTeamSeasonStats(teamLogoName: oppLogo) {
                // Approximate per-game score from points deltas
                // (We use totalPoints - pointsAllowed heuristics over one game; if unavailable, default to 0)
                let userPoints = max(0, userStats.totalPoints - (preUserGames > 0 ? Int(Double(userStats.totalPoints) * Double(preUserGames) / Double(postUserGames)) : 0))
                let oppPoints = max(0, oppStats.totalPoints - (preOppGames > 0 ? Int(Double(oppStats.totalPoints) * Double(preOppGames) / Double(postOppGames)) : 0))
                overlayUserScore = userPoints
                overlayOppScore = oppPoints
            } else {
                // BYE (or missing opponent)
                isBye = true
            }
            
            // Publish overlay for ~2.5 seconds
            LeagueHubStateManager(leagueManager: leagueManager, currentLeague: currentLeague).showResultOverlay(
                userLogo: userLogo,
                oppLogo: oppLogo,
                userScore: overlayUserScore,
                oppScore: overlayOppScore,
                isBye: isBye
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                LeagueHubStateManager(leagueManager: leagueManager, currentLeague: currentLeague).clearResultOverlay()
            }
        }
        
        isAdvancingWeek = false
        print("✅ Week advanced successfully!")
    }
    
    func simulateToWeek(_ targetWeek: Int, leagueManager: LeagueManager, currentLeague: ObservableLeague) async {
        guard !isSimulating else { return }
        
        isSimulating = true
        simulationProgress = 0.0
        
        let startWeek = leagueManager.currentWeek
        let totalWeeks = max(1, targetWeek - startWeek)
        
        for week in startWeek..<targetWeek {
            // Update progress
            simulationProgress = Double(week - startWeek) / Double(totalWeeks)
            
            // Simulate the week
            leagueManager.simulateWeek(week)
            
            // Update the observable league (basic sync)
            // Note: ObservableLeague should be updated through its own methods
            
            // Small delay to show progress
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        simulationProgress = 1.0
        isSimulating = false
        print("✅ Simulated to week \(targetWeek)")
    }

    // MARK: - Unified Sim Runner (per-week overlay, same animation for all buttons)
    /// Runs week-by-week simulation from the current week up to (and not including) targetWeek,
    /// showing the same overlay animation each step with real scores when available.
    /// This avoids the progress bar popping back by not toggling isSimulating during the run.
    func runUnifiedSim(to targetWeek: Int,
                       leagueManager: LeagueManager,
                       currentLeague: ObservableLeague,
                       stateManager: LeagueHubStateManager) async {
        // Bounds and no-op guards
        let startWeek = max(leagueManager.currentWeek, 1)
        guard targetWeek > startWeek else { return }

        let userLogo = currentLeague.teamLogoName
        let schedule = MasterDataLoader.shared.getSchedule(for: userLogo)

        // Use a small delay per step so the overlay can be seen
        let stepDelayNanos: UInt64 = 450_000_000 // 0.45s (faster cadence)

        // Don't show the generic progress bar while we are animating overlays
        let originalIsSimulating = isSimulating
        await MainActor.run { self.isSimulating = false }

        for week in startWeek..<targetWeek {
            // Pre-capture opponent and points to compute fallback if needed
            let preGame = schedule.first { $0.week == week }
            let oppFullName = preGame?.opponent ?? ""
            let oppLogo = LeagueHubHelpers.getOpponentLogoName(oppFullName)
            let preUserPts = leagueManager.getTeamSeasonStats(teamLogoName: userLogo)?.totalPoints ?? 0
            let preOppPts = leagueManager.getTeamSeasonStats(teamLogoName: oppLogo)?.totalPoints ?? 0

            // Simulate this specific week
            leagueManager.simulateWeek(week)

            // Sync the observable league's week immediately so UI state advances
            if currentLeague.currentWeek != week { currentLeague.currentWeek = week }

            // Try to fetch a stored result first
            var shown = false
            if !oppFullName.isEmpty,
               let result = getGameResultForTeam(
                   teamName: userLogo,
                   week: week,
                   opponent: oppFullName,
                   isHome: preGame?.isHome ?? true
               ) {
                let isHome = preGame?.isHome ?? true
                let userScore = isHome ? result.homeScore : result.awayScore
                let oppScore = isHome ? result.awayScore : result.homeScore
                await MainActor.run {
                    stateManager.showResultOverlay(userLogo: userLogo,
                                                   oppLogo: oppLogo,
                                                   userScore: userScore,
                                                   oppScore: oppScore,
                                                   isBye: false)
                }
                shown = true
            }

            // Fallback: compute deltas if we didn't find a stored result
            if !shown {
                let postUserPts = leagueManager.getTeamSeasonStats(teamLogoName: userLogo)?.totalPoints ?? preUserPts
                let postOppPts = leagueManager.getTeamSeasonStats(teamLogoName: oppLogo)?.totalPoints ?? preOppPts
                let userScore = max(0, postUserPts - preUserPts)
                let oppScore = max(0, postOppPts - preOppPts)
                let isBye = (oppFullName.isEmpty) || (userScore == 0 && oppScore == 0)
                await MainActor.run {
                    stateManager.showResultOverlay(userLogo: userLogo,
                                                   oppLogo: oppLogo,
                                                   userScore: userScore,
                                                   oppScore: oppScore,
                                                   isBye: isBye)
                }
            }

            // Hold the overlay briefly, then clear and move to next
            try? await Task.sleep(nanoseconds: stepDelayNanos)
            await MainActor.run { stateManager.clearResultOverlay() }

            // Update opponent/logos for the upcoming week so the header reflects the next game
            let nextWeek = week + 1
            let nextSched = MasterDataLoader.shared.getSchedule(for: userLogo)
            if let nextGame = nextSched.first(where: { $0.week == nextWeek }) {
                let simplified = LeagueHubHelpers.simplifyOpponentName(nextGame.opponent)
                let nextOppLogo = LeagueHubHelpers.getOpponentLogoName(nextGame.opponent)
                let nextOppRecord = LeagueHubHelpers.generateRealisticRecord(for: nextWeek,
                                                                             leagueManager: leagueManager,
                                                                             teamLogoName: userLogo)
                await MainActor.run {
                    stateManager.updateOpponentInfo(name: simplified,
                                                    logoName: nextOppLogo,
                                                    record: nextOppRecord,
                                                    isHome: nextGame.isHome)
                }
            } else {
                await MainActor.run {
                    stateManager.updateOpponentInfo(name: "BYE",
                                                    logoName: "",
                                                    record: (0,0,0),
                                                    isHome: true)
                }
            }
        }

        // Ensure UI shows the target week's opponent context
        await MainActor.run {
            currentLeague.currentWeek = targetWeek
        }

        // Restore original sim flag state
        await MainActor.run { self.isSimulating = originalIsSimulating }
    }
    
    // MARK: - Helper Functions
    private func getOpponentShortName(_ fullOpponentName: String) -> String {
        let logoMapping: [String: String] = [
            "Kansas City Chiefs": "KansasCity",
            "San Francisco 49ers": "SanFrancisco",
            "Miami Dolphins": "Miami",
            "Dallas Cowboys": "Dallas",
            "Chicago Bears": "Chicago",
            "Detroit Lions": "Detroit",
            "Green Bay Packers": "GreenBay",
            "Minnesota Vikings": "Minnesota",
            "New York Giants": "NYN",
            "Philadelphia Eagles": "Philadelphia",
            "Washington Commanders": "Washington",
            "Atlanta Falcons": "Atlanta",
            "Carolina Panthers": "Carolina",
            "New Orleans Saints": "NewOrleans",
            "Tampa Bay Buccaneers": "TampaBay",
            "Arizona Cardinals": "Arizona",
            "Los Angeles Rams": "LAN",
            "Seattle Seahawks": "Seattle",
            "Baltimore Ravens": "Baltimore",
            "Cincinnati Bengals": "Cincinnati",
            "Cleveland Browns": "Cleveland",
            "Pittsburgh Steelers": "Pittsburgh",
            "Buffalo Bills": "Buffalo",
            "New England Patriots": "NewEngland",
            "New York Jets": "NYA",
            "Houston Texans": "Houston",
            "Indianapolis Colts": "Indianapolis",
            "Jacksonville Jaguars": "Jacksonville",
            "Tennessee Titans": "Tennessee",
            "Denver Broncos": "Denver",
            "Las Vegas Raiders": "LasVegas",
            "Los Angeles Chargers": "LAA"
        ]
        
        return logoMapping[fullOpponentName] ?? fullOpponentName
    }
}

// MARK: - Global Compatibility Bridge
class GlobalGameResultsManager: ObservableObject {
    static let shared = GlobalGameResultsManager()
    
    private var currentLeagueId: UUID?
    
    private init() {}
    
    func switchToLeague(_ leagueId: UUID) {
        currentLeagueId = leagueId
        GameplayManager.shared.switchToLeague(leagueId)
    }
    
    // Compatibility methods that delegate to GameplayManager
    func updateGameResult(_ result: GameResult) {
        guard let leagueId = currentLeagueId else {
            print("⚠️ No current league set for game result update")
            return
        }
        GameplayManager.shared.getManagerForLeague(leagueId).updateGameResult(result)
    }
    
    func getAllGameResults() -> [String: GameResult] {
        guard let leagueId = currentLeagueId else { return [:] }
        return GameplayManager.shared.getManagerForLeague(leagueId).getAllGameResults()
    }
    
    func restoreGameResults(_ results: [String: GameResult]) {
        guard let leagueId = currentLeagueId else {
            print("⚠️ No current league set for game results restoration")
            return
        }
        GameplayManager.shared.getManagerForLeague(leagueId).restoreGameResults(results)
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func getGameResultForTeam(teamName: String, week: Int, opponent: String, isHome: Bool) -> GameResult? {
        guard let leagueId = currentLeagueId else { return nil }
        return GameplayManager.shared.getManagerForLeague(leagueId).getGameResultForTeam(
            teamName: teamName, week: week, opponent: opponent, isHome: isHome
        )
    }
}
