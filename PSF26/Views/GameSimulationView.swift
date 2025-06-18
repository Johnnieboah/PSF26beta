import SwiftUI

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
                // Background
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(.systemBackground), location: 0.0),
                        .init(color: Color(.systemGray6), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Game Header
                        gameHeaderView
                        
                        // Score Display
                        scoreDisplayView
                        
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
            }
            .navigationTitle("Week \(game.week)")
            .navigationBarTitleDisplayMode(.inline)
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
            Text("2025 NFL Season")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(1)
            
            HStack(spacing: 40) {
                // Away Team
                VStack(spacing: 12) {
                    Image(currentGame.awayTeam.logoName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
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
                    Image(currentGame.homeTeam.logoName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
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
                    Button {
                        simulateNextPlay()
                    } label: {
                        HStack {
                            Image(systemName: "forward.fill")
                            Text("Next Play")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.green, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isSimulating)
                    
                    Button {
                        simulateQuarter()
                    } label: {
                        HStack {
                            Image(systemName: "forward.end.fill")
                            Text("Sim Quarter")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isSimulating)
                }
                
            } else if simulationPhase == .completed {
                VStack(spacing: 12) {
                    Button {
                        showingFinalStats = true
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                            Text("View Game Stats")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.purple, in: RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Button {
                        onGameCompleted(currentGame)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Complete Game")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                    }
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSimulating = false
        }
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSimulating = false
        }
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
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    simulationPhase = .inProgress
                    playDescription = "Second half begins..."
                    isSimulating = false
                }
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSimulating = false
        }
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
                    
                    // Team Stats
                    teamStatsSection
                    
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
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 40) {
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
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(game.awayScore > game.homeScore ? .green : .primary)
                }
                
                Text("-")
                    .font(.title)
                    .foregroundColor(.secondary)
                
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
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(game.homeScore > game.awayScore ? .green : .primary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var teamStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Team Stats")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                statRow(title: "Total Yards", away: "\(Int.random(in: 250...450))", home: "\(Int.random(in: 250...450))")
                statRow(title: "Passing Yards", away: "\(Int.random(in: 150...350))", home: "\(Int.random(in: 150...350))")
                statRow(title: "Rushing Yards", away: "\(Int.random(in: 80...200))", home: "\(Int.random(in: 80...200))")
                statRow(title: "First Downs", away: "\(Int.random(in: 15...25))", home: "\(Int.random(in: 15...25))")
                statRow(title: "Turnovers", away: "\(Int.random(in: 0...3))", home: "\(Int.random(in: 0...3))")
                statRow(title: "Time of Possession", away: "\(Int.random(in: 25...35)):00", home: "\(Int.random(in: 25...35)):00")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func statRow(title: String, away: String, home: String) -> some View {
        HStack {
            Text(away)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Text(home)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .trailing)
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
                overallRating: 78
            ),
            awayTeam: LeagueTeam(
                logoName: "Detroit",
                name: "Detroit Lions",
                conference: "NFC",
                division: "NFC North",
                primaryColor: "#0076B6",
                secondaryColor: "#B0B7BC",
                players: [],
                overallRating: 82
            )
        ),
        onGameCompleted: { _ in }
    )
}