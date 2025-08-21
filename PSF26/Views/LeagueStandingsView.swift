import SwiftUI

// MARK: - League Standings View
struct LeagueStandingsView: View {
    @ObservedObject var leagueManager: LeagueManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedConference: Conference = .nfc
    @State private var selectedView: StandingsView = .division
    
    enum Conference: String, CaseIterable {
    case nfc = "NCFT"
    case afc = "ACFT"
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
            .onAppear {
                print("🏆 LeagueStandingsView appeared")
                print("🏆 Total teams in league manager: \(leagueManager.allTeams.count)")
                print("🏆 Sample team data:")
                for team in leagueManager.allTeams.prefix(3) {
                    print("   \(team.name) (\(team.logoName)) - \(team.conference) \(team.division) - Record: \(team.record.wins)-\(team.record.losses)")
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
            // Single unified standings for all 32 teams
            AllTeamsStandingsCard(
                teams: getAllTeamsSorted(),
                userTeamName: leagueManager.userTeam?.logoName ?? ""
            )
        }
    }
    
    // MARK: - Helper Methods
    private func getDivisionsForConference(_ conference: Conference) -> [String] {
        switch conference {
        case .nfc:
            return ["NCFT North", "NCFT East", "NCFT South", "NCFT West"]
        case .afc:
            return ["ACFT North", "ACFT East", "ACFT South", "ACFT West"]
        }
    }
    
    private func getTeamsForDivision(_ division: String) -> [LeagueTeam] {
        return leagueManager.allTeams
            .filter { $0.division == division }
            .sorted { team1, team2 in
                // Use proper NFL tiebreaking logic, not simple win percentage
                return leagueManager.compareTeamRecords(team1: team1, team2: team2)
            }
    }
    
    private func getTeamsForConference(_ conference: Conference) -> [LeagueTeam] {
        // CRITICAL: Use proper NFL playoff seeding logic, not simple win percentage
        // This ensures division winners are ALWAYS ranked 1-4, wild cards 5-7
        let conferenceTeams = leagueManager.allTeams.filter { $0.conference == conference.rawValue }
        
        // Get divisions in this conference  
        let conferenceDivisions = Set(conferenceTeams.map { $0.division })
        var divisionWinners: [LeagueTeam] = []
        var wildCardCandidates: [LeagueTeam] = []
        
        // STEP 1: Find division winner for each division
        for division in conferenceDivisions.sorted() {
            let divisionTeams = conferenceTeams.filter { $0.division == division }
            let sortedDivisionTeams = divisionTeams.sorted { team1, team2 in
                return leagueManager.compareTeamRecords(team1: team1, team2: team2)
            }
            
            if let winner = sortedDivisionTeams.first {
                divisionWinners.append(winner)
                // Add remaining teams to wild card pool
                let remainingTeams = Array(sortedDivisionTeams.dropFirst())
                wildCardCandidates.append(contentsOf: remainingTeams)
            }
        }
        
        // STEP 2: Sort division winners by record for seeds 1-4
        divisionWinners.sort { team1, team2 in
            return leagueManager.compareTeamRecords(team1: team1, team2: team2)
        }
        
        // STEP 3: Sort wild card candidates for seeds 5+
        wildCardCandidates.sort { team1, team2 in
            return leagueManager.compareTeamRecords(team1: team1, team2: team2)
        }
        
        // STEP 4: Combine with proper NFL seeding - Division winners ALWAYS 1-4
        return divisionWinners + wildCardCandidates
    }
    
    private func getAllTeamsSorted() -> [LeagueTeam] {
        // Get both conferences sorted with proper NFL playoff seeding logic
        let afcTeams = getTeamsForConference(.afc)
        let nfcTeams = getTeamsForConference(.nfc)
        
        // Combine both conferences - AFC first, then NFC
        return afcTeams + nfcTeams
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

// MARK: - All Teams Standings Card
struct AllTeamsStandingsCard: View {
    let teams: [LeagueTeam]
    let userTeamName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("All Teams")
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
            
            // Teams List
            VStack(spacing: 8) {
                ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                    HStack(spacing: 16) {
                        // Rank with playoff indicator
                        HStack(spacing: 4) {
                            Text("\(index + 1)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(rankColor(for: index))
                                .frame(width: 25)
                            
                            if index < 14 { // Top 14 make playoffs (7 per conference)
                                Circle()
                                    .fill(rankColor(for: index))
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
                            .lineLimit(1)
                        
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
                                index < 14 ? rankColor(for: index).opacity(0.05) : .clear
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                team.logoName == userTeamName ? .blue.opacity(0.3) :
                                index < 14 ? rankColor(for: index).opacity(0.3) : .clear,
                                lineWidth: team.logoName == userTeamName || index < 14 ? 1 : 0
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
    
    private func rankColor(for index: Int) -> Color {
        switch index {
        case 0...1: return .green      // Top 2 seeds (bye week)
        case 2...6: return .blue       // Wild card teams
        case 7...13: return .orange    // Playoff contenders
        default: return .gray          // Out of playoffs
        }
    }
}

#Preview {
    LeagueStandingsView(leagueManager: LeagueManager())
}