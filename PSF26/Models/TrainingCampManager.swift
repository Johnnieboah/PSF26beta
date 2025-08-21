import Foundation

// MARK: - Training Camp Manager

class TrainingCampManager {
    
    // MARK: - Roster Cutting Validation
    
    /// Validates that all teams can make the required cuts from 60 to 53 players
    /// while maintaining salary cap compliance and position requirements
    static func validateAllTeamsCanMakeCuts(teams: [LeagueTeam]) -> TrainingCampValidationResult {
        print("🏕️ Validating training camp roster cuts for \(teams.count) teams...")
        
        var validationResults: [String: TeamCuttingValidation] = [:]
        var totalIssues = 0
        
        for team in teams {
            // Safety check for empty or invalid team data
            guard !team.logoName.isEmpty, !team.name.isEmpty else {
                print("⚠️ Skipping team with invalid data")
                continue
            }
            
            let validation = validateTeamCanMakeCuts(team: team)
            validationResults[team.logoName] = validation
            
            if !validation.canMakeCuts {
                totalIssues += 1
                print("❌ \(team.name) cannot make required cuts: \(validation.issues.joined(separator: ", "))")
            } else {
                print("✅ \(team.name) can make cuts successfully")
            }
        }
        
        let overallResult = TrainingCampValidationResult(
            allTeamsValid: totalIssues == 0,
            teamValidations: validationResults,
            totalIssues: totalIssues
        )
        
        print("🏕️ Training camp validation complete: \(totalIssues > 0 ? "❌ \(totalIssues) teams need adjustment" : "✅ All teams ready")")
        return overallResult
    }
    
    /// Validates that a specific team can make the required cuts from 60 to 53 players
    static func validateTeamCanMakeCuts(team: LeagueTeam) -> TeamCuttingValidation {
        // Safety check for invalid team data
        guard !team.logoName.isEmpty, !team.name.isEmpty else {
            return TeamCuttingValidation(
                teamName: "Unknown Team",
                canMakeCuts: false,
                issues: ["Invalid team data"],
                salaryValidation: SalaryCapValidation(
                    currentSpending: 0,
                    projectedSpendingAfterCuts: 0,
                    potentialSavings: 0,
                    wouldBeUnderCap: false,
                    hasFlexibility: false,
                    cuttingCandidates: []
                ),
                positionValidation: PositionValidation(
                    canMaintainMinimums: false,
                    positionIssues: ["Invalid team data"],
                    currentComposition: [:]
                ),
                recommendedCuts: [],
                projectedSalarySavings: 0
            )
        }
        
        var issues: [String] = []
        var canMakeCuts = true
        
        // 1. Check current roster size
        if team.players.count != 60 {
            issues.append("Team has \(team.players.count) players instead of 60")
            canMakeCuts = false
        }
        
        // 2. Check salary cap flexibility
        let salaryValidation = validateSalaryCapFlexibility(team: team)
        if !salaryValidation.hasFlexibility {
            issues.append("Insufficient salary cap flexibility")
            canMakeCuts = false
        }
        
        // 3. Check position requirements
        let positionValidation = validatePositionRequirements(team: team)
        if !positionValidation.canMaintainMinimums {
            issues.append("Cannot maintain minimum position requirements")
            canMakeCuts = false
        }
        
        // 4. Generate cutting recommendations
        let cuttingPlan = generateCuttingPlan(team: team)
        
        return TeamCuttingValidation(
            teamName: team.name,
            canMakeCuts: canMakeCuts,
            issues: issues,
            salaryValidation: salaryValidation,
            positionValidation: positionValidation,
            recommendedCuts: cuttingPlan.recommendedCuts,
            projectedSalarySavings: cuttingPlan.totalSavings
        )
    }
    
    // MARK: - Salary Cap Validation
    
    private static func validateSalaryCapFlexibility(team: LeagueTeam) -> SalaryCapValidation {
        let currentSpending = team.totalSalarySpending
        let _ = team.targetCapSpending
        let salaryCap = NFLCapData.salaryCap
        
        // Sort players by salary (lowest first - these are cutting candidates)
        let sortedBySalary = team.players.sorted { $0.estimatedSalary < $1.estimatedSalary }
        
        // Calculate potential savings from cutting 7 lowest-paid players
        let cuttingCandidates = Array(sortedBySalary.prefix(10)) // Look at bottom 10 for flexibility
        let potentialSavings = cuttingCandidates.prefix(7).reduce(0) { $0 + $1.estimatedSalary }
        let safePotentialSavings = max(0, min(potentialSavings, Int.max / 2)) // Prevent overflow and negative values
        
        // Check if team would still be over cap after cuts
        let projectedSpendingAfterCuts = max(0, currentSpending - safePotentialSavings)
        let wouldBeUnderCap = projectedSpendingAfterCuts <= salaryCap
        
        // Ensure there's variation in who gets cut (not always the same players)
        let hasVariation = cuttingCandidates.count >= 10 && 
                          max(0, cuttingCandidates[6].estimatedSalary - cuttingCandidates[0].estimatedSalary) < 500_000
        
        return SalaryCapValidation(
            currentSpending: currentSpending,
            projectedSpendingAfterCuts: projectedSpendingAfterCuts,
            potentialSavings: safePotentialSavings,
            wouldBeUnderCap: wouldBeUnderCap,
            hasFlexibility: wouldBeUnderCap && hasVariation,
            cuttingCandidates: cuttingCandidates
        )
    }

    // MARK: - Cap Compliance Planning
    /// Determines whether a team can reach cap compliance by cutting up to (players.count - targetCount) players,
    /// preferring to cut fewer, lower-impact players (low overall, non-critical positions, older, high salary).
    static func capComplianceFeasible(team: LeagueTeam, targetCount: Int = 65, capSlack: Int = 0) -> (feasible: Bool, plan: [PlayerData], savings: Int) {
        // Allow team spending up to cap + capSlack (e.g., -$5M space)
        let permissibleSpend = NFLCapData.salaryCap + capSlack
        let requiredSavings = max(0, team.totalSalarySpending - permissibleSpend)
        if requiredSavings == 0 { return (true, [], 0) }

        let allowedCuts = max(0, team.players.count - targetCount)
        guard allowedCuts > 0 else { return (false, [], 0) }

        // Position minimums
        let minimums: [String: Int] = ["QB": 2, "K": 1, "P": 1, "LT": 1, "C": 1]
        var composition = team.getRosterComposition()

        // Score players for cutting: larger is more likely to cut (better savings/impact ratio)
        func isCritical(_ pos: String) -> Bool { return ["QB","K","P","LT","C"].contains(pos) }
        func score(_ p: PlayerData) -> Double {
            let salary = max(1, p.estimatedSalary)
            let quality = max(1.0, Double(p.overall))
            let ageBonus = Double(max(0, p.age - 28)) * 1.0 // prefer cutting older
            let posPenalty = isCritical(p.position) ? 80.0 : 0.0
            // Higher score when salary high and quality low; subtract penalties
            return (Double(salary) / 1_000_000.0) / (quality / 10.0 + 1.0) + ageBonus - posPenalty
        }

        let sorted = team.players.sorted { score($0) > score($1) }
        var plan: [PlayerData] = []
        var savings = 0

        for p in sorted {
            if plan.count >= allowedCuts { break }
            if savings >= requiredSavings { break }

            // Respect minimums per position and keep at least 1 everywhere
            let currentAtPos = composition[p.position] ?? 0
            let minReq = max(1, minimums[p.position] ?? 0)
            if currentAtPos <= minReq { continue }

            // Choose this player
            plan.append(p)
            savings += p.estimatedSalary
            composition[p.position] = max(0, currentAtPos - 1)
        }

        return (savings >= requiredSavings, plan, savings)
    }

    /// Applies an automatic cap-compliance cut plan to the given team.
    /// Tries to achieve cap >= 0 while also reaching the final roster size.
    /// Returns the list of players cut and whether cap compliance was achieved.
    static func enforceCapCompliance(team: inout LeagueTeam, finalCount: Int = 53, capSlack: Int = 0) -> (didComply: Bool, cuts: [PlayerData], savings: Int) {
        // If already compliant and at or below finalCount, no work
        if team.totalSalarySpending <= NFLCapData.salaryCap + capSlack && team.players.count <= finalCount {
            return (true, [], 0)
        }

        // First, attempt the planned feasibility method
        let planResult = capComplianceFeasible(team: team, targetCount: finalCount, capSlack: capSlack)

        var workingPlayers = team.players
        var cuts: [PlayerData] = []
        var savings = 0

        if planResult.feasible {
            // Apply recommended plan
            for p in planResult.plan {
                if let idx = workingPlayers.firstIndex(where: { $0.id == p.id }) {
                    cuts.append(workingPlayers.remove(at: idx))
                    savings += p.estimatedSalary
                }
            }
        } else {
            // Greedy fallback: cut by score until either under cap or at finalCount
            let permissibleSpend = NFLCapData.salaryCap + capSlack
            let requiredSavings = max(0, team.totalSalarySpending - permissibleSpend)
            let minimums: [String: Int] = ["QB":2, "K":1, "P":1, "LT":1, "C":1]
            func isCritical(_ pos: String) -> Bool { ["QB","K","P","LT","C"].contains(pos) }
            func score(_ p: PlayerData) -> Double {
                let salary = max(1, p.estimatedSalary)
                let quality = max(1.0, Double(p.overall))
                let ageBonus = Double(max(0, p.age - 28))
                let posPenalty = isCritical(p.position) ? 80.0 : 0.0
                return (Double(salary) / 1_000_000.0) / (quality / 10.0 + 1.0) + ageBonus - posPenalty
            }
            var composition = team.getRosterComposition()
            let sortedByScore = workingPlayers.sorted { score($0) > score($1) }
            for p in sortedByScore {
                if workingPlayers.count <= finalCount && (team.totalSalarySpending - savings) <= permissibleSpend { break }
                if workingPlayers.count <= finalCount && requiredSavings == 0 { break }
                let currentAtPos = composition[p.position] ?? 0
                let minReq = max(1, minimums[p.position] ?? 0)
                if currentAtPos <= minReq { continue }
                if let idx = workingPlayers.firstIndex(where: { $0.id == p.id }) {
                    cuts.append(workingPlayers.remove(at: idx))
                    composition[p.position] = max(0, currentAtPos - 1)
                    savings += p.estimatedSalary
                    if (team.totalSalarySpending - savings) <= NFLCapData.salaryCap && workingPlayers.count <= finalCount {
                        break
                    }
                }
            }
        }

        // Apply changes
        team.players = workingPlayers
        let didComply = (team.totalSalarySpending <= NFLCapData.salaryCap + capSlack)
        return (didComply, cuts, savings)
    }
    
    // MARK: - Position Requirements Validation
    
    private static func validatePositionRequirements(team: LeagueTeam) -> PositionValidation {
        let composition = team.getRosterComposition()
        var canMaintainMinimums = true
        var positionIssues: [String] = []
        
        // NFL minimum requirements for 53-man roster
        let minimumRequirements: [String: Int] = [
            "QB": 2,    // Need at least 2 QBs
            "K": 1,     // Need at least 1 kicker
            "P": 1,     // Need at least 1 punter
            "LT": 1,    // Need at least 1 left tackle
            "C": 1      // Need at least 1 center
        ]
        
        for (position, minRequired) in minimumRequirements {
            let currentCount = composition[position] ?? 0
            if currentCount < minRequired {
                canMaintainMinimums = false
                positionIssues.append("Need \(minRequired) \(position) but only have \(currentCount)")
            } else if currentCount == minRequired {
                // At minimum - cannot cut any players at this position
                positionIssues.append("At minimum for \(position) - cannot cut")
            }
        }
        
        return PositionValidation(
            canMaintainMinimums: canMaintainMinimums,
            positionIssues: positionIssues,
            currentComposition: composition
        )
    }
    
    // MARK: - Cutting Plan Generation
    
    private static func generateCuttingPlan(team: LeagueTeam) -> CuttingPlan {
        // Safety check for valid team data
        guard !team.logoName.isEmpty else {
            return CuttingPlan(recommendedCuts: [], totalSavings: 0)
        }
        
        // Create a varied cutting plan that doesn't always cut the same players
        let players = team.players
        
        // Sort by a combination of factors to create variation
        let seed = abs(team.logoName.hashValue) // Use team name as seed for consistency per team
        var random = SeededRandom(seed: seed)
        
        let sortedPlayers = players.sorted { player1, player2 in
            // Primary: Overall rating (lower first)
            if player1.overall != player2.overall {
                return player1.overall < player2.overall
            }
            
            // Secondary: Age (older first for same rating)
            if player1.age != player2.age {
                return player1.age > player2.age
            }
            
            // Tertiary: Salary (higher first to create cap space)
            if player1.estimatedSalary != player2.estimatedSalary {
                return player1.estimatedSalary > player2.estimatedSalary
            }
            
            // Final: Random factor for variation
            return random.nextBool()
        }
        
        // Identify protected positions (cannot cut below minimums)
        let composition = team.getRosterComposition()
        let protectedPositions: Set<String> = ["QB", "K", "P"] // Always protect these
        
        var cuttingCandidates: [PlayerData] = []
        var totalSavings = 0
        
        // Target: number of players to cut to reach training camp target of 65
        let targetCount = max(0, team.players.count - 65)
        for player in sortedPlayers {
            if cuttingCandidates.count >= targetCount { break }
            
            // Don't cut if it would violate minimum requirements
            let currentAtPosition = composition[player.position] ?? 0
            let alreadyCutAtPosition = cuttingCandidates.filter { $0.position == player.position }.count
            let remainingAtPosition = max(0, currentAtPosition - alreadyCutAtPosition)
            
            let minimumRequired = getMinimumRequired(position: player.position)
            // Guardrail: never recommend if they'd be the last remaining at that position (for any position)
            // Also respect explicit minimum requirements for special positions (QB/K/P/LT/C)
            let guardMinimum = max(1, minimumRequired)
            if remainingAtPosition <= guardMinimum { continue }
            if remainingAtPosition > minimumRequired || !protectedPositions.contains(player.position) {
                cuttingCandidates.append(player)
                totalSavings += player.estimatedSalary
                totalSavings = max(0, min(totalSavings, Int.max / 2)) // Prevent overflow and negative values
            }
        }
        
        return CuttingPlan(
            recommendedCuts: cuttingCandidates,
            totalSavings: totalSavings
        )
    }
    
    private static func getMinimumRequired(position: String) -> Int {
        switch position {
        case "QB": return 2
        case "K", "P": return 1
        case "LT", "C": return 1
        default: return 0
        }
    }
    
    // MARK: - Team Adjustment
    
    /// Adjusts team rosters to ensure they can make proper cuts
    static func adjustTeamsForProperCutting(teams: inout [LeagueTeam]) {
        print("🔧 Adjusting teams to ensure proper cutting capabilities...")
        
        for i in 0..<teams.count {
            let validation = validateTeamCanMakeCuts(team: teams[i])
            
            if !validation.canMakeCuts {
                print("🔧 Adjusting \(teams[i].name)...")
                adjustTeamRoster(team: &teams[i], validation: validation)
            }
        }
        
        print("🔧 Team adjustments complete")
    }
    
    private static func adjustTeamRoster(team: inout LeagueTeam, validation: TeamCuttingValidation) {
        // Respect imported salaries and rosters. Avoid auto-adjusting salaries/positions.
        // Intentionally left blank to prevent noisy logs and unintended changes.
    }
    
    private static func adjustTeamSalaries(team: inout LeagueTeam) {
        // Disabled: keep imported salaries intact
    }
    
    private static func adjustPositionDistribution(team: inout LeagueTeam) {
        // This would involve swapping players between positions if needed
        // For now, we'll log what needs to be adjusted
        print("   🔄 Would adjust position distribution for \(team.name)")
    }
}

// MARK: - Supporting Structures

struct TrainingCampValidationResult {
    let allTeamsValid: Bool
    let teamValidations: [String: TeamCuttingValidation]
    let totalIssues: Int
}

struct TeamCuttingValidation {
    let teamName: String
    let canMakeCuts: Bool
    let issues: [String]
    let salaryValidation: SalaryCapValidation
    let positionValidation: PositionValidation
    let recommendedCuts: [PlayerData]
    let projectedSalarySavings: Int
}

struct SalaryCapValidation {
    let currentSpending: Int
    let projectedSpendingAfterCuts: Int
    let potentialSavings: Int
    let wouldBeUnderCap: Bool
    let hasFlexibility: Bool
    let cuttingCandidates: [PlayerData]
}

struct PositionValidation {
    let canMaintainMinimums: Bool
    let positionIssues: [String]
    let currentComposition: [String: Int]
}

struct CuttingPlan {
    let recommendedCuts: [PlayerData]
    let totalSavings: Int
}

// MARK: - Seeded Random for Consistent Variation

struct SeededRandom {
    private var seed: UInt64
    
    init(seed: Int) {
        self.seed = UInt64(seed)
    }
    
    mutating func nextBool() -> Bool {
        seed = seed &* 1103515245 &+ 12345
        return (seed / 65536) % 2 == 0
    }
    
    mutating func nextInt(in range: Range<Int>) -> Int {
        guard range.count > 0 else { return range.lowerBound }
        seed = seed &* 1103515245 &+ 12345
        let randomValue = Int(seed % UInt64(range.count))
        return range.lowerBound + randomValue
    }
} 