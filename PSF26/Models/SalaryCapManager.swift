import Foundation

// MARK: - Salary Cap Manager

class SalaryCapManager {
    // MARK: - Cap Enforcement
    /// Blocks a transaction if it would put the team over the cap; uses Top-51 in offseason.
    static func canAfford(team: LeagueTeam, additionalCapHit: Int, isOffseason: Bool) -> Bool {
        return team.canAffordCapHit(addedCharge: additionalCapHit, isOffseason: isOffseason)
    }
    
    // MARK: - Main Distribution Function
    
    static func assignTeamSalaries(team: LeagueTeam) {
        let targetSpending = NFLCapData.getCapSpending(for: team.logoName)
        
        let rookies = team.players.filter { isRookiePlayer($0) }
        let veterans = team.players.filter { !isRookiePlayer($0) }
        
        print("💰 Assigning salaries for \(team.name): Target $\(targetSpending)")
        print("   Rookies: \(rookies.count), Veterans: \(veterans.count)")
        
        // Step 1: Assign rookie salaries first (non-negotiable)
        var totalRookieSalary = 0
        for rookie in rookies {
            if let pick = estimateDraftPick(for: rookie) {
                let rookieSalary = RookieWageScale.getCurrentYearSalary(pick: pick, contractYear: 1)
                // Since we can't modify PlayerData directly, we'll use estimated salary
                totalRookieSalary += rookieSalary
                print("   Rookie \(rookie.fullName) (est. pick \(pick)): $\(rookieSalary)")
            }
        }
        
        // Step 2: Distribute remaining cap among veterans
        let veteranCapSpace = targetSpending - totalRookieSalary
        distributeVeteranSalaries(veterans: veterans, availableCap: veteranCapSpace)
        
        print("💰 \(team.name) salary assignment complete:")
        print("   Rookie total: $\(totalRookieSalary)")
        print("   Veteran budget: $\(veteranCapSpace)")
        print("   Total target: $\(targetSpending)")
    }
    
    // MARK: - Veteran Salary Distribution
    
    private static func distributeVeteranSalaries(veterans: [PlayerData], availableCap: Int) {
        guard !veterans.isEmpty else { return }
        
        // Calculate salary weights for each veteran
        var playerWeights: [(player: PlayerData, weight: Double)] = []
        var totalWeight: Double = 0
        
        for player in veterans {
            let weight = calculateSalaryWeight(player: player)
            playerWeights.append((player: player, weight: weight))
            totalWeight += weight
        }
        
        // Distribute cap proportionally
        for (player, weight) in playerWeights {
            let proportionalSalary = Int(Double(availableCap) * (weight / totalWeight))
            let finalSalary = max(proportionalSalary, getMinimumSalary(player: player))
            
            // Store salary in a way that can be accessed (this is a simplified approach)
            print("   \(player.fullName) (\(player.position)): $\(finalSalary)")
        }
    }
    
    // MARK: - Salary Weight Calculation
    
    private static func calculateSalaryWeight(player: PlayerData) -> Double {
        let baseWeight = Double(player.overall) / 100.0 // 0.0 to 1.0
        let ageMultiplier = getAgeMultiplier(age: player.age)
        let positionMultiplier = getPositionMultiplier(position: player.position)
        
        return baseWeight * ageMultiplier * positionMultiplier
    }
    
    private static func getAgeMultiplier(age: Int) -> Double {
        switch age {
        case 22...24: return 1.0  // Reduced from 1.1 - young players
        case 25...28: return 1.1  // Reduced from 1.3 - prime years
        case 29...31: return 1.0  // Still good
        case 32...35: return 0.8  // Reduced from 0.7 - declining
        default: return 0.6  // Reduced from 0.5 - very young or old
        }
    }
    
    static func getPositionMultiplier(position: String) -> Double {
        switch position {
        case "QB": return 1.8  // Reduced from 2.5
        case "LT", "RT": return 1.4  // Reduced from 1.8
        case "DE", "EDGE": return 1.3  // Reduced from 1.6
        case "WR", "CB": return 1.2  // Reduced from 1.4
        case "RB", "TE", "SS", "FS": return 1.1  // Reduced from 1.2
        case "C", "LG", "RG", "DT", "MLB": return 1.0  // Reduced from 1.1
        case "K", "P": return 0.3
        default: return 1.0
        }
    }
    
    private static func getMinimumSalary(player: PlayerData) -> Int {
        // NFL minimum salaries by years of service
        let yearsInLeague = max(0, player.age - 22) // Rough estimate
        switch yearsInLeague {
        case 0: return 750_000 // Rookie minimum
        case 1: return 825_000
        case 2: return 900_000
        case 3: return 985_000
        default: return 1_210_000 // Veteran minimum
        }
    }
    
    // MARK: - Contract Creation Functions
    
    static func createRookieContract(pick: Int) -> PlayerContract {
        guard let rookieData = RookieWageScale.getContract(for: pick) else {
                    return PlayerContract(
            isRookieContract: true,
            totalValue: 0,
            currentYearSalary: 750_000, // Minimum
            yearlyValues: [750_000],
            yearsRemaining: 1,
            draftPick: pick,
            hasFifthYearOption: false,
            totalGuaranteed: 750_000,
            guaranteedAtSigning: 750_000,
            injuryGuaranteed: 0,
            skillGuaranteed: 0,
            signingBonus: 450_000, // 60% for rookies
            hasOffsetLanguage: false
        )
        }
        
        // NFL-like rookie guarantees by round (simplified)
        let fullG = pick <= 32
        let guaranteePct: Double
        switch pick {
        case 1...32: guaranteePct = 0.95
        case 33...64: guaranteePct = 0.6
        case 65...102: guaranteePct = 0.35
        default: guaranteePct = 0.15
        }
        return PlayerContract(
            isRookieContract: true,
            totalValue: rookieData.totalValue,
            currentYearSalary: rookieData.year1,
            yearlyValues: [rookieData.year1, rookieData.year2, rookieData.year3, rookieData.year4],
            yearsRemaining: 4,
            draftPick: pick,
            hasFifthYearOption: pick <= 32,
            totalGuaranteed: Int(Double(rookieData.totalValue) * (fullG ? 1.0 : guaranteePct)),
            guaranteedAtSigning: Int(Double(rookieData.totalValue) * (fullG ? 0.8 : guaranteePct * 0.7)),
            injuryGuaranteed: Int(Double(rookieData.totalValue) * (fullG ? 0.15 : guaranteePct * 0.2)),
            skillGuaranteed: Int(Double(rookieData.totalValue) * (fullG ? 0.05 : guaranteePct * 0.1)),
            signingBonus: Int(Double(rookieData.totalValue) * 0.6),
            hasOffsetLanguage: pick > 10 // enable offsets for most rookies
        )
    }
    
    static func createVeteranContract(player: PlayerData, salary: Int) -> PlayerContract {
        // Generate realistic veteran contract (2-5 years typically)
        let contractLength = generateContractLength(player: player)
        // Mix in bonus types (simplified proportions)
        let total = salary * contractLength
        let guaranteed = Int(Double(total) * 0.5)
        let rosterBonus = Int(Double(total) * 0.05)
        let workoutBonus = Int(Double(total) * 0.01)
        let ltbe = 0 // default none
        let ntlbe = 0

        return PlayerContract(
            isRookieContract: false,
            totalValue: total,
            currentYearSalary: salary,
            yearlyValues: Array(repeating: salary, count: contractLength),
            yearsRemaining: contractLength,
            draftPick: nil,
            hasFifthYearOption: false,
            totalGuaranteed: guaranteed,
            guaranteedAtSigning: Int(Double(total) * 0.35),
            injuryGuaranteed: Int(Double(total) * 0.1),
            skillGuaranteed: Int(Double(total) * 0.05),
            signingBonus: Int(Double(total) * 0.25),
            hasOffsetLanguage: true,
            ltbeIncentives: ltbe,
            ntlbeIncentives: ntlbe,
            rosterBonus: rosterBonus,
            optionBonus: 0,
            workoutBonus: workoutBonus
        )
    }
    
    private static func generateContractLength(player: PlayerData) -> Int {
        switch player.age {
        case 22...26: return Int.random(in: 3...5) // Longer deals for young players
        case 27...30: return Int.random(in: 2...4) // Medium deals for prime players
        case 31...35: return Int.random(in: 1...2) // Short deals for older players
        default: return 1
        }
    }
    
    // MARK: - Utility Functions
    
    static func estimatePlayerSalary(overall: Int, age: Int, position: String) -> Int {
        let baseWeight = Double(overall) / 100.0
        let ageMultiplier = getAgeMultiplier(age: age)
        let positionMultiplier = getPositionMultiplier(position: position)
        
        // Reduced base salary to be more realistic (~$1.5M average instead of $2.8M)
        let baseSalary = 1_500_000.0
        let estimatedSalary = baseSalary * baseWeight * ageMultiplier * positionMultiplier
        
        return max(Int(estimatedSalary), getMinimumSalary(player: PlayerData(
            firstName: "", lastName: "", position: position, number: 0, overall: overall, age: age
        )))
    }
    
    private static func isRookiePlayer(_ player: PlayerData) -> Bool {
        // Simple heuristic: players 22-23 years old with high ratings might be rookies
        return player.age <= 23 && (player.age - 22) <= 1
    }
    
    private static func estimateDraftPick(for player: PlayerData) -> Int? {
        // Estimate draft pick based on overall rating and position
        let overall = player.overall
        let position = player.position
        
        // High-value positions get drafted earlier
        let positionAdjustment: Int
        switch position {
        case "QB": positionAdjustment = 20
        case "LT", "DE", "EDGE": positionAdjustment = 15
        case "WR", "CB": positionAdjustment = 10
        case "RB", "TE": positionAdjustment = 5
        default: positionAdjustment = 0
        }
        
        let adjustedRating = overall + positionAdjustment
        
        // Convert to draft pick (higher rating = earlier pick)
        switch adjustedRating {
        case 95...: return Int.random(in: 1...10)
        case 90...94: return Int.random(in: 11...32)
        case 85...89: return Int.random(in: 33...64)
        case 80...84: return Int.random(in: 65...100)
        case 75...79: return Int.random(in: 101...150)
        default: return Int.random(in: 151...257)
        }
    }
    
    // MARK: - League-wide Salary Assignment
    
    static func assignAllTeamsSalaries(teams: [LeagueTeam]) {
        // Disabled in CSV-contract mode — APY from CSV is authoritative
        #if DEBUG
        print("💰 Skipping league-wide salary assignment — using CSV APY salaries")
        #endif
    }
    
    private static func validateSalaryCapCompliance(teams: [LeagueTeam]) {
        print("💰 Validating salary cap compliance...")
        
        for team in teams {
            let spending = team.totalSalarySpending
            let target = team.targetCapSpending
            let difference = abs(spending - target)
            
            print("   \(team.name): Target: $\(target), Actual: $\(spending), Diff: $\(difference)")
            
            // Should be reasonably close (within 5% due to estimation)
            let tolerance = target / 20 // 5% tolerance
            if difference > tolerance {
                print("   ⚠️ Large difference for \(team.name) - may need adjustment")
            }
        }
    }
} 