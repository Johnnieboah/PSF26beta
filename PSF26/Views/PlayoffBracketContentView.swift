import SwiftUI

struct PlayoffBracketContentView: View {
    @ObservedObject var leagueManager: LeagueManager
    @State private var currentPlayoffWeek: Int = 19
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(leagueManager.currentWeek >= 19 ? "Playoff Bracket" : "Playoff Picture")
                    .font(.title)
                    .fontWeight(.bold)
                
                // NCFT Side
                VStack(alignment: .leading, spacing: 15) {
                    Text("NCFT")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Wild Card Round (NCFT)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image("wildcardround")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40)
                            Text("Wild Card")
                                .font(.headline)
                        }
                        
                        ForEach([0, 1, 2], id: \.self) { index in
                            if let matchup = getWildCardMatchup(conference: "NCFT", index: index) {
                                HStack {
                                    Text("#\(matchup.homeTeamSeed)")
                                        .fontWeight(.bold)
                                    Text(matchup.homeTeam.logoName)
                                        .foregroundColor(getTeamColor(matchup.homeTeam))
                                    Spacer()
                                    Text("vs")
                                    Spacer()
                                    Text(matchup.awayTeam.logoName)
                                        .foregroundColor(getTeamColor(matchup.awayTeam))
                                    Text("#\(matchup.awayTeamSeed)")
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Divisional Round (NCFT)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image("divisionalround")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40)
                            Text("Divisional")
                                .font(.headline)
                        }
                        
                        ForEach([0, 1], id: \.self) { index in
                            if let matchup = getDivisionalMatchup(conference: "NCFT", index: index) {
                                HStack {
                                    Text("#\(matchup.homeTeamSeed)")
                                        .fontWeight(.bold)
                                    Text(matchup.homeTeam.logoName)
                                        .foregroundColor(getTeamColor(matchup.homeTeam))
                                    Spacer()
                                    Text("vs")
                                    Spacer()
                                    Text(matchup.awayTeam.logoName)
                                        .foregroundColor(getTeamColor(matchup.awayTeam))
                                    Text("#\(matchup.awayTeamSeed)")
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Conference Championship (NCFT)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image("conferencechampionship1_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40)
                            Text("Conference Championship")
                                .font(.headline)
                        }
                        
                        if let matchup = getConferenceChampionship(conference: "NCFT") {
                            HStack {
                                Text("#\(matchup.homeTeamSeed)")
                                    .fontWeight(.bold)
                                Text(matchup.homeTeam.logoName)
                                    .foregroundColor(getTeamColor(matchup.homeTeam))
                                Spacer()
                                Text("vs")
                                Spacer()
                                Text(matchup.awayTeam.logoName)
                                    .foregroundColor(getTeamColor(matchup.awayTeam))
                                Text("#\(matchup.awayTeamSeed)")
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical)
                
                // ACFT Side
                VStack(alignment: .leading, spacing: 15) {
                    Text("ACFT")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Wild Card Round (ACFT)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image("wildcardround")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40)
                            Text("Wild Card")
                                .font(.headline)
                        }
                        
                        ForEach([0, 1, 2], id: \.self) { index in
                            if let matchup = getWildCardMatchup(conference: "ACFT", index: index) {
                                HStack {
                                    Text("#\(matchup.homeTeamSeed)")
                                        .fontWeight(.bold)
                                    Text(matchup.homeTeam.logoName)
                                        .foregroundColor(getTeamColor(matchup.homeTeam))
                                    Spacer()
                                    Text("vs")
                                    Spacer()
                                    Text(matchup.awayTeam.logoName)
                                        .foregroundColor(getTeamColor(matchup.awayTeam))
                                    Text("#\(matchup.awayTeamSeed)")
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Divisional Round (ACFT)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image("divisionalround")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40)
                            Text("Divisional")
                                .font(.headline)
                        }
                        
                        ForEach([0, 1], id: \.self) { index in
                            if let matchup = getDivisionalMatchup(conference: "ACFT", index: index) {
                                HStack {
                                    Text("#\(matchup.homeTeamSeed)")
                                        .fontWeight(.bold)
                                    Text(matchup.homeTeam.logoName)
                                        .foregroundColor(getTeamColor(matchup.homeTeam))
                                    Spacer()
                                    Text("vs")
                                    Spacer()
                                    Text(matchup.awayTeam.logoName)
                                        .foregroundColor(getTeamColor(matchup.awayTeam))
                                    Text("#\(matchup.awayTeamSeed)")
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Conference Championship (ACFT)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image("conferencechampionship1_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40)
                            Text("Conference Championship")
                                .font(.headline)
                        }
                        
                        if let matchup = getConferenceChampionship(conference: "ACFT") {
                            HStack {
                                Text("#\(matchup.homeTeamSeed)")
                                    .fontWeight(.bold)
                                Text(matchup.homeTeam.logoName)
                                    .foregroundColor(getTeamColor(matchup.homeTeam))
                                Spacer()
                                Text("vs")
                                Spacer()
                                Text(matchup.awayTeam.logoName)
                                    .foregroundColor(getTeamColor(matchup.awayTeam))
                                Text("#\(matchup.awayTeamSeed)")
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical)
                
                // Super Bowl
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image("championshiplogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40)
                        Text("Super Bowl \(getRomanNumeral())")
                            .font(.headline)
                    }
                    
                    if let matchup = getChampionshipGame() {
                        HStack {
                            Text("#\(matchup.homeTeamSeed)")
                                .fontWeight(.bold)
                            Text(matchup.homeTeam.logoName)
                                .foregroundColor(getTeamColor(matchup.homeTeam))
                            Spacer()
                            Text("vs")
                            Spacer()
                            Text(matchup.awayTeam.logoName)
                                .foregroundColor(getTeamColor(matchup.awayTeam))
                            Text("#\(matchup.awayTeamSeed)")
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            currentPlayoffWeek = leagueManager.currentWeek
        }
        .onChange(of: leagueManager.currentWeek, { _, newWeek in
            currentPlayoffWeek = newWeek
        })
    }
    
    // Helper function to get Wild Card matchups
    private func getWildCardMatchup(conference: String, index: Int) -> (homeTeam: LeagueTeam, awayTeam: LeagueTeam, homeTeamSeed: Int, awayTeamSeed: Int)? {
        if leagueManager.currentWeek >= 19 {
            // During playoffs, use actual bracket
            let wildCardBracket = leagueManager.bracketManager.getCurrentBracket()
            let wildCardMatchups = wildCardBracket.filter { matchup in
                (conference == "ACFT" ? matchup.homeTeam.conference == "ACFT" : matchup.homeTeam.conference == "NCFT")
            }
            
            guard index < wildCardMatchups.count else { return nil }
            let matchup = wildCardMatchups[index]
            return (homeTeam: matchup.homeTeam, awayTeam: matchup.awayTeam, homeTeamSeed: matchup.homeTeamSeed, awayTeamSeed: matchup.awayTeamSeed)
        } else {
            // During regular season, use projected playoff teams
            let teams = conference == "ACFT" ? leagueManager.getProjectedPlayoffTeams(conference: "ACFT") : leagueManager.getProjectedPlayoffTeams(conference: "NCFT")
            
            // Wild card matchups: 2v7, 3v6, 4v5
            let matchups = [
                (2,7), (3,6), (4,5)
            ]
            
            guard index < matchups.count else { return nil }
            let (homeSeed, awaySeed) = matchups[index]
            
            guard homeSeed - 1 < teams.count, awaySeed - 1 < teams.count else { return nil }
            let homeTeam = teams[homeSeed - 1]
            let awayTeam = teams[awaySeed - 1]
            
            return (homeTeam: homeTeam, awayTeam: awayTeam, homeTeamSeed: homeSeed, awayTeamSeed: awaySeed)
        }
    }
    
    // Helper function to get Divisional matchups
    private func getDivisionalMatchup(conference: String, index: Int) -> (homeTeam: LeagueTeam, awayTeam: LeagueTeam, homeTeamSeed: Int, awayTeamSeed: Int)? {
        if leagueManager.currentWeek >= 20 {
            // During divisional round, use actual bracket
            let divisionalBracket = leagueManager.bracketManager.getCurrentBracket()
            let divisionalMatchups = divisionalBracket.filter { matchup in
                (conference == "ACFT" ? matchup.homeTeam.conference == "ACFT" : matchup.homeTeam.conference == "NCFT")
            }
            
            guard index < divisionalMatchups.count else { return nil }
            let matchup = divisionalMatchups[index]
            return (homeTeam: matchup.homeTeam, awayTeam: matchup.awayTeam, homeTeamSeed: matchup.homeTeamSeed, awayTeamSeed: matchup.awayTeamSeed)
        } else {
            // During regular season or wild card, show projected matchups
            let teams = conference == "ACFT" ? leagueManager.getProjectedPlayoffTeams(conference: "ACFT") : leagueManager.getProjectedPlayoffTeams(conference: "NCFT")
            
            // First seed gets shown but no opponent yet
            if index == 0, !teams.isEmpty {
                let firstSeedTeam = teams[0]
                return (homeTeam: firstSeedTeam, awayTeam: firstSeedTeam, homeTeamSeed: 1, awayTeamSeed: 1)
            }
            
            return nil
        }
    }
    
    // Helper function to get Conference Championship matchups
    private func getConferenceChampionship(conference: String) -> (homeTeam: LeagueTeam, awayTeam: LeagueTeam, homeTeamSeed: Int, awayTeamSeed: Int)? {
        if leagueManager.currentWeek >= 21 {
            // During conference championships, use actual bracket
            let conferenceBracket = leagueManager.bracketManager.getCurrentBracket()
            if let matchup = conferenceBracket.first(where: { matchup in
                (conference == "ACFT" ? matchup.homeTeam.conference == "ACFT" : matchup.homeTeam.conference == "NCFT")
            }) {
                return (homeTeam: matchup.homeTeam, awayTeam: matchup.awayTeam, homeTeamSeed: matchup.homeTeamSeed, awayTeamSeed: matchup.awayTeamSeed)
            }
        }
        return nil
    }
    
    // Helper function to get Championship Game matchup
    private func getChampionshipGame() -> (homeTeam: LeagueTeam, awayTeam: LeagueTeam, homeTeamSeed: Int, awayTeamSeed: Int)? {
        if leagueManager.currentWeek >= 22 {
            // During super bowl, use actual bracket
            let superBowlBracket = leagueManager.bracketManager.getCurrentBracket()
            if let matchup = superBowlBracket.first {
                return (homeTeam: matchup.homeTeam, awayTeam: matchup.awayTeam, homeTeamSeed: matchup.homeTeamSeed, awayTeamSeed: matchup.awayTeamSeed)
            }
        }
        return nil
    }
    
    // Helper function to get team color based on elimination status
    private func getTeamColor(_ team: LeagueTeam) -> Color {
        if leagueManager.currentWeek >= 19 {
            // During playoffs, show elimination colors
            let allResults = leagueManager.bracketManager.getAllResults()
            // Check each week's results
            for (_, weekResults) in allResults {
                for result in weekResults {
                    if result.winner.logoName == team.logoName {
                        return .green
                    } else if result.loser.logoName == team.logoName {
                        return .red
                    }
                }
            }
        }
        return .primary
    }
    
    // Helper function to get Roman numeral for current season
    private func getRomanNumeral() -> String {
        let currentWeek = leagueManager.currentWeek
        let season = (currentWeek - 1) / 18 + 1 // 18 weeks per season
        
        let romanNumerals = [
            "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
            "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"
        ]
        
        return romanNumerals[min(season - 1, romanNumerals.count - 1)]
    }
} 