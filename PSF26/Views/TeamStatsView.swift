import SwiftUI

// MARK: - Team Stats View (User Team Only)
struct TeamStatsView: View {
    @ObservedObject var leagueManager: LeagueManager
    let userTeam: TeamData
    let leagueId: UUID? // Phase 5: Add league context for player details
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatCategory: LeagueManager.StatCategory = .passingYards
    
    init(leagueManager: LeagueManager, userTeam: TeamData, leagueId: UUID? = nil) {
        self.leagueManager = leagueManager
        self.userTeam = userTeam
        self.leagueId = leagueId
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                teamStatsHeader
                
                // Stats Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Offensive Team Stats Card
                        offensiveTeamStatsCard
                        
                        // Defensive Team Stats Card
                        defensiveTeamStatsCard
                        
                        // Special Teams Stats Card
                        specialTeamsStatsCard
                        
                        // Player Stats Card
                        teamPlayerStatsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("\(userTeam.name) Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Team Stats Header
    private var teamStatsHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Image(userTeam.logoName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                
                Text("\(userTeam.name) Player Statistics")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            
            Divider()
        }
    }
    
    // MARK: - Offensive Team Stats Card
    private var offensiveTeamStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Offensive Stats")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let teamStats = leagueManager.getTeamSeasonStats(teamLogoName: userTeam.logoName) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    StatCard(title: "Points/Game", value: String(format: "%.1f", teamStats.pointsPerGame), style: .highlighted(.blue))
                    StatCard(title: "Total Yards", value: String(format: "%.0f", teamStats.yardsPerGame), style: .highlighted(.green))
                    StatCard(title: "Pass Yards", value: "\(teamStats.totalPassingYards)", style: .highlighted(.orange))
                    StatCard(title: "Rush Yards", value: "\(teamStats.totalRushingYards)", style: .highlighted(.purple))
                    StatCard(title: "Total TDs", value: "\(teamStats.totalTouchdowns)", style: .highlighted(.red))
                    StatCard(title: "1st Downs", value: "\(teamStats.totalFirstDowns)", style: .highlighted(.cyan))
                    StatCard(title: "3rd Down %", value: String(format: "%.1f%%", teamStats.thirdDownPercentage), style: .highlighted(.mint))
                    StatCard(title: "Red Zone %", value: String(format: "%.1f%%", teamStats.redZonePercentage), style: .highlighted(.pink))
                }
            } else {
                Text("Offensive stats will be available after games are played")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Defensive Team Stats Card
    private var defensiveTeamStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Defensive Stats")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let teamStats = leagueManager.getTeamSeasonStats(teamLogoName: userTeam.logoName) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    StatCard(title: "Points Allow", value: String(format: "%.1f", teamStats.pointsAllowedPerGame), style: .highlighted(.red))
                    StatCard(title: "Yards Allow", value: String(format: "%.0f", teamStats.yardsAllowedPerGame), style: .highlighted(.orange))
                    StatCard(title: "Pass Yds Allow", value: "\(teamStats.passingYardsAllowed)", style: .highlighted(.yellow))
                    StatCard(title: "Rush Yds Allow", value: "\(teamStats.rushingYardsAllowed)", style: .highlighted(.brown))
                    StatCard(title: "Sacks", value: "\(teamStats.sacksAllowed)", style: .highlighted(.blue))
                    StatCard(title: "Interceptions", value: "\(teamStats.interceptionsForced)", style: .highlighted(.green))
                    StatCard(title: "Fumbles Forced", value: "\(teamStats.fumblesForced)", style: .highlighted(.purple))
                    StatCard(title: "Def TDs", value: "\(teamStats.defensiveTouchdowns)", style: .highlighted(.cyan))
                }
            } else {
                Text("Defensive stats will be available after games are played")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Special Teams Stats Card
    private var specialTeamsStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Special Teams Stats")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let teamStats = leagueManager.getTeamSeasonStats(teamLogoName: userTeam.logoName) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    StatCard(title: "Field Goals", value: "\(teamStats.fieldGoalsMade)/\(teamStats.fieldGoalsAttempted)", style: .highlighted(.blue))
                    StatCard(title: "FG %", value: String(format: "%.1f%%", teamStats.fieldGoalPercentage), style: .highlighted(.green))
                    StatCard(title: "Extra Points", value: "\(teamStats.extraPointsMade)/\(teamStats.extraPointsAttempted)", style: .highlighted(.orange))
                    StatCard(title: "Total Punts", value: "\(teamStats.totalPunts)", style: .highlighted(.purple))
                }
            } else {
                Text("Special teams stats will be available after games are played")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Team Player Stats Card
    private var teamPlayerStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Player Leaders")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Stat category picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach([LeagueManager.StatCategory.passingYards, .rushingYards, .receivingYards, .passingTouchdowns, .rushingTouchdowns, .receivingTouchdowns, .tackles, .sacks, .interceptions, .fieldGoals], id: \.self) { category in
                        Button {
                            selectedStatCategory = category
                        } label: {
                            Text(categoryDisplayName(category))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(selectedStatCategory == category ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedStatCategory == category ? Color.blue : Color(.systemGray6))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Team players list for selected category
            let teamPlayers = leagueManager.getTeamLeaders(teamLogoName: userTeam.logoName, category: selectedStatCategory, limit: 10)
            
            if teamPlayers.isEmpty {
                Text("No player stats available yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(teamPlayers.enumerated()), id: \.element.id) { index, player in
                        TeamPlayerRow(
                            rank: index + 1,
                            player: player,
                            statValue: getStatValue(player: player, category: selectedStatCategory),
                            statLabel: getStatLabel(category: selectedStatCategory),
                            leagueId: leagueId,
                            leagueManager: leagueManager
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Functions
    private func categoryDisplayName(_ category: LeagueManager.StatCategory) -> String {
        switch category {
        case .passingYards: return "Pass Yds"
        case .rushingYards: return "Rush Yds"
        case .receivingYards: return "Rec Yds"
        case .passingTouchdowns: return "Pass TDs"
        case .rushingTouchdowns: return "Rush TDs"
        case .receivingTouchdowns: return "Rec TDs"
        case .tackles: return "Tackles"
        case .sacks: return "Sacks"
        case .interceptions: return "INTs"
        case .fieldGoals: return "FGs"
        }
    }
    
    private func getStatValue(player: PlayerSeasonStats, category: LeagueManager.StatCategory) -> String {
        switch category {
        case .passingYards: return "\(player.passingYards)"
        case .rushingYards: return "\(player.rushingYards)"
        case .receivingYards: return "\(player.receivingYards)"
        case .passingTouchdowns: return "\(player.passingTouchdowns)"
        case .rushingTouchdowns: return "\(player.rushingTouchdowns)"
        case .receivingTouchdowns: return "\(player.receivingTouchdowns)"
        case .tackles: return "\(player.tackles)"
        case .sacks: return "\(player.sacksMade)"
        case .interceptions: return "\(player.interceptionsDefense)"
        case .fieldGoals: return "\(player.fieldGoalsMade)"
        }
    }
    
    private func getStatLabel(category: LeagueManager.StatCategory) -> String {
        switch category {
        case .passingYards, .rushingYards, .receivingYards: return "yards"
        case .passingTouchdowns, .rushingTouchdowns, .receivingTouchdowns: return "TDs"
        case .tackles: return "tackles"
        case .sacks: return "sacks"
        case .interceptions: return "INTs"
        case .fieldGoals: return "FGs"
        }
    }
}

// MARK: - Team Player Row
struct TeamPlayerRow: View {
    let rank: Int
    let player: PlayerSeasonStats
    let statValue: String
    let statLabel: String
    let leagueId: UUID?
    let leagueManager: LeagueManager?
    @State private var showingPlayerDetail = false
    
    init(rank: Int, player: PlayerSeasonStats, statValue: String, statLabel: String, leagueId: UUID? = nil, leagueManager: LeagueManager? = nil) {
        self.rank = rank
        self.player = player
        self.statValue = statValue
        self.statLabel = statLabel
        self.leagueId = leagueId
        self.leagueManager = leagueManager
    }
    
    var body: some View {
        Button(action: {
            showingPlayerDetail = true
        }) {
            HStack {
                // Rank
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                // Player info
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.playerName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(player.position)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                // Stat value
                VStack(alignment: .trailing, spacing: 2) {
                    Text(statValue)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text(statLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Navigation indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingPlayerDetail) {
            PlayerDetailView(
                player: player.toPlayerData(),
                teamLogoName: player.teamLogoName,
                leagueId: leagueId,
                isEditable: leagueId != nil,
                leagueManager: leagueManager
            )
        }
    }
}

// MARK: - Preview
#Preview {
    TeamStatsView(
        leagueManager: LeagueManager(),
        userTeam: TeamData.createTeamFromData(name: "Chicago"),
        leagueId: UUID()
    )
} 