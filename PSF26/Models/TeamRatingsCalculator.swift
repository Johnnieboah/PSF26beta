import Foundation

// MARK: - Team Ratings Calculator (shared)
// Centralizes OFF/DEF/OVR calculation so every view shows the same numbers.
// Uses the same weighting/normalization heuristics we use in roster/team views.

struct TeamRatingsCalculator {
    /// Calculate offense/defense/overall for a team from PlayerData array.
    /// - Parameters:
    ///   - teamLogoName: Short team key (e.g., "Chicago", "Minnesota"). Used for small team-strength nudges.
    ///   - players: The roster to evaluate (typically 53 or 60).
    /// - Returns: (offense, defense, overall)
    static func calculateTeamOveralls(for teamLogoName: String, players: [PlayerData]) -> (offense: Int, defense: Int, overall: Int) {
        let offensivePositions = ["QB", "RB", "FB", "WR", "TE", "LT", "LG", "C", "RG", "RT"]
        let defensivePositions = ["MLB", "ROLB", "LOLB", "EDGE", "DE", "DT", "CB", "SS", "FS"]

        let offensivePlayers = players.filter { offensivePositions.contains($0.position) }
        let defensivePlayers = players.filter { defensivePositions.contains($0.position) }

        let rawOffenseRating = calculateEnhancedUnitRating(players: offensivePlayers, isOffense: true)
        let rawDefenseRating = calculateEnhancedUnitRating(players: defensivePlayers, isOffense: false)

        let offenseOverall = normalizeUnitRating(Double(rawOffenseRating), players: offensivePlayers, teamName: teamLogoName)
        let defenseOverall = normalizeUnitRating(Double(rawDefenseRating), players: defensivePlayers, teamName: teamLogoName)

        // Special Teams (light influence in overall)
        let specialTeamsPlayers = players.filter { ["K", "P"].contains($0.position) }
        let specialTeamsRating = calculateSpecialTeamsRating(players: specialTeamsPlayers)

        let rawTeamRating = (Double(offenseOverall) * 0.45) + (Double(defenseOverall) * 0.45) + (specialTeamsRating * 0.10)
        let teamOverall = Int(round(rawTeamRating))

        return (offenseOverall, defenseOverall, teamOverall)
    }

    // MARK: - Internal helpers (copied from roster calculations to keep results identical)

    private static func normalizeUnitRating(_ rawRating: Double, players: [PlayerData], teamName: String) -> Int {
        let minUnitRating = 70.0
        let maxUnitRating = 95.0

        let sortedPlayers = players.sorted { $0.overall > $1.overall }
        let topPlayers = Array(sortedPlayers.prefix(min(8, sortedPlayers.count)))
        let topPlayerAverage = topPlayers.isEmpty ? rawRating : Double(topPlayers.map { $0.overall }.reduce(0, +)) / Double(topPlayers.count)

        let enhancedRating = (rawRating * 0.6) + (topPlayerAverage * 0.4)
        let teamAdjustment = getTeamStrengthAdjustment(teamName: teamName)
        let adjustedRating = enhancedRating + teamAdjustment

        let strengthMultiplier = calculateStrengthMultiplier(enhancedRating: adjustedRating)
        let amplifiedRating = adjustedRating * strengthMultiplier

        let normalizedValue = (amplifiedRating - 60.0) / 35.0
        let clampedValue = max(0.0, min(1.0, normalizedValue))
        let finalRating = minUnitRating + (clampedValue * (maxUnitRating - minUnitRating))
        return Int(round(finalRating))
    }

    private static func calculateStrengthMultiplier(enhancedRating: Double) -> Double {
        if enhancedRating >= 85 { return 1.15 }
        else if enhancedRating >= 80 { return 1.08 }
        else if enhancedRating >= 75 { return 1.02 }
        else if enhancedRating >= 70 { return 0.95 }
        else { return 0.88 }
    }

    private static func calculateSpecialTeamsRating(players: [PlayerData]) -> Double {
        guard !players.isEmpty else { return 78.0 }
        let avg = Double(players.map { $0.overall }.reduce(0, +)) / Double(players.count)
        return max(70.0, min(92.0, avg))
    }

    private static func calculateEnhancedUnitRating(players: [PlayerData], isOffense: Bool) -> Int {
        guard !players.isEmpty else { return 75 }
        let positionWeights: [String: Double] = isOffense ? [
            "QB": 4.5,
            "LT": 2.5, "RT": 2.2,
            "WR": 2.0,
            "RB": 1.8,
            "TE": 1.5,
            "C": 1.4,
            "LG": 1.2, "RG": 1.2,
            "FB": 0.9
        ] : [
            "CB": 2.5,
            "EDGE": 2.3,
            "MLB": 2.0,
            "DE": 1.8,
            "SS": 1.6, "FS": 1.6,
            "DT": 1.5,
            "ROLB": 1.4, "LOLB": 1.4
        ]

        let playersByPosition = Dictionary(grouping: players) { $0.position }
        var weightedSum = 0.0
        var totalWeight = 0.0

        for (position, positionPlayers) in playersByPosition {
            let weight = positionWeights[position] ?? 1.0
            let sortedPlayers = positionPlayers.sorted { $0.overall > $1.overall }
            let playersToConsider = Array(sortedPlayers.prefix(min(3, sortedPlayers.count)))

            for (index, player) in playersToConsider.enumerated() {
                let depthMultiplier = index == 0 ? 1.0 : (index == 1 ? 0.6 : 0.3)
                let playerWeight = weight * depthMultiplier
                weightedSum += Double(player.overall) * playerWeight
                totalWeight += playerWeight
            }
        }

        guard totalWeight > 0 else { return 75 }
        let weightedAverage = weightedSum / totalWeight
        return Int(round(weightedAverage))
    }

    private static func getTeamStrengthAdjustment(teamName: String) -> Double {
        switch teamName {
        case "Philadelphia": return 12.0
        case "KansasCity": return 11.0
        case "Buffalo": return 10.0
        case "SanFrancisco": return 9.5
        case "Baltimore": return 8.5
        case "Cincinnati": return 8.0
        case "Miami": return 7.0
        case "Dallas": return 6.5
        case "Detroit": return 6.0
        case "GreenBay": return 5.0
        case "Seattle": return 4.5
        case "Minnesota": return 4.0
        case "LAN": return 3.5
        case "Jacksonville": return 3.0
        case "Pittsburgh": return 2.0
        case "Cleveland": return 1.5
        case "Indianapolis": return 0.5
        case "Atlanta": return 0.0
        case "TampaBay": return -0.5
        case "LasVegas": return -1.0
        case "LAA": return -1.5
        case "NewOrleans": return -2.0
        case "NYN": return -2.5
        case "Houston": return -3.5
        case "Tennessee": return -4.0
        case "NYA": return -4.5
        case "Denver": return -5.0
        case "NewEngland": return -5.5
        case "Washington": return -6.0
        case "Chicago": return -7.0
        case "Carolina": return -8.0
        case "Arizona": return -9.0
        default: return 0.0
        }
    }
}


