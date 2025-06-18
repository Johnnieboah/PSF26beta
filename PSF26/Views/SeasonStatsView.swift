import SwiftUI

// MARK: - Season Stats View
struct SeasonStatsView: View {
    @ObservedObject var leagueManager: LeagueManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: StatsCategory = .team
    
    enum StatsCategory: String, CaseIterable {
        case team = "Team"
        case offense = "Offense"
        case defense = "Defense"
        case league = "League"
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
    
    private func createUserTeamStatsCard(_ userTeam: TeamData) -> some View {
        let teamRecord = leagueManager.teamRecord
        return UserTeamStatsCard(
            team: userTeam,
            record: teamRecord,
            leagueManager: leagueManager
        )
    }
    
    private func createTeamComparisonCard(_ userTeam: TeamData) -> some View {
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
}

// MARK: - User Team Stats Card
struct UserTeamStatsCard: View {
    let team: TeamData
    let record: TeamRecord
    let leagueManager: LeagueManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            statsGrid
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: team.primaryColor).opacity(0.3), lineWidth: 1.5)
        )
    }
    
    private var headerSection: some View {
        HStack {
            Image(team.logoName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(team.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("\(record.wins)-\(record.losses)-\(record.ties)")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: team.primaryColor))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Rank")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("#\(leagueManager.getDivisionRank(for: team))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
            StatItem(title: "Win %", value: String(format: "%.3f", record.winPercentage), color: .green)
            StatItem(title: "Points For", value: "\(calculatePointsFor())", color: .blue)
            StatItem(title: "Points Against", value: "\(calculatePointsAgainst())", color: .red)
            StatItem(title: "Point Diff", value: "\(calculatePointsDiff())", color: calculatePointsDiff() >= 0 ? .green : .red)
            StatItem(title: "Playoff Odds", value: "\(leagueManager.getPlayoffOdds(for: team))%", color: .purple)
            StatItem(title: "Games Left", value: "\(17 - record.gamesPlayed)", color: .orange)
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

// MARK: - Stat Item
struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Team Comparison Card
struct TeamComparisonCard: View {
    let userTeam: TeamData
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
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
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatItem(title: "Points/Game", value: "24.3", color: .blue)
                StatItem(title: "Total Yards", value: "352", color: .green)
                StatItem(title: "Pass Yards", value: "245", color: .orange)
                StatItem(title: "Rush Yards", value: "107", color: .purple)
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
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatItem(title: "Points Allow", value: "18.7", color: .red)
                StatItem(title: "Yards Allow", value: "298", color: .orange)
                StatItem(title: "Takeaways", value: "12", color: .green)
                StatItem(title: "Sacks", value: "28", color: .blue)
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
