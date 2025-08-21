import Foundation
import SwiftUI

// MARK: - Supporting Enums
enum Conference: String, CaseIterable {
    case afc = "ACFT"
    case nfc = "NCFT"
}

enum Division: String, CaseIterable {
    case afcEast = "AFC East"
    case afcNorth = "AFC North"
    case afcSouth = "AFC South"
    case afcWest = "AFC West"
    case nfcEast = "NFC East"
    case nfcNorth = "NFC North"
    case nfcSouth = "NFC South"
    case nfcWest = "NFC West"
}

// MARK: - Team Setup Manager
// Extracted from LeagueManager to handle team creation and setup operations
@MainActor
class TeamSetupManager {
    
    // MARK: - Team Creation
    static func createAllTeams(leagueId: UUID?, isTrainingCamp: Bool) -> [LeagueTeam] {
        _ = MasterDataLoader.shared  // Available for future use if needed
        var allTeams: [LeagueTeam] = []
        
        // Create teams for all NFL franchises
        let teamNames = [
            "Arizona", "Atlanta", "Baltimore", "Buffalo", "Carolina", "Chicago",
            "Cincinnati", "Cleveland", "Dallas", "Denver", "Detroit", "GreenBay",
            "Houston", "Indianapolis", "Jacksonville", "KansasCity", "LasVegas",
            "LAA", "LAN", "Miami", "Minnesota", "NewEngland", "NewOrleans",
            "NYN", "NYA", "Philadelphia", "Pittsburgh", "SanFrancisco",
            "Seattle", "TampaBay", "Tennessee", "Washington"
        ]
        
        for teamName in teamNames {
            let teamData = TeamData.createTeamFromData(name: teamName, leagueId: leagueId, isTrainingCamp: isTrainingCamp)
            let coach = generateCoachForTeam(teamName: teamName)
            let colors = TeamColorMapping.getColors(for: teamName)
            
            let team = LeagueTeam(
                logoName: teamName,
                name: TeamData.getTeamDisplayName(teamName),
                conference: getProperConference(for: teamName).rawValue,
                division: getProperDivision(for: teamName).rawValue,
                primaryColor: colors.primary,
                secondaryColor: colors.secondary,
                players: teamData.players,
                overallRating: calculateTeamOverall(players: teamData.players, teamName: teamName),
                coach: coach
            )
            
            allTeams.append(team)
        }
        
        return allTeams
    }
    
    // MARK: - Coach Generation
    static func generateCoachForTeam(teamName: String) -> Coach {
        // Coach experience data based on real 2025 NFL coaches (names randomized)
        let coachData: [String: (firstName: String, lastName: String, experience: Int)] = [
            "Arizona": ("Marcus", "Thompson", 2),
            "Atlanta": ("Derek", "Williams", 1),
            "Baltimore": ("Robert", "Mitchell", 17),
            "Buffalo": ("Tyler", "Anderson", 8),
            "Carolina": ("Jason", "Rodriguez", 1),
            "Chicago": ("Trevor", "Hayes", 0),
            "Cincinnati": ("Nathan", "Cooper", 6),
            "Cleveland": ("Brandon", "Parker", 5),
            "Dallas": ("Cameron", "Foster", 0),
            "Denver": ("Vincent", "Murphy", 2),
            "Detroit": ("Gregory", "Bennett", 4),
            "GreenBay": ("Austin", "Reed", 6),
            "Houston": ("Darius", "Coleman", 2),
            "Indianapolis": ("Garrett", "Brooks", 2),
            "Jacksonville": ("Ethan", "Sullivan", 0),
            "KansasCity": ("Raymond", "Peterson", 12),
            "LasVegas": ("Douglas", "Graham", 0),
            "LAA": ("Bradley", "Watson", 1),
            "LAN": ("Caleb", "Hughes", 8),
            "Miami": ("Preston", "Sanders", 3),
            "Minnesota": ("Tristan", "Price", 3),
            "NewEngland": ("Curtis", "Barnes", 0),
            "NewOrleans": ("Adrian", "Ross", 0),
            "NYN": ("Spencer", "Kelly", 3),
            "NYA": ("Dominic", "Rivera", 0),
            "Philadelphia": ("Landon", "Torres", 4),
            "Pittsburgh": ("Marshall", "Evans", 18),
            "SanFrancisco": ("Colton", "Stewart", 8),
            "Seattle": ("Phillip", "Morgan", 1),
            "TampaBay": ("Maxwell", "Bailey", 3),
            "Tennessee": ("Donovan", "Carter", 1),
            "Washington": ("Sterling", "Phillips", 1)
        ]
        
        let coach = coachData[teamName] ?? ("Alex", "Johnson", 5)
        let rating = getCoachRating(for: teamName)
        
        let offensiveSchemes = [
            "West Coast", "Air Raid", "Spread", "Pro Style", "Run-Heavy", "RPO", "Vertical", "Smashmouth"
        ]
        
        let defensiveSchemes = [
            "4-3 Base", "3-4 Base", "Nickel", "4-2-5", "3-3-5", "Cover 2", "Cover 3", "Tampa 2"
        ]
        
        let offensiveScheme = offensiveSchemes.randomElement() ?? "Pro Style"
        let defensiveScheme = defensiveSchemes.randomElement() ?? "4-3 Base"
        
        return Coach(
            firstName: coach.firstName,
            lastName: coach.lastName,
            overallRating: rating,
            offensiveScheme: offensiveScheme,
            defensiveScheme: defensiveScheme,
            experience: coach.experience,
            offensiveCoordinator: generateOffensiveCoordinator(),
            defensiveCoordinator: generateDefensiveCoordinator()
        )
    }
    
    // MARK: - Team Overall Calculation (Classic starter-based method; top 53 basis)
    static func calculateTeamOverall(players: [PlayerData], teamName: String) -> Int {
        guard !players.isEmpty else { return 75 }
        // Consider top 53 only to reflect active roster strength
        let top53 = Array(players.sorted { $0.overall > $1.overall }.prefix(53))

        // Offense components
        let qb = top53.filter { $0.position == "QB" }.sorted { $0.overall > $1.overall }.first?.overall
        let hb = top53.filter { $0.position == "RB" }.sorted { $0.overall > $1.overall }.first?.overall
        let wrs = top53.filter { $0.position == "WR" }.sorted { $0.overall > $1.overall }.prefix(3).map { $0.overall }
        let te = top53.filter { $0.position == "TE" }.sorted { $0.overall > $1.overall }.first?.overall
        let olPositions = ["LT","LG","C","RG","RT"]
        let ol = olPositions.compactMap { pos in top53.filter { $0.position == pos }.sorted { $0.overall > $1.overall }.first?.overall }

        let wrAvg = wrs.isEmpty ? nil : Double(wrs.reduce(0,+)) / Double(wrs.count)
        let olAvg = ol.count == 0 ? nil : Double(ol.reduce(0,+)) / Double(ol.count)
        let offenseBuckets = [qb, hb, te].compactMap { $0 }.map { Double($0) } + [wrAvg, olAvg].compactMap { $0 }
        let offenseAvg = offenseBuckets.isEmpty ? 75.0 : offenseBuckets.reduce(0,+) / Double(offenseBuckets.count)

        // Defense components
        // DL: take top 4 among DE/DT/EDGE
        let dlPool = top53.filter { ["DE","DT","EDGE"].contains($0.position) }.sorted { $0.overall > $1.overall }.prefix(4).map { $0.overall }
        let dlAvg = dlPool.isEmpty ? nil : Double(dlPool.reduce(0,+)) / Double(dlPool.count)
        // LB: take top 3 among MLB/ROLB/LOLB
        let lbPool = top53.filter { ["MLB","ROLB","LOLB"].contains($0.position) }.sorted { $0.overall > $1.overall }.prefix(3).map { $0.overall }
        let lbAvg = lbPool.isEmpty ? nil : Double(lbPool.reduce(0,+)) / Double(lbPool.count)
        // DB: 2 CB + FS + SS (pick best two CBs; best FS; best SS)
        let cbs = top53.filter { $0.position == "CB" }.sorted { $0.overall > $1.overall }.prefix(2).map { $0.overall }
        let fs = top53.filter { $0.position == "FS" }.sorted { $0.overall > $1.overall }.first?.overall
        let ss = top53.filter { $0.position == "SS" }.sorted { $0.overall > $1.overall }.first?.overall
        let dbParts = cbs + [fs, ss].compactMap { $0 }
        let dbAvg = dbParts.isEmpty ? nil : Double(dbParts.reduce(0,+)) / Double(dbParts.count)

        let defenseBuckets = [dlAvg, lbAvg, dbAvg].compactMap { $0 }
        let defenseAvg = defenseBuckets.isEmpty ? 75.0 : defenseBuckets.reduce(0,+) / Double(defenseBuckets.count)

        // Special teams: best K and best P average
        let k = top53.filter { $0.position == "K" }.sorted { $0.overall > $1.overall }.first?.overall
        let p = top53.filter { $0.position == "P" }.sorted { $0.overall > $1.overall }.first?.overall
        let stParts = [k, p].compactMap { $0 }
        let stAvg = stParts.isEmpty ? 75.0 : Double(stParts.reduce(0,+)) / Double(stParts.count)

        // Combine with 45/45/10 weighting
        let rawTeamRating = (offenseAvg * 0.45) + (defenseAvg * 0.45) + (stAvg * 0.10)
        let normalizedRating = normalizeTeamRating(rawTeamRating, allPlayers: top53, teamName: teamName)
        return normalizedRating
    }
    
    // MARK: - Conference and Division
    static func getProperConference(for teamLogoName: String) -> Conference {
        switch teamLogoName {
        case "Buffalo", "Miami", "NewEngland", "NYA": return .afc
        case "Baltimore", "Cincinnati", "Cleveland", "Pittsburgh": return .afc
        case "Houston", "Indianapolis", "Jacksonville", "Tennessee": return .afc
        case "Denver", "KansasCity", "LasVegas", "LAA": return .afc
        case "Dallas", "NYN", "Philadelphia", "Washington": return .nfc
        case "Chicago", "Detroit", "GreenBay", "Minnesota": return .nfc
        case "Atlanta", "Carolina", "NewOrleans", "TampaBay": return .nfc
        case "Arizona", "LAN", "SanFrancisco", "Seattle": return .nfc
        default: return .afc
        }
    }
    
    static func getProperDivision(for teamLogoName: String) -> Division {
        switch teamLogoName {
        case "Buffalo", "Miami", "NewEngland", "NYA": return .afcEast
        case "Baltimore", "Cincinnati", "Cleveland", "Pittsburgh": return .afcNorth
        case "Houston", "Indianapolis", "Jacksonville", "Tennessee": return .afcSouth
        case "Denver", "KansasCity", "LasVegas", "LAA": return .afcWest
        case "Dallas", "NYN", "Philadelphia", "Washington": return .nfcEast
        case "Chicago", "Detroit", "GreenBay", "Minnesota": return .nfcNorth
        case "Atlanta", "Carolina", "NewOrleans", "TampaBay": return .nfcSouth
        case "Arizona", "LAN", "SanFrancisco", "Seattle": return .nfcWest
        default: return .afcEast
        }
    }
    
    // MARK: - Team Roster Management
    static func recalculateAllTeamOveralls(teams: inout [LeagueTeam]) {
        // Note: overallRating is a let constant, so we need to recreate teams with updated ratings
        for i in 0..<teams.count {
            let currentTeam = teams[i]
            let newOverallRating = calculateTeamOverall(players: currentTeam.players, teamName: currentTeam.logoName)
            
            // Only recreate if rating changed
            if newOverallRating != currentTeam.overallRating {
                let newTeam = LeagueTeam(
                    logoName: currentTeam.logoName,
                    name: currentTeam.name,
                    conference: currentTeam.conference,
                    division: currentTeam.division,
                    primaryColor: currentTeam.primaryColor,
                    secondaryColor: currentTeam.secondaryColor,
                    players: currentTeam.players,
                    overallRating: newOverallRating,
                    coach: currentTeam.coach
                )
                // Preserve record and other mutable properties
                var updatedTeam = newTeam
                updatedTeam.record = currentTeam.record
                updatedTeam.divisionRank = currentTeam.divisionRank
                teams[i] = updatedTeam
            }
        }
    }
    
    // MARK: - Training Camp
    static func canUserTeamAdvanceFromTrainingCamp(userTeam: LeagueTeam?) -> (canAdvance: Bool, issues: [String]) {
        guard let userTeam = userTeam else {
            return (false, ["No user team found"])
        }
        
        var issues: [String] = []
        
        // Check roster size (should be around 53 players)
        if userTeam.players.count > 60 {
            issues.append("Roster too large (\(userTeam.players.count)/53). Cut \(userTeam.players.count - 53) players.")
        } else if userTeam.players.count < 45 {
            issues.append("Roster too small (\(userTeam.players.count)/53). Need at least 45 players.")
        }
        
        // Check for required positions
        let requiredPositions = ["QB", "RB", "WR", "TE", "LT", "LG", "C", "RG", "RT"]
        for position in requiredPositions {
            let playersAtPosition = userTeam.players.filter { $0.position == position }
            if playersAtPosition.isEmpty {
                issues.append("No players at \(position)")
            }
        }
        
        return (issues.isEmpty, issues)
    }
    
    static func executeAITeamTrainingCampCuts(teams: inout [LeagueTeam], userTeamLogoName: String?) {
        for i in 0..<teams.count {
            // Skip user team
            if let userTeam = userTeamLogoName, teams[i].logoName == userTeam { continue }
            
            // Simple AI GM: sign from Free Agents to reach 53, cut lowest OVR to 53 if over
            var team = teams[i]
            if team.players.count < 53 {
                // Pull best-fitting free agents
                var needed = 53 - team.players.count
                let faPlayers = PlayerDataManager.shared.getPlayers(for: "Free Agent", leagueId: nil)
                    .sorted { $0.overall > $1.overall }
                var additions: [PlayerData] = []
                for fa in faPlayers {
                    guard needed > 0 else { break }
                    // Avoid duplicates by number/position/name
                    if !team.players.contains(where: { $0.firstName == fa.firstName && $0.lastName == fa.lastName && $0.number == fa.number }) {
                        additions.append(fa)
                        needed -= 1
                    }
                }
                team.players.append(contentsOf: additions)
            } else if team.players.count > 53 {
                let sorted = team.players.sorted { $0.overall > $1.overall }
                team.players = Array(sorted.prefix(53))
            }
            teams[i] = team
        }
    }
    
    static func validateAndAdjustTrainingCampRosters(teams: inout [LeagueTeam]) {
        for i in 0..<teams.count {
            // Do not auto-inflate or trim imported rosters. Respect CSV roster size.
            _ = teams[i].players.count
        }
    }
    
    // MARK: - Private Helper Functions
    private static func calculateUnitRating(players: [PlayerData], isOffense: Bool) -> Double {
        guard !players.isEmpty else { return 70.0 }
        
        let positionWeights: [String: Double] = isOffense ? [
            "QB": 4.5, "LT": 2.5, "RT": 2.2, "WR": 2.0, "RB": 1.8,
            "TE": 1.5, "C": 1.4, "LG": 1.2, "RG": 1.2, "FB": 0.9
        ] : [
            "CB": 2.5, "EDGE": 2.3, "MLB": 2.0, "DE": 1.8, "SS": 1.6,
            "FS": 1.6, "DT": 1.5, "ROLB": 1.4, "LOLB": 1.4
        ]
        
        let playersByPosition = Dictionary(grouping: players) { $0.position }
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        for (position, positionPlayers) in playersByPosition {
            let weight = positionWeights[position] ?? 1.0
            let sortedPlayers = positionPlayers.sorted { $0.overall > $1.overall }
            let depthToConsider = min(3, sortedPlayers.count)
            
            for (index, player) in sortedPlayers.prefix(depthToConsider).enumerated() {
                let depthMultiplier = index == 0 ? 1.0 : (index == 1 ? 0.5 : 0.25)
                let playerWeight = weight * depthMultiplier
                weightedSum += Double(player.overall) * playerWeight
                totalWeight += playerWeight
            }
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : 75.0
    }
    
    private static func calculateSpecialTeamsRating(players: [PlayerData]) -> Double {
        guard !players.isEmpty else { return 75.0 }
        
        let kickers = players.filter { $0.position == "K" }
        let punters = players.filter { $0.position == "P" }
        
        let kRating = kickers.isEmpty ? 75.0 : Double(kickers.max(by: { $0.overall < $1.overall })?.overall ?? 75)
        let pRating = punters.isEmpty ? 75.0 : Double(punters.max(by: { $0.overall < $1.overall })?.overall ?? 75)
        
        return (kRating + pRating) / 2.0
    }
    
    private static func normalizeTeamRating(_ rawRating: Double, allPlayers: [PlayerData], teamName: String) -> Int {
        // Team-specific adjustments based on recent performance
        let teamAdjustments: [String: Double] = [
            "Buffalo": 2.0, "KansasCity": 3.0, "Baltimore": 2.5,
            "Detroit": 1.5, "SanFrancisco": 1.0, "Dallas": 1.0,
            "Miami": 0.5, "Philadelphia": 0.5, "Minnesota": 0.0,
            "Chicago": -2.0, "Carolina": -1.5, "Arizona": -1.0
        ]
        
        let adjustment = teamAdjustments[teamName] ?? 0.0
        let adjustedRating = rawRating + adjustment
        
        // Normalize to 70-90 range
        let normalizedRating = max(70, min(90, Int(round(adjustedRating))))
        return normalizedRating
    }
    
    private static func getCoachRating(for teamName: String) -> Int {
        let coachRatings: [String: Int] = [
            "KansasCity": 95, "Baltimore": 92, "Pittsburgh": 90, "Buffalo": 88,
            "SanFrancisco": 87, "GreenBay": 85, "Philadelphia": 84, "Detroit": 83,
            "Miami": 82, "Cincinnati": 81, "Dallas": 80, "Minnesota": 79,
            "LAN": 78, "Seattle": 77, "Houston": 76, "TampaBay": 75,
            "Indianapolis": 74, "Atlanta": 73, "Cleveland": 72, "Denver": 71,
            "LasVegas": 70, "NewOrleans": 69, "NYN": 68, "Arizona": 67,
            "Tennessee": 66, "Washington": 65, "JAcksonville": 64, "NYA": 63,
            "NewEngland": 62, "Carolina": 61, "Chicago": 60, "LAA": 59
        ]
        
        return coachRatings[teamName] ?? 75
    }
    
    private static func generateOffensiveCoordinator() -> OffensiveCoordinator {
        let firstNames = ["Mike", "Josh", "Brian", "Kyle", "Sean", "Matt", "Doug", "Eric"]
        let lastNames = ["Johnson", "Smith", "Williams", "Brown", "Davis", "Miller", "Wilson", "Moore"]
        
        return OffensiveCoordinator(
            firstName: firstNames.randomElement() ?? "Mike",
            lastName: lastNames.randomElement() ?? "Johnson",
            overallRating: Int.random(in: 70...85),
            offensiveScheme: ["West Coast", "Air Raid", "Pro Style"].randomElement() ?? "Pro Style",
            experience: Int.random(in: 3...15)
        )
    }
    
    private static func generateDefensiveCoordinator() -> DefensiveCoordinator {
        let firstNames = ["Dan", "Wade", "Vic", "Rex", "Jim", "Todd", "Steve", "Jack"]
        let lastNames = ["Quinn", "Phillips", "Fangio", "Ryan", "Schwartz", "Bowles", "Spagnuolo", "Del Rio"]
        
        return DefensiveCoordinator(
            firstName: firstNames.randomElement() ?? "Dan",
            lastName: lastNames.randomElement() ?? "Quinn",
            overallRating: Int.random(in: 70...85),
            defensiveScheme: ["4-3 Base", "3-4 Base", "Nickel"].randomElement() ?? "4-3 Base",
            experience: Int.random(in: 3...15)
        )
    }
    
    private static func generatePracticeSquadPlayers(count: Int, teamName: String) -> [PlayerData] {
        var players: [PlayerData] = []
        let positions = ["QB", "RB", "WR", "TE", "LT", "LG", "C", "RG", "RT", "EDGE", "DT", "MLB", "CB", "SS", "FS"]
        
        for _ in 0..<count {
            let position = positions.randomElement() ?? "WR"
            let player = PlayerData(
                firstName: "Practice",
                lastName: "Squad",
                position: position,
                number: Int.random(in: 1...99),
                overall: Int.random(in: 55...70),
                age: Int.random(in: 22...26),
                height: 72 // 6'0" in inches
            )
            players.append(player)
        }
        
        return players
    }
}
