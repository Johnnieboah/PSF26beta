import SwiftUI

// MARK: - League Standings View
struct LeagueStandingsView: View {
    @ObservedObject var leagueManager: LeagueManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedConference: Conference = .nfc
    @State private var selectedView: StandingsView = .division
    
    enum Conference: String, CaseIterable {
        case nfc = "NFC"
        case afc = "AFC"
    }
    
    enum StandingsView: String, CaseIterable {
        case division = "Division"
        case conference = "Conference"
        case overall = "League"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View Selector
                viewSelectorHeader
                
                // Conference Selector (for division/conference views)
                if selectedView != .overall {
                    conferenceSelectorHeader
                }
                
                // Standings Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedView {
                        case .division:
                            divisionStandingsContent
                        case .conference:
                            conferenceStandingsContent
                        case .overall:
                            overallStandingsContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Standings")
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
    
    // MARK: - View Selector Header
    private var viewSelectorHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(StandingsView.allCases, id: \.self) { view in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedView = view
                        }
                    } label: {
                        Text(view.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedView == view ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedView == view ? .blue : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            
            Divider()
        }
    }
    
    // MARK: - Conference Selector Header
    private var conferenceSelectorHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Conference.allCases, id: \.self) { conference in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedConference = conference
                        }
                    } label: {
                        Text(conference.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedConference == conference ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedConference == conference ? .orange : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            
            Divider()
        }
    }
    
    // MARK: - Division Standings Content
    private var divisionStandingsContent: some View {
        ForEach(getDivisionsForConference(selectedConference), id: \.self) { division in
            DivisionStandingsCard(
                division: division,
                teams: getTeamsForDivision(division),
                userTeamName: leagueManager.userTeam?.logoName ?? ""
            )
        }
    }
    
    // MARK: - Conference Standings Content
    private var conferenceStandingsContent: some View {
        ConferenceStandingsCard(
            conference: selectedConference,
            teams: getTeamsForConference(selectedConference),
            userTeamName: leagueManager.userTeam?.logoName ?? ""
        )
    }
    
    // MARK: - Overall Standings Content
    private var overallStandingsContent: some View {
        VStack(spacing: 16) {
            OverallStandingsCard(
                conference: .nfc,
                teams: getTeamsForConference(.nfc),
                userTeamName: leagueManager.userTeam?.logoName ?? ""
            )
            
            OverallStandingsCard(
                conference: .afc,
                teams: getTeamsForConference(.afc),
                userTeamName: leagueManager.userTeam?.logoName ?? ""
            )
        }
    }
    
    // MARK: - Helper Methods
    private func getDivisionsForConference(_ conference: Conference) -> [String] {
        switch conference {
        case .nfc:
            return ["NFC North", "NFC East", "NFC South", "NFC West"]
        case .afc:
            return ["AFC North", "AFC East", "AFC South", "AFC West"]
        }
    }
    
    private func getTeamsForDivision(_ division: String) -> [LeagueTeam] {
        return leagueManager.allTeams
            .filter { $0.division == division }
            .sorted { team1, team2 in
                if team1.record.winPercentage != team2.record.winPercentage {
                    return team1.record.winPercentage > team2.record.winPercentage
                }
                return team1.record.wins > team2.record.wins
            }
    }
    
    private func getTeamsForConference(_ conference: Conference) -> [LeagueTeam] {
        return leagueManager.allTeams
            .filter { $0.conference == conference.rawValue }
            .sorted { team1, team2 in
                if team1.record.winPercentage != team2.record.winPercentage {
                    return team1.record.winPercentage > team2.record.winPercentage
                }
                return team1.record.wins > team2.record.wins
            }
    }
}

// MARK: - Division Standings Card
struct DivisionStandingsCard: View {
    let division: String
    let teams: [LeagueTeam]
    let userTeamName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Division Header
            HStack {
                Text(division)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("W-L")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .center)
            }
            
            // Teams
            VStack(spacing: 12) {
                ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                    HStack(spacing: 16) {
                        // Rank
                        Text("\(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(index == 0 ? .green : .primary)
                            .frame(width: 20)
                        
                        // Team Logo
                        Image(team.logoName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                        
                        // Team Name
                        Text(TeamData.getTeamDisplayName(team.logoName))
                            .font(.subheadline)
                            .fontWeight(team.logoName == userTeamName ? .bold : .medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Record
                        Text("\(team.record.wins)-\(team.record.losses)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(team.logoName == userTeamName ? .blue : .secondary)
                            .frame(width: 50, alignment: .center)
                        
                        // Win Percentage
                        Text(String(format: "%.3f", team.record.winPercentage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(team.logoName == userTeamName ? .blue.opacity(0.1) : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                index == 0 ? .green.opacity(0.3) : 
                                team.logoName == userTeamName ? .blue.opacity(0.3) : .clear,
                                lineWidth: index == 0 || team.logoName == userTeamName ? 1.5 : 0
                            )
                    )
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

// MARK: - Conference Standings Card
struct ConferenceStandingsCard: View {
    let conference: LeagueStandingsView.Conference
    let teams: [LeagueTeam]
    let userTeamName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Conference Header
            HStack {
                Text("\(conference.rawValue) Conference")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Text("W-L")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .center)
                    
                    Text("PCT")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
            
            // Teams
            VStack(spacing: 8) {
                ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                    HStack(spacing: 16) {
                        // Rank with playoff indicator
                        HStack(spacing: 4) {
                            Text("\(index + 1)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(playoffColor(for: index))
                                .frame(width: 20)
                            
                            if index < 7 { // Top 7 make playoffs
                                Circle()
                                    .fill(playoffColor(for: index))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        
                        // Team Logo
                        Image(team.logoName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                        
                        // Team Name
                        Text(TeamData.getTeamDisplayName(team.logoName))
                            .font(.subheadline)
                            .fontWeight(team.logoName == userTeamName ? .bold : .medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Record
                        Text("\(team.record.wins)-\(team.record.losses)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(team.logoName == userTeamName ? .blue : .secondary)
                            .frame(width: 50, alignment: .center)
                        
                        // Win Percentage
                        Text(String(format: "%.3f", team.record.winPercentage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                team.logoName == userTeamName ? .blue.opacity(0.1) :
                                index < 7 ? playoffColor(for: index).opacity(0.05) : .clear
                            )
                    )
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
    
    private func playoffColor(for rank: Int) -> Color {
        switch rank {
        case 0: return .green // Division winner
        case 1, 2, 3: return .orange // Division winners
        case 4, 5, 6: return .blue // Wild card
        default: return .secondary
        }
    }
}

// MARK: - Overall Standings Card
struct OverallStandingsCard: View {
    let conference: LeagueStandingsView.Conference
    let teams: [LeagueTeam]
    let userTeamName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Conference Header
            HStack {
                Text("\(conference.rawValue) Conference")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("(\(teams.count) teams)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Top teams preview
            VStack(spacing: 8) {
                ForEach(Array(teams.prefix(8).enumerated()), id: \.element.id) { index, team in
                    HStack(spacing: 12) {
                        // Rank
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(index < 7 ? .green : .secondary)
                            .frame(width: 20)
                        
                        // Team Logo
                        Image(team.logoName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        
                        // Team Name (abbreviated)
                        Text(getAbbreviatedName(team.logoName))
                            .font(.caption)
                            .fontWeight(team.logoName == userTeamName ? .bold : .medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Record
                        Text("\(team.record.wins)-\(team.record.losses)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(team.logoName == userTeamName ? .blue : .secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(team.logoName == userTeamName ? .blue.opacity(0.1) : .clear)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func getAbbreviatedName(_ logoName: String) -> String {
        let abbreviations: [String: String] = [
            "Chicago": "CHI", "Detroit": "DET", "GreenBay": "GB", "Minnesota": "MIN",
            "Dallas": "DAL", "NYN": "NYG", "Philadelphia": "PHI", "Washington": "WAS",
            "Atlanta": "ATL", "Carolina": "CAR", "NewOrleans": "NO", "TampaBay": "TB",
            "Arizona": "ARI", "LAN": "LAR", "SanFrancisco": "SF", "Seattle": "SEA",
            "Baltimore": "BAL", "Cincinnati": "CIN", "Cleveland": "CLE", "Pittsburgh": "PIT",
            "Buffalo": "BUF", "Miami": "MIA", "NewEngland": "NE", "NYA": "NYJ",
            "Houston": "HOU", "Indianapolis": "IND", "Jacksonville": "JAX", "Tennessee": "TEN",
            "Denver": "DEN", "KansasCity": "KC", "LasVegas": "LV", "LAA": "LAC"
        ]
        
        return abbreviations[logoName] ?? logoName
    }
}

#Preview {
    LeagueStandingsView(leagueManager: LeagueManager())
}