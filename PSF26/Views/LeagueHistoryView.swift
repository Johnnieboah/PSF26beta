import SwiftUI

struct LeagueHistoryView: View {
    let completedSeasons: [SeasonHistory]
    @State private var selectedSeason: SeasonHistory?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            if completedSeasons.isEmpty {
                EmptyHistoryView()
            } else {
                PopulatedHistoryView(seasons: completedSeasons, selectedSeason: $selectedSeason)
            }
        }
        .navigationTitle("League History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .navigationDestination(item: $selectedSeason) { season in
            SeasonRecapView(seasonHistory: season, isPostSeasonPopup: false)
        }
    }
}

// MARK: - Empty State View
private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Completed Seasons")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Complete your first season to see league history")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Populated History View
private struct PopulatedHistoryView: View {
    let seasons: [SeasonHistory]
    @Binding var selectedSeason: SeasonHistory?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(seasons.reversed(), id: \.id) { season in
                    SeasonHistoryButton(
                        title: "Season \(romanNumeral(for: season.seasonYear))",
                        subtitle: "Champion: \(TeamData.getTeamDisplayName(season.superBowlWinner))",
                        season: season
                    ) {
                        selectedSeason = season
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Season History Button
private struct SeasonHistoryButton: View {
    let title: String
    let subtitle: String
    let season: SeasonHistory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Roman numeral in circle
                ZStack {
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 50, height: 50)
                    
                    Text(extractRomanNumeral(from: title))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Champion team logo
                Image(season.superBowlWinner)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
            }
            .padding(16)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
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

private func extractRomanNumeral(from title: String) -> String {
    // Extract roman numeral from "Season X" format
    let components = title.components(separatedBy: " ")
    return components.last ?? ""
} 