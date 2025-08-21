import SwiftUI

// MARK: - Playoff Stats View (Playoff Teams and Stats Only)
struct PlayoffStatsView: View {
    @ObservedObject var leagueManager: LeagueManager
    let userTeam: LeagueTeam
    let leagueId: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: PlayoffStatsTab = .teams
    @State private var showingDetailedStats = false
    @State private var selectedDetailCategory: LeagueManager.StatCategory = .passingYards
    
    init(leagueManager: LeagueManager, userTeam: LeagueTeam, leagueId: UUID? = nil) {
        self.leagueManager = leagueManager
        self.userTeam = userTeam
        self.leagueId = leagueId
    }
    
    enum PlayoffStatsTab: String, CaseIterable {
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
                    .tag(PlayoffStatsTab.teams)
                
                // Players Tab
                playerStatsContent
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Players")
                    }
                    .tag(PlayoffStatsTab.players)
            }
            .navigationTitle("Playoff Stats")
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
            PlayoffDetailedStatsView(
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
                    PlayoffTeamStatContainer(
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
                    PlayoffPlayerStatContainer(
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

// MARK: - Playoff Team Stat Container
struct PlayoffTeamStatContainer: View {
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
                
                // Top 5 playoff teams
                let topTeams = getTopPlayoffTeams(for: category)
                
                VStack(spacing: 8) {
                    ForEach(Array(topTeams.prefix(5).enumerated()), id: \.element.teamLogoName) { index, teamRanking in
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .leading)
                            
                            Text(TeamData.getTeamDisplayName(teamRanking.teamLogoName))
                                .font(.caption)
                                .foregroundColor(teamRanking.teamLogoName == userTeam.logoName ? .orange : .primary)
                                .fontWeight(teamRanking.teamLogoName == userTeam.logoName ? .bold : .medium)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(teamRanking.totalStat)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(teamRanking.teamLogoName == userTeam.logoName ? .orange : .blue)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.secondary.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func getTopPlayoffTeams(for category: LeagueManager.StatCategory) -> [TeamRanking] {
        // Get only playoff teams
        let playoffTeamLogoNames = Set(leagueManager.playoffTeams.map { $0.logoName })
        
        var teamTotals: [String: Int] = [:]
        
        // Get playoff-only stats (weeks 19+)
        let playoffGameStats = leagueManager.gamePlayerStats.values
            .flatMap { $0 }
            .filter { $0.week >= 19 && playoffTeamLogoNames.contains($0.teamLogoName) }
        
        for playerStat in playoffGameStats {
            let statValue = getStatValueInt(playerStat: playerStat, category: category)
            teamTotals[playerStat.teamLogoName, default: 0] += statValue
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
    
    private func getStatValueInt(playerStat: GamePlayerStats, category: LeagueManager.StatCategory) -> Int {
        switch category {
        case .passingYards: return playerStat.passingYards
        case .rushingYards: return playerStat.rushingYards
        case .receivingYards: return playerStat.receivingYards
        case .passingTouchdowns: return playerStat.passingTouchdowns
        case .rushingTouchdowns: return playerStat.rushingTouchdowns
        case .receivingTouchdowns: return playerStat.receivingTouchdowns
        case .tackles: return playerStat.tackles
        case .sacks: return playerStat.sacksMade
        case .interceptions: return playerStat.interceptionsDefense
        case .fieldGoals: return playerStat.fieldGoalsMade
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

// MARK: - Playoff Player Stat Container
struct PlayoffPlayerStatContainer: View {
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
                
                // Top 5 playoff players
                let topPlayers = getTopPlayoffPlayers(for: category)
                
                VStack(spacing: 8) {
                    ForEach(Array(topPlayers.prefix(5).enumerated()), id: \.element.playerId) { index, playerStats in
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .leading)
                            
                            Text(playerStats.playerName)
                                .font(.caption)
                                .foregroundColor(playerStats.teamLogoName == userTeam.logoName ? .orange : .primary)
                                .fontWeight(playerStats.teamLogoName == userTeam.logoName ? .bold : .medium)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(getStatValue(playerStats: playerStats, category: category))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(playerStats.teamLogoName == userTeam.logoName ? .orange : .blue)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.secondary.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func getTopPlayoffPlayers(for category: LeagueManager.StatCategory) -> [PlayoffPlayerStats] {
        // Get only playoff teams
        let playoffTeamLogoNames = Set(leagueManager.playoffTeams.map { $0.logoName })
        
        // Get playoff-only stats (weeks 19+)
        let playoffGameStats = leagueManager.gamePlayerStats.values
            .flatMap { $0 }
            .filter { $0.week >= 19 && playoffTeamLogoNames.contains($0.teamLogoName) }
        
        // Group by player and accumulate stats
        var playerTotals: [String: PlayoffPlayerStats] = [:]
        
        for gameStat in playoffGameStats {
            let playerId = gameStat.playerId
            
            if playerTotals[playerId] == nil {
                playerTotals[playerId] = PlayoffPlayerStats(
                    playerId: gameStat.playerId,
                    playerName: gameStat.playerName,
                    position: gameStat.position,
                    teamLogoName: gameStat.teamLogoName
                )
            }
            
            var playerStats = playerTotals[playerId]!
            
            // Accumulate stats
            playerStats.passingYards += gameStat.passingYards
            playerStats.rushingYards += gameStat.rushingYards
            playerStats.receivingYards += gameStat.receivingYards
            playerStats.passingTouchdowns += gameStat.passingTouchdowns
            playerStats.rushingTouchdowns += gameStat.rushingTouchdowns
            playerStats.receivingTouchdowns += gameStat.receivingTouchdowns
            playerStats.tackles += gameStat.tackles
            playerStats.sacksMade += gameStat.sacksMade
            playerStats.interceptionsDefense += gameStat.interceptionsDefense
            playerStats.fieldGoalsMade += gameStat.fieldGoalsMade
            
            playerTotals[playerId] = playerStats
        }
        
        return playerTotals.values.sorted { player1, player2 in
            let stat1 = getStatValue(playerStats: player1, category: category)
            let stat2 = getStatValue(playerStats: player2, category: category)
            
            if stat1 != stat2 {
                return stat1 > stat2
            }
            return player1.playerName < player2.playerName // Stable tie-breaker
        }
    }
    
    private func getStatValue(playerStats: PlayoffPlayerStats, category: LeagueManager.StatCategory) -> Int {
        switch category {
        case .passingYards: return playerStats.passingYards
        case .rushingYards: return playerStats.rushingYards
        case .receivingYards: return playerStats.receivingYards
        case .passingTouchdowns: return playerStats.passingTouchdowns
        case .rushingTouchdowns: return playerStats.rushingTouchdowns
        case .receivingTouchdowns: return playerStats.receivingTouchdowns
        case .tackles: return playerStats.tackles
        case .sacks: return playerStats.sacksMade
        case .interceptions: return playerStats.interceptionsDefense
        case .fieldGoals: return playerStats.fieldGoalsMade
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

// MARK: - Playoff Player Stats Model
struct PlayoffPlayerStats {
    let playerId: String
    let playerName: String
    let position: String
    let teamLogoName: String
    
    var passingYards: Int = 0
    var rushingYards: Int = 0
    var receivingYards: Int = 0
    var passingTouchdowns: Int = 0
    var rushingTouchdowns: Int = 0
    var receivingTouchdowns: Int = 0
    var tackles: Int = 0
    var sacksMade: Int = 0
    var interceptionsDefense: Int = 0
    var fieldGoalsMade: Int = 0
}

// MARK: - Playoff Detailed Stats View
struct PlayoffDetailedStatsView: View {
    @ObservedObject var leagueManager: LeagueManager
    let userTeam: LeagueTeam
    let category: LeagueManager.StatCategory
    let isTeamStats: Bool
    let leagueId: UUID?
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
                        let teamRankings = getPlayoffTeamRankings(for: category)
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
                        let players = getPlayoffPlayerLeaders(category: category, limit: 50)
                        ForEach(Array(players.enumerated()), id: \.element.playerId) { index, player in
                            PlayoffPlayerRow(
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
            .navigationTitle("Playoff \(categoryDisplayName(category))")
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
    
    private func getPlayoffTeamRankings(for category: LeagueManager.StatCategory) -> [TeamRanking] {
        // Get only playoff teams
        let playoffTeamLogoNames = Set(leagueManager.playoffTeams.map { $0.logoName })
        
        var teamTotals: [String: Int] = [:]
        
        // Get playoff-only stats (weeks 19+)
        let playoffGameStats = leagueManager.gamePlayerStats.values
            .flatMap { $0 }
            .filter { $0.week >= 19 && playoffTeamLogoNames.contains($0.teamLogoName) }
        
        for playerStat in playoffGameStats {
            let statValue = getStatValueInt(playerStat: playerStat, category: category)
            teamTotals[playerStat.teamLogoName, default: 0] += statValue
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
    
    private func getPlayoffPlayerLeaders(category: LeagueManager.StatCategory, limit: Int) -> [PlayoffPlayerStats] {
        // Get only playoff teams
        let playoffTeamLogoNames = Set(leagueManager.playoffTeams.map { $0.logoName })
        
        // Get playoff-only stats (weeks 19+)
        let playoffGameStats = leagueManager.gamePlayerStats.values
            .flatMap { $0 }
            .filter { $0.week >= 19 && playoffTeamLogoNames.contains($0.teamLogoName) }
        
        // Group by player and accumulate stats
        var playerTotals: [String: PlayoffPlayerStats] = [:]
        
        for gameStat in playoffGameStats {
            let playerId = gameStat.playerId
            
            if playerTotals[playerId] == nil {
                playerTotals[playerId] = PlayoffPlayerStats(
                    playerId: gameStat.playerId,
                    playerName: gameStat.playerName,
                    position: gameStat.position,
                    teamLogoName: gameStat.teamLogoName
                )
            }
            
            var playerStats = playerTotals[playerId]!
            
            // Accumulate stats
            playerStats.passingYards += gameStat.passingYards
            playerStats.rushingYards += gameStat.rushingYards
            playerStats.receivingYards += gameStat.receivingYards
            playerStats.passingTouchdowns += gameStat.passingTouchdowns
            playerStats.rushingTouchdowns += gameStat.rushingTouchdowns
            playerStats.receivingTouchdowns += gameStat.receivingTouchdowns
            playerStats.tackles += gameStat.tackles
            playerStats.sacksMade += gameStat.sacksMade
            playerStats.interceptionsDefense += gameStat.interceptionsDefense
            playerStats.fieldGoalsMade += gameStat.fieldGoalsMade
            
            playerTotals[playerId] = playerStats
        }
        
        return playerTotals.values.sorted { player1, player2 in
            let stat1 = getStatValue(player: player1, category: category)
            let stat2 = getStatValue(player: player2, category: category)
            
            if stat1 != stat2 {
                return stat1 > stat2
            }
            return player1.playerName < player2.playerName // Stable tie-breaker
        }.prefix(limit).map { $0 }
    }
    
    private func getStatValueInt(playerStat: GamePlayerStats, category: LeagueManager.StatCategory) -> Int {
        switch category {
        case .passingYards: return playerStat.passingYards
        case .rushingYards: return playerStat.rushingYards
        case .receivingYards: return playerStat.receivingYards
        case .passingTouchdowns: return playerStat.passingTouchdowns
        case .rushingTouchdowns: return playerStat.rushingTouchdowns
        case .receivingTouchdowns: return playerStat.receivingTouchdowns
        case .tackles: return playerStat.tackles
        case .sacks: return playerStat.sacksMade
        case .interceptions: return playerStat.interceptionsDefense
        case .fieldGoals: return playerStat.fieldGoalsMade
        }
    }
    
    private func getStatValue(player: PlayoffPlayerStats, category: LeagueManager.StatCategory) -> String {
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

// MARK: - Playoff Player Row
struct PlayoffPlayerRow: View {
    let rank: Int
    let player: PlayoffPlayerStats
    let statValue: String
    let statLabel: String
    let isUserTeamPlayer: Bool
    let leagueId: UUID?
    let leagueManager: LeagueManager?
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(rankColor)
                )
            
            // Player Info
            VStack(alignment: .leading, spacing: 2) {
                Text(player.playerName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isUserTeamPlayer ? .orange : .primary)
                
                HStack(spacing: 8) {
                    Text(player.position)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(4)
                    
                    Text(TeamData.getTeamDisplayName(player.teamLogoName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Stat Value
            VStack(alignment: .trailing, spacing: 2) {
                Text(statValue)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(isUserTeamPlayer ? .orange : .blue)
                
                Text(statLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isUserTeamPlayer ? Color.orange.opacity(0.1) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isUserTeamPlayer ? Color.orange.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2...3: return .gray
        case 4...10: return .blue
        default: return .secondary
        }
    }
} 