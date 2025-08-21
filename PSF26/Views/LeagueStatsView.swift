import SwiftUI

// MARK: - League Stats View (Full League with User Team Highlighting)
struct LeagueStatsView: View {
    @ObservedObject var leagueManager: LeagueManager
    let userTeam: LeagueTeam
    let leagueId: UUID? // Phase 5: Add league context for player details
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: LeagueStatsTab = .teams
    @State private var showingDetailedStats = false
    @State private var selectedDetailCategory: LeagueManager.StatCategory = .passingYards
    
    init(leagueManager: LeagueManager, userTeam: LeagueTeam, leagueId: UUID? = nil) {
        self.leagueManager = leagueManager
        self.userTeam = userTeam
        self.leagueId = leagueId
    }
    
    enum LeagueStatsTab: String, CaseIterable {
        case teams = "Teams"
        case players = "Players"
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Teams Tab
                teamStatsContent
                    .tabItem {
                        Image(systemName: "person.3.fill")
                        Text("Teams")
                    }
                    .tag(LeagueStatsTab.teams)
                
                // Players Tab
                playerStatsContent
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Players")
                    }
                    .tag(LeagueStatsTab.players)
            }
            .navigationTitle("League Stats")
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
        .sheet(isPresented: $showingDetailedStats) {
            DetailedStatsView(
                leagueManager: leagueManager,
                userTeam: userTeam,
                category: selectedDetailCategory,
                isTeamStats: selectedTab == .teams,
                leagueId: leagueId
            )
        }
    }
    

    
    // MARK: - Team Stats Content
    private var teamStatsContent: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach([LeagueManager.StatCategory.passingYards, .rushingYards, .receivingYards, .passingTouchdowns, .rushingTouchdowns, .receivingTouchdowns, .tackles, .sacks, .interceptions, .fieldGoals], id: \.self) { category in
                    TeamStatContainer(
                        category: category,
                        leagueManager: leagueManager,
                        userTeam: userTeam,
                        onTap: {
                            selectedDetailCategory = category
                            showingDetailedStats = true
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Player Stats Content
    private var playerStatsContent: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach([LeagueManager.StatCategory.passingYards, .rushingYards, .receivingYards, .passingTouchdowns, .rushingTouchdowns, .receivingTouchdowns, .tackles, .sacks, .interceptions, .fieldGoals], id: \.self) { category in
                    PlayerStatContainer(
                        category: category,
                        leagueManager: leagueManager,
                        userTeam: userTeam,
                        onTap: {
                            selectedDetailCategory = category
                            showingDetailedStats = true
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }
    

}

// MARK: - Team Stat Container
struct TeamStatContainer: View {
    let category: LeagueManager.StatCategory
    @ObservedObject var leagueManager: LeagueManager
    let userTeam: LeagueTeam
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text(categoryDisplayName(category))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Top 5 teams
                let topTeams = getTopTeams(for: category)
                
                if topTeams.isEmpty {
                    Text("No data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(topTeams.prefix(5).enumerated()), id: \.element.teamLogoName) { index, teamRanking in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(teamRanking.teamLogoName == userTeam.logoName ? .blue : .secondary)
                                    .frame(width: 16)
                                
                                Image(teamRanking.teamLogoName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                
                                Text(TeamData.getTeamDisplayName(teamRanking.teamLogoName))
                                    .font(.caption)
                                    .fontWeight(teamRanking.teamLogoName == userTeam.logoName ? .bold : .medium)
                                    .foregroundColor(teamRanking.teamLogoName == userTeam.logoName ? .blue : .primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text("\(teamRanking.totalStat)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(teamRanking.teamLogoName == userTeam.logoName ? .blue : .primary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func getTopTeams(for category: LeagueManager.StatCategory) -> [TeamRanking] {
        var teamTotals: [String: Int] = [:]
        
        for player in leagueManager.playerSeasonStats.values {
            let statValue = getStatValueInt(player: player, category: category)
            teamTotals[player.teamLogoName, default: 0] += statValue
        }
        
        return teamTotals.map { teamLogoName, totalStat in
            TeamRanking(teamLogoName: teamLogoName, totalStat: totalStat)
        }.sorted { 
            if $0.totalStat != $1.totalStat {
                return $0.totalStat > $1.totalStat
            }
            return $0.teamLogoName < $1.teamLogoName // Stable tie-breaker
        }
    }
    
    private func getStatValueInt(player: PlayerSeasonStats, category: LeagueManager.StatCategory) -> Int {
        switch category {
        case .passingYards: return player.passingYards
        case .rushingYards: return player.rushingYards
        case .receivingYards: return player.receivingYards
        case .passingTouchdowns: return player.passingTouchdowns
        case .rushingTouchdowns: return player.rushingTouchdowns
        case .receivingTouchdowns: return player.receivingTouchdowns
        case .tackles: return player.tackles
        case .sacks: return player.sacksMade
        case .interceptions: return player.interceptionsDefense
        case .fieldGoals: return player.fieldGoalsMade
        }
    }
    
    private func categoryDisplayName(_ category: LeagueManager.StatCategory) -> String {
        switch category {
        case .passingYards: return "Passing Yards"
        case .rushingYards: return "Rushing Yards"
        case .receivingYards: return "Receiving Yards"
        case .passingTouchdowns: return "Passing TDs"
        case .rushingTouchdowns: return "Rushing TDs"
        case .receivingTouchdowns: return "Receiving TDs"
        case .tackles: return "Tackles"
        case .sacks: return "Sacks"
        case .interceptions: return "Interceptions"
        case .fieldGoals: return "Field Goals"
        }
    }
}

// MARK: - Player Stat Container
struct PlayerStatContainer: View {
    let category: LeagueManager.StatCategory
    @ObservedObject var leagueManager: LeagueManager
    let userTeam: LeagueTeam
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text(categoryDisplayName(category))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Top 5 players
                let topPlayers = leagueManager.getLeagueLeaders(category: category, limit: 5)
                
                if topPlayers.isEmpty {
                    Text("No data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(topPlayers.enumerated()), id: \.element.id) { index, player in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(player.teamLogoName == userTeam.logoName ? .blue : .secondary)
                                    .frame(width: 16)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(player.playerName)
                                        .font(.caption)
                                        .fontWeight(player.teamLogoName == userTeam.logoName ? .bold : .medium)
                                        .foregroundColor(player.teamLogoName == userTeam.logoName ? .blue : .primary)
                                        .lineLimit(1)
                                    
                                    Text(TeamData.getTeamDisplayName(player.teamLogoName))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Text(getStatValue(player: player, category: category))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(player.teamLogoName == userTeam.logoName ? .blue : .primary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
    
    private func categoryDisplayName(_ category: LeagueManager.StatCategory) -> String {
        switch category {
        case .passingYards: return "Passing Yards"
        case .rushingYards: return "Rushing Yards"
        case .receivingYards: return "Receiving Yards"
        case .passingTouchdowns: return "Passing TDs"
        case .rushingTouchdowns: return "Rushing TDs"
        case .receivingTouchdowns: return "Receiving TDs"
        case .tackles: return "Tackles"
        case .sacks: return "Sacks"
        case .interceptions: return "Interceptions"
        case .fieldGoals: return "Field Goals"
        }
    }
}

// MARK: - Detailed Stats View
struct DetailedStatsView: View {
    @ObservedObject var leagueManager: LeagueManager
    let userTeam: LeagueTeam
    let category: LeagueManager.StatCategory
    let isTeamStats: Bool
    let leagueId: UUID? // Phase 5: Add league context for player details
    @Environment(\.dismiss) private var dismiss
    
    init(leagueManager: LeagueManager, userTeam: LeagueTeam, category: LeagueManager.StatCategory, isTeamStats: Bool, leagueId: UUID? = nil) {
        self.leagueManager = leagueManager
        self.userTeam = userTeam
        self.category = category
        self.isTeamStats = isTeamStats
        self.leagueId = leagueId
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    if isTeamStats {
                        // Team stats
                        let teamRankings = getTeamRankings(for: category)
                        ForEach(Array(teamRankings.enumerated()), id: \.element.teamLogoName) { index, teamRanking in
                            TeamRankingRow(
                                rank: index + 1,
                                teamRanking: teamRanking,
                                statLabel: getStatLabel(category: category),
                                isUserTeam: teamRanking.teamLogoName == userTeam.logoName
                            )
                        }
                    } else {
                        // Player stats
                        let players = leagueManager.getLeagueLeaders(category: category, limit: 50)
                        ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                            LeaguePlayerRow(
                                rank: index + 1,
                                player: player,
                                statValue: getStatValue(player: player, category: category),
                                statLabel: getStatLabel(category: category),
                                isUserTeamPlayer: player.teamLogoName == userTeam.logoName,
                                leagueId: leagueId,
                                leagueManager: leagueManager
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
            .navigationTitle(categoryDisplayName(category))
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
    
    private func getTeamRankings(for category: LeagueManager.StatCategory) -> [TeamRanking] {
        var teamTotals: [String: Int] = [:]
        
        for player in leagueManager.playerSeasonStats.values {
            let statValue = getStatValueInt(player: player, category: category)
            teamTotals[player.teamLogoName, default: 0] += statValue
        }
        
        return teamTotals.map { teamLogoName, totalStat in
            TeamRanking(teamLogoName: teamLogoName, totalStat: totalStat)
        }.sorted { 
            if $0.totalStat != $1.totalStat {
                return $0.totalStat > $1.totalStat
            }
            return $0.teamLogoName < $1.teamLogoName // Stable tie-breaker
        }
    }
    
    private func getStatValueInt(player: PlayerSeasonStats, category: LeagueManager.StatCategory) -> Int {
        switch category {
        case .passingYards: return player.passingYards
        case .rushingYards: return player.rushingYards
        case .receivingYards: return player.receivingYards
        case .passingTouchdowns: return player.passingTouchdowns
        case .rushingTouchdowns: return player.rushingTouchdowns
        case .receivingTouchdowns: return player.receivingTouchdowns
        case .tackles: return player.tackles
        case .sacks: return player.sacksMade
        case .interceptions: return player.interceptionsDefense
        case .fieldGoals: return player.fieldGoalsMade
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
    
    private func categoryDisplayName(_ category: LeagueManager.StatCategory) -> String {
        switch category {
        case .passingYards: return "Passing Yards"
        case .rushingYards: return "Rushing Yards"
        case .receivingYards: return "Receiving Yards"
        case .passingTouchdowns: return "Passing TDs"
        case .rushingTouchdowns: return "Rushing TDs"
        case .receivingTouchdowns: return "Receiving TDs"
        case .tackles: return "Tackles"
        case .sacks: return "Sacks"
        case .interceptions: return "Interceptions"
        case .fieldGoals: return "Field Goals"
        }
    }
}

// MARK: - Team Ranking Model
struct TeamRanking {
    let teamLogoName: String
    let totalStat: Int
}

// MARK: - Team Ranking Row
struct TeamRankingRow: View {
    let rank: Int
    let teamRanking: TeamRanking
    let statLabel: String
    let isUserTeam: Bool
    
    var body: some View {
        HStack {
            // Rank
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isUserTeam ? .blue : .secondary)
                .frame(width: 20)
            
            // Team logo
            Image(teamRanking.teamLogoName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            
            // Team info
            VStack(alignment: .leading, spacing: 2) {
                Text(TeamData.getTeamDisplayName(teamRanking.teamLogoName))
                    .font(.subheadline)
                    .fontWeight(isUserTeam ? .bold : .semibold)
                    .foregroundColor(isUserTeam ? .blue : .primary)
                
                Text("Team Total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Stat value
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(teamRanking.totalStat)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isUserTeam ? .blue : .primary)
                
                Text(statLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isUserTeam ? .blue.opacity(0.1) : Color(.systemGray6).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isUserTeam ? .blue.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
}

// MARK: - League Player Row (with highlighting)
struct LeaguePlayerRow: View {
    let rank: Int
    let player: PlayerSeasonStats
    let statValue: String
    let statLabel: String
    let isUserTeamPlayer: Bool
    let leagueId: UUID?
    let leagueManager: LeagueManager?
    @State private var showingPlayerDetail = false
    
    init(rank: Int, player: PlayerSeasonStats, statValue: String, statLabel: String, isUserTeamPlayer: Bool, leagueId: UUID? = nil, leagueManager: LeagueManager? = nil) {
        self.rank = rank
        self.player = player
        self.statValue = statValue
        self.statLabel = statLabel
        self.isUserTeamPlayer = isUserTeamPlayer
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
                    .foregroundColor(isUserTeamPlayer ? .blue : .secondary)
                    .frame(width: 20)
                
                // Player info
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.playerName)
                        .font(.subheadline)
                        .fontWeight(isUserTeamPlayer ? .bold : .semibold)
                        .foregroundColor(isUserTeamPlayer ? .blue : .primary)
                    
                    HStack(spacing: 4) {
                        Text(player.position)
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(TeamData.getTeamDisplayName(player.teamLogoName))
                            .font(.caption)
                            .fontWeight(isUserTeamPlayer ? .semibold : .regular)
                            .foregroundColor(isUserTeamPlayer ? .blue : .secondary)
                    }
                }
                
                Spacer()
                
                // Stat value
                VStack(alignment: .trailing, spacing: 2) {
                    Text(statValue)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(isUserTeamPlayer ? .blue : .primary)
                    
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
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isUserTeamPlayer ? .blue.opacity(0.1) : Color(.systemGray6).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isUserTeamPlayer ? .blue.opacity(0.3) : .clear, lineWidth: 1)
            )
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
    LeagueStatsView(
        leagueManager: LeagueManager(),
        userTeam: TeamData.createTeamFromData(name: "Chicago").asLeagueTeam,
        leagueId: UUID()
    )
} 