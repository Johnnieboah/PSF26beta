import Foundation

// MARK: - Salary Cap Data Access Layer

// Ready for UI consumption - all salary cap data easily accessible

extension LeagueManager {
    
    // MARK: - League-wide Salary Information
    
    func getLeagueSalaryOverview() -> LeagueSalaryOverview {
        let allTeamBreakdowns = allTeams.map { $0.getSalaryBreakdown() }
        
        let totalSpending = allTeamBreakdowns.reduce(0) { $0 + $1.totalSpending }
        let totalCap = NFLCapData.salaryCap * allTeams.count
        let averageSpending = totalSpending / max(allTeams.count, 1)
        
        let overCapTeams = allTeams.filter { $0.isOverCap }
        let nearCapTeams = allTeams.filter { team in
            let capUtilization = Double(team.totalSalarySpending) / Double(NFLCapData.salaryCap)
            return capUtilization > 0.95 && !team.isOverCap
        }
        
        return LeagueSalaryOverview(
            totalLeagueSpending: totalSpending,
            totalLeagueCap: totalCap,
            averageTeamSpending: averageSpending,
            overCapTeamsCount: overCapTeams.count,
            nearCapTeamsCount: nearCapTeams.count,
            healthyTeamsCount: allTeams.count - overCapTeams.count - nearCapTeams.count
        )
    }
    
    func getTeamsSortedByCapSpace() -> [LeagueTeam] {
        return allTeams.sorted { $0.capSpace > $1.capSpace }
    }
    
    func getTeamsSortedBySpending() -> [LeagueTeam] {
        return allTeams.sorted { $0.totalSalarySpending > $1.totalSalarySpending }
    }
    
    func getOverCapTeams() -> [LeagueTeam] {
        return allTeams.filter { $0.isOverCap }
    }
    
    // MARK: - Position Market Analysis
    
    func getPositionSalaryAnalysis() -> [PositionSalaryAnalysis] {
        let positions = ["QB", "RB", "WR", "TE", "LT", "LG", "C", "RG", "RT", "DE", "DT", "MLB", "ROLB", "LOLB", "CB", "SS", "FS", "K", "P"]
        
        return positions.compactMap { position in
            let allPositionPlayers = allTeams.flatMap { $0.getPlayersAtPosition(position) }
            guard !allPositionPlayers.isEmpty else { return nil }
            
            let salaries = allPositionPlayers.map { $0.estimatedSalary }.sorted(by: >)
            let totalSalary = salaries.reduce(0, +)
            let averageSalary = totalSalary / salaries.count
            let medianSalary = salaries[salaries.count / 2]
            
            return PositionSalaryAnalysis(
                position: position,
                playerCount: allPositionPlayers.count,
                totalSalary: totalSalary,
                averageSalary: averageSalary,
                medianSalary: medianSalary,
                highestSalary: salaries.first ?? 0,
                lowestSalary: salaries.last ?? 0,
                topPlayers: Array(allPositionPlayers.sorted { $0.estimatedSalary > $1.estimatedSalary }.prefix(5))
            )
        }
    }
    
    // MARK: - Contract Status League-wide
    
    func getLeagueContractStatus() -> LeagueContractStatus {
        let allPlayers = allTeams.flatMap { $0.players }
        
        let rookies = allPlayers.filter { $0.age <= 23 && (($0.age - 22) <= 1) }
        let veteransNearExpiry = allPlayers.filter { player in
            let yearsLeft = max(0, 4 - (player.age - 22))
            return yearsLeft <= 1 && player.age > 23
        }
        
        let totalContracts = allPlayers.count
        let averageContractLength = 3 // Estimated average
        
        return LeagueContractStatus(
            totalPlayers: totalContracts,
            rookieContracts: rookies.count,
            veteranContracts: totalContracts - rookies.count,
            expiringContracts: veteransNearExpiry.count,
            averageContractLength: averageContractLength,
            upcomingFreeAgents: veteransNearExpiry
        )
    }
    
    // MARK: - Salary Cap Projections
    
    func getCapProjections(yearsAhead: Int = 3) -> [CapProjection] {
        var projections: [CapProjection] = []
        
        for year in 1...yearsAhead {
            let projectedCap = NFLCapData.salaryCap + (year * 10_000_000) // Assume $10M annual increase
            
            let currentCommitments = allTeams.reduce(0) { teamTotal, team in
                // Estimate committed salary for future year
                let commitments = team.players.reduce(0) { playerTotal, player in
                    let yearsLeft = max(0, 4 - (player.age - 22))
                    return yearsLeft >= year ? playerTotal + player.estimatedSalary : playerTotal
                }
                return teamTotal + commitments
            }
            
            projections.append(CapProjection(
                year: year,
                projectedCap: projectedCap,
                currentCommitments: currentCommitments,
                availableSpace: (projectedCap * allTeams.count) - currentCommitments,
                flexibilityRating: calculateFlexibilityRating(commitments: currentCommitments, cap: projectedCap * allTeams.count)
            ))
        }
        
        return projections
    }
    
    private func calculateFlexibilityRating(commitments: Int, cap: Int) -> CapFlexibilityRating {
        let utilization = Double(commitments) / Double(cap)
        
        switch utilization {
        case 0.0...0.6: return .excellent
        case 0.6...0.75: return .good
        case 0.75...0.9: return .limited
        default: return .constrained
        }
    }
}

// MARK: - Data Structures for UI

struct LeagueSalaryOverview {
    let totalLeagueSpending: Int
    let totalLeagueCap: Int
    let averageTeamSpending: Int
    let overCapTeamsCount: Int
    let nearCapTeamsCount: Int
    let healthyTeamsCount: Int
    
    var leagueCapUtilization: Double {
        return Double(totalLeagueSpending) / Double(totalLeagueCap)
    }
    
    var averageCapSpace: Int {
        return (totalLeagueCap / 32) - averageTeamSpending
    }
}

struct PositionSalaryAnalysis {
    let position: String
    let playerCount: Int
    let totalSalary: Int
    let averageSalary: Int
    let medianSalary: Int
    let highestSalary: Int
    let lowestSalary: Int
    let topPlayers: [PlayerData]
    
    var salaryRange: Int {
        return highestSalary - lowestSalary
    }
    
    var marketTier: PositionMarketTier {
        switch averageSalary {
        case 8_000_000...: return .premium
        case 4_000_000...7_999_999: return .high
        case 2_000_000...3_999_999: return .medium
        case 1_000_000...1_999_999: return .low
        default: return .minimum
        }
    }
}

enum PositionMarketTier: String, CaseIterable {
    case premium = "Premium"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case minimum = "Minimum"
    
    var color: String {
        switch self {
        case .premium: return "#FF6B6B"
        case .high: return "#4ECDC4"
        case .medium: return "#45B7D1"
        case .low: return "#96CEB4"
        case .minimum: return "#FFEAA7"
        }
    }
}

struct LeagueContractStatus {
    let totalPlayers: Int
    let rookieContracts: Int
    let veteranContracts: Int
    let expiringContracts: Int
    let averageContractLength: Int
    let upcomingFreeAgents: [PlayerData]
    
    var rookiePercentage: Double {
        return Double(rookieContracts) / Double(totalPlayers)
    }
    
    var expiringPercentage: Double {
        return Double(expiringContracts) / Double(totalPlayers)
    }
    
    var contractStability: ContractStability {
        switch expiringPercentage {
        case 0.0...0.15: return .stable
        case 0.15...0.25: return .moderate
        default: return .volatile
        }
    }
}

enum ContractStability: String {
    case stable = "Stable"
    case moderate = "Moderate"
    case volatile = "Volatile"
    
    var color: String {
        switch self {
        case .stable: return "#2ECC71"
        case .moderate: return "#F39C12"
        case .volatile: return "#E74C3C"
        }
    }
}

struct CapProjection {
    let year: Int
    let projectedCap: Int
    let currentCommitments: Int
    let availableSpace: Int
    let flexibilityRating: CapFlexibilityRating
    
    var commitmentPercentage: Double {
        return Double(currentCommitments) / Double(projectedCap * 32)
    }
}

enum CapFlexibilityRating: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case limited = "Limited"
    case constrained = "Constrained"
    
    var color: String {
        switch self {
        case .excellent: return "#2ECC71"
        case .good: return "#27AE60"
        case .limited: return "#F39C12"
        case .constrained: return "#E74C3C"
        }
    }
    
    var description: String {
        switch self {
        case .excellent: return "Plenty of flexibility for signings and extensions"
        case .good: return "Good flexibility with some room for moves"
        case .limited: return "Limited flexibility - careful planning needed"
        case .constrained: return "Heavily constrained - difficult to make moves"
        }
    }
}

// MARK: - Quick Access Functions

extension LeagueTeam {
    // MARK: Top-51 offseason cap usage (approximation)
    /// Computes current cap usage using Top-51 rule if in offseason.
    /// Falls back to totalSalarySpending if roster/contract details unavailable.
    func currentCapUsageTop51(isOffseason: Bool) -> Int {
        guard isOffseason else { return totalSalarySpending }
        let salaries = players.map { $0.estimatedSalary }
        if salaries.isEmpty { return totalSalarySpending }
        return salaries.sorted(by: >).prefix(51).reduce(0, +)
    }

    /// Checks whether a team can afford an added cap charge under current rules.
    /// Uses Top-51 outside of the regular season.
    func canAffordCapHit(addedCharge: Int, isOffseason: Bool) -> Bool {
        let usage = currentCapUsageTop51(isOffseason: isOffseason)
        return usage + addedCharge <= NFLCapData.salaryCap
    }
    
    // Quick salary information for UI displays
    var salaryCapSummary: String {
        let spending = totalSalarySpending
        let cap = NFLCapData.salaryCap
        let space = cap - spending
        
        if space >= 0 {
            return "$\(space / 1_000_000)M under cap"
        } else {
            return "$\(abs(space) / 1_000_000)M over cap"
        }
    }
    
    var capHealthColor: String {
        let utilization = Double(totalSalarySpending) / Double(NFLCapData.salaryCap)
        
        switch utilization {
        case 0.0...0.8: return "#2ECC71" // Green - healthy
        case 0.8...0.95: return "#F39C12" // Orange - caution
        default: return "#E74C3C" // Red - danger
        }
    }
    
    var topSalaryPositions: [String] {
        let positionTotals = getSalaryByPosition()
        return positionTotals.sorted { $0.value > $1.value }
                           .prefix(3)
                           .map { $0.key }
    }
} 