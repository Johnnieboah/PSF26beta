import Foundation
import SwiftUI
import Combine

// MARK: - Array Extension for Batch Processing
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - League Manager
@MainActor
class LeagueManager: ObservableObject {
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
    
    var teamRecord: TeamRecord {
        guard let userTeam = userTeam else { return TeamRecord() }
        return getTeamRecord(for: userTeam.logoName)
    }
    
    private let masterDataLoader = MasterDataLoader.shared
    
    // MARK: - Statistics Tracking
    var playerSeasonStats: [String: PlayerSeasonStats] = [:]  // playerId -> stats
    var teamSeasonStats: [String: TeamSeasonStats] = [:]      // teamLogoName -> stats
    var gamePlayerStats: [UUID: [GamePlayerStats]] = [:]      // gameId -> [player stats]
    
    // Batch simulation mode to reduce UI updates
    private var isBatchSimulating = false
    
    // MARK: - Performance Optimization - Batch Simulation Mode
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
        // Sort teams by win percentage to determine playoff seeding
        let sortedTeams = allTeams.sorted { team1, team2 in
            let record1 = getTeamRecord(for: team1.logoName)
            let record2 = getTeamRecord(for: team2.logoName)
            
            let winPct1 = Double(record1.wins) / Double(record1.wins + record1.losses)
            let winPct2 = Double(record2.wins) / Double(record2.wins + record2.losses)
            
            return winPct1 > winPct2
        }
        
        // Take top 14 teams (7 from each conference)
        let afcTeams = sortedTeams.filter { $0.conference == "ACFT" }.prefix(7)
        let nfcTeams = sortedTeams.filter { $0.conference == "NCFT" }.prefix(7)
        
        // Combine and return
        return Array(afcTeams) + Array(nfcTeams)
    }
    
    func setupLeague(selectedTeam: TeamData, settings: LeagueGameplaySettings, savedState: League? = nil, leagueId: UUID? = nil, isTrainingCamp: Bool = false) {
        // Convert TeamData to LeagueTeam
        let coach = generateCoachForTeam(teamName: selectedTeam.logoName)
        let colors = TeamColorMapping.getColors(for: selectedTeam.logoName)
        
        let userLeagueTeam = LeagueTeam(
            logoName: selectedTeam.logoName,
            name: TeamData.getTeamDisplayName(selectedTeam.logoName),
            conference: getProperConference(for: selectedTeam.logoName).rawValue,
            division: getProperDivision(for: selectedTeam.logoName).rawValue,
            primaryColor: colors.primary,
            secondaryColor: colors.secondary,
            players: selectedTeam.players,
            overallRating: calculateTeamOverall(players: selectedTeam.players, teamName: selectedTeam.logoName),
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
            // CREATE mode - build from scratch (existing logic)
            print("🆕 Creating new league from scratch...")
            
            // Create all NFL teams with training camp rosters if specified
            createAllTeams(leagueId: leagueId, isTrainingCamp: isTrainingCamp)
            
            // Generate season schedule
            generateSeasonSchedule()
            
            // Recalculate all team overalls with enhanced system
            recalculateAllTeamOveralls()
            
            // Initialize season statistics for all teams and players
            initializeSeasonStats()
            
            // Assign salary cap compliant salaries to all teams
            if settings.salaryCapEnabled {
                SalaryCapManager.assignAllTeamsSalaries(teams: allTeams)
            }
            
            // Validate and adjust training camp rosters for proper cutting
            if isTrainingCamp {
                validateAndAdjustTrainingCampRosters()
            }
            
            print("✅ League setup completed with \(allTeams.count) teams and \(upcomingGames.count) games")
            // Inline console: roster counts and payroll (avoid extension visibility issues)
            let teamsForConsole = MasterDataLoader.shared.getAvailableTeams().sorted()
            var grandTotal = 0
            var grandPayroll = 0
            print("\n📊 Roster counts and payroll:")
            for t in teamsForConsole {
                let players = PlayerDataManager.shared.getPlayers(for: t, leagueId: leagueId)
                let count = players.count
                // Use top 53 players for payroll calculation to reflect active roster
                let top53 = players.sorted { $0.overall > $1.overall }.prefix(53)
                let payroll = top53.reduce(0) { $0 + $1.estimatedSalary }
                grandTotal += count
                grandPayroll += payroll
                print("   \(t)  \(count) players   \(Self.formatTeamPayrollMillions(payroll))")
            }
            print("   TOTAL  \(grandTotal) players   \(Self.formatTeamPayrollMillions(grandPayroll))\n")
        }
    }

    // MARK: - Currency Formatting Helpers
    private static func formatTeamPayrollMillions(_ amount: Int) -> String {
        // Team totals: whole-number millions (e.g., "$323 Million")
        let millions = Int((Double(amount) / 1_000_000.0).rounded())
        return "$\(millions) Million"
    }
    
    private static func formatPlayerSalaryMillions(_ amount: Int) -> String {
        // Player salaries: two decimals (e.g., "$1.25 Million")
        let millions = Double(amount) / 1_000_000.0
        return String(format: "$%.2f Million", millions)
    }
    
    // MARK: - Training Camp Validation
    
    private func validateAndAdjustTrainingCampRosters() {
        print("🏕️ Validating training camp rosters for cutting capability...")
        
        let validationResult = TrainingCampManager.validateAllTeamsCanMakeCuts(teams: allTeams)
        
        if !validationResult.allTeamsValid {
            print("🔧 Adjusting \(validationResult.totalIssues) teams for proper cutting...")
            TrainingCampManager.adjustTeamsForProperCutting(teams: &allTeams)
            
            // Re-validate after adjustments
            let revalidationResult = TrainingCampManager.validateAllTeamsCanMakeCuts(teams: allTeams)
            if revalidationResult.allTeamsValid {
                print("✅ All teams now ready for training camp cuts")
            } else {
                print("⚠️ Some teams still have cutting issues after adjustment")
            }
        } else {
            print("✅ All teams ready for training camp cuts")
        }
    }
    
    /// Checks if user team can make required cuts to advance from training camp
    func canUserTeamAdvanceFromTrainingCamp() -> (canAdvance: Bool, issues: [String]) {
        guard let userTeam = userTeam else {
            return (false, ["No user team found"])
        }
        
        // New advance rule: allow advance when roster is between 45 and 65 and cap is positive
        var issues: [String] = []
        if !(userTeam.players.count <= 65 && userTeam.players.count >= 45) {
            issues.append("Roster size must be between 45 and 65 to advance")
        }
        if userTeam.capSpace <= 0 {
            // Allow negative cap space at start; only roster size matters now
        }
        return (issues.isEmpty, issues)
    }
    
    /// Forces all AI teams to make their training camp cuts
    func executeAITeamTrainingCampCuts() {
        print("🤖 Executing AI team training camp cuts...")
        
        for i in 0..<allTeams.count {
            if allTeams[i].logoName != userTeam?.logoName {
                executeTrainingCampCutsForTeam(team: &allTeams[i])
            }
        }
        
        print("🤖 AI team cuts complete")
    }
    
    private func executeTrainingCampCutsForTeam(team: inout LeagueTeam) {
        let validation = TrainingCampManager.validateTeamCanMakeCuts(team: team)
        
        if validation.canMakeCuts && team.players.count == 60 {
            // Remove the recommended cuts
            let playersToKeep = team.players.filter { player in
                !validation.recommendedCuts.contains { $0.id == player.id }
            }
            
            // Ensure we have exactly 53 players
            if playersToKeep.count >= 53 {
                team.players = Array(playersToKeep.prefix(53))
                print("   ✂️ \(team.name): Cut \(60 - team.players.count) players (saved $\(validation.projectedSalarySavings))")
            }
        }
    }
    
    // MARK: - Team Creation
    private func createAllTeams(leagueId: UUID? = nil, isTrainingCamp: Bool = false) {
        let nflTeams = [
            // ACFT East
            "Buffalo", "Miami", "NewEngland", "NYA",
            // ACFT North
            "Baltimore", "Cincinnati", "Cleveland", "Pittsburgh",
            // ACFT South
            "Houston", "Indianapolis", "Jacksonville", "Tennessee",
            // ACFT West
            "Denver", "KansasCity", "LasVegas", "LAA",
            // NCFT East
            "Dallas", "NYN", "Philadelphia", "Washington",
            // NCFT North
            "Chicago", "Detroit", "GreenBay", "Minnesota",
            // NCFT South
            "Atlanta", "Carolina", "NewOrleans", "TampaBay",
            // NCFT West
            "Arizona", "LAN", "SanFrancisco", "Seattle"
        ]
        
        allTeams = nflTeams.map { teamName in
            let colors = TeamColorMapping.getColors(for: teamName)
            let teamData = TeamData.createTeamFromData(name: teamName, leagueId: leagueId, isTrainingCamp: isTrainingCamp)
            let coach = generateCoachForTeam(teamName: teamName)
            
            return LeagueTeam(
                logoName: teamName,
                name: TeamData.getTeamDisplayName(teamName),
                conference: getProperConference(for: teamName).rawValue,
                division: getProperDivision(for: teamName).rawValue,
                primaryColor: colors.primary,
                secondaryColor: colors.secondary,
                players: teamData.players,
                overallRating: calculateTeamOverall(players: teamData.players, teamName: teamName),
                coach: coach
            )
        }
        
        // Add Free Agent team from master data
        let freeAgentTeamData = TeamData.createTeamFromData(name: "Free Agent", leagueId: leagueId)
        if !freeAgentTeamData.players.isEmpty {
            let freeAgentTeam = LeagueTeam(
                logoName: "Free Agent",
                name: "Free Agents",
                conference: "",
                division: "",
                primaryColor: "#808080",
                secondaryColor: "#FFFFFF",
                players: freeAgentTeamData.players,
                overallRating: 0, // Free agents don't have team overall
                coach: Coach.placeholder()
            )
            allTeams.append(freeAgentTeam)
            print("📦 Added Free Agent team with \(freeAgentTeamData.players.count) players")
        }
        
        // Sort teams by division for easier management (Free Agent team will be last)
        allTeams.sort { team1, team2 in
            // Free Agent team goes last
            if team1.logoName == "Free Agent" { return false }
            if team2.logoName == "Free Agent" { return true }
            
            if team1.division != team2.division {
                return team1.division < team2.division
            }
            return team1.name < team2.name
        }
    }
    
    // MARK: - Coach Generation
    private func generateCoachForTeam(teamName: String) -> Coach {
        // Coach experience data based on real 2025 NFL coaches (names randomized)
        let coachData: [String: (firstName: String, lastName: String, experience: Int)] = [
            "Arizona": ("Marcus", "Thompson", 2),           // 2023-present
            "Atlanta": ("Derek", "Williams", 1),            // 2024-present (previously 2009-2011 TB)
            "Baltimore": ("Robert", "Mitchell", 17),        // 2008-present
            "Buffalo": ("Tyler", "Anderson", 8),            // 2017-present
            "Carolina": ("Jason", "Rodriguez", 1),          // 2024-present
            "Chicago": ("Trevor", "Hayes", 0),              // 2025-present (new hire)
            "Cincinnati": ("Nathan", "Cooper", 6),          // 2019-present
            "Cleveland": ("Brandon", "Parker", 5),          // 2020-present
            "Dallas": ("Cameron", "Foster", 0),             // 2025-present (new hire)
            "Denver": ("Vincent", "Murphy", 2),             // 2023-present (previously 2006-2021 NO)
            "Detroit": ("Gregory", "Bennett", 4),           // 2021-present
            "GreenBay": ("Austin", "Reed", 6),              // 2019-present
            "Houston": ("Darius", "Coleman", 2),            // 2023-present
            "Indianapolis": ("Garrett", "Brooks", 2),       // 2023-present
            "Jacksonville": ("Ethan", "Sullivan", 0),       // 2025-present (new hire)
            "KansasCity": ("Raymond", "Peterson", 12),      // 2013-present (previously 1999-2012 PHI)
            "LasVegas": ("Douglas", "Graham", 0),           // 2025-present (previously 2010-2023 SEA)
            "LAA": ("Bradley", "Watson", 1),                // 2024-present (previously 2011-2014 SF)
            "LAN": ("Caleb", "Hughes", 8),                  // 2017-present
            "Miami": ("Preston", "Sanders", 3),             // 2022-present
            "Minnesota": ("Tristan", "Price", 3),           // 2022-present
            "NewEngland": ("Curtis", "Barnes", 0),          // 2025-present (previously 2018-2023 TEN)
            "NewOrleans": ("Adrian", "Ross", 0),            // 2025-present (new hire)
            "NYN": ("Spencer", "Kelly", 3),                 // 2022-present
            "NYA": ("Dominic", "Rivera", 0),                // 2025-present (new hire)
            "Philadelphia": ("Landon", "Torres", 4),        // 2021-present
            "Pittsburgh": ("Marshall", "Evans", 18),        // 2007-present
            "SanFrancisco": ("Colton", "Stewart", 8),       // 2017-present
            "Seattle": ("Phillip", "Morgan", 1),            // 2024-present
            "TampaBay": ("Maxwell", "Bailey", 3),           // 2022-present (previously 2015-2018 NYJ)
            "Tennessee": ("Donovan", "Carter", 1),          // 2024-present
            "Washington": ("Sterling", "Phillips", 1)       // 2024-present (previously 2015-2020 ATL)
        ]
        
        // Get actual coach data or fallback
        let coach = coachData[teamName] ?? ("Alex", "Johnson", 5)
        
        // Coach ratings based on team performance (with special case for Bears)
        let rating = getCoachRating(for: teamName)
        
        // Offensive schemes
        let offensiveSchemes = [
            "West Coast", "Air Raid", "Spread", "Pro Style", "Run-Heavy", "RPO", "Vertical", "Smashmouth"
        ]
        
        // Defensive schemes
        let defensiveSchemes = [
            "3-4 Base", "4-3 Base", "Nickel", "Cover 2", "Cover 3", "Man Coverage", "Zone Blitz", "Hybrid"
        ]
        
        // Special case for Chicago - RPO scheme to match Caleb Williams perfectly
        let headCoachOffensiveScheme: String
        let headCoachDefensiveScheme: String
        
        if teamName == "Chicago" {
            headCoachOffensiveScheme = "RPO" // Perfect for Caleb Williams
            headCoachDefensiveScheme = defensiveSchemes.randomElement()!
        } else {
            headCoachOffensiveScheme = offensiveSchemes.randomElement()!
            headCoachDefensiveScheme = defensiveSchemes.randomElement()!
        }
        
        // Generate coordinators
        let oc = generateOffensiveCoordinator(headCoachScheme: headCoachOffensiveScheme, teamName: teamName)
        let dc = generateDefensiveCoordinator(headCoachScheme: headCoachDefensiveScheme, teamName: teamName)
        
        return Coach(
            firstName: coach.firstName,
            lastName: coach.lastName,
            overallRating: rating,
            offensiveScheme: headCoachOffensiveScheme,
            defensiveScheme: headCoachDefensiveScheme,
            experience: coach.experience,
            offensiveCoordinator: oc,
            defensiveCoordinator: dc
        )
    }
    
    private func generateOffensiveCoordinator(headCoachScheme: String, teamName: String) -> OffensiveCoordinator {
        // OC names pool
        let firstNames = ["Mike", "Josh", "Brian", "Kevin", "Matt", "Dan", "Chris", "Ryan", "Todd", "Ben", "Alex", "Shane", "Luke", "Kyle", "Eric"]
        let lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson"]
        
        let firstName = firstNames.randomElement()!
        let lastName = lastNames.randomElement()!
        
        // OC ratings (usually 70-85 range, slightly lower than head coaches)
        let baseRating = Int.random(in: 72...83)
        
        // Experience (usually less than head coaches)
        let experience = Int.random(in: 1...12)
        
        // Offensive schemes
        let offensiveSchemes = [
            "West Coast", "Air Raid", "Spread", "Pro Style", "Run-Heavy", "RPO", "Vertical", "Smashmouth"
        ]
        
        // 60% chance to match head coach scheme, 40% chance for different scheme
        let ocScheme: String
        if Double.random(in: 0...1) < 0.6 {
            ocScheme = headCoachScheme // Matching scheme
        } else {
            ocScheme = offensiveSchemes.filter { $0 != headCoachScheme }.randomElement() ?? headCoachScheme
        }
        
        return OffensiveCoordinator(
            firstName: firstName,
            lastName: lastName,
            overallRating: baseRating,
            offensiveScheme: ocScheme,
            experience: experience
        )
    }
    
    private func generateDefensiveCoordinator(headCoachScheme: String, teamName: String) -> DefensiveCoordinator {
        // DC names pool (different from OC pool)
        let firstNames = ["Steve", "Wade", "Vic", "Dom", "Jim", "Jack", "Ray", "Lou", "Gregg", "Rex", "Dick", "Bill", "Joe", "Pete", "Sean"]
        let lastNames = ["Taylor", "Thomas", "Jackson", "White", "Harris", "Martin", "Thompson", "Moore", "Young", "Walker", "Allen", "King", "Wright", "Scott", "Torres"]
        
        let firstName = firstNames.randomElement()!
        let lastName = lastNames.randomElement()!
        
        // DC ratings (usually 70-85 range, slightly lower than head coaches)
        let baseRating = Int.random(in: 72...83)
        
        // Experience (usually less than head coaches)
        let experience = Int.random(in: 1...12)
        
        // Defensive schemes
        let defensiveSchemes = [
            "3-4 Base", "4-3 Base", "Nickel", "Cover 2", "Cover 3", "Man Coverage", "Zone Blitz", "Hybrid"
        ]
        
        // 60% chance to match head coach scheme, 40% chance for different scheme
        let dcScheme: String
        if Double.random(in: 0...1) < 0.6 {
            dcScheme = headCoachScheme // Matching scheme
        } else {
            dcScheme = defensiveSchemes.filter { $0 != headCoachScheme }.randomElement() ?? headCoachScheme
        }
        
        return DefensiveCoordinator(
            firstName: firstName,
            lastName: lastName,
            overallRating: baseRating,
            defensiveScheme: dcScheme,
            experience: experience
        )
    }

    private func getCoachRating(for teamName: String) -> Int {
        // Coach ratings based on team performance - with special case for Bears
        let baseRating: Int
        
        switch teamName {
        // Special case: Bears coach is now elite
        case "Chicago": baseRating = 90     // Elite coach with perfect scheme for Caleb Williams
        
        // Elite coaches (88-92 range)
        case "KansasCity": baseRating = 91  // Andy Reid
        case "Philadelphia": baseRating = 90  // Nick Sirianni
        case "SanFrancisco": baseRating = 89  // Kyle Shanahan
        case "Buffalo": baseRating = 88      // Sean McDermott
        case "Pittsburgh": baseRating = 88   // Mike Tomlin
        
        // Very Good coaches (85-87 range)
        case "Baltimore": baseRating = 87    // John Harbaugh
        case "Miami": baseRating = 86        // Mike McDaniel
        case "Detroit": baseRating = 86      // Dan Campbell
        case "GreenBay": baseRating = 85     // Matt LaFleur
        case "Dallas": baseRating = 85       // Mike McCarthy
        
        // Good coaches (82-84 range)
        case "Seattle": baseRating = 84      // Pete Carroll era
        case "Minnesota": baseRating = 83    // Kevin O'Connell
        case "Cincinnati": baseRating = 83   // Zac Taylor
        case "LAN": baseRating = 82          // Sean McVay
        case "Jacksonville": baseRating = 82 // Doug Pederson
        
        // Average coaches (79-81 range)
        case "Cleveland": baseRating = 81    // Kevin Stefanski
        case "Indianapolis": baseRating = 80 // Shane Steichen
        case "Atlanta": baseRating = 80      // Arthur Smith era
        case "TampaBay": baseRating = 79     // Todd Bowles
        case "Houston": baseRating = 79      // DeMeco Ryans
        case "LasVegas": baseRating = 79     // Josh McDaniels era
        case "LAA": baseRating = 79          // Brandon Staley era
        case "NewOrleans": baseRating = 79   // Dennis Allen
        
        // Below average coaches (76-78 range)
        case "Tennessee": baseRating = 77    // Mike Vrabel era
        case "NYA": baseRating = 77          // Robert Saleh
        case "Denver": baseRating = 76       // Sean Payton
        case "Carolina": baseRating = 76     // Frank Reich era
        case "Arizona": baseRating = 76      // Jonathan Gannon
        case "NewEngland": baseRating = 76   // Bill Belichick era
        case "Washington": baseRating = 76   // Ron Rivera era
        case "NYN": baseRating = 76          // Brian Daboll
        
        default: baseRating = 80
        }
        
        // Add some randomness (±2 points) but keep Bears at exactly 90
        if teamName == "Chicago" {
            return 90 // No randomness for Bears - exactly 90
        } else {
            return max(70, min(95, baseRating + Int.random(in: -2...2)))
        }
    }
    
    // MARK: - Schedule Generation
    private func generateSeasonSchedule() {
        upcomingGames.removeAll()
        
        print("📅 Starting season schedule generation...")
        
        // Use real schedule data when available, otherwise generate
        for week in 1...18 {
            print("📅 Generating games for week \(week)...")
            let weekGames = generateGamesForWeek(week)
            upcomingGames.append(contentsOf: weekGames)
        }
        
        print("📅 Generated \(upcomingGames.count) games for the season")
        
        // Debug: Print first few games
        print("📅 Sample games:")
        for game in upcomingGames.prefix(5) {
            print("   Week \(game.week): \(game.homeTeam.logoName) vs \(game.awayTeam.logoName)")
        }
    }
    
    private func generateGamesForWeek(_ week: Int) -> [GameResult] {
        var games: [GameResult] = []
        var teamsScheduled: Set<String> = []
        
        // Use real schedule data for ALL teams
        let allNFLTeams = [
            "Buffalo", "Miami", "NewEngland", "NYA",
            "Baltimore", "Cincinnati", "Cleveland", "Pittsburgh", 
            "Houston", "Indianapolis", "Jacksonville", "Tennessee",
            "Denver", "KansasCity", "LasVegas", "LAA",
            "Dallas", "NYN", "Philadelphia", "Washington",
            "Chicago", "Detroit", "GreenBay", "Minnesota",
            "Atlanta", "Carolina", "NewOrleans", "TampaBay",
            "Arizona", "LAN", "SanFrancisco", "Seattle"
        ]
        
        for teamLogoName in allNFLTeams {
            if teamsScheduled.contains(teamLogoName) { continue }
            
            let realSchedule = masterDataLoader.getSchedule(for: teamLogoName)
            if let gameData = realSchedule.first(where: { $0.week == week }) {
                let opponentShortName = getOpponentShortName(gameData.opponent)
                
                // Only create the game if this team is the home team (to avoid duplicates)
                if gameData.isHome {
                    // Find the teams
                    let homeTeam = allTeams.first(where: { $0.logoName == teamLogoName })
                    let awayTeam = allTeams.first(where: { $0.logoName == opponentShortName })
                    
                    if let homeTeam = homeTeam, let awayTeam = awayTeam {
                        let game = GameResult(
                            week: week,
                            homeTeam: homeTeam,
                            awayTeam: awayTeam
                        )
                        games.append(game)
                        teamsScheduled.insert(homeTeam.logoName)
                        teamsScheduled.insert(awayTeam.logoName)
                        
                        print("   ✅ Created game: \(homeTeam.logoName) vs \(awayTeam.logoName)")
                    } else {
                        print("   ❌ Failed to find teams - home: \(teamLogoName), away: \(opponentShortName)")
                    }
                }
            }
        }
        
        print("📅 Generated \(games.count) games for week \(week)")
        return games
    }
    
    // Helper function to convert full team names to short names
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
        
        // First check if it's already a short name
        if logoMapping.values.contains(fullOpponentName) {
            return fullOpponentName
        }
        
        // Otherwise try to map it
        return logoMapping[fullOpponentName] ?? fullOpponentName
    }
    
    // MARK: - Game Simulation
    
    // Enable batch simulation mode to reduce UI updates
    func enableBatchSimulation() {
        batchModeEnabled = true
        pendingUIUpdates = false
        
        // Disable haptics during batch operations to prevent CoreHaptics overload
        HapticManager.shared.disableHapticsTemporarily()
        
        // Pause performance monitoring during intensive operations
        AdvancedPerformanceManager.shared.pauseMonitoringForIntensiveOperation()
        
        // Pre-optimize memory before large batch operations
        Task {
            await PerformanceIntegrationManager.shared.optimizeMemoryForLargeOperation()
        }
        
        print("🚀 Enhanced batch simulation enabled with performance optimizations")
    }
    
    // Disable batch simulation mode and send final UI update
    func disableBatchSimulation() {
        batchModeEnabled = false
        
        // Resume performance monitoring
        AdvancedPerformanceManager.shared.resumeMonitoringAfterIntensiveOperation()
        
        // Re-enable haptics
        HapticManager.shared.enableHaptics()
        
        // Send final UI update if needed
        if pendingUIUpdates {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
            pendingUIUpdates = false
        }
        
        // Clean up any remaining pooled objects
        Task {
            await cleanupAfterBatchOperation()
        }
        
        print("✅ Enhanced batch simulation disabled, performance monitoring resumed")
    }
    
    // Clean up resources after batch operations
    private func cleanupAfterBatchOperation() async {
        // Force a final memory cleanup
        await AdvancedPerformanceManager.shared.optimizeMemoryUsage()
        
        // Clear any temporary caches
        await MainActor.run {
            // Trigger final UI update
            self.objectWillChange.send()
        }
    }
    
    // Optimized UI update method that respects batch mode
    private func triggerUIUpdate() {
        if batchModeEnabled {
            pendingUIUpdates = true
        } else {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    // MARK: - Enhanced Batch Simulation with Memory Safety
    func simulateWeek(_ week: Int) {
        print("🏈 Starting simulation of week \(week)")
        
        // Build performance caches for optimal speed
        buildPerformanceCaches()
        
        // Get games to simulate for this week
        let gamesToSimulate = upcomingGames.filter { $0.week == week && !$0.isCompleted }
        print("🏈 Found \(gamesToSimulate.count) games to simulate for week \(week)")
        
        // Enable batch mode for performance
        let wasBatchMode = batchModeEnabled
        enableBatchSimulation()
        
        autoreleasepool {
            // Simulate games in larger batches to reduce overhead
            let gameBatches = gamesToSimulate.chunked(into: 16) // Process 16 games at a time for better performance
            var completedGames: [GameResult] = []
            completedGames.reserveCapacity(gamesToSimulate.count)
            
            // Find user's game for this week if it exists
            _ = gamesToSimulate.first { game in
                game.homeTeam.logoName == userTeam?.logoName || game.awayTeam.logoName == userTeam?.logoName
            }
            
            // Process batches with optimized parallel execution
            for (batchIndex, gameBatch) in gameBatches.enumerated() {
                // Process each batch in a single autoreleasepool with better memory management
                autoreleasepool {
                    // Pre-allocate array for better performance
                    var batchResults: [GameResult] = []
                    batchResults.reserveCapacity(gameBatch.count)
                    
                    for game in gameBatch {
                        // Simulate individual game
                        let simulatedGame = simulateGameSafely(game)
                        batchResults.append(simulatedGame)
                        
                        // If this is the user's game, update the latest result immediately
                        if let userTeamData = userTeam,
                           (simulatedGame.homeTeam.logoName == userTeamData.logoName || simulatedGame.awayTeam.logoName == userTeamData.logoName) {
                            let isUserHome = simulatedGame.homeTeam.logoName == userTeamData.logoName
                            let userScore = isUserHome ? simulatedGame.homeScore : simulatedGame.awayScore
                            let opponentScore = isUserHome ? simulatedGame.awayScore : simulatedGame.homeScore
                            let opponentName = isUserHome ? simulatedGame.awayTeam.name : simulatedGame.homeTeam.name
                            
                            Task { @MainActor in
                                self.latestUserGameResult = (week: week, userScore: userScore, opponentScore: opponentScore, opponent: opponentName)
                            }
                        }
                    }
                    
                    // Append batch results all at once for better performance
                    completedGames.append(contentsOf: batchResults)
                    
                    // Progress update every batch (reduced logging for performance)
                    if batchIndex % 2 == 0 || batchIndex == gameBatches.count - 1 {
                        print("🏈 📊 Completed batch \(batchIndex + 1)/\(gameBatches.count) (\(completedGames.count)/\(gamesToSimulate.count) games)")
                    }
                }
            }
            
            // Process all completed games in optimized batches
            autoreleasepool {
                // Build performance caches once for all operations
                buildPerformanceCaches()
                
                // Pre-collect game indices for faster removal
                var gameIndicesToRemove: [Int] = []
                gameIndicesToRemove.reserveCapacity(completedGames.count)
                
                for game in completedGames {
                    // Store game result and update statistics
                    GlobalGameResultsManager.shared.updateGameResult(game)
                    updateStatsFromGame(game)
                    
                    // Determine win/loss/tie once per game
                    let homeWon = game.homeScore > game.awayScore
                    let awayWon = game.awayScore > game.homeScore
                    let isTie = game.homeScore == game.awayScore
                    
                    // Update team records using cached indices
                    updateTeamRecordFast(game.homeTeam.logoName, won: homeWon, tied: isTie)
                    updateTeamRecordFast(game.awayTeam.logoName, won: awayWon, tied: isTie)
                    
                    // Update coach records using cached indices
                    updateCoachRecordFast(game.homeTeam.logoName, won: homeWon, tied: isTie)
                    updateCoachRecordFast(game.awayTeam.logoName, won: awayWon, tied: isTie)
                    
                    // Collect indices for batch removal
                    if let gameIndex = upcomingGames.firstIndex(where: { $0.id == game.id }) {
                        gameIndicesToRemove.append(gameIndex)
                    }
                }
                
                // Remove games from upcoming in reverse order for efficiency
                for index in gameIndicesToRemove.sorted(by: >) {
                    upcomingGames.remove(at: index)
                }
                
                // Add all completed games at once
                self.completedGames.append(contentsOf: completedGames)
            }
            
            // Update current week and standings
            currentWeek = week + 1
            updateStandings()
        }
        
        // Restore batch mode state
        if !wasBatchMode {
            disableBatchSimulation()
        }
        
        print("✅ Week \(week) simulation completed: \(gamesToSimulate.count) games")
    }
    
    // Safe game simulation with error handling and memory optimization
    private func simulateGameSafely(_ game: GameResult) -> GameResult {
        // Use autoreleasepool to manage memory during intensive simulation
        return autoreleasepool {
            // Since simulateGameBetweenTeamsDetailed doesn't throw, we don't need a do-catch block
            let result = simulateGameBetweenTeamsDetailed(game.homeTeam, game.awayTeam)
            
            // Ensure the result has the correct week information
            var enhancedResult = result
            enhancedResult.week = game.week
            
            return enhancedResult
        }
    }
    
    func simulateToPlayoffs() {
        // Check if adaptive batch mode should be enabled based on performance
        let shouldUseBatchMode = PerformanceIntegrationManager.shared.shouldEnableBatchMode()
        
        if shouldUseBatchMode {
            // Enable batch simulation mode to improve performance and reduce rate limiting
            enableBatchSimulation()
        }
        
        // Simulate through week 18
        for week in currentWeek...18 {
            simulateWeek(week)
        }
        
        // Set up playoffs and transition to week 19 (pre-playoff stage)
        currentWeek = 19
        setupPlayoffs() // This will determine playoff teams and generate the bracket
        
        if shouldUseBatchMode {
            // Disable batch simulation and send final UI update
            disableBatchSimulation()
        }
        
        // Summary log of season statistics after batch simulation
        let totalTeamGames = teamSeasonStats.values.reduce(0) { $0 + $1.gamesPlayed }
        let totalPlayerGames = playerSeasonStats.values.reduce(0) { $0 + $1.gamesPlayed }
        print("✅ Season simulation complete - Team games: \(totalTeamGames), Player games: \(totalPlayerGames)")
        print("📊 Season stats updated for \(teamSeasonStats.count) teams, \(playerSeasonStats.count) players")
        print("🏈 Playoff teams determined and bracket generated")
    }
    
    func simulateFullSeason() {
        // Check if adaptive batch mode should be enabled based on performance
        let shouldUseBatchMode = PerformanceIntegrationManager.shared.shouldEnableBatchMode()
        
        if shouldUseBatchMode {
            // Enable batch simulation mode to improve performance and reduce rate limiting
            enableBatchSimulation()
        }
        
        // Simulate through week 18
        for week in currentWeek...18 {
            simulateWeek(week)
        }
        currentWeek = 19  // Move to pre-post-season week
        
        if shouldUseBatchMode {
            // Disable batch simulation and send final UI update
            disableBatchSimulation()
        }
        
        // Summary log of season statistics after batch simulation
        let totalTeamGames = teamSeasonStats.values.reduce(0) { $0 + $1.gamesPlayed }
        let totalPlayerGames = playerSeasonStats.values.reduce(0) { $0 + $1.gamesPlayed }
        print("✅ Full season simulation complete - Team games: \(totalTeamGames), Player games: \(totalPlayerGames)")
        print("📊 Season stats updated for \(teamSeasonStats.count) teams, \(playerSeasonStats.count) players")
    }

    // MARK: - Advanced Game Simulation Integration
    private func simulateGameAdvanced(_ game: GameResult) -> GameResult {
        let advancedEngine = AdvancedGameSimulationEngine()
        let result = advancedEngine.simulateCompleteGame(homeTeam: game.homeTeam, awayTeam: game.awayTeam, week: game.week)
        
        // Use the original game as the base and update it with simulation results
        // This preserves the original game's ID so stats can be properly retrieved
        var enhancedResult = game
        enhancedResult.homeScore = result.homeScore
        enhancedResult.awayScore = result.awayScore
        enhancedResult.isCompleted = result.isCompleted
        enhancedResult.detailedStats = result.detailedStats
        enhancedResult.scoringPlays = result.scoringPlays
        enhancedResult.playByPlaySummary = result.playByPlaySummary
        enhancedResult.gameLength = result.gameLength
        
        // The AdvancedEngine stored stats with its own gameId, but we need them under the original gameId
        // So we need to transfer the stats from the engine's gameId to our gameId
        if let engineStats = GlobalGamePlayerStatsManager.shared.getGamePlayerStats(gameId: result.id) {
            // Update the gameId in all player stats to match our enhanced result
            let updatedStats = engineStats.map { stat in
                var updatedStat = GamePlayerStats(
                    gameId: enhancedResult.id, // Use the original game's ID
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
            GlobalGamePlayerStatsManager.shared.storeGamePlayerStats(gameId: enhancedResult.id, stats: updatedStats)
            
            // Clean up the old entry
            GlobalGamePlayerStatsManager.shared.removeGamePlayerStats(gameId: result.id)
            
            // Debug logging for user team games
            if (enhancedResult.homeTeam.logoName == userTeam?.logoName || enhancedResult.awayTeam.logoName == userTeam?.logoName) && !isBatchSimulating {
                print("📊 🔄 Transferred \(updatedStats.count) player stats from engineId: \(result.id) to gameId: \(enhancedResult.id)")
            }
        }
        
        // Extract natural player stats from the enhanced result (should now work)
        extractNaturalPlayerStats(from: advancedEngine, for: enhancedResult)
        
        // Only log game results for user team games to reduce spam
        if result.homeTeam.logoName == userTeam?.logoName || result.awayTeam.logoName == userTeam?.logoName {
            print("🏈 Advanced simulation: \(result.homeTeam.name) \(result.homeScore) - \(result.awayScore) \(result.awayTeam.name)")
        }
        
        return enhancedResult
    }
    
    // Extract natural player stats from the simulation engine
    private func extractNaturalPlayerStats(from engine: AdvancedGameSimulationEngine, for game: GameResult) {
        // The AdvancedGameSimulationEngine already processes player actions and stores them
        // in GlobalGamePlayerStatsManager. We just need to retrieve them.
        if let globalStats = GlobalGamePlayerStatsManager.shared.getGamePlayerStats(gameId: game.id) {
            gamePlayerStats[game.id] = globalStats
            if (game.homeTeam.logoName == userTeam?.logoName || game.awayTeam.logoName == userTeam?.logoName) && !isBatchSimulating {
                print("📊 ✅ LeagueManager: Retrieved natural player stats from advanced engine for \(globalStats.count) players")
                
                // Show breakdown by team
                let homeTeamStats = globalStats.filter { $0.teamLogoName == game.homeTeam.logoName }
                let awayTeamStats = globalStats.filter { $0.teamLogoName == game.awayTeam.logoName }
                print("📊   \(game.homeTeam.logoName): \(homeTeamStats.count) players")
                print("📊   \(game.awayTeam.logoName): \(awayTeamStats.count) players")
            }
        } else {
            // No stats found - this indicates an issue with the advanced simulation engine
            if (game.homeTeam.logoName == userTeam?.logoName || game.awayTeam.logoName == userTeam?.logoName) && !isBatchSimulating {
                print("⚠️ LeagueManager: No player stats found in global manager for \(game.awayTeam.name) @ \(game.homeTeam.name)")
                print("📊 GameId: \(game.id)")
                
                // Check global manager status
                let memoryUsage = GlobalGamePlayerStatsManager.shared.getMemoryUsage()
                print("📊 Global manager has \(memoryUsage.gameCount) games, \(memoryUsage.playerCount) total players")
            }
        }
    }
    


    // MARK: - Realistic Game Simulation (Legacy - now uses advanced engine as fallback)
    private func simulateGameFast(_ game: GameResult) -> GameResult {
        // Use advanced simulation for more realistic results
        return simulateGameAdvanced(game)
    }

    // Public method to simulate a game between two teams and return scores
    func simulateGameBetweenTeams(_ homeTeam: LeagueTeam, _ awayTeam: LeagueTeam) -> (Int, Int) {
        // Use advanced simulation engine for better accuracy
        let advancedEngine = AdvancedGameSimulationEngine()
        let result = advancedEngine.simulateCompleteGame(homeTeam: homeTeam, awayTeam: awayTeam, week: currentWeek)
        return (result.homeScore, result.awayScore)
    }

    // Method to get detailed game simulation with full stats
    func simulateGameBetweenTeamsDetailed(_ homeTeam: LeagueTeam, _ awayTeam: LeagueTeam) -> GameResult {
        let advancedEngine = AdvancedGameSimulationEngine()
        return advancedEngine.simulateCompleteGame(homeTeam: homeTeam, awayTeam: awayTeam, week: currentWeek)
    }

    // Public method to update team records from a completed game
    func updateTeamRecordsFromGame(_ game: GameResult) {
        updateTeamRecordFast(game.homeTeam.logoName, won: game.homeScore > game.awayScore, tied: game.homeScore == game.awayScore)
        updateTeamRecordFast(game.awayTeam.logoName, won: game.awayScore > game.homeScore, tied: game.homeScore == game.awayScore)
    }

    // MARK: - Optimized Team Record Updates
    private func updateTeamRecordFast(_ teamName: String, won: Bool, tied: Bool) {
        // Use cached index for O(1) lookup instead of O(n) search
        buildPerformanceCaches()
        guard let teamIndex = teamIndexCache[teamName] else { return }
        
        if won {
            allTeams[teamIndex].record.wins += 1
        } else if tied {
            allTeams[teamIndex].record.ties += 1
        } else {
            allTeams[teamIndex].record.losses += 1
        }
        
        // Mark cache as dirty for standings update
        invalidatePerformanceCaches()
    }
    
    // MARK: - Coach Record Updates
    private func updateCoachRecordFast(_ teamName: String, won: Bool, tied: Bool) {
        // Use cached index for O(1) lookup instead of O(n) search
        buildPerformanceCaches()
        guard let teamIndex = teamIndexCache[teamName] else { return }
        
        if won {
            allTeams[teamIndex].coach.record.wins += 1
        } else if tied {
            allTeams[teamIndex].coach.record.ties += 1
        } else {
            allTeams[teamIndex].coach.record.losses += 1
        }
    }

    // Legacy method for compatibility - now calls fast version
    private func simulateGame(_ game: GameResult) {
        let result = simulateGameFast(game)
        
        if let gameIndex = upcomingGames.firstIndex(where: { $0.id == game.id }) {
            upcomingGames[gameIndex] = result
            GlobalGameResultsManager.shared.updateGameResult(result)
            completedGames.append(result)
            upcomingGames.remove(at: gameIndex)
        }
        
        updateTeamRecordFast(result.homeTeam.logoName, won: result.homeScore > result.awayScore, tied: result.homeScore == result.awayScore)
        updateTeamRecordFast(result.awayTeam.logoName, won: result.awayScore > result.homeScore, tied: result.homeScore == result.awayScore)
        updateCoachRecordFast(result.homeTeam.logoName, won: result.homeScore > result.awayScore, tied: result.homeScore == result.awayScore)
        updateCoachRecordFast(result.awayTeam.logoName, won: result.awayScore > result.homeScore, tied: result.homeScore == result.awayScore)
        
        // Use optimized UI update method
        triggerUIUpdate()
    }

    func updateGameResult(_ result: GameResult) {
        if let gameIndex = upcomingGames.firstIndex(where: { $0.id == result.id }) {
            print("📊 Moving game from upcoming to completed: \(result.awayTeam.logoName) @ \(result.homeTeam.logoName) (Week \(result.week))")
            
            // First update the game in upcoming games
            upcomingGames[gameIndex] = result
            
            // Update team records immediately
            updateTeamRecordFast(result.homeTeam.logoName, won: result.homeScore > result.awayScore, tied: result.homeScore == result.awayScore)
            updateTeamRecordFast(result.awayTeam.logoName, won: result.awayScore > result.homeScore, tied: result.homeScore == result.awayScore)
            
            // Update coach records
            updateCoachRecordFast(result.homeTeam.logoName, won: result.homeScore > result.awayScore, tied: result.homeScore == result.awayScore)
            updateCoachRecordFast(result.awayTeam.logoName, won: result.awayScore > result.homeScore, tied: result.homeScore == result.awayScore)
            
            // Update shared game results manager
            GlobalGameResultsManager.shared.updateGameResult(result)
            
            // Update comprehensive statistics
            updateStatsFromGame(result)
            
            // Ensure stats are properly saved and displayed
            ensureStatsAreSaved(for: result)
            
            // Move game from upcoming to completed AFTER all updates
            completedGames.append(result)
            upcomingGames.remove(at: gameIndex)
            
            // Update standings
            updateStandings()
            
            // Force UI refresh with stats validation
            refreshAllStatDisplays()
            
            print("📊 Game successfully moved and records updated")
        } else {
            print("⚠️ Could not find game to update in upcoming games: \(result.awayTeam.logoName) @ \(result.homeTeam.logoName) (Week \(result.week))")
        }
    }
    
    // MARK: - Team Records and Stats
    private func updateTeamRecord(_ teamName: String, won: Bool, tied: Bool) {
        if let teamIndex = allTeams.firstIndex(where: { $0.logoName == teamName }) {
            let oldRecord = allTeams[teamIndex].record
            
            if won {
                allTeams[teamIndex].record.wins += 1
            } else if tied {
                allTeams[teamIndex].record.ties += 1
            } else {
                allTeams[teamIndex].record.losses += 1
            }
            
            let newRecord = allTeams[teamIndex].record
            print("📊 Updated \(teamName): \(oldRecord.wins)-\(oldRecord.losses) → \(newRecord.wins)-\(newRecord.losses)")
        } else {
            print("⚠️ Could not find team \(teamName) to update record")
        }
    }
    
    private func updateStandings() {
        // Build caches for faster lookups
        buildPerformanceCaches()
        
        // Use cached division teams for better performance
        for division in getAllDivisions() {
            guard let divisionTeams = divisionTeamsCache[division] else { continue }
            
            let sortedTeams = divisionTeams.sorted { team1, team2 in
                let winPct1 = Double(team1.record.wins) / Double(max(team1.record.gamesPlayed, 1))
                let winPct2 = Double(team2.record.wins) / Double(max(team2.record.gamesPlayed, 1))
                if winPct1 != winPct2 {
                    return winPct1 > winPct2
                }
                if team1.record.wins != team2.record.wins {
                    return team1.record.wins > team2.record.wins
                }
                return team1.logoName < team2.logoName // Stable tie-breaker
            }
            
            // Update division ranks using cached indices
            for (index, team) in sortedTeams.enumerated() {
                if let teamIndex = teamIndexCache[team.logoName] {
                    allTeams[teamIndex].divisionRank = index + 1
                }
            }
        }
        
        // Rebuild caches after standings update
        invalidatePerformanceCaches()
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
    
    func getDivisionStandings(for team: LeagueTeam) -> [LeagueTeam] {
        return allTeams
            .filter { $0.division == team.division }
            .sorted { $0.divisionRank < $1.divisionRank }
    }
    
    func getDivisionRank(for team: LeagueTeam) -> Int {
        return team.divisionRank
    }
    
    func getPlayoffOdds(for team: LeagueTeam) -> Int {
        let winPercentage = Double(team.record.wins) / Double(max(team.record.gamesPlayed, 1))
        
        let divisionRank = team.divisionRank
        let gamesRemaining = 17 - team.record.gamesPlayed
        
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
    
    // MARK: - Helper Methods
    private func calculateTeamOverall(players: [PlayerData], teamName: String) -> Int {
        guard !players.isEmpty else { return 75 }
        
        // Enhanced team overall calculation with position weighting and variance
        let offensivePositions = ["QB", "RB", "FB", "WR", "TE", "LT", "LG", "C", "RG", "RT"]
        let defensivePositions = ["MLB", "ROLB", "LOLB", "EDGE", "DE", "DT", "CB", "SS", "FS"]
        let specialTeamsPositions = ["K", "P"]
        
        // Separate players by position groups
        let offensivePlayers = players.filter { offensivePositions.contains($0.position) }
        let defensivePlayers = players.filter { defensivePositions.contains($0.position) }
        let specialTeamsPlayers = players.filter { specialTeamsPositions.contains($0.position) }
        
        // Calculate weighted averages for each unit
        let offenseRating = calculateUnitRating(players: offensivePlayers, isOffense: true)
        let defenseRating = calculateUnitRating(players: defensivePlayers, isOffense: false)
        let specialTeamsRating = calculateSpecialTeamsRating(players: specialTeamsPlayers)
        
        // Weight the units (Offense: 45%, Defense: 45%, Special Teams: 10%)
        let rawTeamRating = (offenseRating * 0.45) + (defenseRating * 0.45) + (specialTeamsRating * 0.10)
        
        // Apply team variance and normalization to spread ratings from 78-86
        let normalizedRating = normalizeTeamRating(rawTeamRating, allPlayers: players, teamName: teamName)
        
        return normalizedRating
    }
    
    private func calculateUnitRating(players: [PlayerData], isOffense: Bool) -> Double {
        guard !players.isEmpty else { return 70.0 }
        
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
        
        return totalWeight > 0 ? weightedSum / totalWeight : 70.0
    }
    
    private func calculateSpecialTeamsRating(players: [PlayerData]) -> Double {
        let kickers = players.filter { $0.position == "K" }
        let punters = players.filter { $0.position == "P" }
        
        let kickerRating = kickers.isEmpty ? 75.0 : Double(kickers.max { $0.overall < $1.overall }?.overall ?? 75)
        let punterRating = punters.isEmpty ? 75.0 : Double(punters.max { $0.overall < $1.overall }?.overall ?? 75)
        
        return (kickerRating + punterRating) / 2.0
    }
    
    private func normalizeTeamRating(_ rawRating: Double, allPlayers: [PlayerData], teamName: String) -> Int {
        // Calculate team depth and talent variance
        let sortedPlayers = allPlayers.sorted { $0.overall > $1.overall }
        let topPlayersCount = min(22, sortedPlayers.count) // Starting 22
        let topPlayers = Array(sortedPlayers.prefix(topPlayersCount))
        
        // Calculate additional factors
        let topPlayerAverage = topPlayers.isEmpty ? rawRating : Double(topPlayers.map { $0.overall }.reduce(0, +)) / Double(topPlayers.count)
        let depthQuality = calculateDepthQuality(allPlayers: allPlayers)
        let talentVariance = calculateTalentVariance(allPlayers: allPlayers)
        
        // Combine factors with enhanced weights - top player talent matters more
        let enhancedRating = (rawRating * 0.5) + (topPlayerAverage * 0.35) + (depthQuality * 0.1) + (talentVariance * 0.05)
        
        // Apply team-specific adjustments based on recent performance and known strengths
        let teamAdjustment = getTeamStrengthAdjustment(allPlayers: allPlayers, teamName: teamName)
        let finalEnhancedRating = enhancedRating + teamAdjustment
        
        // Map to expanded range (72-92) for better team differentiation
        let minRating = 72.0
        let maxRating = 92.0
        let normalizedValue = (finalEnhancedRating - 60.0) / 25.0 // Expanded range for better spread
        let clampedValue = max(0.0, min(1.0, normalizedValue))
        
        let finalRating = minRating + (clampedValue * (maxRating - minRating))
        
        return Int(round(finalRating))
    }
    
    private func getTeamStrengthAdjustment(allPlayers: [PlayerData], teamName: String) -> Double {
        // Enhanced team-specific adjustments based on 2024 season performance and roster quality
        // These adjustments are more aggressive to create proper separation between teams
        switch teamName {
        // Elite Tier - Super Bowl Champions & Perennial Contenders (88-92 range)
        case "Philadelphia": return 8.0  // Super Bowl winners - elite across the board
        case "KansasCity": return 7.5    // Mahomes + championship pedigree
        case "Buffalo": return 7.0       // Josh Allen + consistently elite
        case "SanFrancisco": return 6.5  // Elite roster construction
        
        // Very Strong Tier - Playoff Contenders (85-87 range)
        case "Baltimore": return 5.5     // Lamar + strong defense
        case "Cincinnati": return 5.0    // Burrow + elite receiving corps
        case "Miami": return 4.5         // High-powered offense
        case "Dallas": return 4.0        // Talented but inconsistent
        case "Detroit": return 3.5       // Rising with good coaching
        
        // Good Tier - Solid Teams (82-84 range)
        case "GreenBay": return 3.0      // Solid with good QB play
        case "Seattle": return 2.5       // Consistent playoff team
        case "Minnesota": return 2.0     // Good roster, coaching
        case "LAN": return 1.5           // Rams with McVay
        case "Jacksonville": return 1.0  // Young team improving
        
        // Average Tier - Middle of Pack (79-81 range)
        case "Pittsburgh": return 0.5    // Solid but aging
        case "Cleveland": return 0.0     // Inconsistent talent
        case "Indianapolis": return 0.0  // Rebuilding mode
        case "Atlanta": return 0.0       // Middle of the pack
        case "TampaBay": return 0.0      // Post-Brady transition
        case "LasVegas": return -0.5     // Underachieving
        case "LAA": return -0.5          // Chargers - talented but disappointing
        case "NewOrleans": return -0.5   // Saints - aging roster
        case "NYN": return -1.0          // Giants - limited talent
        
        // Below Average Tier - Rebuilding Teams (75-78 range)
        case "Houston": return -2.0      // Young team, still building
        case "Tennessee": return -2.5    // Down year, roster issues
        case "NYA": return -3.0          // Jets - disappointing with talent
        case "Denver": return -3.5       // Inconsistent, QB questions
        case "NewEngland": return -4.0   // Post-Brady struggles
        case "Washington": return -4.5   // Rebuilding, limited talent
        
        // Poor Tier - Bottom Feeders (72-75 range)
        case "Chicago": return -5.0      // Rebuilding, picked 10th overall
        case "Carolina": return -5.5     // Panthers - major rebuild
        case "Arizona": return -6.0      // Cardinals - bottom tier roster
        
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
    
    private func getConference(for teamName: String) -> String {
        let afcTeams = ["Buffalo", "Miami", "NewEngland", "NYA", "Baltimore", "Cincinnati", "Cleveland", "Pittsburgh", "Houston", "Indianapolis", "Jacksonville", "Tennessee", "Denver", "KansasCity", "LasVegas", "LAA"]
        return afcTeams.contains(teamName) ? "ACFT" : "NCFT"
    }
    
    private func getDivision(for teamName: String) -> String {
        switch teamName {
        case "Buffalo", "Miami", "NewEngland", "NYA": return "ACFT East"
        case "Baltimore", "Cincinnati", "Cleveland", "Pittsburgh": return "ACFT North"
        case "Houston", "Indianapolis", "Jacksonville", "Tennessee": return "ACFT South"
        case "Denver", "KansasCity", "LasVegas", "LAA": return "ACFT West"
        case "Dallas", "NYN", "Philadelphia", "Washington": return "NCFT East"
        case "Chicago", "Detroit", "GreenBay", "Minnesota": return "NCFT North"
        case "Atlanta", "Carolina", "NewOrleans", "TampaBay": return "NCFT South"
        case "Arizona", "LAN", "SanFrancisco", "Seattle": return "NCFT West"
        default: return "Unknown"
        }
    }
    
    private func getAllDivisions() -> [String] {
        return ["ACFT East", "ACFT North", "ACFT South", "ACFT West", "NCFT East", "NCFT North", "NCFT South", "NCFT West"]
    }
    
    // MARK: - Team Overall Recalculation
    func recalculateAllTeamOveralls() {
        print("🔄 Recalculating team overalls with enhanced system...")
        
        for index in allTeams.indices {
            let newOverall = calculateTeamOverall(players: allTeams[index].players, teamName: allTeams[index].logoName)
            let oldOverall = allTeams[index].overallRating
            
            // Create updated team with new overall rating
            allTeams[index] = LeagueTeam(
                logoName: allTeams[index].logoName,
                name: allTeams[index].name,
                conference: allTeams[index].conference,
                division: allTeams[index].division,
                primaryColor: allTeams[index].primaryColor,
                secondaryColor: allTeams[index].secondaryColor,
                players: allTeams[index].players,
                overallRating: newOverall,
                coach: allTeams[index].coach
            )
            
            print("   \(allTeams[index].name): \(oldOverall) → \(newOverall)")
        }
        
        // Sort teams by new overall ratings to see the distribution
        let sortedTeams = allTeams.sorted { $0.overallRating > $1.overallRating }
        print("📊 New team overall distribution:")
        print("   Best: \(sortedTeams.first?.name ?? "Unknown") (\(sortedTeams.first?.overallRating ?? 0))")
        print("   Worst: \(sortedTeams.last?.name ?? "Unknown") (\(sortedTeams.last?.overallRating ?? 0))")
        print("   Average: \(Int(sortedTeams.map { $0.overallRating }.reduce(0, +) / sortedTeams.count))")
        print("✅ Team overall recalculation complete!")
    }
    // MARK: - Team Data Refresh from PlayerDataManager
    func refreshTeamDataFromPlayerDataManager() {
        print("🔄 Refreshing team data from PlayerDataManager...")
        
        for index in allTeams.indices {
            let teamName = allTeams[index].logoName
            let currentPlayerCount = allTeams[index].players.count
            
            // Get fresh player data from PlayerDataManager
            let freshPlayers = PlayerDataManager.shared.getPlayers(for: teamName, leagueId: currentLeagueId)
            let newPlayerCount = freshPlayers.count
            
            if currentPlayerCount != newPlayerCount {
                print("🔄 \(teamName): Updating from \(currentPlayerCount) to \(newPlayerCount) players")
                
                // Create updated team with fresh player data
                let newOverall = calculateTeamOverall(players: freshPlayers, teamName: teamName)
                allTeams[index] = LeagueTeam(
                    logoName: allTeams[index].logoName,
                    name: allTeams[index].name,
                    conference: allTeams[index].conference,
                    division: allTeams[index].division,
                    primaryColor: allTeams[index].primaryColor,
                    secondaryColor: allTeams[index].secondaryColor,
                    players: freshPlayers,
                    overallRating: newOverall,
                    coach: allTeams[index].coach
                )
            }
        }
        
        // Update user team if it exists
        if let userTeam = userTeam {
            let freshUserPlayers = PlayerDataManager.shared.getPlayers(for: userTeam.logoName, leagueId: currentLeagueId)
            let newUserOverall = calculateTeamOverall(players: freshUserPlayers, teamName: userTeam.logoName)
            
            self.userTeam = LeagueTeam(
                logoName: userTeam.logoName,
                name: userTeam.name,
                conference: userTeam.conference,
                division: userTeam.division,
                primaryColor: userTeam.primaryColor,
                secondaryColor: userTeam.secondaryColor,
                players: freshUserPlayers,
                overallRating: newUserOverall,
                coach: userTeam.coach
            )
            
            print("🔄 User team updated: \(userTeam.logoName) - \(freshUserPlayers.count) players")
        }
        
        print("✅ Team data refresh complete!")
    }

    // MARK: - Statistics Management
    func initializeSeasonStats() {
        print("🏈 Initializing season statistics...")
        
        // Enable batch mode for initialization to prevent UI updates
        let wasBatchMode = batchModeEnabled
        if !wasBatchMode {
            enableBatchSimulation()
        }
        
        // Check if we already have stats loaded (from saved league)
        let hasExistingStats = !teamSeasonStats.isEmpty || !playerSeasonStats.isEmpty
        
        if hasExistingStats {
            print("🏈 ✅ Stats already loaded from saved league - only filling missing entries")
            // Don't clear existing stats - only fill missing ones
        } else {
            print("🏈 ➕ No existing stats found - initializing all stats from scratch")
            // Pre-allocate dictionaries with estimated capacity
            teamSeasonStats.reserveCapacity(32)
            playerSeasonStats.reserveCapacity(2500)
        }
        
        // Initialize team stats only if they don't exist
        var newTeamStatsCount = 0
        for team in allTeams {
            if teamSeasonStats[team.logoName] == nil {
                let teamStats = TeamSeasonStats(teamLogoName: team.logoName)
                teamSeasonStats[team.logoName] = teamStats
                newTeamStatsCount += 1
                print("🏈 ➕ Initialized new team stats for \(team.logoName)")
            }
        }
        
        // Initialize player stats only if they don't exist
        var totalPlayersInitialized = 0
        
        // Process teams in batches to reduce memory pressure
        let teamBatches = allTeams.chunked(into: 8) // Process 8 teams at a time
        
        for (batchIndex, teamBatch) in teamBatches.enumerated() {
            autoreleasepool {
                for team in teamBatch {
                    let players = PlayerDataManager.shared.getPlayers(for: team.logoName, leagueId: currentLeagueId)
                    
                    // Initialize players only if they don't exist
                    for player in players {
                        let playerId = "\(player.firstName)_\(player.lastName)_\(player.number)"
                        
                        // Only create if doesn't exist (avoid duplicates)
                        if playerSeasonStats[playerId] == nil {
                            let playerStats = PlayerSeasonStats(
                                playerId: playerId,
                                playerName: "\(player.firstName) \(player.lastName)",
                                position: player.position,
                                teamLogoName: team.logoName
                            )
                            playerSeasonStats[playerId] = playerStats
                            totalPlayersInitialized += 1
                        }
                    }
                }
                
                // Progress logging every few batches
                if (batchIndex + 1) % 4 == 0 {
                    print("🏈 📊 Processed \(batchIndex + 1)/\(teamBatches.count) team batches")
                }
            }
        }
        
        if hasExistingStats {
            print("🏈 Stats status: \(teamSeasonStats.count) teams (added \(newTeamStatsCount) new), \(playerSeasonStats.count) players (added \(totalPlayersInitialized) new)")
        } else {
            print("🏈 Stats status: \(teamSeasonStats.count) teams, \(totalPlayersInitialized) players initialized")
        }
        
        if let firstTeam = allTeams.first {
            let sampleStats = teamSeasonStats[firstTeam.logoName]
            print("🏈 Sample team stats for \(firstTeam.logoName): \(sampleStats?.gamesPlayed ?? 0) games played")
        }
        
        // Restore previous batch mode state
        if !wasBatchMode {
            disableBatchSimulation()
        }
    }
    
    func loadSeasonStatsFromSavedLeague(_ savedLeague: League) {
        print("🏈 Loading saved season statistics...")
        
        // Load player season stats if available
        if let savedPlayerStats = savedLeague.playerSeasonStats {
            playerSeasonStats = savedPlayerStats
            print("🏈 ✅ Loaded \(savedPlayerStats.count) player season stats")
        }
        
        // Load team season stats if available
        if let savedTeamStats = savedLeague.teamSeasonStats {
            teamSeasonStats = savedTeamStats
            print("🏈 ✅ Loaded \(savedTeamStats.count) team season stats")
        }
        
        // Load game player stats if available
        if let savedGameStats = savedLeague.gamePlayerStats {
            gamePlayerStats.removeAll()
            for (uuidString, stats) in savedGameStats {
                if let uuid = UUID(uuidString: uuidString) {
                    gamePlayerStats[uuid] = stats
                }
            }
            print("🏈 ✅ Loaded \(savedGameStats.count) game player stats")
        }
        
        // Fix existing GamePlayerStats with week 0
        fixWeekZeroStats()
        
        // Show what was loaded
        let totalGamesPlayed = teamSeasonStats.values.reduce(0) { $0 + $1.gamesPlayed }
        let totalPlayerGames = playerSeasonStats.values.reduce(0) { $0 + $1.gamesPlayed }
        print("🏈 📊 Loaded stats summary - Team games: \(totalGamesPlayed), Player games: \(totalPlayerGames)")
    }
    
    /// Fixes existing GamePlayerStats that have week 0 by matching them to completed games
    private func fixWeekZeroStats() {
        print("🔧 Fixing GamePlayerStats with week 0...")
        
        var fixedCount = 0
        
        // Create a mapping of game IDs to weeks from completed games
        var gameIdToWeek: [UUID: Int] = [:]
        for game in completedGames {
            gameIdToWeek[game.id] = game.week
        }
        
        // Fix stats in gamePlayerStats dictionary
        for (gameId, playerStatsArray) in gamePlayerStats {
            // Get the correct week for this game
            guard let correctWeek = gameIdToWeek[gameId], correctWeek > 0 else { continue }
            
            // Check if any stats have week 0
            var needsUpdate = false
            var updatedStats: [GamePlayerStats] = []
            
            for playerStat in playerStatsArray {
                if playerStat.week == 0 {
                    // Create a new GamePlayerStats with the correct week (since week is immutable)
                    var newPlayerStat = GamePlayerStats(
                        gameId: playerStat.gameId,
                        playerId: playerStat.playerId,
                        playerName: playerStat.playerName,
                        position: playerStat.position,
                        teamLogoName: playerStat.teamLogoName,
                        week: correctWeek
                    )
                    
                    // Copy all the stats from the original
                    newPlayerStat.passingAttempts = playerStat.passingAttempts
                    newPlayerStat.passingCompletions = playerStat.passingCompletions
                    newPlayerStat.passingYards = playerStat.passingYards
                    newPlayerStat.passingTouchdowns = playerStat.passingTouchdowns
                    newPlayerStat.interceptions = playerStat.interceptions
                    newPlayerStat.rushingAttempts = playerStat.rushingAttempts
                    newPlayerStat.rushingYards = playerStat.rushingYards
                    newPlayerStat.rushingTouchdowns = playerStat.rushingTouchdowns
                    newPlayerStat.receptions = playerStat.receptions
                    newPlayerStat.receivingYards = playerStat.receivingYards
                    newPlayerStat.receivingTouchdowns = playerStat.receivingTouchdowns
                    newPlayerStat.tackles = playerStat.tackles
                    newPlayerStat.sacksMade = playerStat.sacksMade
                    newPlayerStat.interceptionsDefense = playerStat.interceptionsDefense
                    newPlayerStat.passesDefended = playerStat.passesDefended
                    newPlayerStat.forcedFumbles = playerStat.forcedFumbles
                    newPlayerStat.fumbleRecoveries = playerStat.fumbleRecoveries
                    newPlayerStat.fieldGoalAttempts = playerStat.fieldGoalAttempts
                    newPlayerStat.fieldGoalsMade = playerStat.fieldGoalsMade
                    newPlayerStat.extraPointAttempts = playerStat.extraPointAttempts
                    newPlayerStat.extraPointsMade = playerStat.extraPointsMade
                    newPlayerStat.punts = playerStat.punts
                    newPlayerStat.puntYards = playerStat.puntYards
                    
                    updatedStats.append(newPlayerStat)
                    needsUpdate = true
                    fixedCount += 1
                } else {
                    updatedStats.append(playerStat)
                }
            }
            
            // Update the array if we made changes
            if needsUpdate {
                gamePlayerStats[gameId] = updatedStats
            }
        }
        
        if fixedCount > 0 {
            print("🔧 ✅ Fixed \(fixedCount) GamePlayerStats entries with incorrect week 0")
        } else {
            print("🔧 ✅ No GamePlayerStats with week 0 found to fix")
        }
    }
    
    func updateStatsFromGame(_ game: GameResult) {
        guard let detailedStats = game.detailedStats else {
            // Only log missing stats for user team games to avoid spam
            if game.homeTeam.logoName == userTeam?.logoName || game.awayTeam.logoName == userTeam?.logoName {
                print("⚠️ No detailed stats available for game: \(game.awayTeam.name) @ \(game.homeTeam.name)")
            }
            return
        }
        
        // Only log stats updates for user team games and only during non-batch simulation to reduce spam
        let isUserTeamGame = game.homeTeam.logoName == userTeam?.logoName || game.awayTeam.logoName == userTeam?.logoName
        if isUserTeamGame && !isBatchSimulating {
            print("📊 Updating season stats: \(game.awayTeam.name) @ \(game.homeTeam.name) (Week \(game.week))")
            print("📊 Home team stats: \(detailedStats.homeTeamStats.totalYards) yards, \(detailedStats.homeTeamStats.passingYards) pass, \(detailedStats.homeTeamStats.rushingYards) rush")
            print("📊 Away team stats: \(detailedStats.awayTeamStats.totalYards) yards, \(detailedStats.awayTeamStats.passingYards) pass, \(detailedStats.awayTeamStats.rushingYards) rush")
        }
        
        // Update team stats
        updateTeamSeasonStats(game.homeTeam.logoName, gameStats: detailedStats.homeTeamStats, isHome: true, game: game)
        updateTeamSeasonStats(game.awayTeam.logoName, gameStats: detailedStats.awayTeamStats, isHome: false, game: game)
        
        // Use only natural player stats from the advanced game engine
        // This prevents double-counting stats from both natural and simulated systems
        accumulateNaturalPlayerStats(for: game)
    }
    
    // MARK: - Natural Statistics Accumulation
    private func accumulateNaturalPlayerStats(for game: GameResult) {
        // Check if we have game player stats with natural player actions
        var gamePlayerStatsArray = gamePlayerStats[game.id]
        
        // If no local stats, try to get from global manager
        if gamePlayerStatsArray == nil || gamePlayerStatsArray!.isEmpty {
            gamePlayerStatsArray = GlobalGamePlayerStatsManager.shared.getGamePlayerStats(gameId: game.id)
            
            // Store locally if found
            if let stats = gamePlayerStatsArray {
                gamePlayerStats[game.id] = stats
            }
        }
        
        guard let gamePlayerStatsArray = gamePlayerStatsArray, !gamePlayerStatsArray.isEmpty else {
            // No natural stats available - debug what's happening
            if (game.homeTeam.logoName == userTeam?.logoName || game.awayTeam.logoName == userTeam?.logoName) && !isBatchSimulating {
                print("⚠️ No natural player stats found for game \(game.awayTeam.name) @ \(game.homeTeam.name)")
                print("📊 🔍 LeagueManager looking for gameId: \(game.id)")
                
                // Show what IDs are available in global manager
                let availableIds = GlobalGamePlayerStatsManager.shared.getAllGameIds()
                print("📊 🔍 Available gameIds in GlobalManager: \(availableIds.count) total")
                if availableIds.count > 0 {
                    print("📊 🔍 Recent gameIds: \(Array(availableIds.suffix(5)))")
                }
                
                // Check if our specific gameId exists
                if availableIds.contains(game.id) {
                    print("📊 ✅ GameId EXISTS in global manager!")
                    if let foundStats = GlobalGamePlayerStatsManager.shared.getGamePlayerStats(gameId: game.id) {
                        print("📊 ✅ Found \(foundStats.count) stats when retrieved again")
                    } else {
                        print("📊 ❌ Stats returned nil on second attempt")
                    }
                } else {
                    print("📊 ❌ GameId NOT FOUND in global manager")
                }
            }
            return
        }
        
        // Accumulate natural stats from actual game player stats
        for gamePlayerStat in gamePlayerStatsArray {
            let playerId = gamePlayerStat.playerId
            
            // Get or create player season stats
            var playerSeasonStat = playerSeasonStats[playerId] ?? PlayerSeasonStats(
                playerId: playerId,
                playerName: gamePlayerStat.playerName,
                position: gamePlayerStat.position,
                teamLogoName: gamePlayerStat.teamLogoName
            )
            
            // Add game stats to season totals
            playerSeasonStat.passingAttempts += gamePlayerStat.passingAttempts
            playerSeasonStat.passingCompletions += gamePlayerStat.passingCompletions
            playerSeasonStat.passingYards += gamePlayerStat.passingYards
            playerSeasonStat.passingTouchdowns += gamePlayerStat.passingTouchdowns
            playerSeasonStat.interceptions += gamePlayerStat.interceptions
            
            playerSeasonStat.rushingAttempts += gamePlayerStat.rushingAttempts
            playerSeasonStat.rushingYards += gamePlayerStat.rushingYards
            playerSeasonStat.rushingTouchdowns += gamePlayerStat.rushingTouchdowns
            
            playerSeasonStat.receptions += gamePlayerStat.receptions
            playerSeasonStat.receivingYards += gamePlayerStat.receivingYards
            playerSeasonStat.receivingTouchdowns += gamePlayerStat.receivingTouchdowns
            
            playerSeasonStat.tackles += gamePlayerStat.tackles
            playerSeasonStat.sacksMade += gamePlayerStat.sacksMade
            playerSeasonStat.interceptionsDefense += gamePlayerStat.interceptionsDefense
            playerSeasonStat.passesDefended += gamePlayerStat.passesDefended
            playerSeasonStat.forcedFumbles += gamePlayerStat.forcedFumbles
            playerSeasonStat.fumbleRecoveries += gamePlayerStat.fumbleRecoveries
            
            playerSeasonStat.fieldGoalAttempts += gamePlayerStat.fieldGoalAttempts
            playerSeasonStat.fieldGoalsMade += gamePlayerStat.fieldGoalsMade
            
            playerSeasonStat.gamesPlayed += 1
            
            // Save updated stats
            playerSeasonStats[playerId] = playerSeasonStat
        }
        
        // Log natural stats accumulation for user team
        if (game.homeTeam.logoName == userTeam?.logoName || game.awayTeam.logoName == userTeam?.logoName) && !isBatchSimulating {
            print("📊 ✅ Accumulated natural player stats from \(gamePlayerStatsArray.count) players")
        }
    }
    
    private func updateTeamSeasonStats(_ teamLogoName: String, gameStats: TeamGameStats, isHome: Bool, game: GameResult) {
        guard var teamStats = teamSeasonStats[teamLogoName] else {
            // Only log missing team stats for user team to avoid spam
            if teamLogoName == userTeam?.logoName {
                print("⚠️ Team stats not found for \(teamLogoName)")
            }
            return
        }
        
        // Update offensive stats
        teamStats.totalOffensiveYards += gameStats.totalYards
        teamStats.totalPassingYards += gameStats.passingYards
        teamStats.totalRushingYards += gameStats.rushingYards
        teamStats.totalFirstDowns += gameStats.firstDowns
        teamStats.thirdDownAttempts += gameStats.thirdDownAttempts
        teamStats.thirdDownConversions += gameStats.thirdDownConversions
        teamStats.redZoneAttempts += gameStats.redZoneAttempts
        teamStats.redZoneScores += gameStats.redZoneScores
        teamStats.totalPenalties += gameStats.penalties
        teamStats.totalPenaltyYards += gameStats.penaltyYards
        teamStats.totalTurnovers += gameStats.turnovers
        teamStats.timeOfPossession += gameStats.timeOfPossession
        
        // Update special teams stats
        teamStats.fieldGoalsAttempted += gameStats.fieldGoalAttempts
        teamStats.fieldGoalsMade += gameStats.fieldGoalsMade
        teamStats.extraPointsAttempted += gameStats.extraPointAttempts
        teamStats.extraPointsMade += gameStats.extraPointsMade
        teamStats.totalPunts += gameStats.punts
        teamStats.totalPuntYards += gameStats.puntYards
        
        // Update points scored
        let pointsScored = isHome ? game.homeScore : game.awayScore
        teamStats.totalPoints += pointsScored
        
        // Update touchdown stats
        let totalTDs = gameStats.passingTouchdowns + gameStats.rushingTouchdowns
        teamStats.totalTouchdowns += totalTDs
        
        // Update games played
        teamStats.gamesPlayed += 1
        
        // Calculate defensive stats (opponent's offensive stats)
        let opponentStats = isHome ? game.detailedStats!.awayTeamStats : game.detailedStats!.homeTeamStats
        teamStats.totalYardsAllowed += opponentStats.totalYards
        teamStats.passingYardsAllowed += opponentStats.passingYards
        teamStats.rushingYardsAllowed += opponentStats.rushingYards
        teamStats.pointsAllowed += (isHome ? game.awayScore : game.homeScore)
        teamStats.interceptionsForced += opponentStats.interceptions
        teamStats.fumblesForced += opponentStats.fumbles
        
        // Sacks made by this team's defense = sacks allowed by opponent
        teamStats.sacksAllowed += opponentStats.sacks // This is actually sacks made by defense
        
        // Save updated stats
        teamSeasonStats[teamLogoName] = teamStats
        
        // Debug logging for user team
        if teamLogoName == userTeam?.logoName && !isBatchSimulating {
            print("📊 Updated \(teamLogoName) season stats: \(teamStats.gamesPlayed) games, \(teamStats.totalPoints) points, \(teamStats.totalOffensiveYards) yards")
        }
    }
    
    // MARK: - Phase 6: Updated to use hybrid data loading
    private func simulatePlayerStats(for game: GameResult) {
        // This function simulates realistic player stats based on team performance
        // Updated to use hybrid approach: files first, then master data fallback
        
        let homeTeamPlayers = PlayerDataManager.shared.getPlayers(for: game.homeTeam.logoName, leagueId: currentLeagueId)
        let awayTeamPlayers = PlayerDataManager.shared.getPlayers(for: game.awayTeam.logoName, leagueId: currentLeagueId)
        
        // Convert PlayerData to MasterPlayer format for compatibility
        let homeTeamMasterPlayers = convertToMasterPlayers(playerData: homeTeamPlayers, teamLogoName: game.homeTeam.logoName)
        let awayTeamMasterPlayers = convertToMasterPlayers(playerData: awayTeamPlayers, teamLogoName: game.awayTeam.logoName)
        
        // Simulate home team player stats
        simulateTeamPlayerStats(
            players: homeTeamMasterPlayers,
            teamStats: game.detailedStats!.homeTeamStats,
            teamLogoName: game.homeTeam.logoName,
            game: game
        )
        
        // Simulate away team player stats
        simulateTeamPlayerStats(
            players: awayTeamMasterPlayers,
            teamStats: game.detailedStats!.awayTeamStats,
            teamLogoName: game.awayTeam.logoName,
            game: game
        )
    }
    
    // MARK: - Helper method for Phase 6
    private func convertToMasterPlayers(playerData: [PlayerData], teamLogoName: String) -> [MasterPlayer] {
        // Get master data as fallback for complete player attributes
        let masterLoader = MasterDataLoader.shared
        let masterPlayers = masterLoader.getPlayers(for: teamLogoName)
        
        // Create mapping from player data to master players by matching name and position
        return playerData.compactMap { playerDataItem in
            // Try to find matching master player
            if let matchingMaster = masterPlayers.first(where: { master in
                master.firstName.lowercased() == playerDataItem.firstName.lowercased() &&
                master.lastName.lowercased() == playerDataItem.lastName.lowercased() &&
                master.position == playerDataItem.position
            }) {
                return matchingMaster
            }
            
            // If no exact match found, try position-only match for simulation
            if let positionMatch = masterPlayers.first(where: { $0.position == playerDataItem.position }) {
                return positionMatch
            }
            
            // Return first available player as fallback
            return masterPlayers.first
        }
    }
    
    private func simulateTeamPlayerStats(players: [MasterPlayer], teamStats: TeamGameStats, teamLogoName: String, game: GameResult) {
        var gamePlayerStatsArray: [GamePlayerStats] = []
        
        // Only log for user team and only during non-batch simulation to reduce spam
        if teamLogoName == userTeam?.logoName && !batchModeEnabled {
            print("📊 Simulating player stats for \(teamLogoName) - \(players.count) players")
        }
        
        // Group players by position for realistic distribution
        let playersByPosition = Dictionary(grouping: players) { $0.position }
        
        // Distribute team stats realistically among players
        distributeQBStats(playersByPosition["QB"] ?? [], teamStats: teamStats, teamLogoName: teamLogoName, game: game, gamePlayerStatsArray: &gamePlayerStatsArray)
        distributeRBStats(playersByPosition["RB"] ?? [], teamStats: teamStats, teamLogoName: teamLogoName, game: game, gamePlayerStatsArray: &gamePlayerStatsArray)
        distributeReceivingStats(playersByPosition["WR"] ?? [], teamStats: teamStats, teamLogoName: teamLogoName, game: game, gamePlayerStatsArray: &gamePlayerStatsArray, position: "WR")
        distributeReceivingStats(playersByPosition["TE"] ?? [], teamStats: teamStats, teamLogoName: teamLogoName, game: game, gamePlayerStatsArray: &gamePlayerStatsArray, position: "TE")
        distributeKickingStats(playersByPosition["K"] ?? [], teamStats: teamStats, teamLogoName: teamLogoName, game: game, gamePlayerStatsArray: &gamePlayerStatsArray)
        distributePuntingStats(playersByPosition["P"] ?? [], teamStats: teamStats, teamLogoName: teamLogoName, game: game, gamePlayerStatsArray: &gamePlayerStatsArray)
        // Get opponent's stats for defensive calculations
        let opponentStats = teamLogoName == game.homeTeam.logoName ? game.detailedStats!.awayTeamStats : game.detailedStats!.homeTeamStats
        distributeDefensiveStats(playersByPosition, teamStats: teamStats, opponentStats: opponentStats, teamLogoName: teamLogoName, game: game, gamePlayerStatsArray: &gamePlayerStatsArray)
        
        // Store game player stats
        gamePlayerStats[game.id] = gamePlayerStatsArray
    }
    
    private func distributeQBStats(_ qbs: [MasterPlayer], teamStats: TeamGameStats, teamLogoName: String, game: GameResult, gamePlayerStatsArray: inout [GamePlayerStats]) {
        guard !qbs.isEmpty else { return }
        
        // Sort QBs by overall rating to determine starter vs backup
        let sortedQBs = qbs.sorted { $0.overall > $1.overall }
        
        for (index, qb) in sortedQBs.enumerated() {
            let playerId = "\(qb.firstName)_\(qb.lastName)_\(qb.jerseyNum)"
            guard var playerSeasonStat = playerSeasonStats[playerId] else { continue }
            
            var gamePlayerStat = GamePlayerStats(
                gameId: game.id,
                playerId: playerId,
                playerName: "\(qb.firstName) \(qb.lastName)",
                position: qb.position,
                teamLogoName: teamLogoName,
                week: game.week
            )
            
            // Starter gets majority of stats, backups get minimal
            let share = index == 0 ? 0.92 : (0.08 / Double(max(sortedQBs.count - 1, 1)))
            
            let attempts = Int(Double(teamStats.passingAttempts) * share)
            let completions = Int(Double(teamStats.passingCompletions) * share)
            let yards = Int(Double(teamStats.passingYards) * share)
            
            // Enhanced touchdown distribution with QB rating variance
            let baseTouchdowns = Int(Double(teamStats.passingTouchdowns) * share)
            let touchdowns = calculateEnhancedQBTouchdowns(
                baseTouchdowns: baseTouchdowns,
                qbRating: Int(qb.overall) ?? 75,
                attempts: attempts,
                isStarter: index == 0
            )
            
            let interceptions = Int(Double(teamStats.interceptions) * share)
            
            // Update season stats
            playerSeasonStat.passingAttempts += attempts
            playerSeasonStat.passingCompletions += completions
            playerSeasonStat.passingYards += yards
            playerSeasonStat.passingTouchdowns += touchdowns
            playerSeasonStat.interceptions += interceptions
            playerSeasonStat.gamesPlayed += 1
            
            // Update game stats
            gamePlayerStat.passingAttempts = attempts
            gamePlayerStat.passingCompletions = completions
            gamePlayerStat.passingYards = yards
            gamePlayerStat.passingTouchdowns = touchdowns
            gamePlayerStat.interceptions = interceptions
            
            // QB rushing (mobile QBs get more)
            let rushingShare = index == 0 ? 0.15 : 0.02
            let rushAttempts = Int(Double(teamStats.rushingAttempts) * rushingShare)
            let rushYards = Int(Double(teamStats.rushingYards) * rushingShare)
            let rushTDs = Int(Double(teamStats.rushingTouchdowns) * rushingShare)
            
            playerSeasonStat.rushingAttempts += rushAttempts
            playerSeasonStat.rushingYards += rushYards
            playerSeasonStat.rushingTouchdowns += rushTDs
            
            gamePlayerStat.rushingAttempts = rushAttempts
            gamePlayerStat.rushingYards = rushYards
            gamePlayerStat.rushingTouchdowns = rushTDs
            
            playerSeasonStats[playerId] = playerSeasonStat
            gamePlayerStatsArray.append(gamePlayerStat)
        }
    }
    
    // MARK: - Enhanced QB Touchdown Calculation
    private func calculateEnhancedQBTouchdowns(baseTouchdowns: Int, qbRating: Int, attempts: Int, isStarter: Bool) -> Int {
        // Only apply enhancement to starters with meaningful attempts
        guard isStarter && attempts > 10 else { return baseTouchdowns }
        
        // Calculate QB rating multiplier for touchdown variance
        let ratingMultiplier = getQBTouchdownRatingMultiplier(rating: qbRating)
        
        // Apply weekly variance for hot/cold streaks (similar to defensive stats)
        let weeklyVariance = getQBWeeklyVariance()
        
        // Calculate enhanced touchdowns with rating and variance
        let enhancedTouchdowns = Double(baseTouchdowns) * ratingMultiplier * weeklyVariance
        
        // Add attempt-based bonus for high-volume passers (more attempts = more TD opportunities)
        let attemptBonus = attempts > 35 ? 0.15 : (attempts > 25 ? 0.08 : 0.0)
        let bonusTouchdowns = enhancedTouchdowns * attemptBonus
        
        // Final touchdown count with some randomness
        let finalTouchdowns = Int(enhancedTouchdowns + bonusTouchdowns)
        
        // Ensure we don't go below 0 or exceed reasonable limits (max 6 TDs per game)
        return max(0, min(6, finalTouchdowns))
    }
    
    private func getQBTouchdownRatingMultiplier(rating: Int) -> Double {
        // Enhanced multipliers for QB touchdown generation based on rating
        switch rating {
        case 95...99: return 1.8  // Elite QBs get 80% more touchdowns (Mahomes, Allen, etc.)
        case 90...94: return 1.5  // Very good QBs get 50% more touchdowns
        case 85...89: return 1.25 // Good QBs get 25% more touchdowns
        case 80...84: return 1.1  // Above average QBs get 10% more touchdowns
        case 75...79: return 1.0  // Average QBs get baseline touchdowns
        case 70...74: return 0.85 // Below average QBs get 15% fewer touchdowns
        default: return 0.7       // Poor QBs get 30% fewer touchdowns
        }
    }
    
    private func getQBWeeklyVariance() -> Double {
        // Weekly variance specifically tuned for QB performance
        let roll = Double.random(in: 0...1)
        
        if roll < 0.08 {
            return 2.2      // 8% chance of explosive game (4+ TDs)
        } else if roll < 0.18 {
            return 1.6      // 10% chance of great game (3+ TDs)
        } else if roll < 0.35 {
            return 1.3      // 17% chance of good game (2+ TDs)
        } else if roll < 0.75 {
            return 1.0      // 40% chance of average game (1-2 TDs)
        } else {
            return 0.6      // 25% chance of quiet game (0-1 TDs)
        }
    }
    
    private func distributeRBStats(_ rbs: [MasterPlayer], teamStats: TeamGameStats, teamLogoName: String, game: GameResult, gamePlayerStatsArray: inout [GamePlayerStats]) {
        guard !rbs.isEmpty else { return }
        
        let sortedRBs = rbs.sorted { $0.overall > $1.overall }
        
        // Create realistic distribution: RB1 gets most, RB2 gets some, others get scraps
        let shares = createRealisticShares(playerCount: sortedRBs.count, primaryShare: 0.60)
        
        for (index, rb) in sortedRBs.enumerated() {
            let playerId = "\(rb.firstName)_\(rb.lastName)_\(rb.jerseyNum)"
            guard var playerSeasonStat = playerSeasonStats[playerId] else { continue }
            
            var gamePlayerStat = GamePlayerStats(
                gameId: game.id,
                playerId: playerId,
                playerName: "\(rb.firstName) \(rb.lastName)",
                position: rb.position,
                teamLogoName: teamLogoName,
                week: game.week
            )
            
            let share = shares[index]
            
            // Rushing stats
            let attempts = Int(Double(teamStats.rushingAttempts) * share)
            let yards = Int(Double(teamStats.rushingYards) * share)
            let touchdowns = Int(Double(teamStats.rushingTouchdowns) * share)
            
            playerSeasonStat.rushingAttempts += attempts
            playerSeasonStat.rushingYards += yards
            playerSeasonStat.rushingTouchdowns += touchdowns
            playerSeasonStat.gamesPlayed += 1
            
            gamePlayerStat.rushingAttempts = attempts
            gamePlayerStat.rushingYards = yards
            gamePlayerStat.rushingTouchdowns = touchdowns
            
            // RB receiving (pass-catching backs get more)
            let receivingShare = share * 0.3 // RBs get some receiving
            let receptions = Int(Double(teamStats.passingCompletions) * receivingShare)
            let recYards = Int(Double(teamStats.passingYards) * receivingShare * 0.5) // Shorter passes
            // Use realistic touchdown rate for RBs - they score on ~4% of receptions
            let recTDs = max(0, Int(Double(receptions) * 0.04))
            
            playerSeasonStat.receptions += receptions
            playerSeasonStat.receivingYards += recYards
            playerSeasonStat.receivingTouchdowns += recTDs
            
            gamePlayerStat.receptions = receptions
            gamePlayerStat.receivingYards = recYards
            gamePlayerStat.receivingTouchdowns = recTDs
            
            playerSeasonStats[playerId] = playerSeasonStat
            gamePlayerStatsArray.append(gamePlayerStat)
        }
    }
    
    private func distributeReceivingStats(_ receivers: [MasterPlayer], teamStats: TeamGameStats, teamLogoName: String, game: GameResult, gamePlayerStatsArray: inout [GamePlayerStats], position: String) {
        guard !receivers.isEmpty else { return }
        
        let sortedReceivers = receivers.sorted { $0.overall > $1.overall }
        
        // WRs get more than TEs
        let baseShare = position == "WR" ? 0.50 : 0.25
        let shares = createRealisticShares(playerCount: sortedReceivers.count, primaryShare: baseShare)
        
        for (index, receiver) in sortedReceivers.enumerated() {
            let playerId = "\(receiver.firstName)_\(receiver.lastName)_\(receiver.jerseyNum)"
            guard var playerSeasonStat = playerSeasonStats[playerId] else { continue }
            
            var gamePlayerStat = GamePlayerStats(
                gameId: game.id,
                playerId: playerId,
                playerName: "\(receiver.firstName) \(receiver.lastName)",
                position: receiver.position,
                teamLogoName: teamLogoName,
                week: game.week
            )
            
            let share = shares[index]
            
            let receptions = Int(Double(teamStats.passingCompletions) * share)
            let yards = Int(Double(teamStats.passingYards) * share)
            // Use realistic touchdown rate based on receptions/yards, not inflated team stats
            let touchdownRate = position == "WR" ? 0.08 : 0.06  // WRs: ~8% of receptions are TDs, TEs: ~6%
            let touchdowns = max(0, Int(Double(receptions) * touchdownRate))
            
            playerSeasonStat.receptions += receptions
            playerSeasonStat.receivingYards += yards
            playerSeasonStat.receivingTouchdowns += touchdowns
            playerSeasonStat.gamesPlayed += 1
            
            gamePlayerStat.receptions = receptions
            gamePlayerStat.receivingYards = yards
            gamePlayerStat.receivingTouchdowns = touchdowns
            
            playerSeasonStats[playerId] = playerSeasonStat
            gamePlayerStatsArray.append(gamePlayerStat)
        }
    }
    
    private func distributeKickingStats(_ kickers: [MasterPlayer], teamStats: TeamGameStats, teamLogoName: String, game: GameResult, gamePlayerStatsArray: inout [GamePlayerStats]) {
        guard let kicker = kickers.first else { return }
        
        let playerId = "\(kicker.firstName)_\(kicker.lastName)_\(kicker.jerseyNum)"
        guard var playerSeasonStat = playerSeasonStats[playerId] else { return }
        
        var gamePlayerStat = GamePlayerStats(
            gameId: game.id,
            playerId: playerId,
            playerName: "\(kicker.firstName) \(kicker.lastName)",
            position: kicker.position,
            teamLogoName: teamLogoName,
            week: game.week
        )
        
        playerSeasonStat.fieldGoalAttempts += teamStats.fieldGoalAttempts
        playerSeasonStat.fieldGoalsMade += teamStats.fieldGoalsMade
        playerSeasonStat.extraPointAttempts += teamStats.extraPointAttempts
        playerSeasonStat.extraPointsMade += teamStats.extraPointsMade
        playerSeasonStat.gamesPlayed += 1
        
        gamePlayerStat.fieldGoalAttempts = teamStats.fieldGoalAttempts
        gamePlayerStat.fieldGoalsMade = teamStats.fieldGoalsMade
        
        playerSeasonStats[playerId] = playerSeasonStat
        gamePlayerStatsArray.append(gamePlayerStat)
    }
    
    private func distributePuntingStats(_ punters: [MasterPlayer], teamStats: TeamGameStats, teamLogoName: String, game: GameResult, gamePlayerStatsArray: inout [GamePlayerStats]) {
        guard let punter = punters.first else { return }
        
        let playerId = "\(punter.firstName)_\(punter.lastName)_\(punter.jerseyNum)"
        guard var playerSeasonStat = playerSeasonStats[playerId] else { return }
        
        playerSeasonStat.punts += teamStats.punts
        playerSeasonStat.puntYards += teamStats.puntYards
        playerSeasonStat.gamesPlayed += 1
        
        playerSeasonStats[playerId] = playerSeasonStat
    }
    private func distributeDefensiveStats(_ playersByPosition: [String: [MasterPlayer]], teamStats: TeamGameStats, opponentStats: TeamGameStats, teamLogoName: String, game: GameResult, gamePlayerStatsArray: inout [GamePlayerStats]) {
        let defensivePositions = ["MLB", "ROLB", "LOLB", "EDGE", "DE", "DT", "CB", "SS", "FS"]
        
        for position in defensivePositions {
            let players = playersByPosition[position] ?? []
            guard !players.isEmpty else { continue }
            
            let sortedPlayers = players.sorted { $0.overall > $1.overall }
            let shares = createRealisticShares(playerCount: sortedPlayers.count, primaryShare: getDefensiveTackleShare(position: position))
            
            for (index, player) in sortedPlayers.enumerated() {
                let playerId = "\(player.firstName)_\(player.lastName)_\(player.jerseyNum)"
                guard var playerSeasonStat = playerSeasonStats[playerId] else { continue }
                
                var gamePlayerStat = GamePlayerStats(
                    gameId: game.id,
                    playerId: playerId,
                    playerName: "\(player.firstName) \(player.lastName)",
                    position: player.position,
                    teamLogoName: teamLogoName,
                    week: game.week
                )
                
                let tackleShare = shares[index]
                let sackShare = getDefensiveSackShare(position: position) * (index == 0 ? 1.0 : 0.3)
                let interceptionShare = getDefensiveInterceptionShare(position: position) * (index == 0 ? 1.0 : 0.4)
                let passDefenseShare = getDefensivePassDefenseShare(position: position) * (index == 0 ? 1.0 : 0.5)
                let fumbleShare = getDefensiveFumbleShare(position: position) * (index == 0 ? 1.0 : 0.3)
                
                // Apply player rating multiplier for elite performance
                let playerRating = Int(player.overall) ?? 75
                let ratingMultiplier = getDefensiveRatingMultiplier(playerRating: playerRating)
                
                // Apply weekly variance for hot/cold streaks
                let weeklyVariance = getWeeklyVariance()
                
                // Use realistic base rates instead of opponent's inflated stats
                let basePassAttempts = max(25, opponentStats.passingAttempts)  // Minimum realistic pass attempts
                let baseRushAttempts = max(15, opponentStats.rushingAttempts)  // Minimum realistic rush attempts
                let totalPlays = basePassAttempts + baseRushAttempts
                
                // Calculate realistic defensive stats with proper base rates
                let estimatedTackles = Int(Double(totalPlays) * tackleShare * ratingMultiplier * weeklyVariance)
                let estimatedSacks = Int(Double(basePassAttempts) * sackShare * 0.015 * ratingMultiplier * weeklyVariance)  // Reduced from 0.12 to 0.015 for realistic totals
                let estimatedInterceptions = Int(Double(basePassAttempts) * interceptionShare * 0.025 * ratingMultiplier * weeklyVariance)  // ~2.5% INT rate
                let estimatedPassesDefended = Int(Double(basePassAttempts) * passDefenseShare * 0.15 * ratingMultiplier * weeklyVariance)  // ~15% PD rate
                let estimatedForcedFumbles = Int(Double(totalPlays) * fumbleShare * 0.015 * ratingMultiplier * weeklyVariance)  // ~1.5% fumble rate
                let estimatedFumbleRecoveries = Int(Double(totalPlays) * fumbleShare * 0.01 * ratingMultiplier * weeklyVariance)  // ~1% recovery rate
                
                playerSeasonStat.tackles += estimatedTackles
                playerSeasonStat.sacksMade += estimatedSacks
                playerSeasonStat.interceptionsDefense += estimatedInterceptions
                playerSeasonStat.passesDefended += estimatedPassesDefended
                playerSeasonStat.forcedFumbles += estimatedForcedFumbles
                playerSeasonStat.fumbleRecoveries += estimatedFumbleRecoveries
                playerSeasonStat.gamesPlayed += 1
                
                gamePlayerStat.tackles = estimatedTackles
                gamePlayerStat.sacksMade = estimatedSacks
                gamePlayerStat.interceptionsDefense = estimatedInterceptions
                gamePlayerStat.passesDefended = estimatedPassesDefended
                gamePlayerStat.forcedFumbles = estimatedForcedFumbles
                gamePlayerStat.fumbleRecoveries = estimatedFumbleRecoveries
                
                playerSeasonStats[playerId] = playerSeasonStat
                gamePlayerStatsArray.append(gamePlayerStat)
            }
        }
    }
    
    // Helper function to create realistic stat distribution
    private func createRealisticShares(playerCount: Int, primaryShare: Double) -> [Double] {
        guard playerCount > 0 else { return [] }
        
        if playerCount == 1 {
            return [primaryShare]
        }
        
        var shares: [Double] = []
        let remainingShare = primaryShare
        
        // First player gets the lion's share
        shares.append(remainingShare * 0.7)
        
        if playerCount > 1 {
            // Second player gets decent share
            shares.append(remainingShare * 0.2)
        }
        
        // Remaining players split the scraps
        let remainingPlayers = playerCount - 2
        if remainingPlayers > 0 {
            let scrapShare = (remainingShare * 0.1) / Double(remainingPlayers)
            for _ in 0..<remainingPlayers {
                shares.append(scrapShare)
            }
        }
        
        return shares
    }
    
    private func getDefensiveTackleShare(position: String) -> Double {
        // Rebalanced for realistic NFL tackle totals (reduced by ~60%)
        switch position {
        case "MLB": return 0.08        // Was 0.20 - elite MLBs now get ~120-140 tackles vs 300+
        case "ROLB", "LOLB": return 0.06   // Was 0.15 - OLBs now get ~90-110 tackles vs 250+
        case "SS", "FS": return 0.05       // Was 0.12 - Safeties now get ~75-95 tackles vs 200+
        case "CB": return 0.03             // Was 0.08 - CBs now get ~45-65 tackles vs 140+
        case "DE", "EDGE": return 0.04     // Was 0.10 - Edge rushers now get ~60-80 tackles vs 170+
        case "DT": return 0.03             // Was 0.08 - DTs now get ~45-65 tackles vs 140+
        default: return 0.02
        }
    }
    
    private func getDefensiveSackShare(position: String) -> Double {
        // Position-based sack distribution - works with 1.5% base rate for realistic totals
        switch position {
        case "DE", "EDGE": return 0.35     // Elite pass rushers: ~14-19 sacks (realistic NFL range)
        case "ROLB", "LOLB": return 0.20   // OLBs: ~6-10 sacks  
        case "DT": return 0.15             // DTs: ~4-7 sacks
        case "MLB": return 0.08            // MLBs: ~2-4 sacks
        default: return 0.03
        }
    }
    
    private func getDefensiveInterceptionShare(position: String) -> Double {
        // Reduced to account for lower base interception rates
        switch position {
        case "CB": return 0.30             // Was 0.35 - elite CBs now get ~6-10 INTs vs 15+
        case "SS", "FS": return 0.20       // Was 0.25 - Safeties now get ~4-8 INTs vs 12+
        case "ROLB", "LOLB": return 0.12   // Was 0.15 - OLBs now get ~2-5 INTs vs 8+
        case "MLB": return 0.08            // Was 0.10 - MLBs now get ~1-4 INTs vs 6+
        default: return 0.03
        }
    }
    
    private func getDefensivePassDefenseShare(position: String) -> Double {
        switch position {
        case "CB": return 0.40
        case "SS", "FS": return 0.20
        case "ROLB", "LOLB": return 0.15
        case "MLB": return 0.10
        default: return 0.05
        }
    }
    
    private func getDefensiveFumbleShare(position: String) -> Double {
        switch position {
        case "DE", "EDGE": return 0.25
        case "ROLB", "LOLB": return 0.20
        case "MLB": return 0.20
        case "DT": return 0.15
        case "SS", "FS": return 0.10
        case "CB": return 0.05
        default: return 0.05
        }
    }
    
    /// Returns a multiplier based on player rating for defensive stats - creates natural elite performance
    private func getDefensiveRatingMultiplier(playerRating: Int) -> Double {
        switch playerRating {
        case 95...99: return 1.8  // Elite defenders get 80% more opportunities
        case 90...94: return 1.5  // Very good defenders get 50% more
        case 85...89: return 1.2  // Good defenders get 20% more
        case 80...84: return 1.0  // Average baseline
        case 75...79: return 0.8  // Below average get 20% fewer
        default: return 0.6       // Poor defenders get 40% fewer
        }
    }
    
    /// Returns weekly performance variance to create hot/cold streaks and exceptional games
    private func getWeeklyVariance() -> Double {
        let roll = Double.random(in: 0...1)
        
        if roll < 0.05 {
            return 2.5      // 5% chance of monster game (3 sacks, 2 INTs, etc.)
        } else if roll < 0.15 {
            return 1.7      // 10% chance of great game
        } else if roll < 0.25 {
            return 1.3      // 10% chance of good game
        } else if roll < 0.75 {
            return 1.0      // 50% chance of average game
        } else {
            return 0.6      // 25% chance of quiet game
        }
    }

    // MARK: - Statistics Queries
    func getLeagueLeaders(category: StatCategory, limit: Int = 10) -> [PlayerSeasonStats] {
        let allPlayers = Array(playerSeasonStats.values)
        
        switch category {
        case .passingYards:
            return allPlayers.sorted { 
                if $0.passingYards != $1.passingYards {
                    return $0.passingYards > $1.passingYards
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .rushingYards:
            return allPlayers.sorted { 
                if $0.rushingYards != $1.rushingYards {
                    return $0.rushingYards > $1.rushingYards
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .receivingYards:
            return allPlayers.sorted { 
                if $0.receivingYards != $1.receivingYards {
                    return $0.receivingYards > $1.receivingYards
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .passingTouchdowns:
            return allPlayers.sorted { 
                if $0.passingTouchdowns != $1.passingTouchdowns {
                    return $0.passingTouchdowns > $1.passingTouchdowns
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .rushingTouchdowns:
            return allPlayers.sorted { 
                if $0.rushingTouchdowns != $1.rushingTouchdowns {
                    return $0.rushingTouchdowns > $1.rushingTouchdowns
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .receivingTouchdowns:
            return allPlayers.sorted { 
                if $0.receivingTouchdowns != $1.receivingTouchdowns {
                    return $0.receivingTouchdowns > $1.receivingTouchdowns
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .tackles:
            return allPlayers.sorted { 
                if $0.tackles != $1.tackles {
                    return $0.tackles > $1.tackles
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .sacks:
            return allPlayers.sorted { 
                if $0.sacksMade != $1.sacksMade {
                    return $0.sacksMade > $1.sacksMade
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .interceptions:
            return allPlayers.sorted { 
                if $0.interceptionsDefense != $1.interceptionsDefense {
                    return $0.interceptionsDefense > $1.interceptionsDefense
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .fieldGoals:
            return allPlayers.sorted { 
                if $0.fieldGoalsMade != $1.fieldGoalsMade {
                    return $0.fieldGoalsMade > $1.fieldGoalsMade
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        }
    }
    
    func getTeamLeaders(teamLogoName: String, category: StatCategory, limit: Int = 5) -> [PlayerSeasonStats] {
        let teamPlayers = playerSeasonStats.values.filter { $0.teamLogoName == teamLogoName }
        
        switch category {
        case .passingYards:
            return teamPlayers.sorted { 
                if $0.passingYards != $1.passingYards {
                    return $0.passingYards > $1.passingYards
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .rushingYards:
            return teamPlayers.sorted { 
                if $0.rushingYards != $1.rushingYards {
                    return $0.rushingYards > $1.rushingYards
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .receivingYards:
            return teamPlayers.sorted { 
                if $0.receivingYards != $1.receivingYards {
                    return $0.receivingYards > $1.receivingYards
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .passingTouchdowns:
            return teamPlayers.sorted { 
                if $0.passingTouchdowns != $1.passingTouchdowns {
                    return $0.passingTouchdowns > $1.passingTouchdowns
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .rushingTouchdowns:
            return teamPlayers.sorted { 
                if $0.rushingTouchdowns != $1.rushingTouchdowns {
                    return $0.rushingTouchdowns > $1.rushingTouchdowns
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .receivingTouchdowns:
            return teamPlayers.sorted { 
                if $0.receivingTouchdowns != $1.receivingTouchdowns {
                    return $0.receivingTouchdowns > $1.receivingTouchdowns
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .tackles:
            return teamPlayers.sorted { 
                if $0.tackles != $1.tackles {
                    return $0.tackles > $1.tackles
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .sacks:
            return teamPlayers.sorted { 
                if $0.sacksMade != $1.sacksMade {
                    return $0.sacksMade > $1.sacksMade
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .interceptions:
            return teamPlayers.sorted { 
                if $0.interceptionsDefense != $1.interceptionsDefense {
                    return $0.interceptionsDefense > $1.interceptionsDefense
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        case .fieldGoals:
            return teamPlayers.sorted { 
                if $0.fieldGoalsMade != $1.fieldGoalsMade {
                    return $0.fieldGoalsMade > $1.fieldGoalsMade
                }
                return $0.playerName < $1.playerName // Stable tie-breaker
            }.prefix(limit).map { $0 }
        }
    }
    
    func getTeamSeasonStats(teamLogoName: String) -> TeamSeasonStats? {
        return teamSeasonStats[teamLogoName]
    }
    
    func getPlayerSeasonStats(playerId: String) -> PlayerSeasonStats? {
        return playerSeasonStats[playerId]
    }
    
    // MARK: - Debug Methods
    func debugStatsStatus() {
        print("🔍 STATS DEBUG:")
        print("🔍 Team stats count: \(teamSeasonStats.count)")
        print("🔍 Player stats count: \(playerSeasonStats.count)")
        
        let totalTeamGames = teamSeasonStats.values.reduce(0) { $0 + $1.gamesPlayed }
        let totalPlayerGames = playerSeasonStats.values.reduce(0) { $0 + $1.gamesPlayed }
        print("🔍 Total team games: \(totalTeamGames)")
        print("🔍 Total player games: \(totalPlayerGames)")
    }
    
    /// Validates statistical ranges to ensure they're in realistic NFL ranges
    func validateStatisticalRanges() {
        let interceptionLeaders = getLeagueLeaders(category: .interceptions, limit: 5)
        let sackLeaders = getLeagueLeaders(category: .sacks, limit: 5)
        let tackleLeaders = getLeagueLeaders(category: .tackles, limit: 5)
        let receivingTDLeaders = getLeagueLeaders(category: .receivingTouchdowns, limit: 5)
        
        if let topINT = interceptionLeaders.first {
            print("📊 Top Interceptions: \(topINT.playerName) - \(topINT.interceptionsDefense)")
            if topINT.interceptionsDefense > 11 {
                print("⚠️ Interceptions too high (target: 7-11 range, NFL leaders typically 8-10)")
            } else if topINT.interceptionsDefense < 5 {
                print("⚠️ Interceptions too low (target: 7-11 range)")
            } else {
                print("✅ Interceptions in realistic NFL range")
            }
        }
        
        if let topSacks = sackLeaders.first {
            print("📊 Top Sacks: \(topSacks.playerName) - \(topSacks.sacksMade)")
            if topSacks.sacksMade > 23 {
                print("⚠️ Sacks too high (target: 14-22 range, NFL leaders typically 15-19)")
            } else if topSacks.sacksMade < 10 {
                print("⚠️ Sacks too low (target: 14-22 range)")
            } else {
                print("✅ Sacks in realistic NFL range")
            }
        }
        
        if let topTackles = tackleLeaders.first {
            print("📊 Top Tackles: \(topTackles.playerName) - \(topTackles.tackles)")
            if topTackles.tackles > 190 {
                print("⚠️ Tackles too high (target: 120-180 range, NFL leaders typically 150-175)")
            } else if topTackles.tackles < 100 {
                print("⚠️ Tackles too low (target: 120-180 range)")
            } else {
                print("✅ Tackles in realistic NFL range")
            }
        }
        
        if let topRecTDs = receivingTDLeaders.first {
            print("📊 Top Receiving TDs: \(topRecTDs.playerName) - \(topRecTDs.receivingTouchdowns)")
            if topRecTDs.receivingTouchdowns > 20 {
                print("⚠️ Receiving TDs still too high (target: 12-18)")
            } else {
                print("✅ Receiving TDs in realistic range")
            }
        }
        
        // Show user team stats if available
        if let userTeam = userTeam,
           let teamStats = teamSeasonStats[userTeam.logoName] {
            print("🔍 User team (\(userTeam.logoName)) stats:")
            print("🔍   Games played: \(teamStats.gamesPlayed)")
            print("🔍   Total points: \(teamStats.totalPoints)")
            print("🔍   Total yards: \(teamStats.totalOffensiveYards)")
        }
        
        // Show top 3 players by passing yards
        let topPassers = playerSeasonStats.values
            .filter { $0.passingYards > 0 }
            .sorted { $0.passingYards > $1.passingYards }
            .prefix(3)
        
        print("🔍 Top passers:")
        for (index, player) in topPassers.enumerated() {
            print("🔍   \(index + 1). \(player.playerName): \(player.passingYards) yards")
        }
    }

    enum StatCategory {
        case passingYards, rushingYards, receivingYards
        case passingTouchdowns, rushingTouchdowns, receivingTouchdowns
        case tackles, sacks, interceptions, fieldGoals
    }

    // Helper method to get games for a specific week
    private func getGamesForWeek(_ week: Int) -> [GameResult]? {
        let weekGames = upcomingGames.filter { $0.week == week && !$0.isCompleted }
        return weekGames.isEmpty ? nil : weekGames
    }
    
    // MARK: - Playoff Management
    var playoffTeams: [LeagueTeam] = []
    let bracketManager = PlayoffBracketManager()
    
    // REMOVED: Legacy playoffResults - now using only bracketManager for single source of truth
    
    func determinePlayoffTeams() {
        // Use deterministic seeding to prevent inconsistent brackets
        getDeterministicPlayoffSeeding()
        
        // Split playoff teams back into conferences for display
        let afcPlayoffTeams = Array(playoffTeams.prefix(7))
        let nfcPlayoffTeams = Array(playoffTeams.suffix(7))
        
        print("🏈 Determined playoff teams:")
        print("ACFT:")
        for (index, team) in afcPlayoffTeams.enumerated() {
            let record = getTeamRecord(for: team.logoName)
            print("   \(index + 1). \(team.name) (\(record.wins)-\(record.losses)-\(record.ties))")
        }
        print("NCFT:")
        for (index, team) in nfcPlayoffTeams.enumerated() {
            let record = getTeamRecord(for: team.logoName)
            print("   \(index + 1). \(team.name) (\(record.wins)-\(record.losses)-\(record.ties))")
        }
        
        // Debug: Check if user team made playoffs
        if let userTeam = userTeam {
            let userMadePlayoffs = playoffTeams.contains { $0.logoName == userTeam.logoName }
            let userRecord = getTeamRecord(for: userTeam.logoName)
            print("🏈 USER TEAM PLAYOFF STATUS:")
            print("   Team: \(userTeam.logoName)")
            print("   Record: \(userRecord.wins)-\(userRecord.losses)-\(userRecord.ties)")
            print("   Made Playoffs: \(userMadePlayoffs ? "✅ YES" : "❌ NO")")
            
            if !userMadePlayoffs {
                print("❌ USER TEAM DID NOT MAKE PLAYOFFS!")
                print("   This may indicate a record synchronization issue.")
                print("   Checking user team position in conference...")
                
                let userConference = getProperConference(for: userTeam.logoName)
                let conferenceTeams = allTeams.filter { $0.conference == userConference.rawValue }
                let sortedConferenceTeams = conferenceTeams.sorted { team1, team2 in
                    compareTeamRecords(team1: team1, team2: team2)
                }
                
                if let userPosition = sortedConferenceTeams.firstIndex(where: { $0.logoName == userTeam.logoName }) {
                    print("   User team position in \(userConference.rawValue): \(userPosition + 1) out of \(sortedConferenceTeams.count)")
                    print("   Top 7 teams in \(userConference.rawValue):")
                    for (index, team) in sortedConferenceTeams.prefix(7).enumerated() {
                        let record = getTeamRecord(for: team.logoName)
                        let marker = team.logoName == userTeam.logoName ? " ← USER TEAM" : ""
                        print("     \(index + 1). \(team.name) (\(record.wins)-\(record.losses)-\(record.ties))\(marker)")
                    }
                }
            }
        }
    }
    
    // Proper NFL playoff seeding: Seeds 1-4 are division winners, Seeds 5-7 are wild cards
    private func getProperConferencePlayoffTeams(from teams: [LeagueTeam]) -> [LeagueTeam] {
        print("🏈 === NFL PLAYOFF SEEDING (Conference with \(teams.count) teams) ===")
        
        // Get all divisions in this conference
        let conferenceDivisions = Set(teams.map { $0.division })
        var divisionWinners: [LeagueTeam] = []
        var wildCardCandidates: [LeagueTeam] = []
        
        print("🏈 Divisions in conference: \(conferenceDivisions.sorted())")
        
        // STEP 1: Find division winner for each division
        for division in conferenceDivisions.sorted() {
            let divisionTeams = teams.filter { $0.division == division }
            let sortedDivisionTeams = divisionTeams.sorted { team1, team2 in
                compareTeamRecords(team1: team1, team2: team2)
            }
            
            if let winner = sortedDivisionTeams.first {
                divisionWinners.append(winner)
                let winnerRecord = getTeamRecord(for: winner.logoName)
                print("🏆 \(division) DIVISION WINNER: \(winner.name) (\(winnerRecord.wins)-\(winnerRecord.losses)-\(winnerRecord.ties))")
                
                // Add remaining teams to wild card pool
                let remainingTeams = Array(sortedDivisionTeams.dropFirst())
                wildCardCandidates.append(contentsOf: remainingTeams)
                
                for team in remainingTeams {
                    let record = getTeamRecord(for: team.logoName)
                    print("   Wild Card Candidate: \(team.name) (\(record.wins)-\(record.losses)-\(record.ties))")
                }
            }
            print("---")
        }
        
        // DEFENSIVE VALIDATION: Ensure we have exactly 4 division winners
        guard divisionWinners.count == 4 else {
            print("❌ ERROR: Expected 4 division winners, got \(divisionWinners.count)")
            print("❌ This violates NFL playoff structure!")
            return []
        }
        
        // STEP 2: Sort division winners by record for seeds 1-4
        divisionWinners.sort { team1, team2 in
            compareTeamRecords(team1: team1, team2: team2)
        }
        
        print("🏈 DIVISION WINNERS (Seeds 1-4) - ALWAYS ranked above wild cards:")
        for (index, winner) in divisionWinners.enumerated() {
            let record = getTeamRecord(for: winner.logoName)
            print("   SEED #\(index + 1): \(winner.name) (\(record.wins)-\(record.losses)-\(record.ties)) - \(winner.division) Champion")
        }
        
        // STEP 3: Sort wild card candidates and take top 3 for seeds 5-7
        wildCardCandidates.sort { team1, team2 in
            compareTeamRecords(team1: team1, team2: team2)
        }
        let wildCardTeams = Array(wildCardCandidates.prefix(3))
        
        // DEFENSIVE VALIDATION: Ensure we have exactly 3 wild cards
        guard wildCardTeams.count == 3 else {
            print("❌ ERROR: Expected 3 wild cards, got \(wildCardTeams.count)")
            print("❌ This violates NFL playoff structure!")
            return []
        }
        
        print("🏈 WILD CARD TEAMS (Seeds 5-7) - NEVER ranked above division winners:")
        for (index, wildCard) in wildCardTeams.enumerated() {
            let record = getTeamRecord(for: wildCard.logoName)
            print("   SEED #\(index + 5): \(wildCard.name) (\(record.wins)-\(record.losses)-\(record.ties)) - Wild Card")
        }
        
        // STEP 4: Combine according to NFL rules
        let playoffTeams = divisionWinners + wildCardTeams
        
        // FINAL VALIDATION: Ensure no division has 2 teams in top 4
        let topFourDivisions = Set(divisionWinners.map { $0.division })
        guard topFourDivisions.count == 4 else {
            print("❌ ERROR: Top 4 seeds contain duplicate divisions!")
            print("❌ Division winners: \(divisionWinners.map { "\($0.name) (\($0.division))" })")
            print("❌ This violates NFL rule: No two teams from same division in top 4!")
            return []
        }
        
        // FINAL VALIDATION: Ensure all 7 playoff teams are from different scenarios
        let playoffTeamsByDivision = Dictionary(grouping: playoffTeams) { $0.division }
        for (division, teams) in playoffTeamsByDivision {
            if teams.count > 2 {
                print("⚠️ WARNING: \(division) has \(teams.count) playoff teams: \(teams.map { $0.name })")
            }
        }
        
        print("🏈 ✅ FINAL PLAYOFF SEEDING (NFL Rules Enforced):")
        for (index, team) in playoffTeams.enumerated() {
            let record = getTeamRecord(for: team.logoName)
            let seedType = index < 4 ? "DIVISION WINNER" : "WILD CARD"
            let seedRank = index + 1
            print("   #\(seedRank): \(team.name) (\(record.wins)-\(record.losses)-\(record.ties)) - \(seedType)")
        }
        print("🏈 === END NFL PLAYOFF SEEDING ===")
        
        return playoffTeams
    }
    
    public func compareTeamRecords(team1: LeagueTeam, team2: LeagueTeam) -> Bool {
        let record1 = getTeamRecord(for: team1.logoName)
        let record2 = getTeamRecord(for: team2.logoName)
        
        // First compare win percentage (ties count as 0.5 wins)
        let winPct1 = calculateWinPercentage(wins: record1.wins, losses: record1.losses, ties: record1.ties)
        let winPct2 = calculateWinPercentage(wins: record2.wins, losses: record2.losses, ties: record2.ties)
        
        if winPct1 != winPct2 {
            return winPct1 > winPct2
        }
        
        // If teams are from same division, apply division tiebreakers
        if team1.division == team2.division {
            return applyDivisionTiebreakers(team1: team1, team2: team2)
        }
        
        // If teams are from different divisions but same conference, apply conference/wild card tiebreakers
        if team1.conference == team2.conference {
            return applyConferenceTiebreakers(team1: team1, team2: team2)
        }
        
        // If teams are from different conferences, use basic tiebreakers
        return applyBasicTiebreakers(team1: team1, team2: team2)
    }

    private func calculateWinPercentage(wins: Int, losses: Int, ties: Int) -> Double {
        let totalGames = Double(wins + losses + ties)
        guard totalGames > 0 else { return 0.0 }
        // NFL rule: ties count as half win and half loss
        return Double(wins) + (Double(ties) * 0.5) / totalGames
    }

    private func applyDivisionTiebreakers(team1: LeagueTeam, team2: LeagueTeam) -> Bool {
        // NFL Division Tiebreakers (Two Clubs)
        
        // 1. Head-to-head (best won-lost-tied percentage in games between the clubs)
        let headToHead = getHeadToHeadRecord(team1: team1, team2: team2)
        if headToHead.winner != nil {
            return headToHead.winner?.logoName == team1.logoName
        }
        
        // 2. Best won-lost-tied percentage in games played within the division
        let divRecord1 = getDivisionRecord(for: team1)
        let divRecord2 = getDivisionRecord(for: team2)
        let divWinPct1 = calculateWinPercentage(wins: divRecord1.wins, losses: divRecord1.losses, ties: divRecord1.ties)
        let divWinPct2 = calculateWinPercentage(wins: divRecord2.wins, losses: divRecord2.losses, ties: divRecord2.ties)
        
        if divWinPct1 != divWinPct2 {
            return divWinPct1 > divWinPct2
        }
        
        // 3. Best won-lost-tied percentage in common games
        let commonGames = getCommonGamesRecord(team1: team1, team2: team2)
        if commonGames.team1WinPercentage != commonGames.team2WinPercentage {
            return commonGames.team1WinPercentage > commonGames.team2WinPercentage
        }
        
        // 4. Best won-lost-tied percentage in games played within the conference
        let confRecord1 = getConferenceRecord(for: team1)
        let confRecord2 = getConferenceRecord(for: team2)
        let confWinPct1 = calculateWinPercentage(wins: confRecord1.wins, losses: confRecord1.losses, ties: confRecord1.ties)
        let confWinPct2 = calculateWinPercentage(wins: confRecord2.wins, losses: confRecord2.losses, ties: confRecord2.ties)
        
        if confWinPct1 != confWinPct2 {
            return confWinPct1 > confWinPct2
        }
        
        // 5. Strength of victory
        let sov1 = calculateStrengthOfVictory(for: team1)
        let sov2 = calculateStrengthOfVictory(for: team2)
        
        if sov1 != sov2 {
            return sov1 > sov2
        }
        
        // 6. Strength of schedule
        let sos1 = calculateStrengthOfSchedule(for: team1)
        let sos2 = calculateStrengthOfSchedule(for: team2)
        
        if sos1 != sos2 {
            return sos1 > sos2
        }
        
        // 7. Best combined ranking among conference teams in points scored and points allowed
        let confRanking1 = calculateConferencePointsRanking(for: team1)
        let confRanking2 = calculateConferencePointsRanking(for: team2)
        
        if confRanking1 != confRanking2 {
            return confRanking1 < confRanking2  // Lower combined ranking is better
        }
        
        // 8. Best combined ranking among all teams in points scored and points allowed
        let overallRanking1 = calculateOverallPointsRanking(for: team1)
        let overallRanking2 = calculateOverallPointsRanking(for: team2)
        
        if overallRanking1 != overallRanking2 {
            return overallRanking1 < overallRanking2  // Lower combined ranking is better
        }
        
        // 9. Best net points in common games
        let commonNetPoints1 = calculateNetPointsInCommonGames(team1: team1, team2: team2)
        let commonNetPoints2 = calculateNetPointsInCommonGames(team1: team2, team2: team1)
        
        if commonNetPoints1 != commonNetPoints2 {
            return commonNetPoints1 > commonNetPoints2
        }
        
        // 10. Best net points in all games
        let netPoints1 = calculateNetPoints(for: team1)
        let netPoints2 = calculateNetPoints(for: team2)
        
        if netPoints1 != netPoints2 {
            return netPoints1 > netPoints2
        }
        
        // 11. Best net touchdowns in all games
        let netTDs1 = calculateNetTouchdowns(for: team1)
        let netTDs2 = calculateNetTouchdowns(for: team2)
        
        if netTDs1 != netTDs2 {
            return netTDs1 > netTDs2
        }
        
        // 12. Coin toss (use team overall rating as deterministic substitute)
        return team1.overallRating > team2.overallRating
    }
    private func applyConferenceTiebreakers(team1: LeagueTeam, team2: LeagueTeam) -> Bool {
        // NFL Wild Card Tiebreakers (Two Clubs from different divisions)
        
        // 1. Head-to-head, if applicable
        let headToHead = getHeadToHeadRecord(team1: team1, team2: team2)
        if headToHead.gamesPlayed > 0 && headToHead.winner != nil {
            return headToHead.winner?.logoName == team1.logoName
        }
        
        // 2. Best won-lost-tied percentage in games played within the conference
        let confRecord1 = getConferenceRecord(for: team1)
        let confRecord2 = getConferenceRecord(for: team2)
        let confWinPct1 = calculateWinPercentage(wins: confRecord1.wins, losses: confRecord1.losses, ties: confRecord1.ties)
        let confWinPct2 = calculateWinPercentage(wins: confRecord2.wins, losses: confRecord2.losses, ties: confRecord2.ties)
        
        if confWinPct1 != confWinPct2 {
            return confWinPct1 > confWinPct2
        }
        
        // 3. Best won-lost-tied percentage in common games, minimum of four
        let commonGames = getCommonGamesRecord(team1: team1, team2: team2)
        if commonGames.totalGames >= 4 && commonGames.team1WinPercentage != commonGames.team2WinPercentage {
            return commonGames.team1WinPercentage > commonGames.team2WinPercentage
        }
        
        // 4. Strength of victory
        let sov1 = calculateStrengthOfVictory(for: team1)
        let sov2 = calculateStrengthOfVictory(for: team2)
        
        if sov1 != sov2 {
            return sov1 > sov2
        }
        
        // 5. Strength of schedule
        let sos1 = calculateStrengthOfSchedule(for: team1)
        let sos2 = calculateStrengthOfSchedule(for: team2)
        
        if sos1 != sos2 {
            return sos1 > sos2
        }
        
        // 6. Best combined ranking among conference teams in points scored and points allowed
        let confRanking1 = calculateConferencePointsRanking(for: team1)
        let confRanking2 = calculateConferencePointsRanking(for: team2)
        
        if confRanking1 != confRanking2 {
            return confRanking1 < confRanking2  // Lower combined ranking is better
        }
        
        // 7. Best combined ranking among all teams in points scored and points allowed
        let overallRanking1 = calculateOverallPointsRanking(for: team1)
        let overallRanking2 = calculateOverallPointsRanking(for: team2)
        
        if overallRanking1 != overallRanking2 {
            return overallRanking1 < overallRanking2  // Lower combined ranking is better
        }
        
        // 8. Best net points in conference games
        let confNetPoints1 = calculateNetPointsInConferenceGames(for: team1)
        let confNetPoints2 = calculateNetPointsInConferenceGames(for: team2)
        
        if confNetPoints1 != confNetPoints2 {
            return confNetPoints1 > confNetPoints2
        }
        
        // 9. Best net points in all games
        let netPoints1 = calculateNetPoints(for: team1)
        let netPoints2 = calculateNetPoints(for: team2)
        
        if netPoints1 != netPoints2 {
            return netPoints1 > netPoints2
        }
        
        // 10. Best net touchdowns in all games
        let netTDs1 = calculateNetTouchdowns(for: team1)
        let netTDs2 = calculateNetTouchdowns(for: team2)
        
        if netTDs1 != netTDs2 {
            return netTDs1 > netTDs2
        }
        
        // 11. Coin toss (use team overall rating as deterministic substitute)
        return team1.overallRating > team2.overallRating
    }

    private func applyBasicTiebreakers(team1: LeagueTeam, team2: LeagueTeam) -> Bool {
        // For teams from different conferences, use simplified tiebreakers
        
        // 1. Strength of victory
        let sov1 = calculateStrengthOfVictory(for: team1)
        let sov2 = calculateStrengthOfVictory(for: team2)
        
        if sov1 != sov2 {
            return sov1 > sov2
        }
        
        // 2. Strength of schedule
        let sos1 = calculateStrengthOfSchedule(for: team1)
        let sos2 = calculateStrengthOfSchedule(for: team2)
        
        if sos1 != sos2 {
            return sos1 > sos2
        }
        
        // 3. Net points
        let netPoints1 = calculateNetPoints(for: team1)
        let netPoints2 = calculateNetPoints(for: team2)
        
        if netPoints1 != netPoints2 {
            return netPoints1 > netPoints2
        }
        
        // Final tiebreaker: team overall rating
        return team1.overallRating > team2.overallRating
    }

    // Helper struct for head-to-head records
    private struct HeadToHeadResult {
        let winner: LeagueTeam?
        let gamesPlayed: Int
    }

    // Helper struct for common games records
    struct CommonGamesResult {
        let team1Record: (wins: Int, losses: Int, ties: Int)
        let team2Record: (wins: Int, losses: Int, ties: Int)
        let team1WinPercentage: Double
        let team2WinPercentage: Double
        let totalGames: Int
    }

    private func getHeadToHeadRecord(team1: LeagueTeam, team2: LeagueTeam) -> HeadToHeadResult {
        var team1Wins = 0
        var team2Wins = 0
        var ties = 0
        var gamesPlayed = 0
        
        let allGames = completedGames + upcomingGames.filter { $0.isCompleted }
        for game in allGames {
            if (game.homeTeam.logoName == team1.logoName && game.awayTeam.logoName == team2.logoName) ||
               (game.homeTeam.logoName == team2.logoName && game.awayTeam.logoName == team1.logoName) {
                gamesPlayed += 1
                if game.winningTeam?.logoName == team1.logoName {
                    team1Wins += 1
                } else if game.winningTeam?.logoName == team2.logoName {
                    team2Wins += 1
                } else {
                    ties += 1  // Handle ties properly
                }
            }
        }
        
        // Calculate head-to-head win percentage including ties
        if gamesPlayed > 0 {
            let team1WinPct = (Double(team1Wins) + Double(ties) * 0.5) / Double(gamesPlayed)
            let team2WinPct = (Double(team2Wins) + Double(ties) * 0.5) / Double(gamesPlayed)
            
            if team1WinPct > team2WinPct {
                return HeadToHeadResult(winner: team1, gamesPlayed: gamesPlayed)
            } else if team2WinPct > team1WinPct {
                return HeadToHeadResult(winner: team2, gamesPlayed: gamesPlayed)
            }
        }
        
        return HeadToHeadResult(winner: nil, gamesPlayed: gamesPlayed)
    }

    // MARK: - Record Calculation Methods
    func getDivisionRecord(for team: LeagueTeam) -> (wins: Int, losses: Int, ties: Int) {
        var wins = 0
        var losses = 0
        var ties = 0
        
        let allGames = completedGames + upcomingGames.filter { $0.isCompleted }
        for game in allGames {
            let opponent = game.homeTeam.logoName == team.logoName ? game.awayTeam : game.homeTeam
            if opponent.division == team.division {
                if game.winningTeam?.logoName == team.logoName {
                    wins += 1
                } else if game.winningTeam?.logoName == opponent.logoName {
                    losses += 1
                } else {
                    ties += 1
                }
            }
        }
        
        return (wins, losses, ties)
    }

    func getConferenceRecord(for team: LeagueTeam) -> (wins: Int, losses: Int, ties: Int) {
        var wins = 0
        var losses = 0
        var ties = 0
        
        let allGames = completedGames + upcomingGames.filter { $0.isCompleted }
        for game in allGames {
            let opponent = game.homeTeam.logoName == team.logoName ? game.awayTeam : game.homeTeam
            if opponent.conference == team.conference {
                if game.winningTeam?.logoName == team.logoName {
                    wins += 1
                } else if game.winningTeam?.logoName == opponent.logoName {
                    losses += 1
                } else {
                    ties += 1
                }
            }
        }
        
        return (wins, losses, ties)
    }

    func getCommonGamesRecord(team1: LeagueTeam, team2: LeagueTeam) -> CommonGamesResult {
        let allGames = completedGames + upcomingGames.filter { $0.isCompleted }
        
        // Get all opponents for both teams
        let team1Opponents = Set(allGames.compactMap { game in
            game.homeTeam.logoName == team1.logoName ? game.awayTeam.logoName : 
            game.awayTeam.logoName == team1.logoName ? game.homeTeam.logoName : nil
        })
        
        let team2Opponents = Set(allGames.compactMap { game in
            game.homeTeam.logoName == team2.logoName ? game.awayTeam.logoName :
            game.awayTeam.logoName == team2.logoName ? game.homeTeam.logoName : nil
        })
        
        // Find common opponents
        let commonOpponents = team1Opponents.intersection(team2Opponents)
        
        var team1Record = (wins: 0, losses: 0, ties: 0)
        var team2Record = (wins: 0, losses: 0, ties: 0)
        
        // Calculate records against common opponents
        for game in allGames {
            let isCommonGame = commonOpponents.contains(game.homeTeam.logoName) || commonOpponents.contains(game.awayTeam.logoName)
            
            if isCommonGame {
                if game.homeTeam.logoName == team1.logoName || game.awayTeam.logoName == team1.logoName {
                    let opponent = game.homeTeam.logoName == team1.logoName ? game.awayTeam : game.homeTeam
                    if commonOpponents.contains(opponent.logoName) {
                        if game.winningTeam?.logoName == team1.logoName {
                            team1Record.wins += 1
                        } else if game.winningTeam?.logoName == opponent.logoName {
                            team1Record.losses += 1
                        } else {
                            team1Record.ties += 1
                        }
                    }
                }
                
                if game.homeTeam.logoName == team2.logoName || game.awayTeam.logoName == team2.logoName {
                    let opponent = game.homeTeam.logoName == team2.logoName ? game.awayTeam : game.homeTeam
                    if commonOpponents.contains(opponent.logoName) {
                        if game.winningTeam?.logoName == team2.logoName {
                            team2Record.wins += 1
                        } else if game.winningTeam?.logoName == opponent.logoName {
                            team2Record.losses += 1
                        } else {
                            team2Record.ties += 1
                        }
                    }
                }
            }
        }
        
        let team1WinPct = calculateWinPercentage(wins: team1Record.wins, losses: team1Record.losses, ties: team1Record.ties)
        let team2WinPct = calculateWinPercentage(wins: team2Record.wins, losses: team2Record.losses, ties: team2Record.ties)
        let totalGames = team1Record.wins + team1Record.losses + team1Record.ties
        
        return CommonGamesResult(
            team1Record: team1Record,
            team2Record: team2Record,
            team1WinPercentage: team1WinPct,
            team2WinPercentage: team2WinPct,
            totalGames: totalGames
        )
    }

    private func calculateStrengthOfVictory(for team: LeagueTeam) -> Double {
        var totalOpponentWins = 0.0
        var totalOpponentGames = 0
        
        let allGames = completedGames + upcomingGames.filter { $0.isCompleted }
        
        // Get all teams this team has beaten
        let beatenTeams = allGames.compactMap { game -> LeagueTeam? in
            if game.winningTeam?.logoName == team.logoName {
                return game.homeTeam.logoName == team.logoName ? game.awayTeam : game.homeTeam
            }
            return nil
        }
        
        // Calculate combined win percentage of beaten teams (including ties as 0.5 wins)
        for opponent in beatenTeams {
            let record = getTeamRecord(for: opponent.logoName)
            totalOpponentWins += Double(record.wins) + (Double(record.ties) * 0.5)
            totalOpponentGames += record.wins + record.losses + record.ties
        }
        
        return totalOpponentGames > 0 ? totalOpponentWins / Double(totalOpponentGames) : 0.0
    }
    
    private func calculateStrengthOfSchedule(for team: LeagueTeam) -> Double {
        var totalOpponentWins = 0.0
        var totalOpponentGames = 0
        
        let allGames = completedGames + upcomingGames.filter { $0.isCompleted }
        
        // Get all opponents this team has played
        let opponents = allGames.compactMap { game -> LeagueTeam? in
            if game.homeTeam.logoName == team.logoName {
                return game.awayTeam
            } else if game.awayTeam.logoName == team.logoName {
                return game.homeTeam
            }
            return nil
        }
        
        // Calculate combined win percentage of all opponents (including ties as 0.5 wins)
        for opponent in opponents {
            let record = getTeamRecord(for: opponent.logoName)
            totalOpponentWins += Double(record.wins) + (Double(record.ties) * 0.5)
            totalOpponentGames += record.wins + record.losses + record.ties
        }
        
        return totalOpponentGames > 0 ? totalOpponentWins / Double(totalOpponentGames) : 0.0
    }
    
    private func calculateConferencePointsRanking(for team: LeagueTeam) -> Int {
        let conferenceTeams = allTeams.filter { $0.conference == team.conference }
        
        // Calculate points scored ranking
        let sortedByPointsScored = conferenceTeams.sorted { team1, team2 in
            let points1 = calculateTotalPointsScored(for: team1)
            let points2 = calculateTotalPointsScored(for: team2)
            return points1 > points2
        }
        
        let pointsScoredRank = (sortedByPointsScored.firstIndex(where: { $0.logoName == team.logoName }) ?? 0) + 1
        
        // Calculate points allowed ranking (lower is better, so reverse sort)
        let sortedByPointsAllowed = conferenceTeams.sorted { team1, team2 in
            let points1 = calculateTotalPointsAllowed(for: team1)
            let points2 = calculateTotalPointsAllowed(for: team2)
            return points1 < points2
        }
        
        let pointsAllowedRank = (sortedByPointsAllowed.firstIndex(where: { $0.logoName == team.logoName }) ?? 0) + 1
        
        return pointsScoredRank + pointsAllowedRank
    }
    
    private func calculateOverallPointsRanking(for team: LeagueTeam) -> Int {
        // Calculate points scored ranking among all teams
        let sortedByPointsScored = allTeams.sorted { team1, team2 in
            let points1 = calculateTotalPointsScored(for: team1)
            let points2 = calculateTotalPointsScored(for: team2)
            return points1 > points2
        }
        
        let pointsScoredRank = (sortedByPointsScored.firstIndex(where: { $0.logoName == team.logoName }) ?? 0) + 1
        
        // Calculate points allowed ranking among all teams (lower is better)
        let sortedByPointsAllowed = allTeams.sorted { team1, team2 in
            let points1 = calculateTotalPointsAllowed(for: team1)
            let points2 = calculateTotalPointsAllowed(for: team2)
            return points1 < points2
        }
        
        let pointsAllowedRank = (sortedByPointsAllowed.firstIndex(where: { $0.logoName == team.logoName }) ?? 0) + 1
        
        return pointsScoredRank + pointsAllowedRank
    }
    
    private func calculateNetPointsInCommonGames(team1: LeagueTeam, team2: LeagueTeam) -> Int {
        let allGames = completedGames + upcomingGames.filter { $0.isCompleted }
        
        // Get common opponents
        let team1Opponents = Set(allGames.compactMap { game in
            game.homeTeam.logoName == team1.logoName ? game.awayTeam.logoName : 
            game.awayTeam.logoName == team1.logoName ? game.homeTeam.logoName : nil
        })
        
        let team2Opponents = Set(allGames.compactMap { game in
            game.homeTeam.logoName == team2.logoName ? game.awayTeam.logoName :
            game.awayTeam.logoName == team2.logoName ? game.homeTeam.logoName : nil
        })
        
        let commonOpponents = team1Opponents.intersection(team2Opponents)
        
        var netPoints = 0
        
        // Calculate net points for team1 against common opponents
        for game in allGames {
            let isCommonGame = commonOpponents.contains(game.homeTeam.logoName) || commonOpponents.contains(game.awayTeam.logoName)
            
            if isCommonGame && (game.homeTeam.logoName == team1.logoName || game.awayTeam.logoName == team1.logoName) {
                let opponent = game.homeTeam.logoName == team1.logoName ? game.awayTeam : game.homeTeam
                if commonOpponents.contains(opponent.logoName) {
                    if game.homeTeam.logoName == team1.logoName {
                        netPoints += game.homeScore - game.awayScore
                    } else {
                        netPoints += game.awayScore - game.homeScore
                    }
                }
            }
        }
        
        return netPoints
    }
    
    private func calculateNetPointsInConferenceGames(for team: LeagueTeam) -> Int {
        let allGames = completedGames + upcomingGames.filter { $0.isCompleted }
        var netPoints = 0
        
        for game in allGames {
            if game.homeTeam.logoName == team.logoName {
                let opponent = game.awayTeam
                if opponent.conference == team.conference {
                    netPoints += game.homeScore - game.awayScore
                }
            } else if game.awayTeam.logoName == team.logoName {
                let opponent = game.homeTeam
                if opponent.conference == team.conference {
                    netPoints += game.awayScore - game.homeScore
                }
            }
        }
        
        return netPoints
    }
    
    private func calculateNetPoints(for team: LeagueTeam) -> Int {
        let allGames = completedGames + upcomingGames.filter { $0.isCompleted }
        var netPoints = 0
        
        for game in allGames {
            if game.homeTeam.logoName == team.logoName {
                netPoints += game.homeScore - game.awayScore
            } else if game.awayTeam.logoName == team.logoName {
                netPoints += game.awayScore - game.homeScore
            }
        }
        
        return netPoints
    }
    
    private func calculateNetTouchdowns(for team: LeagueTeam) -> Int {
        // This would need access to detailed game stats to calculate actual touchdowns
        // For now, estimate based on points (assuming ~7 points per TD on average)
        let netPoints = calculateNetPoints(for: team)
        return netPoints / 7  // Rough approximation
    }
    
    private func calculateTotalPointsScored(for team: LeagueTeam) -> Int {
        let allGames = completedGames + upcomingGames.filter { $0.isCompleted }
        var totalPoints = 0
        
        for game in allGames {
            if game.homeTeam.logoName == team.logoName {
                totalPoints += game.homeScore
            } else if game.awayTeam.logoName == team.logoName {
                totalPoints += game.awayScore
            }
        }
        
        return totalPoints
    }
    
    private func calculateTotalPointsAllowed(for team: LeagueTeam) -> Int {
        let allGames = completedGames + upcomingGames.filter { $0.isCompleted }
        var totalPoints = 0
        
        for game in allGames {
            if game.homeTeam.logoName == team.logoName {
                totalPoints += game.awayScore
            } else if game.awayTeam.logoName == team.logoName {
                totalPoints += game.homeScore
            }
        }
        
        return totalPoints
    }
    
    func generatePlayoffBracket() {
        guard playoffTeams.count >= 14 else {
            print("❌ Cannot generate playoff bracket: Need 14 playoff teams, have \(playoffTeams.count)")
            return
        }
        
        // Split into conferences (first 7 are AFC, next 7 are NFC)
        let afcTeams = Array(playoffTeams.prefix(7))
        let nfcTeams = Array(playoffTeams.suffix(7))
        
        // Generate Wild Card bracket (bracket manager should already be reset by caller)
        let wildCardMatchups = bracketManager.generateWildCardBracket(afcTeams: afcTeams, nfcTeams: nfcTeams)
        
        // Add Wild Card games to upcoming games for week 19
        addPlayoffGamesToSchedule(matchups: wildCardMatchups)
        
        print("🏈 Generated complete playoff bracket structure using new bracket manager")
    }
    

    
    // Add playoff result using consolidated bracket manager (single source of truth)
    func addPlayoffResult(winner: LeagueTeam, loser: LeagueTeam, week: Int, homeScore: Int = 0, awayScore: Int = 0) {
        // Validate inputs
        guard validatePlayoffResult(winner: winner, loser: loser, week: week) else {
            print("❌ Invalid playoff result: \(winner.name) vs \(loser.name) week \(week)")
            return
        }
        
        // Add to bracket manager (single source of truth)
        let result = PlayoffBracketManager.PlayoffResult(
            winner: winner, 
            loser: loser, 
            week: week, 
            homeScore: homeScore, 
            awayScore: awayScore
        )
        bracketManager.addResult(result)
        
        let scoreText = (homeScore > 0 || awayScore > 0) ? " (\(homeScore)-\(awayScore))" : ""
        print("🏈 ✅ Added playoff result for week \(week): \(winner.name) defeated \(loser.name)\(scoreText)")
        print("🏈 ✅ Total bracket manager results for week \(week): \(bracketManager.getResults(for: week).count)")
        
        // Debug: Show all results by checking each week
        print("🏈 🔧 DEBUG: All bracket manager results:")
        for week in 19...22 {
            let weekResults = bracketManager.getResults(for: week)
            if !weekResults.isEmpty {
                print("   Week \(week): \(weekResults.count) results")
                for result in weekResults {
                    print("     \(result.winner.name) defeated \(result.loser.name)")
                }
            }
        }
        
        // CRITICAL: Check if this round is complete and generate next round's bracket
        checkAndGenerateNextRoundBracket(completedWeek: week)
        
        // Force UI update to reflect playoff progression
        objectWillChange.send()
    }
    
    // Check if a playoff round is complete and automatically generate the next round's bracket
    private func checkAndGenerateNextRoundBracket(completedWeek: Int) {
        print("🏈 🔧 Checking if week \(completedWeek) is complete to generate next round...")
        
        // Get the current results for this week
        let weekResults = bracketManager.getResults(for: completedWeek)
        
        // Determine expected number of games for this week
        let expectedGames: Int
        switch completedWeek {
        case 19: expectedGames = 6  // Wild Card: 3 AFC + 3 NFC
        case 20: expectedGames = 4  // Divisional: 2 AFC + 2 NFC  
        case 21: expectedGames = 2  // Conference: 1 AFC + 1 NFC
        case 22: expectedGames = 1  // Championship: 1 game (season complete)
        default: 
            print("🏈 🔧 Invalid playoff week: \(completedWeek)")
            return
        }
        
        print("🏈 🔧 Week \(completedWeek): \(weekResults.count)/\(expectedGames) games completed")
        
        // If the round is complete, generate the next round's bracket
        if weekResults.count >= expectedGames {
            let nextWeek = completedWeek + 1
            if nextWeek <= 22 {
                print("🏈 🔧 Week \(completedWeek) complete! Auto-generating bracket for week \(nextWeek)")
                generateNextRoundBracket(for: nextWeek)
                
                // CRITICAL: Set the current bracket to the new week's bracket
                bracketManager.setCurrentBracketToWeek(nextWeek)
                print("🏈 🔧 Updated current bracket to week \(nextWeek)")
                
                // Update current week to match
                currentWeek = nextWeek
                print("🏈 🔧 Advanced current week to \(nextWeek)")
            } else {
                print("🏈 🔧 Championship complete! Season over.")
            }
        } else {
            print("🏈 🔧 Week \(completedWeek) not yet complete, waiting for more results...")
        }
    }
    
    // Validate playoff result inputs
    private func validatePlayoffResult(winner: LeagueTeam, loser: LeagueTeam, week: Int) -> Bool {
        print("🏈 🔍 Validating playoff result: \(winner.name) defeats \(loser.name) in week \(week)")
        
        // Ensure week is valid playoff week
        guard week >= 19 && week <= 22 else { 
            print("❌ Invalid playoff week: \(week)")
            return false 
        }
        
        // Ensure teams are different
        guard winner.logoName != loser.logoName else { 
            print("❌ Winner and loser are same team: \(winner.logoName)")
            return false 
        }
        
        // Ensure both teams are in playoffs
        guard playoffTeams.contains(where: { $0.logoName == winner.logoName }),
              playoffTeams.contains(where: { $0.logoName == loser.logoName }) else { 
            print("❌ Team not in playoffs - Winner in playoffs: \(playoffTeams.contains(where: { $0.logoName == winner.logoName })), Loser in playoffs: \(playoffTeams.contains(where: { $0.logoName == loser.logoName }))")
            return false 
        }
        
        // Check for duplicate results first
        let existingResults = bracketManager.getResults(for: week)
        let isDuplicate = existingResults.contains { existing in
            (existing.winner.logoName == winner.logoName && existing.loser.logoName == loser.logoName) ||
            (existing.winner.logoName == loser.logoName && existing.loser.logoName == winner.logoName)
        }
        
        if isDuplicate {
            print("❌ Duplicate result: \(winner.name) vs \(loser.name) already recorded for week \(week)")
            return false
        }
        
        // Ensure loser wasn't already eliminated in previous rounds
        if week > 19 {
            for prevWeek in 19..<week {
                let prevResults = bracketManager.getResults(for: prevWeek)
                if prevResults.contains(where: { $0.loser.logoName == winner.logoName }) {
                    print("❌ Winner \(winner.name) was already eliminated in week \(prevWeek)")
                    return false
                }
                if prevResults.contains(where: { $0.loser.logoName == loser.logoName }) {
                    print("❌ Loser \(loser.name) was already eliminated in week \(prevWeek)")
                    return false
                }
            }
        }
        
        print("✅ Playoff result validation passed")
        return true
    }
    
    func generateNextRoundBracket(for week: Int) {
        print("🏈 Generating bracket for week \(week) using bracket manager")
        
        // Validate bracket generation conditions
        guard week >= 20 && week <= 22 else {
            print("❌ Invalid week for bracket generation: \(week)")
            return
        }
        
        // Split into conferences (first 7 are AFC, next 7 are NFC)
        let afcTeams = Array(playoffTeams.prefix(7))
        let nfcTeams = Array(playoffTeams.suffix(7))
        
        print("🏈 ACFT Teams: \(afcTeams.map { "\($0.logoName) (#\(afcTeams.firstIndex(of: $0)! + 1))" })")
        print("🏈 NCFT Teams: \(nfcTeams.map { "\($0.logoName) (#\(nfcTeams.firstIndex(of: $0)! + 1))" })")
        
        // Ensure we have results from the previous week
        let prevWeek = week - 1
        let prevWeekResults = bracketManager.getResults(for: prevWeek)
        guard !prevWeekResults.isEmpty else {
            print("❌ Cannot generate bracket for week \(week): No results from week \(prevWeek)")
            return
        }
        
        var matchups: [PlayoffBracketManager.PlayoffMatchup] = []
        
        switch week {
        case 20: // Divisional Round
            print("🏈 Generating Divisional Round bracket...")
            matchups = bracketManager.generateDivisionalBracket(afcTeams: afcTeams, nfcTeams: nfcTeams)
            
        case 21: // Conference Championships
            print("🏈 🔧 DEBUG: Attempting to generate Conference Championship bracket for week 21...")
            print("🏈 🔧 DEBUG: ACFT Teams: \(afcTeams.map { $0.name })")
            print("🏈 🔧 DEBUG: NCFT Teams: \(nfcTeams.map { $0.name })")
            matchups = bracketManager.generateConferenceBracket(afcTeams: afcTeams, nfcTeams: nfcTeams)
            print("🏈 🔧 DEBUG: Generated \(matchups.count) conference championship matchups")
            
        case 22: // Super Bowl
            print("🏈 Generating Super Bowl bracket...")
            matchups = bracketManager.generateSuperBowlBracket(afcTeams: afcTeams, nfcTeams: nfcTeams)
            
        default:
            print("❌ Invalid playoff week: \(week)")
            return
        }
        
        // Validate generated matchups
        guard !matchups.isEmpty else {
            print("❌ Failed to generate matchups for week \(week)")
            return
        }
        
        // Add games to schedule
        addPlayoffGamesToSchedule(matchups: matchups)
        
        print("🏈 Successfully generated bracket for week \(week) with \(matchups.count) games")
        
        // Force UI update
        objectWillChange.send()
    }
    
    // Validate generated playoff matchups
    private func validateGeneratedMatchups(_ matchups: [PlayoffBracketManager.PlayoffMatchup], for week: Int) -> Bool {
        // Check if matchups contain eliminated teams
        for matchup in matchups {
            if wasTeamEliminated(matchup.homeTeam) || wasTeamEliminated(matchup.awayTeam) {
                print("❌ Matchup contains eliminated team: \(matchup.homeTeam.name) vs \(matchup.awayTeam.name)")
                return false
            }
            
            // Ensure teams don't play themselves
            if matchup.homeTeam.logoName == matchup.awayTeam.logoName {
                print("❌ Team matched against itself: \(matchup.homeTeam.name)")
                return false
            }
        }
        
        // Check expected number of games per round
        let expectedGames: Int
        switch week {
        case 20: expectedGames = 4  // Divisional: 2 AFC + 2 NFC
        case 21: expectedGames = 2  // Conference: 1 AFC + 1 NFC  
        case 22: expectedGames = 1  // Super Bowl: 1 game
        default: return false
        }
        
        if matchups.count != expectedGames {
            print("❌ Wrong number of games for week \(week): expected \(expectedGames), got \(matchups.count)")
            return false
        }
        
        return true
    }
    
    // Check if a team was eliminated in previous rounds
    private func wasTeamEliminated(_ team: LeagueTeam, currentWeek: Int = 0) -> Bool {
        let checkWeek = currentWeek == 0 ? self.currentWeek : currentWeek
        print("🏈 🔍 Checking if \(team.name) was eliminated (current week: \(checkWeek))")
        let isEliminated = bracketManager.wasTeamEliminated(team, currentWeek: checkWeek)
        if isEliminated {
            print("   💀 \(team.name) was eliminated")
        } else {
            print("   ✅ \(team.name) was NOT eliminated")
        }
        return isEliminated
    }
    

    

    

    
    // Add playoff games from matchups to upcoming games
    private func addPlayoffGamesToSchedule(matchups: [PlayoffBracketManager.PlayoffMatchup]) {
        guard let firstMatchup = matchups.first else { return }
        let week = firstMatchup.week
        
        // Remove any existing games for this week (in case of regeneration)
        upcomingGames.removeAll { $0.week == week }
        
        // Add all matchup games to upcoming games
        for matchup in matchups {
            let game = GameResult(week: week, homeTeam: matchup.homeTeam, awayTeam: matchup.awayTeam)
            upcomingGames.append(game)
            print("🏈 Added playoff game to schedule: Week \(week) - \(matchup.homeTeam.name) vs \(matchup.awayTeam.name)")
        }
    }
    
    // Call this to set up playoffs
    func setupPlayoffs() {
        print("🏈 Setting up playoffs...")
        
        // CRITICAL: Sync user team record before determining playoffs
        syncUserTeamRecord()
        
        // Clear any previous playoff data in bracket manager BEFORE generating new bracket
        bracketManager.reset()
        
        determinePlayoffTeams()
        generatePlayoffBracket()
        
        print("🏈 Playoffs setup complete with \(playoffTeams.count) teams")
    }
    // MARK: - User Team Record Synchronization
    func syncUserTeamRecord() {
        guard let userTeam = userTeam else { 
            print("⚠️ No user team to sync record for")
            return 
        }
        
        // Find user team in allTeams array
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
        print("🔄 Synced user team record based on \(userGames.count) completed games")
        
        // Invalidate caches to ensure fresh calculations
        invalidatePerformanceCaches()
    }
    
    // Get playoff bracket information for UI
    func getPlayoffBracket() -> [(homeTeam: LeagueTeam, awayTeam: LeagueTeam)] {
        let currentBracket = bracketManager.getCurrentBracket()
        return currentBracket.map { (homeTeam: $0.homeTeam, awayTeam: $0.awayTeam) }
    }
    
    // Get user's playoff opponent and seeding info using new bracket manager
    func getUserPlayoffInfo() -> (opponent: LeagueTeam?, seed: Int, isHome: Bool)? {
        guard let userTeam = userTeam else { 
            print("❌ No user team found for playoff info")
            return nil 
        }
        
        print("🏈 Looking for playoff info for user team: \(userTeam.logoName)")
        
        // Find user team in playoff teams
        guard playoffTeams.first(where: { $0.logoName == userTeam.logoName }) != nil else {
            print("❌ User team \(userTeam.logoName) not found in playoff teams")
            return nil
        }
        
        // CRITICAL ELIMINATION CHECK: Check if user was eliminated in previous rounds
        if currentWeek > 19 {
            print("🏈 Checking if user was eliminated in previous rounds...")
            
            // Check all previous playoff weeks for user elimination
            for week in 19..<currentWeek {
                let weekResults = bracketManager.getResults(for: week)
                for result in weekResults {
                    if result.loser.logoName == userTeam.logoName {
                        print("💀 User team was eliminated in week \(week) by \(result.winner.name)")
                        return nil
                    }
                }
            }
            print("✅ User team survived all previous rounds")
        }
        
        // Determine user's seed by finding their position in playoff teams array
        let userSeed: Int
        if let afcIndex = playoffTeams.prefix(7).firstIndex(where: { $0.logoName == userTeam.logoName }) {
            userSeed = afcIndex + 1
        } else if playoffTeams.suffix(7).firstIndex(where: { $0.logoName == userTeam.logoName }) != nil {
            userSeed = Array(playoffTeams.suffix(7)).firstIndex(where: { $0.logoName == userTeam.logoName })! + 1
        } else {
            print("❌ Could not determine user seed")
            return nil
        }
        
        print("🏈 User team \(userTeam.logoName) is seed #\(userSeed)")
        
        // Check current bracket for user's matchup - use specific week bracket
        let currentBracket = bracketManager.getBracketForWeek(currentWeek)
        
        print("🏈 DEBUG: Current week: \(currentWeek), Current bracket has \(currentBracket.count) matchups")
        for (index, matchup) in currentBracket.enumerated() {
            print("   \(index + 1). \(matchup.homeTeam.logoName) vs \(matchup.awayTeam.logoName) (Week \(matchup.week))")
        }
        
        for matchup in currentBracket {
            if matchup.homeTeam.logoName == userTeam.logoName {
                print("🏈 User matchup: HOME vs \(matchup.awayTeam.name)")
                return (opponent: matchup.awayTeam, seed: userSeed, isHome: true)
            } else if matchup.awayTeam.logoName == userTeam.logoName {
                print("🏈 User matchup: AWAY vs \(matchup.homeTeam.name)")
                return (opponent: matchup.homeTeam, seed: userSeed, isHome: false)
            }
        }
        
        // If not in current bracket, check if user has a bye
        if currentWeek == 19 && (userSeed == 1 || userSeed == 2) {
            print("🏈 User has first round bye as #\(userSeed) seed")
            return (opponent: nil, seed: userSeed, isHome: true)
        }
        
        print("❌ User team in playoffs but no valid matchup found for week \(currentWeek)")
        print("🏈 Current bracket: \(currentBracket.map { "\($0.homeTeam.logoName) vs \($0.awayTeam.logoName)" }.joined(separator: ", "))")
        
        return nil
    }

    // MARK: - Performance Optimization Caches
    private var teamIndexCache: [String: Int] = [:]
    private var divisionTeamsCache: [String: [LeagueTeam]] = [:]
    private var sortedTeamsCache: [LeagueTeam] = []
    private var cacheInvalidated = true
    
    // Pre-computed indices for faster lookups
    private func buildPerformanceCaches() {
        guard cacheInvalidated else { return }
        
        // Build team index cache for O(1) lookups
        teamIndexCache.removeAll()
        for (index, team) in allTeams.enumerated() {
            teamIndexCache[team.logoName] = index
        }
        
        // Build division teams cache
        divisionTeamsCache.removeAll()
        let divisions = Set(allTeams.map { $0.division })
        for division in divisions {
            divisionTeamsCache[division] = allTeams.filter { $0.division == division }
        }
        
        // Build sorted teams cache
        sortedTeamsCache = allTeams.sorted { $0.overallRating > $1.overallRating }
        
        cacheInvalidated = false
        print("✅ Performance caches built - \(teamIndexCache.count) teams indexed")
    }
    
    private func invalidatePerformanceCaches() {
        cacheInvalidated = true
    }
    
    // Simulate all remaining playoff games for the current week
    func simulateRemainingPlayoffGames(for week: Int) {
        let remainingGames = upcomingGames.filter { $0.week == week && !$0.isCompleted }
        print("🎮 Simulating \(remainingGames.count) remaining games for week \(week)")
        
        for game in remainingGames {
            // Skip user's game - it should already be completed
            if game.homeTeam.logoName == userTeam?.logoName || game.awayTeam.logoName == userTeam?.logoName {
                continue
            }
            
            // Use the same simulation method as regular season for consistency
            let simulatedGame = simulateGameFast(game)
            updateGameResult(simulatedGame)
            
            // CRITICAL: Add playoff result for bracket progression
            let winner = simulatedGame.homeScore > simulatedGame.awayScore ? simulatedGame.homeTeam : simulatedGame.awayScore > simulatedGame.homeScore ? simulatedGame.awayTeam : simulatedGame.homeTeam
            let loser = winner.logoName == simulatedGame.homeTeam.logoName ? simulatedGame.awayTeam : simulatedGame.homeTeam
            
            addPlayoffResult(winner: winner, loser: loser, week: week, homeScore: simulatedGame.homeScore, awayScore: simulatedGame.awayScore)
            
            print("🎮 Simulated: \(simulatedGame.homeTeam.name) \(simulatedGame.homeScore) - \(simulatedGame.awayScore) \(simulatedGame.awayTeam.name)")
            print("🏈 Added playoff result: \(winner.name) defeated \(loser.name)")
        }
        
        // Force UI update after all games are processed
        objectWillChange.send()
    }
    
    // Check if all playoff games for a week are completed
    func areAllPlayoffGamesCompleted(for week: Int) -> Bool {
        let weekGames = upcomingGames.filter { $0.week == week }
        return weekGames.allSatisfy { $0.isCompleted }
    }
    
    // Get deterministic playoff seeding using proper NFL rules
    private func getDeterministicPlayoffSeeding() {
        print("🏈 Creating deterministic playoff seeding...")
        
        // Get teams by conference using proper enum system
        let afcTeams = allTeams.filter { $0.conference == Conference.afc.rawValue }
        let nfcTeams = allTeams.filter { $0.conference == Conference.nfc.rawValue }
        
        // Get playoff teams using proper NFL seeding
        let afcPlayoffTeams = getProperConferencePlayoffTeams(from: afcTeams)
        let nfcPlayoffTeams = getProperConferencePlayoffTeams(from: nfcTeams)
        
        // Combine both conferences - ACFT teams first (0-6), then NCFT teams (7-13)
        playoffTeams = afcPlayoffTeams + nfcPlayoffTeams
        
        print("🏈 Deterministic playoff seeding complete:")
        print("ACFT: \(afcPlayoffTeams.map { $0.name }.joined(separator: ", "))")
        print("NCFT: \(nfcPlayoffTeams.map { $0.name }.joined(separator: ", "))")
    }
    

    
    // MARK: - League Structure Enums
    enum Conference: String, CaseIterable {
        case afc = "ACFT"
        case nfc = "NCFT"
    }
    
    enum Division: String, CaseIterable {
        case afcEast = "ACFT East"
        case afcNorth = "ACFT North"
        case afcSouth = "ACFT South"
        case afcWest = "ACFT West"
        case nfcEast = "NCFT East"
        case nfcNorth = "NCFT North"
        case nfcSouth = "NCFT South"
        case nfcWest = "NCFT West"
        
        var conference: Conference {
            switch self {
            case .afcEast, .afcNorth, .afcSouth, .afcWest:
                return .afc
            case .nfcEast, .nfcNorth, .nfcSouth, .nfcWest:
                return .nfc
            }
        }
    }
    
    // MARK: - Team Structure
    private func getProperConference(for teamLogoName: String) -> Conference {
        switch teamLogoName {
        // ACFT Teams
        case "Buffalo", "Miami", "NewEngland", "NYA": return .afc
        case "Baltimore", "Cincinnati", "Cleveland", "Pittsburgh": return .afc
        case "Houston", "Indianapolis", "Jacksonville", "Tennessee": return .afc
        case "Denver", "KansasCity", "LasVegas", "LAA": return .afc
        // NCFT Teams  
        case "Dallas", "NYN", "Philadelphia", "Washington": return .nfc
        case "Chicago", "Detroit", "GreenBay", "Minnesota": return .nfc
        case "Atlanta", "Carolina", "NewOrleans", "TampaBay": return .nfc
        case "Arizona", "LAN", "SanFrancisco", "Seattle": return .nfc
        default: return .afc // Fallback
        }
    }
    
    private func getProperDivision(for teamLogoName: String) -> Division {
        switch teamLogoName {
        // ACFT East
        case "Buffalo", "Miami", "NewEngland", "NYA": return .afcEast
        // ACFT North
        case "Baltimore", "Cincinnati", "Cleveland", "Pittsburgh": return .afcNorth
        // ACFT South
        case "Houston", "Indianapolis", "Jacksonville", "Tennessee": return .afcSouth
        // ACFT West
        case "Denver", "KansasCity", "LasVegas", "LAA": return .afcWest
        // NCFT East
        case "Dallas", "NYN", "Philadelphia", "Washington": return .nfcEast
        // NCFT North
        case "Chicago", "Detroit", "GreenBay", "Minnesota": return .nfcNorth
        // NCFT South
        case "Atlanta", "Carolina", "NewOrleans", "TampaBay": return .nfcSouth
        // NCFT West
        case "Arizona", "LAN", "SanFrancisco", "Seattle": return .nfcWest
        default: return .afcEast // Fallback
        }
    }
    
    // MARK: - Playoff Bracket Manager
    public class PlayoffBracketManager {
        private var currentBracket: [PlayoffMatchup] = []
        private var bracketHistory: [Int: [PlayoffMatchup]] = [:]
        private var results: [Int: [PlayoffResult]] = [:]
        private var eliminatedTeamsCache: [String: Int] = [:] // Cache of eliminated teams and the week they were eliminated
        
        // Public methods to access bracket data
        public func getBracketForWeek(_ week: Int) -> [PlayoffMatchup] {
            return bracketHistory[week] ?? []
        }
        
        public func getCurrentBracket() -> [PlayoffMatchup] {
            return currentBracket
        }
        
        // Set the current bracket to a specific week's bracket
        public func setCurrentBracketToWeek(_ week: Int) {
            if let weekBracket = bracketHistory[week] {
                currentBracket = weekBracket
                print("🏈 Set current bracket to week \(week) with \(weekBracket.count) matchups")
            } else {
                print("❌ No bracket found for week \(week)")
            }
        }
        
        // Set the current bracket directly
        public func setCurrentBracket(_ bracket: [PlayoffMatchup]) {
            currentBracket = bracket
            print("🏈 Set current bracket with \(bracket.count) matchups")
        }
        
        // Set bracket history for a specific week
        public func setBracketHistory(week: Int, matchups: [PlayoffMatchup]) {
            bracketHistory[week] = matchups
            print("🏈 Set bracket history for week \(week) with \(matchups.count) matchups")
        }
        
        // Get all bracket history
        public func getBracketHistory() -> [Int: [PlayoffMatchup]] {
            return bracketHistory
        }
        
        // Get all results
        public func getAllResults() -> [Int: [PlayoffResult]] {
            return results
        }
        
        // Validate bracket for a specific week
        public func validateBracket(for week: Int, afcTeams: [LeagueTeam], nfcTeams: [LeagueTeam]) -> Bool {
            guard let bracket = bracketHistory[week] else {
                print("❌ No bracket found for week \(week)")
                return false
            }
            
            // Check expected number of games per round
            let expectedGames: Int
            switch week {
            case 19: expectedGames = 6  // Wild Card: 6 games
            case 20: expectedGames = 4  // Divisional: 4 games
            case 21: expectedGames = 2  // Conference: 2 games
            case 22: expectedGames = 1  // Super Bowl: 1 game
            default: return false
            }
            
            if bracket.count != expectedGames {
                print("❌ Wrong number of games for week \(week): expected \(expectedGames), got \(bracket.count)")
                return false
            }
            
            // Validate no team plays against itself
            for matchup in bracket {
                if matchup.homeTeam.logoName == matchup.awayTeam.logoName {
                    print("❌ Team matched against itself: \(matchup.homeTeam.name)")
                    return false
                }
            }
            
            return true
        }
        
        public struct PlayoffMatchup {
            public let homeTeam: LeagueTeam
            public let awayTeam: LeagueTeam
            public let week: Int
            public let round: PlayoffRound
            public let homeTeamSeed: Int
            public let awayTeamSeed: Int
        }
        
        struct PlayoffResult {
            let winner: LeagueTeam
            let loser: LeagueTeam
            let week: Int
            let homeScore: Int
            let awayScore: Int
        }
        
        public enum PlayoffRound: Int, CaseIterable {
            case wildCard = 19
            case divisional = 20
            case conference = 21
            case superBowl = 22
            
            var displayName: String {
                switch self {
                case .wildCard: return "Wild Card"
                case .divisional: return "Divisional"
                case .conference: return "Conference Championship"
                case .superBowl: return "Super Bowl"
                }
            }
            
            var gamesCount: Int {
                switch self {
                case .wildCard: return 6
                case .divisional: return 4
                case .conference: return 2
                case .superBowl: return 1
                }
            }
        }
        
        // Generate Wild Card bracket (Week 19)
        func generateWildCardBracket(afcTeams: [LeagueTeam], nfcTeams: [LeagueTeam]) -> [PlayoffMatchup] {
            guard afcTeams.count >= 7 && nfcTeams.count >= 7 else {
                print("❌ Invalid playoff teams count: AFC \(afcTeams.count), NFC \(nfcTeams.count)")
                return []
            }
            
            var matchups: [PlayoffMatchup] = []
            
            // AFC Wild Card: 2v7, 3v6, 4v5 (1 seed gets bye)
            matchups.append(PlayoffMatchup(
                homeTeam: afcTeams[1], awayTeam: afcTeams[6],
                week: 19, round: .wildCard, homeTeamSeed: 2, awayTeamSeed: 7
            ))
            matchups.append(PlayoffMatchup(
                homeTeam: afcTeams[2], awayTeam: afcTeams[5],
                week: 19, round: .wildCard, homeTeamSeed: 3, awayTeamSeed: 6
            ))
            matchups.append(PlayoffMatchup(
                homeTeam: afcTeams[3], awayTeam: afcTeams[4],
                week: 19, round: .wildCard, homeTeamSeed: 4, awayTeamSeed: 5
            ))
            
            // NFC Wild Card: 2v7, 3v6, 4v5 (1 seed gets bye)
            matchups.append(PlayoffMatchup(
                homeTeam: nfcTeams[1], awayTeam: nfcTeams[6],
                week: 19, round: .wildCard, homeTeamSeed: 2, awayTeamSeed: 7
            ))
            matchups.append(PlayoffMatchup(
                homeTeam: nfcTeams[2], awayTeam: nfcTeams[5],
                week: 19, round: .wildCard, homeTeamSeed: 3, awayTeamSeed: 6
            ))
            matchups.append(PlayoffMatchup(
                homeTeam: nfcTeams[3], awayTeam: nfcTeams[4],
                week: 19, round: .wildCard, homeTeamSeed: 4, awayTeamSeed: 5
            ))
            
            currentBracket = matchups
            bracketHistory[19] = matchups
            
            print("🏈 Generated Wild Card bracket:")
            for matchup in matchups {
                let conference = afcTeams.contains(where: { $0.logoName == matchup.homeTeam.logoName }) ? "AFC" : "NFC"
                print("   \(conference): #\(matchup.homeTeamSeed) \(matchup.homeTeam.name) vs #\(matchup.awayTeamSeed) \(matchup.awayTeam.name)")
            }
            
            return matchups
        }
        
        // Generate Divisional Round bracket (Week 20)
        func generateDivisionalBracket(afcTeams: [LeagueTeam], nfcTeams: [LeagueTeam]) -> [PlayoffMatchup] {
            let wildCardResults = results[19] ?? []
            guard wildCardResults.count >= 6 else {
                print("❌ Cannot generate divisional bracket: Need 6 wild card results, have \(wildCardResults.count)")
                return []
            }
            
            var matchups: [PlayoffMatchup] = []
            
            // Get ACFT and NCFT wild card winners
            let acftWinners = wildCardResults.compactMap { result -> LeagueTeam? in
                // Only count teams that won their specific Wild Card matchup AND were not #1 seed
                let isAcftTeam = afcTeams.contains { $0.logoName == result.winner.logoName }
                let isNotTopSeed = result.winner.logoName != afcTeams[0].logoName // #1 seed has bye
                return (isAcftTeam && isNotTopSeed) ? result.winner : nil
            }
            
            let ncftWinners = wildCardResults.compactMap { result -> LeagueTeam? in
                // Only count teams that won their specific Wild Card matchup AND were not #1 seed
                let isNcftTeam = nfcTeams.contains { $0.logoName == result.winner.logoName }
                let isNotTopSeed = result.winner.logoName != nfcTeams[0].logoName // #1 seed has bye
                return (isNcftTeam && isNotTopSeed) ? result.winner : nil
            }
            
            print("🏈 ACFT Wild Card Winners: \(acftWinners.map { $0.name })")
            print("🏈 NCFT Wild Card Winners: \(ncftWinners.map { $0.name })")
            
            // Validate we have exactly 3 winners from each conference
            guard acftWinners.count == 3 else {
                print("❌ Expected 3 ACFT Wild Card winners, got \(acftWinners.count)")
                return []
            }
            
            guard ncftWinners.count == 3 else {
                print("❌ Expected 3 NCFT Wild Card winners, got \(ncftWinners.count)")
                return []
            }
            
            // ACFT Divisional: #1 seed plays lowest remaining seed
            let acftTeam1 = afcTeams[0] // #1 seed
            
            // Sort wild card winners by seed (highest number = lowest seed)
            let sortedAcftWinners = acftWinners.sorted { winner1, winner2 in
                let seed1 = getOriginalSeed(winner1, in: afcTeams)
                let seed2 = getOriginalSeed(winner2, in: afcTeams)
                return seed1 > seed2 // Higher seed number = lower seed
            }
            
            print("🏈 ACFT Wild Card Winners (sorted by seed): \(sortedAcftWinners.map { "#\(getOriginalSeed($0, in: afcTeams)) \($0.name)" })")
            
            // #1 seed always plays lowest remaining seed
            matchups.append(PlayoffMatchup(
                homeTeam: acftTeam1,
                awayTeam: sortedAcftWinners[0], // Highest seed number = lowest seed
                week: 20,
                round: .divisional,
                homeTeamSeed: 1,
                awayTeamSeed: getOriginalSeed(sortedAcftWinners[0], in: afcTeams)
            ))
            
            // Find highest remaining seed for second matchup
            let remainingAcftWinners = Array(sortedAcftWinners.dropFirst())
            let highestRemainingAcftSeed = remainingAcftWinners.min { winner1, winner2 in
                let seed1 = getOriginalSeed(winner1, in: afcTeams)
                let seed2 = getOriginalSeed(winner2, in: afcTeams)
                return seed1 < seed2 // Lower seed number = higher seed
            }!
            
            // Highest remaining seed is home team
            matchups.append(PlayoffMatchup(
                homeTeam: highestRemainingAcftSeed,
                awayTeam: remainingAcftWinners.first { $0.logoName != highestRemainingAcftSeed.logoName }!,
                week: 20,
                round: .divisional,
                homeTeamSeed: getOriginalSeed(highestRemainingAcftSeed, in: afcTeams),
                awayTeamSeed: getOriginalSeed(remainingAcftWinners.first { $0.logoName != highestRemainingAcftSeed.logoName }!, in: afcTeams)
            ))
            
            // NCFT Divisional: Same logic as ACFT - #1 seed plays lowest remaining seed
            let ncftTeam1 = nfcTeams[0] // #1 seed
            
            // Sort wild card winners by seed (highest number = lowest seed)
            let sortedNcftWinners = ncftWinners.sorted { winner1, winner2 in
                let seed1 = getOriginalSeed(winner1, in: nfcTeams)
                let seed2 = getOriginalSeed(winner2, in: nfcTeams)
                return seed1 > seed2 // Higher seed number = lower seed
            }
            
            print("🏈 NCFT Wild Card Winners (sorted by seed): \(sortedNcftWinners.map { "#\(getOriginalSeed($0, in: nfcTeams)) \($0.name)" })")
            
            // #1 seed always plays lowest remaining seed
            matchups.append(PlayoffMatchup(
                homeTeam: ncftTeam1,
                awayTeam: sortedNcftWinners[0], // Highest seed number = lowest seed
                week: 20,
                round: .divisional,
                homeTeamSeed: 1,
                awayTeamSeed: getOriginalSeed(sortedNcftWinners[0], in: nfcTeams)
            ))
            
            // Find highest remaining seed for second matchup
            let remainingNcftWinners = Array(sortedNcftWinners.dropFirst())
            let highestRemainingNcftSeed = remainingNcftWinners.min { winner1, winner2 in
                let seed1 = getOriginalSeed(winner1, in: nfcTeams)
                let seed2 = getOriginalSeed(winner2, in: nfcTeams)
                return seed1 < seed2 // Lower seed number = higher seed
            }!
            
            // Highest remaining seed is home team
            matchups.append(PlayoffMatchup(
                homeTeam: highestRemainingNcftSeed,
                awayTeam: remainingNcftWinners.first { $0.logoName != highestRemainingNcftSeed.logoName }!,
                week: 20,
                round: .divisional,
                homeTeamSeed: getOriginalSeed(highestRemainingNcftSeed, in: nfcTeams),
                awayTeamSeed: getOriginalSeed(remainingNcftWinners.first { $0.logoName != highestRemainingNcftSeed.logoName }!, in: nfcTeams)
            ))
            
            currentBracket = matchups
            bracketHistory[20] = matchups
            
            print("🏈 Generated Divisional Round bracket:")
            for matchup in matchups {
                let conference = afcTeams.contains(where: { $0.logoName == matchup.homeTeam.logoName }) ? "ACFT" : "NCFT"
                print("   \(conference): #\(matchup.homeTeamSeed) \(matchup.homeTeam.name) vs #\(matchup.awayTeamSeed) \(matchup.awayTeam.name)")
            }
            
            return matchups
        }
        
        // Generate Conference Championship bracket (Week 21)
        func generateConferenceBracket(afcTeams: [LeagueTeam], nfcTeams: [LeagueTeam]) -> [PlayoffMatchup] {
            print("🏈 🔧 DEBUG: Generating Conference Championship bracket")
            let divisionalResults = results[20] ?? []
            print("🏈 🔧 DEBUG: Found \(divisionalResults.count) divisional results:")
            for result in divisionalResults {
                print("   \(result.winner.name) defeated \(result.loser.name)")
            }
            
            // Be more lenient - try to generate even with fewer results for viewing purposes
            if divisionalResults.count < 4 {
                print("⚠️ Only \(divisionalResults.count)/4 divisional results available - generating partial bracket for viewing")
                if divisionalResults.isEmpty {
                    print("❌ Cannot generate conference bracket: No divisional results available")
                    return []
                }
            }
            
            var matchups: [PlayoffMatchup] = []
            
            // Get AFC and NFC divisional winners
            let afcWinners = divisionalResults.filter { result in
                afcTeams.contains { $0.logoName == result.winner.logoName }
            }.map { $0.winner }
            
            let nfcWinners = divisionalResults.filter { result in
                nfcTeams.contains { $0.logoName == result.winner.logoName }
            }.map { $0.winner }
            
            // AFC Championship: Higher seed hosts
            if afcWinners.count >= 2 {
                let sortedAfcWinners = afcWinners.sorted { winner1, winner2 in
                    let seed1 = getOriginalSeed(winner1, in: afcTeams)
                    let seed2 = getOriginalSeed(winner2, in: afcTeams)
                    return seed1 < seed2 // Lower seed number = higher seed
                }
                
                matchups.append(PlayoffMatchup(
                    homeTeam: sortedAfcWinners[0], awayTeam: sortedAfcWinners[1],
                    week: 21, round: .conference,
                    homeTeamSeed: getOriginalSeed(sortedAfcWinners[0], in: afcTeams),
                    awayTeamSeed: getOriginalSeed(sortedAfcWinners[1], in: afcTeams)
                ))
            }
            
            // NFC Championship: Same logic
            if nfcWinners.count >= 2 {
                let sortedNfcWinners = nfcWinners.sorted { winner1, winner2 in
                    let seed1 = getOriginalSeed(winner1, in: nfcTeams)
                    let seed2 = getOriginalSeed(winner2, in: nfcTeams)
                    return seed1 < seed2 // Lower seed number = higher seed
                }
                
                matchups.append(PlayoffMatchup(
                    homeTeam: sortedNfcWinners[0], awayTeam: sortedNfcWinners[1],
                    week: 21, round: .conference,
                    homeTeamSeed: getOriginalSeed(sortedNfcWinners[0], in: nfcTeams),
                    awayTeamSeed: getOriginalSeed(sortedNfcWinners[1], in: nfcTeams)
                ))
            }
            
            currentBracket = matchups
            bracketHistory[21] = matchups
            
            print("🏈 Generated Conference Championship bracket:")
            for matchup in matchups {
                let conference = afcTeams.contains { $0.logoName == matchup.homeTeam.logoName } ? "AFC" : "NFC"
                print("   \(conference): #\(matchup.homeTeamSeed) \(matchup.homeTeam.name) vs #\(matchup.awayTeamSeed) \(matchup.awayTeam.name)")
            }
            
            return matchups
        }
        
        // Generate Super Bowl bracket (Week 22)
        func generateSuperBowlBracket(afcTeams: [LeagueTeam], nfcTeams: [LeagueTeam]) -> [PlayoffMatchup] {
            let conferenceResults = results[21] ?? []
            guard conferenceResults.count >= 2 else {
                print("❌ Cannot generate Super Bowl: Need 2 conference results, have \(conferenceResults.count)")
                return []
            }
            
            var matchups: [PlayoffMatchup] = []
            
            // Get AFC and NFC champions
            let afcChampion = conferenceResults.first { result in
                afcTeams.contains { $0.logoName == result.winner.logoName }
            }?.winner
            
            let nfcChampion = conferenceResults.first { result in
                nfcTeams.contains { $0.logoName == result.winner.logoName }
            }?.winner
            
            // Super Bowl: NFC champion hosts by convention
            if let afcChamp = afcChampion, let nfcChamp = nfcChampion {
                matchups.append(PlayoffMatchup(
                    homeTeam: nfcChamp, awayTeam: afcChamp,
                    week: 22, round: .superBowl,
                    homeTeamSeed: getOriginalSeed(nfcChamp, in: nfcTeams),
                    awayTeamSeed: getOriginalSeed(afcChamp, in: afcTeams)
                ))
                
                currentBracket = matchups
                bracketHistory[22] = matchups
                
                print("🏈 Generated Super Bowl: \(nfcChamp.name) vs \(afcChamp.name)")
            }
            
            return matchups
        }
        
        // Helper function to get original seed
        private func getOriginalSeed(_ team: LeagueTeam, in teams: [LeagueTeam]) -> Int {
            // Find the team's index in the original seeding array
            if let index = teams.firstIndex(where: { $0.logoName == team.logoName }) {
                return index + 1 // Convert to 1-based seed number
            }
            // If team not found in array (shouldn't happen), return a high seed number
            print("⚠️ Could not find seed for team: \(team.name)")
            return 99
        }
        
        // Add playoff result
        func addResult(_ result: PlayoffResult) {
            if results[result.week] == nil {
                results[result.week] = []
            }
            
            // Check for duplicate results before adding
            let existingResults = results[result.week] ?? []
            let isDuplicate = existingResults.contains { existing in
                existing.winner.logoName == result.winner.logoName &&
                existing.loser.logoName == result.loser.logoName &&
                existing.week == result.week
            }
            
            if isDuplicate {
                print("⚠️ Duplicate playoff result ignored: \(result.winner.name) defeated \(result.loser.name) in week \(result.week)")
                return
            }
            
            results[result.week]?.append(result)
            
            // Cache the eliminated team
            eliminatedTeamsCache[result.loser.logoName] = result.week
            
            print("🏈 Added playoff result: \(result.winner.name) defeated \(result.loser.name) in week \(result.week)")
        }
        
        // Get user's matchup info
        func getUserMatchup(userTeam: LeagueTeam) -> (opponent: LeagueTeam?, seed: Int, isHome: Bool, hasBye: Bool)? {
            // Find user in current bracket
            for matchup in currentBracket {
                if matchup.homeTeam.logoName == userTeam.logoName {
                    return (opponent: matchup.awayTeam, seed: matchup.homeTeamSeed, isHome: true, hasBye: false)
                } else if matchup.awayTeam.logoName == userTeam.logoName {
                    return (opponent: matchup.homeTeam, seed: matchup.awayTeamSeed, isHome: false, hasBye: false)
                }
            }
            
            // Check if user is #1 or #2 seed with bye (only in wild card round)
            if currentBracket.first?.round == .wildCard {
                // Determine user's seed in their conference
                let afcTeams = currentBracket.isEmpty ? [] : Array(currentBracket.prefix(3)).map { $0.homeTeam } + Array(currentBracket.prefix(3)).map { $0.awayTeam }
                let nfcTeams = currentBracket.isEmpty ? [] : Array(currentBracket.suffix(3)).map { $0.homeTeam } + Array(currentBracket.suffix(3)).map { $0.awayTeam }
                
                // Check if user is AFC #1 or #2 seed (not in wild card games)
                if !afcTeams.contains(where: { $0.logoName == userTeam.logoName }) {
                    // User is AFC #1 or #2 seed - has bye
                    return (opponent: nil, seed: 1, isHome: true, hasBye: true) // We'll determine actual seed later
                }
                
                // Check if user is NFC #1 or #2 seed (not in wild card games)
                if !nfcTeams.contains(where: { $0.logoName == userTeam.logoName }) {
                    // User is NFC #1 or #2 seed - has bye
                    return (opponent: nil, seed: 1, isHome: true, hasBye: true) // We'll determine actual seed later
                }
            }
            
            return nil
        }
        
        // Clear all data
        func reset() {
            currentBracket = []
            bracketHistory = [:]
            results = [:]
            eliminatedTeamsCache = [:]
        }
        
        // Get results for a specific week
        func getResults(for week: Int) -> [PlayoffResult] {
            return results[week] ?? []
        }
        // Check if a team was eliminated using cache
        func wasTeamEliminated(_ team: LeagueTeam, currentWeek: Int) -> Bool {
            if let eliminationWeek = eliminatedTeamsCache[team.logoName] {
                return eliminationWeek <= currentWeek // Changed from < to <= to include current week eliminations
            }
            
            // If not in cache, check results and cache the finding
            for week in 19...currentWeek { // Changed from ..<currentWeek to ...currentWeek to include current week
                let weekResults = results[week] ?? []
                for result in weekResults {
                    if result.loser.logoName == team.logoName {
                        eliminatedTeamsCache[team.logoName] = week
                        return true
                    }
                }
            }
            
            return false
        }
    }
    
    // MARK: - Playoff Data Management
    
    // Computed properties for persistence
    var bracketHistory: [Int: [BracketMatchup]] {
        var result: [Int: [BracketMatchup]] = [:]
        for (week, matchups) in bracketManager.getBracketHistory() {
            result[week] = matchups.map { matchup in
                BracketMatchup(
                    homeTeamLogoName: matchup.homeTeam.logoName,
                    awayTeamLogoName: matchup.awayTeam.logoName,
                    week: matchup.week,
                    round: matchup.round.rawValue,
                    homeTeamSeed: matchup.homeTeamSeed,
                    awayTeamSeed: matchup.awayTeamSeed
                )
            }
        }
        return result
    }
    
    var bracketResults: [Int: [BracketResult]] {
        var result: [Int: [BracketResult]] = [:]
        for (week, results) in bracketManager.getAllResults() {
            result[week] = results.map { playoffResult in
                BracketResult(
                    winnerLogoName: playoffResult.winner.logoName,
                    loserLogoName: playoffResult.loser.logoName,
                    week: playoffResult.week,
                    homeScore: playoffResult.homeScore,
                    awayScore: playoffResult.awayScore
                )
            }
        }
        return result
    }
    
    // Load playoff data from saved league
    func loadPlayoffData(from league: League) {
        print("🏈 Loading playoff data from saved league...")
        
        // Load playoff teams
        if let savedPlayoffTeamNames = league.playoffTeamLogoNames {
            playoffTeams = savedPlayoffTeamNames.compactMap { logoName in
                allTeams.first(where: { $0.logoName == logoName })
            }
            print("🏈 Loaded \(playoffTeams.count) playoff teams")
        }
        
        // Load bracket manager state (single source of truth)
        loadBracketManagerState(from: league)
        
        // Validate loaded data integrity
        validateLoadedPlayoffData()
        
        // Regenerate bracket if needed
        if !playoffTeams.isEmpty && bracketManager.getCurrentBracket().isEmpty && currentWeek >= 19 {
            print("🏈 Regenerating playoff bracket for week \(currentWeek)")
            generatePlayoffBracket()
            
            // If we're past the wild card round, generate the appropriate bracket
            if currentWeek >= 20 {
                generateNextRoundBracket(for: currentWeek)
            }
        }
    }
    
    // Validate loaded playoff data for consistency
    private func validateLoadedPlayoffData() {
        // Ensure all playoff teams are valid
        playoffTeams = playoffTeams.filter { team in
            allTeams.contains(where: { $0.logoName == team.logoName })
        }
        
        // Ensure we have the correct number of playoff teams
        if playoffTeams.count != 14 && !playoffTeams.isEmpty {
            print("⚠️ Loaded \(playoffTeams.count) playoff teams, expected 14")
        }
        
        print("🏈 ✅ Playoff data validation complete")
    }
    
    // NEW: Load bracket manager state from saved data
    private func loadBracketManagerState(from league: League) {
        print("🏈 Loading bracket manager state...")
        
        // Load bracket history
        if let savedBracketHistory = league.bracketHistory {
            for (week, matchups) in savedBracketHistory {
                let restoredMatchups = matchups.compactMap { bracketMatchup -> PlayoffBracketManager.PlayoffMatchup? in
                    guard let homeTeam = allTeams.first(where: { $0.logoName == bracketMatchup.homeTeamLogoName }),
                          let awayTeam = allTeams.first(where: { $0.logoName == bracketMatchup.awayTeamLogoName }),
                          let round = PlayoffBracketManager.PlayoffRound(rawValue: bracketMatchup.round) else {
                        print("⚠️ Failed to restore matchup: \(bracketMatchup.homeTeamLogoName) vs \(bracketMatchup.awayTeamLogoName)")
                        return nil
                    }
                    
                    return PlayoffBracketManager.PlayoffMatchup(
                        homeTeam: homeTeam,
                        awayTeam: awayTeam,
                        week: bracketMatchup.week,
                        round: round,
                        homeTeamSeed: bracketMatchup.homeTeamSeed,
                        awayTeamSeed: bracketMatchup.awayTeamSeed
                    )
                }
                
                if !restoredMatchups.isEmpty {
                    bracketManager.setBracketHistory(week: week, matchups: restoredMatchups)
                }
            }
            print("🏈 Loaded bracket history for \(savedBracketHistory.count) weeks")
        }
        
        // Load bracket results
        if let savedBracketResults = league.bracketResults {
            for (_, results) in savedBracketResults {
                let restoredResults = results.compactMap { bracketResult -> PlayoffBracketManager.PlayoffResult? in
                    guard let winner = allTeams.first(where: { $0.logoName == bracketResult.winnerLogoName }),
                          let loser = allTeams.first(where: { $0.logoName == bracketResult.loserLogoName }) else {
                        print("⚠️ Failed to restore result: \(bracketResult.winnerLogoName) defeated \(bracketResult.loserLogoName)")
                        return nil
                    }
                    
                    return PlayoffBracketManager.PlayoffResult(
                        winner: winner,
                        loser: loser,
                        week: bracketResult.week,
                        homeScore: bracketResult.homeScore,
                        awayScore: bracketResult.awayScore
                    )
                }
                
                for result in restoredResults {
                    bracketManager.addResult(result)
                }
            }
            print("🏈 Loaded bracket results for \(savedBracketResults.count) weeks")
        }
        
        // Data sync no longer needed with single source of truth
        
        // Set current bracket based on current week
        if currentWeek >= 19 && currentWeek <= 22 {
            let currentBracket = bracketManager.getBracketHistory()[currentWeek] ?? []
            bracketManager.setCurrentBracket(currentBracket)
            print("🏈 Set current bracket for week \(currentWeek) with \(currentBracket.count) matchups")
        }
        
        // Validate data integrity
        validatePlayoffDataIntegrity()
    }
    
    // REMOVED: syncLegacyResultsToBracketManager - no longer needed with single source of truth
    
    // Validate playoff data integrity after loading
    private func validatePlayoffDataIntegrity() {
        print("🏈 Validating playoff data integrity...")
        
        let bracketHistory = bracketManager.getBracketHistory()
        let bracketResults = bracketManager.getAllResults()
        
        // Check that all playoff teams are valid
        let invalidTeams = playoffTeams.filter { team in
            !allTeams.contains(where: { $0.logoName == team.logoName })
        }
        
        if !invalidTeams.isEmpty {
            print("⚠️ Found invalid playoff teams: \(invalidTeams.map { $0.logoName })")
        }
        
        // Check bracket consistency
        for (week, matchups) in bracketHistory {
            let results = bracketResults[week] ?? []
            
            if week < currentWeek && results.count < matchups.count {
                print("⚠️ Incomplete results for past week \(week): \(results.count)/\(matchups.count) games completed")
            }
        }
        
        // Validate no eliminated teams in future brackets
        for week in currentWeek...22 {
            if let matchups = bracketHistory[week] {
                for matchup in matchups {
                    if wasTeamEliminated(matchup.homeTeam) || wasTeamEliminated(matchup.awayTeam) {
                        print("⚠️ Future bracket contains eliminated team: week \(week)")
                    }
                }
            }
        }
        
        print("🏈 ✅ Playoff data integrity validation complete")
    }
    
    // Public method for UI to load fresh playoff opponent
    func loadFreshPlayoffOpponent(for week: Int) -> PlayoffOpponentResult {
        // First, ensure playoff bracket is properly set up
        if week == 19 && getPlayoffBracket().isEmpty {
            print("🏈 Playoff bracket empty, setting up playoffs")
            if userTeam != nil {
                syncUserTeamRecord()
            }
            setupPlayoffs()
        }
        
        // For weeks 20+, ensure the bracket for this week is generated
        if week >= 20 && week <= 22 {
            print("🏈 Ensuring bracket is generated for week \(week)")
            
            // Only generate next round if we have results from previous week
            let prevWeekResults = bracketManager.getResults(for: week - 1)
            if !prevWeekResults.isEmpty {
                generateNextRoundBracket(for: week)
            } else {
                print("⚠️ No results from week \(week - 1) yet - cannot generate next bracket")
            }
        }
        
        // Check if playoffs are over (after League Championship is completed)
        if week > 22 {
            return .seasonComplete
        }
        
        // FIXED: Don't return seasonComplete during week 22, only when trying to advance beyond it
        // The UI will handle showing "Season Complete" button after the championship game is played
        
        // If no user team, they can still watch playoffs
        guard let userTeamData = userTeam else {
            print("🏈 No user team - can still watch playoffs")
            return .userEliminated // They can still watch even without a team
        }
        
        // Convert TeamData to LeagueTeam
        guard let userLeagueTeam = allTeams.first(where: { $0.logoName == userTeamData.logoName }) else {
            print("🏈 User team not found in league - can still watch playoffs")
            return .userEliminated // They can still watch even if team not found
        }
        
        // Check if user was eliminated in a previous round
        if !bracketManager.getResults(for: week - 1).isEmpty && bracketManager.getResults(for: week - 1).contains(where: { $0.loser.logoName == userLeagueTeam.logoName }) {
            print("💀 User was eliminated in week \(week - 1) - but can still watch")
            return .userEliminated
        }
        
        // Get user's playoff info from fresh bracket data
        guard let playoffInfo = getUserPlayoffInfo() else {
            // User didn't make playoffs or was eliminated - they can still watch
            print("🏈 User didn't make playoffs or was eliminated - can still watch")
            return .userEliminated
        }
        
        // Handle byes
        if playoffInfo.opponent == nil && week == 19 {
            return .firstRoundBye(seed: playoffInfo.seed)
        }
        
        // Validate opponent
        guard let opponent = playoffInfo.opponent else {
            return .noOpponentFound
        }
        
        // Final validation: ensure opponent is different from user
        if opponent.logoName == userLeagueTeam.logoName {
            print("❌ CRITICAL: User matched against self - finding different opponent")
            return .invalidOpponent(reason: "User matched against self")
        }
        
        return .validOpponent(team: opponent, seed: playoffInfo.seed, isHome: playoffInfo.isHome)
    }
    
    // NEW: Debug method to test playoff data persistence
    func debugPlayoffDataPersistence() {
        print("🔍 DEBUG: Playoff Data Persistence Status")
        print("========================================")
        
        // Check playoff teams
        print("🏈 Playoff Teams (\(playoffTeams.count)):")
        for (index, team) in playoffTeams.enumerated() {
            print("  \(index + 1). \(team.name) (\(team.logoName)) - \(team.record.description)")
        }
        
        // REMOVED: Legacy playoff results (now using bracket manager only)
        
        // Check bracket manager state
        let bracketHistory = bracketManager.getBracketHistory()
        let bracketResults = bracketManager.getAllResults()
        
        print("\n🏈 Bracket Manager History:")
        for (week, matchups) in bracketHistory.sorted(by: { $0.key < $1.key }) {
            print("  Week \(week): \(matchups.count) matchups")
            for matchup in matchups {
                print("    #\(matchup.homeTeamSeed) \(matchup.homeTeam.name) vs #\(matchup.awayTeamSeed) \(matchup.awayTeam.name)")
            }
        }
        
        print("\n🏈 Bracket Manager Results:")
        for (week, results) in bracketResults.sorted(by: { $0.key < $1.key }) {
            print("  Week \(week): \(results.count) results")
            for result in results {
                print("    \(result.winner.name) defeated \(result.loser.name) \(result.homeScore)-\(result.awayScore)")
            }
        }
        
        // Check current bracket
        let currentBracket = bracketManager.getCurrentBracket()
        print("\n🏈 Current Bracket (Week \(currentWeek)): \(currentBracket.count) matchups")
        for matchup in currentBracket {
            print("  \(matchup.homeTeam.name) vs \(matchup.awayTeam.name)")
        }
        
        // Check data for persistence
        let persistentBracketHistory = bracketHistory
        let persistentBracketResults = bracketResults
        
        print("\n💾 Data Ready for Persistence:")
        print("  Bracket History: \(persistentBracketHistory.count) weeks")
        print("  Bracket Results: \(persistentBracketResults.count) weeks")
        print("  Playoff Teams: \(playoffTeams.count) teams")
        
        print("========================================")
    }

    // MARK: - Atomic Playoff Transition System
    
    // Process complete playoff round transition atomically (fixes same opponent bug)
    func processPlayoffRoundTransition(from currentWeek: Int, to nextWeek: Int) -> PlayoffTransitionResult {
        print("🏈 🔄 Processing atomic playoff transition: Week \(currentWeek) → Week \(nextWeek)")
        
        // Step 0: Check if this is for an eliminated/non-playoff user
        // In this case, we just need to simulate games and return userEliminated status
        if let userTeamData = userTeam {
            let userLeagueTeam = allTeams.first(where: { $0.logoName == userTeamData.logoName })
            
            // Check if user didn't make playoffs or was eliminated
            if userLeagueTeam == nil || !playoffTeams.contains(where: { $0.logoName == userTeamData.logoName }) {
                print("🏈 User didn't make playoffs - they can continue watching")
                return .success(.userEliminated)
            }
            
            // Check if user was eliminated in a previous round
            if let userTeam = userLeagueTeam, bracketManager.wasTeamEliminated(userTeam, currentWeek: currentWeek) {
                print("💀 User was eliminated in previous round - they can continue watching")
                return .success(.userEliminated)
            }
        } else {
            print("🏈 No user team - they can continue watching playoffs")
            return .success(.userEliminated)
        }
        
        // Step 1: Validate transition
        guard validatePlayoffTransition(from: currentWeek, to: nextWeek) else {
            print("❌ Playoff transition validation failed")
            return .failure(.invalidTransition)
        }
        print("✅ Playoff transition validation passed")
        
        // Step 2: Check if user was eliminated in current round (but allow them to continue watching)
        if let userTeamData = userTeam,
           let userLeagueTeam = allTeams.first(where: { $0.logoName == userTeamData.logoName }) {
            print("🏈 🔍 Checking if user team \(userLeagueTeam.name) was eliminated...")
            
            // Only check elimination if we have results for the current week
            let currentWeekResults = bracketManager.getResults(for: currentWeek)
            if !currentWeekResults.isEmpty {
                // Check if user lost in current week
                if currentWeekResults.contains(where: { $0.loser.logoName == userLeagueTeam.logoName }) {
                    print("💀 User team eliminated in week \(currentWeek) - but they can continue watching")
                    // Don't return early - let them continue to Step 3 and beyond
                }
                
                // Check if user won in current week
                if !currentWeekResults.contains(where: { $0.winner.logoName == userLeagueTeam.logoName }) {
                    // User didn't play this week, check if they were eliminated in a previous week
                    if bracketManager.wasTeamEliminated(userLeagueTeam, currentWeek: currentWeek) {
                        print("💀 User team was eliminated in a previous week - but they can continue watching")
                        // Don't return early - let them continue to Step 3 and beyond
                    }
                }
            }
            print("✅ User team check complete - allowing advancement")
        } else {
            print("🏈 No user team found - they can still advance to watch playoffs")
            // Don't return an error - users without teams can still advance
        }
        
        // Step 3: Clear all cached opponent data
        clearPlayoffOpponentCache()
        
        // Step 4: Generate next round bracket
        if nextWeek <= 22 {
            // Check user status for bracket generation requirements
            let hasUserTeam = userTeam != nil && allTeams.contains(where: { $0.logoName == userTeam?.logoName })
            let userInPlayoffs = hasUserTeam && playoffTeams.contains(where: { $0.logoName == userTeam?.logoName })
            let userEliminated = hasUserTeam && userInPlayoffs && bracketManager.wasTeamEliminated(allTeams.first(where: { $0.logoName == userTeam?.logoName })!, currentWeek: currentWeek)
            let isWatchingUser = !hasUserTeam || !userInPlayoffs || userEliminated
            
            let currentWeekResults = bracketManager.getResults(for: currentWeek)
            
            // Be more lenient for watching users - generate brackets even with fewer results
            let shouldGenerate = !currentWeekResults.isEmpty || isWatchingUser
            
            if shouldGenerate {
                generateNextRoundBracket(for: nextWeek)
                // Set the current bracket to the new week
                bracketManager.setCurrentBracketToWeek(nextWeek)
                print("🏈 Generated bracket for week \(nextWeek) (watching mode: \(isWatchingUser))")
            } else {
                print("⚠️ No results for week \(currentWeek) yet - deferring bracket generation")
            }
        }
        
        // Step 5: Validate bracket was generated correctly
        guard validateCurrentBracket(for: nextWeek) else {
            return .failure(.bracketGenerationFailed)
        }
        
        // Step 6: Load fresh opponent data
        let opponentResult = loadFreshPlayoffOpponent(for: nextWeek)
        
        print("🏈 ✅ Atomic playoff transition complete")
        return .success(.advanced(opponentResult))
    }
    
    // Validate playoff transition is legal
    private func validatePlayoffTransition(from currentWeek: Int, to nextWeek: Int) -> Bool {
        // Ensure sequential weeks
        guard nextWeek == currentWeek + 1 else {
            print("❌ Non-sequential playoff transition: \(currentWeek) → \(nextWeek)")
            return false
        }
        
        // Ensure valid playoff weeks
        guard currentWeek >= 19 && nextWeek <= 22 else {
            print("❌ Invalid playoff week range: \(currentWeek) → \(nextWeek)")
            return false
        }
        
        // For playoff weeks, check if we have sufficient results instead of checking incomplete games
        // This handles bye weeks and other special cases properly
        if currentWeek >= 19 {
            let currentWeekResults = bracketManager.getResults(for: currentWeek)
            let expectedResults: Int
            
            switch currentWeek {
            case 19: expectedResults = 6  // Wild Card: 6 games
            case 20: expectedResults = 4  // Divisional: 4 games  
            case 21: expectedResults = 2  // Conference: 2 games
            case 22: expectedResults = 1  // Super Bowl: 1 game
            default: expectedResults = 0
            }
            
            // Be more lenient for eliminated/watching users - they should still be able to advance to see future brackets
            let hasUserTeam = userTeam != nil && allTeams.contains(where: { $0.logoName == userTeam?.logoName })
            let userInPlayoffs = hasUserTeam && playoffTeams.contains(where: { $0.logoName == userTeam?.logoName })
            let userEliminated = hasUserTeam && userInPlayoffs && bracketManager.wasTeamEliminated(allTeams.first(where: { $0.logoName == userTeam?.logoName })!, currentWeek: currentWeek)
            
            // If user is eliminated or not in playoffs, be more lenient about result requirements
            let isWatchingUser = !hasUserTeam || !userInPlayoffs || userEliminated
            
            if !isWatchingUser && currentWeekResults.count < expectedResults {
                print("❌ Cannot advance - insufficient playoff results for week \(currentWeek): \(currentWeekResults.count)/\(expectedResults)")
                return false
            } else if isWatchingUser && currentWeekResults.count == 0 {
                print("⚠️ No playoff results yet for week \(currentWeek), but user is watching - allowing advancement for viewing purposes")
            }
            
            print("✅ Playoff validation passed: \(currentWeekResults.count)/\(expectedResults) results for week \(currentWeek) (watching mode: \(isWatchingUser))")
        } else {
            // For regular season, check incomplete games as before
            let currentWeekGames = upcomingGames.filter { $0.week == currentWeek }
            let incompleteGames = currentWeekGames.filter { !$0.isCompleted }
            
            if !incompleteGames.isEmpty {
                print("❌ Cannot advance - \(incompleteGames.count) games incomplete in week \(currentWeek)")
                return false
            }
        }
        
        return true
    }
    
    // Clear all cached opponent data to prevent stale state
    private func clearPlayoffOpponentCache() {
        print("🏈 🗑️ Clearing playoff opponent cache")
        // This will be called by the UI layer to clear its cached data
        objectWillChange.send()
    }
    
    // Validate current bracket for given week
    private func validateCurrentBracket(for week: Int) -> Bool {
        let currentBracket = bracketManager.getCurrentBracket()
        
        // Check if bracket is empty for future weeks
        if week > 22 {
            return true // End of playoffs
        }
        
        // Check user status for bracket validation requirements
        let hasUserTeam = userTeam != nil && allTeams.contains(where: { $0.logoName == userTeam?.logoName })
        let userInPlayoffs = hasUserTeam && playoffTeams.contains(where: { $0.logoName == userTeam?.logoName })
        let userEliminated = hasUserTeam && userInPlayoffs && bracketManager.wasTeamEliminated(allTeams.first(where: { $0.logoName == userTeam?.logoName })!, currentWeek: week - 1)
        let isWatchingUser = !hasUserTeam || !userInPlayoffs || userEliminated
        
        // Be more lenient for watching users - allow empty brackets for future viewing
        if week <= 22 && currentBracket.isEmpty && !isWatchingUser {
            print("❌ Empty bracket for week \(week)")
            return false
        } else if week <= 22 && currentBracket.isEmpty && isWatchingUser {
            print("⚠️ Empty bracket for week \(week) but user is watching - allowing for viewing purposes")
            return true
        }
        
        // Split teams into conferences for validation
        let afcTeams = Array(playoffTeams.prefix(7))
        let nfcTeams = Array(playoffTeams.suffix(7))
        
        // Use improved bracket validation from bracket manager
        if !bracketManager.validateBracket(for: week, afcTeams: afcTeams, nfcTeams: nfcTeams) {
            return false
        }
        
        // Additional validation: no teams eliminated before the current week
        for matchup in currentBracket {
            if wasTeamEliminated(matchup.homeTeam, currentWeek: week - 1) || wasTeamEliminated(matchup.awayTeam, currentWeek: week - 1) {
                print("❌ Team eliminated before week \(week) in bracket: \(matchup.homeTeam.name) vs \(matchup.awayTeam.name)")
                return false
            }
        }
        
        return true
    }
    
    // REMOVED: Duplicate loadFreshPlayoffOpponent method - using public method instead

    // MARK: - Playoff Transition Result Types
    
    enum PlayoffTransitionResult {
        case success(PlayoffAdvancementResult)
        case failure(PlayoffTransitionError)
    }
    
    enum PlayoffAdvancementResult {
        case advanced(PlayoffOpponentResult)
        case userEliminated
    }
    
    enum PlayoffTransitionError {
        case invalidTransition
        case bracketGenerationFailed
        case incompleteGames
    }
    
    enum PlayoffOpponentResult {
        case validOpponent(team: LeagueTeam, seed: Int, isHome: Bool)
        case firstRoundBye(seed: Int)
        case userEliminated
        case seasonComplete
        case noOpponentFound
        case noUserTeam
        case invalidOpponent(reason: String)
    }
    
    // Public methods to access playoff bracket history
    func getPlayoffBracketForWeek(_ week: Int) -> [PlayoffBracketManager.PlayoffMatchup] {
        return bracketManager.getBracketForWeek(week)
    }

    /// Validates that all players from all teams have stats being tracked and reported properly
    func validateStatTracking() {
        print("🔍 ========== STAT TRACKING VALIDATION ==========")
        
        // Check overall stat counts
        let totalPlayerStats = playerSeasonStats.count
        let totalTeamStats = teamSeasonStats.count
        let totalGameStats = gamePlayerStats.count
        
        print("🔍 Total player season stats: \(totalPlayerStats)")
        print("🔍 Total team season stats: \(totalTeamStats)")
        print("🔍 Total game stats records: \(totalGameStats)")
        
        // Check completed games vs stats
        let completedGamesCount = completedGames.count
        print("🔍 Completed games: \(completedGamesCount)")
        
        // Validate team coverage
        print("\n🔍 TEAM STATS VALIDATION:")
        for team in allTeams {
            if let teamStats = teamSeasonStats[team.logoName] {
                print("✅ \(team.logoName): \(teamStats.gamesPlayed) games, \(teamStats.totalOffensiveYards) total yards")
            } else {
                print("❌ \(team.logoName): NO STATS FOUND")
            }
        }
        
        // Validate player coverage by team
        print("\n🔍 PLAYER STATS VALIDATION BY TEAM:")
        for team in allTeams {
            let teamPlayers = playerSeasonStats.values.filter { $0.teamLogoName == team.logoName }
            let playersWithStats = teamPlayers.filter { $0.gamesPlayed > 0 }
            print("🔍 \(team.logoName): \(teamPlayers.count) players, \(playersWithStats.count) with game stats")
            
            // Show top performers for this team
            let topPasser = teamPlayers.max { $0.passingYards < $1.passingYards }
            let topRusher = teamPlayers.max { $0.rushingYards < $1.rushingYards }
            let topReceiver = teamPlayers.max { $0.receivingYards < $1.receivingYards }
            let topTackler = teamPlayers.max { $0.tackles < $1.tackles }
            
            if let passer = topPasser, passer.passingYards > 0 {
                print("   📊 Top Passer: \(passer.playerName) - \(passer.passingYards) yards")
            }
            if let rusher = topRusher, rusher.rushingYards > 0 {
                print("   📊 Top Rusher: \(rusher.playerName) - \(rusher.rushingYards) yards")
            }
            if let receiver = topReceiver, receiver.receivingYards > 0 {
                print("   📊 Top Receiver: \(receiver.playerName) - \(receiver.receivingYards) yards")
            }
            if let tackler = topTackler, tackler.tackles > 0 {
                print("   📊 Top Tackler: \(tackler.playerName) - \(tackler.tackles) tackles")
            }
        }
        
        // Validate game-by-game stat accumulation
        print("\n🔍 GAME STATS VALIDATION:")
        for (gameId, gameStats) in gamePlayerStats {
            if let game = completedGames.first(where: { $0.id == gameId }) {
                print("✅ Game: \(game.awayTeam.name) @ \(game.homeTeam.name) - \(gameStats.count) player stats recorded")
            } else {
                print("⚠️ Game ID \(gameId): Found stats but no matching completed game")
            }
        }
        
        // Check for missing game stats
        for game in completedGames {
            if gamePlayerStats[game.id] == nil {
                print("❌ Missing stats for game: \(game.awayTeam.name) @ \(game.homeTeam.name)")
            }
        }
        
        // Statistical validation - check for realistic ranges
        validateStatisticalRanges()
        
        print("🔍 ========== VALIDATION COMPLETE ==========\n")
    }
    
    /// Forces a complete refresh of all stat displays and UI components
    func refreshAllStatDisplays() {
        // Force UI refresh for all stat-dependent views
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        // Log current stat status for debugging
        if !isBatchSimulating {
            let totalPlayerGames = playerSeasonStats.values.reduce(0) { $0 + $1.gamesPlayed }
            let totalTeamGames = teamSeasonStats.values.reduce(0) { $0 + $1.gamesPlayed }
            print("📊 Stats refresh: \(playerSeasonStats.count) players, \(totalPlayerGames) player-games, \(totalTeamGames) team-games")
        }
    }
    
    /// Ensures stats are properly saved after each game
    func ensureStatsAreSaved(for game: GameResult) {
        // Verify that game player stats were created and stored
        if gamePlayerStats[game.id] == nil {
            print("⚠️ No game player stats found for \(game.awayTeam.name) @ \(game.homeTeam.name), attempting recovery...")
            
            // Try to recover from global manager
            if let globalStats = GlobalGamePlayerStatsManager.shared.getGamePlayerStats(gameId: game.id) {
                gamePlayerStats[game.id] = globalStats
                print("✅ Recovered \(globalStats.count) player stats from global manager")
                
                // Re-accumulate these stats to season totals
                accumulateNaturalPlayerStats(for: game)
            } else {
                print("❌ Could not recover stats for game - stats may be missing")
            }
        }
        
        // Force refresh of all displays
        refreshAllStatDisplays()
    }

    /// Tests the complete stat tracking system by simulating a game and validating all stats
    func testStatTrackingSystem() {
        print("🧪 ========== TESTING STAT TRACKING SYSTEM ==========")
        
        // Pick two teams for testing
        guard allTeams.count >= 2 else {
            print("❌ Need at least 2 teams to test stat tracking")
            return
        }
        
        let homeTeam = allTeams[0]
        let awayTeam = allTeams[1]
        
        print("🧪 Testing with \(homeTeam.name) vs \(awayTeam.name)")
        
        // Create a test game
        let testGame = GameResult(week: 99, homeTeam: homeTeam, awayTeam: awayTeam) // Week 99 for testing
        
        // Simulate the game using advanced engine
        let simulatedResult = simulateGameAdvanced(testGame)
        
        print("🧪 Game simulated: \(simulatedResult.homeTeam.name) \(simulatedResult.homeScore) - \(simulatedResult.awayScore) \(simulatedResult.awayTeam.name)")
        
        // Validate that game player stats were created
        if let gameStats = gamePlayerStats[simulatedResult.id] {
            print("✅ Game stats created: \(gameStats.count) player stats")
            
            // Count stats by team
            let homeTeamStats = gameStats.filter { $0.teamLogoName == homeTeam.logoName }
            let awayTeamStats = gameStats.filter { $0.teamLogoName == awayTeam.logoName }
            
            print("📊 \(homeTeam.logoName): \(homeTeamStats.count) player stats")
            print("📊 \(awayTeam.logoName): \(awayTeamStats.count) player stats")
            
            // Show sample stats
            if let qbStats = gameStats.first(where: { $0.position == "QB" }) {
                print("📊 Sample QB: \(qbStats.playerName) - \(qbStats.passingYards) pass yds, \(qbStats.passingAttempts) attempts")
            }
            
            if let rbStats = gameStats.first(where: { $0.position == "RB" }) {
                print("📊 Sample RB: \(rbStats.playerName) - \(rbStats.rushingYards) rush yds, \(rbStats.rushingAttempts) attempts")
            }
            
            if let defStats = gameStats.first(where: { $0.tackles > 0 }) {
                print("📊 Sample Defender: \(defStats.playerName) - \(defStats.tackles) tackles, \(defStats.sacksMade) sacks")
            }
            
        } else {
            print("❌ No game stats found for simulated game!")
        }
        
        // Check if stats were accumulated to season totals
        let homeQBs = playerSeasonStats.values.filter { $0.teamLogoName == homeTeam.logoName && $0.position == "QB" }
        let awayQBs = playerSeasonStats.values.filter { $0.teamLogoName == awayTeam.logoName && $0.position == "QB" }
        
        if let homeQB = homeQBs.first {
            print("📊 \(homeTeam.logoName) QB season: \(homeQB.playerName) - \(homeQB.passingYards) yds, \(homeQB.gamesPlayed) games")
        }
        
        if let awayQB = awayQBs.first {
            print("📊 \(awayTeam.logoName) QB season: \(awayQB.playerName) - \(awayQB.passingYards) yds, \(awayQB.gamesPlayed) games")
        }
        
        // Clean up test game (remove it from completed games since it's just a test)
        if let index = completedGames.firstIndex(where: { $0.id == simulatedResult.id }) {
            completedGames.remove(at: index)
        }
        
        print("🧪 ========== STAT TRACKING TEST COMPLETE ==========\n")
    }
    
    // MARK: - Team Management
    
    func updateTeam(_ updatedTeam: LeagueTeam) {
        if let index = allTeams.firstIndex(where: { $0.logoName == updatedTeam.logoName }) {
            allTeams[index] = updatedTeam
            
            // If this is the user's team, update userTeam as well
            if updatedTeam.logoName == userTeam?.logoName {
                userTeam = updatedTeam
            }
        }
    }

    // MARK: - Team Creation Support
    func getConferenceForTeam(_ teamName: String) -> String {
        getProperConference(for: teamName).rawValue
    }

    func getDivisionForTeam(_ teamName: String) -> String {
        getProperDivision(for: teamName).rawValue
    }

    func getTeamOverall(players: [PlayerData]) -> Int {
        calculateTeamOverall(players: players, teamName: "")
    }
    func getCoachForTeam(_ teamName: String) -> Coach {
        generateCoachForTeam(teamName: teamName)
    }
    // Get projected playoff teams for a conference during regular season
    func getProjectedPlayoffTeams(conference: String) -> [LeagueTeam] {
        // Get all teams in the conference
        let conferenceTeams = allTeams.filter { $0.conference == conference }
        
        // Group teams by division
        let divisionTeams = Dictionary(grouping: conferenceTeams) { $0.division }
        var divisionWinners: [LeagueTeam] = []
        var wildCardCandidates: [LeagueTeam] = []
        
        // Get division winners
        for division in divisionTeams.keys.sorted() {
            guard let teams = divisionTeams[division] else { continue }
            let sortedDivisionTeams = teams.sorted { team1, team2 in
                compareTeamRecords(team1: team1, team2: team2)
            }
            if let winner = sortedDivisionTeams.first {
                divisionWinners.append(winner)
                wildCardCandidates.append(contentsOf: sortedDivisionTeams.dropFirst())
            }
        }
        
        // Sort division winners by record (seeds 1-4)
        divisionWinners.sort { team1, team2 in
            compareTeamRecords(team1: team1, team2: team2)
        }
        
        // Sort wild card candidates by record and take top 3 (seeds 5-7)
        wildCardCandidates.sort { team1, team2 in
            compareTeamRecords(team1: team1, team2: team2)
        }
        
        // Combine division winners and wild card teams
        let playoffTeams = divisionWinners + Array(wildCardCandidates.prefix(3))
        
        return playoffTeams
    }
    
    // MARK: - Season History Generation
    func generateSeasonHistory(seasonNumber: Int) -> SeasonHistory? {
        print("🏈 Generating season history for Season \(seasonNumber)...")
        
        // Try to extract complete playoff results first
        if let champions = extractChampionsFromPlayoffResults(),
           let statLeaders = generateComprehensiveStatLeaders(),
           let userInfo = getUserSeasonSummary() {
            
            print("✅ Complete season history with playoff results generated")
            return SeasonHistory(
                seasonYear: seasonNumber,
                completedDate: Date(),
                superBowlWinner: champions.leagueChampion,
                superBowlRunnerUp: champions.runnerUp,
                afcChampion: champions.afcChampion,
                nfcChampion: champions.nfcChampion,
                afcEast: champions.divisions["AFC East"] ?? "",
                afcNorth: champions.divisions["AFC North"] ?? "",
                afcSouth: champions.divisions["AFC South"] ?? "",
                afcWest: champions.divisions["AFC West"] ?? "",
                nfcEast: champions.divisions["NFC East"] ?? "",
                nfcNorth: champions.divisions["NFC North"] ?? "",
                nfcSouth: champions.divisions["NFC South"] ?? "",
                nfcWest: champions.divisions["NFC West"] ?? "",
                passingYardsLeader: statLeaders.passingYards,
                rushingYardsLeader: statLeaders.rushingYards,
                receivingYardsLeader: statLeaders.receivingYards,
                passingTouchdownsLeader: statLeaders.passingTouchdowns,
                rushingTouchdownsLeader: statLeaders.rushingTouchdowns,
                receivingTouchdownsLeader: statLeaders.receivingTouchdowns,
                tacklesLeader: statLeaders.tackles,
                sacksLeader: statLeaders.sacks,
                interceptionsLeader: statLeaders.interceptions,
                userTeamRecord: userInfo.record,
                userTeamFinalRank: userInfo.finalRank
            )
        }
        
        // Fallback: Generate basic season history without complete playoff data
        print("⚠️ Complete playoff data not available, generating basic season history...")
        if let basicHistory = generateBasicSeasonHistory(seasonNumber: seasonNumber) {
            return basicHistory
        }
        
        // Final fallback: Create minimal season history
        print("⚠️ Basic season history also failed, creating minimal season history...")
        return createMinimalSeasonHistory(seasonNumber: seasonNumber)
    }
    
    private func generateBasicSeasonHistory(seasonNumber: Int) -> SeasonHistory? {
        print("🏈 Generating basic season history for Season \(seasonNumber)...")
        
        // Debug: Check if we have basic data
        print("🔍 DEBUG Basic History: allTeams count = \(allTeams.count)")
        print("🔍 DEBUG Basic History: playerSeasonStats count = \(playerSeasonStats.count)")
        print("🔍 DEBUG Basic History: userTeam = \(userTeam?.name ?? "nil")")
        
        // Get user info (this should always work)
        guard let userInfo = getUserSeasonSummary() else {
            print("❌ Cannot get user season summary")
            return nil
        }
        
        print("✅ Got user season summary: \(userInfo.record.wins)-\(userInfo.record.losses)-\(userInfo.record.ties), rank \(userInfo.finalRank)")
        
        // Create fallback stat leaders
        let fallbackStatLeader = StatLeader(
            playerName: "Data Unavailable",
            teamLogoName: "unknown",
            position: "N/A",
            statValue: 0,
            statDescription: "N/A"
        )
        
        // Try to get at least some stat leaders if available
        let statLeaders = generateFallbackStatLeaders() ?? (
            passingYards: fallbackStatLeader,
            rushingYards: fallbackStatLeader,
            receivingYards: fallbackStatLeader,
            passingTouchdowns: fallbackStatLeader,
            rushingTouchdowns: fallbackStatLeader,
            receivingTouchdowns: fallbackStatLeader,
            tackles: fallbackStatLeader,
            sacks: fallbackStatLeader,
            interceptions: fallbackStatLeader
        )
        
        // Generate basic division winners from regular season standings
        let divisionChampions = generateBasicDivisionChampions()
        
        return SeasonHistory(
            seasonYear: seasonNumber,
            completedDate: Date(),
            superBowlWinner: divisionChampions["AFC East"] ?? "unknown", // Fallback
            superBowlRunnerUp: divisionChampions["NFC East"] ?? "unknown", // Fallback
            afcChampion: divisionChampions["AFC East"] ?? "unknown", // Fallback
            nfcChampion: divisionChampions["NFC East"] ?? "unknown", // Fallback
            afcEast: divisionChampions["AFC East"] ?? "unknown",
            afcNorth: divisionChampions["AFC North"] ?? "unknown",
            afcSouth: divisionChampions["AFC South"] ?? "unknown",
            afcWest: divisionChampions["AFC West"] ?? "unknown",
            nfcEast: divisionChampions["NFC East"] ?? "unknown",
            nfcNorth: divisionChampions["NFC North"] ?? "unknown",
            nfcSouth: divisionChampions["NFC South"] ?? "unknown",
            nfcWest: divisionChampions["NFC West"] ?? "unknown",
            passingYardsLeader: statLeaders.passingYards,
            rushingYardsLeader: statLeaders.rushingYards,
            receivingYardsLeader: statLeaders.receivingYards,
            passingTouchdownsLeader: statLeaders.passingTouchdowns,
            rushingTouchdownsLeader: statLeaders.rushingTouchdowns,
            receivingTouchdownsLeader: statLeaders.receivingTouchdowns,
            tacklesLeader: statLeaders.tackles,
            sacksLeader: statLeaders.sacks,
            interceptionsLeader: statLeaders.interceptions,
            userTeamRecord: userInfo.record,
            userTeamFinalRank: userInfo.finalRank
        )
    }
    
    private func generateFallbackStatLeaders() -> (passingYards: StatLeader, rushingYards: StatLeader, receivingYards: StatLeader, passingTouchdowns: StatLeader, rushingTouchdowns: StatLeader, receivingTouchdowns: StatLeader, tackles: StatLeader, sacks: StatLeader, interceptions: StatLeader)? {
        // Try to get stat leaders, but don't fail if some are missing
        guard !playerSeasonStats.isEmpty else {
            print("⚠️ No player stats available for fallback leaders")
            return nil
        }
        
        let fallbackStatLeader = StatLeader(
            playerName: "No Data",
            teamLogoName: "unknown",
            position: "N/A",
            statValue: 0,
            statDescription: "N/A"
        )
        
        // Get what stats we can, use fallback for missing ones
        let passingLeader = getLeagueLeaders(category: .passingYards, limit: 1).first
        let rushingLeader = getLeagueLeaders(category: .rushingYards, limit: 1).first
        let receivingLeader = getLeagueLeaders(category: .receivingYards, limit: 1).first
        let passingTDLeader = getLeagueLeaders(category: .passingTouchdowns, limit: 1).first
        let rushingTDLeader = getLeagueLeaders(category: .rushingTouchdowns, limit: 1).first
        let receivingTDLeader = getLeagueLeaders(category: .receivingTouchdowns, limit: 1).first
        let tacklesLeader = getLeagueLeaders(category: .tackles, limit: 1).first
        let sacksLeader = getLeagueLeaders(category: .sacks, limit: 1).first
        let interceptionsLeader = getLeagueLeaders(category: .interceptions, limit: 1).first
        
        return (
            passingYards: passingLeader.map { StatLeader(playerName: $0.playerName, teamLogoName: $0.teamLogoName, position: $0.position, statValue: $0.passingYards, statDescription: "\($0.passingYards) yards") } ?? fallbackStatLeader,
            rushingYards: rushingLeader.map { StatLeader(playerName: $0.playerName, teamLogoName: $0.teamLogoName, position: $0.position, statValue: $0.rushingYards, statDescription: "\($0.rushingYards) yards") } ?? fallbackStatLeader,
            receivingYards: receivingLeader.map { StatLeader(playerName: $0.playerName, teamLogoName: $0.teamLogoName, position: $0.position, statValue: $0.receivingYards, statDescription: "\($0.receivingYards) yards") } ?? fallbackStatLeader,
            passingTouchdowns: passingTDLeader.map { StatLeader(playerName: $0.playerName, teamLogoName: $0.teamLogoName, position: $0.position, statValue: $0.passingTouchdowns, statDescription: "\($0.passingTouchdowns) TDs") } ?? fallbackStatLeader,
            rushingTouchdowns: rushingTDLeader.map { StatLeader(playerName: $0.playerName, teamLogoName: $0.teamLogoName, position: $0.position, statValue: $0.rushingTouchdowns, statDescription: "\($0.rushingTouchdowns) TDs") } ?? fallbackStatLeader,
            receivingTouchdowns: receivingTDLeader.map { StatLeader(playerName: $0.playerName, teamLogoName: $0.teamLogoName, position: $0.position, statValue: $0.receivingTouchdowns, statDescription: "\($0.receivingTouchdowns) TDs") } ?? fallbackStatLeader,
            tackles: tacklesLeader.map { StatLeader(playerName: $0.playerName, teamLogoName: $0.teamLogoName, position: $0.position, statValue: $0.tackles, statDescription: "\($0.tackles) tackles") } ?? fallbackStatLeader,
            sacks: sacksLeader.map { StatLeader(playerName: $0.playerName, teamLogoName: $0.teamLogoName, position: $0.position, statValue: $0.sacksMade, statDescription: "\($0.sacksMade) sacks") } ?? fallbackStatLeader,
            interceptions: interceptionsLeader.map { StatLeader(playerName: $0.playerName, teamLogoName: $0.teamLogoName, position: $0.position, statValue: $0.interceptionsDefense, statDescription: "\($0.interceptionsDefense) INTs") } ?? fallbackStatLeader
        )
    }
    
    private func generateBasicDivisionChampions() -> [String: String] {
        var divisionChampions: [String: String] = [:]
        
        // Debug: Print all team divisions first
        print("🔍 DEBUG: All team divisions:")
        for team in allTeams.prefix(5) { // Just first 5 to avoid spam
            print("   \(team.name) (\(team.logoName)): '\(team.division)'")
        }
        
        // FIXED: Use correct division names that match the actual team data (ACFT/NCFT not AFC/NFC)
        let divisions = ["ACFT East", "ACFT North", "ACFT South", "ACFT West", 
                        "NCFT East", "NCFT North", "NCFT South", "NCFT West"]
        
        for division in divisions {
            let divisionTeams = allTeams.filter { $0.division == division }
            print("🔍 DEBUG: Found \(divisionTeams.count) teams in '\(division)'")
            
            if let winner = divisionTeams.max(by: { team1, team2 in
                compareTeamRecords(team1: team1, team2: team2)
            }) {
                // Map back to the expected keys for SeasonHistory compatibility
                let historyKey = division.replacingOccurrences(of: "ACFT", with: "AFC").replacingOccurrences(of: "NCFT", with: "NFC")
                divisionChampions[historyKey] = winner.logoName
                print("🏆 Division winner for \(division): \(winner.name) -> stored as \(historyKey)")
            } else {
                print("⚠️ No teams found for division: \(division)")
                // Use a fallback team for this division
                if let anyTeam = allTeams.first {
                    let historyKey = division.replacingOccurrences(of: "ACFT", with: "AFC").replacingOccurrences(of: "NCFT", with: "NFC")
                    divisionChampions[historyKey] = anyTeam.logoName
                    print("🔄 Using fallback team: \(anyTeam.name)")
                } else {
                    let historyKey = division.replacingOccurrences(of: "ACFT", with: "AFC").replacingOccurrences(of: "NCFT", with: "NFC")
                    divisionChampions[historyKey] = "unknown"
                }
            }
        }
        
        return divisionChampions
    }
    
    private func extractChampionsFromPlayoffResults() -> (leagueChampion: String, runnerUp: String, afcChampion: String, nfcChampion: String, divisions: [String: String])? {
        // Use existing bracketManager to safely extract champions
        let superBowlResults = bracketManager.getResults(for: 22)
        let conferenceResults = bracketManager.getResults(for: 21)
        
        guard let superBowl = superBowlResults.first else {
            print("❌ No Super Bowl result found")
            return nil
        }
        
        let afcChamp = conferenceResults.first { result in
            result.winner.conference.contains("ACFT")  // FIXED: Use correct conference name
        }?.winner.logoName ?? ""
        
        let nfcChamp = conferenceResults.first { result in
            result.winner.conference.contains("NCFT")  // FIXED: Use correct conference name
        }?.winner.logoName ?? ""
        
        // Extract division champions from playoff seeding (seeds 1-4 in each conference)
        let divisionChampions = extractDivisionChampionsFromSeeding()
        
        return (
            leagueChampion: superBowl.winner.logoName,
            runnerUp: superBowl.loser.logoName,
            afcChampion: afcChamp,
            nfcChampion: nfcChamp,
            divisions: divisionChampions
        )
    }
    
    private func extractDivisionChampionsFromSeeding() -> [String: String] {
        var divisionChampions: [String: String] = [:]
        
        // Seeds 1-4 in each conference are division winners
        let afcPlayoffTeams = getProjectedPlayoffTeams(conference: "ACFT")  // FIXED: Use correct conference name
        let nfcPlayoffTeams = getProjectedPlayoffTeams(conference: "NCFT")  // FIXED: Use correct conference name
        
        // ACFT Division Winners (top 4 seeds)
        if afcPlayoffTeams.count >= 4 {
            for i in 0..<4 {
                let team = afcPlayoffTeams[i]
                // Map division names to expected SeasonHistory format
                let historyKey = team.division.replacingOccurrences(of: "ACFT", with: "AFC").replacingOccurrences(of: "NCFT", with: "NFC")
                divisionChampions[historyKey] = team.logoName
                print("🏆 Playoff seeding: \(team.name) (\(team.division)) -> stored as \(historyKey)")
            }
        }
        
        // NCFT Division Winners (top 4 seeds)  
        if nfcPlayoffTeams.count >= 4 {
            for i in 0..<4 {
                let team = nfcPlayoffTeams[i]
                // Map division names to expected SeasonHistory format
                let historyKey = team.division.replacingOccurrences(of: "ACFT", with: "AFC").replacingOccurrences(of: "NCFT", with: "NFC")
                divisionChampions[historyKey] = team.logoName
                print("🏆 Playoff seeding: \(team.name) (\(team.division)) -> stored as \(historyKey)")
            }
        }
        
        return divisionChampions
    }
    
    private func generateComprehensiveStatLeaders() -> (passingYards: StatLeader, rushingYards: StatLeader, receivingYards: StatLeader, passingTouchdowns: StatLeader, rushingTouchdowns: StatLeader, receivingTouchdowns: StatLeader, tackles: StatLeader, sacks: StatLeader, interceptions: StatLeader)? {
        // Use existing getLeagueLeaders method
        let passingLeader = getLeagueLeaders(category: .passingYards, limit: 1).first
        let rushingLeader = getLeagueLeaders(category: .rushingYards, limit: 1).first
        let receivingLeader = getLeagueLeaders(category: .receivingYards, limit: 1).first
        let passingTDLeader = getLeagueLeaders(category: .passingTouchdowns, limit: 1).first
        let rushingTDLeader = getLeagueLeaders(category: .rushingTouchdowns, limit: 1).first
        let receivingTDLeader = getLeagueLeaders(category: .receivingTouchdowns, limit: 1).first
        let tacklesLeader = getLeagueLeaders(category: .tackles, limit: 1).first
        let sacksLeader = getLeagueLeaders(category: .sacks, limit: 1).first
        let interceptionsLeader = getLeagueLeaders(category: .interceptions, limit: 1).first
        
        guard let passer = passingLeader,
              let rusher = rushingLeader,
              let receiver = receivingLeader,
              let passingTD = passingTDLeader,
              let rushingTD = rushingTDLeader,
              let receivingTD = receivingTDLeader,
              let tackles = tacklesLeader,
              let sacks = sacksLeader,
              let interceptions = interceptionsLeader else {
            print("❌ Failed to find stat leaders")
            return nil
        }
        
        return (
            passingYards: StatLeader(playerName: passer.playerName, teamLogoName: passer.teamLogoName, position: passer.position, statValue: passer.passingYards, statDescription: "\(passer.passingYards) yards"),
            rushingYards: StatLeader(playerName: rusher.playerName, teamLogoName: rusher.teamLogoName, position: rusher.position, statValue: rusher.rushingYards, statDescription: "\(rusher.rushingYards) yards"),
            receivingYards: StatLeader(playerName: receiver.playerName, teamLogoName: receiver.teamLogoName, position: receiver.position, statValue: receiver.receivingYards, statDescription: "\(receiver.receivingYards) yards"),
            passingTouchdowns: StatLeader(playerName: passingTD.playerName, teamLogoName: passingTD.teamLogoName, position: passingTD.position, statValue: passingTD.passingTouchdowns, statDescription: "\(passingTD.passingTouchdowns) TDs"),
            rushingTouchdowns: StatLeader(playerName: rushingTD.playerName, teamLogoName: rushingTD.teamLogoName, position: rushingTD.position, statValue: rushingTD.rushingTouchdowns, statDescription: "\(rushingTD.rushingTouchdowns) TDs"),
            receivingTouchdowns: StatLeader(playerName: receivingTD.playerName, teamLogoName: receivingTD.teamLogoName, position: receivingTD.position, statValue: receivingTD.receivingTouchdowns, statDescription: "\(receivingTD.receivingTouchdowns) TDs"),
            tackles: StatLeader(playerName: tackles.playerName, teamLogoName: tackles.teamLogoName, position: tackles.position, statValue: tackles.tackles, statDescription: "\(tackles.tackles) tackles"),
            sacks: StatLeader(playerName: sacks.playerName, teamLogoName: sacks.teamLogoName, position: sacks.position, statValue: sacks.sacksMade, statDescription: "\(sacks.sacksMade) sacks"),
            interceptions: StatLeader(playerName: interceptions.playerName, teamLogoName: interceptions.teamLogoName, position: interceptions.position, statValue: interceptions.interceptionsDefense, statDescription: "\(interceptions.interceptionsDefense) INTs")
        )
    }
    
    private func getUserSeasonSummary() -> (record: TeamRecord, finalRank: Int)? {
        guard let userTeam = userTeam else {
            print("❌ No user team found")
            return nil
        }
        
        let record = getTeamRecord(for: userTeam.logoName)
        
        // Calculate final rank by comparing records with all teams
        let allTeamRecords = allTeams.map { team in
            (team: team, record: getTeamRecord(for: team.logoName))
        }
        
        let sortedTeams = allTeamRecords.sorted { team1, team2 in
            compareTeamRecords(team1: team1.team, team2: team2.team)
        }
        
        let userRank = sortedTeams.firstIndex { $0.team.logoName == userTeam.logoName }?.advanced(by: 1) ?? 32
        
        return (record: record, finalRank: userRank)
    }
    
    private func createMinimalSeasonHistory(seasonNumber: Int) -> SeasonHistory {
        print("🔧 Creating minimal season history for Season \(seasonNumber)")
        
        // Create absolute minimum season history that will always work
        let fallbackStatLeader = StatLeader(
            playerName: "Season Complete",
            teamLogoName: userTeam?.logoName ?? "unknown",
            position: "N/A",
            statValue: 0,
            statDescription: "Season Completed"
        )
        
        let userRecord = userTeam?.record ?? TeamRecord(wins: 0, losses: 0, ties: 0)
        
        // Create realistic fallback champions using different teams
        let userTeamLogo = userTeam?.logoName ?? "unknown"
        
        print("🏆 DEBUG: Creating minimal season history for user team: \(userTeamLogo)")
        
        // Determine user's conference and division for proper placement
        let userConference = getProperConference(for: userTeamLogo)
        let userDivision = getProperDivision(for: userTeamLogo)
        
        print("🏆 DEBUG: User team conference: \(userConference), division: \(userDivision)")
        
        // ACFT Championship logic
        let afcChamp = (userConference == .afc) ? userTeamLogo : "KansasCity"
        let nfcChamp = (userConference == .nfc) ? userTeamLogo : "Philadelphia"
        
        // Division champions - place user in their correct division, others get defaults
        let afcEastChamp: String
        let afcNorthChamp: String
        let afcSouthChamp: String
        let afcWestChamp: String
        let nfcEastChamp: String
        let nfcNorthChamp: String
        let nfcSouthChamp: String
        let nfcWestChamp: String
        
        // Set division champions based on user's actual division
        switch userDivision {
        case .afcEast:
            afcEastChamp = userTeamLogo
            afcNorthChamp = "Baltimore"
            afcSouthChamp = "Indianapolis"
            afcWestChamp = "KansasCity"
            nfcEastChamp = "Philadelphia"
            nfcNorthChamp = "Detroit"
            nfcSouthChamp = "NewOrleans"
            nfcWestChamp = "SanFrancisco"
        case .afcNorth:
            afcEastChamp = "Buffalo"
            afcNorthChamp = userTeamLogo
            afcSouthChamp = "Indianapolis"
            afcWestChamp = "KansasCity"
            nfcEastChamp = "Philadelphia"
            nfcNorthChamp = "Detroit"
            nfcSouthChamp = "NewOrleans"
            nfcWestChamp = "SanFrancisco"
        case .afcSouth:
            afcEastChamp = "Buffalo"
            afcNorthChamp = "Baltimore"
            afcSouthChamp = userTeamLogo
            afcWestChamp = "KansasCity"
            nfcEastChamp = "Philadelphia"
            nfcNorthChamp = "Detroit"
            nfcSouthChamp = "NewOrleans"
            nfcWestChamp = "SanFrancisco"
        case .afcWest:
            afcEastChamp = "Buffalo"
            afcNorthChamp = "Baltimore"
            afcSouthChamp = "Indianapolis"
            afcWestChamp = userTeamLogo
            nfcEastChamp = "Philadelphia"
            nfcNorthChamp = "Detroit"
            nfcSouthChamp = "NewOrleans"
            nfcWestChamp = "SanFrancisco"
        case .nfcEast:
            afcEastChamp = "Buffalo"
            afcNorthChamp = "Baltimore"
            afcSouthChamp = "Indianapolis"
            afcWestChamp = "KansasCity"
            nfcEastChamp = userTeamLogo
            nfcNorthChamp = "Detroit"
            nfcSouthChamp = "NewOrleans"
            nfcWestChamp = "SanFrancisco"
        case .nfcNorth:
            afcEastChamp = "Buffalo"
            afcNorthChamp = "Baltimore"
            afcSouthChamp = "Indianapolis"
            afcWestChamp = "KansasCity"
            nfcEastChamp = "Philadelphia"
            nfcNorthChamp = userTeamLogo
            nfcSouthChamp = "NewOrleans"
            nfcWestChamp = "SanFrancisco"
        case .nfcSouth:
            afcEastChamp = "Buffalo"
            afcNorthChamp = "Baltimore"
            afcSouthChamp = "Indianapolis"
            afcWestChamp = "KansasCity"
            nfcEastChamp = "Philadelphia"
            nfcNorthChamp = "Detroit"
            nfcSouthChamp = userTeamLogo
            nfcWestChamp = "SanFrancisco"
        case .nfcWest:
            afcEastChamp = "Buffalo"
            afcNorthChamp = "Baltimore"
            afcSouthChamp = "Indianapolis"
            afcWestChamp = "KansasCity"
            nfcEastChamp = "Philadelphia"
            nfcNorthChamp = "Detroit"
            nfcSouthChamp = "NewOrleans"
            nfcWestChamp = userTeamLogo
        }
        
        print("🏆 DEBUG: Division champions set:")
        print("   ACFT East: \(afcEastChamp)")
        print("   ACFT North: \(afcNorthChamp)")
        print("   ACFT South: \(afcSouthChamp)")
        print("   ACFT West: \(afcWestChamp)")
        print("   NCFT East: \(nfcEastChamp)")
        print("   NCFT North: \(nfcNorthChamp)")
        print("   NCFT South: \(nfcSouthChamp)")
        print("   NCFT West: \(nfcWestChamp)")
        
        return SeasonHistory(
            seasonYear: seasonNumber,
            completedDate: Date(),
            superBowlWinner: userTeamLogo, // User wins the Super Bowl as reward
            superBowlRunnerUp: (userConference == .afc) ? "Philadelphia" : "KansasCity", // Different conference runner-up
            afcChampion: afcChamp,
            nfcChampion: nfcChamp,
            afcEast: afcEastChamp,
            afcNorth: afcNorthChamp,
            afcSouth: afcSouthChamp,
            afcWest: afcWestChamp,
            nfcEast: nfcEastChamp,
            nfcNorth: nfcNorthChamp,
            nfcSouth: nfcSouthChamp,
            nfcWest: nfcWestChamp,
            passingYardsLeader: fallbackStatLeader,
            rushingYardsLeader: fallbackStatLeader,
            receivingYardsLeader: fallbackStatLeader,
            passingTouchdownsLeader: fallbackStatLeader,
            rushingTouchdownsLeader: fallbackStatLeader,
            receivingTouchdownsLeader: fallbackStatLeader,
            tacklesLeader: fallbackStatLeader,
            sacksLeader: fallbackStatLeader,
            interceptionsLeader: fallbackStatLeader,
            userTeamRecord: userRecord,
            userTeamFinalRank: 1
        )
    }
    
    // MARK: - Season Management
    
    func advanceToNextSeason() {
        print("🏈 Advancing to next season...")
        
        // Advance season number
        currentSeasonNumber += 1
        
        // Reset week to 0 (pre-season)
        currentWeek = 0
        
        // Clear completed games
        completedGames.removeAll()
        
        // Reset upcoming games (would need to regenerate schedule)
        upcomingGames.removeAll()
        
        // Clear statistics for new season
        playerSeasonStats.removeAll()
        teamSeasonStats.removeAll()
        gamePlayerStats.removeAll()
        
        print("✅ Advanced to season \(currentSeasonNumber)")
    }
}