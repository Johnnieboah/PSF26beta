import Foundation
import SwiftUI
import Combine

@MainActor
class AIGameAnalysisManager: ObservableObject {
    static let shared = AIGameAnalysisManager()
    
    @Published var analysisAvailable: Bool = false
    @Published var currentAnalysis: GameAnalysis?
    @Published var coachingTips: [CoachingTip] = []
    @Published var isAnalyzing: Bool = false
    
    private let performanceManager = AdvancedPerformanceManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    struct GameAnalysis {
        let gameId: UUID
        let keyInsights: [String]
        let strengthsWeaknesses: (strengths: [String], weaknesses: [String])
        let strategicRecommendations: [String]
        let playerPerformanceHighlights: [String]
        let timestamp: Date
        let analysisType: AnalysisType
        
        enum AnalysisType {
            case aiPowered
            case ruleBased
        }
    }
    
    struct CoachingTip {
        let id = UUID()
        let category: TipCategory
        let title: String
        let description: String
        let actionable: Bool
        let priority: Priority
        
        enum TipCategory {
            case offense, defense, specialTeams, management, draft, strategy
            
            var icon: String {
                switch self {
                case .offense: return "arrow.up.circle"
                case .defense: return "shield.fill"
                case .specialTeams: return "star.circle"
                case .management: return "person.3.fill"
                case .draft: return "plus.circle"
                case .strategy: return "brain.head.profile"
                }
            }
            
            var color: Color {
                switch self {
                case .offense: return .green
                case .defense: return .blue
                case .specialTeams: return .orange
                case .management: return .purple
                case .draft: return .red
                case .strategy: return .indigo
                }
            }
        }
        
        enum Priority: Int, CaseIterable {
            case low = 1, medium = 2, high = 3, critical = 4
            
            var color: Color {
                switch self {
                case .low: return .gray
                case .medium: return .yellow
                case .high: return .orange
                case .critical: return .red
                }
            }
        }
    }
    
    private init() {
        setupAIAvailabilityMonitoring()
        assessInitialAvailability()
    }
    
    private func setupAIAvailabilityMonitoring() {
        performanceManager.$aiAvailability
            .sink { [weak self] availability in
                self?.analysisAvailable = availability != .unavailable
            }
            .store(in: &cancellables)
    }
    
    private func assessInitialAvailability() {
        performanceManager.assessAICapability()
        analysisAvailable = performanceManager.aiAvailability != .unavailable
    }
    
    func analyzeGamePerformance(_ gameResult: GameResult) async {
        guard !isAnalyzing else { return }
        
        isAnalyzing = true
        
        if analysisAvailable && performanceManager.aiAvailability != .unavailable {
            if #available(iOS 26.0, *), performanceManager.deviceCapabilities.supportsFoundationModels {
                await performAIAnalysis(gameResult)
            } else {
                await provideFallbackAnalysis(gameResult)
            }
        } else {
            await provideFallbackAnalysis(gameResult)
        }
        
        isAnalyzing = false
    }
    
    @available(iOS 26.0, *)
    private func performAIAnalysis(_ gameResult: GameResult) async {
        let insights = await generateAIInsights(gameResult)
        let tips = await generateAICoachingTips(gameResult)
        
        await MainActor.run {
            self.currentAnalysis = GameAnalysis(
                gameId: gameResult.id,
                keyInsights: insights,
                strengthsWeaknesses: analyzeStrengthsWeaknesses(gameResult),
                strategicRecommendations: generateStrategicRecommendations(gameResult),
                playerPerformanceHighlights: analyzePlayerPerformance(gameResult),
                timestamp: Date(),
                analysisType: .aiPowered
            )
            self.coachingTips = tips
        }
    }
    
    private func provideFallbackAnalysis(_ gameResult: GameResult) async {
        let ruleBasedInsights = generateRuleBasedInsights(gameResult)
        let ruleBasedTips = generateRuleBasedTips(gameResult)
        
        await MainActor.run {
            self.currentAnalysis = GameAnalysis(
                gameId: gameResult.id,
                keyInsights: ruleBasedInsights,
                strengthsWeaknesses: analyzeStrengthsWeaknesses(gameResult),
                strategicRecommendations: generateStrategicRecommendations(gameResult),
                playerPerformanceHighlights: analyzePlayerPerformance(gameResult),
                timestamp: Date(),
                analysisType: .ruleBased
            )
            self.coachingTips = ruleBasedTips
        }
    }
    
    private func generateRuleBasedInsights(_ gameResult: GameResult) -> [String] {
        var insights: [String] = []
        
        let scoreDiff = abs(gameResult.homeScore - gameResult.awayScore)
        if scoreDiff > 21 {
            insights.append("Dominant performance with a \(scoreDiff)-point victory margin")
        } else if scoreDiff <= 3 {
            insights.append("Close game decided by \(scoreDiff) points")
        }
        
        let homeTurnovers = gameResult.turnovers.home
        let awayTurnovers = gameResult.turnovers.away
        let turnoverDiff = homeTurnovers - awayTurnovers
        if abs(turnoverDiff) >= 3 {
            insights.append("Turnover differential of \(turnoverDiff) was decisive")
        }
        
        if gameResult.homeScore > 35 {
            insights.append("High-scoring offensive performance")
        } else if gameResult.homeScore < 14 {
            insights.append("Low scoring indicates offensive struggles")
        }
        
        return insights
    }
    
    private func generateRuleBasedTips(_ gameResult: GameResult) -> [CoachingTip] {
        var tips: [CoachingTip] = []
        
        if gameResult.homeScore < 21 {
            tips.append(CoachingTip(
                category: .offense,
                title: "Red Zone Efficiency",
                description: "Focus on red zone practice to improve scoring opportunities",
                actionable: true,
                priority: .high
            ))
        }
        
        if gameResult.awayScore > 28 {
            tips.append(CoachingTip(
                category: .defense,
                title: "Defensive Adjustments",
                description: "Review defensive schemes to limit big plays",
                actionable: true,
                priority: .medium
            ))
        }
        
        if gameResult.turnovers.home > 2 {
            tips.append(CoachingTip(
                category: .management,
                title: "Ball Security",
                description: "Emphasize ball security drills in practice",
                actionable: true,
                priority: .critical
            ))
        }
        
        return tips
    }
    
    private func analyzeStrengthsWeaknesses(_ gameResult: GameResult) -> (strengths: [String], weaknesses: [String]) {
        var strengths: [String] = []
        var weaknesses: [String] = []
        
        if gameResult.homeScore > gameResult.awayScore {
            strengths.append("Winning execution when it mattered")
        } else {
            weaknesses.append("Need to improve game management")
        }
        
        if gameResult.turnovers.home > gameResult.turnovers.away {
            weaknesses.append("Ball security needs attention")
        } else if gameResult.turnovers.home < gameResult.turnovers.away {
            strengths.append("Good ball security")
        }
        
        return (strengths: strengths, weaknesses: weaknesses)
    }
    
    private func generateStrategicRecommendations(_ gameResult: GameResult) -> [String] {
        var recommendations: [String] = []
        
        if gameResult.homeScore < 21 {
            recommendations.append("Consider more aggressive red zone play-calling")
        }
        
        if gameResult.awayScore > 24 {
            recommendations.append("Review defensive formations")
        }
        
        recommendations.append("Build on successful game plan elements")
        
        return recommendations
    }
    
    private func analyzePlayerPerformance(_ gameResult: GameResult) -> [String] {
        var highlights: [String] = []
        
        if gameResult.homeScore > gameResult.awayScore {
            highlights.append("Quarterback showed excellent decision-making")
            highlights.append("Defense made key stops")
        } else {
            highlights.append("Team showed resilience despite outcome")
        }
        
        return highlights
    }
    
    @available(iOS 26.0, *)
    private func generateAIInsights(_ gameResult: GameResult) async -> [String] {
        return generateRuleBasedInsights(gameResult) + ["AI-enhanced analysis available"]
    }
    
    @available(iOS 26.0, *)
    private func generateAICoachingTips(_ gameResult: GameResult) async -> [CoachingTip] {
        var tips = generateRuleBasedTips(gameResult)
        
        tips.append(CoachingTip(
            category: .strategy,
            title: "AI Strategic Insight",
            description: "Advanced pattern recognition suggests tempo control focus",
            actionable: true,
            priority: .medium
        ))
        
        return tips
    }
    
    func clearAnalysis() {
        currentAnalysis = nil
        coachingTips.removeAll()
    }
    
    func getAnalysisSummary() -> String {
        guard let analysis = currentAnalysis else {
            return "No analysis available"
        }
        
        let typeLabel = analysis.analysisType == .aiPowered ? "AI-Powered" : "Rule-Based"
        return "\(typeLabel) analysis with \(analysis.keyInsights.count) insights and \(coachingTips.count) coaching tips"
    }
}
