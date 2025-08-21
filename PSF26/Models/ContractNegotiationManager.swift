import Foundation

// MARK: - Shared Enums

enum OfferType {
    case high      // Player-friendly, always accepted
    case base      // Fair market value, always accepted
    case low       // Below market, chance of rejection
}

// MARK: - Contract Negotiation Manager

class ContractNegotiationManager {
    
    // MARK: - Contract Negotiation Status
    
    enum NegotiationStatus {
        case available        // Can negotiate
        case lockedInSeason   // Recently signed/restructured, locked until offseason
        case lockedUntilOffseason // Explicitly locked until offseason
        case rejectedOffers   // Rejected all offers, locked until offseason
    }
    
    enum NegotiationType {
        case restructure   // Modify existing contract
        case resign        // New contract for expiring player
        case rejected      // Player rejected all offers (for tracking lockout)
    }
    
    // MARK: - Contract Offers
    
    struct ContractOffer {
        let type: OfferType
        let negotiationType: NegotiationType
        let totalValue: Int
        let yearlyValue: Int
        let contractLength: Int
        let guaranteedMoney: Int
        let description: String
        let acceptanceChance: Double
    }
    
    struct NegotiationResult {
        let accepted: Bool
        let offer: ContractOffer
        let playerResponse: String
        let newContract: PlayerContract?
        let attemptNumber: Int
        let isLastAttempt: Bool
    }
    
    // MARK: - Main Negotiation Functions
    
    static func generateContractOffers(
        player: PlayerData,
        team: LeagueTeam,
        negotiationType: NegotiationType
    ) -> [ContractOffer] {
        
        let baseWorth = calculatePlayerWorth(player: player, team: team)
        let contractLength = calculateOptimalContractLength(player: player, negotiationType: negotiationType)
        
        return [
            generateHighOffer(baseWorth: baseWorth, contractLength: contractLength, negotiationType: negotiationType),
            generateBaseOffer(baseWorth: baseWorth, contractLength: contractLength, negotiationType: negotiationType),
            generateLowOffer(baseWorth: baseWorth, contractLength: contractLength, negotiationType: negotiationType)
        ]
    }
    
    static func negotiateContract(
        offer: ContractOffer,
        player: PlayerData,
        team: LeagueTeam,
        attemptNumber: Int = 1,
        isLastAttempt: Bool = false
    ) -> NegotiationResult {
        
        let acceptanceChance = calculateAcceptanceChance(
            offer: offer,
            player: player,
            team: team
        )
        
        let accepted = Double.random(in: 0...1) <= acceptanceChance
        
        let playerResponse = generatePlayerResponse(
            accepted: accepted,
            offer: offer,
            player: player,
            team: team,
            attemptNumber: attemptNumber,
            isLastAttempt: isLastAttempt
        )
        
        let newContract = accepted ? createContractFromOffer(offer: offer, player: player) : nil
        
        return NegotiationResult(
            accepted: accepted,
            offer: offer,
            playerResponse: playerResponse,
            newContract: newContract,
            attemptNumber: attemptNumber,
            isLastAttempt: isLastAttempt
        )
    }
    
    // MARK: - Player Worth Calculation
    
    private static func calculatePlayerWorth(player: PlayerData, team: LeagueTeam) -> Int {
        // Base calculation using existing salary estimation
        let baseSalary = SalaryCapManager.estimatePlayerSalary(
            overall: player.overall,
            age: player.age,
            position: player.position
        )
        
        // Team performance multiplier
        let teamOverall = calculateTeamOverall(team: team)
        let teamMultiplier = getTeamPerformanceMultiplier(teamOverall: teamOverall)
        
        // Player loyalty/tenure multiplier
        let loyaltyMultiplier = getLoyaltyMultiplier(player: player, team: team)
        
        // Market demand multiplier
        let marketMultiplier = getMarketDemandMultiplier(player: player)
        
        let finalWorth = Double(baseSalary) * teamMultiplier * loyaltyMultiplier * marketMultiplier
        
        return Int(finalWorth)
    }
    
    private static func calculateTeamOverall(team: LeagueTeam) -> Int {
        guard !team.players.isEmpty else { return 75 }
        let totalOverall = team.players.reduce(0) { $0 + $1.overall }
        return totalOverall / team.players.count
    }
    
    private static func getTeamPerformanceMultiplier(teamOverall: Int) -> Double {
        switch teamOverall {
        case 85...: return 1.15    // Elite teams pay premium
        case 80...84: return 1.10  // Good teams pay slightly more
        case 75...79: return 1.00  // Average teams pay market rate
        case 70...74: return 0.95  // Below average teams pay less
        default: return 0.90       // Poor teams struggle to pay
        }
    }
    
    private static func getLoyaltyMultiplier(player: PlayerData, team: LeagueTeam) -> Double {
        // Simulate player loyalty based on age and performance
        // Older players and team favorites get slight discount
        switch player.age {
        case 22...25: return 1.05  // Young players want to prove themselves
        case 26...29: return 1.00  // Prime players at market rate
        case 30...33: return 0.95  // Aging players more flexible
        default: return 0.90       // Veterans take discounts for stability
        }
    }
    
    private static func getMarketDemandMultiplier(player: PlayerData) -> Double {
        // High-demand positions and elite players cost more
        let positionDemand = SalaryCapManager.getPositionMultiplier(position: player.position)
        let performanceDemand = player.overall >= 85 ? 1.1 : (player.overall >= 75 ? 1.0 : 0.95)
        
        return min(1.2, positionDemand * 0.3 + performanceDemand)
    }
    
    // MARK: - Offer Generation
    
    private static func generateHighOffer(
        baseWorth: Int,
        contractLength: Int,
        negotiationType: NegotiationType
    ) -> ContractOffer {
        
        let yearlyValue = Int(Double(baseWorth) * 1.15) // 15% above market
        let totalValue = yearlyValue * contractLength
        let guaranteedMoney = Int(Double(totalValue) * 0.75) // 75% guaranteed - very player friendly
        
        let description = "Premium offer - High salary, strong guarantees"
        
        return ContractOffer(
            type: .high,
            negotiationType: negotiationType,
            totalValue: totalValue,
            yearlyValue: yearlyValue,
            contractLength: contractLength,
            guaranteedMoney: guaranteedMoney,
            description: description,
            acceptanceChance: 1.0 // Always accepted
        )
    }
    
    private static func generateBaseOffer(
        baseWorth: Int,
        contractLength: Int,
        negotiationType: NegotiationType
    ) -> ContractOffer {
        
        let yearlyValue = baseWorth // Market value
        let totalValue = yearlyValue * contractLength
        let guaranteedMoney = Int(Double(totalValue) * 0.45) // 45% guaranteed - fair balance
        
        let description = "Fair market value - Balanced deal"
        
        return ContractOffer(
            type: .base,
            negotiationType: negotiationType,
            totalValue: totalValue,
            yearlyValue: yearlyValue,
            contractLength: contractLength,
            guaranteedMoney: guaranteedMoney,
            description: description,
            acceptanceChance: 1.0 // Always accepted
        )
    }
    
    private static func generateLowOffer(
        baseWorth: Int,
        contractLength: Int,
        negotiationType: NegotiationType
    ) -> ContractOffer {
        
        let yearlyValue = Int(Double(baseWorth) * 0.85) // 15% below market
        let totalValue = yearlyValue * contractLength
        let guaranteedMoney = Int(Double(totalValue) * 0.25) // 25% guaranteed - team friendly
        
        let description = "Team-friendly offer - Lower salary, risk of rejection"
        
        return ContractOffer(
            type: .low,
            negotiationType: negotiationType,
            totalValue: totalValue,
            yearlyValue: yearlyValue,
            contractLength: contractLength,
            guaranteedMoney: guaranteedMoney,
            description: description,
            acceptanceChance: 0.0 // Will be calculated based on factors
        )
    }
    
    // MARK: - Contract Length Calculation
    
    private static func calculateOptimalContractLength(
        player: PlayerData,
        negotiationType: NegotiationType
    ) -> Int {
        
        // Both restructures and re-signings use the same age-based logic
        // This simplifies the system and makes both work similarly
        switch player.age {
        case 22...25: return Int.random(in: 3...4) // Shorter deals for young players (they want to hit FA sooner)
        case 26...29: return Int.random(in: 3...5) // Prime players get medium to long deals
        case 30...33: return Int.random(in: 2...3) // Aging players get shorter deals
        default: return 1 // Veterans get 1-year deals
        }
    }
    
    // MARK: - Acceptance Logic
    
    private static func calculateAcceptanceChance(
        offer: ContractOffer,
        player: PlayerData,
        team: LeagueTeam
    ) -> Double {
        
        // High and base offers are always accepted
        // Make high/base not guaranteed: reflect market uncertainty
        if offer.type == .high { return 0.92 }
        if offer.type == .base { return 0.78 }
        
        // Low offer acceptance based on multiple factors
        var acceptanceChance = 0.35 // Base chance
        
        // Team overall factor
        let teamOverall = calculateTeamOverall(team: team)
        let teamFactor = getTeamAcceptanceFactor(teamOverall: teamOverall)
        acceptanceChance *= teamFactor
        
        // Player overall factor
        let playerFactor = getPlayerAcceptanceFactor(playerOverall: player.overall)
        acceptanceChance *= playerFactor
        
        // Age factor
        let ageFactor = getAgeAcceptanceFactor(age: player.age)
        acceptanceChance *= ageFactor
        
        // Position factor (some positions have more leverage)
        let positionFactor = getPositionAcceptanceFactor(position: player.position)
        acceptanceChance *= positionFactor
        
        // GUARANTEED MONEY FACTOR - This is crucial for player decisions
        let guaranteedFactor = getGuaranteedMoneyFactor(offer: offer)
        acceptanceChance *= guaranteedFactor
        
        // Cap room factor: if team short on cap, player expects concessions
        let capRoom = team.capSpace
        if capRoom < offer.yearlyValue { acceptanceChance *= 0.85 }
        return min(0.97, max(0.03, acceptanceChance))
    }
    
    private static func getGuaranteedMoneyFactor(offer: ContractOffer) -> Double {
        let guaranteedPercentage = Double(offer.guaranteedMoney) / Double(offer.totalValue)
        
        // Players care a lot about guaranteed money
        switch guaranteedPercentage {
        case 0.6...: return 1.4    // High guarantees (60%+) make players more likely to accept
        case 0.4...0.6: return 1.2 // Medium guarantees (40-60%) slightly positive
        case 0.25...0.4: return 1.0 // Low guarantees (25-40%) neutral
        default: return 0.7        // Very low guarantees (<25%) make players hesitant
        }
    }
    
    private static func getTeamAcceptanceFactor(teamOverall: Int) -> Double {
        switch teamOverall {
        case 85...: return 1.3     // Players want to play for elite teams
        case 80...84: return 1.1   // Good teams have appeal
        case 75...79: return 1.0   // Average teams neutral
        case 70...74: return 0.8   // Below average teams less appealing
        default: return 0.6        // Poor teams struggle to retain talent
        }
    }
    
    private static func getPlayerAcceptanceFactor(playerOverall: Int) -> Double {
        switch playerOverall {
        case 85...: return 0.7     // Elite players have more options
        case 80...84: return 0.8   // Good players have some leverage
        case 75...79: return 1.0   // Average players at baseline
        case 70...74: return 1.2   // Below average players more likely to accept
        default: return 1.4        // Poor players grateful for opportunities
        }
    }
    
    private static func getAgeAcceptanceFactor(age: Int) -> Double {
        switch age {
        case 22...25: return 0.8   // Young players want to maximize earnings
        case 26...29: return 0.9   // Prime players still have leverage
        case 30...33: return 1.1   // Aging players more accepting
        default: return 1.3        // Veterans happy for any deal
        }
    }
    
    private static func getPositionAcceptanceFactor(position: String) -> Double {
        switch position {
        case "QB": return 0.6      // QBs have most leverage
        case "LT", "DE", "EDGE": return 0.8  // Premium positions
        case "WR", "CB": return 0.9  // Skill positions
        case "K", "P": return 1.4  // Specialists have less leverage
        default: return 1.0        // Other positions baseline
        }
    }
    
    // MARK: - Player Response Generation
    
    private static func generatePlayerResponse(
        accepted: Bool,
        offer: ContractOffer,
        player: PlayerData,
        team: LeagueTeam,
        attemptNumber: Int,
        isLastAttempt: Bool
    ) -> String {
        
        if accepted {
            let acceptanceResponses = getAcceptanceResponses(offer: offer, player: player, team: team)
            return acceptanceResponses.randomElement() ?? "Sure! I'm excited to sign with this great organization!"
        } else {
            if isLastAttempt {
                let freeAgencyResponses = getFreeAgencyResponses(player: player)
                return freeAgencyResponses.randomElement() ?? "I am going to test free agency this year."
            } else {
                let rejectionResponses = getRejectionResponses(offer: offer, player: player, attemptNumber: attemptNumber)
                return rejectionResponses.randomElement() ?? "I'm not playing for this offer."
            }
        }
    }
    
    private static func getAcceptanceResponses(offer: ContractOffer, player: PlayerData, team: LeagueTeam) -> [String] {
        let teamName = team.name
        
        switch offer.type {
        case .high:
            return [
                "Hell yeah! This is exactly what I was hoping for! Let's win some championships together!",
                "Wow, this offer shows how much \(teamName) values me. I'm all in!",
                "This is incredible! I can't wait to give everything I have for this organization!",
                "Sure! I'm excited to sign with this great organization - this deal is amazing!",
                "This is a dream come true! \(teamName) just became my favorite team!"
            ]
        case .base:
            return [
                "This is a fair deal that works for everyone. Let's get it done!",
                "I appreciate \(teamName) coming to the table with a solid offer. I'm ready to sign!",
                "Sure! I'm excited to sign with this great organization!",
                "This shows mutual respect. I'm happy to continue my career here!",
                "Fair is fair - let's make this official!"
            ]
        case .low:
            return [
                "It's not what I hoped for, but I love this team. Let's do it!",
                "I understand the cap situation. I'm willing to take this deal for \(teamName)!",
                "Sometimes you gotta make sacrifices for the team you believe in.",
                "Sure! I'm excited to sign with this great organization, even if it's not top dollar!",
                "My heart is with \(teamName). This works for me!"
            ]
        }
    }
    
    private static func getRejectionResponses(offer: ContractOffer, player: PlayerData, attemptNumber: Int) -> [String] {
        let baseResponses = [
            "I'm not playing for this offer.",
            "This doesn't reflect my value to the team.",
            "I need something more competitive than this.",
            "My agent says this is way below market value.",
            "I love this team, but I have to look out for my family."
        ]
        
        let attemptSpecificResponses: [String]
        switch attemptNumber {
        case 1:
            attemptSpecificResponses = [
                "Come on, you can do better than that!",
                "I was expecting something more serious from you guys.",
                "This feels like a lowball offer to me."
            ]
        case 2:
            attemptSpecificResponses = [
                "I thought we were making progress, but this still isn't close.",
                "You're getting warmer, but we're not there yet.",
                "I'm starting to wonder if we can make this work."
            ]
        default:
            attemptSpecificResponses = [
                "I'm disappointed we can't find common ground.",
                "This is our last chance to make something work."
            ]
        }
        
        return baseResponses + attemptSpecificResponses
    }
    
    private static func getFreeAgencyResponses(player: PlayerData) -> [String] {
        return [
            "I am going to test free agency this year.",
            "I think it's time for me to explore other opportunities.",
            "We tried, but I need to see what's out there for me.",
            "My agent thinks free agency is the best move for my career right now.",
            "I appreciate everything this organization has done, but I'm going to test the market.",
            "Three strikes and you're out. I'll be entering free agency.",
            "I guess we just couldn't make it work. Time to move on.",
            "I'll always have love for this team, but it's time to see what else is available."
        ]
    }
    
    // MARK: - Contract Creation
    
    private static func createContractFromOffer(
        offer: ContractOffer,
        player: PlayerData
    ) -> PlayerContract {
        
        let yearlyValues = Array(repeating: offer.yearlyValue, count: offer.contractLength)
        
        return PlayerContract(
            isRookieContract: false,
            totalValue: offer.totalValue,
            currentYearSalary: offer.yearlyValue,
            yearlyValues: yearlyValues,
            yearsRemaining: offer.contractLength,
            draftPick: nil,
            hasFifthYearOption: false,
            totalGuaranteed: offer.guaranteedMoney,
            guaranteedAtSigning: Int(Double(offer.guaranteedMoney) * 0.7),
            injuryGuaranteed: Int(Double(offer.guaranteedMoney) * 0.2),
            skillGuaranteed: Int(Double(offer.guaranteedMoney) * 0.1),
            ltbeIncentives: 0,
            ntlbeIncentives: 0,
            rosterBonus: 0,
            optionBonus: 0,
            workoutBonus: 0
        )
    }
    
    // MARK: - Utility Functions
    
    static func getContractTypeDescription(negotiationType: NegotiationType, yearsRemaining: Int) -> String {
        switch negotiationType {
        case .restructure:
            return "Contract Restructure"
        case .resign:
            return "Contract Re-signing"
        case .rejected:
            return "Contract Rejected"
        }
    }
    
    static func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    static func formatContractSummary(offer: ContractOffer) -> String {
        let yearly = formatCurrency(offer.yearlyValue)
        let total = formatCurrency(offer.totalValue)
        let guaranteed = formatCurrency(offer.guaranteedMoney)
        
        return "\(offer.contractLength) years, \(yearly)/year (\(total) total, \(guaranteed) guaranteed)"
    }
    
    // MARK: - Player Negotiation Status Methods
    
    static func canPlayerNegotiate(
        player: PlayerData,
        currentSeason: Int,
        currentWeek: Int
    ) -> NegotiationStatus {
        // For now, return available - this can be enhanced later with actual tracking
        return .available
    }
    
    static func getNegotiationStatusMessage(
        player: PlayerData,
        currentSeason: Int,
        currentWeek: Int
    ) -> String? {
        // Check negotiation status first
        let status = canPlayerNegotiate(player: player, currentSeason: currentSeason, currentWeek: currentWeek)
        
        switch status {
        case .available:
            return nil
        case .lockedInSeason:
            return "Player recently signed/restructured - locked until offseason"
        case .lockedUntilOffseason:
            return "Player locked from negotiations until offseason"
        case .rejectedOffers:
            return "Player rejected all offers - locked until offseason"
        }
    }
    
    static func saveContractToPlayer(
        player: PlayerData,
        contract: PlayerContract,
        leagueId: UUID,
        teamLogoName: String,
        currentSeason: Int,
        negotiationType: NegotiationType
    ) async throws {
        // Load the player's editable data
        let players = try PlayerDataManager.shared.loadPlayersFromFile(
            leagueId: leagueId,
            teamLogoName: teamLogoName
        )
        
        // Find and update the player
        var updatedPlayers = players
        let playerId = "\(player.firstName)_\(player.lastName)_\(player.number)"
        
        for i in 0..<updatedPlayers.count {
            let currentPlayer = updatedPlayers[i]
            if "\(currentPlayer.firstName)_\(currentPlayer.lastName)_\(currentPlayer.number)" == playerId {
                updatedPlayers[i].contract = contract
                updatedPlayers[i].salary = contract.currentYearSalary
                updatedPlayers[i].contractYearsLeft = contract.yearsRemaining
                updatedPlayers[i].lastModified = Date()
                break
            }
        }
        
        // Save the updated players
        let playersDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Players")
        let fileURL = playersDirectory.appendingPathComponent("league_\(leagueId.uuidString)_\(teamLogoName).json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(updatedPlayers)
        try data.write(to: fileURL)
        
        print("✅ Contract saved for player: \(playerId)")
    }
    
    static func recordContractRejection(
        player: PlayerData,
        season: Int,
        originalNegotiationType: NegotiationType
    ) {
        // For now, just log the rejection - this can be enhanced later with actual tracking
        let playerId = "\(player.firstName)_\(player.lastName)_\(player.number)"
        print("📝 Contract rejection recorded for player: \(playerId) in season \(season)")
    }
}

// MARK: - Free Agent Signing Manager

class FreeAgentSigningManager {
    
    // MARK: - NFL Minimum Salary Rules (2025)
    
    private static func getNFLMinimumSalary(yearsOfExperience: Int) -> Int {
        switch yearsOfExperience {
        case 0: return 840_000    // Rookie
        case 1: return 960_000    // 1 Year
        case 2: return 1_030_000  // 2 Years
        case 3: return 1_100_000  // 3 Years
        case 4...6: return 1_170_000  // 4-6 Years
        default: return 1_255_000     // 7+ Years
        }
    }
    
    // MARK: - Free Agent Contract Offers
    
    struct FreeAgentOffer {
        let type: OfferType
        let totalValue: Int
        let yearlyValue: Int
        let contractLength: Int
        let guaranteedMoney: Int
        let description: String
        let acceptanceChance: Double
    }
    
    struct SigningResult {
        let accepted: Bool
        let offer: FreeAgentOffer
        let playerResponse: String
        let newContract: PlayerContract?
    }
    
    // MARK: - Generate Free Agent Offers
    
    static func generateFreeAgentOffers(player: PlayerData, signingTeam: LeagueTeam) -> [FreeAgentOffer] {
        let yearsOfExperience = max(0, player.age - 22)
        let minimumSalary = getNFLMinimumSalary(yearsOfExperience: yearsOfExperience)
        let marketValue = SalaryCapManager.estimatePlayerSalary(
            overall: player.overall,
            age: player.age,
            position: player.position
        )
        
        var offers: [FreeAgentOffer] = []
        
        // Calculate all salary levels first
        let belowMarketSalary = max(minimumSalary, Int(Double(marketValue) * 0.75))
        let playerFriendlySalary = max(belowMarketSalary, Int(Double(marketValue) * 1.15))
        
        // Offer 1: Player-Friendly (Highest Money)
        let playerFriendlyOffer = FreeAgentOffer(
            type: .high,
            totalValue: playerFriendlySalary * 4, // 4-year deal
            yearlyValue: playerFriendlySalary,
            contractLength: 4,
            guaranteedMoney: playerFriendlySalary * 3, // Three years guaranteed
            description: "Player-friendly offer - above market value",
            acceptanceChance: 0.95
        )
        offers.append(playerFriendlyOffer)
        
        // Offer 2: Below Market Value (Middle Money)
        let belowMarketOffer = FreeAgentOffer(
            type: .base,
            totalValue: belowMarketSalary * 3, // 3-year deal
            yearlyValue: belowMarketSalary,
            contractLength: 3,
            guaranteedMoney: belowMarketSalary * 2, // Two years guaranteed
            description: "Below market value - competitive offer",
            acceptanceChance: 0.7
        )
        offers.append(belowMarketOffer)
        
        // Offer 3: League Minimum (Lowest Money)
        let minimumOffer = FreeAgentOffer(
            type: .low,
            totalValue: minimumSalary * 2, // 2-year minimum deal
            yearlyValue: minimumSalary,
            contractLength: 2,
            guaranteedMoney: minimumSalary, // First year guaranteed
            description: "League minimum salary - \(yearsOfExperience) year(s) experience",
            acceptanceChance: 0.3 // Low chance unless desperate
        )
        offers.append(minimumOffer)
        
        return offers
    }
    
    // MARK: - Process Free Agent Signing
    
    static func processFreAgentSigning(
        offer: FreeAgentOffer,
        player: PlayerData,
        signingTeam: LeagueTeam
    ) -> SigningResult {
        let accepted = Double.random(in: 0...1) <= offer.acceptanceChance
        
        let playerResponse = generateFreeAgentResponse(
            accepted: accepted,
            offer: offer,
            player: player,
            team: signingTeam
        )
        
        let newContract = accepted ? createFreeAgentContract(offer: offer, player: player) : nil
        
        return SigningResult(
            accepted: accepted,
            offer: offer,
            playerResponse: playerResponse,
            newContract: newContract
        )
    }
    
    // MARK: - Helper Methods
    
    private static func generateFreeAgentResponse(
        accepted: Bool,
        offer: FreeAgentOffer,
        player: PlayerData,
        team: LeagueTeam
    ) -> String {
        if accepted {
            let responses = [
                "I'm excited to join \(team.name) and contribute to the team's success!",
                "This is a great opportunity and I can't wait to get started with \(team.name).",
                "I believe \(team.name) is the right fit for me and my career goals.",
                "Looking forward to bringing my skills to \(team.name) and helping the team win.",
                "I'm ready to give my all for \(team.name) and the fans!"
            ]
            return responses.randomElement() ?? "I'm excited to join the team!"
        } else {
            let responses = [
                "I appreciate the offer, but I'm looking for something that better fits my value.",
                "Thank you for the interest, but I'll be exploring other opportunities.",
                "I need to consider all my options before making a decision.",
                "The offer doesn't quite meet my expectations at this time.",
                "I'm grateful for the opportunity, but I'll be looking elsewhere."
            ]
            return responses.randomElement() ?? "Thank you for the offer, but I'll pass."
        }
    }
    
    private static func createFreeAgentContract(offer: FreeAgentOffer, player: PlayerData) -> PlayerContract {
        // Create yearly salary breakdown
        var yearlyValues: [Int] = []
        for _ in 0..<offer.contractLength {
            yearlyValues.append(offer.yearlyValue)
        }
        
        return PlayerContract(
            isRookieContract: false,
            totalValue: offer.totalValue,
            currentYearSalary: offer.yearlyValue,
            yearlyValues: yearlyValues,
            yearsRemaining: offer.contractLength,
            draftPick: nil,
            hasFifthYearOption: false,
            totalGuaranteed: offer.guaranteedMoney,
            guaranteedAtSigning: offer.guaranteedMoney,
            injuryGuaranteed: 0,
            skillGuaranteed: 0,
            signingBonus: Int(Double(offer.guaranteedMoney) * 0.3), // 30% signing bonus
            hasOffsetLanguage: offer.type != .high // High offers don't have offset language
        )
    }
    
    // MARK: - Utility Functions
    
    static func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
} 