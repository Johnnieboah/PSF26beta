import SwiftUI
import Metal
import Combine
import Foundation

struct LeagueHubView: View {
    @StateObject private var currentLeague: ObservableLeague
    @Environment(\.dismiss) var dismiss
    @StateObject private var storageManager = LeagueStorageManager.shared
    
    // League Manager for proper game simulation
    @StateObject private var leagueManager: LeagueManager
    
    // Advanced State Management
    @StateObject private var stateContainer = StateContainer()
    @StateObject private var performanceManager = AdvancedPerformanceManager.shared
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @State private var selectedTab: LeagueTab = .hub
    
    // New state for two-step simulation



    
    // Alert and sheet states
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var showingExitConfirmation = false
    @State private var showingTeamSchedule = false
    @State private var showingCoachInfo = false
    @State private var showingTeamStats = false
    @State private var showingUserTeamStats = false
    @State private var showingTeamRoster = false
    @State private var showingLeagueSchedule = false
    @State private var showingLeagueStandings = false
    @State private var showingAllCoaches = false
    @State private var showingLeagueStats = false
    @State private var showingFreeAgents = false
    @State private var showingTrainingCampCuts = false
    @State private var trainingCampCutsRefreshTrigger = false
    
    // Add playoff stats state
    @State private var showingPlayoffStats = false
    
    // League History and Championships states
    @State private var showingLeagueHistory = false
    @State private var showingChampionships = false
    @State private var showSeasonRecapPopup = false
    @State private var currentSeasonRecapData: SeasonHistory?

    
    // Refresh trigger for UI updates
    @State private var refreshTrigger = UUID()
    
    // Consolidated sheet management
    @State private var activeSheet: ActiveSheet?
    
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
        case welcome // NEW
        
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
            case .welcome: return "welcome"
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
    
    // Game simulation states

    

    
    // iOS 26 Performance Enhancements
    @StateObject private var backgroundSimulationManager = BackgroundSimulationManager()
    @StateObject private var memoryOptimizer = MemoryOptimizer()
    @StateObject private var metalOptimizationManager = MetalOptimizationManager.shared
    
    // Phase 3: Advanced Background Processing & Predictive Analytics
    @StateObject private var backgroundProcessingManager = iOS26BackgroundProcessingManager.shared
    @StateObject private var predictiveAnalyticsManager = iOS26PredictiveAnalyticsManager.shared
    
    // Performance-optimized simulation state

    
    // MARK: - Manager Objects
    @StateObject private var gameplayManager = GameplayManager.shared
    @StateObject private var stateManager: LeagueHubStateManager
    
    // Simulation managers
    private var simulationManager: GameplayManager { gameplayManager }
    private var playoffSimulationManager: PlayoffSimulationManager {
        PlayoffSimulationManager(leagueManager: leagueManager, currentLeague: currentLeague, stateManager: stateManager)
    }
    
    // Initialize with a League model
    init(league: League) {
        let currentLeague = ObservableLeague(league: league)
        let leagueManager = LeagueManager()
        self._currentLeague = StateObject(wrappedValue: currentLeague)
        self._leagueManager = StateObject(wrappedValue: leagueManager)
        
        // Create state manager first
        let stateManager = LeagueHubStateManager(leagueManager: leagueManager, currentLeague: currentLeague)
        self._stateManager = StateObject(wrappedValue: stateManager)
        
        // GameplayManager is now a singleton, no need to create instances
    }
    
    // Convenience initializer for backwards compatibility
    init(teamName: String, teamLogoName: String, customLogoData: Data?) {
        let league = League(
            teamName: teamName,
            teamLogoName: teamLogoName,
            customLogoData: customLogoData
        )
        let currentLeague = ObservableLeague(league: league)
        let leagueManager = LeagueManager()
        self._currentLeague = StateObject(wrappedValue: currentLeague)
        self._leagueManager = StateObject(wrappedValue: leagueManager)
        
        // Create state manager first
        let stateManager = LeagueHubStateManager(leagueManager: leagueManager, currentLeague: currentLeague)
        self._stateManager = StateObject(wrappedValue: stateManager)
        
        // GameplayManager is now a singleton, no need to create instances
    }
    
    // Computed properties from league
    private var currentWeek: Int {
        get { currentLeague.currentWeek }
    }
    
    private var userRecord: (wins: Int, losses: Int, ties: Int) {
        get { (wins: currentLeague.wins, losses: currentLeague.losses, ties: currentLeague.ties) }
    }
    
    enum LeagueTab: String, CaseIterable {
        case team = "Team"
        case league = "League"
        case hub = "Hub"
        case history = "History"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .team: return "person.3.fill"
            case .league: return "chart.bar.fill"
            case .hub: return "house.fill"
            case .history: return "book.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationCoordinator.navigationPath) {
            TabView(selection: $selectedTab) {
                // Team Tab - Enhanced with Performance Optimization
                OptimizedListRow(id: "team-tab") {
                    LeagueHubTeamTabView(currentLeague: currentLeague, leagueManager: leagueManager)
                        .performanceOptimized(identifier: "team-schedule")
                        .iOS26Enhanced()
                }
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Team")
                }
                .tag(LeagueTab.team)
                
                // League Tab - Enhanced with Glass Cards
                OptimizedListRow(id: "league-tab") {
                    LeagueHubLeagueTabView(currentLeague: currentLeague, leagueManager: leagueManager, stateManager: stateManager)
                        .performanceOptimized(identifier: "league-schedule")
                        .iOS26Enhanced()
                }
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("League")
                }
                .tag(LeagueTab.league)
                
                // Hub Tab - Main content
                OptimizedListRow(id: "hub-tab") {
                    hubContent
                        .performanceOptimized(identifier: "league-hub")
                        .iOS26Enhanced()
                }
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Hub")
                }
                .tag(LeagueTab.hub)
                
                // History Tab - League History
                OptimizedListRow(id: "history-tab") {
                    historyContent
                        .performanceOptimized(identifier: "league-history")
                        .iOS26Enhanced()
                }
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("History")
                }
                .tag(LeagueTab.history)
                
                // Settings Tab - Coming Soon
                OptimizedListRow(id: "settings-tab") {
                    VStack(spacing: 20) {
                        Image(systemName: "gearshape.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Coming Soon")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("League Settings feature is under development")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                }
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(LeagueTab.settings)
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .modifier(iOS26TabBarEnhancements())
            .navigationDestination(for: NavigationCoordinator.NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(getToolbarTitle())
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        saveLeague()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title3)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingExitConfirmation = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                    }
                }
            }
            .onAppear {
                // Switch to this league (only clears if different league)
                GlobalGameResultsManager.shared.switchToLeague(currentLeague.id)
                
                // Setup league manager with user's team
                let teamData = TeamData.createTeamFromData(name: currentLeague.teamLogoName, leagueId: currentLeague.id, isTrainingCamp: currentLeague.isInTrainingCamp)
                let settings = LeagueGameplaySettings.defaultSettings()
                
                // Debug: Check what's in the saved league before loading
                let savedLeague = currentLeague.getLeague()
                let savedPlayerStatsCount = savedLeague.playerSeasonStats?.count ?? 0
                let savedTeamStatsCount = savedLeague.teamSeasonStats?.count ?? 0
                print("🏈 🔍 DEBUG: League file contains - \(savedPlayerStatsCount) player stats, \(savedTeamStatsCount) team stats")
                
                // Pass the loaded league for state restoration
                leagueManager.setupLeague(selectedTeam: teamData, settings: settings, savedState: savedLeague, leagueId: currentLeague.id)
                print("🏈 League setup complete with user team: \(currentLeague.teamLogoName)")
                print("🏈 League has \(leagueManager.allTeams.count) teams loaded")
                
                // Load saved season statistics before initializing new ones
                leagueManager.loadSeasonStatsFromSavedLeague(savedLeague)
                
                // Debug: Check what was loaded
                let loadedPlayerStats = leagueManager.playerSeasonStats.count
                let loadedTeamStats = leagueManager.teamSeasonStats.count
                let totalGamesPlayedAfterLoad = leagueManager.playerSeasonStats.values.reduce(0) { $0 + $1.gamesPlayed }
                print("🏈 🔍 DEBUG: After loading - \(loadedPlayerStats) player stats, \(loadedTeamStats) team stats, \(totalGamesPlayedAfterLoad) total player games")
                
                // Force recreate player data if roster sizes are incorrect
                Task {
                    await forceRecreatePlayerDataIfNeeded()
                }
                
                // Initialize comprehensive statistics tracking (will only fill missing stats)
                leagueManager.initializeSeasonStats()
                
                // Always refresh LeagueManager team data to ensure consistency
                print("🔄 Forcing LeagueManager team data refresh...")
                leagueManager.refreshTeamDataFromPlayerDataManager()
                print("🔄 ✅ LeagueManager team data refresh complete")
                
                // Debug: Check what exists after initialization
                let finalPlayerStats = leagueManager.playerSeasonStats.count
                let finalTeamStats = leagueManager.teamSeasonStats.count
                let totalGamesPlayedAfterInit = leagueManager.playerSeasonStats.values.reduce(0) { $0 + $1.gamesPlayed }
                print("🏈 🔍 DEBUG: After initialization - \(finalPlayerStats) player stats, \(finalTeamStats) team stats, \(totalGamesPlayedAfterInit) total player games")
                
                // Load league progress - with proper timing to ensure master data is loaded
                if MasterDataLoader.shared.isDataLoaded {
                    loadLeagueProgress()
                } else {
                    print("🔄 Master data not ready yet - will load progress once data is available")
                    // Give master data a moment to load, then try loading progress
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.loadLeagueProgress()
                    }
                }
                
                // Present welcome for new leagues when in training camp
                if leagueManager.isInTrainingCamp {
                    activeSheet = .welcome
                }

                // Wire global notifications to present sheets from other views
                NotificationCenter.default.addObserver(forName: .presentTrainingCampCuts, object: nil, queue: .main) { _ in
                    self.showingTrainingCampCuts = true
                }
                NotificationCenter.default.addObserver(forName: .presentTeamRoster, object: nil, queue: .main) { _ in
                    self.activeSheet = .teamRoster
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .seasonRecap(let seasonHistory):
                NavigationStack {
                    SeasonRecapView(seasonHistory: seasonHistory, isPostSeasonPopup: true)
                        .onAppear {
                            print("📱 Consolidated sheet: Season recap appeared for Season \(seasonHistory.seasonYear)")
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Continue to Offseason") {
                                    activeSheet = nil
                                    print("📱 Season recap dismissed manually")
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            }
                        }
                        .navigationBarBackButtonHidden(true)
                }
            case .leagueHistory:
                NavigationStack {
                    LeagueHistoryView(completedSeasons: currentLeague.completedSeasons ?? [])
                        .onAppear {
                            print("📱 Consolidated sheet: League history appeared")
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    activeSheet = nil
                                }
                            }
                        }
                }
            case .championships:
                NavigationStack {
                    ChampionshipsView(completedSeasons: currentLeague.completedSeasons ?? [])
                        .onAppear {
                            print("📱 Consolidated sheet: Championships appeared")
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    activeSheet = nil
                                }
                            }
                        }
                }
            case .welcome:
                NavigationStack {
                    VStack(spacing: 16) {
                        Text("Welcome to the league")
                            .font(.title2.weight(.semibold))
                        Text("Your journey to becoming the greatest team owner in the history of the Pure Football League starts now. Before the regular season, you are given the last call on who gets cut, and who stays as you trim your roster to 65 players.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        Button("Let's get started") {
                            activeSheet = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .navigationBarBackButtonHidden(true)
                }
            case .teamRoster:
                NavigationStack {
                    // Build a temporary TeamData binding from currentLeague
                    let teamData = TeamData.createTeamFromData(name: currentLeague.teamLogoName)
                    HubRosterInlineSection(
                        teamData: teamData,
                        leagueId: currentLeague.getLeague().id
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { activeSheet = nil }
                        }
                    }
                }
            default:
                EmptyView()
            }
        }
        // Dedicated presentation for Training Camp Cuts (boolean-driven)
        .sheet(isPresented: $showingTrainingCampCuts) {
            // Present the existing cuts view using current league objects
            TrainingCampCuttingView(
                leagueManager: leagueManager,
                // We pass a constant binding to the existing ObservableLeague instance.
                // The view mutates properties on the object; it doesn't replace the binding.
                currentLeague: .constant(currentLeague)
            )
        }
        .alert("Save League", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text(saveAlertMessage)
        }
        .alert("Exit League", isPresented: $showingExitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Save and Exit") {
                saveAndExit()
            }
            Button("Exit Without Saving", role: .destructive) {
                dismiss()
            }
        } message: {
            if currentLeague.autoSave {
                Text("Do you want to save your current progress before exiting?\n(Auto-save is enabled)")
            } else {
                Text("Do you want to save your progress before exiting?\n(Auto-save is disabled)")
            }
        }

    }
    
    // MARK: - Save/Load Functions
    private func saveLeague() {
        do {
            try currentLeague.save(from: leagueManager)
            withAnimation {
                saveAlertMessage = "League saved successfully!"
                showingSaveAlert = true
            }
            print("💾 League saved successfully")
        } catch {
            withAnimation {
                saveAlertMessage = "Failed to save league: \(error.localizedDescription)"
                showingSaveAlert = true
            }
            print("❌ Failed to save league: \(error)")
        }
    }
    
    private func saveAndExit() {
        do {
            try currentLeague.save(from: leagueManager)
            print("💾 League saved before exit")
            dismiss()
        } catch {
            // If save fails, show error but still allow exit
            withAnimation {
                saveAlertMessage = "Failed to save league: \(error.localizedDescription)"
                showingSaveAlert = true
            }
            print("❌ Failed to save league before exit: \(error)")
            
            // Dismiss after a brief delay to show the error
        }
    }
    
    @MainActor
    private func forceRecreatePlayerDataIfNeeded() async {
        // Disabled: we want to keep CSV roster counts (~74) and not regenerate
        #if DEBUG
        print("🔄 DEBUG: Skipping forceRecreatePlayerDataIfNeeded — CSV rosters are authoritative")
        #endif
    }
    
    private func loadLeagueProgress() {
        print("🔄 Loading league progress - Current Week: \(currentWeek)")
        
        let masterLoader = MasterDataLoader.shared
        
        // CRITICAL FIX: Ensure master data is loaded before proceeding
        guard masterLoader.isDataLoaded else {
            print("🔄 ⚠️ Master data not loaded yet - waiting...")
            // Retry after master data loads
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.loadLeagueProgress()
            }
            return
        }
        
        if currentWeek > 0 {
            // Check if we're in playoffs (week 19+)
            if currentWeek > 18 {
                // Playoffs - load saved playoff data first
                print("🔄 Loading playoff save for week \(currentWeek)")
                leagueManager.loadPlayoffData(from: currentLeague.getLeague())
                // FIXED: Don't call setupPlayoffs from view - this triggers objectWillChange
                playoffSimulationManager.loadPlayoffOpponent()
                print("🔄 ✅ Playoff opponent loaded: \(stateManager.opponentName)")
            } else {
                // Regular season - load from schedule
                let realSchedule = masterLoader.getSchedule(for: currentLeague.teamLogoName)
                
                // DEBUG: Print what we got
                print("🔄 DEBUG: Schedule loaded for \(currentLeague.teamLogoName):")
                print("🔄 DEBUG: Found \(realSchedule.count) games")
                print("🔄 DEBUG: Looking for week \(currentWeek)")
                for game in realSchedule.prefix(5) {
                    print("🔄 DEBUG: Week \(game.week): \(game.opponent) (Home: \(game.isHome))")
                }
                
                if let currentGame = realSchedule.first(where: { $0.week == currentLeague.currentWeek }) {
                    withAnimation {
                        stateManager.opponentName = simplifyOpponentName(currentGame.opponent)
                        stateManager.opponentLogoName = getOpponentLogoName(currentGame.opponent)
                        stateManager.opponentRecord = generateRealisticRecord(for: currentLeague.currentWeek)
                        stateManager.isHomeGame = currentGame.isHome
                    }
                    print("🔄 ✅ Found opponent: \(stateManager.opponentName) for week \(currentWeek)")
                } else {
                    // Check if it's actually a bye week or a data issue
                    let scheduledWeeks = Set(realSchedule.map { $0.week })
                    print("🔄 DEBUG: Scheduled weeks: \(scheduledWeeks.sorted())")
                    
                    if scheduledWeeks.isEmpty {
                        print("🔄 ❌ No schedule data found - this is a data loading issue!")
                        // Try to recover by waiting a bit more
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.loadLeagueProgress()
                        }
                        return
                    } else if !scheduledWeeks.contains(currentWeek) {
                        // This is actually a bye week
                        print("🔄 ✅ Week \(currentWeek) is confirmed bye week")
                        stateManager.opponentName = "BYE"
                        stateManager.opponentLogoName = ""
                        stateManager.opponentRecord = (wins: 0, losses: 0, ties: 0)
                        stateManager.isHomeGame = true
                    } else {
                        print("🔄 ❌ Week \(currentWeek) should have a game but wasn't found - data parsing issue!")
                        // This shouldn't happen, but handle it gracefully
                        stateManager.opponentName = "BYE"
                        stateManager.opponentLogoName = ""
                        stateManager.opponentRecord = (wins: 0, losses: 0, ties: 0)
                        stateManager.isHomeGame = true
                    }
                }
            }
        } else {
            // League just started, load first opponent
            setupFirstOpponent()
        }
        
        // Reset user game state when loading progress
        // For bye weeks, we don't need to track game completion since there's no game
        // For playoff byes, userGameCompleted should remain true (set by loadPlayoffOpponent)
        if !isPlayoffWeek() || (stateManager.opponentName != "First Round Bye" && stateManager.opponentName != "Season Complete") {
            withAnimation {
                stateManager.userGameCompleted = false
                stateManager.userGameScore = (0, 0)
            }
        }
        // If it's a playoff bye or season complete, keep the state set by loadPlayoffOpponent
    }
    
    private func setupFirstOpponent() {
        let masterLoader = MasterDataLoader.shared
        
        // Ensure master data is loaded
        guard masterLoader.isDataLoaded else {
            print("🔄 ⚠️ Master data not loaded for first opponent setup - using fallback")
            withAnimation {
                stateManager.opponentName = "Season Setup"
                stateManager.opponentLogoName = ""
                stateManager.opponentRecord = (wins: 0, losses: 0, ties: 0)
                stateManager.isHomeGame = true
            }
            return
        }
        
        let realSchedule = masterLoader.getSchedule(for: currentLeague.teamLogoName)
        
        if let firstGame = realSchedule.first(where: { $0.week == 1 }) {
            stateManager.opponentName = simplifyOpponentName(firstGame.opponent)
            stateManager.opponentLogoName = getOpponentLogoName(firstGame.opponent)
            stateManager.opponentRecord = (wins: 0, losses: 0, ties: 0)
            stateManager.isHomeGame = firstGame.isHome
            print("🔄 ✅ Setup first opponent: \(stateManager.opponentName) for week 1")
        } else {
            // Fallback
            withAnimation {
                stateManager.opponentName = "Season Setup"
                stateManager.opponentLogoName = ""
                stateManager.opponentRecord = (wins: 0, losses: 0, ties: 0)
                stateManager.isHomeGame = true
            }
            print("🔄 ⚠️ No week 1 game found - using season setup fallback")
        }
    }
    
    private var leagueScheduleHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("League Schedule")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if currentWeek > 0 {
                    Text("Week \(currentWeek)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.09, blue: 0.16),
                        Color(red: 0.52, green: 0.08, blue: 0.14)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .continuousClip(Corner.large)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Hub Content
    private var hubContent: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Team Logos Section - Centered at top
                        teamLogosSection
                            .padding(.top, isPlayoffWeek() && stateManager.opponentName == "Eliminated - Watching Playoffs" ? 12 : 24)
                        
                        // Playoff Bracket Section (when user is eliminated but playoffs are ongoing)
                        if isPlayoffWeek() && stateManager.opponentName == "Eliminated - Watching Playoffs" {
                            PlayoffBracketCompactView(
                                leagueManager: leagueManager,
                                selectedTeam: TeamData.createTeamFromData(name: currentLeague.teamLogoName),
                                showRoundLogos: false,
                                teamLogoSize: 24)
                                .frame(minHeight: 400, maxHeight: 600)
                        } else {
                            // Training Camp Cuts Button (if needed)
                            if currentLeague.needsTrainingCampCuts() {
                                trainingCampCutsButton
                                    .padding(.horizontal)
                                    .padding(.top, 20)
                            }
                            
                            // Main Action Button (normal position)
                            mainActionButton
                                .padding(.horizontal)
                                .padding(.top, currentLeague.needsTrainingCampCuts() ? 12 : 20)
                        }
                        
                        // Quick Simulation Buttons
                        if currentWeek > 0 && currentWeek < 23 && stateManager.opponentName != "Season Complete" {
                            quickSimulationSection
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }
                        
                        // Simulation Progress (if simulating)
                        if simulationManager.isSimulating {
                            simulationProgressView
                                .padding(.horizontal)
                        }
                    }
                }
                
                // Main Action Button for eliminated playoff view
                if isPlayoffWeek() && stateManager.opponentName == "Eliminated - Watching Playoffs" {
                    mainActionButton
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                }
            }
        }
    }
    
    // MARK: - Team Logos Section
    private var teamLogosSection: some View {
        LeagueHubTeamLogosView(
            currentLeague: currentLeague,
            leagueManager: leagueManager,
            opponentName: stateManager.opponentName,
            opponentLogoName: stateManager.opponentLogoName,
            userGameCompleted: stateManager.userGameCompleted,
            userGameScore: stateManager.userGameScore,
            currentWeek: currentWeek,
            isSimulating: simulationManager.isSimulating,
            resultOverlay: stateManager.resultOverlay
        )
    }
    
    // MARK: - Playoff Logo Section
    private var playoffLogoSection: some View {
        LeagueHubPlayoffLogoSection(currentWeek: currentWeek)
    }
    
    // MARK: - Playoff Helper Functions
    private func isPlayoffWeek() -> Bool {
        return LeagueHubHelpers.isPlayoffWeek(currentWeek)
    }
    
    private func playoffRoundImage() -> Image {
        return LeagueHubHelpers.playoffRoundImage(for: currentWeek)
    }
    
    // MARK: - Training Camp Cuts Button
    private var trainingCampCutsButton: some View {
        LeagueHubTrainingCampCutsButton {
            print("🔧 Training Camp Cuts button pressed")
            print("🔧 showingTrainingCampCuts before: \(showingTrainingCampCuts)")
            DispatchQueue.main.async {
                showingTrainingCampCuts = true
                print("🔧 showingTrainingCampCuts after: \(showingTrainingCampCuts)")
            }
        }
    }
    
    // MARK: - Main Action Button
    private var mainActionButton: some View {
        LeagueHubActionButtonsView(
            currentLeague: currentLeague,
            leagueManager: leagueManager,
            currentWeek: currentWeek,
            opponentName: stateManager.opponentName,
            userGameCompleted: stateManager.userGameCompleted,
            isSimulating: simulationManager.isSimulating,
            isAdvancingWeek: simulationManager.isAdvancingWeek,
            isProcessingOffseason: stateManager.isProcessingOffseason,
            isReadyForPostseason: stateManager.isReadyForPostseason,
            onMainActionButtonPressed: {
                Task {
                    if currentLeague.isInTrainingCamp {
                        await gameplayManager.startSeason(leagueManager: leagueManager, currentLeague: currentLeague)
                    } else {
                        // Capture PRE week, opponent, and points for delta fallback
                        let preWeek = currentWeek
                        let userLogo = currentLeague.teamLogoName
                        let schedule = MasterDataLoader.shared.getSchedule(for: userLogo)
                        let preGame = schedule.first { $0.week == preWeek }
                        let oppFullName = preGame?.opponent ?? ""
                        let oppLogo = LeagueHubHelpers.getOpponentLogoName(oppFullName)
                        let preUserPts = leagueManager.getTeamSeasonStats(teamLogoName: userLogo)?.totalPoints ?? 0
                        let preOppPts = leagueManager.getTeamSeasonStats(teamLogoName: oppLogo)?.totalPoints ?? 0

                        await gameplayManager.advanceWeek(leagueManager: leagueManager, currentLeague: currentLeague)

                        // Prefer real stored result if available
                        var shown = false
                        let preIsHome = preGame?.isHome ?? true
                        if !oppFullName.isEmpty,
                           let result = gameplayManager.getGameResultForTeam(
                                teamName: userLogo,
                                week: preWeek,
                                opponent: oppFullName,
                                isHome: preIsHome
                           ) {
                            let userScore = preIsHome ? result.homeScore : result.awayScore
                            let oppScore = preIsHome ? result.awayScore : result.homeScore
                            await MainActor.run {
                                // Ensure progress UI is hidden before overlay
                                gameplayManager.isSimulating = false
                                gameplayManager.isAdvancingWeek = false
                                stateManager.showResultOverlay(userLogo: userLogo, oppLogo: oppLogo, userScore: userScore, oppScore: oppScore, isBye: false)
                            }
                            shown = true
                        }

                        // Fallback to deltas if no stored result was found
                        if !shown {
                            let postUserPts = leagueManager.getTeamSeasonStats(teamLogoName: userLogo)?.totalPoints ?? preUserPts
                            let postOppPts = leagueManager.getTeamSeasonStats(teamLogoName: oppLogo)?.totalPoints ?? preOppPts
                            let userScore = max(0, postUserPts - preUserPts)
                            let oppScore = max(0, postOppPts - preOppPts)
                            let isBye = (userScore == 0 && oppScore == 0)
                            await MainActor.run {
                                gameplayManager.isSimulating = false
                                gameplayManager.isAdvancingWeek = false
                                stateManager.showResultOverlay(userLogo: userLogo, oppLogo: oppLogo, userScore: userScore, oppScore: oppScore, isBye: isBye)
                            }
                        }

                        // After ~2.5s, clear overlay and show next week's opponent (or BYE)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            stateManager.clearResultOverlay()
                            let nextWeek = currentLeague.currentWeek
                            let nextSchedule = MasterDataLoader.shared.getSchedule(for: currentLeague.teamLogoName)
                            if let nextGame = nextSchedule.first(where: { $0.week == nextWeek }) {
                                withAnimation {
                                    stateManager.opponentName = nextGame.opponent
                                    stateManager.opponentLogoName = LeagueHubHelpers.getOpponentLogoName(nextGame.opponent)
                                    stateManager.isHomeGame = nextGame.isHome
                                }
                            } else {
                                withAnimation {
                                    stateManager.opponentName = "BYE"
                                    stateManager.opponentLogoName = ""
                                    stateManager.isHomeGame = true
                                }
                            }
                        }
                    }
                }
            },
            onAdvanceToOffseason: stateManager.advanceToOffseason
        )
    }
    
    // MARK: - Quick Simulation Section
    private var quickSimulationSection: some View {
        LeagueHubQuickSimulationView(
            currentWeek: currentWeek,
            opponentName: stateManager.opponentName,
            isReadyForPostseason: stateManager.isReadyForPostseason,
            isSimulating: simulationManager.isSimulating,
            isAdvancingWeek: simulationManager.isAdvancingWeek,
            teamLogoName: currentLeague.teamLogoName,
            onSimToNextWeek: {
                Task {
                    // Use unified sim runner for a single step to make the animation consistent
                    let target = min(currentWeek + 1, 23)
                    await gameplayManager.runUnifiedSim(to: target,
                                                         leagueManager: leagueManager,
                                                         currentLeague: currentLeague,
                                                         stateManager: stateManager)
                    await MainActor.run { self.loadLeagueProgress() }
                }
            },
            onSimToMidSeason: {
                Task {
                    let targetWeek = 9
                    await gameplayManager.runUnifiedSim(to: targetWeek,
                                                         leagueManager: leagueManager,
                                                         currentLeague: currentLeague,
                                                         stateManager: stateManager)
                    await MainActor.run { self.loadLeagueProgress() }
                }
            },
            onSimToPlayoffs: {
                Task {
                    let targetWeek = 18
                    await gameplayManager.runUnifiedSim(to: targetWeek,
                                                         leagueManager: leagueManager,
                                                         currentLeague: currentLeague,
                                                         stateManager: stateManager)
                    await MainActor.run { self.loadLeagueProgress() }
                }
            }
        )
    }
    
    // MARK: - Simulation Progress View
    private var simulationProgressView: some View {
        LeagueHubSimulationProgressView(
            isSimulating: simulationManager.isSimulating,
            simulationProgress: simulationManager.simulationProgress,
            currentWeek: currentWeek,
            leagueManager: leagueManager
        )
    }
    
    // MARK: - Season Recap Processing Overlay
    private var seasonRecapProcessingOverlay: some View {
        LeagueHubSeasonRecapProcessingOverlay(
            isProcessingOffseason: stateManager.isProcessingOffseason,
            offseasonProcessingProgress: stateManager.offseasonProcessingProgress
        )
    }
    

    

    

    


    

    

    

    

    


    
    // MARK: - Helper Functions for Schedule
    private func simplifyOpponentName(_ fullOpponentName: String) -> String {
        return LeagueHubHelpers.simplifyOpponentName(fullOpponentName)
    }
    
    private func getOpponentLogoName(_ fullOpponentName: String) -> String {
        return LeagueHubHelpers.getOpponentLogoName(fullOpponentName)
    }
    
    private func generateRealisticRecord(for week: Int) -> (wins: Int, losses: Int, ties: Int) {
        return LeagueHubHelpers.generateRealisticRecord(for: week, leagueManager: leagueManager, teamLogoName: currentLeague.teamLogoName)
    }

    


    
    // MARK: - Helper Functions
    
    private func createDefaultTeam(logoName: String) -> LeagueTeam {
        return LeagueHubHelpers.createDefaultTeam(logoName: logoName)
    }
    
    private func getToolbarTitle() -> String {
        return LeagueHubHelpers.getToolbarTitle(for: selectedTab, currentLeague: currentLeague)
    }
    
    private func getStageLabel() -> String {
        return LeagueHubHelpers.getStageLabel(for: currentWeek)
    }
    
    // MARK: - Training Camp Helpers
    private func canAdvanceFromTrainingCamp() -> Bool {
        return LeagueHubHelpers.canAdvanceFromTrainingCamp(currentLeague: currentLeague, leagueManager: leagueManager)
    }
    

    

    





    
    // MARK: - History Content
    private var historyContent: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // History Header
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .symbolEffect(.pulse)
                        
                        Text("League History")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 20)
                    
                    // History Content
                    if let completedSeasons = currentLeague.completedSeasons, !completedSeasons.isEmpty {
                        // Show completed seasons
                        VStack(spacing: 16) {
                            SectionHeaderView(
                                title: "Completed Seasons (\(completedSeasons.count))",
                                subtitle: "View your league's history and achievements"
                            )
                            
                            LazyVStack(spacing: 12) {
                                ForEach(completedSeasons.reversed(), id: \.id) { season in
                                    Button {
                                        print("🔘 History button pressed for Season \(season.seasonYear)")
                                        // Force UI update to ensure sheet state is properly synchronized
                                        DispatchQueue.main.async {
                                            self.currentSeasonRecapData = season
                                            self.activeSheet = .seasonRecap(season)
                                            print("🔘 Set currentSeasonRecapData and activeSheet = .seasonRecap")
                                        }
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Season \(season.seasonYear)")
                                                    .font(.headline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.primary)
                                                
                                                Text("Champion: \(TeamData.getTeamDisplayName(season.superBowlWinner))")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                
                                                Text("Your Record: \(season.userTeamRecord.wins)-\(season.userTeamRecord.losses)\(season.userTeamRecord.ties > 0 ? "-\(season.userTeamRecord.ties)" : "")")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .roundedBackground(.ultraThinMaterial, radius: Corner.medium)
                                    }
                                }
                            }
                            
                            // Championships Summary
                            ActionButton(
                                title: "View Championships",
                                systemImage: "trophy.fill",
                                action: {
                                    print("🏆 DEBUG: Championships button pressed")
                                    // Force UI update to ensure sheet state is properly synchronized
                                    DispatchQueue.main.async {
                                        self.activeSheet = .championships
                                        print("🏆 DEBUG: activeSheet set to .championships")
                                    }
                                },
                                style: .league(Color(red: 0.02, green: 0.25, blue: 0.70))
                            )
                        }
                        .padding(.horizontal)
                        
                    } else {
                        // Empty state
                        VStack(spacing: 20) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("No History Yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Complete your first season to start building your league history")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("League History")
    }
    

    

    
    // MARK: - Advanced Simulation Test
    private func testAdvancedSimulation() {
        print("🧪 Testing Advanced Simulation Engine Integration")
        
        // Get two teams for testing
        guard let homeTeam = leagueManager.allTeams.first(where: { $0.logoName == "Chicago" }),
              let awayTeam = leagueManager.allTeams.first(where: { $0.logoName == "GreenBay" }) else {
            print("❌ Could not find test teams")
            return
        }
        
        print("🏈 Testing simulation: \(homeTeam.name) vs \(awayTeam.name)")
        
        // Test the detailed simulation
        let detailedResult = leagueManager.simulateGameBetweenTeamsDetailed(homeTeam, awayTeam)
        
        print("📊 Game Result:")
        print("   Final Score: \(detailedResult.homeTeam.name) \(detailedResult.homeScore) - \(detailedResult.awayScore) \(detailedResult.awayTeam.name)")
        
        if let stats = detailedResult.detailedStats {
            print("   Total Plays: \(stats.totalPlays)")
            print("   Game Length: \(Int(stats.gameLength / 60)) minutes")
            print("   Home Total Yards: \(stats.homeTeamStats.totalYards)")
            print("   Away Total Yards: \(stats.awayTeamStats.totalYards)")
            print("   Home Passing: \(stats.homeTeamStats.passingCompletions)/\(stats.homeTeamStats.passingAttempts) for \(stats.homeTeamStats.passingYards) yards")
            print("   Away Passing: \(stats.awayTeamStats.passingCompletions)/\(stats.awayTeamStats.passingAttempts) for \(stats.awayTeamStats.passingYards) yards")
            print("   Home Rushing: \(stats.homeTeamStats.rushingAttempts) attempts for \(stats.homeTeamStats.rushingYards) yards")
            print("   Away Rushing: \(stats.awayTeamStats.rushingAttempts) attempts for \(stats.awayTeamStats.rushingYards) yards")
            print("   Turnovers: Home \(stats.homeTeamStats.turnovers), Away \(stats.awayTeamStats.turnovers)")
            print("   Big Plays (20+): \(stats.bigPlays)")
        } else {
            print("   ⚠️ No detailed stats available")
        }
        
        print("   Scoring Plays: \(detailedResult.scoringPlays.count)")
        for (index, scoringPlay) in detailedResult.scoringPlays.enumerated() {
            print("     \(index + 1). Q\(scoringPlay.quarter) - \(scoringPlay.team): \(scoringPlay.description) (+\(scoringPlay.points))")
        }
        
        print("✅ Advanced simulation test completed successfully!")
    }
    
    // MARK: - Phase 3: Predictive Analytics Integration
    private func generatePredictionsForUpcomingGames() async {
        guard predictiveAnalyticsManager.isMLAvailable else { return }
        
        // Get upcoming games for the next few weeks
        let upcomingWeeks = [currentLeague.currentWeek, currentLeague.currentWeek + 1, currentLeague.currentWeek + 2]
        
        for week in upcomingWeeks {
            guard week <= 18 else { continue }
            
            // Get user's game for this week
            let masterLoader = MasterDataLoader.shared
            let realSchedule = masterLoader.getSchedule(for: currentLeague.teamLogoName)
            
            if let game = realSchedule.first(where: { $0.week == week }) {
                let homeTeam = game.isHome ? currentLeague.teamLogoName : simplifyOpponentName(game.opponent)
                let awayTeam = game.isHome ? simplifyOpponentName(game.opponent) : currentLeague.teamLogoName
                
                // Generate prediction for this matchup
                await predictiveAnalyticsManager.predictGameOutcome(homeTeam: homeTeam, awayTeam: awayTeam)
            }
        }
        
        print("📊 Generated predictions for upcoming games")
    }
}

// MARK: - Team Schedule View
struct TeamScheduleView: View {
    let teamName: String
    let teamLogoName: String
    @State private var selectedWeek: Int?
    @StateObject private var masterDataLoader = MasterDataLoader.shared
    
    private var teamData: TeamData {
        TeamData.createTeamFromData(name: teamLogoName)
    }
    
    private var scheduleGames: [GameData] {
        let realSchedule = masterDataLoader.getSchedule(for: teamLogoName)
        
        if !realSchedule.isEmpty {
            // Create 18-week schedule including bye weeks (NFL has 18 weeks total, 17 games + 1 bye)
            var allWeeks: [GameData] = []
            let gamesByWeek = Dictionary(grouping: realSchedule) { $0.week }
            
            // NFL season spans weeks 1-18
            for week in 1...18 {
                if let games = gamesByWeek[week], let game = games.first {
                    allWeeks.append(GameData(
                        week: game.week,
                        opponent: TeamData.simplifyOpponentName(game.opponent),
                        isHome: game.isHome,
                        date: "Week \(game.week)",
                        time: TeamData.getGameTime(for: game.week)
                    ))
                } else {
                    // Missing week - this is a bye week
                    allWeeks.append(GameData(
                        week: week,
                        opponent: "BYE",
                        isHome: true,
                        date: "Week \(week)",
                        time: ""
                    ))
                }
            }
            return allWeeks
        } else {
            // Fallback to sample data if no real schedule available
            return teamData.schedule
        }
    }
    
    // Helper function to get opponent logo name from simplified name
    private func getOpponentLogoNameForGame(_ opponent: String) -> String {
        // Get the full opponent name from schedule
        let realSchedule = masterDataLoader.getSchedule(for: teamLogoName)
        
        // Find the matching game to get the full opponent name
        if let matchingGame = realSchedule.first(where: { 
            TeamData.simplifyOpponentName($0.opponent) == opponent 
        }) {
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
            
            return logoMapping[matchingGame.opponent] ?? ""
        }
        
        // Fallback mapping for simplified names
        let simplifiedMapping: [String: String] = [
            "Kansas City": "KansasCity",
            "San Francisco": "SanFrancisco",
            "Miami": "Miami",
            "Dallas": "Dallas",
            "Chicago": "Chicago",
            "Detroit": "Detroit",
            "Green Bay": "GreenBay",
            "Minnesota": "Minnesota",
            "New York": "NYN", // Default to Giants
            "Philadelphia": "Philadelphia",
            "Washington": "Washington",
            "Atlanta": "Atlanta",
            "Carolina": "Carolina",
            "New Orleans": "NewOrleans",
            "Tampa Bay": "TampaBay",
            "Arizona": "Arizona",
            "Los Angeles": "LAN", // Default to Rams
            "Seattle": "Seattle",
            "Baltimore": "Baltimore",
            "Cincinnati": "Cincinnati",
            "Cleveland": "Cleveland",
            "Pittsburgh": "Pittsburgh",
            "Buffalo": "Buffalo",
            "New England": "NewEngland",
            "Houston": "Houston",
            "Indianapolis": "Indianapolis",
            "Jacksonville": "Jacksonville",
            "Tennessee": "Tennessee",
            "Denver": "Denver",
            "Las Vegas": "LasVegas",
            // Handling sample schedule opponent names
            "Patriots": "NewEngland",
            "Dolphins": "Miami",
            "Bills": "Buffalo",
            "Steelers": "Pittsburgh",
            "Ravens": "Baltimore",
            "Browns": "Cleveland",
            "Bengals": "Cincinnati",
            "Colts": "Indianapolis",
            "Titans": "Tennessee",
            "Jaguars": "Jacksonville",
            "Texans": "Houston",
            "Chiefs": "KansasCity",
            "Chargers": "LAA",
            "Raiders": "LasVegas",
            "Broncos": "Denver",
            "Cowboys": "Dallas",
            "Giants": "NYN"
        ]
        
        return simplifiedMapping[opponent] ?? ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(Color(hex: teamData.primaryColor))
                
                Text("Season Schedule")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(scheduleGames.filter { $0.opponent != "BYE" }.count) Games")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if masterDataLoader.isDataLoaded && !masterDataLoader.getSchedule(for: teamLogoName).isEmpty {
                        Text("Real Schedule")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                }
            }
            
            LazyVStack(spacing: 12) {
                ForEach(scheduleGames) { game in
                    if game.opponent == "BYE" {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedWeek = selectedWeek == game.week ? nil : game.week
                            }
                        } label: {
                            ByeWeekRowView(
                                week: game.week,
                                teamColor: teamData.primaryColor
                            )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(selectedWeek == game.week ? 1.02 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedWeek)
                    } else {
                        EnhancedGameRowView(
                            game: game,
                            teamColor: teamData.primaryColor,
                            opponentLogoName: getOpponentLogoNameForGame(game.opponent),
                            isSelected: selectedWeek == game.week,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedWeek = selectedWeek == game.week ? nil : game.week
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - League Schedule View
struct LeagueScheduleView: View {
    let currentWeek: Int
    let userTeamLogoName: String?
    let userCustomLogoData: Data?
    @State private var selectedWeek: Int
    @StateObject private var masterDataLoader = MasterDataLoader.shared
    
    init(currentWeek: Int, userTeamLogoName: String? = nil, userCustomLogoData: Data? = nil) {
        self.currentWeek = currentWeek
        self.userTeamLogoName = userTeamLogoName
        self.userCustomLogoData = userCustomLogoData
        self._selectedWeek = State(initialValue: max(currentWeek, 1))
    }
    
    private let allNFLTeams = [
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
    
    private var weekGames: [(homeTeam: String, awayTeam: String)] {
        var games: [(String, String)] = []
        var scheduledTeams: Set<String> = []
        
        // Get all games for the selected week
        for team in allNFLTeams {
            if scheduledTeams.contains(team) { continue }
            
            let schedule = masterDataLoader.getSchedule(for: team)
            if let game = schedule.first(where: { $0.week == selectedWeek }) {
                let opponentShortName = getOpponentShortName(game.opponent)
                
                if game.isHome {
                    // This team is home
                    games.append((team, opponentShortName))
                    scheduledTeams.insert(team)
                    scheduledTeams.insert(opponentShortName)
                }
            }
        }
        
        return games
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Week Selector
            weekSelector
            
            // Games List
            if weekGames.isEmpty {
                byeWeekView
            } else {
                gamesListView
            }
        }
    }
    
    private var weekSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(1...18, id: \.self) { week in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedWeek = week
                        }
                    } label: {
                        Text("Week \(week)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedWeek == week ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: Corner.xLarge, style: .continuous)
                                    .fill(selectedWeek == week ? Color.blue : Color(.systemGray5))
                            )
                    }
                    .scaleEffect(selectedWeek == week ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedWeek)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var byeWeekView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Games This Week")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("All teams have a bye week")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var gamesListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(weekGames.enumerated()), id: \.offset) { index, game in
                LeagueGameRowView(
                    homeTeam: game.homeTeam,
                    awayTeam: game.awayTeam,
                    week: selectedWeek,
                    userTeamLogoName: userTeamLogoName,
                    userCustomLogoData: userCustomLogoData
                )
            }
        }
    }
    
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

// MARK: - League Game Row View
struct LeagueGameRowView: View {
    let homeTeam: String
    let awayTeam: String
    let week: Int
    let userTeamLogoName: String?
    let userCustomLogoData: Data?
    
    private var homeTeamColors: TeamColorMapping.TeamColors {
        TeamColorMapping.getColors(for: homeTeam)
    }
    
    private var awayTeamColors: TeamColorMapping.TeamColors {
        TeamColorMapping.getColors(for: awayTeam)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Away Team
            HStack(spacing: 12) {
                Group {
                    if awayTeam == userTeamLogoName {
                        TeamLogoView(
                            teamLogoName: awayTeam,
                            customLogoData: userCustomLogoData,
                            size: 40
                        )
                    } else {
                        Image(awayTeam)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    }
                }
                
                Text(TeamData.getTeamDisplayName(awayTeam))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // @ Symbol
            Text("@")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            // Home Team
            HStack(spacing: 12) {
                Text(TeamData.getTeamDisplayName(homeTeam))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Group {
                    if homeTeam == userTeamLogoName {
                        TeamLogoView(
                            teamLogoName: homeTeam,
                            customLogoData: userCustomLogoData,
                            size: 40
                        )
                    } else {
                        Image(homeTeam)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: awayTeamColors.primary).opacity(0.3), location: 0.0),
                    .init(color: Color(hex: homeTeamColors.primary).opacity(0.3), location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Corner.medium, style: .continuous)
                .stroke(.ultraThinMaterial, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - League Coaching View
struct LeagueCoachingView: View {
    let userTeamLogoName: String
    let leagueManager: LeagueManager
    let userCustomLogoData: Data?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    private var userTeamCoach: Coach? {
        return leagueManager.allTeams.first(where: { $0.logoName == userTeamLogoName })?.coach
    }
    
    private var allCoaches: [(team: LeagueTeam, coach: Coach)] {
        return leagueManager.allTeams.map { team in
            (team: team, coach: team.coach)
        }.sorted { first, second in
            // Sort by wins first, then by win percentage
            if first.coach.record.wins != second.coach.record.wins {
                return first.coach.record.wins > second.coach.record.wins
            }
            return first.coach.record.winPercentage > second.coach.record.winPercentage
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("View", selection: $selectedTab) {
                    Text("Your Coach").tag(0)
                    Text("All Coaches").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedTab == 0 {
                    yourCoachView
                } else {
                    allCoachesView
                }
            }
            .navigationTitle("Coaching")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var yourCoachView: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let coach = userTeamCoach {
                    // Coach Header
                    VStack(spacing: 16) {
                        // Coach "Photo" - Using initials in a circle
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: TeamColorMapping.getColors(for: userTeamLogoName).primary),
                                            Color(hex: TeamColorMapping.getColors(for: userTeamLogoName).secondary)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                            
                            Text("\(String(coach.firstName.prefix(1)))\(String(coach.lastName.prefix(1)))")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        VStack(spacing: 8) {
                            Text(coach.fullName)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Head Coach")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text(TeamData.getTeamDisplayName(userTeamLogoName))
                                .font(.headline)
                                .foregroundColor(Color(hex: TeamColorMapping.getColors(for: userTeamLogoName).primary))
                            
                            // Coach Record
                            Text("\(coach.record.wins)-\(coach.record.losses)" + (coach.record.ties > 0 ? "-\(coach.record.ties)" : ""))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Coach Stats
                    VStack(spacing: 20) {
                        // Overall Rating
                        StatCardView(
                            title: "Overall Rating",
                            value: "\(coach.overallRating)",
                            icon: "star.fill",
                            color: getRatingColor(coach.overallRating)
                        )
                        
                        // Experience
                        StatCardView(
                            title: "Coaching Experience",
                            value: "\(coach.experience) Years",
                            icon: "calendar.badge.clock",
                            color: .blue
                        )
                        
                        // Scheme Matching Bonus
                        if coach.schemeMatchingBonus > 0 {
                            StatCardView(
                                title: "Scheme Coordination",
                                value: "+\(Int(coach.schemeMatchingBonus * 100))% Bonus",
                                icon: "arrow.triangle.2.circlepath.circle.fill",
                                color: .purple
                            )
                        }
                        
                        // Head Coach Schemes
                        VStack(spacing: 12) {
                            Text("Head Coach Philosophy")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 16) {
                                SchemeCardView(
                                    title: "Offensive Scheme",
                                    scheme: coach.offensiveScheme,
                                    icon: "arrow.up.right.circle.fill",
                                    color: .green
                                )
                                
                                SchemeCardView(
                                    title: "Defensive Scheme",
                                    scheme: coach.defensiveScheme,
                                    icon: "shield.fill",
                                    color: .red
                                )
                            }
                        }
                        .padding(.top, 8)
                        
                        // Coordinators Section
                        VStack(spacing: 16) {
                            Text("Coaching Staff")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Offensive Coordinator
                            CoordinatorCardView(
                                title: "Offensive Coordinator",
                                coordinator: coach.offensiveCoordinator.fullName,
                                rating: coach.offensiveCoordinator.overallRating,
                                scheme: coach.offensiveCoordinator.offensiveScheme,
                                experience: coach.offensiveCoordinator.experience,
                                isMatching: coach.offensiveScheme == coach.offensiveCoordinator.offensiveScheme,
                                color: .green
                            )
                            
                            // Defensive Coordinator
                            CoordinatorCardView(
                                title: "Defensive Coordinator",
                                coordinator: coach.defensiveCoordinator.fullName,
                                rating: coach.defensiveCoordinator.overallRating,
                                scheme: coach.defensiveCoordinator.defensiveScheme,
                                experience: coach.defensiveCoordinator.experience,
                                isMatching: coach.defensiveScheme == coach.defensiveCoordinator.defensiveScheme,
                                color: .red
                            )
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                } else {
                    // No coach found
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.key")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Coach Information Unavailable")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Unable to load coach information for this team.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal)
        }
    }
    
    private var allCoachesView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(allCoaches.enumerated()), id: \.element.team.id) { index, item in
                    CoachListRowView(
                        rank: index + 1,
                        team: item.team,
                        coach: item.coach,
                        isUserTeam: item.team.logoName == userTeamLogoName,
                        userCustomLogoData: userCustomLogoData
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    private func getRatingColor(_ rating: Int) -> Color {
        return LeagueHubHelpers.getRatingColor(rating)
    }
}

// MARK: - Stat Card View
struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding()
        .roundedBackground(.ultraThinMaterial, radius: Corner.medium)
    }
}

// MARK: - Scheme Card View
struct SchemeCardView: View {
    let title: String
    let scheme: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(scheme)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .roundedBackground(.ultraThinMaterial, radius: Corner.medium)
    }
}

// MARK: - All Coaches View
struct AllCoachesView: View {
    let leagueManager: LeagueManager
    let userTeamLogoName: String
    let userCustomLogoData: Data?
    @Environment(\.dismiss) private var dismiss
    
    private var allCoaches: [(team: LeagueTeam, coach: Coach)] {
        return leagueManager.allTeams.map { team in
            (team: team, coach: team.coach)
        }.sorted { first, second in
            // Sort by wins first, then by win percentage
            if first.coach.record.wins != second.coach.record.wins {
                return first.coach.record.wins > second.coach.record.wins
            }
            return first.coach.record.winPercentage > second.coach.record.winPercentage
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(allCoaches.enumerated()), id: \.element.team.id) { index, item in
                        CoachListRowView(
                            rank: index + 1,
                            team: item.team,
                            coach: item.coach,
                            isUserTeam: item.team.logoName == userTeamLogoName,
                            userCustomLogoData: userCustomLogoData
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("All Coaches")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LeagueHubView(
        teamName: "Kansas City Chiefs",
        teamLogoName: "KansasCity",
        customLogoData: nil
    )
}

// MARK: - Team Schedule Results View
struct TeamScheduleResultsView: View {
    let teamName: String
    let teamLogoName: String
    let customLogoData: Data?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var masterDataLoader = MasterDataLoader.shared
    @ObservedObject private var gameResultsManager = GlobalGameResultsManager.shared
    @State private var selectedWeek: Int?
    
    private var teamData: TeamData {
        TeamData.createTeamFromData(name: teamLogoName)
    }
    
    // Helper function to get opponent logo name from simplified name
    private func getOpponentLogoNameForTeamSchedule(_ opponent: String) -> String {
        // Get the full opponent name from schedule
        let realSchedule = masterDataLoader.getSchedule(for: teamLogoName)
        
        // Find the matching game to get the full opponent name
        if let matchingGame = realSchedule.first(where: { 
            TeamData.simplifyOpponentName($0.opponent) == opponent 
        }) {
            // Use the existing getOpponentLogoName function defined elsewhere in the file
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
            
            return logoMapping[matchingGame.opponent] ?? ""
        }
        
        // Fallback mapping for simplified names
        let simplifiedMapping: [String: String] = [
            "Kansas City": "KansasCity",
            "San Francisco": "SanFrancisco",
            "Miami": "Miami",
            "Dallas": "Dallas",
            "Chicago": "Chicago",
            "Detroit": "Detroit",
            "Green Bay": "GreenBay",
            "Minnesota": "Minnesota",
            "New York": "NYN", // Default to Giants
            "Philadelphia": "Philadelphia",
            "Washington": "Washington",
            "Atlanta": "Atlanta",
            "Carolina": "Carolina",
            "New Orleans": "NewOrleans",
            "Tampa Bay": "TampaBay",
            "Arizona": "Arizona",
            "Los Angeles": "LAN", // Default to Rams
            "Seattle": "Seattle",
            "Baltimore": "Baltimore",
            "Cincinnati": "Cincinnati",
            "Cleveland": "Cleveland",
            "Pittsburgh": "Pittsburgh",
            "Buffalo": "Buffalo",
            "New England": "NewEngland",
            "Houston": "Houston",
            "Indianapolis": "Indianapolis",
            "Jacksonville": "Jacksonville",
            "Tennessee": "Tennessee",
            "Denver": "Denver",
            "Las Vegas": "LasVegas",
            // Sample schedule names
            "Patriots": "NewEngland",
            "Dolphins": "Miami",
            "Bills": "Buffalo",
            "Steelers": "Pittsburgh",
            "Ravens": "Baltimore",
            "Browns": "Cleveland",
            "Bengals": "Cincinnati",
            "Colts": "Indianapolis",
            "Titans": "Tennessee",
            "Jaguars": "Jacksonville",
            "Texans": "Houston",
            "Chiefs": "KansasCity",
            "Chargers": "LAA",
            "Raiders": "LasVegas",
            "Broncos": "Denver",
            "Cowboys": "Dallas",
            "Giants": "NYN"
        ]
        
        return simplifiedMapping[opponent] ?? ""
    }
    
    private var scheduleGames: [GameData] {
        let realSchedule = masterDataLoader.getSchedule(for: teamLogoName)
        
        if !realSchedule.isEmpty {
            var allWeeks: [GameData] = []
            let gamesByWeek = Dictionary(grouping: realSchedule) { $0.week }
            
            for week in 1...18 {
                if let games = gamesByWeek[week], let game = games.first {
                    var gameData = GameData(
                        week: game.week,
                        opponent: TeamData.simplifyOpponentName(game.opponent),
                        isHome: game.isHome,
                        date: "Week \(game.week)",
                        time: TeamData.getGameTime(for: game.week)
                    )
                    
                    // Check for game results from the shared manager
                    if let result = gameResultsManager.getGameResultForTeam(
                        teamName: teamLogoName,
                        week: game.week,
                        opponent: game.opponent,
                        isHome: game.isHome
                    ) {
                        gameData.homeScore = result.homeScore
                        gameData.awayScore = result.awayScore
                        gameData.isCompleted = result.isCompleted
                        print("📅 Team Schedule: Found result for \(teamLogoName) vs \(game.opponent) week \(game.week): \(result.homeScore)-\(result.awayScore)")
                    } else {
                        print("📅 Team Schedule: No result found for \(teamLogoName) vs \(game.opponent) week \(game.week)")
                    }
                    
                    allWeeks.append(gameData)
                } else {
                    // Missing week - this is a bye week
                    allWeeks.append(GameData(
                        week: week,
                        opponent: "BYE",
                        isHome: true,
                        date: "Week \(week)",
                        time: ""
                    ))
                }
            }
            return allWeeks
        } else {
            return teamData.schedule
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Team Header
                    HStack {
                        TeamLogoView(
                            teamLogoName: teamLogoName,
                            customLogoData: customLogoData,
                            size: 60
                        )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(teamName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Season Schedule")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Schedule List
                    LazyVStack(spacing: 12) {
                        ForEach(scheduleGames) { game in
                            if game.opponent == "BYE" {
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedWeek = selectedWeek == game.week ? nil : game.week
                                    }
                                } label: {
                                    ByeWeekRowView(
                                        week: game.week,
                                        teamColor: teamData.primaryColor
                                    )
                                }
                                .buttonStyle(.plain)
                                .scaleEffect(selectedWeek == game.week ? 1.02 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedWeek)
                            } else {
                                EnhancedGameRowView(
                                    game: game,
                                    teamColor: teamData.primaryColor,
                                    opponentLogoName: getOpponentLogoNameForTeamSchedule(game.opponent),
                                    isSelected: selectedWeek == game.week,
                                    onTap: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            selectedWeek = selectedWeek == game.week ? nil : game.week
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("\(teamName) Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                print("📅 Team Schedule View appeared for \(teamLogoName)")
                let allResults = gameResultsManager.getAllGameResults()
                print("📅 Debug: Found \(allResults.count) stored game results")
            }

        }
    }
}

// MARK: - League Schedule Results View for Hub
struct LeagueScheduleResultsView: View {
    let currentWeek: Int
    let userTeamLogoName: String?
    let userCustomLogoData: Data?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var gameResultsManager = GlobalGameResultsManager.shared
    @State private var selectedWeek: Int = 1
    
    private let allNFLTeams = [
        "Buffalo", "Miami", "NewEngland", "NYA",
        "Baltimore", "Cincinnati", "Cleveland", "Pittsburgh",
        "Houston", "Indianapolis", "Jacksonville", "Tennessee",
        "Denver", "KansasCity", "LasVegas", "LAA",
        "Dallas", "NYN", "Philadelphia", "Washington",
        "Chicago", "Detroit", "GreenBay", "Minnesota",
        "Atlanta", "Carolina", "NewOrleans", "TampaBay",
        "Arizona", "LAN", "SanFrancisco", "Seattle"
    ]
    
    private var allWeeks: [Int] {
        Array(1...18)
    }
    
    private var gamesForSelectedWeek: [(homeTeam: String, awayTeam: String, result: GameResult?)] {
        var games: [(String, String, GameResult?)] = []
        var scheduledTeams: Set<String> = []
        
        let masterLoader = MasterDataLoader.shared
        
        for team in allNFLTeams {
            if scheduledTeams.contains(team) { continue }
            
            let schedule = masterLoader.getSchedule(for: team)
            if let game = schedule.first(where: { $0.week == selectedWeek }) {
                let opponentShortName = getOpponentShortName(game.opponent)
                
                if game.isHome {
                    // Check for game result using the proper method
                    let result = gameResultsManager.getGameResultForTeam(
                        teamName: team,
                        week: selectedWeek,
                        opponent: game.opponent,
                        isHome: game.isHome
                    )
                    
                    // Debug logging
                    print("🏈 League Schedule - Looking for game:")
                    print("   Home Team: \(team)")
                    print("   Away Team: \(opponentShortName)")
                    print("   Week: \(selectedWeek)")
                    print("   Opponent Full Name: \(game.opponent)")
                    print("   Found Result: \(result != nil ? "YES" : "NO")")
                    if let result = result {
                        print("   Score: \(result.homeScore) - \(result.awayScore)")
                    } else {
                        print("   ❌ No result found for this game")
                    }
                    
                    games.append((team, opponentShortName, result))
                    scheduledTeams.insert(team)
                    scheduledTeams.insert(opponentShortName)
                }
            }
        }
        
        return games
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Week Selector
                weekSelectorView
                
                // Games List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(gamesForSelectedWeek.enumerated()), id: \.offset) { index, gameInfo in
                            LeagueGameResultRowView(
                                homeTeam: gameInfo.homeTeam,
                                awayTeam: gameInfo.awayTeam,
                                result: gameInfo.result,
                                userTeamLogoName: userTeamLogoName,
                                userCustomLogoData: userCustomLogoData
                            )
                        }
                        
                        if gamesForSelectedWeek.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                
                                Text("No games scheduled")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Text("Week \(selectedWeek)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("League Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedWeek = max(currentWeek, 1)
            print("📅 League Schedule View appeared for week \(selectedWeek)")
            // Debug: Print all stored games
            let allResults = gameResultsManager.getAllGameResults()
            print("📅 Debug: Found \(allResults.count) stored game results")
        }
    }
    
    private var weekSelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(allWeeks, id: \.self) { week in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedWeek = week
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("Week")
                                .font(.caption2)
                                .fontWeight(.medium)
                            
                            Text("\(week)")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(selectedWeek == week ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedWeek == week ? .blue : Color(.systemGray6))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
    
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

// MARK: - Coach List Row View
struct CoachListRowView: View {
    let rank: Int
    let team: LeagueTeam
    let coach: Coach
    let isUserTeam: Bool
    let userCustomLogoData: Data?
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(rankColor)
                )
            
            // Team Logo
            Group {
                if isUserTeam {
                    TeamLogoView(
                        teamLogoName: team.logoName,
                        customLogoData: userCustomLogoData,
                        size: 40
                    )
                } else {
                    Image(team.logoName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                }
            }
            
            // Coach Info
            VStack(alignment: .leading, spacing: 4) {
                Text(coach.fullName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(TeamData.getTeamDisplayName(team.logoName))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("\(coach.overallRating)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("\(coach.experience)y")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if coach.schemeMatchingBonus > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Match")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Record
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(coach.record.wins)-\(coach.record.losses)" + (coach.record.ties > 0 ? "-\(coach.record.ties)" : ""))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if coach.record.gamesPlayed > 0 {
                    Text(String(format: "%.3f", coach.record.winPercentage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("---")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Corner.medium, style: .continuous)
                .fill(isUserTeam ? Color(hex: team.primaryColor).opacity(0.1) : Color.secondary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: Corner.medium, style: .continuous)
                        .stroke(isUserTeam ? Color(hex: team.primaryColor).opacity(0.3) : .clear, lineWidth: 2)
                )
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2...3: return .gray
        case 4...10: return .blue
        default: return .secondary
        }
    }
}

// MARK: - Coordinator Card View
struct CoordinatorCardView: View {
    let title: String
    let coordinator: String
    let rating: Int
    let scheme: String
    let experience: Int
    let isMatching: Bool
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isMatching {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Match")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(coordinator)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(color)
                            .font(.caption)
                        Text("\(rating)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("\(experience) yrs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 4) {
                    Image(systemName: isMatching ? "arrow.up.right.circle.fill" : "arrow.up.right.circle")
                        .foregroundColor(isMatching ? color : .secondary)
                        .font(.caption)
                    Text(scheme)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isMatching ? color : .secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Corner.medium, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Corner.medium, style: .continuous)
                        .stroke(isMatching ? color.opacity(0.5) : .secondary.opacity(0.2), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - League Game Result Row View for Hub
struct LeagueGameResultRowView: View {
    let homeTeam: String
    let awayTeam: String
    let result: GameResult?
    let userTeamLogoName: String?
    let userCustomLogoData: Data?
    
    private var homeTeamColors: TeamColorMapping.TeamColors {
        TeamColorMapping.getColors(for: homeTeam)
    }
    
    private var awayTeamColors: TeamColorMapping.TeamColors {
        TeamColorMapping.getColors(for: awayTeam)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Away Team
            HStack(spacing: 12) {
                Group {
                    if awayTeam == userTeamLogoName {
                        TeamLogoView(
                            teamLogoName: awayTeam,
                            customLogoData: userCustomLogoData,
                            size: 40
                        )
                    } else {
                        Image(awayTeam)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    }
                }
                
                Text(TeamData.getTeamDisplayName(awayTeam))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Game Status/Score
            VStack(spacing: 4) {
                if let result = result, result.isCompleted {
                    HStack(spacing: 8) {
                        Text("\(result.awayScore)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(result.awayScore > result.homeScore ? .green : .secondary)
                        
                        Text("-")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("\(result.homeScore)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(result.homeScore > result.awayScore ? .green : .secondary)
                    }
                    
                    Text("Final")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("@")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Upcoming")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 80)
            
            // Home Team
            HStack(spacing: 12) {
                Text(TeamData.getTeamDisplayName(homeTeam))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Group {
                    if homeTeam == userTeamLogoName {
                        TeamLogoView(
                            teamLogoName: homeTeam,
                            customLogoData: userCustomLogoData,
                            size: 40
                        )
                    } else {
                        Image(homeTeam)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: awayTeamColors.primary).opacity(0.3), location: 0.0),
                    .init(color: Color(hex: homeTeamColors.primary).opacity(0.3), location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Corner.medium, style: .continuous)
                .stroke(.ultraThinMaterial, lineWidth: 1)
        )
            .continuousClip(Corner.medium)
    }
}
// MARK: - Enhanced Hub Content (Rebuilt from Scratch)
struct EnhancedHubContent: View {
    @EnvironmentObject private var currentLeague: ObservableLeague
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // User Team Logo - Center, no container
            TeamLogoView(
                teamLogoName: currentLeague.teamLogoName,
                customLogoData: currentLeague.customLogoData,
                size: 120
            )
            
            // No Game Status
            Text("No Game")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Enhanced Views Placeholders


struct LeagueSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Season Settings")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Coming Soon")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .glassCard()
    }
}

// MARK: - Navigation Destination Handler
extension LeagueHubView {
    @ViewBuilder
    func destinationView(for destination: NavigationCoordinator.NavigationDestination) -> some View {
        switch destination {
        case .teamManagement(let team, let conference):
            TeamManagementView(teamName: team, conference: conference, leagueId: currentLeague.id)
        case .leagueHub(let team):
            LeagueHubView(teamName: team, teamLogoName: team, customLogoData: nil)
        case .gameSimulation(let home, let away):
            GameSimulationView(
                game: GameResult(
                    week: currentWeek,
                    homeTeam: leagueManager.allTeams.first(where: { $0.logoName == home }) ?? createDefaultTeam(logoName: home),
                    awayTeam: leagueManager.allTeams.first(where: { $0.logoName == away }) ?? createDefaultTeam(logoName: away)
                ),
                onGameCompleted: { _ in }
            )
        case .settings:
            SettingsView()
        case .createLeague:
            CreateLeagueView()
        case .loadLeague:
            LoadLeagueView()
        }
    }
}

// MARK: - League Team Roster View
struct LeagueTeamRosterView: View {
    let userTeam: LeagueTeam
    let leagueManager: LeagueManager
    let userCustomLogoData: Data?
    let leagueId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPosition: String = "Overview"
    @StateObject private var masterDataLoader = MasterDataLoader.shared
    @State private var refreshTrigger = UUID()
    
    private var positions: [String] {
        let basePositions = ["Overview"]
        let maddenPositionOrder = ["QB", "RB", "FB", "WR", "TE", "LT", "LG", "C", "RG", "RT", "MLB", "ROLB", "LOLB", "EDGE", "DE", "DT", "CB", "SS", "FS", "K", "P"]
        
        let realPlayers = masterDataLoader.getPlayers(for: userTeam.logoName)
        
        if !realPlayers.isEmpty {
            let realPositions = Set(realPlayers.map { $0.position })
            let orderedPositions = maddenPositionOrder.filter { realPositions.contains($0) }
            return basePositions + orderedPositions
        } else {
            return basePositions + maddenPositionOrder
        }
    }
    
    private var filteredPlayers: [PlayerData] {
        // Use hybrid approach: edited player data first, then master data fallback
        let playersToUse = getTeamPlayers()
        
        if selectedPosition == "Overview" {
            return [] // Return empty for overview - we'll show the overview cards instead
        } else {
            return playersToUse.filter { $0.position == selectedPosition }.sorted { 
                if $0.overall != $1.overall {
                    return $0.overall > $1.overall
                }
                return $0.fullName < $1.fullName // Stable tie-breaker
            }
        }
    }
    
    private func generateSamplePlayers() -> [PlayerData] {
        // Generate sample players for the team
        var samplePlayers: [PlayerData] = []
        
        // QB
        samplePlayers.append(PlayerData(firstName: "Sample", lastName: "Quarterback", position: "QB", number: 1, overall: 85, age: 26))
        
        // RB
        samplePlayers.append(PlayerData(firstName: "Sample", lastName: "Running Back", position: "RB", number: 21, overall: 82, age: 24))
        
        // WR
        samplePlayers.append(PlayerData(firstName: "Sample", lastName: "Wide Receiver", position: "WR", number: 11, overall: 83, age: 25))
        
        return samplePlayers
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Team Header
                    LeagueRosterTeamHeaderView(
                        userTeam: userTeam,
                        userCustomLogoData: userCustomLogoData
                    )
                    
                    // Roster Content
                    VStack(spacing: 20) {
                        rosterContent
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
            }
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Team Roster")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .playerDataDidChange)) { notification in
                // Check if this notification is for our team
                if let teamLogoName = notification.userInfo?["teamLogoName"] as? String,
                   teamLogoName == userTeam.logoName {
                    print("🔄 LeagueTeamRosterView: Received player data change notification for \(teamLogoName)")
                    
                    // Don't refresh if a player detail view is currently open for this team
                    if PlayerDetailViewStateManager.shared.isPlayerDetailViewOpen,
                       let openTeam = PlayerDetailViewStateManager.shared.openPlayerDetailInfo?.teamLogoName,
                       openTeam == teamLogoName {
                        print("🔒 LeagueTeamRosterView: Skipping roster refresh - player detail view is open for \(teamLogoName)")
                        return
                    }
                    
                    // Add delay to allow PlayerDetailView to remain stable
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        refreshPlayerData()
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PlayerReleased"))) { notification in
            // Check if this notification is for our team
            if let teamLogoName = notification.userInfo?["teamLogoName"] as? String,
               teamLogoName == userTeam.logoName {
                print("🚫 LeagueTeamRosterView: Player released from \(teamLogoName) - refreshing roster immediately")
                
                // Immediate refresh since the player detail view is already dismissed
                refreshPlayerData()
            }
        }
    }
    
    private var rosterContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            rosterHeader
            
            if selectedPosition == "Overview" {
                teamOverviewContent
            } else {
                playerList
            }
        }
        .id(refreshTrigger)
    }
    
    private var rosterHeader: some View {
        HStack {
            if selectedPosition != "Overview" {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            Text(selectedPosition == "Overview" ? "Team Overview" : "Team Roster")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Position Filter Dropdown
            positionFilterDropdown
            
            Spacer()
        }
    }
    
    private var positionFilterDropdown: some View {
        Menu {
            ForEach(positions, id: \.self) { position in
                Button(action: {
                    selectedPosition = position
                }) {
                    HStack {
                        Text(position)
                        if position == selectedPosition {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(selectedPosition)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .continuousClip(Corner.small)
        }
    }
    
    private var teamOverviewContent: some View {
        let teamPlayers = getTeamPlayers()
        let teamOveralls = calculateTeamOveralls(players: teamPlayers)
        let topPlayers = getTopPlayers(players: teamPlayers)
        
        // Debug: Log team overalls calculation  
        let _ = print("📊 \(userTeam.logoName) Team Overalls: Offense: \(teamOveralls.offense), Defense: \(teamOveralls.defense), Overall: \(teamOveralls.overall) (Players: \(teamPlayers.count))")
        
        return VStack(alignment: .leading, spacing: 24) {
            // Team Overalls Section
            TeamOverallsCard(
                teamOveralls: teamOveralls,
                teamColor: userTeam.primaryColor
            )
            
            // Salary Section
            TeamSalaryCard(
                teamLogoName: userTeam.logoName,
                teamColor: userTeam.primaryColor
            )
            
            // Top Players Section
            TopPlayersCard(
                players: topPlayers,
                teamColor: userTeam.primaryColor
            )
        }
        .id(refreshTrigger) // Force refresh when trigger changes
    }
    
    private var playerList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredPlayers) { player in
                OptimizedPlayerRow(
                    player: OptimizedPlayerRow.PlayerRowData(
                        id: "\(player.firstName)_\(player.lastName)_\(player.number)",
                        name: player.fullName,
                        position: player.position,
                        number: player.number,
                        overall: player.overall,
                        age: player.age
                    ),
                    teamColor: userTeam.primaryColor,
                    teamLogoName: userTeam.logoName,
                    leagueId: leagueId,
                    onPlayerUpdated: {
                        refreshPlayerData()
                    }
                )
            }
        }
        .id(refreshTrigger)
    }
    
    // MARK: - Helper Methods
    private func getTeamPlayers() -> [PlayerData] {
        // Use hybrid approach: edited player data first, then master data fallback
        let editedPlayers = PlayerDataManager.shared.getPlayers(for: userTeam.logoName, leagueId: leagueId)
        
        if !editedPlayers.isEmpty {
            return editedPlayers
        } else {
            // Fallback to master data
            let realPlayers = masterDataLoader.getPlayers(for: userTeam.logoName)
            
            if !realPlayers.isEmpty {
                return realPlayers.map { player in
                    PlayerData(
                        firstName: player.firstName,
                        lastName: player.lastName,
                        position: player.position,
                        number: Int(player.jerseyNum) ?? 1,
                        overall: player.overallInt,
                        age: player.ageInt
                    )
                }
            } else {
                return generateSamplePlayers()
            }
        }
    }
    
    private func calculateTeamOveralls(players: [PlayerData]) -> (offense: Int, defense: Int, overall: Int) {
        // Separate players into offensive and defensive units
        let offensivePlayers = players.filter { ["QB", "RB", "FB", "WR", "TE", "LT", "LG", "C", "RG", "RT"].contains($0.position) }
        let defensivePlayers = players.filter { ["MLB", "ROLB", "LOLB", "EDGE", "DE", "DT", "CB", "SS", "FS"].contains($0.position) }
        
        // Calculate unit ratings
        let offenseOverall = calculateUnitRating(players: offensivePlayers, isOffense: true)
        let defenseOverall = calculateUnitRating(players: defensivePlayers, isOffense: false)
        
        // Calculate overall team rating
        let specialTeamsPlayers = players.filter { ["K", "P"].contains($0.position) }
        let specialTeamsRating = calculateSpecialTeamsRating(players: specialTeamsPlayers)
        
        // Weight the units (Offense: 45%, Defense: 45%, Special Teams: 10%)
        let rawTeamRating = (Double(offenseOverall) * 0.45) + (Double(defenseOverall) * 0.45) + (specialTeamsRating * 0.10)
        let teamOverall = Int(round(rawTeamRating))
        
        return (offenseOverall, defenseOverall, teamOverall)
    }
    
    private func calculateUnitRating(players: [PlayerData], isOffense: Bool) -> Int {
        guard !players.isEmpty else { return 70 }
        
        // Position weights for each unit
        let positionWeights: [String: Double] = isOffense ? [
            "QB": 3.0, "RB": 1.5, "FB": 1.0, "WR": 2.0, "TE": 1.3,
            "LT": 2.0, "LG": 1.2, "C": 1.3, "RG": 1.2, "RT": 2.0
        ] : [
            "MLB": 2.0, "ROLB": 1.5, "LOLB": 1.5, "EDGE": 2.0, "DE": 1.5,
            "DT": 1.3, "CB": 2.0, "SS": 1.5, "FS": 1.5
        ]
        
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        let playersByPosition = Dictionary(grouping: players, by: { $0.position })
        
        for (position, positionPlayers) in playersByPosition {
            let weight = positionWeights[position] ?? 1.0
            let sortedPlayers = positionPlayers.sorted { $0.overall > $1.overall }
            
            // Take top players at each position
            let playersToConsider = Array(sortedPlayers.prefix(min(2, sortedPlayers.count)))
            
            for (index, player) in playersToConsider.enumerated() {
                let depthMultiplier = index == 0 ? 1.0 : 0.6
                let playerWeight = weight * depthMultiplier
                
                weightedSum += Double(player.overall) * playerWeight
                totalWeight += playerWeight
            }
        }
        
        let unitRating = totalWeight > 0 ? weightedSum / totalWeight : 70.0
        return Int(round(unitRating))
    }
    
    private func calculateSpecialTeamsRating(players: [PlayerData]) -> Double {
        let kickers = players.filter { $0.position == "K" }
        let punters = players.filter { $0.position == "P" }
        
        let kickerRating = kickers.isEmpty ? 75.0 : Double(kickers.max { $0.overall < $1.overall }?.overall ?? 75)
        let punterRating = punters.isEmpty ? 75.0 : Double(punters.max { $0.overall < $1.overall }?.overall ?? 75)
        
        return (kickerRating + punterRating) / 2.0
    }
    
    private func getTopPlayers(players: [PlayerData]) -> [PlayerData] {
        return players.sorted { $0.overall > $1.overall }.prefix(5).map { $0 }
    }
    
    private func refreshPlayerData() {
        print("🔄 Refreshing player data for \(userTeam.logoName)")
        
        // Force PlayerDataManager to reload data from files
        PlayerDataManager.shared.clearCache()
        
        // Trigger view refresh
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.refreshTrigger = UUID()
            }
            print("🔄 Refresh trigger updated: \(self.refreshTrigger)")
        }
    }
}

// MARK: - League Roster Team Header View
struct LeagueRosterTeamHeaderView: View {
    let userTeam: LeagueTeam
    let userCustomLogoData: Data?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                // Team Logo
                TeamLogoView(
                    teamLogoName: userTeam.logoName,
                    customLogoData: userCustomLogoData,
                    size: 80
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    // Team Name
                    Text(TeamData.getTeamDisplayName(userTeam.logoName))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Team Record
                    Text("\(userTeam.record.wins)-\(userTeam.record.losses)" + (userTeam.record.ties > 0 ? "-\(userTeam.record.ties)" : ""))
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    
                    // Team Conference/Division with separator
                    HStack(spacing: 8) {
                        Text(userTeam.conference)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("•")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(userTeam.division)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: userTeam.primaryColor), location: 0.0),
                        .init(color: Color(hex: userTeam.secondaryColor), location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .continuousClip(Corner.large)
        }
        .padding(.horizontal)
    }
}

// MARK: - Team Salary Card
struct TeamSalaryCard: View {
    let teamLogoName: String
    let teamColor: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Salary Cap")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                // Total Cap
                StatCard(
                    title: "Total Cap",
                    value: "$\(Int(NFLCapData.salaryCap / 1_000_000))M",
                    style: .highlighted(.blue)
                )
                
                // Spent Space
                StatCard(
                    title: "Spent Space",
                    value: "$\(Int(NFLCapData.getCapSpending(for: teamLogoName) / 1_000_000))M",
                    style: .highlighted(.orange)
                )
                
                // Cap Remaining
                StatCard(
                    title: "Cap Remaining",
                    value: formatCapSpace(NFLCapData.getCapSpace(for: teamLogoName)),
                    style: .highlighted(.green)
                )
                
                // Dead Cap Space (simplified calculation)
                StatCard(
                    title: "Dead Cap",
                    value: "$\(Int(calculateDeadCap(for: teamLogoName) / 1_000_000))M",
                    style: .highlighted(.red)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .standardCard(.ultraThin16)
    }
    
    private func formatCapSpace(_ cap: Int) -> String {
        let millions = Double(cap) / 1_000_000.0
        let formatted = String(format: "%.0fM", abs(millions))
        return cap < 0 ? "-$\(formatted)" : "$\(formatted)"
    }
    
    private func calculateDeadCap(for teamLogoName: String) -> Int {
        return LeagueHubHelpers.calculateDeadCap(for: teamLogoName)
    }
}

struct PlayoffRaceView: View {
    @ObservedObject var leagueManager: LeagueManager
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("ACFT Playoff Picture")) {
                    ForEach(getAFCPlayoffPicture(), id: \.logoName) { team in
                        PlayoffRaceRow(team: team, record: leagueManager.getTeamRecord(for: team.logoName))
                    }
                }
                
                Section(header: Text("NCFT Playoff Picture")) {
                    ForEach(getNFCPlayoffPicture(), id: \.logoName) { team in
                        PlayoffRaceRow(team: team, record: leagueManager.getTeamRecord(for: team.logoName))
                    }
                }
            }
            .navigationTitle("Playoff Race")
        }
    }
    
    private func getAFCPlayoffPicture() -> [LeagueTeam] {
        let afcTeams = leagueManager.allTeams.filter { $0.conference == "ACFT" }
        return afcTeams.sorted { team1, team2 in
            leagueManager.compareTeamRecords(team1: team1, team2: team2)
        }
    }
    
    private func getNFCPlayoffPicture() -> [LeagueTeam] {
        let nfcTeams = leagueManager.allTeams.filter { $0.conference == "NCFT" }
        return nfcTeams.sorted { team1, team2 in
            leagueManager.compareTeamRecords(team1: team1, team2: team2)
        }
    }
}

struct PlayoffRaceRow: View {
    let team: LeagueTeam
    let record: TeamRecord
    
    var body: some View {
        HStack {
            Text(team.name)
                .fontWeight(.medium)
            Spacer()
            Text(record.description)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Playoff Picture Container View
struct PlayoffPictureContainerView: View {
    @ObservedObject var leagueManager: LeagueManager
    let currentWeek: Int
    let selectedTeam: TeamData
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Setting up playoff picture...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    setupPlayoffsIfNeeded()
                }
            } else {
                PlayoffBracketView(
                    leagueManager: leagueManager,
                    selectedTeam: selectedTeam
                )
            }
        }
    }
    
    private func setupPlayoffsIfNeeded() {
        // FIXED: Don't call LeagueManager methods that trigger objectWillChange from the view
        // Just check if we have enough teams and stop loading
        print("🏈 Checking playoff teams for display...")
        
        // Simply check if we have teams to display and stop loading
        isLoading = false
        
        print("🏈 Playoff picture view ready - teams available: \(leagueManager.playoffTeams.count)")
    }
    

}

