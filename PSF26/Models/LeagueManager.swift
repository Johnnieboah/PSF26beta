import SwiftUI
import Combine

// MARK: - League Manager
class LeagueManager: ObservableObject {
    @Published var allTeams: [LeagueTeam] = []
    @Published var completedGames: [GameResult] = []
    @Published var upcomingGames: [GameResult] = []
    @Published var currentWeek: Int = 1
    @Published var userTeam: TeamData?
    @Published var settings: LeagueGameplaySettings = .defaultSettings()
    
    var teamRecord: TeamRecord {
        guard let userTeam = userTeam else { return TeamRecord() }
        return getTeamRecord(for: userTeam.logoName)
    }
    
    private let masterDataLoader = MasterDataLoader.shared
    
    func setupLeague(selectedTeam: TeamData, settings: LeagueGameplaySettings) {
        self.userTeam = selectedTeam
        self.settings = settings
        
        // Create all NFL teams
        createAllTeams()
        
        // Generate season schedule
        generateSeasonSchedule()
        
        print("✅ League setup completed with \(allTeams.count) teams and \(upcomingGames.count) games")
    }
    
    // MARK: - Team Creation
    private func createAllTeams() {
        let nflTeams = [
            // AFC East
            "Buffalo", "Miami", "NewEngland", "NYA",
            // AFC North
            "Baltimore", "Cincinnati", "Cleveland", "Pittsburgh",
            // AFC South
            "Houston", "Indianapolis", "Jacksonville", "Tennessee",
            // AFC West
            "Denver", "KansasCity", "LasVegas", "LAA",
            // NFC East
            "Dallas", "NYN", "Philadelphia", "Washington",
            // NFC North
            "Chicago", "Detroit", "GreenBay", "Minnesota",
            // NFC South
            "Atlanta", "Carolina", "NewOrleans", "TampaBay",
            // NFC West
            "Arizona", "LAN", "SanFrancisco", "Seattle"
        ]
        
        allTeams = nflTeams.map { teamName in
            let colors = TeamColorMapping.getColors(for: teamName)
            let teamData = TeamData.createTeamFromData(name: teamName)
            
            return LeagueTeam(
                logoName: teamName,
                name: TeamData.getTeamDisplayName(teamName),
                conference: getConference(for: teamName),
                division: getDivision(for: teamName),
                primaryColor: colors.primary,
                secondaryColor: colors.secondary,
                players: teamData.players,
                overallRating: calculateTeamOverall(players: teamData.players)
            )
        }
        
        // Sort teams by division for easier management
        allTeams.sort { team1, team2 in
            if team1.division != team2.division {
                return team1.division < team2.division
            }
            return team1.name < team2.name
        }
    }
    
    // MARK: - Schedule Generation
    private func generateSeasonSchedule() {
        upcomingGames.removeAll()
        
        // Use real schedule data when available, otherwise generate
        for week in 1...18 {
            let weekGames = generateGamesForWeek(week)
            upcomingGames.append(contentsOf: weekGames)
        }
        
        print("📅 Generated \(upcomingGames.count) games for the season")
    }
    
    private func generateGamesForWeek(_ week: Int) -> [GameResult] {
        var games: [GameResult] = []
        var teamsScheduled: Set<String> = []
        
        // Try to use real schedule data first
        if let userTeam = userTeam {
            let realSchedule = masterDataLoader.getSchedule(for: userTeam.logoName)
            
            if let userGame = realSchedule.first(where: { $0.week == week }) {
                // Create user team's game from real data
                if let homeTeam = allTeams.first(where: { $0.name.contains(userGame.isHome ? TeamData.getTeamDisplayName(userTeam.logoName) : userGame.opponent) }),
                   let awayTeam = allTeams.first(where: { $0.name.contains(userGame.isHome ? userGame.opponent : TeamData.getTeamDisplayName(userTeam.logoName)) }) {
                    
                    let game = GameResult(
                        week: week,
                        homeTeam: homeTeam,
                        awayTeam: awayTeam
                    )
                    games.append(game)
                    teamsScheduled.insert(homeTeam.logoName)
                    teamsScheduled.insert(awayTeam.logoName)
                }
            }
        }
        
        // Generate remaining games for teams not yet scheduled
        let remainingTeams = allTeams.filter { !teamsScheduled.contains($0.logoName) }
        
        // Create matchups for remaining teams (simplified scheduling)
        for i in stride(from: 0, to: remainingTeams.count - 1, by: 2) {
            if i + 1 < remainingTeams.count {
                let homeTeam = remainingTeams[i]
                let awayTeam = remainingTeams[i + 1]
                
                let game = GameResult(
                    week: week,
                    homeTeam: homeTeam,
                    awayTeam: awayTeam
                )
                games.append(game)
            }
        }
        
        // Handle bye weeks (Week 18 typically has fewer games)
        if week == 18 && games.count < 16 {
            // Some teams get bye week in week 18
        }
        
        return games
    }
    
    // MARK: - Game Simulation
    func simulateWeek(_ week: Int) {
        let weekGames = upcomingGames.filter { $0.week == week && !$0.isCompleted }
        
        for game in weekGames {
            simulateGame(game)
        }
        
        updateStandings()
        currentWeek = min(week + 1, 18)
        
        print("🎮 Simulated Week \(week) - \(weekGames.count) games completed")
    }
    
    func simulateToPlayoffs() {
        for week in currentWeek...17 {
            simulateWeek(week)
        }
        currentWeek = 18
        print("🏈 Simulated to playoffs!")
    }
    
    func simulateFullSeason() {
        for week in currentWeek...17 {
            simulateWeek(week)
        }
        currentWeek = 18
        print("🏆 Full season simulated!")
    }
    
    private func simulateGame(_ game: GameResult) {
        // Simple game simulation based on team ratings
        let homeAdvantage = 3.0
        let homeTeamStrength = Double(game.homeTeam.overallRating) + homeAdvantage
        let awayTeamStrength = Double(game.awayTeam.overallRating)
        
        // Add some randomness (± 10 points)
        let homeRandomness = Double.random(in: -10...10)
        let awayRandomness = Double.random(in: -10...10)
        
        let adjustedHomeStrength = homeTeamStrength + homeRandomness
        let adjustedAwayStrength = awayTeamStrength + awayRandomness
        
        // Calculate base scores (14-35 point range)
        let baseScore = Int.random(in: 14...35)
        let scoreDifference = abs(adjustedHomeStrength - adjustedAwayStrength)
        
        var homeScore: Int
        var awayScore: Int
        
        if adjustedHomeStrength > adjustedAwayStrength {
            homeScore = baseScore + Int(scoreDifference / 3)
            awayScore = baseScore - Int.random(in: 0...7)
        } else {
            awayScore = baseScore + Int(scoreDifference / 3)
            homeScore = baseScore - Int.random(in: 0...7)
        }
        
        // Ensure realistic score ranges
        homeScore = max(min(homeScore, 56), 0)
        awayScore = max(min(awayScore, 56), 0)
        
        // Handle ties (very rare)
        if homeScore == awayScore && Int.random(in: 1...100) > 2 {
            if Bool.random() {
                homeScore += Int.random(in: 1...3)
            } else {
                awayScore += Int.random(in: 1...3)
            }
        }
        
        // Update game result
        if let gameIndex = upcomingGames.firstIndex(where: { $0.id == game.id }) {
            upcomingGames[gameIndex].homeScore = homeScore
            upcomingGames[gameIndex].awayScore = awayScore
            upcomingGames[gameIndex].isCompleted = true
            
            // Move to completed games
            completedGames.append(upcomingGames[gameIndex])
        }
        
        // Update team records
        updateTeamRecord(game.homeTeam.logoName, won: homeScore > awayScore, tied: homeScore == awayScore)
        updateTeamRecord(game.awayTeam.logoName, won: awayScore > homeScore, tied: homeScore == awayScore)
    }
    
    // MARK: - Team Records and Stats
    private func updateTeamRecord(_ teamName: String, won: Bool, tied: Bool) {
        if let teamIndex = allTeams.firstIndex(where: { $0.logoName == teamName }) {
            if won {
                allTeams[teamIndex].record.wins += 1
            } else if tied {
                allTeams[teamIndex].record.ties += 1
            } else {
                allTeams[teamIndex].record.losses += 1
            }
        }
    }
    
    func updateGameResult(_ result: GameResult) {
        if let gameIndex = upcomingGames.firstIndex(where: { $0.id == result.id }) {
            upcomingGames[gameIndex] = result
            completedGames.append(result)
            
            // Update team records
            updateTeamRecord(result.homeTeam.logoName, won: result.homeScore > result.awayScore, tied: result.homeScore == result.awayScore)
            updateTeamRecord(result.awayTeam.logoName, won: result.awayScore > result.homeScore, tied: result.homeScore == result.awayScore)
            
            updateStandings()
        }
    }
    
    private func updateStandings() {
        // Sort teams by record for standings
        for division in getAllDivisions() {
            let divisionTeams = allTeams.filter { $0.division == division }
            let sortedTeams = divisionTeams.sorted { team1, team2 in
                let winPct1 = Double(team1.record.wins) / Double(max(team1.record.gamesPlayed, 1))
                let winPct2 = Double(team2.record.wins) / Double(max(team2.record.gamesPlayed, 1))
                return winPct1 > winPct2
            }
            
            // Update division ranks
            for (index, team) in sortedTeams.enumerated() {
                if let teamIndex = allTeams.firstIndex(where: { $0.id == team.id }) {
                    allTeams[teamIndex].divisionRank = index + 1
                }
            }
        }
    }
    
    // MARK: - Data Access Methods
    func getGamesForWeek(_ week: Int) -> [GameResult] {
        return upcomingGames.filter { $0.week == week }
    }
    
    func hasUpcomingGames(week: Int) -> Bool {
        return upcomingGames.contains { $0.week == week && !$0.isCompleted }
    }
    
    func getRecentGames(for team: TeamData) -> [GameResult] {
        return completedGames
            .filter { $0.homeTeam.logoName == team.logoName || $0.awayTeam.logoName == team.logoName }
            .sorted { $0.week > $1.week }
    }
    
    func getDivisionStandings(for team: TeamData) -> [LeagueTeam] {
        guard let userLeagueTeam = allTeams.first(where: { $0.logoName == team.logoName }) else { return [] }
        
        return allTeams
            .filter { $0.division == userLeagueTeam.division }
            .sorted { $0.divisionRank < $1.divisionRank }
    }
    
    func getDivisionRank(for team: TeamData) -> Int {
        return allTeams.first(where: { $0.logoName == team.logoName })?.divisionRank ?? 1
    }
    
    func getPlayoffOdds(for team: TeamData) -> Int {
        guard let leagueTeam = allTeams.first(where: { $0.logoName == team.logoName }) else { return 0 }
        
        let winPercentage = Double(leagueTeam.record.wins) / Double(max(leagueTeam.record.gamesPlayed, 1))
        let divisionRank = leagueTeam.divisionRank
        let gamesRemaining = 17 - leagueTeam.record.gamesPlayed
        
        // Simple playoff odds calculation
        var odds = Int(winPercentage * 100)
        
        // Adjust based on division rank
        switch divisionRank {
        case 1: odds += 20
        case 2: odds += 5
        case 3: odds -= 5
        case 4: odds -= 15
        default: break
        }
        
        // Adjust based on games remaining
        if gamesRemaining > 8 {
            odds = max(odds - 10, 0) // Early season uncertainty
        }
        
        return max(min(odds, 99), 1)
    }
    
    func getTeamRecord(for teamName: String) -> TeamRecord {
        return allTeams.first(where: { $0.logoName == teamName })?.record ?? TeamRecord()
    }
    
    // MARK: - Helper Methods
    private func calculateTeamOverall(players: [PlayerData]) -> Int {
        guard !players.isEmpty else { return 75 }
        let totalOverall = players.map { $0.overall }.reduce(0, +)
        return totalOverall / players.count
    }
    
    private func getConference(for teamName: String) -> String {
        let afcTeams = ["Buffalo", "Miami", "NewEngland", "NYA", "Baltimore", "Cincinnati", "Cleveland", "Pittsburgh", "Houston", "Indianapolis", "Jacksonville", "Tennessee", "Denver", "KansasCity", "LasVegas", "LAA"]
        return afcTeams.contains(teamName) ? "AFC" : "NFC"
    }
    
    private func getDivision(for teamName: String) -> String {
        switch teamName {
        case "Buffalo", "Miami", "NewEngland", "NYA": return "AFC East"
        case "Baltimore", "Cincinnati", "Cleveland", "Pittsburgh": return "AFC North"
        case "Houston", "Indianapolis", "Jacksonville", "Tennessee": return "AFC South"
        case "Denver", "KansasCity", "LasVegas", "LAA": return "AFC West"
        case "Dallas", "NYN", "Philadelphia", "Washington": return "NFC East"
        case "Chicago", "Detroit", "GreenBay", "Minnesota": return "NFC North"
        case "Atlanta", "Carolina", "NewOrleans", "TampaBay": return "NFC South"
        case "Arizona", "LAN", "SanFrancisco", "Seattle": return "NFC West"
        default: return "Unknown"
        }
    }
    
    private func getAllDivisions() -> [String] {
        return ["AFC East", "AFC North", "AFC South", "AFC West", "NFC East", "NFC North", "NFC South", "NFC West"]
    }
}

// MARK: - League Team Model
struct LeagueTeam: Identifiable {
    let id = UUID()
    let logoName: String
    let name: String
    let conference: String
    let division: String
    let primaryColor: String
    let secondaryColor: String
    let players: [PlayerData]
    let overallRating: Int
    var record = TeamRecord()
    var divisionRank: Int = 1
}

// MARK: - Team Record Model
struct TeamRecord {
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
}

// MARK: - Game Result Model
struct GameResult: Identifiable {
    let id = UUID()
    let week: Int
    let homeTeam: LeagueTeam
    let awayTeam: LeagueTeam
    var homeScore: Int = 0
    var awayScore: Int = 0
    var isCompleted: Bool = false
    
    var winningTeam: LeagueTeam? {
        guard isCompleted else { return nil }
        if homeScore > awayScore {
            return homeTeam
        } else if awayScore > homeScore {
            return awayTeam
        }
        return nil // Tie
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