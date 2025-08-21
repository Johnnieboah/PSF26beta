import Foundation
import Testing
@testable import PSF26

// Manual test runner for playoff system validation
@MainActor
class ManualTestRunner {
    
    static func runAllTests() -> Bool {
        print("🧪 Starting Manual Test Suite for Playoff Fixes")
        print("=" * 50)
        
        let tests = [
            ("Playoff Bracket Generation", testPlayoffBracketGeneration),
            ("Bracket Progression", testBracketProgression),
            ("User Elimination Detection", testUserEliminationDetection),
            ("Proper Opponent Advancement", testProperOpponentAdvancement)
        ]
        
        var allPassed = true
        
        for (testName, testFunction) in tests {
            print("\n🔍 Running: \(testName)")
            let result = testFunction()
            if result {
                print("✅ PASSED: \(testName)")
            } else {
                print("❌ FAILED: \(testName)")
                allPassed = false
            }
        }
        
        print("\n" + "=" * 50)
        print(allPassed ? "🎉 ALL TESTS PASSED!" : "💥 SOME TESTS FAILED!")
        return allPassed
    }
    
    static func testPlayoffBracketGeneration() -> Bool {
        let manager = createTestLeagueManager()
        manager.setupPlayoffs()
        
        // Verify playoff teams were selected
        guard manager.playoffTeams.count == 14 else {
            print("❌ Expected 14 playoff teams, got \(manager.playoffTeams.count)")
            return false
        }
        
        // Verify bracket was generated
        let bracket = manager.getPlayoffBracket()
        guard bracket.count == 6 else {
            print("❌ Expected 6 wild card games, got \(bracket.count)")
            return false
        }
        
        print("✅ Playoff bracket generated correctly with \(manager.playoffTeams.count) teams and \(bracket.count) games")
        return true
    }
    
    static func testBracketProgression() -> Bool {
        let manager = createTestLeagueManager()
        manager.setupPlayoffs()
        
        // Simulate Wild Card results
        let wildCardResults = [
            ("Buffalo", "Miami"),
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
        
        // Generate Divisional Round
        manager.currentWeek = 20
        manager.generateNextRoundBracket(for: 20)
        let divisionalBracket = manager.getPlayoffBracket()
        
        guard divisionalBracket.count == 4 else {
            print("❌ Expected 4 divisional games, got \(divisionalBracket.count)")
            return false
        }
        
        print("✅ Bracket progression working: Wild Card → Divisional")
        return true
    }
    
    static func testUserEliminationDetection() -> Bool {
        let manager = createTestLeagueManager()
        manager.currentWeek = 18
        manager.userTeam = TeamData.getTeam(by: "Buffalo")
        
        manager.setupPlayoffs()
        
        // User should be in wild card
        manager.currentWeek = 19
        let wildCardInfo = manager.getUserPlayoffInfo()
        guard wildCardInfo != nil else {
            print("❌ User should have wild card game")
            return false
        }
        
        // Simulate user LOSING wild card
        if let userTeam = manager.allTeams.first(where: { $0.logoName == "Buffalo" }),
           let opponentTeam = manager.allTeams.first(where: { $0.logoName == "Miami" }) {
            manager.addPlayoffResult(winner: opponentTeam, loser: userTeam, week: 19, homeScore: 24, awayScore: 17)
        }
        
        // User should be eliminated in divisional round
        manager.currentWeek = 20
        manager.generateNextRoundBracket(for: 20)
        let divisionalInfo = manager.getUserPlayoffInfo()
        
        guard divisionalInfo == nil else {
            print("❌ User should be eliminated after losing wild card")
            return false
        }
        
        print("✅ User elimination detection working correctly")
        return true
    }
    
    static func testProperOpponentAdvancement() -> Bool {
        let manager = createTestLeagueManager()
        manager.currentWeek = 18
        manager.userTeam = TeamData.getTeam(by: "Buffalo")
        
        manager.setupPlayoffs()
        
        // User WINS wild card
        manager.currentWeek = 19
        if let userTeam = manager.allTeams.first(where: { $0.logoName == "Buffalo" }),
           let opponentTeam = manager.allTeams.first(where: { $0.logoName == "Miami" }) {
            manager.addPlayoffResult(winner: userTeam, loser: opponentTeam, week: 19, homeScore: 28, awayScore: 21)
        }
        
        // Simulate other wild card games
        let otherResults = [
            ("Baltimore", "Pittsburgh"),
            ("Indianapolis", "Houston"),
            ("Detroit", "GreenBay"),
            ("Philadelphia", "Dallas"),
            ("TampaBay", "Atlanta")
        ]
        
        for (winner, loser) in otherResults {
            if let winnerTeam = manager.allTeams.first(where: { $0.logoName == winner }),
               let loserTeam = manager.allTeams.first(where: { $0.logoName == loser }) {
                manager.addPlayoffResult(winner: winnerTeam, loser: loserTeam, week: 19, homeScore: 24, awayScore: 17)
            }
        }
        
        // Generate divisional round
        manager.currentWeek = 20
        manager.generateNextRoundBracket(for: 20)
        let divisionalInfo = manager.getUserPlayoffInfo()
        
        guard let opponent = divisionalInfo?.opponent else {
            print("❌ User should have divisional opponent")
            return false
        }
        
        // User should NOT be playing Miami again (they just beat them)
        guard opponent.logoName != "Miami" else {
            print("❌ User should not play Miami again after beating them")
            return false
        }
        
        print("✅ User correctly advanced to play \(opponent.name) (not Miami)")
        return true
    }
    
    // MARK: - Helper Methods
    
    static func createTestLeagueManager() -> LeagueManager {
        let manager = LeagueManager()
        manager.allTeams = createTestTeams()
        manager.currentWeek = 18
        manager.userTeam = TeamData.getTeam(by: "Buffalo")
        return manager
    }
    
    static func createTestTeams() -> [LeagueTeam] {
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