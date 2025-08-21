import Testing
@testable import PSF26

@MainActor
struct PlayoffIntegrationTests {
    
    @Test("End-to-end playoff system integration")
    func testPlayoffSystemIntegration() async throws {
        print("🧪 Starting end-to-end playoff system integration test...")
        
        // Step 1: Create a league manager with realistic data
        let manager = LeagueManager()
        manager.allTeams = createFullNFLTeams()
        manager.currentWeek = 18
        
        // Set user team
        manager.userTeam = TeamData.getTeam(by: "Buffalo")
        
        print("✅ Step 1: Created league manager with 32 teams")
        
        // Step 2: Set up playoffs
        manager.setupPlayoffs()
        
        #expect(manager.playoffTeams.count == 14)
        #expect(!manager.getPlayoffBracket().isEmpty)
        
        print("✅ Step 2: Playoffs set up successfully")
        
        // Step 3: Test user playoff info
        guard let userPlayoffInfo = manager.getUserPlayoffInfo() else {
            throw TestError.userNotInPlayoffs
        }
        
        #expect(userPlayoffInfo.seed > 0)
        print("✅ Step 3: User team is in playoffs as seed #\(userPlayoffInfo.seed)")
        
        // Step 4: Simulate a playoff game
        if let opponent = userPlayoffInfo.opponent {
            manager.addPlayoffResult(
                winner: manager.allTeams.first(where: { $0.logoName == "Buffalo" })!,
                loser: opponent,
                week: 19,
                homeScore: 28,
                awayScore: 21
            )
            print("✅ Step 4: Simulated playoff game - Buffalo 28, \(opponent.logoName) 21")
        } else {
            print("✅ Step 4: User has bye week (seed #1)")
        }
        
        // Step 5: Test data persistence
        let league = League(teamName: "Test Buffalo", teamLogoName: "Buffalo")
        let observableLeague = ObservableLeague(league: league)
        
        try observableLeague.save(from: manager)
        let savedLeague = observableLeague.getLeague()
        
        // Verify all playoff data was saved
        #expect(savedLeague.playoffTeamLogoNames?.count == 14)
        #expect(savedLeague.bracketHistory != nil)
        #expect(savedLeague.bracketResults != nil)
        
        print("✅ Step 5: Playoff data persistence verified")
        
        // Step 6: Test data loading
        let newManager = LeagueManager()
        newManager.allTeams = createFullNFLTeams()
        newManager.currentWeek = 19
        newManager.userTeam = TeamData.getTeam(by: "Buffalo")
        
        newManager.loadPlayoffData(from: savedLeague)
        
        #expect(newManager.playoffTeams.count == 14)
        #expect(!newManager.getPlayoffBracket().isEmpty)
        
        print("✅ Step 6: Playoff data loading verified")
        
        // Step 7: Test debug functionality
        manager.debugPlayoffDataPersistence()
        
        print("✅ Step 7: Debug functionality works")
        
        print("🎉 End-to-end playoff system integration test PASSED!")
    }
    
    @Test("Playoff bracket progression through all rounds")
    func testFullPlayoffProgression() async throws {
        print("🧪 Testing full playoff progression...")
        
        let manager = LeagueManager()
        manager.allTeams = createFullNFLTeams()
        manager.currentWeek = 18
        manager.userTeam = TeamData.getTeam(by: "KansasCity") // Set as likely #1 seed
        
        // Set up playoffs
        manager.setupPlayoffs()
        
        // Wild Card Round (Week 19)
        let wildCardResults = [
            ("Buffalo", "LasVegas"),
            ("Baltimore", "Miami"),
            ("Indianapolis", "Pittsburgh"),
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
        
        print("✅ Wild Card round simulated")
        
        // Divisional Round (Week 20)
        manager.generateNextRoundBracket(for: 20)
        let divisionalBracket = manager.getPlayoffBracket()
        #expect(divisionalBracket.count == 4)
        
        let divisionalResults = [
            ("KansasCity", "Indianapolis"),
            ("Buffalo", "Baltimore"),
            ("SanFrancisco", "TampaBay"),
            ("Detroit", "Philadelphia")
        ]
        
        for (winner, loser) in divisionalResults {
            if let winnerTeam = manager.allTeams.first(where: { $0.logoName == winner }),
               let loserTeam = manager.allTeams.first(where: { $0.logoName == loser }) {
                manager.addPlayoffResult(winner: winnerTeam, loser: loserTeam, week: 20, homeScore: 31, awayScore: 24)
            }
        }
        
        print("✅ Divisional round simulated")
        
        // Conference Championships (Week 21)
        manager.generateNextRoundBracket(for: 21)
        let conferenceBracket = manager.getPlayoffBracket()
        #expect(conferenceBracket.count == 2)
        
        // AFC Championship
        if let afcChamp = manager.allTeams.first(where: { $0.logoName == "KansasCity" }),
           let afcRunner = manager.allTeams.first(where: { $0.logoName == "Buffalo" }) {
            manager.addPlayoffResult(winner: afcChamp, loser: afcRunner, week: 21, homeScore: 28, awayScore: 21)
        }
        
        // NFC Championship
        if let nfcChamp = manager.allTeams.first(where: { $0.logoName == "SanFrancisco" }),
           let nfcRunner = manager.allTeams.first(where: { $0.logoName == "Detroit" }) {
            manager.addPlayoffResult(winner: nfcChamp, loser: nfcRunner, week: 21, homeScore: 35, awayScore: 28)
        }
        
        print("✅ Conference championships simulated")
        
        // Super Bowl (Week 22)
        manager.generateNextRoundBracket(for: 22)
        let superBowlBracket = manager.getPlayoffBracket()
        #expect(superBowlBracket.count == 1)
        
        let superBowlGame = superBowlBracket[0]
        let teams = [superBowlGame.homeTeam.logoName, superBowlGame.awayTeam.logoName]
        #expect(teams.contains("KansasCity"))
        #expect(teams.contains("SanFrancisco"))
        
        print("✅ Super Bowl generated: \(superBowlGame.homeTeam.logoName) vs \(superBowlGame.awayTeam.logoName)")
        
        print("🏆 Full playoff progression test PASSED!")
    }
    
    // MARK: - Helper Methods
    
    private func createFullNFLTeams() -> [LeagueTeam] {
        var teams: [LeagueTeam] = []
        
        // AFC East
        teams.append(createTeam("Buffalo", "AFC", "AFC East", 14, 3))
        teams.append(createTeam("Miami", "AFC", "AFC East", 11, 6))
        teams.append(createTeam("NYA", "AFC", "AFC East", 8, 9))
        teams.append(createTeam("NewEngland", "AFC", "AFC East", 6, 11))
        
        // AFC North
        teams.append(createTeam("Baltimore", "AFC", "AFC North", 13, 4))
        teams.append(createTeam("Pittsburgh", "AFC", "AFC North", 10, 7))
        teams.append(createTeam("Cincinnati", "AFC", "AFC North", 9, 8))
        teams.append(createTeam("Cleveland", "AFC", "AFC North", 7, 10))
        
        // AFC South
        teams.append(createTeam("Indianapolis", "AFC", "AFC South", 12, 5))
        teams.append(createTeam("Houston", "AFC", "AFC South", 9, 8))
        teams.append(createTeam("Tennessee", "AFC", "AFC South", 8, 9))
        teams.append(createTeam("Jacksonville", "AFC", "AFC South", 5, 12))
        
        // AFC West
        teams.append(createTeam("KansasCity", "AFC", "AFC West", 15, 2))
        teams.append(createTeam("LasVegas", "AFC", "AFC West", 11, 6))
        teams.append(createTeam("Denver", "AFC", "AFC West", 8, 9))
        teams.append(createTeam("LAA", "AFC", "AFC West", 6, 11))
        
        // NFC East
        teams.append(createTeam("Philadelphia", "NFC", "NFC East", 13, 4))
        teams.append(createTeam("Dallas", "NFC", "NFC East", 10, 7))
        teams.append(createTeam("NYN", "NFC", "NFC East", 8, 9))
        teams.append(createTeam("Washington", "NFC", "NFC East", 7, 10))
        
        // NFC North
        teams.append(createTeam("Detroit", "NFC", "NFC North", 14, 3))
        teams.append(createTeam("GreenBay", "NFC", "NFC North", 11, 6))
        teams.append(createTeam("Minnesota", "NFC", "NFC North", 9, 8))
        teams.append(createTeam("Chicago", "NFC", "NFC North", 6, 11))
        
        // NFC South
        teams.append(createTeam("TampaBay", "NFC", "NFC South", 12, 5))
        teams.append(createTeam("Atlanta", "NFC", "NFC South", 10, 7))
        teams.append(createTeam("NewOrleans", "NFC", "NFC South", 8, 9))
        teams.append(createTeam("Carolina", "NFC", "NFC South", 5, 12))
        
        // NFC West
        teams.append(createTeam("SanFrancisco", "NFC", "NFC West", 15, 2))
        teams.append(createTeam("Seattle", "NFC", "NFC West", 12, 5))
        teams.append(createTeam("LAN", "NFC", "NFC West", 9, 8))
        teams.append(createTeam("Arizona", "NFC", "NFC West", 7, 10))
        
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
    
    enum TestError: Error {
        case userNotInPlayoffs
        case invalidBracketState
        case persistenceFailure
    }
} 