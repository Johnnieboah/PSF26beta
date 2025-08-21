import SwiftUI
import Foundation
import Combine

// MARK: - LeagueHub State Manager
class LeagueHubStateManager: ObservableObject {
    // MARK: - Published State
    @Published var selectedTab: LeagueHubView.LeagueTab = .hub
    @Published var userGameCompleted = false
    @Published var userGameScore: (userScore: Int, opponentScore: Int) = (0, 0)
    @Published var isAdvancingWeek = false
    @Published var isReadyForPostseason = false
    @Published var showPlayoffBracket = false
    
    private let leagueManager: LeagueManager
    private let currentLeague: ObservableLeague
    
    // Alert and sheet states
    @Published var showingSaveAlert = false
    @Published var saveAlertMessage = ""
    @Published var showingExitConfirmation = false
    @Published var showingTeamSchedule = false
    @Published var showingCoachInfo = false
    @Published var showingTeamStats = false
    @Published var showingUserTeamStats = false
    @Published var showingTeamRoster = false
    @Published var showingLeagueSchedule = false
    @Published var showingLeagueStandings = false
    @Published var showingAllCoaches = false
    @Published var showingLeagueStats = false
    @Published var showingFreeAgents = false
    @Published var showingTrainingCampCuts = false
    @Published var trainingCampCutsRefreshTrigger = false
    
    // Add playoff stats state
    @Published var showingPlayoffStats = false
    
    // League History and Championships states
    @Published var showingLeagueHistory = false
    @Published var showingChampionships = false
    @Published var showSeasonRecapPopup = false
    @Published var currentSeasonRecapData: SeasonHistory?
    @Published var isProcessingOffseason = false
    @Published var offseasonProcessingProgress: Double = 0.0
    
    // Refresh trigger for UI updates
    @Published var refreshTrigger = UUID()
    
    // Consolidated sheet management
    @Published var activeSheet: ActiveSheet?
    
    // Opponent information states
    @Published var opponentName = ""
    @Published var opponentLogoName = ""
    @Published var opponentRecord: (wins: Int, losses: Int, ties: Int) = (0, 0, 0)
    @Published var isHomeGame = true
    
    // Performance-optimized simulation state
    @Published var optimizedSimulationProgress: Double = 0.0

    // Transient result overlay (shown ~2.5s after a sim)
    // When set, the Hub shows scores under the logos using these values, then clears.
    @Published var resultOverlay: (userLogo: String, oppLogo: String, userScore: Int, oppScore: Int, isBye: Bool)? = nil
    
    // MARK: - ActiveSheet Enum
    enum ActiveSheet: Identifiable, Equatable {
        case teamSchedule
        case teamRoster
        case coachInfo
        case teamStats
        case userTeamStats
        case leagueSchedule
        case leagueStandings
        case allCoaches
        case leagueStats
        case playoffBracket
        case freeAgents
        case playoffStats
        case leagueHistory
        case championships
        case seasonRecap(SeasonHistory)
        
        var id: String {
            switch self {
            case .teamSchedule: return "teamSchedule"
            case .teamRoster: return "teamRoster" 
            case .coachInfo: return "coachInfo"
            case .teamStats: return "teamStats"
            case .userTeamStats: return "userTeamStats"
            case .leagueSchedule: return "leagueSchedule"
            case .leagueStandings: return "leagueStandings"
            case .allCoaches: return "allCoaches"
            case .leagueStats: return "leagueStats"
            case .playoffBracket: return "playoffBracket"
            case .freeAgents: return "freeAgents"
            case .playoffStats: return "playoffStats"
            case .leagueHistory: return "leagueHistory"
            case .championships: return "championships"
            case .seasonRecap: return "seasonRecap"
            }
        }
        
        static func == (lhs: ActiveSheet, rhs: ActiveSheet) -> Bool {
            switch (lhs, rhs) {
            case (.teamSchedule, .teamSchedule),
                 (.teamRoster, .teamRoster),
                 (.coachInfo, .coachInfo),
                 (.teamStats, .teamStats),
                 (.userTeamStats, .userTeamStats),
                 (.leagueSchedule, .leagueSchedule),
                 (.leagueStandings, .leagueStandings),
                 (.allCoaches, .allCoaches),
                 (.leagueStats, .leagueStats),
                 (.playoffBracket, .playoffBracket),
                 (.freeAgents, .freeAgents),
                 (.playoffStats, .playoffStats),
                 (.leagueHistory, .leagueHistory),
                 (.championships, .championships):
                return true
            case (.seasonRecap(let lhsSeason), .seasonRecap(let rhsSeason)):
                return lhsSeason.id == rhsSeason.id
            default:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    init(leagueManager: LeagueManager, currentLeague: ObservableLeague) {
        self.leagueManager = leagueManager
        self.currentLeague = currentLeague
    }
    
    // MARK: - State Management Functions
    func resetGameState() {
        userGameCompleted = false
        userGameScore = (0, 0)
    }
    
    func updateGameScore(userScore: Int, opponentScore: Int) {
        userGameScore = (userScore: userScore, opponentScore: opponentScore)
        userGameCompleted = true
    }

    // MARK: - Result Overlay Control
    func showResultOverlay(userLogo: String, oppLogo: String, userScore: Int, oppScore: Int, isBye: Bool) {
        resultOverlay = (userLogo: userLogo, oppLogo: oppLogo, userScore: userScore, oppScore: oppScore, isBye: isBye)
    }
    
    func clearResultOverlay() {
        resultOverlay = nil
    }
    
    func updateOpponentInfo(name: String, logoName: String, record: (wins: Int, losses: Int, ties: Int), isHome: Bool) {
        opponentName = name
        opponentLogoName = logoName
        opponentRecord = record
        isHomeGame = isHome
    }
    
    func setSeasonComplete() {
        opponentName = "Season Complete"
        opponentLogoName = ""
        opponentRecord = (wins: 0, losses: 0, ties: 0)
        isHomeGame = true
        userGameCompleted = true
    }
    
    func setAdvanceToPostSeason() {
        opponentName = "Advance to Post-Season"
        opponentLogoName = ""
        opponentRecord = (wins: 0, losses: 0, ties: 0)
        isHomeGame = true
        userGameCompleted = true
        isReadyForPostseason = true
    }
    
    func setEliminatedFromPlayoffs() {
        opponentName = "Eliminated - Watching Playoffs"
        opponentLogoName = ""
        opponentRecord = (wins: 0, losses: 0, ties: 0)
        isHomeGame = true
        userGameCompleted = true
    }
    
    func setFirstRoundBye() {
        opponentName = "First Round Bye"
        opponentLogoName = ""
        opponentRecord = (wins: 0, losses: 0, ties: 0)
        isHomeGame = true
        userGameCompleted = true
    }
    
    func setByeWeek() {
        opponentName = "BYE"
        opponentLogoName = ""
        opponentRecord = (wins: 0, losses: 0, ties: 0)
        isHomeGame = true
    }
    
    // MARK: - Sheet Management
    func showSheet(_ sheet: ActiveSheet) {
        activeSheet = sheet
    }
    
    func dismissSheet() {
        activeSheet = nil
    }
    
    func showSeasonRecap(_ seasonHistory: SeasonHistory) {
        currentSeasonRecapData = seasonHistory
        activeSheet = .seasonRecap(seasonHistory)
    }
    
    // MARK: - Alert Management
    func showSaveAlert(message: String) {
        saveAlertMessage = message
        showingSaveAlert = true
    }
    
    func showExitConfirmation() {
        showingExitConfirmation = true
    }
    
    // MARK: - Offseason Processing
    func startOffseasonProcessing() {
        isProcessingOffseason = true
        offseasonProcessingProgress = 0.0
        
        // Animate the processing
        withAnimation(.linear(duration: 2.0)) {
            offseasonProcessingProgress = 1.0
        }
    }
    
    func completeOffseasonProcessing() {
        isProcessingOffseason = false
        offseasonProcessingProgress = 0.0
    }
    
    func advanceToOffseason() {
        print("🌿 Advancing to offseason...")
        
        // Prevent multiple calls by checking if already processing
        guard !isProcessingOffseason else {
            print("⚠️ Already processing offseason - ignoring duplicate call")
            return
        }
        
        // Start processing animation
        isProcessingOffseason = true
        offseasonProcessingProgress = 0.0
        
        // Animate the processing
        withAnimation(.linear(duration: 2.0)) {
            offseasonProcessingProgress = 1.0
        }
        
        // Generate season history after a delay to show processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [self] in
            // Always advance to next season regardless of whether history generation succeeds
            let currentSeasonNumber = currentLeague.currentSeasonNumber
            print("🏆 Advancing from Season \(currentSeasonNumber) to Season \(currentSeasonNumber + 1)")
            
            // Try to generate season history
            if let seasonHistory = self.leagueManager.generateSeasonHistory(seasonNumber: currentSeasonNumber) {
                print("✅ Season history generated successfully")
                
                // Add to league's completed seasons
                if currentLeague.completedSeasons == nil {
                    currentLeague.completedSeasons = []
                }
                currentLeague.completedSeasons?.append(seasonHistory)
                
                // Debug: Check if season was actually added
                let totalCompletedSeasons = currentLeague.completedSeasons?.count ?? 0
                print("📚 Total completed seasons after adding: \(totalCompletedSeasons)")
                
                // Show season recap
                self.currentSeasonRecapData = seasonHistory
                self.activeSheet = .seasonRecap(seasonHistory)
                print("🏆 Season recap popup triggered for Season \(seasonHistory.seasonYear)")
                
                // Debug: Verify the popup data
                print("🏆 Season recap data set: \(seasonHistory.seasonYear), Super Bowl winner: \(seasonHistory.superBowlWinner)")
                
            } else {
                print("⚠️ Season history generation failed - continuing without recap")
                print("🔍 DEBUG: Checking why season history generation failed...")
                
                // Try to get more info about what failed
                if self.leagueManager.userTeam == nil {
                    print("❌ No user team found")
                } else {
                    print("✅ User team exists: \(self.leagueManager.userTeam?.name ?? "unknown")")
                }
                
                let playerStatsCount = self.leagueManager.playerSeasonStats.count
                let teamStatsCount = self.leagueManager.teamSeasonStats.count
                print("📊 Player stats: \(playerStatsCount), Team stats: \(teamStatsCount)")
            }
            
            // Always advance to next season
            currentLeague.currentSeasonNumber = currentLeague.currentSeasonNumber + 1
            
            // Reset to Week 0 for new season preparation
            currentLeague.currentWeek = 0
            self.leagueManager.currentWeek = 0
            
            // Reset game state for new season
            self.opponentName = ""
            self.opponentLogoName = ""
            self.opponentRecord = (wins: 0, losses: 0, ties: 0)
            self.userGameCompleted = false
            
            // Reset league state for new season
            // Note: This is a basic reset - a full implementation would reset all teams, stats, etc.
            print("🔄 Season advanced - ready for new season setup")
            
            // Auto-save the advanced league state
            if currentLeague.autoSave {
                do {
                    try currentLeague.save(from: self.leagueManager)
                    print("💾 Advanced league state saved successfully!")
                } catch {
                    print("❌ Failed to save advanced league state: \(error)")
                }
            }
            
            // End processing
            self.isProcessingOffseason = false
            print("✅ Offseason advancement completed!")
            print("📚 Final completed seasons count: \(currentLeague.completedSeasons?.count ?? 0)")
        }
    }
    
    // MARK: - UI Refresh
    func triggerRefresh() {
        refreshTrigger = UUID()
    }
    
    func triggerTrainingCampCutsRefresh() {
        trainingCampCutsRefreshTrigger.toggle()
    }
    
    // MARK: - Tab Management
    func selectTab(_ tab: LeagueHubView.LeagueTab) {
        selectedTab = tab
    }
    
    // MARK: - State Queries
    var isPlayoffWeek: Bool {
        // This would need to be passed in from the view
        return false
    }
    
    var shouldShowSingleTeamLogo: Bool {
        // Show single team logo for:
        // 1. Regular season bye weeks
        // 2. TBD opponents
        // 3. Preseason (week 0)
        // 4. Empty opponent name
        // 5. Playoff byes (First Round Bye)
        // 6. Season complete
        // 7. Eliminated - watching playoffs
        return opponentName == "BYE" || 
               opponentName == "TBD" || 
               opponentName.isEmpty ||
               opponentLogoName.isEmpty ||
               opponentName == "First Round Bye" ||
               opponentName == "Season Complete" ||
               opponentName == "Eliminated - Watching Playoffs"
    }
    
    var isSeasonComplete: Bool {
        return opponentName == "Season Complete"
    }
    
    var isAdvanceToPostSeason: Bool {
        return opponentName == "Advance to Post-Season"
    }
    
    var isEliminatedFromPlayoffs: Bool {
        return opponentName == "Eliminated - Watching Playoffs"
    }
    
    var isFirstRoundBye: Bool {
        return opponentName == "First Round Bye"
    }
    
    var isByeWeek: Bool {
        return opponentName == "BYE"
    }
}
