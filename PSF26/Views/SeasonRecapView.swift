import SwiftUI

struct SeasonRecapView: View {
    let seasonHistory: SeasonHistory
    let isPostSeasonPopup: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Season header
                    seasonHeaderView
                    
                    // Champions section
                    championsSection
                    
                    // Stat leaders section
                    statLeadersSection
                    
                    // User team performance
                    userTeamSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
        }
        .navigationTitle("Season \(romanNumeral(for: seasonHistory.seasonYear)) Recap")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isPostSeasonPopup ? "Continue to Offseason" : "Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(isPostSeasonPopup ? .orange : .blue)
            }
        }
        .interactiveDismissDisabled(isPostSeasonPopup) // Prevent accidental swipe dismissal
    }
    
    // MARK: - Season Header
    private var seasonHeaderView: some View {
        VStack(spacing: 12) {
            Text("Season \(romanNumeral(for: seasonHistory.seasonYear))")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Completed \(formatDate(seasonHistory.completedDate))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if isPostSeasonPopup {
                Text("🏆 Congratulations on completing your season!")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Champions Section
    private var championsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SeasonSectionHeaderView(title: "Champions", subtitle: "Season winners at every level")
            
            // League Champion (Biggest highlight)
            ChampionCard(
                title: "League Champion",
                teamLogoName: seasonHistory.superBowlWinner,
                subtitle: "Defeated \(TeamData.getTeamDisplayName(seasonHistory.superBowlRunnerUp))",
                style: .gold
            )
            
            // Conference Champions  
            HStack(spacing: 12) {
                ChampionCard(
                    title: "ACFT Champion", 
                    teamLogoName: seasonHistory.afcChampion,
                    subtitle: "",
                    style: .silver
                )
                ChampionCard(
                    title: "NCFT Champion",
                    teamLogoName: seasonHistory.nfcChampion,
                    subtitle: "",
                    style: .silver
                )
            }
            
            // Division Champions Grid
            DivisionChampionsGrid(seasonHistory: seasonHistory)
        }
    }
    
    // MARK: - Stat Leaders Section
    private var statLeadersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SeasonSectionHeaderView(title: "Statistical Leaders", subtitle: "Top performers from the season")
            
            // Offensive Leaders
            StatLeaderGroup(title: "Offensive Leaders") {
                StatLeaderRow(
                    category: "Passing Yards",
                    leader: seasonHistory.passingYardsLeader
                )
                StatLeaderRow(
                    category: "Rushing Yards", 
                    leader: seasonHistory.rushingYardsLeader
                )
                StatLeaderRow(
                    category: "Receiving Yards",
                    leader: seasonHistory.receivingYardsLeader
                )
                StatLeaderRow(
                    category: "Passing TDs",
                    leader: seasonHistory.passingTouchdownsLeader
                )
                StatLeaderRow(
                    category: "Rushing TDs",
                    leader: seasonHistory.rushingTouchdownsLeader
                )
                StatLeaderRow(
                    category: "Receiving TDs",
                    leader: seasonHistory.receivingTouchdownsLeader
                )
            }
            
            // Defensive Leaders
            StatLeaderGroup(title: "Defensive Leaders") {
                StatLeaderRow(
                    category: "Tackles",
                    leader: seasonHistory.tacklesLeader
                )
                StatLeaderRow(
                    category: "Sacks", 
                    leader: seasonHistory.sacksLeader
                )
                StatLeaderRow(
                    category: "Interceptions",
                    leader: seasonHistory.interceptionsLeader
                )
            }
        }
    }
    
    // MARK: - User Team Section
    private var userTeamSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SeasonSectionHeaderView(title: "Your Season", subtitle: "How your team performed")
            
            UserTeamPerformanceCard(
                record: seasonHistory.userTeamRecord,
                finalRank: seasonHistory.userTeamFinalRank
            )
        }
    }
}

// MARK: - Supporting Views

struct SeasonSectionHeaderView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ChampionCard: View {
    let title: String
    let teamLogoName: String
    let subtitle: String
    let style: ChampionCardStyle
    
    enum ChampionCardStyle {
        case gold, silver
        
        var colors: [Color] {
            switch self {
            case .gold: return [Color.yellow, Color.orange]
            case .silver: return [Color.gray, Color.blue]
            }
        }
        
        var icon: String {
            switch self {
            case .gold: return "crown.fill"
            case .silver: return "trophy.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: style.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack {
                Image(teamLogoName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(TeamData.getTeamDisplayName(teamLogoName))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DivisionChampionsGrid: View {
    let seasonHistory: SeasonHistory
    
    private var divisionChampions: [(division: String, champion: String)] {
        [
            ("ACFT East", seasonHistory.afcEast),
            ("ACFT North", seasonHistory.afcNorth),
            ("ACFT South", seasonHistory.afcSouth),
            ("ACFT West", seasonHistory.afcWest),
            ("NCFT East", seasonHistory.nfcEast),
            ("NCFT North", seasonHistory.nfcNorth),
            ("NCFT South", seasonHistory.nfcSouth),
            ("NCFT West", seasonHistory.nfcWest)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Division Champions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(divisionChampions, id: \.division) { division, champion in
                    DivisionChampionCell(
                        division: division,
                        championLogoName: champion
                    )
                }
            }
        }
    }
}

struct DivisionChampionCell: View {
    let division: String
    let championLogoName: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(division)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Image(championLogoName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            
            Text(TeamData.getTeamDisplayName(championLogoName))
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatLeaderGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: 4) {
                content()
            }
        }
    }
}

struct StatLeaderRow: View {
    let category: String
    let leader: StatLeader
    
    var body: some View {
        HStack(spacing: 12) {
            Image(leader.teamLogoName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(leader.playerName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("\(leader.position) • \(TeamData.getTeamDisplayName(leader.teamLogoName))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 1) {
                Text(category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(leader.statDescription)
                    .font(.body)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct UserTeamPerformanceCard: View {
    let record: TeamRecord
    let finalRank: Int
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Final Record")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(record.description)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("League Rank")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("#\(finalRank)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(finalRank <= 8 ? .green : finalRank <= 16 ? .orange : .red)
                }
            }
            
            // Performance assessment
            HStack {
                Image(systemName: getPerformanceIcon(rank: finalRank))
                    .foregroundColor(getPerformanceColor(rank: finalRank))
                
                Text(getPerformanceText(rank: finalRank))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func getPerformanceIcon(rank: Int) -> String {
        switch rank {
        case 1...8: return "star.fill"
        case 9...16: return "star.leadinghalf.filled"
        default: return "star"
        }
    }
    
    private func getPerformanceColor(rank: Int) -> Color {
        switch rank {
        case 1...8: return .green
        case 9...16: return .orange
        default: return .red
        }
    }
    
    private func getPerformanceText(rank: Int) -> String {
        switch rank {
        case 1: return "League Champion! Outstanding season!"
        case 2...8: return "Excellent season! Made the playoffs."
        case 9...16: return "Solid season with room for improvement."
        case 17...24: return "Challenging season, focus on the draft."
        default: return "Tough season, time to rebuild."
        }
    }
}

// MARK: - Helper Functions
private func romanNumeral(for number: Int) -> String {
    let romanNumerals = [
        (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
        (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
        (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
    ]
    
    var result = ""
    var num = number
    
    for (value, symbol) in romanNumerals {
        let count = num / value
        if count > 0 {
            result += String(repeating: symbol, count: count)
            num %= value
        }
    }
    
    return result
}

private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
} 