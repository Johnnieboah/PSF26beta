import Foundation

// MARK: - Contract Manager

class ContractManager {
    
    // MARK: - Season Progression
    
    static func progressAllContracts(league: LeagueManager) {
        print("📋 Processing contract progression for all teams...")
        
        for team in league.allTeams {
            progressTeamContracts(team: team)
        }
        
        print("📋 Contract progression complete!")
    }
    
    private static func progressTeamContracts(team: LeagueTeam) {
        print("📋 Processing contracts for \(team.name)...")
        
        var playersToRelease: [PlayerData] = []
        var contractsProgressed = 0
        
        for player in team.players {
            if let result = progressPlayerContract(player: player) {
                switch result {
                case .renewed:
                    contractsProgressed += 1
                case .expired:
                    playersToRelease.append(player)
                case .continued:
                    contractsProgressed += 1
                }
            }
        }
        
        print("   Contracts progressed: \(contractsProgressed)")
        print("   Players becoming free agents: \(playersToRelease.count)")
        
        // Handle free agency (simplified - just log for now)
        for player in playersToRelease {
            print("   🏃 \(player.fullName) becomes a free agent")
        }
    }
    
    private static func progressPlayerContract(player: PlayerData) -> ContractProgressionResult? {
        // PlayerData does not carry a runtime contract object. Use heuristic progression.
        let estimatedYearsLeft = estimateContractYearsRemaining(player: player)
        if estimatedYearsLeft <= 0 { return .expired }
        if estimatedYearsLeft == 1 && shouldRenewContract(player: player) { return .renewed }
        return .continued
    }
    
    private static func estimateContractYearsRemaining(player: PlayerData) -> Int {
        // Simple heuristic based on age and performance
        let yearsInLeague = max(0, player.age - 22)
        
        // Assume most contracts are 3-4 years
        let estimatedContractLength = 4
        let yearsIntoContract = yearsInLeague % estimatedContractLength
        
        return max(0, estimatedContractLength - yearsIntoContract)
    }
    
    private static func shouldRenewContract(player: PlayerData) -> Bool {
        // Renewal based on performance and age
        switch player.overall {
        case 85...: return true  // Elite players always renewed
        case 75...84: return player.age < 32  // Good players if not too old
        case 65...74: return player.age < 28  // Average players if young
        default: return false  // Below average players not renewed
        }
    }
    
    // MARK: - Draft Integration
    
    static func assignRookieContract(player: PlayerData, draftPick: Int, draftYear: Int) -> PlayerContract {
        print("📋 Assigning rookie contract: \(player.fullName) (Pick #\(draftPick))")
        
        let rookieContract = SalaryCapManager.createRookieContract(pick: draftPick)
        
        print("   Contract: $\(rookieContract.totalValue) over \(rookieContract.yearsRemaining) years")
        print("   Year 1 salary: $\(rookieContract.currentYearSalary)")
        
        return rookieContract
    }
    
    // MARK: - Free Agency Simulation
    
    static func simulateFreeAgency(league: LeagueManager) {
        print("🏃 Simulating free agency...")
        
        // Get all free agents (players with expired contracts)
        var freeAgents: [PlayerData] = []
        
        for team in league.allTeams {
            for player in team.players {
                if estimateContractYearsRemaining(player: player) <= 0 {
                    freeAgents.append(player)
                }
            }
        }
        
        print("   Free agents available: \(freeAgents.count)")
        
        // Simple free agency - assign players to teams with cap space
        for freeAgent in freeAgents {
            if let newTeam = findTeamForFreeAgent(freeAgent, in: league.allTeams) {
                print("   \(freeAgent.fullName) signs with \(newTeam.name)")
            } else {
                print("   \(freeAgent.fullName) remains unsigned")
            }
        }
    }
    
    private static func findTeamForFreeAgent(_ player: PlayerData, in teams: [LeagueTeam]) -> LeagueTeam? {
        // Find teams with cap space that need this position
        let teamsWithCapSpace = teams.filter { $0.capSpace > player.estimatedSalary }
        
        // Prefer teams that need this position
        let teamsNeedingPosition = teamsWithCapSpace.filter { team in
            let positionPlayers = team.players.filter { $0.position == player.position }
            return positionPlayers.count < getIdealPositionCount(position: player.position)
        }
        
        return teamsNeedingPosition.randomElement() ?? teamsWithCapSpace.randomElement()
    }
    
    private static func getIdealPositionCount(position: String) -> Int {
        switch position {
        case "QB": return 3
        case "RB", "FB": return 4
        case "WR": return 6
        case "TE": return 3
        case "LT", "LG", "C", "RG", "RT": return 2
        case "DE", "DT": return 4
        case "MLB", "ROLB", "LOLB": return 4
        case "CB": return 5
        case "SS", "FS": return 3
        case "K", "P": return 1
        default: return 2
        }
    }
    
    // MARK: - Contract Extensions
    
    static func offerContractExtension(player: PlayerData, team: LeagueTeam) -> PlayerContract? {
        let yearsLeft = estimateContractYearsRemaining(player: player)
        
        // Only offer extensions to players with 1-2 years left
        guard yearsLeft <= 2 else { return nil }
        
        // Check if team wants to extend
        guard shouldOfferExtension(player: player, team: team) else { return nil }
        
        // Calculate extension terms
        let newSalary = calculateExtensionSalary(player: player)
        let extensionYears = calculateExtensionLength(player: player)
        
        print("📋 Offering extension to \(player.fullName): \(extensionYears) years, $\(newSalary)/year")
        
        return SalaryCapManager.createVeteranContract(player: player, salary: newSalary)
    }
    
    private static func shouldOfferExtension(player: PlayerData, team: LeagueTeam) -> Bool {
        // Check if team can afford extension
        let extensionSalary = calculateExtensionSalary(player: player)
        guard team.canAffordPlayer(withSalary: extensionSalary) else { return false }
        
        // Check if player is worth extending
        return player.overall >= 70 && player.age <= 32
    }
    
    private static func calculateExtensionSalary(player: PlayerData) -> Int {
        // Base extension on current estimated value with some increase
        let currentValue = player.estimatedSalary
        let increaseMultiplier = player.overall >= 85 ? 1.2 : 1.1
        
        return Int(Double(currentValue) * increaseMultiplier)
    }
    
    private static func calculateExtensionLength(player: PlayerData) -> Int {
        switch player.age {
        case 22...26: return Int.random(in: 4...6) // Long deals for young stars
        case 27...30: return Int.random(in: 3...4) // Medium deals for prime players
        case 31...34: return Int.random(in: 2...3) // Short deals for aging players
        default: return 1 // One year deals for very old players
        }
    }
    
    // MARK: - Salary Cap Management
    
    static func checkSalaryCapCompliance(team: LeagueTeam) -> SalaryCapStatus {
        let spending = team.totalSalarySpending
        let cap = NFLCapData.salaryCap
        
        if spending > cap {
            return .overCap(amount: spending - cap)
        } else if spending > Int(Double(cap) * 0.95) {
            return .nearCap(remaining: cap - spending)
        } else {
            return .underCap(remaining: cap - spending)
        }
    }
    
    static func suggestCapMoves(team: LeagueTeam) -> [CapManagementSuggestion] {
        let status = checkSalaryCapCompliance(team: team)
        var suggestions: [CapManagementSuggestion] = []
        
        switch status {
        case .overCap(let amount):
            suggestions.append(.cutPlayers(amount: amount))
            suggestions.append(.restructureContracts)
            
        case .nearCap(let remaining):
            if remaining < 5_000_000 {
                suggestions.append(.cautionOnSigning)
            }
            
        case .underCap(let remaining):
            if remaining > 20_000_000 {
                suggestions.append(.signFreeAgents)
                suggestions.append(.extendKeyPlayers)
            }
        }
        
        return suggestions
    }
}

// MARK: - Supporting Enums and Structs

enum ContractProgressionResult {
    case continued
    case renewed
    case expired
}

enum SalaryCapStatus {
    case overCap(amount: Int)
    case nearCap(remaining: Int)
    case underCap(remaining: Int)
}

enum CapManagementSuggestion {
    case cutPlayers(amount: Int)
    case restructureContracts
    case signFreeAgents
    case extendKeyPlayers
    case cautionOnSigning
    
    var description: String {
        switch self {
        case .cutPlayers(let amount):
            return "Cut players to save $\(amount)"
        case .restructureContracts:
            return "Restructure contracts to create cap space"
        case .signFreeAgents:
            return "Sign free agents to improve roster"
        case .extendKeyPlayers:
            return "Extend key players before they hit free agency"
        case .cautionOnSigning:
            return "Be cautious with new signings - limited cap space"
        }
    }
} 