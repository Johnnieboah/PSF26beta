import SwiftUI
import Combine

// MARK: - Errors
enum LeagueCreationError: Error {
    case teamCreationFailed
    case saveError(Error)
}

// MARK: - Configuration
struct LeagueSetupSettings {
    let difficulty: String
    let autoSave: Bool
    let autoSetDepthChart: Bool
    let autoFillTeam: Bool
    let injuriesEnabled: Bool
    let salaryCapEnabled: Bool
    let gameSpeed: String
}

// MARK: - Helper Extensions
extension String {
    func toGameDifficulty() -> GameDifficulty {
        switch self {
        case "Rookie": return .rookie
        case "Semi-Pro": return .semiPro
        case "Pro": return .pro
        case "Hall of Fame": return .hallOfFame
        default: return .pro
        }
    }
    
    func toGameSpeed() -> GameSpeed {
        switch self {
        case "Slow": return .slow
        case "Normal": return .normal
        case "Fast": return .fast
        default: return .normal
        }
    }
}

// MARK: - Core League Manager
/// Consolidated manager handling league creation, flow, and scheduling
@MainActor
class CoreLeagueManager: ObservableObject {
    static let shared = CoreLeagueManager()
    
    // League Flow State
    @Published var shouldDismissToHub = false
    @Published var pendingLeague: ActiveLeague?
    
    private init() {}
    
    // MARK: - League Creation & Flow
    func startNewLeague(teamName: String, logoName: String, customLogoData: Data? = nil, settings: LeagueSetupSettings? = nil) async {
        // Create a new league
        var league = League(
            teamName: teamName,
            teamLogoName: logoName,
            customLogoData: customLogoData,
            difficulty: settings?.difficulty ?? "Pro",
            autoSave: settings?.autoSave ?? true,
            autoSetDepthChart: settings?.autoSetDepthChart ?? true,
            autoFillTeam: settings?.autoFillTeam ?? false,
            injuriesEnabled: settings?.injuriesEnabled ?? true,
            salaryCapEnabled: settings?.salaryCapEnabled ?? true,
            gameSpeed: settings?.gameSpeed ?? "Normal"
        )
        
        // Initialize the league with full team data immediately
        print("🏈 Initializing new league with full team data...")
        do {
            let tempLeagueManager = LeagueManager()
            let teamData = TeamData.createTeamFromData(name: logoName, leagueId: league.id, isTrainingCamp: true)
            let gameplaySettings = LeagueGameplaySettings(
                difficulty: settings?.difficulty.toGameDifficulty() ?? .pro,
                autoSave: settings?.autoSave ?? true,
                autoSetDepthChart: settings?.autoSetDepthChart ?? true,
                autoFillTeam: settings?.autoFillTeam ?? false,
                injuriesEnabled: settings?.injuriesEnabled ?? true,
                salaryCapEnabled: settings?.salaryCapEnabled ?? true,
                acceleratedClock: false,
                gameSpeed: settings?.gameSpeed.toGameSpeed() ?? .normal
            )
            
            // Setup the league manager to create all teams and schedule
            tempLeagueManager.setupLeague(selectedTeam: teamData, settings: gameplaySettings, leagueId: league.id, isTrainingCamp: true)
            
            // Verify teams were created successfully
            guard !tempLeagueManager.allTeams.isEmpty else {
                print("❌ Failed to create teams - falling back to basic league creation")
                throw LeagueCreationError.teamCreationFailed
            }
            
            // Update the league with the full state
            league.allTeams = tempLeagueManager.allTeams
            league.completedGames = tempLeagueManager.completedGames
            league.upcomingGames = tempLeagueManager.upcomingGames
            league.currentWeek = tempLeagueManager.currentWeek
            league.isInTrainingCamp = true
            league.trainingCampCompleted = false
            
            print("🏈 League initialized with \(league.allTeams?.count ?? 0) teams and \(league.upcomingGames?.count ?? 0) scheduled games")
            
            // Skipping file-based balancing generation: we respect imported roster sizes now.
        } catch {
            print("⚠️ Error during league initialization: \(error)")
            print("🔄 Falling back to basic league creation - teams will be created when hub loads")
            // Leave the league with empty arrays - LeagueHubView will handle creation
        }
        
        // Save the league with full data
        do {
            try LeagueStorageManager.shared.saveLeague(league)
            print("League saved successfully!")
        } catch {
            print("Failed to save league: \(error)")
        }
        
        // Create the pending league for UI
        pendingLeague = ActiveLeague(
            teamName: teamName,
            logoName: logoName,
            customLogoData: customLogoData,
            league: league
        )
        
        // Trigger dismissal
        shouldDismissToHub = true
    }
    
    func reset() {
        shouldDismissToHub = false
        pendingLeague = nil
    }
    
    // MARK: - Season Schedule Generation
    func generateSeasonSchedule(teams: [LeagueTeam], masterDataLoader: MasterDataLoader) -> [GameResult] {
        var allGames: [GameResult] = []
        
        print("📅 Starting season schedule generation...")
        
        // Generate games for all 18 weeks
        for week in 1...18 {
            print("📅 Generating games for week \(week)...")
            let weekGames = generateGamesForWeek(week, teams: teams, masterDataLoader: masterDataLoader)
            allGames.append(contentsOf: weekGames)
        }
        
        print("📅 Generated \(allGames.count) games for the season")
        
        // Debug: Print first few games
        print("📅 Sample games:")
        for game in allGames.prefix(5) {
            print("   Week \(game.week): \(game.homeTeam.logoName) vs \(game.awayTeam.logoName)")
        }
        
        return allGames
    }
    
    private func generateGamesForWeek(_ week: Int, teams: [LeagueTeam], masterDataLoader: MasterDataLoader) -> [GameResult] {
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
                    let homeTeam = teams.first(where: { $0.logoName == teamLogoName })
                    let awayTeam = teams.first(where: { $0.logoName == opponentShortName })
                    
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
    
    // MARK: - Game Filtering & Queries
    func getGamesForWeek(_ week: Int, from games: [GameResult]) -> [GameResult] {
        return games.filter { $0.week == week }
    }
    
    func getGamesForTeam(_ teamLogoName: String, from games: [GameResult]) -> [GameResult] {
        return games.filter { game in
            game.homeTeam.logoName == teamLogoName || game.awayTeam.logoName == teamLogoName
        }
    }
    
    func getRemainingGamesForTeam(_ teamLogoName: String, from upcomingGames: [GameResult], currentWeek: Int) -> [GameResult] {
        return upcomingGames.filter { game in
            game.week >= currentWeek && (game.homeTeam.logoName == teamLogoName || game.awayTeam.logoName == teamLogoName)
        }
    }
    
    // MARK: - Playoff Schedule Generation
    func generatePlayoffSchedule(teams: [LeagueTeam], bracketManager: LeagueManager.PlayoffBracketManager) -> [GameResult] {
        var playoffGames: [GameResult] = []
        
        // Separate AFC and NFC teams
        let afcTeams = Array(teams.filter { $0.conference == "ACFT" }.prefix(7))
        let nfcTeams = Array(teams.filter { $0.conference == "NCFT" }.prefix(7))
        
        // Generate Wild Card matchups using the existing bracket manager
        let wildCardMatchups = bracketManager.generateWildCardBracket(afcTeams: afcTeams, nfcTeams: nfcTeams)
        
        // Convert matchups to GameResults
        for matchup in wildCardMatchups {
            let game = GameResult(
                week: matchup.week,
                homeTeam: matchup.homeTeam,
                awayTeam: matchup.awayTeam
            )
            playoffGames.append(game)
        }
        
        return playoffGames
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

