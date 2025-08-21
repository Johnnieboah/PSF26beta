import SwiftUI

// MARK: - Season Stats View
struct SeasonStatsView: View {
    @ObservedObject var leagueManager: LeagueManager
    let leagueId: UUID? // Phase 5: Add league context for player details
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: StatsCategory = .team
    
    init(leagueManager: LeagueManager, leagueId: UUID? = nil) {
        self.leagueManager = leagueManager
        self.leagueId = leagueId
    }
    
    enum StatsCategory: String, CaseIterable {
        case team = "Team"
        case offense = "Offense"
        case defense = "Defense"
        case league = "League"
        case players = "Players"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Selector
                categorySelectorHeader
                
                // Stats Content
                ScrollView {
                    statsContentView
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                }
            }
            .navigationTitle("Season Stats")
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
    
    // MARK: - Category Selector Header
    private var categorySelectorHeader: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StatsCategory.allCases, id: \.self) { category in
                        categoryButton(for: category)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
            .background(.regularMaterial)
            
            Divider()
        }
    }
    
    private func categoryButton(for category: StatsCategory) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedCategory = category
            }
        } label: {
            Text(category.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(selectedCategory == category ? .white : .primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedCategory == category ? Color.blue : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Stats Content View
    private var statsContentView: some View {
        LazyVStack(spacing: 20) {
            switch selectedCategory {
            case .team:
                teamStatsContent
            case .offense:
                offenseStatsContent
            case .defense:
                defenseStatsContent
            case .league:
                leagueStatsContent
            case .players:
                playerStatsContent
            }
        }
    }
    
    // MARK: - Team Stats Content
    private var teamStatsContent: some View {
        VStack(spacing: 20) {
            if let userTeam = leagueManager.userTeam {
                createUserTeamStatsCard(userTeam)
                createTeamComparisonCard(userTeam)
            }
        }
    }
    
    private func createUserTeamStatsCard(_ userTeam: LeagueTeam) -> some View {
        let teamRecord = leagueManager.teamRecord
        return UserTeamStatsCard(
            team: userTeam,
            record: teamRecord,
            leagueManager: leagueManager
        )
    }
    
    private func createTeamComparisonCard(_ userTeam: LeagueTeam) -> some View {
        TeamComparisonCard(
            userTeam: userTeam,
            leagueManager: leagueManager
        )
    }
    
    // MARK: - Offense Stats Content
    private var offenseStatsContent: some View {
        VStack(spacing: 20) {
            OffenseStatsCard(leagueManager: leagueManager)
            TopPerformersCard(category: "Offense", leagueManager: leagueManager)
        }
    }
    
    // MARK: - Defense Stats Content
    private var defenseStatsContent: some View {
        VStack(spacing: 20) {
            DefenseStatsCard(leagueManager: leagueManager)
            TopPerformersCard(category: "Defense", leagueManager: leagueManager)
        }
    }
    
    // MARK: - League Stats Content
    private var leagueStatsContent: some View {
        VStack(spacing: 20) {
            LeagueLeadersCard(leagueManager: leagueManager)
            PlayoffPictureCard(leagueManager: leagueManager)
        }
    }
    
    // MARK: - Player Stats Content
    private var playerStatsContent: some View {
        VStack(spacing: 20) {
            PlayerLeadersCard(leagueManager: leagueManager, leagueId: leagueId)
            if let userTeam = leagueManager.userTeam {
                TeamPlayerLeadersCard(team: userTeam, leagueManager: leagueManager)
            }
        }
    }
}

// MARK: - User Team Stats Card
struct UserTeamStatsCard: View {
    let team: LeagueTeam
    let record: TeamRecord
    let leagueManager: LeagueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Your Team")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(record.description)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Record")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Team season stats if available
            if let teamStats = leagueManager.getTeamSeasonStats(teamLogoName: team.logoName) {
                teamSeasonStatsGrid(teamStats)
            } else {
                // Basic stats grid
                statsGrid
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
    
    private func teamSeasonStatsGrid(_ teamStats: TeamSeasonStats) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
            StatCard(title: "Points/Game", value: String(format: "%.1f", teamStats.pointsPerGame), style: .highlighted(.blue))
            StatCard(title: "Yards/Game", value: String(format: "%.0f", teamStats.yardsPerGame), style: .highlighted(.green))
            StatCard(title: "Pass Yards", value: "\(teamStats.totalPassingYards)", style: .highlighted(.orange))
            StatCard(title: "Rush Yards", value: "\(teamStats.totalRushingYards)", style: .highlighted(.purple))
            StatCard(title: "Points Against", value: String(format: "%.1f", teamStats.pointsAllowedPerGame), style: .highlighted(.red))
            StatCard(title: "Turnovers", value: "\(teamStats.totalTurnovers)", style: .highlighted(.yellow))
        }
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
            StatCard(title: "Win %", value: String(format: "%.3f", record.winPercentage), style: .highlighted(.green))
            StatCard(title: "Points For", value: "\(calculatePointsFor())", style: .highlighted(.blue))
            StatCard(title: "Points Against", value: "\(calculatePointsAgainst())", style: .highlighted(.red))
            StatCard(title: "Point Diff", value: "\(calculatePointsDiff())", style: .highlighted(calculatePointsDiff() >= 0 ? .green : .red))
            StatCard(title: "Playoff Odds", value: "\(leagueManager.getPlayoffOdds(for: team))%", style: .highlighted(.purple))
            StatCard(title: "Games Left", value: "\(17 - record.gamesPlayed)", style: .highlighted(.orange))
        }
    }
    
    private func calculatePointsFor() -> Int {
        return leagueManager.completedGames
            .filter { $0.homeTeam.logoName == team.logoName || $0.awayTeam.logoName == team.logoName }
            .reduce(0) { total, game in
                if game.homeTeam.logoName == team.logoName {
                    return total + game.homeScore
                } else {
                    return total + game.awayScore
                }
            }
    }
    
    private func calculatePointsAgainst() -> Int {
        return leagueManager.completedGames
            .filter { $0.homeTeam.logoName == team.logoName || $0.awayTeam.logoName == team.logoName }
            .reduce(0) { total, game in
                if game.homeTeam.logoName == team.logoName {
                    return total + game.awayScore
                } else {
                    return total + game.homeScore
                }
            }
    }
    
    private func calculatePointsDiff() -> Int {
        return calculatePointsFor() - calculatePointsAgainst()
    }
}



// MARK: - Player Leaders Card
struct PlayerLeadersCard: View {
    let leagueManager: LeagueManager
    let leagueId: UUID? // Phase 5: Add league context for player details
    @State private var selectedStatCategory: LeagueManager.StatCategory = .passingYards
    
    init(leagueManager: LeagueManager, leagueId: UUID? = nil) {
        self.leagueManager = leagueManager
        self.leagueId = leagueId
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("League Leaders")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Stat category picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach([LeagueManager.StatCategory.passingYards, .rushingYards, .receivingYards, .passingTouchdowns, .rushingTouchdowns, .receivingTouchdowns, .tackles, .sacks, .interceptions], id: \.self) { category in
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
            
            // Leaders list
            let leaders = leagueManager.getLeagueLeaders(category: selectedStatCategory, limit: 5)
            
            if leaders.isEmpty {
                Text("No stats available yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(leaders.enumerated()), id: \.element.id) { index, player in
                        PlayerLeaderRow(
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

// MARK: - Player Leader Row
struct PlayerLeaderRow: View {
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
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                // Player info
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.playerName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text(player.position)
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(TeamData.getTeamDisplayName(player.teamLogoName))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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

// MARK: - Team Player Leaders Card
struct TeamPlayerLeadersCard: View {
    let team: LeagueTeam
    let leagueManager: LeagueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(team.name) Leaders")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Passing leader
                if let passingLeader = leagueManager.getTeamLeaders(teamLogoName: team.logoName, category: .passingYards, limit: 1).first {
                    TeamLeaderRow(title: "Passing", player: passingLeader, stat: "\(passingLeader.passingYards) yards")
                }
                
                // Rushing leader
                if let rushingLeader = leagueManager.getTeamLeaders(teamLogoName: team.logoName, category: .rushingYards, limit: 1).first {
                    TeamLeaderRow(title: "Rushing", player: rushingLeader, stat: "\(rushingLeader.rushingYards) yards")
                }
                
                // Receiving leader
                if let receivingLeader = leagueManager.getTeamLeaders(teamLogoName: team.logoName, category: .receivingYards, limit: 1).first {
                    TeamLeaderRow(title: "Receiving", player: receivingLeader, stat: "\(receivingLeader.receivingYards) yards")
                }
                
                // Tackles leader
                if let tacklesLeader = leagueManager.getTeamLeaders(teamLogoName: team.logoName, category: .tackles, limit: 1).first {
                    TeamLeaderRow(title: "Tackles", player: tacklesLeader, stat: "\(tacklesLeader.tackles) tackles")
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
}

// MARK: - Team Leader Row
struct TeamLeaderRow: View {
    let title: String
    let player: PlayerSeasonStats
    let stat: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .frame(width: 80, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.playerName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(player.position)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(stat)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Team Comparison Card
struct TeamComparisonCard: View {
    let userTeam: LeagueTeam
    let leagueManager: LeagueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Division Comparison")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(leagueManager.getDivisionStandings(for: userTeam)) { team in
                    teamComparisonRow(for: team)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .standardCard(.ultraThin16)
    }
    
    private func teamComparisonRow(for team: LeagueTeam) -> some View {
        HStack(spacing: 16) {
            Text("\(team.divisionRank)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(team.divisionRank == 1 ? .green : .primary)
                .frame(width: 20)
            
            Image(team.logoName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
            
            Text(getTeamAbbreviation(team.logoName))
                .font(.subheadline)
                .fontWeight(team.logoName == userTeam.logoName ? .bold : .medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(team.record.wins)-\(team.record.losses)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(team.logoName == userTeam.logoName ? .blue : .secondary)
            
            Text(String(format: "%.3f", team.record.winPercentage))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(team.logoName == userTeam.logoName ? .blue.opacity(0.1) : .clear)
        )
    }
    
    private func getTeamAbbreviation(_ logoName: String) -> String {
        let abbreviations: [String: String] = [
            "Chicago": "CHI", "Detroit": "DET", "GreenBay": "GB", "Minnesota": "MIN"
        ]
        return abbreviations[logoName] ?? logoName
    }
}

// MARK: - Simple Stats Cards
struct OffenseStatsCard: View {
    let leagueManager: LeagueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Offensive Stats")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let userTeam = leagueManager.userTeam,
               let teamStats = leagueManager.getTeamSeasonStats(teamLogoName: userTeam.logoName) {
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    StatCard(title: "Points/Game", value: "0.0", style: .highlighted(.blue))
                    StatCard(title: "Total Yards", value: "0", style: .highlighted(.green))
                    StatCard(title: "Pass Yards", value: "0", style: .highlighted(.orange))
                    StatCard(title: "Rush Yards", value: "0", style: .highlighted(.purple))
                    StatCard(title: "Total TDs", value: "0", style: .highlighted(.red))
                    StatCard(title: "1st Downs", value: "0", style: .highlighted(.cyan))
                    StatCard(title: "3rd Down %", value: "0.0%", style: .highlighted(.mint))
                    StatCard(title: "Red Zone %", value: "0.0%", style: .highlighted(.pink))
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
}

struct DefenseStatsCard: View {
    let leagueManager: LeagueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Defensive Stats")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let userTeam = leagueManager.userTeam,
               let teamStats = leagueManager.getTeamSeasonStats(teamLogoName: userTeam.logoName) {
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    StatCard(title: "Points Allow", value: "0.0", style: .highlighted(.red))
                    StatCard(title: "Yards Allow", value: "0", style: .highlighted(.orange))
                    StatCard(title: "Pass Yds Allow", value: "0", style: .highlighted(.yellow))
                    StatCard(title: "Rush Yds Allow", value: "0", style: .highlighted(.brown))
                    StatCard(title: "Sacks", value: "0", style: .highlighted(.blue))
                    StatCard(title: "Interceptions", value: "0", style: .highlighted(.green))
                    StatCard(title: "Fumbles Forced", value: "0", style: .highlighted(.purple))
                    StatCard(title: "Def TDs", value: "0", style: .highlighted(.cyan))
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
}

struct TopPerformersCard: View {
    let category: String
    let leagueManager: LeagueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top \(category) Performers")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(0..<3) { index in
                    performerRow(rank: index + 1)
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
    
    private func performerRow(rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Player Name")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Position")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Stats")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct LeagueLeadersCard: View {
    let leagueManager: LeagueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("League Leaders")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                LeaderRow(category: "Passing Yards", player: "Josh Allen", team: "BUF", stat: "2847")
                LeaderRow(category: "Rushing Yards", player: "Christian McCaffrey", team: "SF", stat: "1203")
                LeaderRow(category: "Receiving Yards", player: "Tyreek Hill", team: "MIA", stat: "1156")
                LeaderRow(category: "Sacks", player: "T.J. Watt", team: "PIT", stat: "12.5")
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
}

struct LeaderRow: View {
    let category: String
    let player: String
    let team: String
    let stat: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(player)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(team)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(stat)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PlayoffPictureCard: View {
    let leagueManager: LeagueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Playoff Picture")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                PlayoffSpotRow(seed: 1, team: "Buffalo Bills", record: "12-3", status: "Division Leader")
                PlayoffSpotRow(seed: 2, team: "Kansas City Chiefs", record: "11-4", status: "Division Leader")
                PlayoffSpotRow(seed: 3, team: "Baltimore Ravens", record: "10-5", status: "Division Leader")
                PlayoffSpotRow(seed: 4, team: "Houston Texans", record: "9-6", status: "Division Leader")
                PlayoffSpotRow(seed: 5, team: "Miami Dolphins", record: "10-5", status: "Wild Card")
                PlayoffSpotRow(seed: 6, team: "Pittsburgh Steelers", record: "9-6", status: "Wild Card")
                PlayoffSpotRow(seed: 7, team: "Los Angeles Chargers", record: "8-7", status: "Wild Card")
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
}

struct PlayoffSpotRow: View {
    let seed: Int
    let team: String
    let record: String
    let status: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(seed)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(statusColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(team)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(record)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var statusColor: Color {
        switch status {
        case "Division Leader": return .green
        case "Wild Card": return .blue
        default: return .secondary
        }
    }
}

#Preview {
    SeasonStatsView(leagueManager: LeagueManager())
}
