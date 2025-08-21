import Foundation

// MARK: - LeagueTeam Extensions for Salary Cap

extension LeagueTeam {
    
    // MARK: - Salary Calculations
    
    var totalSalarySpending: Int {
        // Use actualSalary when present; otherwise fallback to estimated
        let total = players.reduce(0) { $0 + ($1.actualSalary ?? $1.estimatedSalary) }
        return max(0, min(total, Int.max / 2)) // Prevent overflow and negative values
    }
    
    var targetCapSpending: Int {
        return NFLCapData.getCapSpending(for: logoName)
    }
    
    var capSpace: Int {
        return NFLCapData.salaryCap - totalSalarySpending
    }
    
    var rookieSalaryTotal: Int {
        let total = players.filter { player in
            // Check if player is a rookie (0 years pro or drafted this year)
            return player.age <= 23 && (player.age - 22) <= 1
        }.reduce(0) { $0 + $1.estimatedSalary }
        return max(0, min(total, Int.max / 2)) // Prevent overflow and negative values
    }
    
    var veteranSalaryTotal: Int {
        return max(0, totalSalarySpending - rookieSalaryTotal)
    }
    
    var isOverCap: Bool {
        return totalSalarySpending > NFLCapData.salaryCap
    }
    
    // MARK: - Salary Breakdown
    
    func getSalaryBreakdown() -> TeamSalaryBreakdown {
        return TeamSalaryBreakdown(
            totalSpending: totalSalarySpending,
            targetSpending: targetCapSpending,
            capSpace: capSpace,
            rookieTotal: rookieSalaryTotal,
            veteranTotal: veteranSalaryTotal,
            averageSalary: players.isEmpty ? 0 : totalSalarySpending / players.count,
            highestPaid: players.max(by: { $0.estimatedSalary < $1.estimatedSalary }),
            lowestPaid: players.min(by: { $0.estimatedSalary < $1.estimatedSalary })
        )
    }
    
    func getSalaryByPosition() -> [String: Int] {
        var positionTotals: [String: Int] = [:]
        for player in players {
            let currentTotal = positionTotals[player.position] ?? 0
            let newTotal = currentTotal + player.estimatedSalary
            positionTotals[player.position] = max(0, min(newTotal, Int.max / 2)) // Prevent overflow and negative values
        }
        return positionTotals
    }
    
    func getContractStatusSummary() -> ContractStatusSummary {
        let rookies = players.filter { $0.age <= 23 && (($0.age - 22) <= 1) }
        let expiringContracts = players.filter { player in
            // Estimate contract expiration based on age and years pro
            let yearsLeft = max(0, 4 - (player.age - 22)) // Assume 4-year contracts
            return yearsLeft <= 1
        }
        
        return ContractStatusSummary(
            totalPlayers: players.count,
            rookiesCount: rookies.count,
            expiringCount: expiringContracts.count,
            averageYearsRemaining: 2 // Default estimate
        )
    }
    
    // MARK: - Cap Management
    
    func updateSalaryTotals() {
        // This would trigger recalculation of salary totals
        // Implementation depends on how the team data is managed
    }
    
    func canAffordPlayer(withSalary salary: Int) -> Bool {
        return capSpace >= salary
    }
    
    // MARK: - Roster Management (Training Camp & Regular Season)
    
    /// Validates that the roster meets NFL requirements
    /// - Parameter isTrainingCamp: Whether the team is in training camp mode (60 players) or regular season (53 players)
    func isRosterValid(isTrainingCamp: Bool = false) -> Bool {
        let targetSize = isTrainingCamp ? 60 : 53
        return players.count == targetSize
    }
    
    /// Legacy method for backward compatibility - assumes regular season
    var isRosterValid: Bool {
        return isRosterValid(isTrainingCamp: false)
    }
    
    /// Returns the number of roster spots available
    /// - Parameter isTrainingCamp: Whether the team is in training camp mode (60 players) or regular season (53 players)
    func availableRosterSpots(isTrainingCamp: Bool = false) -> Int {
        let targetSize = isTrainingCamp ? 60 : 53
        return max(0, targetSize - players.count)
    }
    
    /// Legacy method for backward compatibility - assumes regular season
    var availableRosterSpots: Int {
        return availableRosterSpots(isTrainingCamp: false)
    }
    
    /// Checks if a player can be added to the roster
    /// - Parameter isTrainingCamp: Whether the team is in training camp mode (60 players) or regular season (53 players)
    func canAddPlayer(isTrainingCamp: Bool = false) -> Bool {
        let targetSize = isTrainingCamp ? 60 : 53
        return players.count < targetSize
    }
    
    /// Legacy method for backward compatibility - assumes regular season
    func canAddPlayer() -> Bool {
        return canAddPlayer(isTrainingCamp: false)
    }
    
    /// Returns roster status for UI display
    /// - Parameter isTrainingCamp: Whether the team is in training camp mode (60 players) or regular season (53 players)
    func rosterStatus(isTrainingCamp: Bool = false) -> RosterStatus {
        let count = players.count
        let targetSize = isTrainingCamp ? 60 : 53
        let nearFullThreshold = isTrainingCamp ? 57 : 50
        
        if count > targetSize {
            return .overLimit
        } else if count == targetSize {
            return .full
        } else if count >= nearFullThreshold {
            return .nearFull
        } else {
            return .normal
        }
    }
    
    /// Legacy method for backward compatibility - assumes regular season
    var rosterStatus: RosterStatus {
        return rosterStatus(isTrainingCamp: false)
    }
    
    /// Gets roster composition by position for validation
    func getRosterComposition() -> [String: Int] {
        var composition: [String: Int] = [:]
        for player in players {
            composition[player.position, default: 0] += 1
        }
        return composition
    }
    
    /// Validates roster has minimum required positions
    func hasMinimumPositionRequirements() -> Bool {
        let composition = getRosterComposition()
        
        // Basic NFL roster requirements (simplified)
        let minimumRequirements: [String: Int] = [
            "QB": 2,    // At least 2 quarterbacks
            "K": 1,     // At least 1 kicker
            "P": 1      // At least 1 punter
        ]
        
        for (position, minCount) in minimumRequirements {
            if (composition[position] ?? 0) < minCount {
                return false
            }
        }
        
        return true
    }
    
    /// Releases a player from the team (moves to free agency)
    func releasePlayer(_ player: PlayerData) -> Bool {
        // Validate we can release this player (maintain minimums)
        let composition = getRosterComposition()
        let currentAtPosition = composition[player.position] ?? 0
        
        // Check critical position minimums
        let criticalMinimums: [String: Int] = [
            "QB": 2,    // Must keep at least 2 QBs
            "K": 1,     // Must keep at least 1 kicker
            "P": 1      // Must keep at least 1 punter
        ]
        
        if let minRequired = criticalMinimums[player.position],
           currentAtPosition <= minRequired {
            print("❌ Cannot release \(player.fullName) - would violate minimum position requirements")
            return false
        }
        
        // Player can be released
        print("🚫 Releasing \(player.fullName) from \(name)")
        return true
    }
    
    /// Gets players that can be safely released (doesn't violate minimums)
    func getReleasablePlayers() -> [PlayerData] {
        let composition = getRosterComposition()
        let criticalMinimums: [String: Int] = [
            "QB": 2, "K": 1, "P": 1
        ]
        
        return players.filter { player in
            let currentAtPosition = composition[player.position] ?? 0
            let minRequired = criticalMinimums[player.position] ?? 0
            return currentAtPosition > minRequired
        }
    }
    
    /// Gets recommended players for release (lowest overall at non-critical positions)
    func getRecommendedReleases(count: Int) -> [PlayerData] {
        let releasablePlayers = getReleasablePlayers()
        
        // Sort by overall rating (lowest first) and exclude critical starters
        return releasablePlayers
            .sorted { $0.overall < $1.overall }
            .prefix(count)
            .map { $0 }
    }
    
    func getTopPaidPlayers(count: Int = 5) -> [PlayerData] {
        return players.sorted { $0.estimatedSalary > $1.estimatedSalary }
                     .prefix(count)
                     .map { $0 }
    }
    
    func getPlayersAtPosition(_ position: String) -> [PlayerData] {
        return players.filter { $0.position == position }
    }
    
    func getPositionSalaryCap(_ position: String) -> Int {
        let positionPlayers = getPlayersAtPosition(position)
        let total = positionPlayers.reduce(0) { $0 + $1.estimatedSalary }
        return max(0, min(total, Int.max / 2)) // Prevent overflow and negative values
    }
}

// MARK: - Supporting Data Structures

struct TeamSalaryBreakdown {
    let totalSpending: Int
    let targetSpending: Int
    let capSpace: Int
    let rookieTotal: Int
    let veteranTotal: Int
    let averageSalary: Int
    let highestPaid: PlayerData?
    let lowestPaid: PlayerData?
    
    var capUtilization: Double {
        return Double(totalSpending) / Double(NFLCapData.salaryCap)
    }
    
    var isHealthy: Bool {
        return capSpace > 0 && capUtilization < 0.95
    }
}

struct ContractStatusSummary {
    let totalPlayers: Int
    let rookiesCount: Int
    let expiringCount: Int
    let averageYearsRemaining: Int
    
    var rookiePercentage: Double {
        return Double(rookiesCount) / Double(max(totalPlayers, 1))
    }
    
    var expiringPercentage: Double {
        return Double(expiringCount) / Double(max(totalPlayers, 1))
    }
}

// MARK: - Roster Management Enums

enum RosterStatus {
    case normal      // Under threshold (50 regular season / 57 training camp)
    case nearFull    // Near full (50-52 regular season / 57-59 training camp)
    case full        // Exactly full (53 regular season / 60 training camp)
    case overLimit   // Over limit (invalid)
    
    var displayText: String {
        switch self {
        case .normal:
            return "Roster OK"
        case .nearFull:
            return "Nearly Full"
        case .full:
            return "Roster Full"
        case .overLimit:
            return "Over Limit"
        }
    }
    
    var color: String {
        switch self {
        case .normal:
            return "primary"
        case .nearFull:
            return "orange"
        case .full:
            return "green"
        case .overLimit:
            return "red"
        }
    }
} 