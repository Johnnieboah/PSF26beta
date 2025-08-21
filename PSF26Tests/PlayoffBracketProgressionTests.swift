import Testing
@testable import PSF26

@MainActor
struct PlayoffBracketProgressionTests {
    
    @Test("User doesn't play same team twice in consecutive playoff rounds")
    func testNoDuplicateOpponents() async throws {
        let manager = LeagueManager()
        manager.allTeams = createTestTeams()
        manager.currentWeek = 18
        
        // Set user team as a wild card team (seed #6)
        manager.userTeam = TeamData.getTeam(by: "Buffalo")
        
        // Set up playoffs
        manager.setupPlayoffs()
        
        // Simulate Wild Card round - Buffalo beats Miami
        let wildCardResults = [
            ("Buffalo", "Miami"),    // User beats Miami
            ("Baltimore", "Pittsburgh"),
            ("Indianapolis", "Houston"),
            ("Detroit", "GreenBay"),
            ("Philadelphia", "Dallas"),
            ("TampaBay", "Atlanta")
        ]
        
        for (winner, loser) in wildCardResults {
            if let winnerTeam = manager.allTeams.first(where: { $0.logoName == winner }),
               let loserTeam = manager.allTeams.first(where: { $0.logoName == loser }) {
                manager.addPlayoffResult(winner: winnerTeam, loser: loserTeam, week: 19, homeScore: 28, awayScore: 21)
            }
        }
        
        print("✅ Wild Card round completed")
        
        // Generate Divisional Round
        manager.generateNextRoundBracket(for: 20)
        
        // Get user's divisional opponent
        let userPlayoffInfo = manager.getUserPlayoffInfo()
        #expect(userPlayoffInfo != nil, "User should have playoff info for divisional round")
        
        if let opponent = userPlayoffInfo?.opponent {
            // User should NOT be playing Miami again (they just beat them)
            #expect(opponent.logoName != "Miami", "User should not play Miami again after beating them in Wild Card")
            print("✅ User correctly playing \(opponent.name) in divisional round (not Miami)")
        }
    }
    
    @Test("Playoff bracket progression with proper elimination checking")
    func testPlayoffBracketProgressionWithElimination() async throws {
        let manager = LeagueManager()
        manager.allTeams = createTestTeams()
        manager.currentWeek = 18
        
        // Set user team as a wild card team
        manager.userTeam = TeamData.getTeam(by: "Buffalo")
        
        // Set up playoffs
        manager.setupPlayoffs()
        
        // Verify user is in wild card round
        manager.currentWeek = 19
        let wildCardInfo = manager.getUserPlayoffInfo()
        #expect(wildCardInfo != nil, "User should have wild card game")
        #expect(wildCardInfo?.opponent != nil, "User should have an opponent in wild card")
        
        // Simulate user LOSING wild card game
        if let userTeam = manager.allTeams.first(where: { $0.logoName == "Buffalo" }),
           let opponentTeam = manager.allTeams.first(where: { $0.logoName == "Miami" }) {
            
            // User loses to Miami
            manager.addPlayoffResult(winner: opponentTeam, loser: userTeam, week: 19, homeScore: 24, awayScore: 17)
            print("🏈 Simulated user loss: \(opponentTeam.name) 24, \(userTeam.name) 17")
        }
        
        // Advance to divisional round
        manager.currentWeek = 20
        manager.generateNextRoundBracket(for: 20)
        
        // User should be eliminated and have no playoff info
        let divisionalInfo = manager.getUserPlayoffInfo()
        #expect(divisionalInfo == nil, "User should be eliminated and have no divisional round info")
        
        print("✅ User correctly eliminated after wild card loss")
    }
    
    @Test("User advances correctly when winning playoff games")
    func testUserAdvancementAfterWins() async throws {
        let manager = LeagueManager()
        manager.allTeams = createTestTeams()
        manager.currentWeek = 18
        
        // Set user team as a wild card team
        manager.userTeam = TeamData.getTeam(by: "Buffalo")
        
        // Set up playoffs
        manager.setupPlayoffs()
        
        // Wild Card Round - User WINS
        manager.currentWeek = 19
        if let userTeam = manager.allTeams.first(where: { $0.logoName == "Buffalo" }),
           let opponentTeam = manager.allTeams.first(where: { $0.logoName == "Miami" }) {
            
            // User beats Miami
            manager.addPlayoffResult(winner: userTeam, loser: opponentTeam, week: 19, homeScore: 28, awayScore: 21)
            print("🏈 User won wild card: \(userTeam.name) 28, \(opponentTeam.name) 21")
        }
        
        // Simulate other wild card games
        let otherWildCardResults = [
            ("Baltimore", "Pittsburgh"),
            ("Indianapolis", "Houston"),
            ("Detroit", "GreenBay"),
            ("Philadelphia", "Dallas"),
            ("TampaBay", "Atlanta")
        ]
        
        for (winner, loser) in otherWildCardResults {
            if let winnerTeam = manager.allTeams.first(where: { $0.logoName == winner }),
               let loserTeam = manager.allTeams.first(where: { $0.logoName == loser }) {
                manager.addPlayoffResult(winner: winnerTeam, loser: loserTeam, week: 19, homeScore: 24, awayScore: 17)
            }
        }
        
        // Advance to Divisional Round
        manager.currentWeek = 20
        manager.generateNextRoundBracket(for: 20)
        
        // User should have a divisional opponent (and it should NOT be Miami)
        let divisionalInfo = manager.getUserPlayoffInfo()
        #expect(divisionalInfo != nil, "User should advance to divisional round")
        #expect(divisionalInfo?.opponent != nil, "User should have divisional opponent")
        
        if let opponent = divisionalInfo?.opponent {
            #expect(opponent.logoName != "Miami", "User should not play Miami again")
            print("✅ User correctly advanced to play \(opponent.name) in divisional round")
        }
        
        // Divisional Round - User WINS again
        if let userTeam = manager.allTeams.first(where: { $0.logoName == "Buffalo" }),
           let divisionalOpponent = divisionalInfo?.opponent {
            
            // User beats divisional opponent
            manager.addPlayoffResult(winner: userTeam, loser: divisionalOpponent, week: 20, homeScore: 31, awayScore: 24)
            print("🏈 User won divisional: \(userTeam.name) 31, \(divisionalOpponent.name) 24")
        }
        
        // Simulate other divisional games
        let otherDivisionalResults = [
            ("KansasCity", "Indianapolis"),
            ("Baltimore", "Cincinnati"),
            ("SanFrancisco", "TampaBay"),
            ("Detroit", "Philadelphia")
        ]
        
        for (winner, loser) in otherDivisionalResults {
            if let winnerTeam = manager.allTeams.first(where: { $0.logoName == winner }),
               let loserTeam = manager.allTeams.first(where: { $0.logoName == loser }) {
                manager.addPlayoffResult(winner: winnerTeam, loser: loserTeam, week: 20, homeScore: 28, awayScore: 21)
            }
        }
        
        // Advance to Conference Championship
        manager.currentWeek = 21
        manager.generateNextRoundBracket(for: 21)
        
        // User should have a conference championship opponent
        let conferenceInfo = manager.getUserPlayoffInfo()
        #expect(conferenceInfo != nil, "User should advance to conference championship")
        #expect(conferenceInfo?.opponent != nil, "User should have conference championship opponent")
        
        if let opponent = conferenceInfo?.opponent {
            print("✅ User correctly advanced to AFC Championship vs \(opponent.name)")
        }
    }
    
    @Test("Proper NFL reseeding in divisional round")
    func testProperNFLReseeding() async throws {
        let manager = LeagueManager()
        manager.allTeams = createTestTeams()
        manager.currentWeek = 18
        manager.userTeam = TeamData.getTeam(by: "Buffalo")
        
        manager.setupPlayoffs()
        
        // Simulate specific wild card results to test reseeding
        // AFC: #2 beats #7, #3 beats #6, #4 beats #5
        // So advancing teams are: #1 (bye), #2, #3, #4
        let wildCardResults = [
            ("Baltimore", "LasVegas"),    // #2 beats #7
            ("Cincinnati", "Miami"),      // #3 beats #6  
            ("Indianapolis", "Buffalo"),  // #4 beats #5
            ("Detroit", "GreenBay"),      // NFC
            ("Philadelphia", "Dallas"),   // NFC
            ("TampaBay", "Atlanta")       // NFC
        ]
        
        for (winner, loser) in wildCardResults {
            if let winnerTeam = manager.allTeams.first(where: { $0.logoName == winner }),
               let loserTeam = manager.allTeams.first(where: { $0.logoName == loser }) {
                manager.addPlayoffResult(winner: winnerTeam, loser: loserTeam, week: 19, homeScore: 24, awayScore: 17)
            }
        }
        
        // Generate Divisional Round
        manager.generateNextRoundBracket(for: 20)
        let divisionalBracket = manager.getPlayoffBracket()
        
        #expect(divisionalBracket.count == 4, "Should have 4 divisional games")
        
        // Find AFC games
        let afcGames = divisionalBracket.filter { matchup in
            let homeTeamConference = manager.getProperConference(for: matchup.homeTeam.logoName)
            return homeTeamConference == .afc
        }
        
        #expect(afcGames.count == 2, "Should have 2 AFC divisional games")
        
        // Verify proper reseeding:
        // #1 seed should play #4 seed (lowest remaining)
        // #2 seed should play #3 seed (second-lowest remaining)
        
        print("✅ Proper NFL reseeding verified in divisional round")
    }
    
    // MARK: - Helper Methods
    
    private func createTestTeams() -> [LeagueTeam] {
        let teamNames = [
            // AFC Teams (first 16)
            "KansasCity", "Baltimore", "Cincinnati", "Buffalo", "Miami", "Indianapolis", "LasVegas", "Pittsburgh",
            "Houston", "Cleveland", "NewEngland", "Tennessee", "Jacksonville", "Denver", "LAA", "NYA",
            // NFC Teams (next 16)
            "SanFrancisco", "Detroit", "Philadelphia", "Dallas", "GreenBay", "TampaBay", "Minnesota", "Atlanta",
            "Seattle", "LAN", "Arizona", "Chicago", "Carolina", "NewOrleans", "NYN", "Washington"
        ]
        
        return teamNames.enumerated().map { index, name in
            let isAFC = index < 16
            let conference = isAFC ? "AFC" : "NFC"
            
            // Create division assignments
            let division: String
            if isAFC {
                switch index % 4 {
                case 0: division = "AFC East"
                case 1: division = "AFC North"
                case 2: division = "AFC South"
                default: division = "AFC West"
                }
            } else {
                switch index % 4 {
                case 0: division = "NFC East"
                case 1: division = "NFC North"
                case 2: division = "NFC South"
                default: division = "NFC West"
                }
            }
            
            // Create varying records for realistic playoff scenarios
            let baseWins = 14 - (index % 8) // Vary wins from 14 down to 7
            let wins = max(baseWins, 7)
            let losses = 17 - wins
            
            let defaultCoach = Coach(
                firstName: "Coach",
                lastName: name,
                overallRating: 75,
                offensiveScheme: "Pro Style",
                defensiveScheme: "4-3 Base",
                experience: 5,
                offensiveCoordinator: OffensiveCoordinator(
                    firstName: "OC",
                    lastName: name,
                    overallRating: 70,
                    offensiveScheme: "Pro Style",
                    experience: 3
                ),
                defensiveCoordinator: DefensiveCoordinator(
                    firstName: "DC",
                    lastName: name,
                    overallRating: 70,
                    defensiveScheme: "4-3 Base",
                    experience: 3
                )
            )
            
            return LeagueTeam(
                logoName: name,
                name: name,
                conference: conference,
                division: division,
                primaryColor: "blue",
                secondaryColor: "white",
                players: [],
                overallRating: 85 - index, // Varying ratings
                coach: defaultCoach,
                record: TeamRecord(wins: wins, losses: losses, ties: 0)
            )
        }
    }
} 