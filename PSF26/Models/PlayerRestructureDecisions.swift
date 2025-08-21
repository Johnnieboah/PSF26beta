import Foundation
import Combine

// MARK: - Player Restructure Decision Tracking
struct PlayerRestructureDecision: Codable {
    let playerId: String // Using player name as ID for now
    let decision: RestructureDecision
    let decisionDate: Date
    let contractYearsRemaining: Int
    let contractValue: Int
    
    enum RestructureDecision: Codable {
        case willing
        case reluctant
        case refused
    }
    
    // Check if decision is still valid (expires mid-season)
    var isValid: Bool {
        let calendar = Calendar.current
        let monthsSinceDecision = calendar.dateComponents([.month], from: decisionDate, to: Date()).month ?? 0
        return monthsSinceDecision < 6 // Valid for 6 months (half season)
    }
}

class PlayerRestructureManager: ObservableObject {
    @Published private var decisions: [String: PlayerRestructureDecision] = [:]
    
    // Check if player wants to restructure
    func checkRestructureWillingness(player: PlayerData, contract: PlayerContract) -> PlayerRestructureDecision.RestructureDecision {
        let playerId = "\(player.firstName) \(player.lastName)"
        
        // Check if we have a recent decision
        if let existingDecision = decisions[playerId], existingDecision.isValid {
            return existingDecision.decision
        }
        
        // Calculate willingness based on contract factors
        let decision = calculateRestructureWillingness(player: player, contract: contract)
        
        // Save the decision
        let restructureDecision = PlayerRestructureDecision(
            playerId: playerId,
            decision: decision,
            decisionDate: Date(),
            contractYearsRemaining: contract.yearsRemaining,
            contractValue: contract.totalValue
        )
        
        decisions[playerId] = restructureDecision
        return decision
    }
    
    // Check if player wants to re-sign (different logic than restructure)
    func checkResignWillingness(player: PlayerData, estimatedSalary: Int) -> PlayerRestructureDecision.RestructureDecision {
        let playerId = "\(player.firstName) \(player.lastName)_resign"
        
        // Check if we have a recent decision for re-signing
        if let existingDecision = decisions[playerId], existingDecision.isValid {
            return existingDecision.decision
        }
        
        // Calculate willingness based on player factors (different from restructure)
        let decision = calculateResignWillingness(player: player, estimatedSalary: estimatedSalary)
        
        // Save the decision
        let resignDecision = PlayerRestructureDecision(
            playerId: playerId,
            decision: decision,
            decisionDate: Date(),
            contractYearsRemaining: 0, // No current contract
            contractValue: estimatedSalary
        )
        
        decisions[playerId] = resignDecision
        return decision
    }
    
    private func calculateRestructureWillingness(player: PlayerData, contract: PlayerContract) -> PlayerRestructureDecision.RestructureDecision {
        // Base reluctance factors
        var reluctanceScore = 0.0
        
        // Years remaining factor (more years = more reluctant)
        switch contract.yearsRemaining {
        case 4...: reluctanceScore += 0.6
        case 3: reluctanceScore += 0.4
        case 2: reluctanceScore += 0.2
        default: reluctanceScore += 0.0
        }
        
        // Contract value factor (higher value = more reluctant)
        let averageSalary = contract.totalValue / max(contract.yearsRemaining, 1)
        switch averageSalary {
        case 20_000_000...: reluctanceScore += 0.5 // Elite players
        case 10_000_000...19_999_999: reluctanceScore += 0.3 // Above average
        case 5_000_000...9_999_999: reluctanceScore += 0.1 // Average
        default: reluctanceScore += 0.0 // Below average
        }
        
        // Player overall factor (better players are more confident in their deals)
        switch player.overall {
        case 90...: reluctanceScore += 0.3
        case 80...89: reluctanceScore += 0.2
        case 70...79: reluctanceScore += 0.1
        default: reluctanceScore += 0.0
        }
        
        // Age factor (older players might be more willing to restructure for team success)
        if player.age >= 32 {
            reluctanceScore -= 0.2
        } else if player.age <= 25 {
            reluctanceScore += 0.1
        }
        
        // Guaranteed money factor (more guaranteed = more reluctant)
        if contract.guaranteedPercentage > 0.6 {
            reluctanceScore += 0.2
        }
        
        // Random factor for variability
        reluctanceScore += Double.random(in: -0.1...0.1)
        
        // Convert to decision
        switch reluctanceScore {
        case 0.7...: return .refused
        case 0.4...0.69: return .reluctant
        default: return .willing
        }
    }
    
    private func calculateResignWillingness(player: PlayerData, estimatedSalary: Int) -> PlayerRestructureDecision.RestructureDecision {
        // Re-signing has different logic than restructuring
        var reluctanceScore = 0.0
        
        // Player overall factor (better players have more options)
        switch player.overall {
        case 90...: reluctanceScore += 0.4 // Elite players are picky
        case 80...89: reluctanceScore += 0.2 // Good players have some leverage
        case 70...79: reluctanceScore += 0.1 // Average players
        default: reluctanceScore += 0.0 // Below average players need jobs
        }
        
        // Age factor (affects willingness differently for re-signing)
        switch player.age {
        case 32...: reluctanceScore -= 0.2 // Older players want security
        case 28...31: reluctanceScore += 0.1 // Prime players want max value
        case 25...27: reluctanceScore += 0.2 // Young stars want to maximize earnings
        default: reluctanceScore += 0.0 // Young players happy for opportunity
        }
        
        // Position factor (some positions have more leverage)
        switch player.position {
        case "QB": reluctanceScore += 0.3 // QBs have lots of leverage
        case "WR", "RB", "TE": reluctanceScore += 0.1 // Skill positions
        case "OL", "DL": reluctanceScore += 0.0 // Big guys need jobs
        default: reluctanceScore += 0.05 // Other positions
        }
        
        // Salary expectation factor (if offer seems low)
        let positionAverage = getPositionAverageSalary(position: player.position)
        let salaryRatio = Double(estimatedSalary) / Double(positionAverage)
        if salaryRatio < 0.8 {
            reluctanceScore += 0.3 // Low offer increases reluctance
        } else if salaryRatio > 1.2 {
            reluctanceScore -= 0.2 // Good offer decreases reluctance
        }
        
        // Random factor for variability
        reluctanceScore += Double.random(in: -0.15...0.15)
        
        // Convert to decision (slightly different thresholds than restructure)
        switch reluctanceScore {
        case 0.6...: return .refused
        case 0.3...0.59: return .reluctant
        default: return .willing
        }
    }
    
    private func getPositionAverageSalary(position: String) -> Int {
        // Simplified position averages
        switch position {
        case "QB": return 25_000_000
        case "WR": return 15_000_000
        case "RB": return 8_000_000
        case "TE": return 10_000_000
        case "OL": return 12_000_000
        case "DL": return 14_000_000
        case "LB": return 11_000_000
        case "DB": return 13_000_000
        default: return 10_000_000
        }
    }
    
    // Get player response for restructure reluctance
    func getRestructureResponse(player: PlayerData, decision: PlayerRestructureDecision.RestructureDecision) -> String {
        let responses: [String]
        
        switch decision {
        case .refused:
            responses = [
                "I'm happy with my contract right now.",
                "I don't see any reason to change my deal.",
                "My agent advised me to stick with what I have.",
                "I'm comfortable with my current contract terms.",
                "I worked hard to get this deal - I'm keeping it."
            ]
        case .reluctant:
            responses = [
                "I'd prefer to keep my current deal, but I'm open to listening.",
                "I'm pretty happy with what I have, but let's see what you're thinking.",
                "My contract is fair, but I'll hear you out.",
                "I'm not really looking to change anything, but go ahead."
            ]
        case .willing:
            responses = [
                "I'm always open to discussing ways to help the team.",
                "Let's see what we can work out.",
                "I'm willing to talk about restructuring.",
                "If it helps the team, I'm interested."
            ]
        }
        
        return responses.randomElement() ?? responses[0]
    }
    
    // Get player response for re-sign reluctance
    func getResignResponse(player: PlayerData, decision: PlayerRestructureDecision.RestructureDecision) -> String {
        let responses: [String]
        
        switch decision {
        case .refused:
            responses = [
                "I'm going to explore my options in free agency.",
                "I think it's time for a fresh start somewhere else.",
                "I want to see what other teams are offering.",
                "My agent thinks I can do better on the open market.",
                "I've decided to test free agency this year.",
                "I'm not interested in re-signing right now."
            ]
        case .reluctant:
            responses = [
                "I'm listening, but I'm also considering other opportunities.",
                "I love it here, but I need to see a competitive offer.",
                "I'm open to staying, but the deal has to be right.",
                "Let's see what you're offering, but I have other options too."
            ]
        case .willing:
            responses = [
                "I'd love to stay here if we can work something out.",
                "This organization means a lot to me - let's make a deal.",
                "I'm definitely interested in re-signing.",
                "I want to be here long-term if possible."
            ]
        }
        
        return responses.randomElement() ?? responses[0]
    }
    
    // Clear old decisions (can be called periodically)
    func clearExpiredDecisions() {
        decisions = decisions.filter { $0.value.isValid }
    }
} 