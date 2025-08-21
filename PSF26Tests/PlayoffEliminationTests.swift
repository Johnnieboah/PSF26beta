import Testing
@testable import PSF26

@MainActor
struct PlayoffEliminationTests {
    
    @Test("User season ends when they lose a wild card game")
    func testWildCardElimination() async throws {
        let manager = LeagueManager()
        manager.allTeams = createTestTeams()
        manager.currentWeek = 19
        
        // Set user team as a wild card team
        manager.userTeam = TeamData.getTeam(by: "Buffalo")
        
        // Set up playoffs
        manager.setupPlayoffs()
        
        // Simulate user losing their wild card game
        if let userTeam = manager.allTeams.first(where: { $0.logoName == "Buffalo" }),
           let opponentTeam = manager.allTeams.first(where: { $0.logoName == "Miami" }) {
            
            // User loses - opponent wins
            manager.addPlayoffResult(winner: opponentTeam, loser: userTeam, week: 19, homeScore: 28, awayScore: 21)
            print("🏈 Simulated user loss: \(opponentTeam.name) 28, \(userTeam.name) 21")
            
            // Try to generate next round bracket
            manager.generateNextRoundBracket(for: 20)
            
            // Get user's playoff info for divisional round
            let userPlayoffInfo = manager.getUserPlayoffInfo()
            
            // User should NOT have playoff info since they were eliminated
            #expect(userPlayoffInfo == nil, "User should be eliminated and have no playoff info")
            
            print("✅ User correctly eliminated after wild card loss")
        }
    }
    
    @Test("User season ends when they lose a divisional game")
    func testDivisionalElimination() async throws {
        let manager = LeagueManager()
        manager.allTeams = createTestTeams()
        manager.currentWeek = 19
        
        // Set user team as a high seed (gets bye, goes straight to divisional)
        manager.userTeam = TeamData.getTeam(by: "KansasCity")
        
        // Set up playoffs
        manager.setupPlayoffs()
        
        // Simulate wild card round (user has bye)
        let wildCardResults = [
            ("Baltimore", "LasVegas"),
            ("Cincinnati", "Miami"),
            ("Indianapolis", "Buffalo"),
            ("Detroit", "GreenBay"),
            ("Philadelphia", "Dallas"),
            ("TampaBay", "Atlanta")
        ]
        
        for (winner, loser) in wildCardResults {
            if let winnerTeam = manager.allTeams.first(where: { $0.logoName == winner }),
               let loserTeam = manager.allTeams.first(where: { $0.logoName == loser }) {
                manager.addPlayoffResult(winner: winnerTeam, loser: loserTeam, week: 19, homeScore: 24, awayScore: 17)
            }
        }
        
        // Generate divisional round
        manager.generateNextRoundBracket(for: 20)
        
        // User should have divisional opponent
        let userDivisionalInfo = manager.getUserPlayoffInfo()
        #expect(userDivisionalInfo != nil, "User should have divisional round opponent")
        
        // Simulate user losing divisional game
        if let userTeam = manager.allTeams.first(where: { $0.logoName == "KansasCity" }),
           let opponentTeam = userDivisionalInfo?.opponent {
            
            // User loses divisional game
            manager.addPlayoffResult(winner: opponentTeam, loser: userTeam, week: 20, homeScore: 31, awayScore: 28)
            print("🏈 Simulated user divisional loss: \(opponentTeam.name) 31, \(userTeam.name) 28")
            
            // Try to generate conference championship
            manager.generateNextRoundBracket(for: 21)
            
            // User should NOT be in conference championship
            let userConferenceInfo = manager.getUserPlayoffInfo()
            #expect(userConferenceInfo == nil, "User should be eliminated and have no conference championship info")
            
            print("✅ User correctly eliminated after divisional loss")
        }
    }
    
    @Test("User advances when they win playoff games")
    func testPlayoffAdvancement() async throws {
        let manager = LeagueManager()
        manager.allTeams = createTestTeams()
        manager.currentWeek = 19
        
        // Set user team as wild card
        manager.userTeam = TeamData.getTeam(by: "Buffalo")
        
        // Set up playoffs
        manager.setupPlayoffs()
        
        // User wins wild card game
        if let userTeam = manager.allTeams.first(where: { $0.logoName == "Buffalo" }),
           let opponentTeam = manager.allTeams.first(where: { $0.logoName == "Miami" }) {
            
            // User wins
            manager.addPlayoffResult(winner: userTeam, loser: opponentTeam, week: 19, homeScore: 28, awayScore: 21)
            print("🏈 Simulated user win: \(userTeam.name) 28, \(opponentTeam.name) 21")
            
            // Generate next round bracket
            manager.generateNextRoundBracket(for: 20)
            
            // User should have divisional opponent
            let userPlayoffInfo = manager.getUserPlayoffInfo()
            #expect(userPlayoffInfo != nil, "User should advance to divisional round")
            #expect(userPlayoffInfo?.opponent != nil, "User should have a divisional opponent")
            
            if let opponent = userPlayoffInfo?.opponent {
                print("✅ User correctly advanced to play \(opponent.name) in divisional round")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestTeams() -> [LeagueTeam] {
        var teams: [LeagueTeam] = []
        
        // Create teams with specific records for predictable seeding
        let teamData = [
            // AFC
            ("KansasCity", "AFC", "AFC West", 15, 2),      // #1 seed
            ("Baltimore", "AFC", "AFC North", 13, 4),      // #2 seed  
            ("Cincinnati", "AFC", "AFC North", 12, 5),     // #3 seed
            ("Indianapolis", "AFC", "AFC South", 11, 6),   // #4 seed
            ("Buffalo", "AFC", "AFC East", 10, 7),         // #5 seed
            ("Miami", "AFC", "AFC East", 9, 8),            // #6 seed
            ("LasVegas", "AFC", "AFC West", 9, 8),         // #7 seed
            ("Pittsburgh", "AFC", "AFC North", 8, 9),
            ("NewEngland", "AFC", "AFC East", 7, 10),
            ("Denver", "AFC", "AFC West", 6, 11),
            ("Houston", "AFC", "AFC South", 5, 12),
            ("Cleveland", "AFC", "AFC North", 4, 13),
            ("Tennessee", "AFC", "AFC South", 4, 13),
            ("Jacksonville", "AFC", "AFC South", 3, 14),
            ("NYA", "AFC", "AFC East", 3, 14),
            ("LAA", "AFC", "AFC West", 2, 15),
            
            // NFC
            ("SanFrancisco", "NFC", "NFC West", 14, 3),    // #1 seed
            ("Philadelphia", "NFC", "NFC East", 13, 4),    // #2 seed
            ("Detroit", "NFC", "NFC North", 12, 5),        // #3 seed
            ("TampaBay", "NFC", "NFC South", 11, 6),       // #4 seed
            ("Dallas", "NFC", "NFC East", 10, 7),          // #5 seed
            ("GreenBay", "NFC", "NFC North", 9, 8),        // #6 seed
            ("Atlanta", "NFC", "NFC South", 9, 8),         // #7 seed
            ("Seattle", "NFC", "NFC West", 8, 9),
            ("Minnesota", "NFC", "NFC North", 7, 10),
            ("NYN", "NFC", "NFC East", 6, 11),
            ("Washington", "NFC", "NFC East", 5, 12),
            ("LAN", "NFC", "NFC West", 4, 13),
            ("Carolina", "NFC", "NFC South", 3, 14),
            ("NewOrleans", "NFC", "NFC South", 2, 15),
            ("Chicago", "NFC", "NFC North", 2, 15),
            ("Arizona", "NFC", "NFC West", 1, 16)
        ]
        
        for (logoName, conference, division, wins, losses) in teamData {
            teams.append(createTeam(logoName, conference, division, wins, losses))
        }
        
        return teams
    }
    
    private func createTeam(_ logoName: String, _ conference: String, _ division: String, _ wins: Int, _ losses: Int) -> LeagueTeam {
        let coach = Coach(
            firstName: "Test",
            lastName: "Coach",
            overallRating: 80,
            offensiveScheme: "Pro Style",
            defensiveScheme: "4-3 Base",
            experience: 5,
            offensiveCoordinator: OffensiveCoordinator(
                firstName: "OC",
                lastName: "Test",
                overallRating: 75,
                offensiveScheme: "Pro Style",
                experience: 3
            ),
            defensiveCoordinator: DefensiveCoordinator(
                firstName: "DC",
                lastName: "Test",
                overallRating: 75,
                defensiveScheme: "4-3 Base",
                experience: 3
            )
        )
        
        var team = LeagueTeam(
            logoName: logoName,
            name: logoName,
            conference: conference,
            division: division,
            primaryColor: "blue",
            secondaryColor: "white",
            players: [],
            overallRating: 80,
            coach: coach
        )
        
        team.record = TeamRecord(wins: wins, losses: losses, ties: 0)
        return team
    }
} 