import SwiftUI
import Combine

// MARK: - Player Action Object Pool
class PlayerActionPool {
    static let shared = PlayerActionPool()
    private var pool: [PlayerAction] = []
    private let maxPoolSize = 1000
    
    private init() {
        // Pre-populate pool with some objects
        for _ in 0..<100 {
            pool.append(PlayerAction(playerId: "", playerName: "", position: "", statType: .tackle, value: 0))
        }
    }
    
    func getAction(playerId: String, playerName: String, position: String, statType: PlayerAction.PlayerStatType, value: Int) -> PlayerAction {
        if let action = pool.popLast() {
            // Reuse existing object
            action.configure(playerId: playerId, playerName: playerName, position: position, statType: statType, value: value)
            return action
        } else {
            // Create new if pool is empty
            return PlayerAction(playerId: playerId, playerName: playerName, position: position, statType: statType, value: value)
        }
    }
    
    func returnAction(_ action: PlayerAction) {
        if pool.count < maxPoolSize {
            action.reset()
            pool.append(action)
        }
    }
    
    func returnActions(_ actions: [PlayerAction]) {
        for action in actions {
            returnAction(action)
        }
    }
}

// MARK: - Team Roster Cache for Performance
struct CachedTeamRoster {
    let quarterbacks: [MasterPlayer]
    let runningBacks: [MasterPlayer]
    let receivers: [MasterPlayer]       // WR + TE
    let offensiveLine: [MasterPlayer]   // LT, LG, C, RG, RT
    let defensiveBacks: [MasterPlayer]  // CB, SS, FS
    let linebackers: [MasterPlayer]     // MLB, ROLB, LOLB
    let defensiveLine: [MasterPlayer]   // DE, DT
    let kickers: [MasterPlayer]         // K
    let punters: [MasterPlayer]         // P
    
    // Pre-sorted by overall rating for instant access
    let starterQB: MasterPlayer?
    let starterRB: MasterPlayer?
    let starterK: MasterPlayer?
    let starterP: MasterPlayer?
    
    init(players: [MasterPlayer]) {
        // Group players by position
        quarterbacks = players.filter { $0.position == "QB" }.sorted { (Int($0.overall) ?? 0) > (Int($1.overall) ?? 0) }
        runningBacks = players.filter { ["RB", "FB"].contains($0.position) }.sorted { (Int($0.overall) ?? 0) > (Int($1.overall) ?? 0) }
        receivers = players.filter { ["WR", "TE"].contains($0.position) }.sorted { (Int($0.overall) ?? 0) > (Int($1.overall) ?? 0) }
        offensiveLine = players.filter { ["LT", "LG", "C", "RG", "RT"].contains($0.position) }.sorted { (Int($0.overall) ?? 0) > (Int($1.overall) ?? 0) }
        defensiveBacks = players.filter { ["CB", "SS", "FS"].contains($0.position) }.sorted { (Int($0.overall) ?? 0) > (Int($1.overall) ?? 0) }
        linebackers = players.filter { ["MLB", "ROLB", "LOLB"].contains($0.position) }.sorted { (Int($0.overall) ?? 0) > (Int($1.overall) ?? 0) }
        defensiveLine = players.filter { ["DE", "DT"].contains($0.position) }.sorted { (Int($0.overall) ?? 0) > (Int($1.overall) ?? 0) }
        kickers = players.filter { $0.position == "K" }.sorted { (Int($0.overall) ?? 0) > (Int($1.overall) ?? 0) }
        punters = players.filter { $0.position == "P" }.sorted { (Int($0.overall) ?? 0) > (Int($1.overall) ?? 0) }
        
        // Cache starters for instant access
        starterQB = quarterbacks.first
        starterRB = runningBacks.first
        starterK = kickers.first
        starterP = punters.first
    }
}

// MARK: - Player Action Tracking
class PlayerAction: Codable, Identifiable {
    let id = UUID()
    var playerId: String
    var playerName: String
    var position: String
    var statType: PlayerStatType
    var value: Int
    
    init(playerId: String, playerName: String, position: String, statType: PlayerStatType, value: Int) {
        self.playerId = playerId
        self.playerName = playerName
        self.position = position
        self.statType = statType
        self.value = value
    }
    
    func configure(playerId: String, playerName: String, position: String, statType: PlayerStatType, value: Int) {
        self.playerId = playerId
        self.playerName = playerName
        self.position = position
        self.statType = statType
        self.value = value
    }
    
    func reset() {
        self.playerId = ""
        self.playerName = ""
        self.position = ""
        self.statType = .tackle
        self.value = 0
    }
    
    enum PlayerStatType: String, Codable, CaseIterable {
        // Passing
        case passingAttempt = "passingAttempt"
        case passingCompletion = "passingCompletion"
        case passingYards = "passingYards"
        case passingTouchdown = "passingTouchdown"
        case interceptionThrown = "interceptionThrown"
        case sackTaken = "sackTaken"
        
        // Rushing
        case rushingAttempt = "rushingAttempt"
        case rushingYards = "rushingYards"
        case rushingTouchdown = "rushingTouchdown"
        case fumble = "fumble"
        
        // Receiving
        case reception = "reception"
        case receivingYards = "receivingYards"
        case receivingTouchdown = "receivingTouchdown"
        case target = "target"
        
        // Defensive
        case tackle = "tackle"
        case sackMade = "sackMade"
        case interceptionMade = "interceptionMade"
        case passDefended = "passDefended"
        case forcedFumble = "forcedFumble"
        case fumbleRecovery = "fumbleRecovery"
        
        // Kicking
        case fieldGoalAttempt = "fieldGoalAttempt"
        case fieldGoalMade = "fieldGoalMade"
        case extraPointAttempt = "extraPointAttempt"
        case extraPointMade = "extraPointMade"
        
        // Punting
        case punt = "punt"
        case puntYards = "puntYards"
    }
    
    private enum CodingKeys: String, CodingKey {
        case playerId, playerName, position, statType, value
    }
}

// MARK: - Game Simulation Engine Type Alias
typealias GameSimulationEngine = AdvancedGameSimulationEngine

// MARK: - Advanced NFL Game Simulation Engine
@MainActor
class AdvancedGameSimulationEngine: ObservableObject {
    @Published var gameState = GameState()
    @Published var simulationSpeed: SimulationSpeed = .normal
    @Published var isSimulating = false
    @Published var currentPlay = PlayResult()
    @Published var gameStats = GameStats()
    @Published var playByPlay: [PlayResult] = []
    
    private var simulationTimer: Timer?
    private var homeTeam: LeagueTeam?
    private var awayTeam: LeagueTeam?
    private var currentWeek: Int = 0
    
    // Player rosters for realistic selection
    private var homeTeamPlayers: [MasterPlayer] = []
    private var awayTeamPlayers: [MasterPlayer] = []
    
    // Cached rosters for performance optimization
    private var homeTeamRoster: CachedTeamRoster?
    private var awayTeamRoster: CachedTeamRoster?
    
    // MARK: - Enhanced Game State
    struct GameState {
        var homeTeam: TeamGameData = TeamGameData()
        var awayTeam: TeamGameData = TeamGameData()
        var currentQuarter: Int = 1
        var timeRemaining: String = "15:00"
        var possession: TeamSide = .home
        var down: Int = 1
        var yardsToGo: Int = 10
        var fieldPosition: Int = 25  // Distance from own goal line
        var homeScore: Int = 0
        var awayScore: Int = 0
        var isGameOver: Bool = false
        var isTwoMinuteWarning: Bool = false
        var isRedZone: Bool = false
        var lastPlay: String = ""
        var driveNumber: Int = 1
        var currentDrive: DriveData = DriveData()
        
        enum TeamSide: String, CaseIterable {
            case home = "home"
            case away = "away"
            
            var opposite: TeamSide {
                return self == .home ? .away : .home
            }
        }
        
        mutating func switchPossession() {
            possession = possession.opposite
            down = 1
            yardsToGo = 10
            driveNumber += 1
            currentDrive = DriveData()
        }
    }
    
    // MARK: - Enhanced Team Data
    struct TeamGameData {
        var name: String = ""
        var logoName: String = ""
        var score: Int = 0
        var timeouts: Int = 3
        var stats: TeamStats = TeamStats()
        var overallRating: Int = 80
        var offensiveRating: Int = 80
        var defensiveRating: Int = 80
        var coach: Coach?
        var playbook: Playbook = Playbook()
        
        struct TeamStats {
            // Passing Stats
            var passingYards: Int = 0
            var passingAttempts: Int = 0
            var passingCompletions: Int = 0
            var passingTouchdowns: Int = 0
            var interceptions: Int = 0
            var sacks: Int = 0
            var sacksAllowed: Int = 0
            
            // Rushing Stats
            var rushingYards: Int = 0
            var rushingAttempts: Int = 0
            var rushingTouchdowns: Int = 0
            var fumbles: Int = 0
            var fumblesLost: Int = 0
            
            // General Stats
            var totalYards: Int = 0
            var firstDowns: Int = 0
            var thirdDownAttempts: Int = 0
            var thirdDownConversions: Int = 0
            var fourthDownAttempts: Int = 0
            var fourthDownConversions: Int = 0
            var redZoneAttempts: Int = 0
            var redZoneScores: Int = 0
            var penalties: Int = 0
            var penaltyYards: Int = 0
            var turnovers: Int = 0
            var timeOfPossession: TimeInterval = 0
            
            // Kicking Stats
            var fieldGoalAttempts: Int = 0
            var fieldGoalsMade: Int = 0
            var extraPointAttempts: Int = 0
            var extraPointsMade: Int = 0
            var punts: Int = 0
            var puntYards: Int = 0
            
            var completionPercentage: Double {
                guard passingAttempts > 0 else { return 0.0 }
                return Double(passingCompletions) / Double(passingAttempts) * 100.0
            }
            
            var thirdDownPercentage: Double {
                guard thirdDownAttempts > 0 else { return 0.0 }
                return Double(thirdDownConversions) / Double(thirdDownAttempts) * 100.0
            }
            
            var redZonePercentage: Double {
                guard redZoneAttempts > 0 else { return 0.0 }
                return Double(redZoneScores) / Double(redZoneAttempts) * 100.0
            }
        }
    }
    
    // MARK: - Play System
    struct PlayResult {
        var id = UUID()
        var quarter: Int = 1
        var time: String = "15:00"
        var down: Int = 1
        var distance: Int = 10
        var fieldPosition: Int = 25
        var playType: PlayType = .rush
        var description: String = ""
        var yardGain: Int = 0
        var isScoring: Bool = false
        var isTurnover: Bool = false
        var isFirstDown: Bool = false
        var isPenalty: Bool = false
        var penaltyYards: Int = 0
        var possessionTeam: GameState.TeamSide = .home
        var defensivePlay: DefensivePlay = .base
        var offensivePlay: OffensivePlay = .run
        
        // Player involvement tracking
        var playerActions: [PlayerAction] = []
        var primaryOffensivePlayer: PlayerAction?    // QB, RB, or primary receiver
        var primaryDefensivePlayer: PlayerAction?    // Primary tackler or defender
        
        enum PlayType: String, CaseIterable {
            case rush = "Rush"
            case pass = "Pass"
            case punt = "Punt"
            case fieldGoal = "Field Goal"
            case extraPoint = "Extra Point"
            case kickoff = "Kickoff"
            case safety = "Safety"
            case touchdown = "Touchdown"
            case interception = "Interception"
            case fumble = "Fumble"
            case sack = "Sack"
            case penalty = "Penalty"
        }
        
        enum DefensivePlay: String, CaseIterable {
            case base = "Base Defense"
            case blitz = "Blitz"
            case coverage = "Coverage"
            case goalLine = "Goal Line"
            case prevent = "Prevent"
        }
        
        enum OffensivePlay: String, CaseIterable {
            case run = "Run"
            case shortPass = "Short Pass"
            case mediumPass = "Medium Pass"
            case deepPass = "Deep Pass"
            case screen = "Screen"
            case draw = "Draw"
        }
    }
    
    // MARK: - Drive Tracking
    struct DriveData {
        var id = UUID()
        var startingField: Int = 25
        var plays: [PlayResult] = []
        var totalYards: Int = 0
        var timeElapsed: TimeInterval = 0
        var result: DriveResult = .inProgress
        
        enum DriveResult: String {
            case inProgress = "In Progress"
            case touchdown = "Touchdown"
            case fieldGoal = "Field Goal"
            case punt = "Punt"
            case turnover = "Turnover"
            case safety = "Safety"
            case endOfHalf = "End of Half"
        }
    }
    
    // MARK: - Team Playbooks
    struct Playbook {
        var runPlays: [String] = [
            "Inside Zone", "Outside Zone", "Power Run", "Draw Play", "Sweep",
            "Dive", "Counter", "Trap", "Pitch", "Quarterback Sneak"
        ]
        
        var passPlays: [String] = [
            "Slant", "Hitch", "Comeback", "Out Route", "Post", "Go Route",
            "Cross", "Drag", "Fade", "Screen Pass", "Play Action", "Bootleg"
        ]
        
        var formations: [String] = [
            "I-Formation", "Shotgun", "Pistol", "Singleback", "Gun Trips",
            "Empty Backfield", "Wildcat", "Goal Line"
        ]
    }
    
    // MARK: - Game Statistics
    struct GameStats {
        var totalPlays: Int = 0
        var gameTime: TimeInterval = 0
        var drives: [DriveData] = []
        var scoringPlays: [PlayResult] = []
        var turnovers: [PlayResult] = []
        var bigPlays: [PlayResult] = []  // 20+ yard plays
        var homeTeamStats: TeamGameData.TeamStats = TeamGameData.TeamStats()
        var awayTeamStats: TeamGameData.TeamStats = TeamGameData.TeamStats()
        
        var totalYards: (home: Int, away: Int) {
            return (homeTeamStats.totalYards, awayTeamStats.totalYards)
        }
        
        var turnoversCount: (home: Int, away: Int) {
            return (homeTeamStats.turnovers, awayTeamStats.turnovers)
        }
    }
    
    // MARK: - Simulation Speed
    enum SimulationSpeed: String, CaseIterable {
        case slow = "Slow"
        case normal = "Normal"
        case fast = "Fast"
        case instant = "Instant"
        
        var interval: TimeInterval {
            switch self {
            case .slow: return 3.0
            case .normal: return 1.5
            case .fast: return 0.5
            case .instant: return 0.1
            }
        }
    }
    
    // MARK: - Public Interface
    func startSimulation(homeTeam: LeagueTeam, awayTeam: LeagueTeam) {
        initializeGame(homeTeam: homeTeam, awayTeam: awayTeam)
        startSimulationTimer()
    }
    
    func simulateCompleteGame(homeTeam: LeagueTeam, awayTeam: LeagueTeam, week: Int = 0) -> GameResult {
        self.currentWeek = week
        initializeGame(homeTeam: homeTeam, awayTeam: awayTeam)
        
        // Simulate entire game instantly without UI updates or timers
        let maxPlays = 200 // Safety limit to prevent infinite loops
        var playCount = 0
        
        while !gameState.isGameOver && playCount < maxPlays {
            simulatePlayInstantly()
            playCount += 1
        }
        
        return createGameResult()
    }
    
    func pauseSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        isSimulating = false
    }
    
    func resumeSimulation() {
        if !gameState.isGameOver {
            startSimulationTimer()
        }
    }
    
    // MARK: - Game Initialization
    private func initializeGame(homeTeam: LeagueTeam, awayTeam: LeagueTeam) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        
        // Load player rosters for realistic simulation
        homeTeamPlayers = MasterDataLoader.shared.getPlayers(for: homeTeam.logoName)
        awayTeamPlayers = MasterDataLoader.shared.getPlayers(for: awayTeam.logoName)
        
        // Build cached rosters for performance optimization
        homeTeamRoster = CachedTeamRoster(players: homeTeamPlayers)
        awayTeamRoster = CachedTeamRoster(players: awayTeamPlayers)
        
        // Initialize game state
        gameState = GameState()
        gameState.homeTeam.name = homeTeam.name
        gameState.homeTeam.logoName = homeTeam.logoName
        gameState.homeTeam.overallRating = homeTeam.overallRating
        gameState.homeTeam.coach = homeTeam.coach
        
        gameState.awayTeam.name = awayTeam.name
        gameState.awayTeam.logoName = awayTeam.logoName
        gameState.awayTeam.overallRating = awayTeam.overallRating
        gameState.awayTeam.coach = awayTeam.coach
        
        // Calculate unit ratings
        calculateUnitRatings()
        
        // Reset statistics
        gameStats = GameStats()
        playByPlay = []
        
        // Opening kickoff
        gameState.possession = Bool.random() ? .home : .away
        gameState.fieldPosition = 25
        gameState.lastPlay = "Opening kickoff"
        
        // Game initialization logging removed to prevent rate limiting
    }
    
    private func calculateUnitRatings() {
        // Calculate offensive and defensive ratings from team overall
        let homeRating = gameState.homeTeam.overallRating
        let awayRating = gameState.awayTeam.overallRating
        
        // Add some variance for offensive/defensive specialization
        gameState.homeTeam.offensiveRating = homeRating + Int.random(in: -5...5)
        gameState.homeTeam.defensiveRating = homeRating + Int.random(in: -5...5)
        gameState.awayTeam.offensiveRating = awayRating + Int.random(in: -5...5)
        gameState.awayTeam.defensiveRating = awayRating + Int.random(in: -5...5)
    }
    
    // MARK: - Player Selection Methods
    private func getCurrentOffensivePlayers() -> [MasterPlayer] {
        return gameState.possession == .home ? homeTeamPlayers : awayTeamPlayers
    }
    
    private func getCurrentDefensivePlayers() -> [MasterPlayer] {
        return gameState.possession == .home ? awayTeamPlayers : homeTeamPlayers
    }
    
    private func selectStartingQB(from players: [MasterPlayer]) -> MasterPlayer? {
        // Use cached roster if available for performance
        if gameState.possession == .home {
            return homeTeamRoster?.starterQB
        } else {
            return awayTeamRoster?.starterQB
        }
    }
    
    private func selectRunningBack(from players: [MasterPlayer], situation: GameSituation) -> MasterPlayer? {
        // Use cached roster for performance
        let roster = gameState.possession == .home ? homeTeamRoster : awayTeamRoster
        guard let runningBacks = roster?.runningBacks, !runningBacks.isEmpty else { return nil }
        
        // Goal line situations favor fullbacks
        if situation.isGoalLine {
            if let fb = runningBacks.first(where: { $0.position == "FB" }) {
                return fb
            }
        }
        
        // Otherwise return best RB (already sorted by rating in cache)
        return runningBacks.first(where: { $0.position == "RB" })
    }
    
    private func selectReceiver(from players: [MasterPlayer], situation: GameSituation) -> MasterPlayer? {
        // Use cached roster for performance
        let roster = gameState.possession == .home ? homeTeamRoster : awayTeamRoster
        guard let receivers = roster?.receivers, !receivers.isEmpty else { return nil }
        
        // Red zone and goal line favor tight ends
        if situation.isRedZone || situation.isGoalLine {
            let tightEnds = receivers.filter { $0.position == "TE" }
            if !tightEnds.isEmpty && Double.random(in: 0...1) < 0.4 {
                return tightEnds.first // Already sorted by rating in cache
            }
        }
        
        // Distribute among wide receivers with weighted selection (better players get more targets)
        let wideReceivers = receivers.filter { $0.position == "WR" }
        if !wideReceivers.isEmpty {
            return selectWeightedReceiver(from: wideReceivers)
        }
        
        // Fallback to any receiver with weighted selection
        return selectWeightedReceiver(from: receivers)
    }
    
    private func selectWeightedReceiver(from receivers: [MasterPlayer]) -> MasterPlayer? {
        guard !receivers.isEmpty else { return nil }
        
        // Create weighted distribution - more realistic NFL target distribution
        var weights: [Double] = []
        for (index, receiver) in receivers.enumerated() {
            let rating = Int(receiver.overall) ?? 75
            // More realistic distribution: Top receiver gets 35%, 2nd gets 22%, others split remaining
            let baseWeight = index == 0 ? 0.35 : (index == 1 ? 0.22 : 0.43 / Double(max(1, receivers.count - 2)))
            // Smaller rating adjustment (±15%)
            let ratingMultiplier = 1.0 + (Double(rating - 75) / 500.0)
            weights.append(baseWeight * ratingMultiplier)
        }
        
        // Select based on weights
        let totalWeight = weights.reduce(0, +)
        let randomValue = Double.random(in: 0...totalWeight)
        var currentWeight = 0.0
        
        for (index, weight) in weights.enumerated() {
            currentWeight += weight
            if randomValue <= currentWeight {
                return receivers[index]
            }
        }
        
        return receivers.first // Fallback
    }
    
    private func selectDefender(from players: [MasterPlayer], playType: PlayResult.PlayType) -> MasterPlayer? {
        // Use cached roster for performance (defending team is opposite of possession)
        let roster = gameState.possession == .home ? awayTeamRoster : homeTeamRoster
        
        switch playType {
        case .pass:
            // Pass coverage - prefer DBs
            if let defensiveBacks = roster?.defensiveBacks, !defensiveBacks.isEmpty {
                return defensiveBacks.randomElement()
            }
            // Fallback to linebackers
            return roster?.linebackers.randomElement()
            
        case .rush:
            // Run defense - prefer linebackers and safeties
            if let linebackers = roster?.linebackers, !linebackers.isEmpty {
                return linebackers.randomElement()
            }
            // Include safeties for run defense
            if let defensiveBacks = roster?.defensiveBacks {
                let safeties = defensiveBacks.filter { ["SS", "FS"].contains($0.position) }
                if !safeties.isEmpty {
                    return safeties.randomElement()
                }
            }
            // Fallback to defensive line
            return roster?.defensiveLine.randomElement()
            
        default:
            // Generic defender - prefer linebackers
            if let linebackers = roster?.linebackers, !linebackers.isEmpty {
                return linebackers.randomElement()
            }
            return roster?.defensiveBacks.randomElement()
        }
    }
    
    private func selectKicker(from players: [MasterPlayer]) -> MasterPlayer? {
        // Use cached roster for performance
        let roster = gameState.possession == .home ? homeTeamRoster : awayTeamRoster
        return roster?.starterK
    }
    
    private func selectPunter(from players: [MasterPlayer]) -> MasterPlayer? {
        // Use cached roster for performance
        let roster = gameState.possession == .home ? homeTeamRoster : awayTeamRoster
        return roster?.starterP
    }
    
    // MARK: - Player Performance Calculation Methods
    private func calculatePlaySuccess(offense: Int, defense: Int, baseSuccess: Bool) -> Bool {
        // Calculate success probability based on player ratings
        let offenseAdvantage = Double(offense - defense) / 100.0
        let baseProbability = baseSuccess ? 0.6 : 0.4
        let adjustedProbability = baseProbability + (offenseAdvantage * 0.2)
        let clampedProbability = max(0.1, min(0.9, adjustedProbability))
        
        return Double.random(in: 0...1) < clampedProbability
    }
    
    private func calculateRushingYards(runningBack: MasterPlayer, situation: GameSituation) -> Int {
        let rbRating = Int(runningBack.overall) ?? 75
        let baseYards = situation.isShortYardage ? Int.random(in: 1...8) : Int.random(in: 2...12)
        
        // Higher rated players have better chance for big plays and consistent yardage
        let ratingBonus = Double(rbRating - 75) / 100.0  // -0.25 to +0.25 for ratings 50-100
        let adjustedYards = Double(baseYards) * (1.0 + ratingBonus)
        
        var finalYards = Int(adjustedYards)
        
        // Big play chance based on player rating
        let bigPlayChance = 0.05 + (ratingBonus * 0.1)  // 5-15% chance based on rating
        if Double.random(in: 0...1) < bigPlayChance {
            finalYards += Int.random(in: 10...30)
        }
        
        return max(0, finalYards)
    }
    
    private func calculatePassingYards(quarterback: MasterPlayer, receiver: MasterPlayer, situation: GameSituation) -> Int {
        let qbRating = Int(quarterback.overall) ?? 75
        let receiverRating = Int(receiver.overall) ?? 75
        let avgRating = (qbRating + receiverRating) / 2
        
        let baseYards = getPassYardage(for: PlayResult.OffensivePlay.shortPass)  // Default to short pass
        let ratingBonus = Double(avgRating - 75) / 100.0
        let adjustedYards = Double(baseYards) * (1.0 + ratingBonus)
        
        var finalYards = Int(adjustedYards)
        
        // Big play chance
        let bigPlayChance = 0.1 + (ratingBonus * 0.15)
        if Double.random(in: 0...1) < bigPlayChance {
            finalYards += Int.random(in: 15...40)
        }
        
        return max(0, finalYards)
    }
    
    // MARK: - Simulation Engine
    private func startSimulationTimer() {
        isSimulating = true
        simulationTimer = Timer.scheduledTimer(withTimeInterval: simulationSpeed.interval, repeats: true) { _ in
            Task { @MainActor in
                self.simulatePlay()
            }
        }
    }
    
    private func simulatePlay() {
        guard !gameState.isGameOver else {
            pauseSimulation()
            return
        }
        
        var play = generateRealisticPlay()
        play = processPlay(play)
        currentPlay = play
        updateGameStats(with: play)
        playByPlay.append(play)
        
        checkGameEndConditions()
        
        // Only provide haptic feedback during interactive simulation, not automated simulation
        if simulationSpeed != .instant {
            provideHapticFeedback(for: play)
        }
    }
    
    // MARK: - Optimized Play Generation Using Templates
    private func generateRealisticPlay() -> PlayResult {
        let situation = GameSituation(
            down: gameState.down,
            distance: gameState.yardsToGo,
            fieldPosition: gameState.fieldPosition,
            quarter: gameState.currentQuarter,
            timeRemaining: gameState.timeRemaining,
            scoreDifference: gameState.homeScore - gameState.awayScore,
            possession: gameState.possession
        )
        
        return generatePlayFromTemplate(situation)
    }
    
    private func generatePlayFromTemplate(_ situation: GameSituation) -> PlayResult {
        // Get appropriate templates for this situation
        let templates = PlayTemplateManager.shared.getTemplatesForSituation(situation)
        
        // Handle fourth down specially (punt/FG logic)
        if situation.down == 4 {
            return handleFourthDown(situation, PlayResult())
        }
        
        // Select a random template weighted by situation appropriateness
        guard let selectedTemplate = selectTemplate(from: templates, situation: situation) else {
            // Fallback to original logic if no template matches
            return selectPlayBasedOnSituation(situation)
        }
        
        // Generate play from template
        return createPlayFromTemplate(selectedTemplate, situation: situation)
    }
    
    private func selectTemplate(from templates: [PlayTemplate], situation: GameSituation) -> PlayTemplate? {
        // Weight templates based on situational appropriateness
        var weightedTemplates: [(template: PlayTemplate, weight: Double)] = []
        
        for template in templates {
            let weight = calculateTemplateWeight(template, situation: situation)
            if weight > 0 {
                weightedTemplates.append((template: template, weight: weight))
            }
        }
        
        // Select randomly based on weights
        let totalWeight = weightedTemplates.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return templates.randomElement() }
        
        let randomValue = Double.random(in: 0...totalWeight)
        var currentWeight = 0.0
        
        for weightedTemplate in weightedTemplates {
            currentWeight += weightedTemplate.weight
            if randomValue <= currentWeight {
                return weightedTemplate.template
            }
        }
        
        return weightedTemplates.last?.template
    }
    
    private func calculateTemplateWeight(_ template: PlayTemplate, situation: GameSituation) -> Double {
        var weight = 1.0
        
        // Adjust weight based on situation
        if situation.isGoalLine && template.situationType == .goalLine {
            weight *= 3.0
        } else if situation.isRedZone && template.situationType == .redZone {
            weight *= 2.5
        } else if situation.isTwoMinute && template.situationType == .twoMinute {
            weight *= 2.0
        }
        
        // Adjust for down and distance preferences
        switch (situation.down, situation.isLongDistance) {
        case (1, false): // 1st and 10
            weight *= template.playType == .rush ? 1.2 : 1.0
        case (1, true): // 1st and long
            weight *= template.playType == .pass ? 1.5 : 0.7
        case (2, true): // 2nd and long
            weight *= template.playType == .pass ? 1.4 : 0.8
        case (3, false): // 3rd and short
            weight *= template.playType == .rush ? 1.1 : 1.0
        case (3, true): // 3rd and long
            weight *= template.playType == .pass ? 1.8 : 0.3
        default:
            break
        }
        
        return weight
    }
    
    private func createPlayFromTemplate(_ template: PlayTemplate, situation: GameSituation) -> PlayResult {
        var play = PlayResult()
        play.quarter = situation.quarter
        play.time = situation.timeRemaining
        play.down = situation.down
        play.distance = situation.distance
        play.fieldPosition = situation.fieldPosition
        play.possessionTeam = situation.possession
        play.playType = template.playType
        play.offensivePlay = template.offensivePlay
        
        // Apply team strength modifiers
        let offensiveTeam = getOffensiveTeam()
        let defensiveTeam = getDefensiveTeam()
        let strengthDifference = Double(offensiveTeam.offensiveRating - defensiveTeam.defensiveRating)
        
        // Adjust success rate based on team strength
        let adjustedSuccessRate = template.successRate + (strengthDifference * 0.005) // 0.5% per rating point difference
        let success = Double.random(in: 0...1) < max(0.1, min(0.9, adjustedSuccessRate))
        
        // Generate play outcome
        if template.playType == .rush {
            play = simulateRushingPlayFromTemplate(play, template: template, success: success, situation: situation)
        } else {
            play = simulatePassingPlayFromTemplate(play, template: template, success: success, situation: situation)
        }
        
        return play
    }
    
    struct GameSituation {
        let down: Int
        let distance: Int
        let fieldPosition: Int
        let quarter: Int
        let timeRemaining: String
        let scoreDifference: Int
        let possession: GameState.TeamSide
        
        var isRedZone: Bool { fieldPosition >= 80 }
        var isGoalLine: Bool { fieldPosition >= 95 }
        var isTwoMinute: Bool { 
            let components = timeRemaining.split(separator: ":")
            guard let minutes = Int(components[0]) else { return false }
            return quarter >= 2 && minutes <= 2
        }
        var isLongDistance: Bool { distance >= 10 }
        var isShortYardage: Bool { distance <= 3 }
        var isHighPressure: Bool {
            // High pressure situations: 3rd/4th down, two minute drill, close game in red zone, or goal line
            return down >= 3 || isTwoMinute || (abs(scoreDifference) <= 7 && (isRedZone || isGoalLine))
        }
    }
    
    private func selectPlayBasedOnSituation(_ situation: GameSituation) -> PlayResult {
        var play = PlayResult()
        play.quarter = situation.quarter
        play.time = situation.timeRemaining
        play.down = situation.down
        play.distance = situation.distance
        play.fieldPosition = situation.fieldPosition
        play.possessionTeam = situation.possession
        
        // Determine play type based on situation
        if situation.down == 4 {
            return handleFourthDown(situation, play)
        }
        
        if situation.isGoalLine {
            return handleGoalLinePlay(situation, play)
        }
        
        if situation.isRedZone {
            return handleRedZonePlay(situation, play)
        }
        
        if situation.isTwoMinute {
            return handleTwoMinutePlay(situation, play)
        }
        
        return handleRegularPlay(situation, play)
    }
    
    private func handleFourthDown(_ situation: GameSituation, _ play: PlayResult) -> PlayResult {
        var result = play
        
        // Field goal range (roughly 35-yard line and closer)
        if situation.fieldPosition >= 65 && situation.distance <= 8 {
            result.playType = .fieldGoal
            result = simulateFieldGoal(result, situation)
        }
        // Punt situation
        else if situation.fieldPosition < 50 || situation.distance > 5 {
            result.playType = .punt
            result = simulatePunt(result, situation)
        }
        // Go for it (desperation or short yardage)
        else {
            result.playType = Bool.random() ? .rush : .pass
            result = simulateOffensivePlay(result, situation)
        }
        
        return result
    }
    
    private func handleGoalLinePlay(_ situation: GameSituation, _ play: PlayResult) -> PlayResult {
        var result = play
        
        // Goal line favors running
        if Double.random(in: 0...1) < 0.7 {
            result.playType = .rush
            result.offensivePlay = .run
        } else {
            result.playType = .pass
            result.offensivePlay = .shortPass
        }
        
        return simulateOffensivePlay(result, situation)
    }
    
    private func handleRedZonePlay(_ situation: GameSituation, _ play: PlayResult) -> PlayResult {
        var result = play
        
        // Red zone is more balanced but slightly pass-heavy
        if Double.random(in: 0...1) < 0.6 {
            result.playType = .pass
            result.offensivePlay = [.shortPass, .mediumPass].randomElement() ?? .shortPass
        } else {
            result.playType = .rush
            result.offensivePlay = .run
        }
        
        return simulateOffensivePlay(result, situation)
    }
    
    private func handleTwoMinutePlay(_ situation: GameSituation, _ play: PlayResult) -> PlayResult {
        var result = play
        
        // Two-minute drill favors passing
        if Double.random(in: 0...1) < 0.8 {
            result.playType = .pass
            result.offensivePlay = [.shortPass, .mediumPass, .deepPass].randomElement() ?? .shortPass
        } else {
            result.playType = .rush
            result.offensivePlay = .run
        }
        
        return simulateOffensivePlay(result, situation)
    }
    
    private func handleRegularPlay(_ situation: GameSituation, _ play: PlayResult) -> PlayResult {
        var result = play
        
        // Regular play calling based on down and distance
        let passPercentage = getPassPercentage(for: situation)
        
        if Double.random(in: 0...1) < passPercentage {
            result.playType = .pass
            result.offensivePlay = selectPassPlay(for: situation)
        } else {
            result.playType = .rush
            result.offensivePlay = .run
        }
        
        return simulateOffensivePlay(result, situation)
    }
    
    private func getPassPercentage(for situation: GameSituation) -> Double {
        switch (situation.down, situation.isLongDistance) {
        case (1, false): return 0.45  // 1st and 10
        case (1, true): return 0.65   // 1st and long
        case (2, false): return 0.50  // 2nd and short
        case (2, true): return 0.70   // 2nd and long
        case (3, false): return 0.60  // 3rd and short
        case (3, true): return 0.85   // 3rd and long
        default: return 0.55
        }
    }
    
    private func selectPassPlay(for situation: GameSituation) -> PlayResult.OffensivePlay {
        if situation.isLongDistance {
            return [.mediumPass, .deepPass].randomElement() ?? .mediumPass
        } else if situation.isShortYardage {
            return [.shortPass, .screen].randomElement() ?? .shortPass
        } else {
            return [.shortPass, .mediumPass].randomElement() ?? .shortPass
        }
    }
    
    // MARK: - Play Simulation
    private func simulateOffensivePlay(_ play: PlayResult, _ situation: GameSituation) -> PlayResult {
        var result = play
        
        let offensiveTeam = getOffensiveTeam()
        let defensiveTeam = getDefensiveTeam()
        
        // Calculate success probability based on team strengths
        let offensiveStrength = Double(offensiveTeam.offensiveRating)
        let defensiveStrength = Double(defensiveTeam.defensiveRating)
        let strengthDifference = offensiveStrength - defensiveStrength
        
        // Base success rates
        let baseSuccess = getBaseSuccessRate(for: result.playType, situation: situation)
        let adjustedSuccess = baseSuccess + (strengthDifference * 0.01)
        
        // Simulate the play
        let success = Double.random(in: 0...1) < adjustedSuccess
        
        if result.playType == .rush {
            result = simulateRushingPlay(result, success: success, situation: situation)
        } else {
            result = simulatePassingPlay(result, success: success, situation: situation)
        }
        
        // Check for penalties (5% chance)
        if Double.random(in: 0...1) < 0.05 {
            result = addPenalty(to: result)
        }
        
        // Check for turnovers
        result = checkForTurnover(result, situation: situation)
        
        return result
    }
    
    private func simulateRushingPlay(_ play: PlayResult, success: Bool, situation: GameSituation) -> PlayResult {
        var result = play
        
        let offensivePlayers = getCurrentOffensivePlayers()
        let defensivePlayers = getCurrentDefensivePlayers()
        
        // Select actual players
        guard let runningBack = selectRunningBack(from: offensivePlayers, situation: situation),
              let defender = selectDefender(from: defensivePlayers, playType: .rush) else {
            // Fallback to generic play if player selection fails
            return simulateGenericRushingPlay(result, success: success, situation: situation)
        }
        
        // Calculate success based on player ratings
        let rbRating = Int(runningBack.overall) ?? 75
        let defenderRating = Int(defender.overall) ?? 75
        let actualSuccess = calculatePlaySuccess(offense: rbRating, defense: defenderRating, baseSuccess: success)
        
        if actualSuccess {
            // Successful rushing play
            let baseYards = calculateRushingYards(runningBack: runningBack, situation: situation)
            result.yardGain = baseYards
            
            // Enhanced touchdown calculation with RB rating influence
            let willScore = calculateEnhancedRushingTouchdownProbability(
                fieldPosition: gameState.fieldPosition,
                yardGain: result.yardGain,
                runningBack: runningBack,
                situation: situation
            )
            
            // Create player actions using object pool
            let rushAction = PlayerActionPool.shared.getAction(
                playerId: "\(runningBack.firstName)_\(runningBack.lastName)_\(runningBack.jerseyNum)",
                playerName: "\(runningBack.firstName) \(runningBack.lastName)",
                position: runningBack.position,
                statType: .rushingAttempt,
                value: 1
            )
            
            let rushYardsAction = PlayerActionPool.shared.getAction(
                playerId: "\(runningBack.firstName)_\(runningBack.lastName)_\(runningBack.jerseyNum)",
                playerName: "\(runningBack.firstName) \(runningBack.lastName)",
                position: runningBack.position,
                statType: .rushingYards,
                value: result.yardGain
            )
            
            let tackleAction = PlayerActionPool.shared.getAction(
                playerId: "\(defender.firstName)_\(defender.lastName)_\(defender.jerseyNum)",
                playerName: "\(defender.firstName) \(defender.lastName)",
                position: defender.position,
                statType: .tackle,
                value: 1
            )
            
            var playerActions = [rushAction, rushYardsAction, tackleAction]
            
            // Add rushing touchdown action if scoring
            if willScore {
                let rushingTouchdownAction = PlayerActionPool.shared.getAction(
                    playerId: "\(runningBack.firstName)_\(runningBack.lastName)_\(runningBack.jerseyNum)",
                    playerName: "\(runningBack.firstName) \(runningBack.lastName)",
                    position: runningBack.position,
                    statType: .rushingTouchdown,
                    value: 1
                )
                playerActions.append(rushingTouchdownAction)
            }
            
            result.playerActions = playerActions
            result.primaryOffensivePlayer = rushAction
            result.primaryDefensivePlayer = tackleAction
            
            let formation = getRandomFormation()
            if willScore {
                result.description = "\(runningBack.firstName) \(runningBack.lastName) rushes for \(result.yardGain) yards for a TOUCHDOWN! (\(formation))"
            } else {
                result.description = "\(runningBack.firstName) \(runningBack.lastName) rushes for \(result.yardGain) yards (\(formation))"
            }
        } else {
            // Unsuccessful rushing play
            result.yardGain = Int.random(in: -3...1)
            
            let rushAction = PlayerAction(
                playerId: "\(runningBack.firstName)_\(runningBack.lastName)_\(runningBack.jerseyNum)",
                playerName: "\(runningBack.firstName) \(runningBack.lastName)",
                position: runningBack.position,
                statType: .rushingAttempt,
                value: 1
            )
            
            let rushYardsAction = PlayerAction(
                playerId: "\(runningBack.firstName)_\(runningBack.lastName)_\(runningBack.jerseyNum)",
                playerName: "\(runningBack.firstName) \(runningBack.lastName)",
                position: runningBack.position,
                statType: .rushingYards,
                value: result.yardGain
            )
            
            let tackleAction = PlayerAction(
                playerId: "\(defender.firstName)_\(defender.lastName)_\(defender.jerseyNum)",
                playerName: "\(defender.firstName) \(defender.lastName)",
                position: defender.position,
                statType: .tackle,
                value: 1
            )
            
            result.playerActions = [rushAction, rushYardsAction, tackleAction]
            result.primaryOffensivePlayer = rushAction
            result.primaryDefensivePlayer = tackleAction
            
            result.description = "\(runningBack.firstName) \(runningBack.lastName) rush for \(result.yardGain > 0 ? "\(result.yardGain) yards" : result.yardGain == 0 ? "no gain" : "\(abs(result.yardGain)) yard loss")"
        }
        
        return result
    }
    
    // Fallback method for when player selection fails
    private func simulateGenericRushingPlay(_ play: PlayResult, success: Bool, situation: GameSituation) -> PlayResult {
        var result = play
        
        if success {
            let baseYards = situation.isShortYardage ? Int.random(in: 1...8) : Int.random(in: 2...12)
            result.yardGain = baseYards
            if Double.random(in: 0...1) < 0.1 {
                result.yardGain += Int.random(in: 10...30)
            }
            
            // Check if this will be a touchdown
            let willScore = (gameState.fieldPosition + result.yardGain) >= 100
            
            // Create minimal player actions for touchdown tracking only
            var playerActions: [PlayerAction] = []
            
            // Only create touchdown action if scoring to minimize object creation
            if willScore {
                let genericRushingTouchdownAction = PlayerAction(
                    playerId: "RB_Generic",
                    playerName: "RB",
                    position: "RB",
                    statType: .rushingTouchdown,
                    value: 1
                )
                playerActions.append(genericRushingTouchdownAction)
            }
            
            result.playerActions = playerActions
            
            let formation = getRandomFormation()
            if willScore {
                result.description = "RB rushes for \(result.yardGain) yards for a TOUCHDOWN! (\(formation))"
            } else {
                result.description = "RB rushes for \(result.yardGain) yards (\(formation))"
            }
        } else {
            result.yardGain = Int.random(in: -3...1)
            
            // No player actions for unsuccessful generic plays to minimize object creation
            result.playerActions = []
            result.description = "Rush for \(result.yardGain > 0 ? "\(result.yardGain) yards" : result.yardGain == 0 ? "no gain" : "\(abs(result.yardGain)) yard loss")"
        }
        
        return result
    }
    
    private func simulatePassingPlay(_ play: PlayResult, success: Bool, situation: GameSituation) -> PlayResult {
        var result = play
        
        let offensivePlayers = getCurrentOffensivePlayers()
        let defensivePlayers = getCurrentDefensivePlayers()
        
        // Select actual players
        guard let quarterback = selectStartingQB(from: offensivePlayers),
              let receiver = selectReceiver(from: offensivePlayers, situation: situation),
              let defender = selectDefender(from: defensivePlayers, playType: .pass) else {
            // Fallback to generic play if player selection fails
            return simulateGenericPassingPlay(result, success: success, situation: situation)
        }
        
        // Calculate success based on player ratings
        let qbRating = Int(quarterback.overall) ?? 75
        let receiverRating = Int(receiver.overall) ?? 75
        let defenderRating = Int(defender.overall) ?? 75
        let offenseRating = (qbRating + receiverRating) / 2
        
        // Sack chance is now handled in the template-based system for realistic rates
        
        let actualSuccess = calculatePlaySuccess(offense: offenseRating, defense: defenderRating, baseSuccess: success)
        
        if actualSuccess {
            // Successful passing play
            let baseYards = calculatePassingYards(quarterback: quarterback, receiver: receiver, situation: situation)
            result.yardGain = baseYards
            
            // Enhanced touchdown calculation with QB rating influence
            let willScore = calculateEnhancedTouchdownProbability(
                fieldPosition: gameState.fieldPosition,
                yardGain: result.yardGain,
                quarterback: quarterback,
                situation: situation
            )
            
            // Create player actions
            let passAttemptAction = PlayerAction(
                playerId: "\(quarterback.firstName)_\(quarterback.lastName)_\(quarterback.jerseyNum)",
                playerName: "\(quarterback.firstName) \(quarterback.lastName)",
                position: quarterback.position,
                statType: .passingAttempt,
                value: 1
            )
            
            let passCompletionAction = PlayerAction(
                playerId: "\(quarterback.firstName)_\(quarterback.lastName)_\(quarterback.jerseyNum)",
                playerName: "\(quarterback.firstName) \(quarterback.lastName)",
                position: quarterback.position,
                statType: .passingCompletion,
                value: 1
            )
            
            let passYardsAction = PlayerAction(
                playerId: "\(quarterback.firstName)_\(quarterback.lastName)_\(quarterback.jerseyNum)",
                playerName: "\(quarterback.firstName) \(quarterback.lastName)",
                position: quarterback.position,
                statType: .passingYards,
                value: result.yardGain
            )
            
            let receptionAction = PlayerAction(
                playerId: "\(receiver.firstName)_\(receiver.lastName)_\(receiver.jerseyNum)",
                playerName: "\(receiver.firstName) \(receiver.lastName)",
                position: receiver.position,
                statType: .reception,
                value: 1
            )
            
            let receivingYardsAction = PlayerAction(
                playerId: "\(receiver.firstName)_\(receiver.lastName)_\(receiver.jerseyNum)",
                playerName: "\(receiver.firstName) \(receiver.lastName)",
                position: receiver.position,
                statType: .receivingYards,
                value: result.yardGain
            )
            
            let tackleAction = PlayerAction(
                playerId: "\(defender.firstName)_\(defender.lastName)_\(defender.jerseyNum)",
                playerName: "\(defender.firstName) \(defender.lastName)",
                position: defender.position,
                statType: .tackle,
                value: 1
            )
            
            var playerActions = [passAttemptAction, passCompletionAction, passYardsAction, receptionAction, receivingYardsAction, tackleAction]
            
            // Add touchdown actions if scoring
            if willScore {
                let passingTouchdownAction = PlayerAction(
                    playerId: "\(quarterback.firstName)_\(quarterback.lastName)_\(quarterback.jerseyNum)",
                    playerName: "\(quarterback.firstName) \(quarterback.lastName)",
                    position: quarterback.position,
                    statType: .passingTouchdown,
                    value: 1
                )
                
                let receivingTouchdownAction = PlayerAction(
                    playerId: "\(receiver.firstName)_\(receiver.lastName)_\(receiver.jerseyNum)",
                    playerName: "\(receiver.firstName) \(receiver.lastName)",
                    position: receiver.position,
                    statType: .receivingTouchdown,
                    value: 1
                )
                
                playerActions.append(passingTouchdownAction)
                playerActions.append(receivingTouchdownAction)
            }
            
            result.playerActions = playerActions
            result.primaryOffensivePlayer = passAttemptAction
            result.primaryDefensivePlayer = tackleAction
            
            let route = getRandomRoute(for: play.offensivePlay)
            if willScore {
                result.description = "\(quarterback.firstName) \(quarterback.lastName) pass completed to \(receiver.firstName) \(receiver.lastName) for \(result.yardGain) yards for a TOUCHDOWN! (\(route))"
            } else {
                result.description = "\(quarterback.firstName) \(quarterback.lastName) pass completed to \(receiver.firstName) \(receiver.lastName) for \(result.yardGain) yards (\(route))"
            }
        } else {
            // Interception chance is now handled in the template-based system for realistic rates
            
            // Incomplete pass
            result.yardGain = 0
            
            let passAttemptAction = PlayerAction(
                playerId: "\(quarterback.firstName)_\(quarterback.lastName)_\(quarterback.jerseyNum)",
                playerName: "\(quarterback.firstName) \(quarterback.lastName)",
                position: quarterback.position,
                statType: .passingAttempt,
                value: 1
            )
            
            let targetAction = PlayerAction(
                playerId: "\(receiver.firstName)_\(receiver.lastName)_\(receiver.jerseyNum)",
                playerName: "\(receiver.firstName) \(receiver.lastName)",
                position: receiver.position,
                statType: .target,
                value: 1
            )
            
            let passDefenseAction = PlayerAction(
                playerId: "\(defender.firstName)_\(defender.lastName)_\(defender.jerseyNum)",
                playerName: "\(defender.firstName) \(defender.lastName)",
                position: defender.position,
                statType: .passDefended,
                value: 1
            )
            
            result.playerActions = [passAttemptAction, targetAction, passDefenseAction]
            result.primaryOffensivePlayer = passAttemptAction
            result.primaryDefensivePlayer = passDefenseAction
            
            let reason = ["overthrown", "dropped", "defended", "out of bounds"].randomElement() ?? "incomplete"
            result.description = "\(quarterback.firstName) \(quarterback.lastName) pass incomplete to \(receiver.firstName) \(receiver.lastName) (\(reason))"
        }
        
        return result
    }
    
    private func simulateSack(_ play: PlayResult, quarterback: MasterPlayer, defender: MasterPlayer) -> PlayResult {
        var result = play
        result.playType = .sack
        result.yardGain = Int.random(in: -12...(-3)) // Sack loss of 3-12 yards
        
        // Create player actions
        let passAttemptAction = PlayerAction(
            playerId: "\(quarterback.firstName)_\(quarterback.lastName)_\(quarterback.jerseyNum)",
            playerName: "\(quarterback.firstName) \(quarterback.lastName)",
            position: quarterback.position,
            statType: .passingAttempt,
            value: 1
        )
        
        let sackTakenAction = PlayerAction(
            playerId: "\(quarterback.firstName)_\(quarterback.lastName)_\(quarterback.jerseyNum)",
            playerName: "\(quarterback.firstName) \(quarterback.lastName)",
            position: quarterback.position,
            statType: .sackTaken,
            value: 1
        )
        
        let sackMadeAction = PlayerAction(
            playerId: "\(defender.firstName)_\(defender.lastName)_\(defender.jerseyNum)",
            playerName: "\(defender.firstName) \(defender.lastName)",
            position: defender.position,
            statType: .sackMade,
            value: 1
        )
        
        result.playerActions = [passAttemptAction, sackTakenAction, sackMadeAction]
        result.primaryOffensivePlayer = passAttemptAction
        result.primaryDefensivePlayer = sackMadeAction
        
        result.description = "\(quarterback.firstName) \(quarterback.lastName) sacked by \(defender.firstName) \(defender.lastName) for \(abs(result.yardGain)) yard loss"
        
// Sack logged for debugging
        
        return result
    }
    
    private func simulateInterception(_ play: PlayResult, quarterback: MasterPlayer, defender: MasterPlayer) -> PlayResult {
        var result = play
        result.playType = .interception
        result.isTurnover = true
        result.yardGain = Int.random(in: 0...25) // Interception return yards
        
        // Create player actions
        let passAttemptAction = PlayerAction(
            playerId: "\(quarterback.firstName)_\(quarterback.lastName)_\(quarterback.jerseyNum)",
            playerName: "\(quarterback.firstName) \(quarterback.lastName)",
            position: quarterback.position,
            statType: .passingAttempt,
            value: 1
        )
        
        let interceptionThrownAction = PlayerAction(
            playerId: "\(quarterback.firstName)_\(quarterback.lastName)_\(quarterback.jerseyNum)",
            playerName: "\(quarterback.firstName) \(quarterback.lastName)",
            position: quarterback.position,
            statType: .interceptionThrown,
            value: 1
        )
        
        let interceptionMadeAction = PlayerAction(
            playerId: "\(defender.firstName)_\(defender.lastName)_\(defender.jerseyNum)",
            playerName: "\(defender.firstName) \(defender.lastName)",
            position: defender.position,
            statType: .interceptionMade,
            value: 1
        )
        
        result.playerActions = [passAttemptAction, interceptionThrownAction, interceptionMadeAction]
        result.primaryOffensivePlayer = passAttemptAction
        result.primaryDefensivePlayer = interceptionMadeAction
        
        result.description = "\(quarterback.firstName) \(quarterback.lastName) pass intercepted by \(defender.firstName) \(defender.lastName)"
        if result.yardGain > 0 {
            result.description += " returned for \(result.yardGain) yards"
        }
        
        // Interception logged for debugging
        
        return result
    }
    
    // Fallback method for when player selection fails
    private func simulateGenericPassingPlay(_ play: PlayResult, success: Bool, situation: GameSituation) -> PlayResult {
        var result = play
        
        if success {
            let baseYards = getPassYardage(for: play.offensivePlay)
            result.yardGain = baseYards
            if Double.random(in: 0...1) < 0.15 {
                result.yardGain += Int.random(in: 15...40)
            }
            
            // Check if this will be a touchdown
            let willScore = (gameState.fieldPosition + result.yardGain) >= 100
            
            let receiverPosition = ["WR", "TE", "RB"].randomElement() ?? "WR"
            
            // Create minimal player actions for touchdown tracking only
            var playerActions: [PlayerAction] = []
            
            // Only create touchdown actions if scoring to minimize object creation
            if willScore {
                let genericPassingTouchdownAction = PlayerAction(
                    playerId: "QB_Generic",
                    playerName: "QB",
                    position: "QB",
                    statType: .passingTouchdown,
                    value: 1
                )
                
                let genericReceivingTouchdownAction = PlayerAction(
                    playerId: "\(receiverPosition)_Generic",
                    playerName: receiverPosition,
                    position: receiverPosition,
                    statType: .receivingTouchdown,
                    value: 1
                )
                
                playerActions.append(genericPassingTouchdownAction)
                playerActions.append(genericReceivingTouchdownAction)
            }
            
            result.playerActions = playerActions
            
            let route = getRandomRoute(for: play.offensivePlay)
            if willScore {
                result.description = "Pass completed to \(receiverPosition) for \(result.yardGain) yards for a TOUCHDOWN! (\(route))"
            } else {
                result.description = "Pass completed to \(receiverPosition) for \(result.yardGain) yards (\(route))"
            }
        } else {
            result.yardGain = 0
            
            // No player actions for incomplete generic passes to minimize object creation
            result.playerActions = []
            
            let reason = ["overthrown", "dropped", "defended", "out of bounds"].randomElement() ?? "incomplete"
            result.description = "Pass incomplete (\(reason))"
        }
        
        return result
    }
    
    private func simulateFieldGoal(_ play: PlayResult, _ situation: GameSituation) -> PlayResult {
        var result = play
        
        let offensivePlayers = getCurrentOffensivePlayers()
        
        // Select kicker
        guard let kicker = selectKicker(from: offensivePlayers) else {
            // Fallback to generic field goal
            return simulateGenericFieldGoal(result, situation)
        }
        
        let distance = 120 - situation.fieldPosition + 7  // Add 7 for end zone depth
        let kickerRating = Int(kicker.overall) ?? 75
        
        // Adjust success rate based on kicker rating
        let baseSuccessRate = getFieldGoalSuccessRate(distance: distance)
        let ratingBonus = Double(kickerRating - 75) / 200.0  // +/- 12.5% based on rating
        let adjustedSuccessRate = max(0.1, min(0.95, baseSuccessRate + ratingBonus))
        
        let fgAttemptAction = PlayerAction(
            playerId: "\(kicker.firstName)_\(kicker.lastName)_\(kicker.jerseyNum)",
            playerName: "\(kicker.firstName) \(kicker.lastName)",
            position: kicker.position,
            statType: .fieldGoalAttempt,
            value: 1
        )
        
        if Double.random(in: 0...1) < adjustedSuccessRate {
            result.yardGain = 3
            result.isScoring = true
            
            let fgMadeAction = PlayerAction(
                playerId: "\(kicker.firstName)_\(kicker.lastName)_\(kicker.jerseyNum)",
                playerName: "\(kicker.firstName) \(kicker.lastName)",
                position: kicker.position,
                statType: .fieldGoalMade,
                value: 1
            )
            
            result.playerActions = [fgAttemptAction, fgMadeAction]
            result.primaryOffensivePlayer = fgAttemptAction
            result.description = "\(kicker.firstName) \(kicker.lastName) \(distance)-yard field goal GOOD!"
        } else {
            result.yardGain = 0
            result.playerActions = [fgAttemptAction]
            result.primaryOffensivePlayer = fgAttemptAction
            result.description = "\(kicker.firstName) \(kicker.lastName) \(distance)-yard field goal MISSED"
        }
        
        return result
    }
    
    private func simulateGenericFieldGoal(_ play: PlayResult, _ situation: GameSituation) -> PlayResult {
        var result = play
        
        let distance = 120 - situation.fieldPosition + 7
        let successRate = getFieldGoalSuccessRate(distance: distance)
        
        if Double.random(in: 0...1) < successRate {
            result.yardGain = 3
            result.isScoring = true
            result.description = "\(distance)-yard field goal GOOD!"
        } else {
            result.yardGain = 0
            result.description = "\(distance)-yard field goal MISSED"
        }
        
        return result
    }
    
    private func simulatePunt(_ play: PlayResult, _ situation: GameSituation) -> PlayResult {
        var result = play
        
        let puntDistance = Int.random(in: 35...55)
        result.yardGain = -puntDistance  // Negative because it's a change of possession
        result.description = "Punt for \(puntDistance) yards"
        
        return result
    }
    
    // MARK: - Helper Functions
    private func getBaseSuccessRate(for playType: PlayResult.PlayType, situation: GameSituation) -> Double {
        switch playType {
        case .rush:
            if situation.isShortYardage { return 0.80 }  // Increased from 0.75
            if situation.isLongDistance { return 0.40 }  // Increased from 0.35
            return 0.65  // Increased from 0.60
        case .pass:
            if situation.isLongDistance { return 0.50 }  // Increased from 0.45
            if situation.isShortYardage { return 0.75 }  // Increased from 0.70
            return 0.67  // Increased from 0.62
        default:
            return 0.55  // Increased from 0.50
        }
    }
    
    private func getPassYardage(for playType: PlayResult.OffensivePlay) -> Int {
        switch playType {
        case .shortPass, .screen:
            return Int.random(in: 4...10)  // Slightly increased
        case .mediumPass:
            return Int.random(in: 10...20)  // Slightly increased
        case .deepPass:
            return Int.random(in: 20...40)  // Slightly increased
        default:
            return Int.random(in: 6...15)  // Slightly increased
        }
    }
    
    private func getFieldGoalSuccessRate(distance: Int) -> Double {
        switch distance {
        case 0...20: return 0.99  // Chip shots almost automatic
        case 21...30: return 0.95
        case 31...40: return 0.85
        case 41...50: return 0.70
        case 51...60: return 0.45
        default: return 0.20
        }
    }
    
    private func getRandomFormation() -> String {
        return ["I-Formation", "Shotgun", "Singleback", "Pistol"].randomElement() ?? "Shotgun"
    }
    
    private func getRandomRoute(for playType: PlayResult.OffensivePlay) -> String {
        switch playType {
        case .shortPass:
            return ["Slant", "Hitch", "Quick Out"].randomElement() ?? "Slant"
        case .mediumPass:
            return ["Comeback", "Dig", "Post"].randomElement() ?? "Comeback"
        case .deepPass:
            return ["Go Route", "Deep Post", "Fade"].randomElement() ?? "Go Route"
        default:
            return ["Slant", "Hitch"].randomElement() ?? "Slant"
        }
    }
    
    private func getOffensiveTeam() -> TeamGameData {
        return gameState.possession == .home ? gameState.homeTeam : gameState.awayTeam
    }
    
    private func getDefensiveTeam() -> TeamGameData {
        return gameState.possession == .home ? gameState.awayTeam : gameState.homeTeam
    }
    
    // MARK: - Game State Updates
    private func processPlay(_ play: PlayResult) -> PlayResult {
        var modifiedPlay = play
        
        // Update field position
        gameState.fieldPosition += play.yardGain
        gameState.fieldPosition = max(0, min(100, gameState.fieldPosition))
        
        // Check for scoring
        if gameState.fieldPosition >= 100 {
            modifiedPlay.isScoring = true
            handleTouchdown(modifiedPlay)
            return modifiedPlay
        }
        
        // Check for safety
        if gameState.fieldPosition <= 0 {
            handleSafety(modifiedPlay)
            return modifiedPlay
        }
        
        // Handle first down
        if play.yardGain >= gameState.yardsToGo {
            gameState.down = 1
            gameState.yardsToGo = 10
            modifiedPlay.isFirstDown = true
        } else {
            gameState.down += 1
            gameState.yardsToGo -= play.yardGain
        }
        
        // Handle turnover on downs
        if gameState.down > 4 {
            gameState.switchPossession()
            gameState.fieldPosition = 100 - gameState.fieldPosition
        }
        
        // Handle special plays
        if modifiedPlay.playType == .punt {
            gameState.switchPossession()
            gameState.fieldPosition = max(20, 100 - abs(modifiedPlay.yardGain))
        }
        
        if modifiedPlay.playType == .fieldGoal {
            if modifiedPlay.isScoring {
                updateScore(points: 3)
            }
            gameState.switchPossession()
            gameState.fieldPosition = 25  // Touchback
        }
        
        // Update red zone status
        gameState.isRedZone = gameState.fieldPosition >= 80
        
        // Update game time
        updateGameTime()
        
        gameState.lastPlay = modifiedPlay.description
        
        return modifiedPlay
    }
    
    private func handleTouchdown(_ play: PlayResult) {
        updateScore(points: 6)
        gameStats.scoringPlays.append(play)
        
        // Extra point attempt
        let extraPoint = simulateExtraPoint()
        if extraPoint.isScoring {
            updateScore(points: 1)
        }
        
        // Kickoff
        gameState.switchPossession()
        gameState.fieldPosition = 25
    }
    
    private func handleSafety(_ play: PlayResult) {
        let oppositeTeam: GameState.TeamSide = gameState.possession.opposite
        if oppositeTeam == .home {
            gameState.homeScore += 2
        } else {
            gameState.awayScore += 2
        }
        
        gameState.switchPossession()
        gameState.fieldPosition = 20  // Free kick from 20
    }
    
    private func simulateExtraPoint() -> PlayResult {
        var extraPoint = PlayResult()
        extraPoint.playType = .extraPoint
        
        if Double.random(in: 0...1) < 0.985 {  // 98.5% success rate, closer to NFL average
            extraPoint.isScoring = true
            extraPoint.description = "Extra point GOOD"
        } else {
            extraPoint.description = "Extra point MISSED"
        }
        
        return extraPoint
    }
    
    private func updateScore(points: Int) {
        if gameState.possession == .home {
            gameState.homeScore += points
        } else {
            gameState.awayScore += points
        }
    }
    
    private func updateGameTime() {
        let timeComponents = gameState.timeRemaining.split(separator: ":")
        guard let minutes = Int(timeComponents[0]),
              let seconds = Int(timeComponents[1]) else { return }
        
        let totalSeconds = minutes * 60 + seconds - Int.random(in: 20...50)
        
        if totalSeconds <= 0 {
            if gameState.currentQuarter < 4 {
                gameState.currentQuarter += 1
                gameState.timeRemaining = "15:00"
                
                // Two-minute warning
                if gameState.currentQuarter == 2 || gameState.currentQuarter == 4 {
                    gameState.isTwoMinuteWarning = true
                }
            } else {
                // Check for overtime
                if gameState.homeScore == gameState.awayScore {
                    // Start overtime
                    gameState.currentQuarter = 5
                    gameState.timeRemaining = "10:00"
                    
                    // Coin toss for overtime possession
                    gameState.possession = Bool.random() ? .home : .away
                    gameState.fieldPosition = 25
                } else {
                    gameState.isGameOver = true
                }
            }
        } else {
            let newMinutes = totalSeconds / 60
            let newSeconds = totalSeconds % 60
            gameState.timeRemaining = String(format: "%d:%02d", newMinutes, newSeconds)
        }
        
        // Check if overtime should end
        if gameState.currentQuarter == 5 {
            // Sudden death rules - game ends on any score
            if gameState.homeScore != gameState.awayScore {
                gameState.isGameOver = true
            } else if gameState.timeRemaining == "0:00" {
                // Very rare case - still tied after overtime
                gameState.isGameOver = true
            }
        }
    }
    
    // MARK: - Statistics Updates
    private func updateGameStats(with play: PlayResult) {
        gameStats.totalPlays += 1
        
        let isHomeTeam = play.possessionTeam == .home
        var stats = isHomeTeam ? gameStats.homeTeamStats : gameStats.awayTeamStats
        
        // Update based on play type
        switch play.playType {
        case .rush:
            stats.rushingAttempts += 1
            stats.rushingYards += play.yardGain
            if play.isScoring {
                stats.rushingTouchdowns += 1
            }
            
        case .pass:
            stats.passingAttempts += 1
            if play.yardGain > 0 {
                stats.passingCompletions += 1
                stats.passingYards += play.yardGain
            }
            if play.isScoring {
                stats.passingTouchdowns += 1
            }
            
        case .fieldGoal:
            stats.fieldGoalAttempts += 1
            if play.isScoring {
                stats.fieldGoalsMade += 1
            }
            
        case .punt:
            stats.punts += 1
            stats.puntYards += abs(play.yardGain)
            
        default:
            break
        }
        
        // Update general stats
        stats.totalYards += max(0, play.yardGain)
        
        if play.isFirstDown {
            stats.firstDowns += 1
        }
        
        if play.down == 3 {
            stats.thirdDownAttempts += 1
            if play.isFirstDown {
                stats.thirdDownConversions += 1
            }
        }
        
        if gameState.isRedZone {
            if play.isScoring {
                stats.redZoneScores += 1
            }
        }
        
        // Big plays (20+ yards)
        if play.yardGain >= 20 {
            gameStats.bigPlays.append(play)
        }
        
        // Update the stats back
        if isHomeTeam {
            gameStats.homeTeamStats = stats
        } else {
            gameStats.awayTeamStats = stats
        }
    }
    
    // MARK: - Turnover and Penalty Logic
    private func checkForTurnover(_ play: PlayResult, situation: GameSituation) -> PlayResult {
        var result = play
        
        let turnoverChance: Double
        switch play.playType {
        case .pass:
            turnoverChance = 0.025  // 2.5% interception rate
        case .rush:
            turnoverChance = 0.015  // 1.5% fumble rate
        default:
            turnoverChance = 0.0
        }
        
        if Double.random(in: 0...1) < turnoverChance {
            result.isTurnover = true
            
            if play.playType == .pass {
                result.playType = .interception
                result.description = "INTERCEPTION! Pass intercepted"
                // Update the defending team's interception stats
                if gameState.possession == .home {
                    gameStats.awayTeamStats.interceptions += 1
                } else {
                    gameStats.homeTeamStats.interceptions += 1
                }
            } else {
                result.playType = .fumble
                result.description = "FUMBLE! Ball recovered by defense"
                // Update the defending team's fumble recovery stats
                if gameState.possession == .home {
                    gameStats.awayTeamStats.fumbles += 1
                } else {
                    gameStats.homeTeamStats.fumbles += 1
                }
            }
            
            gameStats.turnovers.append(result)
        }
        
        return result
    }
    
    private func addPenalty(to play: PlayResult) -> PlayResult {
        var result = play
        result.isPenalty = true
        
        let penalties = [
            ("Holding", 10),
            ("False Start", 5),
            ("Offsides", 5),
            ("Pass Interference", 15),
            ("Roughing the Passer", 15),
            ("Delay of Game", 5)
        ]
        
        let penalty = penalties.randomElement() ?? ("Holding", 10)
        result.penaltyYards = penalty.1
        result.description += " - \(penalty.0) penalty, \(penalty.1) yards"
        
        return result
    }
    
    // MARK: - Game Completion
    private func checkGameEndConditions() {
        if gameState.currentQuarter >= 4 && gameState.timeRemaining == "0:00" {
            if gameState.homeScore != gameState.awayScore {
                gameState.isGameOver = true
                pauseSimulation()
            }
        }
    }
    
    private func createGameResult() -> GameResult {
        guard let homeTeam = homeTeam, let awayTeam = awayTeam else {
            fatalError("Teams not initialized")
        }
        
        var result = GameResult(week: currentWeek, homeTeam: homeTeam, awayTeam: awayTeam)
        result.homeScore = gameState.homeScore
        result.awayScore = gameState.awayScore
        result.isCompleted = true
        result.gameLength = gameStats.gameTime
        
        // Store detailed stats in the result
        result.detailedStats = createDetailedStats()
        result.scoringPlays = createScoringPlays()
        result.playByPlaySummary = playByPlay.map { $0.description }
        
        // Generate natural player stats from play-by-play
        generateNaturalPlayerStats(for: &result)
        
        return result
    }
    
    // MARK: - Streamlined Player Statistics Generation (Ultra-Optimized)
    private func generateNaturalPlayerStats(for gameResult: inout GameResult) {
        // Efficient stats generation that tracks all important stats while maintaining performance
        var playerStatsMap: [String: GamePlayerStats] = [:]
        var actionsToReturn: [PlayerAction] = []
        
        // Process all plays to extract player actions efficiently
        for play in playByPlay where !play.playerActions.isEmpty {
            for action in play.playerActions {
                let playerId = action.playerId
                
                // Get or create player stats
                if playerStatsMap[playerId] == nil {
                    playerStatsMap[playerId] = GamePlayerStats(
                        gameId: gameResult.id,
                        playerId: playerId,
                        playerName: action.playerName,
                        position: action.position,
                        teamLogoName: determineTeamForPlayer(action.playerId),
                        week: gameResult.week
                    )
                }
                
                // Apply the stat efficiently
                if var playerStats = playerStatsMap[playerId] {
                    applyStatToPlayer(&playerStats, statType: action.statType, value: action.value)
                    playerStatsMap[playerId] = playerStats
                }
            }
            
            // Collect actions for later return to pool
            actionsToReturn.append(contentsOf: play.playerActions)
        }
        
        // Store the comprehensive player stats BEFORE returning actions to pool
        if !playerStatsMap.isEmpty {
            storeGamePlayerStats(gameResult.id, Array(playerStatsMap.values))
            
            // Debug logging for user team games
            if let homeTeam = homeTeam, let awayTeam = awayTeam {
                let isUserTeam = homeTeam.logoName == "Chicago" || awayTeam.logoName == "Chicago"
                if isUserTeam {
                    print("📊 🎯 AdvancedEngine: Generated \(playerStatsMap.count) player stats for \(homeTeam.name) vs \(awayTeam.name)")
                    
                    // Show a sample of stats generated
                    if let samplePlayer = playerStatsMap.values.first {
                        print("📊 Sample: \(samplePlayer.playerName) (\(samplePlayer.position)) - Team: \(samplePlayer.teamLogoName)")
                    }
                }
            }
        } else {
            // Debug logging for empty stats
            if let homeTeam = homeTeam, let awayTeam = awayTeam {
                let isUserTeam = homeTeam.logoName == "Chicago" || awayTeam.logoName == "Chicago"
                if isUserTeam {
                    print("📊 ⚠️ AdvancedEngine: No player stats generated for \(homeTeam.name) vs \(awayTeam.name)")
                    print("📊 Play count: \(playByPlay.count)")
                    let playsWithActions = playByPlay.filter { !$0.playerActions.isEmpty }
                    print("📊 Plays with actions: \(playsWithActions.count)")
                }
            }
        }
        
        // Now return actions to pool after we've finished processing
        PlayerActionPool.shared.returnActions(actionsToReturn)
    }
    
    
    
    // Helper function to apply stats efficiently
    private func applyStatToPlayer(_ playerStats: inout GamePlayerStats, statType: PlayerAction.PlayerStatType, value: Int) {
        switch statType {
        case .passingAttempt:
            playerStats.passingAttempts += value
        case .passingCompletion:
            playerStats.passingCompletions += value
        case .passingYards:
            playerStats.passingYards += value
        case .passingTouchdown:
            playerStats.passingTouchdowns += value
        case .interceptionThrown:
            playerStats.interceptions += value
        case .rushingAttempt:
            playerStats.rushingAttempts += value
        case .rushingYards:
            playerStats.rushingYards += value
        case .rushingTouchdown:
            playerStats.rushingTouchdowns += value
        case .reception:
            playerStats.receptions += value
        case .receivingYards:
            playerStats.receivingYards += value
        case .receivingTouchdown:
            playerStats.receivingTouchdowns += value
        case .tackle:
            playerStats.tackles += value
        case .sackMade:
            playerStats.sacksMade += value
        case .interceptionMade:
            playerStats.interceptionsDefense += value
        case .passDefended:
            playerStats.passesDefended += value
        case .forcedFumble:
            playerStats.forcedFumbles += value
        case .fumbleRecovery:
            playerStats.fumbleRecoveries += value
        case .fieldGoalAttempt:
            playerStats.fieldGoalAttempts += value
        case .fieldGoalMade:
            playerStats.fieldGoalsMade += value
        case .extraPointAttempt:
            playerStats.extraPointAttempts += value
        case .extraPointMade:
            playerStats.extraPointsMade += value
        case .punt:
            playerStats.punts += value
        case .puntYards:
            playerStats.puntYards += value
        default:
            break
        }
    }
    
    private func determineTeamForPlayer(_ playerId: String) -> String {
        // Check if player is on home team
        for player in homeTeamPlayers {
            let playerIdCheck = "\(player.firstName)_\(player.lastName)_\(player.jerseyNum)"
            if playerIdCheck == playerId {
                return gameState.homeTeam.logoName
            }
        }
        
        // Check if player is on away team
        for player in awayTeamPlayers {
            let playerIdCheck = "\(player.firstName)_\(player.lastName)_\(player.jerseyNum)"
            if playerIdCheck == playerId {
                return gameState.awayTeam.logoName
            }
        }
        
        // Default to home team if not found
        return gameState.homeTeam.logoName
    }
    
    private func storeGamePlayerStats(_ gameId: UUID, _ stats: [GamePlayerStats]) {
        // Store the player stats in a way that LeagueManager can access them
        // We'll use a global dictionary that LeagueManager can read from
        GlobalGamePlayerStatsManager.shared.storeGamePlayerStats(gameId: gameId, stats: stats)
        
        // Debug verification
        if let homeTeam = homeTeam, let awayTeam = awayTeam {
            let isUserTeam = homeTeam.logoName == "Chicago" || awayTeam.logoName == "Chicago"
            if isUserTeam {
                print("📊 🔄 AdvancedEngine: Stored \(stats.count) player stats with gameId: \(gameId)")
                
                // Verify storage by retrieving immediately
                if let retrievedStats = GlobalGamePlayerStatsManager.shared.getGamePlayerStats(gameId: gameId) {
                    print("📊 ✅ AdvancedEngine: Verified storage - retrieved \(retrievedStats.count) stats")
                } else {
                    print("📊 ❌ AdvancedEngine: Failed to retrieve stored stats!")
                }
            }
        }
    }
    
    private func createDetailedStats() -> DetailedGameStats {
        // Debug logging removed to prevent crashes during batch simulation
        
        return DetailedGameStats(
            homeTeamStats: convertToTeamGameStats(gameState.homeTeam.stats),
            awayTeamStats: convertToTeamGameStats(gameState.awayTeam.stats),
            totalPlays: gameStats.totalPlays,
            gameLength: gameStats.gameTime,
            bigPlays: gameStats.bigPlays.count,
            scoringDrives: gameStats.drives.filter { $0.result == .touchdown || $0.result == .fieldGoal }.count
        )
    }
    
    private func convertToTeamGameStats(_ engineStats: TeamGameData.TeamStats) -> TeamGameStats {
        return TeamGameStats(
            passingYards: engineStats.passingYards,
            passingAttempts: engineStats.passingAttempts,
            passingCompletions: engineStats.passingCompletions,
            passingTouchdowns: engineStats.passingTouchdowns,
            interceptions: engineStats.interceptions,
            sacks: engineStats.sacks,
            sacksAllowed: engineStats.sacksAllowed,
            rushingYards: engineStats.rushingYards,
            rushingAttempts: engineStats.rushingAttempts,
            rushingTouchdowns: engineStats.rushingTouchdowns,
            fumbles: engineStats.fumbles,
            fumblesLost: engineStats.fumblesLost,
            totalYards: engineStats.totalYards,
            firstDowns: engineStats.firstDowns,
            thirdDownAttempts: engineStats.thirdDownAttempts,
            thirdDownConversions: engineStats.thirdDownConversions,
            fourthDownAttempts: engineStats.fourthDownAttempts,
            fourthDownConversions: engineStats.fourthDownConversions,
            redZoneAttempts: engineStats.redZoneAttempts,
            redZoneScores: engineStats.redZoneScores,
            penalties: engineStats.penalties,
            penaltyYards: engineStats.penaltyYards,
            turnovers: engineStats.turnovers,
            timeOfPossession: engineStats.timeOfPossession,
            fieldGoalAttempts: engineStats.fieldGoalAttempts,
            fieldGoalsMade: engineStats.fieldGoalsMade,
            extraPointAttempts: engineStats.extraPointAttempts,
            extraPointsMade: engineStats.extraPointsMade,
            punts: engineStats.punts,
            puntYards: engineStats.puntYards
        )
    }
    
    private func createScoringPlays() -> [ScoringPlay] {
        return gameStats.scoringPlays.map { play in
            ScoringPlay(
                quarter: play.quarter,
                time: play.time,
                team: play.possessionTeam == .home ? gameState.homeTeam.name : gameState.awayTeam.name,
                playType: play.playType.rawValue,
                description: play.description,
                points: getPointsForPlay(play),
                homeScore: gameState.homeScore,
                awayScore: gameState.awayScore
            )
        }
    }
    
    private func getPointsForPlay(_ play: PlayResult) -> Int {
        switch play.playType {
        case .touchdown: return 6
        case .fieldGoal: return 3
        case .extraPoint: return 1
        case .safety: return 2
        default: return 0
        }
    }
    
    private func provideHapticFeedback(for play: PlayResult) {
        if play.isScoring {
            HapticManager.shared.notification(.success)
        } else if play.isTurnover {
            HapticManager.shared.notification(.error)
        } else if play.yardGain >= 20 {
            HapticManager.shared.impact(.medium)
        } else {
            HapticManager.shared.impact(.light)
        }
    }
    
    // MARK: - Optimized Instant Simulation
    private func simulatePlayInstantly() {
        guard !gameState.isGameOver else { return }
        
        var play = generateRealisticPlay()
        play = processPlay(play)
        
        // Store play in playByPlay for player stats extraction, but limit array size
        playByPlay.append(play)
        
        // Prevent memory bloat by limiting playByPlay array size during instant simulation
        if playByPlay.count > 500 {
            playByPlay.removeFirst(100) // Remove oldest 100 plays
        }
        
        // Update game stats without UI updates
        updateGameStatsInstantly(with: play)
        
        // Check game end conditions
        checkGameEndConditions()
        
        // No haptic feedback, UI updates, or timers for instant simulation
    }
    
    private func updateGameStatsInstantly(with play: PlayResult) {
        gameStats.totalPlays += 1
        
        // Update team stats based on play result
        if gameState.possession == .home {
            updateTeamStatsInstantly(&gameState.homeTeam.stats, with: play)
            // Update defensive stats for away team
            updateDefensiveStatsInstantly(&gameState.awayTeam.stats, with: play)
        } else {
            updateTeamStatsInstantly(&gameState.awayTeam.stats, with: play)
            // Update defensive stats for home team
            updateDefensiveStatsInstantly(&gameState.homeTeam.stats, with: play)
        }
        
        // Track scoring plays and big plays without storing full play-by-play
        if play.isScoring {
            gameStats.scoringPlays.append(play)
        }
        
        if play.yardGain >= 20 {
            gameStats.bigPlays.append(play)
        }
    }
    
    private func updateTeamStatsInstantly(_ teamStats: inout TeamGameData.TeamStats, with play: PlayResult) {
        // Note: totalPlays is tracked in gameStats.totalPlays, not in individual team stats
        teamStats.totalYards += max(0, play.yardGain)
        
        // Track first downs
        if play.isFirstDown {
            teamStats.firstDowns += 1
        }
        
        // Track scoring plays
        if play.isScoring {
            switch play.playType {
            case .rush:
                teamStats.rushingTouchdowns += 1
            case .pass:
                teamStats.passingTouchdowns += 1
            case .fieldGoal:
                teamStats.fieldGoalAttempts += 1
                teamStats.fieldGoalsMade += 1
            case .extraPoint:
                teamStats.extraPointAttempts += 1
                teamStats.extraPointsMade += 1
            default:
                break
            }
        }
        
        switch play.playType {
        case .rush:
            teamStats.rushingAttempts += 1
            teamStats.rushingYards += play.yardGain
            
        case .pass:
            teamStats.passingAttempts += 1
            if play.yardGain > 0 {
                teamStats.passingCompletions += 1
                teamStats.passingYards += play.yardGain
            }
            
        case .fieldGoal:
            if !play.isScoring {
                // Missed field goal
                teamStats.fieldGoalAttempts += 1
            }
            
        case .punt:
            teamStats.punts += 1
            teamStats.puntYards += abs(play.yardGain)
            
        case .sack:
            // Sacks are handled in defensive stats
            break
            
        case .interception:
            // Interceptions are handled in defensive stats
            break
            
        case .fumble:
            teamStats.fumbles += 1
            if play.isTurnover {
                teamStats.fumblesLost += 1
            }
            
        default:
            break
        }
        
        // Track turnovers
        if play.isTurnover {
            teamStats.turnovers += 1
        }
        
        // Track down conversions
        if play.down == 3 {
            teamStats.thirdDownAttempts += 1
            if play.isFirstDown {
                teamStats.thirdDownConversions += 1
            }
        }
        
        if play.down == 4 {
            teamStats.fourthDownAttempts += 1
            if play.isFirstDown {
                teamStats.fourthDownConversions += 1
            }
        }
        
        // Track red zone efficiency
        if gameState.fieldPosition >= 80 { // Red zone (within 20 yards of goal)
            teamStats.redZoneAttempts += 1
            if play.isScoring {
                teamStats.redZoneScores += 1
            }
        }
    }
    
    private func updateDefensiveStatsInstantly(_ defenseStats: inout TeamGameData.TeamStats, with play: PlayResult) {
        // Track defensive stats for the defending team
        switch play.playType {
        case .sack:
            defenseStats.sacks += 1
            
        case .interception:
            defenseStats.interceptions += 1
            
        case .fumble:
            if play.isTurnover {
                // Defensive team forced a fumble
                defenseStats.fumbles += 1
            }
            
        default:
            break
        }
    }
    
    // MARK: - Template-Based Play Simulation (Optimized)
    private func simulateRushingPlayFromTemplate(_ play: PlayResult, template: PlayTemplate, success: Bool, situation: GameSituation) -> PlayResult {
        var result = play
        
        // Get players for this play
        let starterRB = gameState.possession == .home ? homeTeamRoster?.starterRB : awayTeamRoster?.starterRB
        let defenseRoster = gameState.possession == .home ? awayTeamRoster : homeTeamRoster
        let defender = defenseRoster?.linebackers.first ?? defenseRoster?.defensiveLine.first
        
        if success {
            // Use template base yards with some variance
            let variance = Int.random(in: -2...3)
            result.yardGain = max(0, template.baseYards + variance)
            
            // Check for big play based on template
            if Double.random(in: 0...1) < template.bigPlayChance {
                result.yardGain += Int.random(in: 15...35)
            }
            
            // Enhanced touchdown calculation with RB rating influence
            let willScore = calculateEnhancedRushingTouchdownProbability(
                fieldPosition: gameState.fieldPosition,
                yardGain: result.yardGain,
                runningBack: starterRB,
                situation: situation
            )
            
            // Create player actions for ALL rushing plays
            var playerActions: [PlayerAction] = []
            
            if let rb = starterRB {
                // Rushing attempt
                let rushAttemptAction = PlayerActionPool.shared.getAction(
                    playerId: "\(rb.firstName)_\(rb.lastName)_\(rb.jerseyNum)",
                    playerName: "\(rb.firstName) \(rb.lastName)",
                    position: rb.position,
                    statType: .rushingAttempt,
                    value: 1
                )
                playerActions.append(rushAttemptAction)
                
                // Rushing yards
                let rushYardsAction = PlayerActionPool.shared.getAction(
                    playerId: "\(rb.firstName)_\(rb.lastName)_\(rb.jerseyNum)",
                    playerName: "\(rb.firstName) \(rb.lastName)",
                    position: rb.position,
                    statType: .rushingYards,
                    value: result.yardGain
                )
                playerActions.append(rushYardsAction)
                
                // Touchdown if scoring
                if willScore {
                    let touchdownAction = PlayerActionPool.shared.getAction(
                        playerId: "\(rb.firstName)_\(rb.lastName)_\(rb.jerseyNum)",
                        playerName: "\(rb.firstName) \(rb.lastName)",
                        position: rb.position,
                        statType: .rushingTouchdown,
                        value: 1
                    )
                    playerActions.append(touchdownAction)
                }
            }
            
            // Add tackle for defender - but only sometimes (more realistic)
            if let def = defender, Double.random(in: 0...1) < 0.35 {  // Only 35% of rushing plays result in solo tackles
                let tackleAction = PlayerActionPool.shared.getAction(
                    playerId: "\(def.firstName)_\(def.lastName)_\(def.jerseyNum)",
                    playerName: "\(def.firstName) \(def.lastName)",
                    position: def.position,
                    statType: .tackle,
                    value: 1
                )
                playerActions.append(tackleAction)
            }
            
            result.playerActions = playerActions
            result.description = willScore ? "Rush for \(result.yardGain) yards - TOUCHDOWN!" : "Rush for \(result.yardGain) yards"
            
        } else {
            // Unsuccessful rush - still track attempt
            result.yardGain = Int.random(in: -2...1)
            
            var playerActions: [PlayerAction] = []
            
            if let rb = starterRB {
                // Still count the attempt
                let rushAttemptAction = PlayerActionPool.shared.getAction(
                    playerId: "\(rb.firstName)_\(rb.lastName)_\(rb.jerseyNum)",
                    playerName: "\(rb.firstName) \(rb.lastName)",
                    position: rb.position,
                    statType: .rushingAttempt,
                    value: 1
                )
                playerActions.append(rushAttemptAction)
                
                // Track yards (can be negative)
                let rushYardsAction = PlayerActionPool.shared.getAction(
                    playerId: "\(rb.firstName)_\(rb.lastName)_\(rb.jerseyNum)",
                    playerName: "\(rb.firstName) \(rb.lastName)",
                    position: rb.position,
                    statType: .rushingYards,
                    value: result.yardGain
                )
                playerActions.append(rushYardsAction)
            }
            
            // Add tackle - but only sometimes (more realistic)
            if let def = defender, Double.random(in: 0...1) < 0.35 {  // Only 35% of rushing plays result in solo tackles
                let tackleAction = PlayerActionPool.shared.getAction(
                    playerId: "\(def.firstName)_\(def.lastName)_\(def.jerseyNum)",
                    playerName: "\(def.firstName) \(def.lastName)",
                    position: def.position,
                    statType: .tackle,
                    value: 1
                )
                playerActions.append(tackleAction)
            }
            
            result.playerActions = playerActions
            result.description = result.yardGain > 0 ? "Rush for \(result.yardGain) yard\(result.yardGain == 1 ? "" : "s")" : 
                               result.yardGain == 0 ? "Rush for no gain" : "Rush for \(abs(result.yardGain)) yard loss"
        }
        
        // Check for turnover based on template
        if Double.random(in: 0...1) < template.turnoverChance {
            result.isTurnover = true
            result.playType = .fumble
            result.description += " - FUMBLE!"
        }
        
        return result
    }
    
    private func simulatePassingPlayFromTemplate(_ play: PlayResult, template: PlayTemplate, success: Bool, situation: GameSituation) -> PlayResult {
        var result = play
        
        // Get players for this play
        let starterQB = gameState.possession == .home ? homeTeamRoster?.starterQB : awayTeamRoster?.starterQB
        let offenseRoster = gameState.possession == .home ? homeTeamRoster : awayTeamRoster
        let defenseRoster = gameState.possession == .home ? awayTeamRoster : homeTeamRoster
        
        // Distribute passes among multiple receivers instead of just the first one
        // Note: receivers already includes both WRs and TEs in CachedTeamRoster
        let receiver = selectWeightedReceiver(from: offenseRoster?.receivers ?? [])
        
        let defender = defenseRoster?.defensiveBacks.first ?? defenseRoster?.linebackers.first
        
        // Check for sack first - use realistic NFL sack rate (final reduction)
        let baseSackChanceTemplate = 0.015 // 1.5% of pass attempts in the NFL result in sacks (realistic for individual players)
        let defenderRating = Int(defender?.overall ?? "75") ?? 75
        // Minimal rating adjustment to prevent inflation
        let ratingAdjustment = Double(defenderRating - 75) / 2500.0  // Very small adjustment
        let adjustedSackChance = max(0.008, min(0.025, baseSackChanceTemplate + ratingAdjustment)) // Cap between 0.8% and 2.5%
        if Double.random(in: 0...1) < adjustedSackChance {
            result.playType = .sack
            result.yardGain = Int.random(in: -8...(-3))
            
            // Create sack actions
            var playerActions: [PlayerAction] = []
            
            if let qb = starterQB {
                let sackTakenAction = PlayerActionPool.shared.getAction(
                    playerId: "\(qb.firstName)_\(qb.lastName)_\(qb.jerseyNum)",
                    playerName: "\(qb.firstName) \(qb.lastName)",
                    position: qb.position,
                    statType: .sackTaken,
                    value: 1
                )
                playerActions.append(sackTakenAction)
            }
            
            if let def = defender {
                let sackMadeAction = PlayerActionPool.shared.getAction(
                    playerId: "\(def.firstName)_\(def.lastName)_\(def.jerseyNum)",
                    playerName: "\(def.firstName) \(def.lastName)",
                    position: def.position,
                    statType: .sackMade,
                    value: 1
                )
                playerActions.append(sackMadeAction)
            }
            
            result.playerActions = playerActions
            result.description = "Sack for \(abs(result.yardGain)) yard loss"
            return result
        }
        
        // Create player actions for ALL passing plays
        var playerActions: [PlayerAction] = []
        
        if let qb = starterQB {
            // Passing attempt (always)
            let passAttemptAction = PlayerActionPool.shared.getAction(
                playerId: "\(qb.firstName)_\(qb.lastName)_\(qb.jerseyNum)",
                playerName: "\(qb.firstName) \(qb.lastName)",
                position: qb.position,
                statType: .passingAttempt,
                value: 1
            )
            playerActions.append(passAttemptAction)
        }
        
        if success {
            // Use template base yards with variance
            let variance = Int.random(in: -3...4)
            result.yardGain = max(0, template.baseYards + variance)
            
            // Check for big play based on template
            if Double.random(in: 0...1) < template.bigPlayChance {
                result.yardGain += Int.random(in: 10...25)
            }
            
            // Enhanced touchdown calculation with QB rating influence
            let willScore = calculateEnhancedTouchdownProbability(
                fieldPosition: gameState.fieldPosition,
                yardGain: result.yardGain,
                quarterback: starterQB,
                situation: situation
            )
            
            if let qb = starterQB {
                // Completion
                let passCompletionAction = PlayerActionPool.shared.getAction(
                    playerId: "\(qb.firstName)_\(qb.lastName)_\(qb.jerseyNum)",
                    playerName: "\(qb.firstName) \(qb.lastName)",
                    position: qb.position,
                    statType: .passingCompletion,
                    value: 1
                )
                playerActions.append(passCompletionAction)
                
                // Passing yards
                let passYardsAction = PlayerActionPool.shared.getAction(
                    playerId: "\(qb.firstName)_\(qb.lastName)_\(qb.jerseyNum)",
                    playerName: "\(qb.firstName) \(qb.lastName)",
                    position: qb.position,
                    statType: .passingYards,
                    value: result.yardGain
                )
                playerActions.append(passYardsAction)
                
                // Passing touchdown if scoring
                if willScore {
                    let passingTouchdownAction = PlayerActionPool.shared.getAction(
                        playerId: "\(qb.firstName)_\(qb.lastName)_\(qb.jerseyNum)",
                        playerName: "\(qb.firstName) \(qb.lastName)",
                        position: qb.position,
                        statType: .passingTouchdown,
                        value: 1
                    )
                    playerActions.append(passingTouchdownAction)
                }
            }
            
            if let rec = receiver {
                // Reception
                let receptionAction = PlayerActionPool.shared.getAction(
                    playerId: "\(rec.firstName)_\(rec.lastName)_\(rec.jerseyNum)",
                    playerName: "\(rec.firstName) \(rec.lastName)",
                    position: rec.position,
                    statType: .reception,
                    value: 1
                )
                playerActions.append(receptionAction)
                
                // Receiving yards
                let receivingYardsAction = PlayerActionPool.shared.getAction(
                    playerId: "\(rec.firstName)_\(rec.lastName)_\(rec.jerseyNum)",
                    playerName: "\(rec.firstName) \(rec.lastName)",
                    position: rec.position,
                    statType: .receivingYards,
                    value: result.yardGain
                )
                playerActions.append(receivingYardsAction)
                
                // Receiving touchdown if scoring
                if willScore {
                    let receivingTouchdownAction = PlayerActionPool.shared.getAction(
                        playerId: "\(rec.firstName)_\(rec.lastName)_\(rec.jerseyNum)",
                        playerName: "\(rec.firstName) \(rec.lastName)",
                        position: rec.position,
                        statType: .receivingTouchdown,
                        value: 1
                    )
                    playerActions.append(receivingTouchdownAction)
                }
            }
            
            // Add tackle for defender - but only sometimes (more realistic)
            if let def = defender, Double.random(in: 0...1) < 0.2 {  // Only 20% of pass completions result in solo tackles
                let tackleAction = PlayerActionPool.shared.getAction(
                    playerId: "\(def.firstName)_\(def.lastName)_\(def.jerseyNum)",
                    playerName: "\(def.firstName) \(def.lastName)",
                    position: def.position,
                    statType: .tackle,
                    value: 1
                )
                playerActions.append(tackleAction)
            }
            
            result.description = willScore ? "Pass completed for \(result.yardGain) yards - TOUCHDOWN!" : "Pass completed for \(result.yardGain) yards"
            
        } else {
            // Incomplete pass - QB attempt already added above
            result.yardGain = 0
            result.description = "Pass incomplete"
        }
        
        result.playerActions = playerActions
        
        // Check for interception - use realistic NFL rate
        if Double.random(in: 0...1) < template.turnoverChance {  // Remove the 0.2 multiplier since rates are now properly calibrated
            result.isTurnover = true
            result.playType = .interception
            result.yardGain = 0
            result.description = "INTERCEPTION!"
            
            // Add interception action
            if let def = defender {
                let interceptionAction = PlayerActionPool.shared.getAction(
                    playerId: "\(def.firstName)_\(def.lastName)_\(def.jerseyNum)",
                    playerName: "\(def.firstName) \(def.lastName)",
                    position: def.position,
                    statType: .interceptionMade,
                    value: 1
                )
                result.playerActions.append(interceptionAction)
            }
        }
        
        return result
    }
    
    // MARK: - Enhanced Touchdown Calculation
    private func calculateEnhancedTouchdownProbability(fieldPosition: Int, yardGain: Int, quarterback: MasterPlayer?, situation: GameSituation) -> Bool {
        // Basic touchdown check
        let basicTouchdown = (fieldPosition + yardGain) >= 100
        
        // If it's not a basic touchdown, check for enhanced touchdown opportunities
        if !basicTouchdown {
            // Only consider enhanced touchdowns in red zone or near goal line
            let distanceToGoal = 100 - fieldPosition
            guard distanceToGoal <= 25 else { return false } // Only within 25 yards
            
            // Get QB rating for bonus calculation
            let qbRating = Int(quarterback?.overall ?? "75") ?? 75
            
            // Calculate enhanced touchdown probability based on QB rating and situation
            var enhancedTouchdownChance = 0.0
            
            // Base enhanced touchdown chance increases as you get closer to goal line
            let proximityBonus = Double(25 - distanceToGoal) / 25.0 * 0.15 // Up to 15% bonus at goal line
            
            // QB rating bonus - elite QBs get significant red zone advantage
            let qbBonus = getQBTouchdownBonus(rating: qbRating)
            
            // Situational bonuses
            var situationalBonus = 0.0
            if situation.isRedZone {
                situationalBonus += 0.08 // 8% bonus in red zone
            }
            if situation.isGoalLine {
                situationalBonus += 0.12 // Additional 12% bonus at goal line
            }
            if situation.down >= 3 {
                situationalBonus += 0.05 // 5% bonus on 3rd/4th down (desperation)
            }
            
            enhancedTouchdownChance = proximityBonus + qbBonus + situationalBonus
            
            // Cap the enhanced chance at 25% to prevent too many extra touchdowns
            enhancedTouchdownChance = min(0.25, enhancedTouchdownChance)
            
            return Double.random(in: 0...1) < enhancedTouchdownChance
        }
        
        return basicTouchdown
    }
    
    private func getQBTouchdownBonus(rating: Int) -> Double {
        // Enhanced QB rating bonus for touchdown generation
        switch rating {
        case 95...99: return 0.20  // Elite QBs get 20% bonus (Mahomes, Allen, etc.)
        case 90...94: return 0.15  // Very good QBs get 15% bonus
        case 85...89: return 0.10  // Good QBs get 10% bonus
        case 80...84: return 0.05  // Above average QBs get 5% bonus
        case 75...79: return 0.0   // Average QBs get no bonus
        default: return -0.05      // Below average QBs get -5% penalty
        }
    }
    
    private func calculateEnhancedRushingTouchdownProbability(fieldPosition: Int, yardGain: Int, runningBack: MasterPlayer?, situation: GameSituation) -> Bool {
        // Basic touchdown check
        let basicTouchdown = (fieldPosition + yardGain) >= 100
        
        // If it's not a basic touchdown, check for enhanced touchdown opportunities
        if !basicTouchdown {
            // Only consider enhanced touchdowns in red zone or near goal line
            let distanceToGoal = 100 - fieldPosition
            guard distanceToGoal <= 20 else { return false } // Only within 20 yards for rushing
            
            // Get RB rating for bonus calculation
            let rbRating = Int(runningBack?.overall ?? "75") ?? 75
            
            // Calculate enhanced touchdown probability based on RB rating and situation
            var enhancedTouchdownChance = 0.0
            
            // Base enhanced touchdown chance increases as you get closer to goal line
            let proximityBonus = Double(20 - distanceToGoal) / 20.0 * 0.12 // Up to 12% bonus at goal line
            
            // RB rating bonus - elite RBs get red zone advantage
            let rbBonus = getRBTouchdownBonus(rating: rbRating)
            
            // Situational bonuses
            var situationalBonus = 0.0
            if situation.isRedZone {
                situationalBonus += 0.06 // 6% bonus in red zone
            }
            if situation.isGoalLine {
                situationalBonus += 0.10 // Additional 10% bonus at goal line
            }
            if situation.down >= 3 && situation.distance <= 3 {
                situationalBonus += 0.08 // 8% bonus on short yardage situations
            }
            
            enhancedTouchdownChance = proximityBonus + rbBonus + situationalBonus
            
            // Cap the enhanced chance at 20% to prevent too many extra touchdowns
            enhancedTouchdownChance = min(0.20, enhancedTouchdownChance)
            
            return Double.random(in: 0...1) < enhancedTouchdownChance
        }
        
        return basicTouchdown
    }
    
    private func getRBTouchdownBonus(rating: Int) -> Double {
        // RB rating bonus for touchdown generation (slightly lower than QB)
        switch rating {
        case 95...99: return 0.15  // Elite RBs get 15% bonus
        case 90...94: return 0.12  // Very good RBs get 12% bonus
        case 85...89: return 0.08  // Good RBs get 8% bonus
        case 80...84: return 0.04  // Above average RBs get 4% bonus
        case 75...79: return 0.0   // Average RBs get no bonus
        default: return -0.03      // Below average RBs get -3% penalty
        }
    }
}

// MARK: - Play Template System for Performance
struct PlayTemplate {
    let situationType: SituationType
    let playType: AdvancedGameSimulationEngine.PlayResult.PlayType
    let offensivePlay: AdvancedGameSimulationEngine.PlayResult.OffensivePlay
    let baseYards: Int
    let successRate: Double
    let bigPlayChance: Double
    let turnoverChance: Double
    
    enum SituationType: CaseIterable {
        case firstAndTen
        case firstAndLong
        case secondAndShort
        case secondAndMedium
        case secondAndLong
        case thirdAndShort
        case thirdAndMedium
        case thirdAndLong
        case fourthDown
        case redZone
        case goalLine
        case twoMinute
    }
    
    func situationMatches(_ situation: AdvancedGameSimulationEngine.GameSituation) -> Bool {
        switch situationType {
        case .firstAndTen:
            return situation.down == 1 && situation.distance == 10
        case .firstAndLong:
            return situation.down == 1 && situation.distance > 10
        case .secondAndShort:
            return situation.down == 2 && situation.distance <= 3
        case .secondAndMedium:
            return situation.down == 2 && situation.distance > 3 && situation.distance <= 7
        case .secondAndLong:
            return situation.down == 2 && situation.distance > 7
        case .thirdAndShort:
            return situation.down == 3 && situation.distance <= 3
        case .thirdAndMedium:
            return situation.down == 3 && situation.distance > 3 && situation.distance <= 7
        case .thirdAndLong:
            return situation.down == 3 && situation.distance > 7
        case .fourthDown:
            return situation.down == 4
        case .redZone:
            return situation.isRedZone && !situation.isGoalLine
        case .goalLine:
            return situation.isGoalLine
        case .twoMinute:
            return situation.isTwoMinute
        }
    }
}

// MARK: - Play Template Manager
class PlayTemplateManager {
    static let shared = PlayTemplateManager()
    private var templates: [PlayTemplate] = []
    
    private init() {
        buildPlayTemplates()
    }
    
    private func buildPlayTemplates() {
        // Build comprehensive play templates for all situations
        templates = [
            // First Down Templates
            PlayTemplate(situationType: .firstAndTen, playType: .rush, offensivePlay: .run, baseYards: 5, successRate: 0.65, bigPlayChance: 0.10, turnoverChance: 0.01),
            PlayTemplate(situationType: .firstAndTen, playType: .pass, offensivePlay: .shortPass, baseYards: 5, successRate: 0.68, bigPlayChance: 0.08, turnoverChance: 0.015),
            PlayTemplate(situationType: .firstAndTen, playType: .pass, offensivePlay: .mediumPass, baseYards: 9, successRate: 0.55, bigPlayChance: 0.12, turnoverChance: 0.02),
            
            PlayTemplate(situationType: .firstAndLong, playType: .pass, offensivePlay: .mediumPass, baseYards: 8, successRate: 0.50, bigPlayChance: 0.12, turnoverChance: 0.025),
            PlayTemplate(situationType: .firstAndLong, playType: .pass, offensivePlay: .deepPass, baseYards: 14, successRate: 0.35, bigPlayChance: 0.20, turnoverChance: 0.035),
            
            // Second Down Templates
            PlayTemplate(situationType: .secondAndShort, playType: .rush, offensivePlay: .run, baseYards: 4, successRate: 0.70, bigPlayChance: 0.08, turnoverChance: 0.01),
            PlayTemplate(situationType: .secondAndShort, playType: .pass, offensivePlay: .shortPass, baseYards: 4, successRate: 0.72, bigPlayChance: 0.08, turnoverChance: 0.015),
            
            PlayTemplate(situationType: .secondAndMedium, playType: .rush, offensivePlay: .run, baseYards: 5, successRate: 0.60, bigPlayChance: 0.12, turnoverChance: 0.01),
            PlayTemplate(situationType: .secondAndMedium, playType: .pass, offensivePlay: .shortPass, baseYards: 6, successRate: 0.65, bigPlayChance: 0.10, turnoverChance: 0.015),
            PlayTemplate(situationType: .secondAndMedium, playType: .pass, offensivePlay: .mediumPass, baseYards: 9, successRate: 0.52, bigPlayChance: 0.13, turnoverChance: 0.02),
            
            PlayTemplate(situationType: .secondAndLong, playType: .pass, offensivePlay: .mediumPass, baseYards: 10, successRate: 0.48, bigPlayChance: 0.15, turnoverChance: 0.025),
            PlayTemplate(situationType: .secondAndLong, playType: .pass, offensivePlay: .deepPass, baseYards: 16, successRate: 0.32, bigPlayChance: 0.22, turnoverChance: 0.035),
            
            // Third Down Templates
            PlayTemplate(situationType: .thirdAndShort, playType: .rush, offensivePlay: .run, baseYards: 3, successRate: 0.75, bigPlayChance: 0.08, turnoverChance: 0.01),
            PlayTemplate(situationType: .thirdAndShort, playType: .pass, offensivePlay: .shortPass, baseYards: 4, successRate: 0.78, bigPlayChance: 0.06, turnoverChance: 0.015),
            
            PlayTemplate(situationType: .thirdAndMedium, playType: .pass, offensivePlay: .shortPass, baseYards: 5, successRate: 0.62, bigPlayChance: 0.08, turnoverChance: 0.02),
            PlayTemplate(situationType: .thirdAndMedium, playType: .pass, offensivePlay: .mediumPass, baseYards: 8, successRate: 0.55, bigPlayChance: 0.12, turnoverChance: 0.025),
            
            PlayTemplate(situationType: .thirdAndLong, playType: .pass, offensivePlay: .mediumPass, baseYards: 11, successRate: 0.42, bigPlayChance: 0.16, turnoverChance: 0.03),
            PlayTemplate(situationType: .thirdAndLong, playType: .pass, offensivePlay: .deepPass, baseYards: 18, successRate: 0.28, bigPlayChance: 0.28, turnoverChance: 0.04),
            
            // Special Situation Templates
            PlayTemplate(situationType: .redZone, playType: .rush, offensivePlay: .run, baseYards: 4, successRate: 0.68, bigPlayChance: 0.15, turnoverChance: 0.015),
            PlayTemplate(situationType: .redZone, playType: .pass, offensivePlay: .shortPass, baseYards: 4, successRate: 0.65, bigPlayChance: 0.15, turnoverChance: 0.02),
            
            PlayTemplate(situationType: .goalLine, playType: .rush, offensivePlay: .run, baseYards: 1, successRate: 0.72, bigPlayChance: 0.75, turnoverChance: 0.015),
            PlayTemplate(situationType: .goalLine, playType: .pass, offensivePlay: .shortPass, baseYards: 2, successRate: 0.68, bigPlayChance: 0.70, turnoverChance: 0.025),
            
            PlayTemplate(situationType: .twoMinute, playType: .pass, offensivePlay: .shortPass, baseYards: 6, successRate: 0.70, bigPlayChance: 0.10, turnoverChance: 0.02),
            PlayTemplate(situationType: .twoMinute, playType: .pass, offensivePlay: .mediumPass, baseYards: 11, successRate: 0.55, bigPlayChance: 0.16, turnoverChance: 0.03),
            PlayTemplate(situationType: .twoMinute, playType: .pass, offensivePlay: .deepPass, baseYards: 20, successRate: 0.35, bigPlayChance: 0.32, turnoverChance: 0.04)
        ]
    }
    
    func getTemplatesForSituation(_ situation: AdvancedGameSimulationEngine.GameSituation) -> [PlayTemplate] {
        // Return templates that match the current situation
        // Priority order: specific situations first, then general
        var matchingTemplates: [PlayTemplate] = []
        
        // Check special situations first
        if situation.isGoalLine {
            matchingTemplates.append(contentsOf: templates.filter { $0.situationType == .goalLine })
        } else if situation.isRedZone {
            matchingTemplates.append(contentsOf: templates.filter { $0.situationType == .redZone })
        } else if situation.isTwoMinute {
            matchingTemplates.append(contentsOf: templates.filter { $0.situationType == .twoMinute })
        } else if situation.down == 4 {
            matchingTemplates.append(contentsOf: templates.filter { $0.situationType == .fourthDown })
        }
        
        // Add general down and distance templates
        for template in templates {
            if template.situationMatches(situation) && !matchingTemplates.contains(where: { $0.situationType == template.situationType && $0.playType == template.playType }) {
                matchingTemplates.append(template)
            }
        }
        
        return matchingTemplates.isEmpty ? getDefaultTemplates() : matchingTemplates
    }
    
    private func getDefaultTemplates() -> [PlayTemplate] {
        return [
            PlayTemplate(situationType: .firstAndTen, playType: .rush, offensivePlay: .run, baseYards: 5, successRate: 0.60, bigPlayChance: 0.10, turnoverChance: 0.01),
            PlayTemplate(situationType: .firstAndTen, playType: .pass, offensivePlay: .shortPass, baseYards: 5, successRate: 0.65, bigPlayChance: 0.10, turnoverChance: 0.02)
        ]
    }
}

// MARK: - Statistical Rebalancing Helper Functions
extension AdvancedGameSimulationEngine {
    
    /// Returns a multiplier based on player rating to create natural elite performance
    private func getRatingMultiplier(playerRating: Int) -> Double {
        switch playerRating {
        case 95...99: return 2.2  // Elite players get 2.2x opportunities
        case 90...94: return 1.7  // Very good players get 70% more
        case 85...89: return 1.3  // Good players get 30% more
        case 80...84: return 1.0  // Average baseline
        case 75...79: return 0.8  // Below average get 20% fewer
        default: return 0.6       // Poor players get 40% fewer
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
    
    /// Returns situational multipliers for high-pressure moments
    private func getSituationalMultiplier(situation: GameSituation, playerRating: Int) -> Double {
        var multiplier = 1.0
        
        // Elite players perform better in pressure situations
        if situation.isHighPressure && playerRating >= 90 {
            multiplier += 0.3
        }
        
        // Third down and red zone create more statistical opportunities
        if situation.down >= 3 {
            multiplier += 0.2
        }
        
        if situation.isRedZone {
            multiplier += 0.15
        }
        
        // Two-minute drill creates more passing opportunities (more sacks/INTs possible)
        if situation.isTwoMinute {
            multiplier += 0.25
        }
        
        return multiplier
    }
}

// Detailed game statistics are now defined in LeagueModels.swift
