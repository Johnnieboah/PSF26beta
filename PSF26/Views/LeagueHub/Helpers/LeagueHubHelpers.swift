import SwiftUI
import Foundation

// MARK: - LeagueHub Helper Functions
struct LeagueHubHelpers {
    
    // MARK: - Schedule Helper Functions
    static func simplifyOpponentName(_ fullOpponentName: String) -> String {
        // Convert full team names to city names
        let cityNameMapping: [String: String] = [
            "Kansas City Chiefs": "Kansas City",
            "San Francisco 49ers": "San Francisco",
            "Miami Dolphins": "Miami",
            "Dallas Cowboys": "Dallas",
            "Chicago Bears": "Chicago",
            "Detroit Lions": "Detroit",
            "Green Bay Packers": "Green Bay",
            "Minnesota Vikings": "Minnesota",
            "New York Giants": "New York",
            "Philadelphia Eagles": "Philadelphia",
            "Washington Commanders": "Washington",
            "Atlanta Falcons": "Atlanta",
            "Carolina Panthers": "Carolina",
            "New Orleans Saints": "New Orleans",
            "Tampa Bay Buccaneers": "Tampa Bay",
            "Arizona Cardinals": "Arizona",
            "Los Angeles Rams": "Los Angeles",
            "Seattle Seahawks": "Seattle",
            "Baltimore Ravens": "Baltimore",
            "Cincinnati Bengals": "Cincinnati",
            "Cleveland Browns": "Cleveland",
            "Pittsburgh Steelers": "Pittsburgh",
            "Buffalo Bills": "Buffalo",
            "New England Patriots": "New England",
            "New York Jets": "New York",
            "Houston Texans": "Houston",
            "Indianapolis Colts": "Indianapolis",
            "Jacksonville Jaguars": "Jacksonville",
            "Tennessee Titans": "Tennessee",
            "Denver Broncos": "Denver",
            "Las Vegas Raiders": "Las Vegas",
            "Los Angeles Chargers": "Los Angeles"
        ]
        
        return cityNameMapping[fullOpponentName] ?? fullOpponentName
    }
    
    static func getOpponentLogoName(_ fullOpponentName: String) -> String {
        // Convert full team names to logo asset names
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
        
        return logoMapping[fullOpponentName] ?? ""
    }
    
    static func generateRealisticRecord(for week: Int, leagueManager: LeagueManager, teamLogoName: String) -> (wins: Int, losses: Int, ties: Int) {
        // Get the actual opponent record from league manager instead of generating random
        let masterLoader = MasterDataLoader.shared
        let realSchedule = masterLoader.getSchedule(for: teamLogoName)
        
        if let currentGame = realSchedule.first(where: { $0.week == week }) {
            let opponentShortName = getOpponentLogoName(currentGame.opponent)
            if let opponentTeam = leagueManager.allTeams.first(where: { $0.logoName == opponentShortName }) {
                return (wins: opponentTeam.record.wins, losses: opponentTeam.record.losses, ties: opponentTeam.record.ties)
            }
        }
        
        // Fallback to realistic record based on current week if team not found
        let gamesPlayed = max(0, week - 1)
        let wins = Int.random(in: 0...gamesPlayed)
        let losses = gamesPlayed - wins
        return (wins: wins, losses: losses, ties: 0)
    }
    
    // MARK: - Playoff Helper Functions
    static func isPlayoffWeek(_ currentWeek: Int) -> Bool {
        return currentWeek > 18
    }
    
    static func playoffRoundImage(for currentWeek: Int) -> Image {
        if currentWeek == 19 {
            return Image("wildcardround")
        } else if currentWeek == 20 {
            return Image("divisionalround")
        } else if currentWeek == 21 {
            // Conference Championship - determine which conference logo to show
            return Image("conferencechampionship1_logo") // Default to ACFT Championship logo
        } else {
            return Image("championshiplogo")
        }
    }
    
    static func getRoundName(for week: Int) -> String {
        switch week {
        case 19: return "Wild Card"
        case 20: return "Divisional"
        case 21: return "Conference Championship"
        case 22: return "League Championship"
        default: return "Playoff"
        }
    }
    
    // MARK: - UI Helper Functions
    static func getToolbarTitle(for selectedTab: LeagueHubView.LeagueTab, currentLeague: ObservableLeague) -> String {
        switch selectedTab {
        case .team:
            return TeamData.getTeamCityName(currentLeague.teamLogoName)
        case .league:
            return "League Schedule"
        case .hub:
            return "Pure Football League"
        case .history:
            return "League History"
        case .settings:
            return "League Settings"
        }
    }
    
    static func getStageLabel(for currentWeek: Int) -> String {
        if currentWeek == 0 {
            return "Pre-Season Setup"
        } else if currentWeek <= 18 {
            return "Regular Season"
        } else {
            return "Playoffs"
        }
    }
    
    static func getSingleTeamStatusText(for opponentName: String, currentWeek: Int) -> String {
        if opponentName == "BYE" {
            return "BYE WEEK"
        } else if opponentName == "First Round Bye" {
            return "FIRST ROUND BYE"
        } else if opponentName == "Season Complete" {
            return "SEASON COMPLETE"
        } else if opponentName == "Eliminated - Watching Playoffs" {
            return "ELIMINATED - WATCHING PLAYOFFS"
        } else if currentWeek == 0 {
            return "PRESEASON"
        } else if opponentName == "TBD" || opponentName.isEmpty {
            return "SCHEDULE TBD"
        } else {
            return "PREPARING"
        }
    }
    
    static func formatRecord(_ record: (wins: Int, losses: Int, ties: Int)) -> String {
        if record.ties > 0 {
            return "\(record.wins)-\(record.losses)-\(record.ties)"
        } else {
            return "\(record.wins)-\(record.losses)"
        }
    }
    
    static func getRatingColor(_ rating: Int) -> Color {
        switch rating {
        case 90...100: return .green
        case 80...89: return .blue
        case 70...79: return .orange
        default: return .red
        }
    }
    
    // MARK: - Training Camp Helper Functions
    static func canAdvanceFromTrainingCamp(currentLeague: ObservableLeague, leagueManager: LeagueManager) -> Bool {
        // If not in training camp, always allow advance
        if !currentLeague.isInTrainingCamp {
            return true
        }
        
        // If in training camp, check roster size; allow negative cap to make some teams a challenge
        guard let userTeam = leagueManager.userTeam else { return false }
        
        // Allow advance when roster is 65 or fewer (down to 45 minimum), regardless of cap space
        let hasValidRosterSize = userTeam.players.count <= 65 && userTeam.players.count >= 45
        return hasValidRosterSize
    }
    
    // MARK: - Team Creation Helper Functions
    static func createDefaultTeam(logoName: String) -> LeagueTeam {
        let defaultCoach = Coach(
            firstName: "Default",
            lastName: "Coach",
            overallRating: 75,
            offensiveScheme: "Pro Style",
            defensiveScheme: "4-3 Base",
            experience: 5,
            offensiveCoordinator: OffensiveCoordinator(
                firstName: "OC",
                lastName: "Default",
                overallRating: 70,
                offensiveScheme: "Pro Style",
                experience: 3
            ),
            defensiveCoordinator: DefensiveCoordinator(
                firstName: "DC",
                lastName: "Default",
                overallRating: 70,
                defensiveScheme: "4-3 Base",
                experience: 3
            )
        )
        
        return LeagueTeam(
            logoName: logoName,
            name: logoName,
            conference: "",
            division: "",
            primaryColor: "blue",
            secondaryColor: "white",
            players: [],
            overallRating: 80,
            coach: defaultCoach
        )
    }
    
    // MARK: - Salary Cap Helper Functions
    static func calculateDeadCap(for teamLogoName: String) -> Int {
        // Simplified dead cap calculation - roughly 5-15% of used cap space
        let usedCap = NFLCapData.getCapSpending(for: teamLogoName)
        let deadCapPercentage = Double.random(in: 0.05...0.15)
        return Int(Double(usedCap) * deadCapPercentage)
    }
} 
