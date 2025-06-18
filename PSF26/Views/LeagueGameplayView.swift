import SwiftUI
import Combine

// MARK: - League Gameplay View
struct LeagueGameplayView: View {
    let selectedTeam: TeamData
    let settings: LeagueGameplaySettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var leagueManager = LeagueManager()
    @State private var currentWeek: Int = 1
    @State private var showingGameSimulation = false
    @State private var selectedGame: GameResult?
    @State private var showingSeasonStats = false
    @State private var showingStandings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // League Header
                        leagueHeaderView
                        
                        // Current Week Section
                        currentWeekSection
                        
                        // Quick Stats
                        quickStatsSection
                        
                        // Recent Games
                        if !leagueManager.completedGames.isEmpty {
                            recentGamesSection
                        }
                        
                        // League Standings Preview
                        standingsPreviewSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("PSF26 League")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back to Teams") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("View Standings", systemImage: "list.number") {
                            showingStandings = true
                        }
                        
                        Button("Season Stats", systemImage: "chart.bar.fill") {
                            showingSeasonStats = true
                        }
                        
                        Divider()
                        
                        Button("Simulate to Playoffs", systemImage: "forward.fill") {
                            simulateToPlayoffs()
                        }
                        
                        Button("Simulate Full Season", systemImage: "forward.end.fill") {
                            simulateFullSeason()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            .onAppear {
                leagueManager.setupLeague(selectedTeam: selectedTeam, settings: settings)
            }
            .sheet(isPresented: $showingGameSimulation) {
                if let game = selectedGame {
                    GameSimulationView(
                        game: game,
                        onGameCompleted: { result in
                            leagueManager.updateGameResult(result)
                            showingGameSimulation = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showingStandings) {
                LeagueStandingsView(leagueManager: leagueManager)
            }
            .sheet(isPresented: $showingSeasonStats) {
                SeasonStatsView(leagueManager: leagueManager)
            }
        }
    }
    
    // MARK: - League Header
    private var leagueHeaderView: some View {
        VStack(spacing: 16) {
            HStack {
                // Team logo and info
                HStack(spacing: 16) {
                    Image(selectedTeam.logoName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedTeam.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("\(leagueManager.teamRecord.wins)-\(leagueManager.teamRecord.losses)-\(leagueManager.teamRecord.ties)")
                            .font(.headline)
                            .foregroundColor(Color(hex: selectedTeam.primaryColor))
                    }
                    
                    Spacer()
                }
                
                // Season info
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Week \(currentWeek)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("2025 Season")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: selectedTeam.primaryColor).opacity(0.1), location: 0.0),
                    .init(color: Color(hex: selectedTeam.secondaryColor).opacity(0.1), location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: selectedTeam.primaryColor).opacity(0.3), lineWidth: 1.5)
        )
    }
    
    // MARK: - Current Week Section
    private var currentWeekSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Week \(currentWeek) Games")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if leagueManager.hasUpcomingGames(week: currentWeek) {
                    Button("Simulate Week") {
                        simulateCurrentWeek()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            
            LazyVStack(spacing: 12) {
                ForEach(leagueManager.getGamesForWeek(currentWeek)) { game in
                    CurrentWeekGameRow(
                        game: game,
                        isUserTeam: game.homeTeam.logoName == selectedTeam.logoName || game.awayTeam.logoName == selectedTeam.logoName
                    ) {
                        selectedGame = game
                        showingGameSimulation = true
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Stats Section
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Season Progress")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                QuickStatCard(
                    title: "Games Played",
                    value: "\(leagueManager.teamRecord.gamesPlayed)",
                    subtitle: "of 17",
                    color: .blue
                )
                
                QuickStatCard(
                    title: "Division Rank",
                    value: "#\(leagueManager.getDivisionRank(for: selectedTeam))",
                    subtitle: "NFC North",
                    color: .orange
                )
                
                QuickStatCard(
                    title: "Playoff Odds",
                    value: "\(leagueManager.getPlayoffOdds(for: selectedTeam))%",
                    subtitle: "chance",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Recent Games Section
    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Recent Games")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(leagueManager.getRecentGames(for: selectedTeam).prefix(3)) { game in
                    RecentGameRow(game: game, userTeam: selectedTeam)
                }
            }
        }
    }
    
    // MARK: - Standings Preview Section
    private var standingsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.number")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Division Standings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View All") {
                    showingStandings = true
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                ForEach(leagueManager.getDivisionStandings(for: selectedTeam).prefix(4)) { team in
                    DivisionStandingRow(team: team, isUserTeam: team.logoName == selectedTeam.logoName)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func simulateCurrentWeek() {
        withAnimation(.easeInOut(duration: 0.5)) {
            leagueManager.simulateWeek(currentWeek)
            if currentWeek < 18 {
                currentWeek += 1
            }
        }
    }
    
    private func simulateToPlayoffs() {
        withAnimation(.easeInOut(duration: 0.8)) {
            leagueManager.simulateToPlayoffs()
            currentWeek = 18
        }
    }
    
    private func simulateFullSeason() {
        withAnimation(.easeInOut(duration: 1.0)) {
            leagueManager.simulateFullSeason()
            currentWeek = 18
        }
    }
}

// MARK: - Quick Stat Card
struct QuickStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Current Week Game Row
struct CurrentWeekGameRow: View {
    let game: GameResult
    let isUserTeam: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Away Team
                HStack(spacing: 12) {
                    Image(game.awayTeam.logoName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TeamData.getTeamDisplayName(game.awayTeam.logoName))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("\(game.awayTeam.record.wins)-\(game.awayTeam.record.losses)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Game Info
                VStack(spacing: 4) {
                    if game.isCompleted {
                        HStack(spacing: 8) {
                            Text("\(game.awayScore)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(game.awayScore > game.homeScore ? .green : .secondary)
                            
                            Text("-")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            Text("\(game.homeScore)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(game.homeScore > game.awayScore ? .green : .secondary)
                        }
                        
                        Text("Final")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("@")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text("Simulate")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Home Team
                HStack(spacing: 12) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TeamData.getTeamDisplayName(game.homeTeam.logoName))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("\(game.homeTeam.record.wins)-\(game.homeTeam.record.losses)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(game.homeTeam.logoName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Game Row
struct RecentGameRow: View {
    let game: GameResult
    let userTeam: TeamData
    
    private var isUserTeamHome: Bool {
        game.homeTeam.logoName == userTeam.logoName
    }
    
    private var userTeamWon: Bool {
        if isUserTeamHome {
            return game.homeScore > game.awayScore
        } else {
            return game.awayScore > game.homeScore
        }
    }
    
    private var opponent: LeagueTeam {
        isUserTeamHome ? game.awayTeam : game.homeTeam
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Result indicator
            Circle()
                .fill(userTeamWon ? .green : .red)
                .frame(width: 12, height: 12)
            
            // Week and opponent
            VStack(alignment: .leading, spacing: 2) {
                Text("Week \(game.week)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Text(isUserTeamHome ? "vs" : "@")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(TeamData.getTeamDisplayName(opponent.logoName))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // Score
            HStack(spacing: 8) {
                if isUserTeamHome {
                    Text("\(game.homeScore)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(userTeamWon ? .green : .red)
                    
                    Text("-")
                        .foregroundColor(.secondary)
                    
                    Text("\(game.awayScore)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(game.awayScore)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(userTeamWon ? .green : .red)
                    
                    Text("-")
                        .foregroundColor(.secondary)
                    
                    Text("\(game.homeScore)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
            
            // Result
            Text(userTeamWon ? "W" : "L")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(userTeamWon ? .green : .red)
                .frame(width: 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Division Standing Row
struct DivisionStandingRow: View {
    let team: LeagueTeam
    let isUserTeam: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("\(team.divisionRank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(isUserTeam ? .blue : .primary)
                .frame(width: 24)
            
            // Team logo and name
            HStack(spacing: 12) {
                Image(team.logoName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                
                Text(TeamData.getTeamDisplayName(team.logoName))
                    .font(.subheadline)
                    .fontWeight(isUserTeam ? .bold : .medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Record
            Text("\(team.record.wins)-\(team.record.losses)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isUserTeam ? .blue : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isUserTeam ? .blue.opacity(0.1) : .clear)
        )
    }
}

#Preview {
    LeagueGameplayView(
        selectedTeam: TeamData.createTeamFromData(name: "Chicago"),
        settings: LeagueGameplaySettings.defaultSettings()
    )
}
