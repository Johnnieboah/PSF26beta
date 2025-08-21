import Foundation

// MARK: - Dead Money Calculation Result

struct DeadMoneyCalculation {
    let totalDeadMoney: Int
    let currentYearHit: Int
    let nextYearHit: Int
    let capSavings: Int
    let isPostJune1: Bool
    
    var isWorthwhile: Bool {
        return capSavings > 0
    }
    
    var description: String {
        if isPostJune1 {
            return "Dead Money: $\(formatCurrency(totalDeadMoney)) (This Year: $\(formatCurrency(currentYearHit)), Next Year: $\(formatCurrency(nextYearHit)))"
        } else {
            return "Dead Money: $\(formatCurrency(totalDeadMoney))"
        }
    }
    
    private func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}

// MARK: - Player Contract Data Models

struct PlayerContract: Codable {
    let isRookieContract: Bool
    let totalValue: Int
    var currentYearSalary: Int
    let yearlyValues: [Int] // For rookies: [year1, year2, year3, year4]
    var yearsRemaining: Int
    let draftPick: Int? // Only for rookies
    let hasFifthYearOption: Bool // Only for picks 1-32
    let signedDate: Date
    
    // Guaranteed money components
    let totalGuaranteed: Int
    let guaranteedAtSigning: Int
    let injuryGuaranteed: Int
    let skillGuaranteed: Int
    
    // Signing bonus and prorated information
    var signingBonus: Int
    var proratedBonusRemaining: Int
    let hasOffsetLanguage: Bool
    var voidYears: Int = 0
    // Incentives (simplified): LTBE affects current-year cap; NTLBE does not until earned next year
    var ltbeIncentives: Int = 0
    var ntlbeIncentives: Int = 0
    // Additional bonus types (simplified accounting)
    var rosterBonus: Int = 0
    var optionBonus: Int = 0
    var workoutBonus: Int = 0
    
    init(isRookieContract: Bool, totalValue: Int, currentYearSalary: Int, yearlyValues: [Int], yearsRemaining: Int, draftPick: Int? = nil, hasFifthYearOption: Bool = false, totalGuaranteed: Int? = nil, guaranteedAtSigning: Int? = nil, injuryGuaranteed: Int? = nil, skillGuaranteed: Int? = nil, signingBonus: Int? = nil, hasOffsetLanguage: Bool = false, ltbeIncentives: Int = 0, ntlbeIncentives: Int = 0, rosterBonus: Int = 0, optionBonus: Int = 0, workoutBonus: Int = 0) {
        self.isRookieContract = isRookieContract
        self.totalValue = totalValue
        self.currentYearSalary = currentYearSalary
        self.yearlyValues = yearlyValues
        self.yearsRemaining = yearsRemaining
        self.draftPick = draftPick
        self.hasFifthYearOption = hasFifthYearOption
        self.signedDate = Date()
        self.hasOffsetLanguage = hasOffsetLanguage
        self.voidYears = 0
        self.ltbeIncentives = ltbeIncentives
        self.ntlbeIncentives = ntlbeIncentives
        self.rosterBonus = rosterBonus
        self.optionBonus = optionBonus
        self.workoutBonus = workoutBonus
        
        // Calculate guaranteed money if not provided
        let calculatedGuaranteed = totalGuaranteed ?? Int(Double(totalValue) * (isRookieContract ? 1.0 : 0.5))
        self.totalGuaranteed = calculatedGuaranteed
        self.guaranteedAtSigning = guaranteedAtSigning ?? Int(Double(calculatedGuaranteed) * 0.7)
        self.injuryGuaranteed = injuryGuaranteed ?? Int(Double(calculatedGuaranteed) * 0.2)
        self.skillGuaranteed = skillGuaranteed ?? Int(Double(calculatedGuaranteed) * 0.1)
        
        // Calculate signing bonus (typically 20-30% of total value for veterans)
        let calculatedSigningBonus = signingBonus ?? Int(Double(totalValue) * (isRookieContract ? 0.6 : 0.25))
        self.signingBonus = calculatedSigningBonus
        
        // Calculate remaining prorated bonus (signing bonus divided by original contract length)
        let originalContractLength = yearlyValues.count
        let proratedPerYear = originalContractLength > 0 ? calculatedSigningBonus / originalContractLength : 0
        self.proratedBonusRemaining = proratedPerYear * yearsRemaining
    }
    
    // Computed properties for salary cap impact
    var guaranteedPercentage: Double {
        return totalValue > 0 ? Double(totalGuaranteed) / Double(totalValue) : 0.0
    }
    
    /// Legacy simplified cap hit (kept for compatibility)
    var capHitCurrentYear: Int {
        let guaranteedHit = totalGuaranteed / max(yearsRemaining, 1)
        let baseHit = currentYearSalary
        return max(guaranteedHit, baseHit)
    }

    /// More accurate cap hit using proration of remaining signing bonus
    var capHitThisYearAccurate: Int {
        let proration = proratedBonusRemaining / max(yearsRemaining + voidYears, 1)
        // LTBE counts now; NTLBE deferred
        return currentYearSalary + proration + rosterBonus + workoutBonus + ltbeIncentives
    }
    
    // MARK: - Dead Money Calculations
    
    /// Calculate dead money if player is released (pre-June 1)
    func calculateDeadMoney(isPostJune1: Bool = false) -> DeadMoneyCalculation {
        // Dead money = remaining guaranteed money + remaining prorated signing bonus
        let remainingGuaranteed = calculateRemainingGuaranteedMoney()
        let deadMoney = remainingGuaranteed + proratedBonusRemaining
        
        if isPostJune1 && yearsRemaining > 1 {
            // Post-June 1 cut: spread dead money over 2 years
            let currentYearDeadMoney = remainingGuaranteed + (proratedBonusRemaining / 2)
            let nextYearDeadMoney = proratedBonusRemaining / 2
            
            return DeadMoneyCalculation(
                totalDeadMoney: deadMoney,
                currentYearHit: currentYearDeadMoney,
                nextYearHit: nextYearDeadMoney,
                capSavings: currentYearSalary - currentYearDeadMoney,
                isPostJune1: true
            )
        } else {
            // Pre-June 1 cut: all dead money hits current year
            return DeadMoneyCalculation(
                totalDeadMoney: deadMoney,
                currentYearHit: deadMoney,
                nextYearHit: 0,
                capSavings: currentYearSalary - deadMoney,
                isPostJune1: false
            )
        }
    }
    
    /// Calculate remaining guaranteed money based on contract structure
    private func calculateRemainingGuaranteedMoney() -> Int {
        // For simplicity, assume guaranteed money is spread evenly over remaining years
        // In reality, this would depend on specific contract language
        let guaranteedPerYear = totalGuaranteed / yearlyValues.count
        return guaranteedPerYear * yearsRemaining
    }

    // MARK: - Seasonal Roll Forward
    /// Advance one season: decrease yearsRemaining, advance currentYearSalary, decrease proration, drop expired bonuses
    mutating func advanceSeason() {
        guard yearsRemaining > 0 else { return }
        let originalLength = max(yearlyValues.count, 1)
        let perYearProration = signingBonus / originalLength
        proratedBonusRemaining = max(0, proratedBonusRemaining - perYearProration)
        // Move salary to next year if available
        let yearsUsed = (yearlyValues.count - yearsRemaining) + 1
        if yearsUsed < yearlyValues.count {
            currentYearSalary = yearlyValues[yearsUsed]
        }
        // Option/roster/workout bonuses reset per year; incentives reset
        ltbeIncentives = 0
        ntlbeIncentives = 0
        rosterBonus = 0
        workoutBonus = 0
        // Reduce years remaining (ensure non-negative). No change to voidYears here.
        yearsRemaining = max(0, yearsRemaining - 1)
    }
    
    /// Calculate cap savings from releasing player
    func calculateCapSavings(isPostJune1: Bool = false) -> Int {
        let deadMoneyCalc = calculateDeadMoney(isPostJune1: isPostJune1)
        return deadMoneyCalc.capSavings
    }
    
    /// Check if releasing player makes financial sense
    func isReleaseWorthwhile(isPostJune1: Bool = false) -> Bool {
        let capSavings = calculateCapSavings(isPostJune1: isPostJune1)
        return capSavings > 0
    }
}

// MARK: - Restructure Utilities
extension PlayerContract {
    /// Converts a portion of current-year base salary into signing bonus and prorates it across
    /// remaining years plus optional void years. Updates currentYearSalary, signingBonus, and
    /// proratedBonusRemaining. Does not change yearsRemaining; void years are tracked in `voidYears`.
    mutating func applyRestructure(convertBaseToBonus amount: Int, addVoidYears: Int = 0) {
        guard amount > 0 else { return }
        let convert = max(0, amount)
        // Guardrail: keep minimum base (approx vet min)
        let vetMin = 840_000
        let allowedConvert = max(0, min(convert, max(0, currentYearSalary - vetMin)))
        currentYearSalary = max(vetMin, currentYearSalary - allowedConvert)
        signingBonus += allowedConvert
        proratedBonusRemaining += allowedConvert
        // Guardrail: proration horizon <= 5 years including void years
        if addVoidYears > 0 {
            let totalHorizon = yearsRemaining + min(addVoidYears, 5)
            let maxVoid = max(0, min(5 - yearsRemaining, addVoidYears))
            if totalHorizon <= 5 {
                voidYears = max(voidYears, maxVoid)
            } else {
                voidYears = max(voidYears, max(0, 5 - yearsRemaining))
            }
        }
    }
}

// MARK: - Player Release Manager

class PlayerReleaseManager {
    
    enum ReleaseType {
        case immediate      // Standard release
        case postJune1     // Post-June 1 designation
        case injured       // Injured reserve release
    }
    
    struct ReleaseOption {
        let type: ReleaseType
        let deadMoneyCalculation: DeadMoneyCalculation
        let title: String
        let description: String
        let isRecommended: Bool
    }
    
    /// Generate release options for a player
    static func generateReleaseOptions(for player: PlayerData, contract: PlayerContract) -> [ReleaseOption] {
        var options: [ReleaseOption] = []
        
        // Standard immediate release
        let immediateDeadMoney = contract.calculateDeadMoney(isPostJune1: false)
        let immediateOption = ReleaseOption(
            type: .immediate,
            deadMoneyCalculation: immediateDeadMoney,
            title: "Release Now",
            description: "Standard release. All dead money hits this year's cap.",
            isRecommended: immediateDeadMoney.capSavings > 0
        )
        options.append(immediateOption)
        
        // Post-June 1 release (only if it provides benefit)
        if contract.yearsRemaining > 1 {
            let postJune1DeadMoney = contract.calculateDeadMoney(isPostJune1: true)
            let postJune1Option = ReleaseOption(
                type: .postJune1,
                deadMoneyCalculation: postJune1DeadMoney,
                title: "Post-June 1 Release",
                description: "Spread dead money over two years. More cap space this year.",
                isRecommended: postJune1DeadMoney.capSavings > immediateDeadMoney.capSavings
            )
            options.append(postJune1Option)
        }
        
        return options
    }
    
    /// Execute player release
    static func releasePlayer(
        player: PlayerData,
        releaseType: ReleaseType,
        leagueId: UUID,
        teamLogoName: String
    ) async throws {
        print("🚫 Releasing \(player.fullName) with \(releaseType) designation")
        
        // Check minimum roster requirements first
        let minRosterSize = 45 // NFL minimum roster size during season
        let currentRosterSize = try await getCurrentRosterSize(leagueId: leagueId, teamLogoName: teamLogoName)
        
        if currentRosterSize <= minRosterSize {
            print("❌ Cannot release player: Team would be below minimum roster size (\(minRosterSize))")
            throw PlayerReleaseError.belowMinimumRoster
        }
        
        // Get player from roster
        let editablePlayer: EditablePlayerData
        do {
            editablePlayer = try await getEditablePlayer(player: player, leagueId: leagueId, teamLogoName: teamLogoName)
        } catch {
            print("❌ Could not find player in roster: \(error)")
            throw PlayerReleaseError.playerNotFound
        }
        
        // Check if player has a contract
        guard let contract = editablePlayer.contract else {
            print("❌ Player \(player.fullName) has no contract information")
            // Allow release of players without contracts, but with zero dead money
            try await removePlayerFromRoster(player: player, leagueId: leagueId, teamLogoName: teamLogoName)
            try await addPlayerToFreeAgency(player: editablePlayer)
            print("✅ \(player.fullName) released successfully (no contract)")
            return
        }
        
        print("💰 Found contract: \(contract.yearsRemaining) years, $\(contract.currentYearSalary)/year")
        
        // Calculate dead money impact
        let deadMoneyCalc = contract.calculateDeadMoney(isPostJune1: releaseType == .postJune1)
        
        // Remove player from team roster
        try await removePlayerFromRoster(player: player, leagueId: leagueId, teamLogoName: teamLogoName)
        
        // Add player to free agency
        try await addPlayerToFreeAgency(player: editablePlayer)
        
        // Apply dead money to team's cap
        // This would integrate with salary cap management system
        
        print("✅ \(player.fullName) released successfully")
        print("💰 Dead money impact: \(deadMoneyCalc.description)")
        print("📊 Cap savings: $\(deadMoneyCalc.capSavings)")
    }
    
    private static func getEditablePlayer(player: PlayerData, leagueId: UUID, teamLogoName: String) async throws -> EditablePlayerData {
        let playerDataManager = PlayerDataManager.shared
        let players = try playerDataManager.loadPlayersFromFile(leagueId: leagueId, teamLogoName: teamLogoName)
        
        print("🔍 Looking for player: \(player.firstName) \(player.lastName) #\(player.number)")
        print("📋 Team roster has \(players.count) players")
        
        // Debug: List first few players for comparison
        for (index, p) in players.prefix(3).enumerated() {
            print("   \(index + 1). \(p.firstName) \(p.lastName) #\(p.number)")
        }
        
        guard let editablePlayer = players.first(where: { 
            $0.firstName == player.firstName && 
            $0.lastName == player.lastName && 
            $0.number == player.number 
        }) else {
            print("❌ Player not found in roster")
            throw PlayerReleaseError.playerNotFound
        }
        
        print("✅ Found matching player: \(editablePlayer.firstName) \(editablePlayer.lastName) #\(editablePlayer.number)")
        return editablePlayer
    }
    
    private static func removePlayerFromRoster(player: PlayerData, leagueId: UUID, teamLogoName: String) async throws {
        let playerDataManager = PlayerDataManager.shared
        var players = try playerDataManager.loadPlayersFromFile(leagueId: leagueId, teamLogoName: teamLogoName)
        
        let initialCount = players.count
        print("📋 Initial roster size: \(initialCount) players")
        print("🗑️ Removing player: \(player.firstName) \(player.lastName) #\(player.number)")
        
        players.removeAll { 
            $0.firstName == player.firstName && 
            $0.lastName == player.lastName && 
            $0.number == player.number 
        }
        
        let finalCount = players.count
        print("📋 Final roster size: \(finalCount) players (removed \(initialCount - finalCount) player(s))")
        
        if initialCount == finalCount {
            print("⚠️ Warning: No players were removed from roster")
        }
        
        // Save the updated roster
        try await saveUpdatedRoster(players: players, leagueId: leagueId, teamLogoName: teamLogoName)
    }
    
    private static func saveUpdatedRoster(players: [EditablePlayerData], leagueId: UUID, teamLogoName: String) async throws {
        // Save the entire updated roster using PlayerDataManager
        let playersDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Players")
        
        // Ensure the directory exists
        if !FileManager.default.fileExists(atPath: playersDirectory.path) {
            try FileManager.default.createDirectory(at: playersDirectory, withIntermediateDirectories: true)
        }
        
        let fileURL = playersDirectory.appendingPathComponent("league_\(leagueId.uuidString)_\(teamLogoName).json")
        
        // Encode and save the updated roster
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(players)
        try data.write(to: fileURL)
        
        print("📝 Updated roster saved with \(players.count) players for \(teamLogoName)")
    }
    
    private static func getCurrentRosterSize(leagueId: UUID, teamLogoName: String) async throws -> Int {
        let playerDataManager = PlayerDataManager.shared
        let players = try playerDataManager.loadPlayersFromFile(leagueId: leagueId, teamLogoName: teamLogoName)
        return players.count
    }
    
    private static func addPlayerToFreeAgency(player: EditablePlayerData) async throws {
        print("🏃 Adding \(player.fullName) to free agency")
        print("🔍 Player details: leagueId=\(player.leagueId), teamLogoName=\(player.teamLogoName)")
        
        // Create a modified player for free agency (remove contract, update team)
        var freeAgentPlayer = player
        freeAgentPlayer.contract = nil
        freeAgentPlayer.teamLogoName = "Free Agent"
        freeAgentPlayer.lastModified = Date()
        
        // Load the league's Free Agent team roster
        let playerDataManager = PlayerDataManager.shared
        
        do {
            var existingFreeAgents = try playerDataManager.loadPlayersFromFile(
                leagueId: player.leagueId,
                teamLogoName: "Free Agent"
            )
            
            print("📋 Found existing Free Agent team with \(existingFreeAgents.count) players")
            
            // Check if player already exists (avoid duplicates)
            if !existingFreeAgents.contains(where: {
                $0.firstName == freeAgentPlayer.firstName &&
                $0.lastName == freeAgentPlayer.lastName &&
                $0.number == freeAgentPlayer.number
            }) {
                existingFreeAgents.append(freeAgentPlayer)
                
                // Save updated free agent roster using PlayerDataManager
                try await saveUpdatedRoster(players: existingFreeAgents, leagueId: player.leagueId, teamLogoName: "Free Agent")
                
                print("✅ \(player.fullName) added to free agency (\(existingFreeAgents.count) total free agents)")
            } else {
                print("⚠️ \(player.fullName) already in free agency")
            }
        } catch {
            print("⚠️ Free Agent team not found in league: \(error)")
            print("🔄 Creating new Free Agent team with released player")
            // If Free Agent team doesn't exist, create it with just this player
            let newFreeAgentRoster = [freeAgentPlayer]
            try await saveUpdatedRoster(players: newFreeAgentRoster, leagueId: player.leagueId, teamLogoName: "Free Agent")
            print("✅ Created Free Agent team with \(player.fullName)")
        }
    }
}

// MARK: - Player Release Errors

enum PlayerReleaseError: Error, LocalizedError {
    case playerNotFound
    case contractNotFound
    case releaseNotAllowed
    case saveFailed(String)
    case belowMinimumRoster
    
    var errorDescription: String? {
        switch self {
        case .playerNotFound:
            return "Player not found in team roster"
        case .contractNotFound:
            return "Player contract information not available"
        case .releaseNotAllowed:
            return "Player cannot be released at this time"
        case .saveFailed(let reason):
            return "Failed to process release: \(reason)"
        case .belowMinimumRoster:
            return "Cannot release player: Team would be below minimum roster size"
        }
    }
}

// MARK: - Rookie Contract Structure

struct RookieContract: Codable {
    let totalValue: Int
    let year1: Int
    let year2: Int
    let year3: Int
    let year4: Int
    
    init(totalValue: Int, year1: Int, year2: Int, year3: Int, year4: Int) {
        self.totalValue = totalValue
        self.year1 = year1
        self.year2 = year2
        self.year3 = year3
        self.year4 = year4
    }
} 