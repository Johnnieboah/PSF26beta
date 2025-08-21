import SwiftUI
import Foundation
import Combine

// MARK: - Playoff Simulation Manager
class PlayoffSimulationManager: ObservableObject {
    private let leagueManager: LeagueManager
    private let currentLeague: ObservableLeague
    private let stateManager: LeagueHubStateManager
    
    init(leagueManager: LeagueManager, currentLeague: ObservableLeague, stateManager: LeagueHubStateManager) {
        self.leagueManager = leagueManager
        self.currentLeague = currentLeague
        self.stateManager = stateManager
    }
    
    // MARK: - Playoff Opponent Loading
    @MainActor
    func loadPlayoffOpponent() {
        print("🏈 Loading playoff opponent for week \(currentLeague.currentWeek)")
        
        // Use atomic playoff system to load fresh opponent data
        let opponentResult = leagueManager.loadFreshPlayoffOpponent(for: currentLeague.currentWeek)
        
        switch opponentResult {
        case .validOpponent(let team, let seed, let isHome):
            setupOpponentFromTeam(team, isHome: isHome, seed: seed)
            
        case .firstRoundBye(let seed):
            // Update state manager
            stateManager.opponentName = "First Round Bye"
            stateManager.opponentLogoName = ""
            stateManager.opponentRecord = (wins: 0, losses: 0, ties: 0)
            stateManager.isHomeGame = true
            stateManager.userGameCompleted = true
            print("🏈 User is #\(seed) seed with a first round bye")
            
        case .userEliminated:
            print("💀 User was eliminated - but can continue watching")
            stateManager.opponentName = "Eliminated - Watching Playoffs"
            stateManager.opponentLogoName = ""
            stateManager.opponentRecord = (wins: 0, losses: 0, ties: 0)
            stateManager.isHomeGame = true
            stateManager.userGameCompleted = true
            
        case .seasonComplete:
            print("🏆 Season complete")
            stateManager.opponentName = "Season Complete" 
            stateManager.opponentLogoName = ""
            stateManager.opponentRecord = (wins: 0, losses: 0, ties: 0)
            stateManager.isHomeGame = true
            stateManager.userGameCompleted = true
            
        case .noOpponentFound:
            print("❌ No opponent found - user can still watch playoffs")
            stateManager.opponentName = "Eliminated - Watching Playoffs"
            stateManager.opponentLogoName = ""
            stateManager.opponentRecord = (wins: 0, losses: 0, ties: 0)
            stateManager.isHomeGame = true
            stateManager.userGameCompleted = true
            
        case .noUserTeam:
            print("❌ No user team - can still watch playoffs")
            stateManager.opponentName = "Eliminated - Watching Playoffs"
            stateManager.opponentLogoName = ""
            stateManager.opponentRecord = (wins: 0, losses: 0, ties: 0)
            stateManager.isHomeGame = true
            stateManager.userGameCompleted = true
            
        case .invalidOpponent(let reason):
            print("❌ Invalid opponent: \(reason) - can still watch playoffs")
            stateManager.opponentName = "Eliminated - Watching Playoffs"
            stateManager.opponentLogoName = ""
            stateManager.opponentRecord = (wins: 0, losses: 0, ties: 0)
            stateManager.isHomeGame = true
            stateManager.userGameCompleted = true
        }
    }
    
    private func setupOpponentFromTeam(_ opponent: LeagueTeam, isHome: Bool, seed: Int) {
        let teamRecord = leagueManager.getTeamRecord(for: opponent.logoName)
        stateManager.opponentName = opponent.name
        stateManager.opponentLogoName = opponent.logoName
        stateManager.opponentRecord = (wins: teamRecord.wins, losses: teamRecord.losses, ties: teamRecord.ties)
        stateManager.isHomeGame = isHome
        stateManager.userGameCompleted = false
        
        // Update main action button text for playoffs
        let roundName = getRoundName(for: currentLeague.currentWeek)
        print("🏈 User is #\(seed) seed, playing \(opponent.name) in \(roundName) round")
    }
    
    private func getRoundName(for week: Int) -> String {
        return LeagueHubHelpers.getRoundName(for: week)
    }
    
    // MARK: - Playoff Game Simulation
    @MainActor
    func simulatePlayoffGameOnly() async -> Bool {
        guard let userTeamData = leagueManager.userTeam,
              let userTeam = leagueManager.allTeams.first(where: { $0.logoName == userTeamData.logoName }),
              let opponentTeam = leagueManager.allTeams.first(where: { $0.logoName == getCurrentOpponentLogoName() }) else {
            print("❌ Could not find user team or opponent for playoff game")
            return false
        }
        
        print("🏈 Simulating playoff game for week \(currentLeague.currentWeek)")
        
        // Simulate the playoff game directly
        let gameResult = leagueManager.simulateGameBetweenTeamsDetailed(
            isHomeGame() ? userTeam : opponentTeam,
            isHomeGame() ? opponentTeam : userTeam
        )
        
        // Update user's record (playoff games count toward record)
        let userWon = (isHomeGame() ? gameResult.homeScore : gameResult.awayScore) > (isHomeGame() ? gameResult.awayScore : gameResult.homeScore)
        let isTie = gameResult.homeScore == gameResult.awayScore
        
        let currentRecord = leagueManager.getTeamRecord(for: userTeamData.logoName)
        let newWins = userWon ? currentRecord.wins + 1 : currentRecord.wins
        let newLosses = (!userWon && !isTie) ? currentRecord.losses + 1 : currentRecord.losses
        let newTies = isTie ? currentRecord.ties + 1 : currentRecord.ties
        
        // Update record immediately
        currentLeague.updateRecord(wins: newWins, losses: newLosses, ties: newTies)
        
        print("🏈 Playoff game completed: \(isHomeGame() ? gameResult.homeScore : gameResult.awayScore) - \(isHomeGame() ? gameResult.awayScore : gameResult.homeScore)")
        print("🏈 Updated user record to: \(newWins)-\(newLosses)-\(newTies)")
        
        // Add playoff result for bracket progression
        if let userLeagueTeam = leagueManager.allTeams.first(where: { $0.logoName == userTeamData.logoName }),
           let opponentLeagueTeam = leagueManager.allTeams.first(where: { $0.logoName == getCurrentOpponentLogoName() }) {
            let winner = userWon ? userLeagueTeam : opponentLeagueTeam
            let loser = userWon ? opponentLeagueTeam : userLeagueTeam
            let homeScore = isHomeGame() ? gameResult.homeScore : gameResult.awayScore
            let awayScore = isHomeGame() ? gameResult.awayScore : gameResult.homeScore
            leagueManager.addPlayoffResult(winner: winner, loser: loser, week: currentLeague.currentWeek, homeScore: homeScore, awayScore: awayScore)
            print("🏈 Added playoff result for bracket progression: \(winner.name) defeated \(loser.name)")
            
            // CRITICAL: If user lost, end their season immediately
            if !userWon {
                print("💀 USER LOST PLAYOFF GAME - SEASON OVER!")
                return false // Signal that user lost
            } else {
                // User won their playoff game - simulate remaining game
                print("🏈 User won playoff game - simulating remaining games for week \(currentLeague.currentWeek)")
                leagueManager.simulateRemainingPlayoffGames(for: currentLeague.currentWeek)
            }
        }
        
        return true // Signal that user won or game was completed
    }
    
    // MARK: - User Game Simulation
    @MainActor
    func simulateUserGameOnly() async {
        guard let userGame = leagueManager.upcomingGames.first(where: { game in
            game.week == currentLeague.currentWeek &&
            (game.homeTeam.logoName == currentLeague.teamLogoName || game.awayTeam.logoName == currentLeague.teamLogoName)
        }) else {
            print("❌ Could not find user game for week \(currentLeague.currentWeek)")
            return
        }
        
        print("🎮 Simulating user game for week \(currentLeague.currentWeek)")
        
        // Simulate the game
        let tempGame = leagueManager.simulateGameBetweenTeamsDetailed(userGame.homeTeam, userGame.awayTeam)
        
        // Create a new game result with the original ID but simulated scores
        var simulatedGame = GameResult(id: userGame.id, week: userGame.week, homeTeam: userGame.homeTeam, awayTeam: userGame.awayTeam)
        simulatedGame.homeScore = tempGame.homeScore
        simulatedGame.awayScore = tempGame.awayScore
        simulatedGame.isCompleted = true
        simulatedGame.detailedStats = tempGame.detailedStats
        simulatedGame.playByPlaySummary = tempGame.playByPlaySummary
        simulatedGame.gameLength = tempGame.gameLength
        simulatedGame.scoringPlays = tempGame.scoringPlays
        
        // Transfer player stats from tempGame to simulatedGame
        if let tempGameStats = GlobalGamePlayerStatsManager.shared.getGamePlayerStats(gameId: tempGame.id) {
            // Update the gameId in all player stats to match our final game
            let updatedStats = tempGameStats.map { stat in
                var updatedStat = GamePlayerStats(
                    gameId: simulatedGame.id,
                    playerId: stat.playerId,
                    playerName: stat.playerName,
                    position: stat.position,
                    teamLogoName: stat.teamLogoName,
                    week: stat.week
                )
                // Copy all the stats over
                updatedStat.passingAttempts = stat.passingAttempts
                updatedStat.passingCompletions = stat.passingCompletions
                updatedStat.passingYards = stat.passingYards
                updatedStat.passingTouchdowns = stat.passingTouchdowns
                updatedStat.interceptions = stat.interceptions
                updatedStat.rushingAttempts = stat.rushingAttempts
                updatedStat.rushingYards = stat.rushingYards
                updatedStat.rushingTouchdowns = stat.rushingTouchdowns
                updatedStat.receptions = stat.receptions
                updatedStat.receivingYards = stat.receivingYards
                updatedStat.receivingTouchdowns = stat.receivingTouchdowns
                updatedStat.tackles = stat.tackles
                updatedStat.sacksMade = stat.sacksMade
                updatedStat.interceptionsDefense = stat.interceptionsDefense
                updatedStat.passesDefended = stat.passesDefended
                updatedStat.forcedFumbles = stat.forcedFumbles
                updatedStat.fumbleRecoveries = stat.fumbleRecoveries
                updatedStat.fieldGoalAttempts = stat.fieldGoalAttempts
                updatedStat.fieldGoalsMade = stat.fieldGoalsMade
                updatedStat.extraPointAttempts = stat.extraPointAttempts
                updatedStat.extraPointsMade = stat.extraPointsMade
                updatedStat.punts = stat.punts
                updatedStat.puntYards = stat.puntYards
                return updatedStat
            }
            
            // Store the stats with the correct gameId
            GlobalGamePlayerStatsManager.shared.storeGamePlayerStats(gameId: simulatedGame.id, stats: updatedStats)
            
            // Clean up the temporary game's stats
            GlobalGamePlayerStatsManager.shared.removeGamePlayerStats(gameId: tempGame.id)
            
            print("📊 🔄 Transferred \(updatedStats.count) player stats from tempGame to simulatedGame")
        }
        
        // Update game result
        let isUserHome = userGame.homeTeam.logoName == currentLeague.teamLogoName
        
        // Update the game result in LeagueManager first
        leagueManager.updateGameResult(simulatedGame)
        
        // Get updated records immediately after game result is processed
        let updatedUserRecord = leagueManager.getTeamRecord(for: currentLeague.teamLogoName)
        let opponentTeamName = isUserHome ? userGame.awayTeam.logoName : userGame.homeTeam.logoName
        _ = leagueManager.getTeamRecord(for: opponentTeamName)
        
        // Update records immediately
        currentLeague.updateRecord(
            wins: updatedUserRecord.wins,
            losses: updatedUserRecord.losses,
            ties: updatedUserRecord.ties
        )
        
        print("🎮 User game completed: \(isUserHome ? simulatedGame.homeScore : simulatedGame.awayScore) - \(isUserHome ? simulatedGame.awayScore : simulatedGame.homeScore)")
        print("🎮 Updated user record to: \(updatedUserRecord.wins)-\(updatedUserRecord.losses)-\(updatedUserRecord.ties)")
        
        // If this is Week 18 and all games are complete, set season complete state
        if currentLeague.currentWeek >= 18 && leagueManager.upcomingGames.filter({ $0.week == currentLeague.currentWeek && !$0.isCompleted }).isEmpty {
            print("🎮 Season complete after Week 18")
        }
    }
    
    // MARK: - Force Win Functions (Debug)
    @MainActor
    func performForceWinToPlayoffs() async {
        // Calculate how many weeks we need to simulate
        let weeksToSimulate = 18 - currentLeague.currentWeek
        _ = 1.0 / Double(weeksToSimulate)
        
        print("🏆 DEBUG: Will simulate \(weeksToSimulate) weeks to reach playoffs")
        
        // Force win each week until we reach playoffs
        for weekOffset in 0..<weeksToSimulate {
            let week = currentLeague.currentWeek + weekOffset
            print("🏆 DEBUG: Force winning week \(week)")
            
            // Find the user's game for this week
            guard let userGame = leagueManager.upcomingGames.first(where: { game in
                game.week == week &&
                (game.homeTeam.logoName == currentLeague.teamLogoName || game.awayTeam.logoName == currentLeague.teamLogoName)
            }) else {
                print("❌ Could not find user game for week \(week)")
                continue
            }
            
            // Determine if user is home team
            let isUserHome = userGame.homeTeam.logoName == currentLeague.teamLogoName
            
            // Force a win with good scores
            let userScore = Int.random(in: 28...42)  // User gets good score
            let opponentScore = Int.random(in: 14...userScore-1)  // Opponent gets lower score
            
            // Create winning game result
            var forcedGame = GameResult(id: userGame.id, week: userGame.week, homeTeam: userGame.homeTeam, awayTeam: userGame.awayTeam)
            
            if isUserHome {
                forcedGame.homeScore = userScore
                forcedGame.awayScore = opponentScore
            } else {
                forcedGame.homeScore = opponentScore
                forcedGame.awayScore = userScore
            }
            
            forcedGame.isCompleted = true
            
            print("🏆 Forced win: User \(userScore) - \(opponentScore) Opponent (User is \(isUserHome ? "home" : "away"))")
            
            // Update the game result in LeagueManager
            leagueManager.updateGameResult(forcedGame)
            
            // Update user record
            let updatedUserRecord = leagueManager.getTeamRecord(for: currentLeague.teamLogoName)
            currentLeague.updateRecord(
                wins: updatedUserRecord.wins,
                losses: updatedUserRecord.losses,
                ties: updatedUserRecord.ties
            )
            
            // Simulate remaining games for the week
            leagueManager.simulateRemainingPlayoffGames(for: week)
        }
        
        // Update UI state for playoffs
        withAnimation(.easeInOut(duration: 0.3)) {
            currentLeague.currentWeek = 19  // Move to pre-post-season week
            leagueManager.currentWeek = 19
        }
        
        // Auto-save if enabled
        if currentLeague.autoSave {
            do {
                try currentLeague.save(from: leagueManager)
                print("💾 Auto-saved league progress after reaching playoffs")
            } catch {
                print("❌ Auto-save failed: \(error)")
            }
        }
    }
    
    @MainActor
    func performForceWinAndAdvance() async {
        // Find the user's game for this week
        guard let userGame = leagueManager.upcomingGames.first(where: { game in
            game.week == currentLeague.currentWeek &&
            (game.homeTeam.logoName == currentLeague.teamLogoName || game.awayTeam.logoName == currentLeague.teamLogoName)
        }) else {
            print("❌ Could not find user game for week \(currentLeague.currentWeek)")
            return
        }
        
        // Determine if user is home team
        let isUserHome = userGame.homeTeam.logoName == currentLeague.teamLogoName
        
        // Force a win with good scores
        let userScore = Int.random(in: 28...42)  // User gets good score
        let opponentScore = Int.random(in: 14...userScore-1)  // Opponent gets lower score
        
        // Create winning game result
        var forcedGame = GameResult(id: userGame.id, week: userGame.week, homeTeam: userGame.homeTeam, awayTeam: userGame.awayTeam)
        
        if isUserHome {
            forcedGame.homeScore = userScore
            forcedGame.awayScore = opponentScore
        } else {
            forcedGame.homeScore = opponentScore  
            forcedGame.awayScore = userScore
        }
        
        forcedGame.isCompleted = true
        
        print("🏆 Forced win: User \(userScore) - \(opponentScore) Opponent (User is \(isUserHome ? "home" : "away"))")
        
        // Update the game result in LeagueManager
        leagueManager.updateGameResult(forcedGame)
        
        // Update user record
        let updatedUserRecord = leagueManager.getTeamRecord(for: currentLeague.teamLogoName)
        currentLeague.updateRecord(
            wins: updatedUserRecord.wins,
            losses: updatedUserRecord.losses,
            ties: updatedUserRecord.ties
        )
        
        print("🏆 Updated user record to: \(updatedUserRecord.wins)-\(updatedUserRecord.losses)-\(updatedUserRecord.ties)")
        
        // Handle playoff result recording if this is a playoff game
        if currentLeague.currentWeek >= 19 {
            if let userTeam = leagueManager.userTeam,
               let userLeagueTeam = leagueManager.allTeams.first(where: { $0.logoName == userTeam.logoName }),
               let opponentTeam = leagueManager.allTeams.first(where: { $0.logoName == getCurrentOpponentLogoName() }) {
                
                let correctHomeScore = isHomeGame() ? userScore : opponentScore
                let correctAwayScore = isHomeGame() ? opponentScore : userScore
                
                print("🏈 Recording forced playoff win: \(userLeagueTeam.name) defeated \(opponentTeam.name)")
                leagueManager.addPlayoffResult(winner: userLeagueTeam, loser: opponentTeam, week: currentLeague.currentWeek, homeScore: correctHomeScore, awayScore: correctAwayScore)
            }
        }
        
        // Small delay to show completion
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
    }
    
    // MARK: - Helper Functions
    private func getCurrentOpponentLogoName() -> String {
        // This would need to be passed in or determined from context
        // For now, return empty string
        return ""
    }
    
    private func isHomeGame() -> Bool {
        // This would need to be passed in or determined from context
        // For now, return true
        return true
    }
}
