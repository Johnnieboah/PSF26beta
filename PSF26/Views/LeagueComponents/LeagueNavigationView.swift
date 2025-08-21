import SwiftUI

// MARK: - League Navigation Hub
struct LeagueNavigationView: View {
    let teamName: String
    let teamData: TeamData
    @Environment(\.dismiss) private var dismiss
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @StateObject private var performanceManager = AdvancedPerformanceManager.shared
    
    var body: some View {
        NavigationStack(path: $navigationCoordinator.navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    // Enhanced Team Header
                    LeagueTeamHeaderView(teamData: teamData)
                        .glassCard()
                        .padding(.horizontal)
                    
                    // Quick Actions Grid
                    LeagueQuickActionsView(teamName: teamName, teamData: teamData)
                        .padding(.horizontal)
                    
                    // League Stats Overview
                    LeagueStatsOverviewView(teamName: teamName)
                        .padding(.horizontal)
                    
                    // Recent Activity
                    LeagueRecentActivityView(teamName: teamName)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .iOS26Enhanced()
            .performanceOptimized(identifier: "LeagueNavigation-\(teamName)")
            .navigationDestination(for: NavigationCoordinator.NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .sheet(item: $navigationCoordinator.presentedSheet) { destination in
            sheetView(for: destination)
        }
        .fullScreenCover(item: $navigationCoordinator.presentedFullScreen) { destination in
            fullScreenView(for: destination)
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationCoordinator.NavigationDestination) -> some View {
        switch destination {
        case .teamManagement(let team, let conference):
            TeamManagementView(teamName: team, conference: conference)
        case .leagueHub(let team):
            LeagueHubView(teamName: team, teamLogoName: team, customLogoData: nil)
        case .gameSimulation(let home, let away):
            SimpleGameSimulationView(homeTeam: home, awayTeam: away)
        case .settings:
            SettingsView()
        case .createLeague:
            CreateLeagueView()
        case .loadLeague:
            LoadLeagueView()
        }
    }
    
    @ViewBuilder
    private func sheetView(for destination: NavigationCoordinator.NavigationDestination) -> some View {
        NavigationStack(path: $navigationCoordinator.navigationPath) {
            destinationView(for: destination)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            navigationCoordinator.dismissSheet()
                        }
                    }
                }
        }
    }
    
    @ViewBuilder
    private func fullScreenView(for destination: NavigationCoordinator.NavigationDestination) -> some View {
        destinationView(for: destination)
    }
}

// MARK: - Enhanced Team Header
struct LeagueTeamHeaderView: View {
    let teamData: TeamData
    @StateObject private var performanceManager = AdvancedPerformanceManager.shared
    
    var body: some View {
        HStack(spacing: 20) {
            // Team Logo with Performance Optimization
            OptimizedAsyncImage(
                teamName: teamData.logoName,
                size: CGSize(width: 80, height: 80)
            )
            .pressableScale()
            .hoverEffect()
            
            VStack(alignment: .leading, spacing: 8) {
                // Team Name
                Text(teamData.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Team City
                HStack(spacing: 12) {
                    Text(TeamData.getTeamCityName(teamData.logoName))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                                            Text("PFL Team")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                // Team Rating
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text("Overall: 85")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // Performance Indicator
            VStack(alignment: .trailing, spacing: 4) {
                if performanceManager.performanceMetrics.memoryPressure == .normal {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                }
                
                Text("Optimized")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }
}

// MARK: - Quick Actions Grid
struct LeagueQuickActionsView: View {
    let teamName: String
    let teamData: TeamData
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    
    private let actions = [
        QuickAction(
            title: "Team Roster",
            subtitle: "Manage Players",
            icon: "person.3.fill",
            color: .blue,
            destination: .teamManagement
        ),
        QuickAction(
            title: "Schedule",
            subtitle: "View Games",
            icon: "calendar.badge.clock",
            color: .green,
            destination: .schedule
        ),
        QuickAction(
            title: "Standings",
            subtitle: "League Rank",
            icon: "chart.bar.fill",
            color: .orange,
            destination: .standings
        ),
        QuickAction(
            title: "Simulate",
            subtitle: "Play Game",
            icon: "play.circle.fill",
            color: .red,
            destination: .simulation
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(actions) { action in
                    QuickActionCard(
                        action: action,
                        teamData: teamData
                    ) {
                        handleActionTap(action)
                    }
                }
            }
        }
    }
    
    private func handleActionTap(_ action: QuickAction) {
        HapticManager.shared.impact(.medium)
        
        // Note: Consider refactoring to append to navigationPath instead of using coordinator's stack for navigation
        switch action.destination {
        case .teamManagement:
            navigationCoordinator.navigate(to: .teamManagement(teamName, "NFC"))
        case .schedule:
            navigationCoordinator.presentSheet(.teamManagement(teamName, "NFC"))
        case .standings:
            // Navigate to standings view
            break
        case .simulation:
            navigationCoordinator.presentFullScreen(.gameSimulation(teamName, "Opponent"))
        }
    }
}

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: ActionDestination
    
    enum ActionDestination {
        case teamManagement, schedule, standings, simulation
    }
}

struct QuickActionCard: View {
    let action: QuickAction
    let teamData: TeamData
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.title)
                    .foregroundColor(action.color)
                
                VStack(spacing: 4) {
                    Text(action.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(action.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .buttonStyle(.plain)
        .neuomorphicCard()
        .pressableScale()
        .hoverEffect()
    }
}

// MARK: - League Stats Overview
struct LeagueStatsOverviewView: View {
    let teamName: String
    @StateObject private var masterDataLoader = MasterDataLoader.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("League Overview")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                StatOverviewCard(
                    title: "Current Week",
                    value: "12",
                    subtitle: "of 18",
                    color: .blue
                )
                
                StatOverviewCard(
                    title: "Teams",
                    value: "32",
                                            subtitle: "PFL Teams",
                    color: .green
                )
                
                StatOverviewCard(
                    title: "Games",
                    value: "267",
                    subtitle: "Completed",
                    color: .orange
                )
            }
        }
    }
}

struct StatOverviewCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCard()
    }
}

// MARK: - Recent Activity
struct LeagueRecentActivityView: View {
    let teamName: String
    
    private let recentActivities = [
        RecentActivity(
            title: "Game Completed",
            description: "Bears defeated Packers 24-17",
            time: "2 hours ago",
            icon: "checkmark.circle.fill",
            color: .green
        ),
        RecentActivity(
            title: "Injury Report",
            description: "QB Justin Fields - Questionable",
            time: "5 hours ago",
            icon: "exclamationmark.triangle.fill",
            color: .orange
        ),
        RecentActivity(
            title: "Trade Completed",
            description: "Acquired WR from Lions",
            time: "1 day ago",
            icon: "arrow.triangle.swap",
            color: .blue
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(recentActivities) { activity in
                    RecentActivityRow(activity: activity)
                }
            }
        }
    }
}

struct RecentActivity: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let time: String
    let icon: String
    let color: Color
}

struct RecentActivityRow: View {
    let activity: RecentActivity
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: activity.icon)
                .font(.title3)
                .foregroundColor(activity.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(activity.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(activity.time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .glassCard()
        .pressableScale(scale: 0.98)
    }
}

// MARK: - Simple Game Simulation View
struct SimpleGameSimulationView: View {
    let homeTeam: String
    let awayTeam: String
    @Environment(\.dismiss) private var dismiss
    @State private var homeScore = 0
    @State private var awayScore = 0
    @State private var isSimulating = false
    @State private var gameCompleted = false
    @State private var currentQuarter = 1
    @State private var timeRemaining = "15:00"
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(.systemBackground), location: 0.0),
                        .init(color: Color(.systemGray6), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Game Header
                        gameHeaderView
                        
                        // Score Display
                        scoreDisplayView
                        
                        // Game Controls
                        gameControlsView
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Game Simulation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var gameHeaderView: some View {
        VStack(spacing: 16) {
                            Text("2025 PFL Season")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(1)
            
            HStack(spacing: 40) {
                // Away Team
                VStack(spacing: 12) {
                    Image(awayTeam)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text(TeamData.getTeamDisplayName(awayTeam))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                
                // VS
                Text("@")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Home Team
                VStack(spacing: 12) {
                    Image(homeTeam)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text(TeamData.getTeamDisplayName(homeTeam))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .standardCard(.ultraThin16)
    }
    
    private var scoreDisplayView: some View {
        HStack(spacing: 60) {
            // Away Score
            VStack(spacing: 8) {
                Text("\(awayScore)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(awayScore > homeScore ? .green : .primary)
                
                Text("Away")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
            }
            
            // Score Separator
            Rectangle()
                .fill(.secondary.opacity(0.3))
                .frame(width: 2, height: 60)
            
            // Home Score
            VStack(spacing: 8) {
                Text("\(homeScore)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(homeScore > awayScore ? .green : .primary)
                
                Text("Home")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .standardCard(.ultraThin16)
    }
    
    private var gameControlsView: some View {
        VStack(spacing: 16) {
            if !gameCompleted {
                Text("Q\(currentQuarter) - \(timeRemaining)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Button(action: simulatePlay) {
                    HStack {
                        if isSimulating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(isSimulating ? "Simulating..." : "Simulate Play")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
                .disabled(isSimulating)
                
                Button(action: simulateGame) {
                    HStack {
                        Image(systemName: "forward.fill")
                        Text("Simulate Full Game")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
                .disabled(isSimulating)
            } else {
                VStack(spacing: 12) {
                    Text("Final Score")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    let winner = homeScore > awayScore ? homeTeam : awayTeam
                    Text("\(TeamData.getTeamDisplayName(winner)) Wins!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .standardCard(.ultraThin16)
    }
    
    private func simulatePlay() {
        guard !gameCompleted else { return }
        
        isSimulating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Random play outcome
            let scoreChange = Int.random(in: 0...7)
            let teamScoring = Bool.random()
            
            if teamScoring {
                homeScore += scoreChange
            } else {
                awayScore += scoreChange
            }
            
            // Update game time
            updateGameTime()
            
            isSimulating = false
        }
    }
    
    private func simulateGame() {
        guard !gameCompleted else { return }
        
        isSimulating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Generate final scores
            homeScore = Int.random(in: 14...35)
            awayScore = Int.random(in: 10...31)
            
            currentQuarter = 4
            timeRemaining = "00:00"
            gameCompleted = true
            isSimulating = false
        }
    }
    
    private func updateGameTime() {
        if currentQuarter < 4 {
            let timeComponents = timeRemaining.split(separator: ":")
            if let minutes = Int(timeComponents[0]), let seconds = Int(timeComponents[1]) {
                let totalSeconds = minutes * 60 + seconds - Int.random(in: 30...120)
                
                if totalSeconds <= 0 {
                    currentQuarter += 1
                    timeRemaining = "15:00"
                } else {
                    let newMinutes = totalSeconds / 60
                    let newSeconds = totalSeconds % 60
                    timeRemaining = String(format: "%02d:%02d", newMinutes, newSeconds)
                }
            }
        } else {
            gameCompleted = true
            timeRemaining = "00:00"
        }
    }
} 

