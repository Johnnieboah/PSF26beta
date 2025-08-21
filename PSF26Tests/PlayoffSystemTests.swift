import Testing
@testable import PSF26

@MainActor
struct PlayoffSystemTests {
    
    // MARK: - Test Setup Helpers
    
    private func createTestLeagueManager() -> LeagueManager {
        let manager = LeagueManager()
        
        // Create test teams with proper divisions and conferences
        let testTeams = createTestTeams()
        manager.allTeams = testTeams
        manager.currentWeek = 18
        
        // Set a user team for testing
        if let userTeam = testTeams.first(where: { $0.logoName == "Buffalo" }) {
            manager.userTeam = TeamData.getTeam(by: "Buffalo")
        }
        
        return manager
    }
    
    private func createTestTeams() -> [LeagueTeam] {
        var teams: [LeagueTeam] = []
        
        // AFC East - Buffalo as division winner
        teams.append(createTestTeam(logoName: "Buffalo", conference: "AFC", division: "AFC East", wins: 14, losses: 3))
        teams.append(createTestTeam(logoName: "Miami", conference: "AFC", division: "AFC East", wins: 11, losses: 6))
        teams.append(createTestTeam(logoName: "NYA", conference: "AFC", division: "AFC East", wins: 8, losses: 9))
        teams.append(createTestTeam(logoName: "NewEngland", conference: "AFC", division: "AFC East", wins: 6, losses: 11))
        
        // AFC North - Baltimore as division winner
        teams.append(createTestTeam(logoName: "Baltimore", conference: "AFC", division: "AFC North", wins: 13, losses: 4))
        teams.append(createTestTeam(logoName: "Pittsburgh", conference: "AFC", division: "AFC North", wins: 10, losses: 7))
        teams.append(createTestTeam(logoName: "Cincinnati", conference: "AFC", division: "AFC North", wins: 9, losses: 8))
        teams.append(createTestTeam(logoName: "Cleveland", conference: "AFC", division: "AFC North", wins: 7, losses: 10))
        
        // AFC South - Indianapolis as division winner
        teams.append(createTestTeam(logoName: "Indianapolis", conference: "AFC", division: "AFC South", wins: 12, losses: 5))
        teams.append(createTestTeam(logoName: "Houston", conference: "AFC", division: "AFC South", wins: 9, losses: 8))
        teams.append(createTestTeam(logoName: "Tennessee", conference: "AFC", division: "AFC South", wins: 8, losses: 9))
        teams.append(createTestTeam(logoName: "Jacksonville", conference: "AFC", division: "AFC South", wins: 5, losses: 12))
        
        // AFC West - Kansas City as division winner
        teams.append(createTestTeam(logoName: "KansasCity", conference: "AFC", division: "AFC West", wins: 15, losses: 2))
        teams.append(createTestTeam(logoName: "LasVegas", conference: "AFC", division: "AFC West", wins: 11, losses: 6))
        teams.append(createTestTeam(logoName: "Denver", conference: "AFC", division: "AFC West", wins: 8, losses: 9))
        teams.append(createTestTeam(logoName: "LAA", conference: "AFC", division: "AFC West", wins: 6, losses: 11))
        
        // NFC East - Philadelphia as division winner
        teams.append(createTestTeam(logoName: "Philadelphia", conference: "NFC", division: "NFC East", wins: 13, losses: 4))
        teams.append(createTestTeam(logoName: "Dallas", conference: "NFC", division: "NFC East", wins: 10, losses: 7))
        teams.append(createTestTeam(logoName: "NYN", conference: "NFC", division: "NFC East", wins: 8, losses: 9))
        teams.append(createTestTeam(logoName: "Washington", conference: "NFC", division: "NFC East", wins: 7, losses: 10))
        
        // NFC North - Detroit as division winner
        teams.append(createTestTeam(logoName: "Detroit", conference: "NFC", division: "NFC North", wins: 14, losses: 3))
        teams.append(createTestTeam(logoName: "GreenBay", conference: "NFC", division: "NFC North", wins: 11, losses: 6))
        teams.append(createTestTeam(logoName: "Minnesota", conference: "NFC", division: "NFC North", wins: 9, losses: 8))
        teams.append(createTestTeam(logoName: "Chicago", conference: "NFC", division: "NFC North", wins: 6, losses: 11))
        
        // NFC South - Tampa Bay as division winner
        teams.append(createTestTeam(logoName: "TampaBay", conference: "NFC", division: "NFC South", wins: 12, losses: 5))
        teams.append(createTestTeam(logoName: "Atlanta", conference: "NFC", division: "NFC South", wins: 10, losses: 7))
        teams.append(createTestTeam(logoName: "NewOrleans", conference: "NFC", division: "NFC South", wins: 8, losses: 9))
        teams.append(createTestTeam(logoName: "Carolina", conference: "NFC", division: "NFC South", wins: 5, losses: 12))
        
        // NFC West - San Francisco as division winner
        teams.append(createTestTeam(logoName: "SanFrancisco", conference: "NFC", division: "NFC West", wins: 15, losses: 2))
        teams.append(createTestTeam(logoName: "Seattle", conference: "NFC", division: "NFC West", wins: 12, losses: 5))
        teams.append(createTestTeam(logoName: "LAN", conference: "NFC", division: "NFC West", wins: 9, losses: 8))
        teams.append(createTestTeam(logoName: "Arizona", conference: "NFC", division: "NFC West", wins: 7, losses: 10))
        
        return teams
    }
    
    private func createTestTeam(logoName: String, conference: String, division: String, wins: Int, losses: Int) -> LeagueTeam {
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
    
    // MARK: - Basic Functionality Tests
    
    @Test("Playoff setup creates correct number of teams")
    func testPlayoffSetup() async throws {
        let manager = createTestLeagueManager()
        manager.setupPlayoffs()
        
        // Should have exactly 14 playoff teams (7 AFC, 7 NFC)
        #expect(manager.playoffTeams.count == 14)
        
        print("✅ Playoff setup test passed")
    }
    
    @Test("Bracket generation creates correct matchups")
    func testBracketGeneration() async throws {
        let manager = createTestLeagueManager()
        manager.setupPlayoffs()
        
        let bracket = manager.getPlayoffBracket()
        
        // Should have Wild Card games (6 total)
        #expect(bracket.count == 6)
        
        print("✅ Bracket generation test passed")
    }
    
    @Test("User playoff info returns valid data")
    func testUserPlayoffInfo() async throws {
        let manager = createTestLeagueManager()
        manager.setupPlayoffs()
        
        // Buffalo should be in playoffs
        guard let playoffInfo = manager.getUserPlayoffInfo() else {
            throw TestError.missingPlayoffInfo
        }
        
        #expect(playoffInfo.seed > 0)
        #expect(playoffInfo.seed <= 7)
        
        print("✅ User playoff info test passed")
    }
    
    // MARK: - Data Persistence Tests
    
    @Test("Playoff data saves and loads correctly")
    func testPlayoffDataPersistence() async throws {
        let manager = createTestLeagueManager()
        manager.setupPlayoffs()
        
        // Create a test league for persistence
        let league = League(teamName: "Test Team", teamLogoName: "Buffalo")
        let observableLeague = ObservableLeague(league: league)
        
        // Save data
        try observableLeague.save(from: manager)
        
        // Verify data was saved
        let savedLeague = observableLeague.getLeague()
        #expect(savedLeague.playoffTeamLogoNames?.count == 14)
        
        print("✅ Playoff data persistence test passed")
    }
    
    // MARK: - Error Types
    
    enum TestError: Error {
        case missingPlayoffInfo
        case invalidBracketState
        case persistenceFailure
    }
} 