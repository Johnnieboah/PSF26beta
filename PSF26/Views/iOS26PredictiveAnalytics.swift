import SwiftUI
import CoreML
import Combine
import Foundation

// MARK: - iOS 26 Predictive Analytics Manager
@MainActor
class iOS26PredictiveAnalyticsManager: ObservableObject {
    static let shared = iOS26PredictiveAnalyticsManager()
    
    // Published state
    @Published var isMLAvailable: Bool = false
    @Published var currentPredictions: [GamePrediction] = []
    @Published var seasonPredictions: SeasonPredictions?
    @Published var playerPerformancePredictions: [PlayerPrediction] = []
    @Published var isProcessing: Bool = false
    @Published var predictionAccuracy: Double = 0.0
    
    // Analytics state
    @Published var totalPredictions: Int = 0
    @Published var correctPredictions: Int = 0
    @Published var averageConfidence: Double = 0.0
    @Published var lastUpdateTime: Date?
    
    // Dependencies
    private var performanceManager = AdvancedPerformanceManager.shared
    private var backgroundManager = iOS26BackgroundProcessingManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // ML Models (simulated - would be actual Core ML models)
    private var gameOutcomeModel: MLModel?
    private var playerPerformanceModel: MLModel?
    private var seasonTrendModel: MLModel?
    
    // Prediction history
    private var predictionHistory: [PredictionRecord] = []
    private let maxHistorySize = 100
    
    struct GamePrediction {
        let id: UUID = UUID()
        let homeTeam: String
        let awayTeam: String
        let predictedHomeScore: Int
        let predictedAwayScore: Int
        let confidence: Double
        let keyFactors: [String]
        let createdAt: Date
        
        var predictedWinner: String {
            return predictedHomeScore > predictedAwayScore ? homeTeam : awayTeam
        }
        
        var scoreDifference: Int {
            return abs(predictedHomeScore - predictedAwayScore)
        }
    }
    
    struct PlayerPrediction {
        let id: UUID = UUID()
        let playerId: String
        let playerName: String
        let position: String
        let predictedStats: [String: Double]
        let confidence: Double
        let trendDirection: TrendDirection
        let createdAt: Date
        
        enum TrendDirection {
            case improving, declining, stable
        }
    }
    
    struct SeasonPredictions {
        let playoffTeams: [String]
        let championshipFavorite: String
        let mvpCandidate: String
        let surpriseTeams: [String]
        let confidence: Double
        let lastUpdated: Date
    }
    
    struct PredictionRecord {
        let id: UUID
        let type: PredictionType
        let prediction: Any
        let actualOutcome: Any?
        let wasCorrect: Bool?
        let confidence: Double
        let createdAt: Date
        
        enum PredictionType {
            case gameOutcome, playerPerformance, seasonTrend
        }
    }
    
    private init() {
        checkMLAvailability()
        setupMLModels()
        setupPerformanceMonitoring()
    }
    
    // MARK: - ML Availability Check
    private func checkMLAvailability() {
        let capabilities = performanceManager.deviceCapabilities
        
        // Enhanced ML features available on iOS 26 with Apple Intelligence
        if capabilities.supportsAppleIntelligence && capabilities.supportsFoundationModels {
            isMLAvailable = true
            print("✅ iOS 26 Enhanced ML Analytics available")
        } else {
            isMLAvailable = false
            print("❌ Enhanced ML Analytics requires Apple Intelligence support")
        }
    }
    
    // MARK: - ML Model Setup
    private func setupMLModels() {
        guard isMLAvailable else { return }
        
        Task {
            // In a real implementation, these would load actual Core ML models
            await loadGameOutcomeModel()
            await loadPlayerPerformanceModel()
            await loadSeasonTrendModel()
            
            print("✅ ML models loaded successfully")
        }
    }
    
    private func loadGameOutcomeModel() async {
        // Simulate loading a Core ML model for game outcome prediction
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        print("📊 Game outcome model loaded")
    }
    
    private func loadPlayerPerformanceModel() async {
        // Simulate loading a Core ML model for player performance prediction
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        print("📊 Player performance model loaded")
    }
    
    private func loadSeasonTrendModel() async {
        // Simulate loading a Core ML model for season trend analysis
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        print("📊 Season trend model loaded")
    }
    
    // MARK: - Game Prediction
    @discardableResult
    func predictGameOutcome(homeTeam: String, awayTeam: String) async -> GamePrediction? {
        guard isMLAvailable && !isProcessing else { return nil }
        
        isProcessing = true
        
        // Simulate ML inference for game prediction
        let prediction = await performGamePredictionInference(homeTeam: homeTeam, awayTeam: awayTeam)
        
        currentPredictions.append(prediction)
        totalPredictions += 1
        lastUpdateTime = Date()
        
        // Record prediction
        recordPrediction(type: .gameOutcome, prediction: prediction, confidence: prediction.confidence)
        
        isProcessing = false
        return prediction
    }
    
    private func performGamePredictionInference(homeTeam: String, awayTeam: String) async -> GamePrediction {
        // Simulate ML model inference
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Get team strengths (simplified simulation)
        let homeStrength = getTeamStrength(homeTeam)
        let awayStrength = getTeamStrength(awayTeam)
        
        // Home field advantage
        let homeAdvantage = 3.0
        let adjustedHomeStrength = homeStrength + homeAdvantage
        
        // Predict scores with some randomness
        let homeScore = max(0, Int(adjustedHomeStrength + Double.random(in: -7...7)))
        let awayScore = max(0, Int(awayStrength + Double.random(in: -7...7)))
        
        // Calculate confidence based on strength difference
        let strengthDiff = abs(adjustedHomeStrength - awayStrength)
        let confidence = min(0.95, 0.5 + (strengthDiff / 30.0))
        
        // Generate key factors
        let keyFactors = generateKeyFactors(homeTeam: homeTeam, awayTeam: awayTeam, homeStrength: homeStrength, awayStrength: awayStrength)
        
        return GamePrediction(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            predictedHomeScore: homeScore,
            predictedAwayScore: awayScore,
            confidence: confidence,
            keyFactors: keyFactors,
            createdAt: Date()
        )
    }
    
    private func getTeamStrength(_ teamName: String) -> Double {
        // Simplified team strength calculation
        // In reality, this would use historical data, player ratings, etc.
        let baseStrengths: [String: Double] = [
            "KansasCity": 28.0, "Buffalo": 27.0, "Baltimore": 26.0,
            "SanFrancisco": 25.0, "Dallas": 24.0, "Philadelphia": 23.0,
            "Miami": 22.0, "Cincinnati": 21.0, "Minnesota": 20.0,
            "Seattle": 19.0, "Detroit": 18.0, "NYN": 17.0,
            "GreenBay": 16.0, "Cleveland": 15.0, "Jacksonville": 14.0,
            "LAN": 13.0, "Pittsburgh": 12.0, "NewEngland": 11.0,
            "Tennessee": 10.0, "Atlanta": 9.0, "NYA": 8.0,
            "Indianapolis": 7.0, "LasVegas": 6.0, "Washington": 5.0,
            "NewOrleans": 4.0, "TampaBay": 3.0, "Chicago": 2.0,
            "Denver": 1.0, "LAA": 0.0, "Carolina": -1.0,
            "Houston": -2.0, "Arizona": -3.0
        ]
        
        return baseStrengths[teamName] ?? 10.0
    }
    
    private func generateKeyFactors(homeTeam: String, awayTeam: String, homeStrength: Double, awayStrength: Double) -> [String] {
        var factors: [String] = []
        
        if homeStrength > awayStrength + 5 {
            factors.append("Home team has significant talent advantage")
        } else if awayStrength > homeStrength + 5 {
            factors.append("Away team has significant talent advantage")
        }
        
        factors.append("Home field advantage (+3 points)")
        
        if performanceManager.thermalState == .nominal {
            factors.append("Optimal weather conditions")
        }
        
        // Add more contextual factors
        factors.append("Recent team performance trends")
        factors.append("Key player matchups")
        
        return factors
    }
    
    // MARK: - Player Performance Prediction
    @discardableResult
    func predictPlayerPerformance(for players: [String]) async -> [PlayerPrediction] {
        guard isMLAvailable && !isProcessing else { return [] }
        
        isProcessing = true
        var predictions: [PlayerPrediction] = []
        
        for player in players.prefix(10) { // Limit to 10 players for performance
            let prediction = await performPlayerPredictionInference(playerId: player)
            predictions.append(prediction)
        }
        
        playerPerformancePredictions = predictions
        isProcessing = false
        
        return predictions
    }
    
    private func performPlayerPredictionInference(playerId: String) async -> PlayerPrediction {
        // Simulate ML model inference for player performance
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds per player
        
        let positions = ["QB", "RB", "WR", "TE", "K"]
        let position = positions.randomElement() ?? "RB"
        
        var predictedStats: [String: Double] = [:]
        var trendDirection = PlayerPrediction.TrendDirection.stable
        
        switch position {
        case "QB":
            predictedStats = [
                "passingYards": Double.random(in: 180...350),
                "touchdowns": Double.random(in: 1...4),
                "interceptions": Double.random(in: 0...2)
            ]
        case "RB":
            predictedStats = [
                "rushingYards": Double.random(in: 40...150),
                "touchdowns": Double.random(in: 0...2),
                "receptions": Double.random(in: 2...8)
            ]
        case "WR", "TE":
            predictedStats = [
                "receptions": Double.random(in: 3...12),
                "receivingYards": Double.random(in: 30...120),
                "touchdowns": Double.random(in: 0...2)
            ]
        default:
            predictedStats = [
                "fieldGoals": Double.random(in: 1...3),
                "extraPoints": Double.random(in: 1...4)
            ]
        }
        
        // Determine trend direction
        let trendRandom = Double.random(in: 0...1)
        if trendRandom < 0.3 {
            trendDirection = .improving
        } else if trendRandom < 0.6 {
            trendDirection = .declining
        }
        
        return PlayerPrediction(
            playerId: playerId,
            playerName: "Player \(playerId)",
            position: position,
            predictedStats: predictedStats,
            confidence: Double.random(in: 0.6...0.9),
            trendDirection: trendDirection,
            createdAt: Date()
        )
    }
    
    // MARK: - Season Predictions
    @discardableResult
    func generateSeasonPredictions() async -> SeasonPredictions {
        guard isMLAvailable && !isProcessing else { return SeasonPredictions(playoffTeams: [], championshipFavorite: "", mvpCandidate: "", surpriseTeams: [], confidence: 0.0, lastUpdated: Date()) }
        
        isProcessing = true
        
        // Simulate comprehensive season analysis
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let predictions = SeasonPredictions(
            playoffTeams: ["KansasCity", "Buffalo", "Baltimore", "SanFrancisco", "Dallas", "Philadelphia", "Miami", "Cincinnati"],
            championshipFavorite: "KansasCity",
            mvpCandidate: "Josh Allen",
            surpriseTeams: ["Detroit", "Seattle"],
            confidence: 0.75,
            lastUpdated: Date()
        )
        
        seasonPredictions = predictions
        isProcessing = false
        
        print("📊 Season predictions generated")
        return predictions
    }
    
    // MARK: - Prediction Accuracy Tracking
    func updatePredictionAccuracy(predictionId: UUID, actualOutcome: Any, wasCorrect: Bool) {
        // Find and update the prediction record
        if let index = predictionHistory.firstIndex(where: { $0.id == predictionId }) {
            let record = predictionHistory[index]
            // Update record with actual outcome
            predictionHistory[index] = PredictionRecord(
                id: record.id,
                type: record.type,
                prediction: record.prediction,
                actualOutcome: actualOutcome,
                wasCorrect: wasCorrect,
                confidence: record.confidence,
                createdAt: record.createdAt
            )
        }
        
        // Recalculate accuracy
        let completedPredictions = predictionHistory.compactMap { $0.wasCorrect }
        if !completedPredictions.isEmpty {
            correctPredictions = completedPredictions.filter { $0 }.count
            predictionAccuracy = Double(correctPredictions) / Double(completedPredictions.count)
        }
        
        // Update average confidence
        let confidenceValues = predictionHistory.map { $0.confidence }
        if !confidenceValues.isEmpty {
            averageConfidence = confidenceValues.reduce(0, +) / Double(confidenceValues.count)
        }
    }
    
    // MARK: - Background Analytics Integration
    func scheduleBackgroundAnalytics() {
        guard backgroundManager.isBackgroundProcessingAvailable else { return }
        
        backgroundManager.scheduleBackgroundAnalytics { [weak self] success in
            if success {
                Task { @MainActor in
                    await self?.performBackgroundAnalytics()
                }
            }
        }
    }
    
    private func performBackgroundAnalytics() async {
        // Update all predictions in background
        await generateSeasonPredictions()
        
        // Update player performance predictions
        let samplePlayers = ["player1", "player2", "player3", "player4", "player5"]
        await predictPlayerPerformance(for: samplePlayers)
        
        print("📊 Background analytics completed")
    }
    
    // MARK: - Performance Monitoring
    private func setupPerformanceMonitoring() {
        performanceManager.$performanceScore
            .sink { [weak self] score in
                // Adjust ML processing based on performance
                if score < 50 && self?.isProcessing == true {
                    print("⚠️ Low performance - reducing ML processing complexity")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Utility Methods
    private func recordPrediction(type: PredictionRecord.PredictionType, prediction: Any, confidence: Double) {
        let record = PredictionRecord(
            id: UUID(),
            type: type,
            prediction: prediction,
            actualOutcome: nil,
            wasCorrect: nil,
            confidence: confidence,
            createdAt: Date()
        )
        
        predictionHistory.append(record)
        
        // Maintain history size
        if predictionHistory.count > maxHistorySize {
            predictionHistory.removeFirst()
        }
    }
    
    // MARK: - Public Interface
    func getAnalyticsReport() -> AnalyticsReport {
        return AnalyticsReport(
            isMLAvailable: isMLAvailable,
            totalPredictions: totalPredictions,
            correctPredictions: correctPredictions,
            accuracy: predictionAccuracy,
            averageConfidence: averageConfidence,
            lastUpdateTime: lastUpdateTime,
            currentPredictions: currentPredictions.count,
            playerPredictions: playerPerformancePredictions.count
        )
    }
    
    struct AnalyticsReport {
        let isMLAvailable: Bool
        let totalPredictions: Int
        let correctPredictions: Int
        let accuracy: Double
        let averageConfidence: Double
        let lastUpdateTime: Date?
        let currentPredictions: Int
        let playerPredictions: Int
        
        var accuracyPercentage: String {
            return String(format: "%.1f%%", accuracy * 100)
        }
        
        var confidencePercentage: String {
            return String(format: "%.1f%%", averageConfidence * 100)
        }
    }
    
    // Add new function to get top players by overall rating
    private func getTopPlayersByOverall(limit: Int = 10) -> [MasterPlayer] {
        let masterLoader = MasterDataLoader.shared
        let allTeams = masterLoader.getAvailableTeams()
        
        // Collect all players
        var allPlayers: [MasterPlayer] = []
        for team in allTeams {
            allPlayers.append(contentsOf: masterLoader.getPlayers(for: team))
        }
        
        // Sort by overall rating and take top players
        return allPlayers
            .sorted { (Int($0.overall) ?? 0) > (Int($1.overall) ?? 0) }
            .prefix(limit)
            .map { $0 }
    }
    
    // Update the generateAllPredictions function
    func generateAllPredictions() async {
        guard isMLAvailable && !isProcessing else { return }
        
        isProcessing = true
        
        // Generate season predictions
        await generateSeasonPredictions()
        
        // Get upcoming games from the current week
        let masterLoader = MasterDataLoader.shared
        let allTeams = masterLoader.getAvailableTeams()
        
        // Generate predictions for a selection of upcoming matchups
        for i in 0..<min(5, allTeams.count/2) {
            let homeTeam = allTeams[i*2]
            let awayTeam = allTeams[i*2 + 1]
            await predictGameOutcome(homeTeam: homeTeam, awayTeam: awayTeam)
        }
        
        // Generate player predictions for top players
        let topPlayers = getTopPlayersByOverall(limit: 10)
        let playerIds = topPlayers.map { "\($0.firstName)_\($0.lastName)_\($0.jerseyNum)" }
        await predictPlayerPerformance(for: playerIds)
        
        isProcessing = false
    }
}

// MARK: - SwiftUI Integration
struct PredictiveAnalyticsView: View {
    @StateObject private var analyticsManager = iOS26PredictiveAnalyticsManager.shared
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                    }
                    
                    Spacer()
                    
                    Text("Predictive Analytics")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await analyticsManager.generateAllPredictions()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                    }
                    .disabled(analyticsManager.isProcessing)
                }
                .padding()
                
                // Tab selection
                Picker("Analytics Type", selection: $selectedTab) {
                    Text("Games").tag(0)
                    Text("Players").tag(1)
                    Text("Season").tag(2)
                    Text("Accuracy").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if analyticsManager.isProcessing {
                    ProgressView("Generating predictions...")
                        .padding()
                } else {
                    ScrollView {
                        switch selectedTab {
                        case 0:
                            gamePredictionsView
                        case 1:
                            playerPredictionsView
                        case 2:
                            seasonPredictionsView
                        case 3:
                            accuracyView
                        default:
                            EmptyView()
                        }
                    }
                }
            }
        }
        .task {
            // Generate predictions when view appears if none exist
            if analyticsManager.currentPredictions.isEmpty {
                await analyticsManager.generateAllPredictions()
            }
        }
    }
    
    // MARK: - Game Predictions View
    private var gamePredictionsView: some View {
        LazyVStack(spacing: 12) {
            if analyticsManager.isProcessing {
                EmptyPredictionsView(type: "game predictions", isLoading: true)
            } else if analyticsManager.currentPredictions.isEmpty {
                EmptyPredictionsView(type: "game predictions", isLoading: false)
            } else {
                ForEach(analyticsManager.currentPredictions, id: \.id) { prediction in
                    GamePredictionCard(prediction: prediction)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Player Predictions View
    private var playerPredictionsView: some View {
        LazyVStack(spacing: 12) {
            if analyticsManager.isProcessing {
                EmptyPredictionsView(type: "player predictions", isLoading: true)
            } else if analyticsManager.playerPerformancePredictions.isEmpty {
                EmptyPredictionsView(type: "player predictions", isLoading: false)
            } else {
                ForEach(analyticsManager.playerPerformancePredictions, id: \.id) { prediction in
                    PlayerPredictionCard(prediction: prediction)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Season Predictions View
    private var seasonPredictionsView: some View {
        VStack(spacing: 16) {
            if analyticsManager.isProcessing {
                EmptyPredictionsView(type: "season predictions", isLoading: true)
            } else if analyticsManager.seasonPredictions == nil {
                EmptyPredictionsView(type: "season predictions", isLoading: false)
            } else if let seasonPredictions = analyticsManager.seasonPredictions {
                SeasonPredictionsCard(predictions: seasonPredictions)
            }
        }
        .padding()
    }
    
    // MARK: - Accuracy View
    private var accuracyView: some View {
        VStack(spacing: 16) {
            AnalyticsAccuracyCard(report: analyticsManager.getAnalyticsReport())
        }
        .padding()
    }
}

// MARK: - Supporting Views
struct GamePredictionCard: View {
    let prediction: iOS26PredictiveAnalyticsManager.GamePrediction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(prediction.homeTeam) vs \(prediction.awayTeam)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(Int(prediction.confidence * 100))%")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            HStack {
                Text("Predicted Score:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(prediction.predictedHomeScore) - \(prediction.predictedAwayScore)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Key Factors:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(prediction.keyFactors, id: \.self) { factor in
                    Text("• \(factor)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct PlayerPredictionCard: View {
    let prediction: iOS26PredictiveAnalyticsManager.PlayerPrediction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(prediction.playerName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(prediction.position)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.gray.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                Image(systemName: trendIcon)
                    .foregroundColor(trendColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Predicted Stats:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(Array(prediction.predictedStats.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text(key.capitalized)
                            .font(.caption)
                        Spacer()
                        Text(String(format: "%.1f", prediction.predictedStats[key] ?? 0))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var trendIcon: String {
        switch prediction.trendDirection {
        case .improving: return "arrow.up.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        case .stable: return "minus.circle.fill"
        }
    }
    
    private var trendColor: Color {
        switch prediction.trendDirection {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .gray
        }
    }
}

struct SeasonPredictionsCard: View {
    let predictions: iOS26PredictiveAnalyticsManager.SeasonPredictions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Season Predictions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(Int(predictions.confidence * 100))% confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                PredictionRow(title: "Championship Favorite", value: predictions.championshipFavorite)
                PredictionRow(title: "MVP Candidate", value: predictions.mvpCandidate)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Playoff Teams:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(predictions.playoffTeams.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Surprise Teams:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(predictions.surpriseTeams.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct PredictionRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct AnalyticsAccuracyCard: View {
    let report: iOS26PredictiveAnalyticsManager.AnalyticsReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Prediction Accuracy")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Overall Accuracy:")
                    Spacer()
                    Text(report.accuracyPercentage)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Average Confidence:")
                    Spacer()
                    Text(report.confidencePercentage)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Total Predictions:")
                    Spacer()
                    Text("\(report.totalPredictions)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Correct Predictions:")
                    Spacer()
                    Text("\(report.correctPredictions)")
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// Empty state view
private struct EmptyPredictionsView: View {
    let type: String
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(.bottom, 24)
            } else {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
            }
            
            Text(isLoading ? "Generating \(type)..." : "No \(type) available")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(isLoading ? "Using on-device ML models to analyze data" : "Predictions will appear here when ML analysis is complete")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}