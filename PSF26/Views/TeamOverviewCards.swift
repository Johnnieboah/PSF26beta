import SwiftUI

// MARK: - Team Overalls Card
struct TeamOverallsCard: View {
    let teamOveralls: (offense: Int, defense: Int, overall: Int)
    let teamColor: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardHeader
            overallsGrid
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .standardCard(.ultraThin16)
    }
    
    private var cardHeader: some View {
        // Centered title per request; remove team name and center within the bubble
        HStack {
            Spacer(minLength: 0)
            Text("Overalls")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Spacer(minLength: 0)
        }
    }
    
    private var overallsGrid: some View {
        // Reordered: Offense, Defense, Overall
        HStack(spacing: 20) {
            OverallStatView(
                title: "Offense",
                value: teamOveralls.offense,
                color: ratingColor(teamOveralls.offense),
                isMainStat: false
            )
            Spacer()
            OverallStatView(
                title: "Defense",
                value: teamOveralls.defense,
                color: ratingColor(teamOveralls.defense),
                isMainStat: false
            )
            Spacer()
            OverallStatView(
                title: "Overall",
                value: teamOveralls.overall,
                color: ratingColor(teamOveralls.overall),
                isMainStat: true
            )
        }
    }
    
    private func ratingColor(_ rating: Int) -> Color {
        // Create a smooth red-to-green gradient based on rating
        // Typical NFL team ratings range from ~65-95, but we'll use 60-95 for better color spread
        let normalizedRating = max(0.0, min(1.0, Double(rating - 60) / 35.0))
        
        // Interpolate between red and green
        let red = 1.0 - normalizedRating
        let green = normalizedRating
        
        return Color(red: red, green: green, blue: 0.0)
    }
}

// MARK: - Overall Stat View
struct OverallStatView: View {
    let title: String
    let value: Int
    let color: Color
    let isMainStat: Bool
    
    var body: some View {
        // Titles above numbers per request
        VStack(spacing: 6) {
            Text(title)
                .font(isMainStat ? .subheadline : .caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text("\(value)")
                .font(isMainStat ? .largeTitle : .title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Top Players Card
struct TopPlayersCard: View {
    let players: [PlayerData]
    let teamColor: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardHeader
            playersList
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .standardCard(.ultraThin16)
    }
    
    private var cardHeader: some View {
        HStack {
            Image(systemName: "star.fill")
                .font(.title2)
                .foregroundColor(.yellow)
            
            Text("Top Players")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(players.count) Players")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var playersList: some View {
        VStack(spacing: 12) {
            ForEach(Array(players.enumerated()), id: \.offset) { index, player in
                TopPlayerRowView(
                    player: player,
                    rank: index + 1,
                    teamColor: teamColor
                )
            }
        }
    }
}

// MARK: - Top Player Row View
struct TopPlayerRowView: View {
    let player: PlayerData
    let rank: Int
    let teamColor: String
    
    var body: some View {
        HStack(spacing: 12) {
            rankBadge
            playerInfo
            Spacer()
            overallBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rank == 1 ? Color(hex: teamColor).opacity(0.1) : .clear)
        )
    }
    
    private var rankBadge: some View {
        Text("\(rank)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(rank == 1 ? .yellow : .secondary)
            )
    }
    
    private var playerInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(player.fullName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("\(player.position) • #\(player.number)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var overallBadge: some View {
        Text("\(player.overall)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 32, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(overallColor(player.overall))
            )
    }
    
    private func overallColor(_ rating: Int) -> Color {
        // Use the same red-to-green gradient system
        let normalizedRating = max(0.0, min(1.0, Double(rating - 60) / 35.0))
        
        // Interpolate between red and green
        let red = 1.0 - normalizedRating
        let green = normalizedRating
        
        return Color(red: red, green: green, blue: 0.0)
    }
}

// MARK: - Team Stats Card
struct TeamStatsCard: View {
    let playerCount: Int
    let scheduleCount: Int
    let teamColor: String
    let teamLogoName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardHeader
            statsGrid
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .standardCard(.ultraThin16)
    }
    
    private var cardHeader: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            Text("Team Stats")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private var statsGrid: some View {
        HStack(spacing: 20) {
            StatCard(
                title: "Players",
                value: "\(playerCount)",
                style: .highlighted(.blue)
            )
            
            StatCard(
                title: "Games",
                value: "\(scheduleCount)",
                style: .highlighted(.green)
            )
            
            StatCard(
                title: "Cap Space",
                value: formatCapSpace(NFLCapData.getCapSpace(for: teamLogoName)),
                style: .highlighted(.purple)
            )
        }
    }

    private func formatCapSpace(_ cap: Int) -> String {
        let millions = Double(cap) / 1_000_000.0
        let formatted = String(format: "%.0fM", abs(millions))
        return cap < 0 ? "-$\(formatted)" : "$\(formatted)"
    }
} 