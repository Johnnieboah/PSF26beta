import SwiftUI
import GameKit
import Foundation
import Combine

// MARK: - Game Center Manager
// Handles authentication, leaderboards, achievements, and multiplayer for football simulation

@MainActor
class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var localPlayer: GKLocalPlayer?
    @Published var authenticationError: String?
    @Published var leaderboards: [GKLeaderboard] = []
    @Published var achievements: [GKAchievement] = []
    @Published var friends: [GKPlayer] = []
    
    // MARK: - Game Center Status
    @Published var isGameCenterAvailable = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupGameCenter()
    }
    
    // MARK: - Game Center Setup
    private func setupGameCenter() {
        guard GKLocalPlayer.local.isAuthenticated == false else {
            // Already authenticated
            handleAuthentication()
            return
        }
        
        isGameCenterAvailable = true
        connectionStatus = .connecting
        
        // Set authentication handler
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                self?.handleAuthenticationResult(viewController: viewController, error: error)
            }
        }
    }
    
    /// Public method to trigger Game Center authentication
    func authenticatePlayer() async {
        await MainActor.run {
            // Check if already authenticated
            if GKLocalPlayer.local.isAuthenticated {
                handleAuthentication()
                return
            }
            
            // Start authentication process
            setupGameCenter()
        }
    }
    
    private func handleAuthenticationResult(viewController: UIViewController?, error: Error?) {
        if let error = error {
            authenticationError = error.localizedDescription
            connectionStatus = .error(error.localizedDescription)
            print("❌ Game Center authentication failed: \(error.localizedDescription)")
            
            // Check if this is the "app not recognized" error (common in development)
            if error.localizedDescription.contains("not recognized by Game Center") {
                print("ℹ️ App not registered with Game Center - this is normal during development")
                print("ℹ️ Make sure to enable Game Center in App Store Connect for production")
            }
            return
        }
        
        if let viewController = viewController {
            // Present authentication view controller
            // iOS 26: Handle authentication UI presentation
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                print("⚠️ Cannot present authentication UI")
                return
            }
            rootViewController.present(viewController, animated: true)
        } else {
            // Authentication successful
            handleAuthentication()
        }
    }
    
    private func handleAuthentication() {
        let player = GKLocalPlayer.local
        isAuthenticated = player.isAuthenticated
        localPlayer = player
        
        if isAuthenticated {
            connectionStatus = .connected
            print("✅ Game Center authenticated: \(player.displayName)")
            
            // Load initial data
            Task {
                await loadGameCenterData()
            }
        } else {
            connectionStatus = .disconnected
            print("⚠️ Game Center not authenticated")
        }
    }
    
    // MARK: - Data Loading
    private func loadGameCenterData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadLeaderboards() }
            group.addTask { await self.loadAchievements() }
            group.addTask { await self.loadFriends() }
        }
    }
    
    // MARK: - Leaderboards
    
    /// Load all available leaderboards
    private func loadLeaderboards() async {
        do {
            let loadedLeaderboards = try await GKLeaderboard.loadLeaderboards(IDs: LeaderboardIDs.allCases.map { $0.rawValue })
            await MainActor.run {
                self.leaderboards = loadedLeaderboards
                print("✅ Loaded \(loadedLeaderboards.count) leaderboards")
            }
        } catch {
            print("❌ Failed to load leaderboards: \(error)")
        }
    }
    
    /// Submit score to leaderboard
    func submitScore(_ score: Int, to leaderboardID: LeaderboardIDs) async {
        guard isAuthenticated else {
            print("⚠️ Cannot submit score: not authenticated")
            return
        }
        
        do {
            // iOS 26 API: Use GKLeaderboard.submitScore with correct signature
            let leaderboard = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID.rawValue]).first
            guard let leaderboard = leaderboard else {
                print("❌ Could not load leaderboard: \(leaderboardID.rawValue)")
                return
            }
            try await leaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local)
            print("✅ Score \(score) submitted to \(leaderboardID.rawValue)")
        } catch {
            print("❌ Failed to submit score: \(error)")
        }
    }
    
    /// Test Game Center integration with simple score and achievement
    func testGameCenter() async {
        guard isAuthenticated else {
            print("❌ Not authenticated with Game Center")
            return
        }
        
        print("🧪 Testing Game Center integration...")
        
        // Submit a test score
        let testScore = Int.random(in: 1...100)
        await submitScore(testScore, to: .test)
        
        // Report test achievement
        await reportAchievement(.test, percentComplete: 100.0)
        
        print("✅ Game Center test completed!")
    }
    
    // MARK: - Achievements
    
    /// Load player's achievements
    private func loadAchievements() async {
        do {
            let loadedAchievements = try await GKAchievement.loadAchievements()
            await MainActor.run {
                self.achievements = loadedAchievements
                print("✅ Loaded \(loadedAchievements.count) achievements")
            }
        } catch {
            print("❌ Failed to load achievements: \(error)")
        }
    }
    
    /// Report achievement progress
    func reportAchievement(_ achievementID: AchievementIDs, percentComplete: Double) async {
        guard isAuthenticated else {
            print("⚠️ Cannot report achievement: not authenticated")
            return
        }
        
        let achievement = GKAchievement(identifier: achievementID.rawValue)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = percentComplete >= 100.0
        
        do {
            try await GKAchievement.report([achievement])
            print("✅ Achievement \(achievementID.rawValue) reported: \(percentComplete)%")
        } catch {
            print("❌ Failed to report achievement: \(error)")
        }
    }
    
    /// Load player's friends
    private func loadFriends() async {
        guard isAuthenticated else { return }
        
        do {
            let loadedFriends = try await GKLocalPlayer.local.loadFriends()
            await MainActor.run {
                self.friends = loadedFriends
                print("✅ Loaded \(loadedFriends.count) friends")
            }
        } catch {
            print("❌ Failed to load friends: \(error)")
        }
    }
}

// MARK: - Leaderboard IDs
enum LeaderboardIDs: String, CaseIterable {
    case test = "Test"
    
    var displayName: String {
        switch self {
        case .test: return "Test Leaderboard"
        }
    }
    
    var description: String {
        switch self {
        case .test: return "Test leaderboard for development"
        }
    }
}

// MARK: - Achievement IDs
enum AchievementIDs: String, CaseIterable {
    case test = "Test"
    
    var displayName: String {
        switch self {
        case .test: return "Test Achievement"
        }
    }
    
    var description: String {
        switch self {
        case .test: return "Test achievement for development"
        }
    }
}

// MARK: - Player Milestones
enum PlayerMilestone {
    case passingYards
    case rushingYards
    case receivingYards
    case touchdowns
}