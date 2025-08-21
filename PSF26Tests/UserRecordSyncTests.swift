import Testing
@testable import PSF26

@MainActor
struct UserRecordSyncTests {
    
    @Test("User team with 13-4 record makes playoffs after sync")
    func testUserTeamMakesPlayoffsWithGoodRecord() async throws {
        // Create league manager
        let manager = LeagueManager()
        manager.allTeams = createTestTeams()
        manager.currentWeek = 18
        
        // Set user team to Buffalo (we'll give them a 13-4 record)
        manager.userTeam = TeamData.getTeam(by: "Buffalo")
        
        // Create completed games that would give Buffalo a 13-4 record
        manager.completedGames = createCompletedGamesFor13And4Record(manager: manager)
        
        // Initially, the allTeams array might have the wrong record
        // (simulating the bug scenario)
        if let buffaloIndex = manager.allTeams.firstIndex(where: { $0.logoName == "Buffalo" }) {
            manager.allTeams[buffaloIndex].record = TeamRecord(wins: 8, losses: 9, ties: 0) // Wrong record
        }
        
        print("🧪 Before sync - Buffalo record in allTeams: \(manager.getTeamRecord(for: "Buffalo").description)")
        
        // Call sync method (this should fix the record)
        manager.syncUserTeamRecord()
        
        print("🧪 After sync - Buffalo record in allTeams: \(manager.getTeamRecord(for: "Buffalo").description)")
        
        // Now set up playoffs
        manager.setupPlayoffs()
        
        // Verify Buffalo made playoffs
        let buffaloMadePlayoffs = manager.playoffTeams.contains { $0.logoName == "Buffalo" }
        #expect(buffaloMadePlayoffs, "Buffalo with 13-4 record should make playoffs")
        
        // Verify getUserPlayoffInfo works
        let playoffInfo = manager.getUserPlayoffInfo()
        #expect(playoffInfo != nil, "User should have playoff info")
        
        if let info = playoffInfo {
            #expect(info.seed > 0, "User should have a valid seed")
            print("✅ Buffalo made playoffs as seed #\(info.seed)")
        }
    }
    
    @Test("Record sync accurately counts wins and losses from completed games")
    func testRecordSyncAccuracy() async throws {
        let manager = LeagueManager()
        manager.allTeams = createTestTeams()
        manager.userTeam = TeamData.getTeam(by: "Buffalo")
        
        // Create exactly 17 games (full season) with known results
        let completedGames = createExactGameResults(manager: manager, wins: 13, losses: 4)
        manager.completedGames = completedGames
        
        // Set wrong record in allTeams
        if let buffaloIndex = manager.allTeams.firstIndex(where: { $0.logoName == "Buffalo" }) {
            manager.allTeams[buffaloIndex].record = TeamRecord(wins: 5, losses: 12, ties: 0)
        }
        
        // Sync should fix it
        manager.syncUserTeamRecord()
        
        let syncedRecord = manager.getTeamRecord(for: "Buffalo")
        #expect(syncedRecord.wins == 13, "Should have 13 wins after sync")
        #expect(syncedRecord.losses == 4, "Should have 4 losses after sync")
        #expect(syncedRecord.ties == 0, "Should have 0 ties after sync")
        
        print("✅ Record sync test passed: \(syncedRecord.description)")
    }
    
    // MARK: - Helper Methods
    
    private func createTestTeams() -> [LeagueTeam] {
        var teams: [LeagueTeam] = []
        
        // Create all 32 NFL teams with realistic records
        let teamData = [
            // AFC East
            ("Buffalo", "AFC", "AFC East", 13, 4),
            ("Miami", "AFC", "AFC East", 11, 6),
            ("NYA", "AFC", "AFC East", 7, 10),
            ("NewEngland", "AFC", "AFC East", 4, 13),
            
            // AFC North
            ("Baltimore", "AFC", "AFC North", 13, 4),
            ("Pittsburgh", "AFC", "AFC North", 10, 7),
            ("Cincinnati", "AFC", "AFC North", 9, 8),
            ("Cleveland", "AFC", "AFC North", 6, 11),
            
            // AFC South
            ("Indianapolis", "AFC", "AFC South", 12, 5),
            ("Houston", "AFC", "AFC South", 10, 7),
            ("Tennessee", "AFC", "AFC South", 6, 11),
            ("Jacksonville", "AFC", "AFC South", 3, 14),
            
            // AFC West
            ("KansasCity", "AFC", "AFC West", 14, 3),
            ("LasVegas", "AFC", "AFC West", 11, 6),
            ("Denver", "AFC", "AFC West", 8, 9),
            ("LAA", "AFC", "AFC West", 5, 12),
            
            // NFC East
            ("Philadelphia", "NFC", "NFC East", 14, 3),
            ("Dallas", "NFC", "NFC East", 12, 5),
            ("NYN", "NFC", "NFC East", 6, 11),
            ("Washington", "NFC", "NFC East", 4, 13),
            
            // NFC North
            ("Detroit", "NFC", "NFC North", 12, 5),
            ("GreenBay", "NFC", "NFC North", 9, 8),
            ("Minnesota", "NFC", "NFC North", 7, 10),
            ("Chicago", "NFC", "NFC North", 7, 10),
            
            // NFC South
            ("TampaBay", "NFC", "NFC South", 9, 8),
            ("NewOrleans", "NFC", "NFC South", 9, 8),
            ("Atlanta", "NFC", "NFC South", 7, 10),
            ("Carolina", "NFC", "NFC South", 2, 15),
            
            // NFC West
            ("SanFrancisco", "NFC", "NFC West", 12, 5),
            ("Seattle", "NFC", "NFC West", 9, 8),
            ("LAN", "NFC", "NFC West", 10, 7),
            ("Arizona", "NFC", "NFC West", 4, 13)
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
    
    private func createCompletedGamesFor13And4Record(manager: LeagueManager) -> [GameResult] {
        guard let buffaloTeam = manager.allTeams.first(where: { $0.logoName == "Buffalo" }) else {
            return []
        }
        
        var games: [GameResult] = []
        var wins = 0
        var losses = 0
        
        // Create 17 games (full season)
        for week in 1...17 {
            // Alternate between home and away games
            let isHome = week % 2 == 1
            
            // Get a random opponent (not Buffalo)
            let opponents = manager.allTeams.filter { $0.logoName != "Buffalo" }
            let opponent = opponents.randomElement()!
            
            var game = GameResult(
                week: week,
                homeTeam: isHome ? buffaloTeam : opponent,
                awayTeam: isHome ? opponent : buffaloTeam
            )
            
            // Set scores to give Buffalo desired record (13-4)
            if wins < 13 {
                // Buffalo wins
                game.homeScore = isHome ? 28 : 21
                game.awayScore = isHome ? 21 : 28
                wins += 1
            } else {
                // Buffalo loses
                game.homeScore = isHome ? 17 : 24
                game.awayScore = isHome ? 24 : 17
                losses += 1
            }
            
            game.isCompleted = true
            games.append(game)
        }
        
        return games
    }
    
    private func createExactGameResults(manager: LeagueManager, wins: Int, losses: Int) -> [GameResult] {
        guard let buffaloTeam = manager.allTeams.first(where: { $0.logoName == "Buffalo" }) else {
            return []
        }
        
        var games: [GameResult] = []
        let totalGames = wins + losses
        
        for week in 1...totalGames {
            let isHome = week % 2 == 1
            let opponents = manager.allTeams.filter { $0.logoName != "Buffalo" }
            let opponent = opponents.randomElement()!
            
            var game = GameResult(
                week: week,
                homeTeam: isHome ? buffaloTeam : opponent,
                awayTeam: isHome ? opponent : buffaloTeam
            )
            
            // First 'wins' games are wins, rest are losses
            if week <= wins {
                game.homeScore = isHome ? 28 : 21
                game.awayScore = isHome ? 21 : 28
            } else {
                game.homeScore = isHome ? 17 : 24
                game.awayScore = isHome ? 24 : 17
            }
            
            game.isCompleted = true
            games.append(game)
        }
        
        return games
    }
} 