import SwiftUI
import Metal
import Combine

// MARK: - Game Simulation View
struct GameSimulationView: View {
    let game: GameResult
    let onGameCompleted: (GameResult) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var currentGame: GameResult
    @State private var isSimulating = false
    @State private var simulationPhase: SimulationPhase = .preGame
    @State private var quarter: Int = 1
    @State private var timeRemaining: String = "15:00"
    @State private var playDescription: String = ""
    @State private var showingFinalStats = false
    
    enum SimulationPhase {
        case preGame, inProgress, halftime, completed
    }
    
    init(game: GameResult, onGameCompleted: @escaping (GameResult) -> Void) {
        self.game = game
        self.onGameCompleted = onGameCompleted
        self._currentGame = State(initialValue: game)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Metal-optimized background
                MetalGradientBackground(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGray6),
                        Color(.systemGray5).opacity(0.5)
                    ],
                    startPoint: UnitPoint.top,
                    endPoint: UnitPoint.bottom,
                    animationSpeed: 0.5
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Game Header
                        gameHeaderView
                        
                        // Score Display
                        scoreDisplayView
                        
                        // Metal-Enhanced Stats Visualization
                        if simulationPhase == .inProgress || simulationPhase == .completed {
                            MetalStatsVisualization(
                                homeScore: currentGame.homeScore,
                                awayScore: currentGame.awayScore,
                                homeTeam: currentGame.homeTeam.logoName,
                                awayTeam: currentGame.awayTeam.logoName
                            )
                            .standardCard(.ultraThin16)
                        }
                        
                        // Game Status
                        gameStatusView
                        
                        // Play by Play
                        if simulationPhase == .inProgress || simulationPhase == .completed {
                            playByPlayView
                        }
                        
                        // Simulation Controls
                        simulationControlsView
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                .metalOptimized()
            }
            .navigationTitle("Week \(game.week)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Additional guard handled at presentation level; keep console note here if needed
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if simulationPhase == .completed {
                        Button("Complete") {
                            onGameCompleted(currentGame)
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingFinalStats) {
                GameStatsView(game: currentGame)
            }
        }
    }
    
    // MARK: - Game Header
    private var gameHeaderView: some View {
        VStack(spacing: 16) {
                            Text("2025 PFL Season")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(1)
            
            HStack(spacing: 40) {
                // Away Team
                VStack(spacing: 12) {
                    MetalTeamLogoRenderer(
                        teamName: currentGame.awayTeam.logoName,
                        size: CGSize(width: 80, height: 80),
                        enableEffects: true
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    VStack(spacing: 4) {
                        Text(TeamData.getTeamDisplayName(currentGame.awayTeam.logoName))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("\(currentGame.awayTeam.record.wins)-\(currentGame.awayTeam.record.losses)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // VS
                VStack(spacing: 8) {
                    Text("@")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Week \(game.week)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Home Team
                VStack(spacing: 12) {
                    MetalTeamLogoRenderer(
                        teamName: currentGame.homeTeam.logoName,
                        size: CGSize(width: 80, height: 80),
                        enableEffects: true
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    VStack(spacing: 4) {
                        Text(TeamData.getTeamDisplayName(currentGame.homeTeam.logoName))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("\(currentGame.homeTeam.record.wins)-\(currentGame.homeTeam.record.losses)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .standardCard(.ultraThin16)
    }
    
    // MARK: - Score Display
    private var scoreDisplayView: some View {
        HStack(spacing: 60) {
            // Away Score
            VStack(spacing: 8) {
                Text("\(currentGame.awayScore)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(awayTeamLeading ? .green : .primary)
                
                Text("Away")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
            }
            
            // Score Separator
            Rectangle()
                .fill(.secondary.opacity(0.3))
                .frame(width: 2, height: 60)
            
            // Home Score
            VStack(spacing: 8) {
                Text("\(currentGame.homeScore)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(homeTeamLeading ? .green : .primary)
                
                Text("Home")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .standardCard(.ultraThin16)
    }
    
    private var awayTeamLeading: Bool {
        currentGame.awayScore > currentGame.homeScore
    }
    
    private var homeTeamLeading: Bool {
        currentGame.homeScore > currentGame.awayScore
    }
    
    // MARK: - Game Status
    private var gameStatusView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: gameStatusIcon)
                    .font(.title2)
                    .foregroundColor(gameStatusColor)
                
                Text(gameStatusText)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            if simulationPhase == .inProgress {
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("Quarter")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(quarter)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Time Left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(timeRemaining)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .monospaced()
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .standardCard(.ultraThin12)
    }
    
    private var gameStatusIcon: String {
        switch simulationPhase {
        case .preGame: return "clock.badge.questionmark"
        case .inProgress: return "play.circle.fill"
        case .halftime: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    private var gameStatusColor: Color {
        switch simulationPhase {
        case .preGame: return .orange
        case .inProgress: return .green
        case .halftime: return .blue
        case .completed: return .purple
        }
    }
    
    private var gameStatusText: String {
        switch simulationPhase {
        case .preGame: return "Ready to Start"
        case .inProgress: return "Game in Progress"
        case .halftime: return "Halftime"
        case .completed: return "Final"
        }
    }
    
    // MARK: - Play by Play
    private var playByPlayView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Latest Play")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            if !playDescription.isEmpty {
                Text(playDescription)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            } else {
                Text("Simulation will begin shortly...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .standardCard(.ultraThin12)
    }
    
    // MARK: - Simulation Controls
    private var simulationControlsView: some View {
        VStack(spacing: 16) {
            if simulationPhase == .preGame {
                Button {
                    startGameSimulation()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.title3)
                        
                        Text("Start Game")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSimulating)
                
            } else if simulationPhase == .inProgress {
                HStack(spacing: 16) {
                    GameActionButton(
                        title: "Next Play",
                        systemImage: "forward.fill",
                        color: .green,
                        isDisabled: isSimulating,
                        action: simulateNextPlay
                    )
                    
                    GameActionButton(
                        title: "Sim Quarter",
                        systemImage: "forward.end.fill",
                        color: .orange,
                        isDisabled: isSimulating,
                        action: simulateQuarter
                    )
                }
                
            } else if simulationPhase == .completed {
                VStack(spacing: 12) {
                    GameActionButton(
                        title: "View Game Stats",
                        systemImage: "chart.bar.fill",
                        color: .purple,
                        action: { showingFinalStats = true }
                    )
                    
                    PrimaryGameButton(
                        title: "Complete Game",
                        systemImage: "checkmark.circle.fill",
                        action: { onGameCompleted(currentGame) }
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Simulation Logic
    private func startGameSimulation() {
        isSimulating = true
        simulationPhase = .inProgress
        quarter = 1
        timeRemaining = "15:00"
        playDescription = "Game has started! Opening kickoff..."
        
        // Complete simulation immediately
        isSimulating = false
    }
    
    private func simulateNextPlay() {
        isSimulating = true
        
        // Generate random play result
        let plays = [
            "3-yard rush up the middle",
            "8-yard pass to the tight end",
            "15-yard completion to the receiver",
            "Incomplete pass",
            "6-yard rush to the left",
            "12-yard pass over the middle",
            "Sack for a loss of 3 yards",
            "20-yard pass down the sideline",
            "2-yard rush for a first down",
            "Interception returned for 15 yards",
            "Fumble recovered by defense",
            "35-yard field goal attempt - GOOD!",
            "25-yard touchdown pass!",
            "1-yard touchdown rush!"
        ]
        
        playDescription = plays.randomElement() ?? "Play completed"
        
        // Simulate scoring occasionally
        if playDescription.contains("touchdown") || playDescription.contains("field goal") {
            if Bool.random() {
                if playDescription.contains("touchdown") {
                    currentGame.homeScore += 7
                } else {
                    currentGame.homeScore += 3
                }
            } else {
                if playDescription.contains("touchdown") {
                    currentGame.awayScore += 7
                } else {
                    currentGame.awayScore += 3
                }
            }
        }
        
        // Update time
        updateGameTime()
        
        // Complete simulation immediately
        isSimulating = false
    }
    
    private func simulateQuarter() {
        isSimulating = true
        
        // Quick simulation of remaining quarter
        let quarterScores = generateQuarterScore()
        currentGame.homeScore += quarterScores.home
        currentGame.awayScore += quarterScores.away
        
        if quarter < 4 {
            quarter += 1
            timeRemaining = "15:00"
            
            if quarter == 3 {
                simulationPhase = .halftime
                playDescription = "End of \(quarter - 1)\(getOrdinalSuffix(quarter - 1)) quarter. Halftime score: \(currentGame.awayScore) - \(currentGame.homeScore)"
                
                // Continue to second half immediately
                simulationPhase = .inProgress
                playDescription = "Second half begins..."
                isSimulating = false
                return
            } else {
                playDescription = "End of \(quarter - 1)\(getOrdinalSuffix(quarter - 1)) quarter. Score: \(currentGame.awayScore) - \(currentGame.homeScore)"
            }
        } else {
            // Game completed
            simulationPhase = .completed
            currentGame.isCompleted = true
            timeRemaining = "0:00"
            
            let winner = currentGame.homeScore > currentGame.awayScore ? 
                TeamData.getTeamDisplayName(currentGame.homeTeam.logoName) : 
                TeamData.getTeamDisplayName(currentGame.awayTeam.logoName)
            
            playDescription = "FINAL: \(winner) wins \(max(currentGame.homeScore, currentGame.awayScore)) - \(min(currentGame.homeScore, currentGame.awayScore))"
        }
        
        // Complete simulation immediately
        isSimulating = false
    }
    
    private func updateGameTime() {
        let times = ["14:23", "13:45", "12:18", "11:02", "9:47", "8:33", "7:21", "6:05", "4:42", "3:28", "2:14", "1:03", "0:45", "0:15", "0:00"]
        
        if let currentIndex = times.firstIndex(of: timeRemaining),
           currentIndex < times.count - 1 {
            timeRemaining = times[currentIndex + 1]
        } else if timeRemaining == "0:00" && quarter < 4 {
            quarter += 1
            timeRemaining = "15:00"
        } else if timeRemaining == "0:00" && quarter == 4 {
            simulationPhase = .completed
            currentGame.isCompleted = true
        }
    }
    
    private func generateQuarterScore() -> (home: Int, away: Int) {
        let homeTeamStrength = currentGame.homeTeam.overallRating + 3 // Home field advantage
        let awayTeamStrength = currentGame.awayTeam.overallRating
        
        let homePoints = Int.random(in: 0...14) + (homeTeamStrength > awayTeamStrength ? Int.random(in: 0...7) : 0)
        let awayPoints = Int.random(in: 0...14) + (awayTeamStrength > homeTeamStrength ? Int.random(in: 0...7) : 0)
        
        return (home: homePoints, away: awayPoints)
    }
    
    private func getOrdinalSuffix(_ number: Int) -> String {
        switch number {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}

// MARK: - Game Stats View
struct GameStatsView: View {
    let game: GameResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Final Score
                    finalScoreSection
                    
                    // Enhanced Team Stats
                    if let detailedStats = game.detailedStats {
                        enhancedTeamStatsSection(detailedStats)
                    } else {
                        basicTeamStatsSection
                    }
                    
                    // Scoring Plays
                    if !game.scoringPlays.isEmpty {
                        scoringPlaysSection
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .navigationTitle("Game Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var finalScoreSection: some View {
        VStack(spacing: 16) {
            Text("Final Score")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                // Away Team
                VStack(spacing: 8) {
                    Image(game.awayTeam.logoName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                    
                    Text(TeamData.getTeamDisplayName(game.awayTeam.logoName))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("\(game.awayScore)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(game.awayScore > game.homeScore ? .green : .primary)
                }
                
                Text("@")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                // Home Team
                VStack(spacing: 8) {
                    Image(game.homeTeam.logoName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                    
                    Text(TeamData.getTeamDisplayName(game.homeTeam.logoName))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("\(game.homeScore)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(game.homeScore > game.awayScore ? .green : .primary)
                }
            }
            
            if let detailedStats = game.detailedStats {
                Text("Game Length: \(formatGameLength(detailedStats.gameLength))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func enhancedTeamStatsSection(_ stats: DetailedGameStats) -> some View {
        VStack(spacing: 20) {
            Text("Team Statistics")
                .font(.title2)
                .fontWeight(.bold)
            
            // Key Stats Overview
            keyStatsOverview(stats)
            
            // Passing Stats
            passingStatsSection(stats)
            
            // Rushing Stats
            rushingStatsSection(stats)
            
            // Efficiency Stats
            efficiencyStatsSection(stats)
            
            // Time of Possession
            timeOfPossessionSection(stats)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func keyStatsOverview(_ stats: DetailedGameStats) -> some View {
        VStack(spacing: 16) {
            Text("Key Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                statColumn(
                    title: TeamData.getTeamDisplayName(game.awayTeam.logoName),
                    stats: [
                        ("Total Yards", "\(stats.awayTeamStats.totalYards)"),
                        ("First Downs", "\(stats.awayTeamStats.firstDowns)"),
                        ("Turnovers", "\(stats.awayTeamStats.turnovers)"),
                        ("Penalties", "\(stats.awayTeamStats.penalties)-\(stats.awayTeamStats.penaltyYards)")
                    ]
                )
                
                Spacer()
                
                statColumn(
                    title: TeamData.getTeamDisplayName(game.homeTeam.logoName),
                    stats: [
                        ("Total Yards", "\(stats.homeTeamStats.totalYards)"),
                        ("First Downs", "\(stats.homeTeamStats.firstDowns)"),
                        ("Turnovers", "\(stats.homeTeamStats.turnovers)"),
                        ("Penalties", "\(stats.homeTeamStats.penalties)-\(stats.homeTeamStats.penaltyYards)")
                    ]
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func passingStatsSection(_ stats: DetailedGameStats) -> some View {
        VStack(spacing: 16) {
            Text("Passing Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                statColumn(
                    title: TeamData.getTeamDisplayName(game.awayTeam.logoName),
                    stats: [
                        ("Comp/Att", "\(stats.awayTeamStats.passingCompletions)/\(stats.awayTeamStats.passingAttempts)"),
                        ("Yards", "\(stats.awayTeamStats.passingYards)"),
                        ("Comp %", String(format: "%.1f%%", stats.awayTeamStats.completionPercentage)),
                        ("TD/INT", "\(stats.awayTeamStats.passingTouchdowns)/\(stats.awayTeamStats.interceptions)"),
                        ("Sacks", "\(stats.awayTeamStats.sacksAllowed)")
                    ]
                )
                
                Spacer()
                
                statColumn(
                    title: TeamData.getTeamDisplayName(game.homeTeam.logoName),
                    stats: [
                        ("Comp/Att", "\(stats.homeTeamStats.passingCompletions)/\(stats.homeTeamStats.passingAttempts)"),
                        ("Yards", "\(stats.homeTeamStats.passingYards)"),
                        ("Comp %", String(format: "%.1f%%", stats.homeTeamStats.completionPercentage)),
                        ("TD/INT", "\(stats.homeTeamStats.passingTouchdowns)/\(stats.homeTeamStats.interceptions)"),
                        ("Sacks", "\(stats.homeTeamStats.sacksAllowed)")
                    ]
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func rushingStatsSection(_ stats: DetailedGameStats) -> some View {
        VStack(spacing: 16) {
            Text("Rushing Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                statColumn(
                    title: TeamData.getTeamDisplayName(game.awayTeam.logoName),
                    stats: [
                        ("Attempts", "\(stats.awayTeamStats.rushingAttempts)"),
                        ("Yards", "\(stats.awayTeamStats.rushingYards)"),
                        ("Avg", stats.awayTeamStats.rushingAttempts > 0 ? String(format: "%.1f", Double(stats.awayTeamStats.rushingYards) / Double(stats.awayTeamStats.rushingAttempts)) : "0.0"),
                        ("Touchdowns", "\(stats.awayTeamStats.rushingTouchdowns)"),
                        ("Fumbles", "\(stats.awayTeamStats.fumbles)")
                    ]
                )
                
                Spacer()
                
                statColumn(
                    title: TeamData.getTeamDisplayName(game.homeTeam.logoName),
                    stats: [
                        ("Attempts", "\(stats.homeTeamStats.rushingAttempts)"),
                        ("Yards", "\(stats.homeTeamStats.rushingYards)"),
                        ("Avg", stats.homeTeamStats.rushingAttempts > 0 ? String(format: "%.1f", Double(stats.homeTeamStats.rushingYards) / Double(stats.homeTeamStats.rushingAttempts)) : "0.0"),
                        ("Touchdowns", "\(stats.homeTeamStats.rushingTouchdowns)"),
                        ("Fumbles", "\(stats.homeTeamStats.fumbles)")
                    ]
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func efficiencyStatsSection(_ stats: DetailedGameStats) -> some View {
        VStack(spacing: 16) {
            Text("Efficiency Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                statColumn(
                    title: TeamData.getTeamDisplayName(game.awayTeam.logoName),
                    stats: [
                        ("3rd Down", "\(stats.awayTeamStats.thirdDownConversions)/\(stats.awayTeamStats.thirdDownAttempts)"),
                        ("3rd Down %", String(format: "%.1f%%", stats.awayTeamStats.thirdDownPercentage)),
                        ("Red Zone", "\(stats.awayTeamStats.redZoneScores)/\(stats.awayTeamStats.redZoneAttempts)"),
                        ("Red Zone %", String(format: "%.1f%%", stats.awayTeamStats.redZonePercentage)),
                        ("FG", "\(stats.awayTeamStats.fieldGoalsMade)/\(stats.awayTeamStats.fieldGoalAttempts)")
                    ]
                )
                
                Spacer()
                
                statColumn(
                    title: TeamData.getTeamDisplayName(game.homeTeam.logoName),
                    stats: [
                        ("3rd Down", "\(stats.homeTeamStats.thirdDownConversions)/\(stats.homeTeamStats.thirdDownAttempts)"),
                        ("3rd Down %", String(format: "%.1f%%", stats.homeTeamStats.thirdDownPercentage)),
                        ("Red Zone", "\(stats.homeTeamStats.redZoneScores)/\(stats.homeTeamStats.redZoneAttempts)"),
                        ("Red Zone %", String(format: "%.1f%%", stats.homeTeamStats.redZonePercentage)),
                        ("FG", "\(stats.homeTeamStats.fieldGoalsMade)/\(stats.homeTeamStats.fieldGoalAttempts)")
                    ]
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func timeOfPossessionSection(_ stats: DetailedGameStats) -> some View {
        VStack(spacing: 16) {
            Text("Time of Possession")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text(TeamData.getTeamDisplayName(game.awayTeam.logoName))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(stats.awayTimeOfPossession)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 8) {
                    Text(TeamData.getTeamDisplayName(game.homeTeam.logoName))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(stats.homeTimeOfPossession)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var scoringPlaysSection: some View {
        VStack(spacing: 16) {
            Text("Scoring Plays")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                ForEach(game.scoringPlays) { play in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Q\(play.quarter) - \(play.time)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(play.team)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(play.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("+\(play.points)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            
                            Text("\(play.awayScore) - \(play.homeScore)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var basicTeamStatsSection: some View {
        VStack(spacing: 20) {
            Text("Team Statistics")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Basic stats - upgrade to advanced simulation for detailed statistics")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack {
                VStack(spacing: 12) {
                    Text(TeamData.getTeamDisplayName(game.awayTeam.logoName))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Team Rating: \(game.awayTeam.overallRating)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Text(TeamData.getTeamDisplayName(game.homeTeam.logoName))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Team Rating: \(game.homeTeam.overallRating)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func statColumn(title: String, stats: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            ForEach(stats, id: \.0) { stat in
                HStack {
                    Text(stat.0)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(stat.1)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatGameLength(_ length: TimeInterval) -> String {
        let hours = Int(length) / 3600
        let minutes = Int(length) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    GameSimulationView(
        game: GameResult(
            week: 1,
            homeTeam: LeagueTeam(
                logoName: "Chicago",
                name: "Chicago Bears",
                conference: "NFC",
                division: "NFC North",
                primaryColor: "#0B162A",
                secondaryColor: "#C83803",
                players: [],
                overallRating: 78,
                coach: Coach(
                    firstName: "Matt",
                    lastName: "Eberflus",
                    overallRating: 78,
                    offensiveScheme: "West Coast",
                    defensiveScheme: "4-3 Base",
                    experience: 8,
                    offensiveCoordinator: OffensiveCoordinator(
                        firstName: "Mock",
                        lastName: "OC",
                        overallRating: 75,
                        offensiveScheme: "West Coast",
                        experience: 5
                    ),
                    defensiveCoordinator: DefensiveCoordinator(
                        firstName: "Mock",
                        lastName: "DC",
                        overallRating: 75,
                        defensiveScheme: "4-3 Base",
                        experience: 5
                    )
                )
            ),
            awayTeam: LeagueTeam(
                logoName: "Detroit",
                name: "Detroit Lions",
                conference: "NFC",
                division: "NFC North",
                primaryColor: "#0076B6",
                secondaryColor: "#B0B7BC",
                players: [],
                overallRating: 82,
                coach: Coach(
                    firstName: "Dan",
                    lastName: "Campbell",
                    overallRating: 86,
                    offensiveScheme: "Pro Style",
                    defensiveScheme: "3-4 Base",
                    experience: 5,
                    offensiveCoordinator: OffensiveCoordinator(
                        firstName: "Mock",
                        lastName: "OC",
                        overallRating: 80,
                        offensiveScheme: "Pro Style",
                        experience: 8
                    ),
                    defensiveCoordinator: DefensiveCoordinator(
                        firstName: "Mock",
                        lastName: "DC",
                        overallRating: 80,
                        defensiveScheme: "3-4 Base",
                        experience: 8
                    )
                )
            )
        ),
        onGameCompleted: { _ in }
    )
}
