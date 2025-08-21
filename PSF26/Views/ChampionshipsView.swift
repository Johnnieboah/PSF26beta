import SwiftUI

struct ChampionshipsView: View {
    let completedSeasons: [SeasonHistory]
    @State private var selectedChampionshipType: ChampionshipType?
    @Environment(\.dismiss) private var dismiss
    
    enum ChampionshipType: String, CaseIterable {
        case divisional = "Divisional Champions"
        case conference = "Conference Champions"
        case league = "League Champions"
        
        var icon: String {
            switch self {
            case .divisional: return "building.2.fill"
            case .conference: return "trophy.fill"
            case .league: return "crown.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            if completedSeasons.isEmpty {
                EmptyChampionshipsView()
            } else {
                PopulatedChampionshipsView(
                    completedSeasons: completedSeasons,
                    selectedType: $selectedChampionshipType
                )
            }
        }
        .navigationTitle("Championships")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .navigationDestination(item: $selectedChampionshipType) { type in
            getChampionshipView(for: type)
        }
    }
    
    @ViewBuilder
    private func getChampionshipView(for type: ChampionshipType) -> some View {
        switch type {
        case .divisional:
            DivisionalChampionshipsView(completedSeasons: completedSeasons)
        case .conference:
            ConferenceChampionshipsView(completedSeasons: completedSeasons)
        case .league:
            LeagueChampionshipsView(completedSeasons: completedSeasons)
        }
    }
}

// MARK: - Empty State View
private struct EmptyChampionshipsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "crown")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Championship History")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Complete your first season to see championship records")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Populated Championships View
private struct PopulatedChampionshipsView: View {
    let completedSeasons: [SeasonHistory]
    @Binding var selectedType: ChampionshipsView.ChampionshipType?
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(ChampionshipsView.ChampionshipType.allCases, id: \.self) { type in
                ChampionshipButton(
                    title: type.rawValue,
                    icon: type.icon
                ) {
                    selectedType = type
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Championship Button
private struct ChampionshipButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.blue.gradient)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Divisional Championships View
struct DivisionalChampionshipsView: View {
    let completedSeasons: [SeasonHistory]
    @State private var selectedConference: Conference?
    
    enum Conference: String, CaseIterable {
        case afc = "ACFT"
        case nfc = "NCFT"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ForEach(Conference.allCases, id: \.self) { conference in
                    DivisionalConferenceButton(
                        title: "\(conference.rawValue) Divisions",
                        conference: conference
                    ) {
                        selectedConference = conference
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Divisional Champions")
        .navigationDestination(item: $selectedConference) { conference in
            DivisionsListView(completedSeasons: completedSeasons, conference: conference)
        }
    }
}

// MARK: - Conference Champions View
struct ConferenceChampionshipsView: View {
    let completedSeasons: [SeasonHistory]
    @State private var selectedConference: ConferenceType?
    
    enum ConferenceType: String, CaseIterable {
        case acft = "ACFT"
        case ncft = "NCFT"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ForEach(ConferenceType.allCases, id: \.self) { conference in
                    ConferenceChampionButton(
                        title: "\(conference.rawValue) Champions",
                        conference: conference
                    ) {
                        selectedConference = conference
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Conference Champions")
        .navigationDestination(item: $selectedConference) { conference in
            ConferenceChampionsListView(completedSeasons: completedSeasons, conference: conference)
        }
    }
}

// MARK: - Conference Champions List View
struct ConferenceChampionsListView: View {
    let completedSeasons: [SeasonHistory]
    let conference: ConferenceChampionshipsView.ConferenceType
    
    private var champions: [ChampionEntry] {
        completedSeasons.map { season in
            let championLogoName = conference == .acft ? season.afcChampion : season.nfcChampion
            return ChampionEntry(
                season: season.seasonYear,
                teamLogoName: championLogoName
            )
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(champions.enumerated()), id: \.offset) { index, champion in
                    ChampionRow(
                        rank: romanNumeral(for: index + 1),
                        teamLogoName: champion.teamLogoName,
                        subtitle: "Season \(romanNumeral(for: champion.season))"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("\(conference.rawValue) Champions")
    }
}

// MARK: - Conference Championship Button
private struct ConferenceChampionButton: View {
    let title: String
    let conference: ConferenceChampionshipsView.ConferenceType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - League Championships View
struct LeagueChampionshipsView: View {
    let completedSeasons: [SeasonHistory]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(completedSeasons.enumerated()), id: \.element.id) { index, season in
                    ChampionRow(
                        rank: romanNumeral(for: index + 1),
                        teamLogoName: season.superBowlWinner,
                        subtitle: "Defeated \(TeamData.getTeamDisplayName(season.superBowlRunnerUp))"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("League Champions")
    }
}

// MARK: - Helper Views
private struct DivisionalConferenceButton: View {
    let title: String
    let conference: DivisionalChampionshipsView.Conference
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}



private struct ChampionRow: View {
    let rank: String
    let teamLogoName: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text(rank)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            
            Image(teamLogoName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(TeamData.getTeamDisplayName(teamLogoName))
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Divisions List View
struct DivisionsListView: View {
    let completedSeasons: [SeasonHistory]
    let conference: DivisionalChampionshipsView.Conference
    @State private var selectedDivision: String?
    
    private var divisions: [String] {
        switch conference {
        case .afc:
            return ["ACFT East", "ACFT North", "ACFT South", "ACFT West"]
        case .nfc:
            return ["NCFT East", "NCFT North", "NCFT South", "NCFT West"]
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(divisions, id: \.self) { division in
                Button(action: { selectedDivision = division }) {
                    HStack {
                        Text(division)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("\(conference.rawValue) Divisions")
        .navigationDestination(item: $selectedDivision) { division in
            DivisionChampionsListView(
                completedSeasons: completedSeasons,
                division: division
            )
        }
    }
}

// MARK: - Division Champions List View
struct DivisionChampionsListView: View {
    let completedSeasons: [SeasonHistory]
    let division: String
    
    private var champions: [ChampionEntry] {
        completedSeasons.compactMap { season in
            let championLogoName = getDivisionChampion(for: division, from: season)
            return championLogoName.isEmpty ? nil : ChampionEntry(
                season: season.seasonYear,
                teamLogoName: championLogoName
            )
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(champions.enumerated()), id: \.offset) { index, champion in
                    ChampionRow(
                        rank: romanNumeral(for: index + 1),
                        teamLogoName: champion.teamLogoName,
                        subtitle: "Season \(romanNumeral(for: champion.season))"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("\(division) Champions")
    }
    
    private func getDivisionChampion(for division: String, from season: SeasonHistory) -> String {
        switch division {
        case "ACFT East": return season.afcEast
        case "ACFT North": return season.afcNorth
        case "ACFT South": return season.afcSouth
        case "ACFT West": return season.afcWest
        case "NCFT East": return season.nfcEast
        case "NCFT North": return season.nfcNorth
        case "NCFT South": return season.nfcSouth
        case "NCFT West": return season.nfcWest
        default: return ""
        }
    }
}

// MARK: - Data Models
struct ChampionEntry {
    let season: Int
    let teamLogoName: String
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