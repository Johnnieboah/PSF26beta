import SwiftUI

struct PlayoffBracketView: View {
    let leagueManager: LeagueManager
    let selectedTeam: TeamData
    
    private let roundLogos = ["wildcardround", "divisionalround", "conferencechampionship1_logo", "championshiplogo"]
    
    // Add computed properties for playoff teams based on current standings
    private var nfcPlayoffTeams: [LeagueTeam] {
        // Get all NFC teams and sort them by NFL playoff seeding rules
        let nfcTeams = leagueManager.allTeams.filter { $0.conference == "NCFT" }
        
        // Group teams by division
        let divisionTeams = Dictionary(grouping: nfcTeams) { $0.division }
        var divisionWinners: [LeagueTeam] = []
        var wildCardCandidates: [LeagueTeam] = []
        
        // Get division winners
        for division in divisionTeams.keys.sorted() {
            guard let teams = divisionTeams[division] else { continue }
            let sortedDivisionTeams = teams.sorted { team1, team2 in
                let record1 = team1.record
                let record2 = team2.record
                let winPct1 = Double(record1.wins) / Double(max(record1.gamesPlayed, 1))
                let winPct2 = Double(record2.wins) / Double(max(record2.gamesPlayed, 1))
                return winPct1 > winPct2
            }
            if let winner = sortedDivisionTeams.first {
                divisionWinners.append(winner)
                wildCardCandidates.append(contentsOf: sortedDivisionTeams.dropFirst())
            }
        }
        
        // Sort division winners by record (seeds 1-4)
        divisionWinners.sort { team1, team2 in
            let record1 = team1.record
            let record2 = team2.record
            let winPct1 = Double(record1.wins) / Double(max(record1.gamesPlayed, 1))
            let winPct2 = Double(record2.wins) / Double(max(record2.gamesPlayed, 1))
            return winPct1 > winPct2
        }
        
        // Sort wild card candidates by record and take top 3 (seeds 5-7)
        wildCardCandidates.sort { team1, team2 in
            let record1 = team1.record
            let record2 = team2.record
            let winPct1 = Double(record1.wins) / Double(max(record1.gamesPlayed, 1))
            let winPct2 = Double(record2.wins) / Double(max(record2.gamesPlayed, 1))
            return winPct1 > winPct2
        }
        let wildCards = Array(wildCardCandidates.prefix(3))
        
        // Return combined list - division winners first (1-4), then wild cards (5-7)
        return divisionWinners + wildCards
    }
    
    private var afcPlayoffTeams: [LeagueTeam] {
        // Get all AFC teams and sort them by NFL playoff seeding rules
        let afcTeams = leagueManager.allTeams.filter { $0.conference == "ACFT" }
        
        // Group teams by division
        let divisionTeams = Dictionary(grouping: afcTeams) { $0.division }
        var divisionWinners: [LeagueTeam] = []
        var wildCardCandidates: [LeagueTeam] = []
        
        // Get division winners
        for division in divisionTeams.keys.sorted() {
            guard let teams = divisionTeams[division] else { continue }
            let sortedDivisionTeams = teams.sorted { team1, team2 in
                let record1 = team1.record
                let record2 = team2.record
                let winPct1 = Double(record1.wins) / Double(max(record1.gamesPlayed, 1))
                let winPct2 = Double(record2.wins) / Double(max(record2.gamesPlayed, 1))
                return winPct1 > winPct2
            }
            if let winner = sortedDivisionTeams.first {
                divisionWinners.append(winner)
                wildCardCandidates.append(contentsOf: sortedDivisionTeams.dropFirst())
            }
        }
        
        // Sort division winners by record (seeds 1-4)
        divisionWinners.sort { team1, team2 in
            let record1 = team1.record
            let record2 = team2.record
            let winPct1 = Double(record1.wins) / Double(max(record1.gamesPlayed, 1))
            let winPct2 = Double(record2.wins) / Double(max(record2.gamesPlayed, 1))
            return winPct1 > winPct2
        }
        
        // Sort wild card candidates by record and take top 3 (seeds 5-7)
        wildCardCandidates.sort { team1, team2 in
            let record1 = team1.record
            let record2 = team2.record
            let winPct1 = Double(record1.wins) / Double(max(record1.gamesPlayed, 1))
            let winPct2 = Double(record2.wins) / Double(max(record2.gamesPlayed, 1))
            return winPct1 > winPct2
        }
        let wildCards = Array(wildCardCandidates.prefix(3))
        
        // Return combined list - division winners first (1-4), then wild cards (5-7)
        return divisionWinners + wildCards
    }
    
    // Helper function to get team by seed
    private func getTeamBySeed(conference: String, seed: Int) -> LeagueTeam? {
        let teams = conference == "NFC" ? nfcPlayoffTeams : afcPlayoffTeams
        
        // Always show original seeding position
        if seed >= 1 && seed <= teams.count {
            let originalTeam = teams[seed - 1]
            
            // During playoffs, check if this team has advanced
            if leagueManager.currentWeek >= 19 {
                let currentBracket = leagueManager.bracketManager.getCurrentBracket()
                let weekResults = leagueManager.bracketManager.getResults(for: leagueManager.currentWeek - 1)
                
                // Check if team won their previous matchup
                if weekResults.contains(where: { $0.winner.logoName == originalTeam.logoName }) {
                    return originalTeam
                }
                
                // Check if team was eliminated
                if weekResults.contains(where: { $0.loser.logoName == originalTeam.logoName }) {
                    return originalTeam // Still show eliminated teams
                }
                
                // Check if team has a bye (seed 1)
                if seed == 1 && leagueManager.currentWeek == 19 {
                    return originalTeam
                }
                
                // Check if team is playing in current round
                if currentBracket.contains(where: { 
                    ($0.homeTeam.logoName == originalTeam.logoName) ||
                    ($0.awayTeam.logoName == originalTeam.logoName)
                }) {
                    return originalTeam
                }
            }
            
            return originalTeam
        }
        
        return nil
    }
    
    // Helper function to check if a team is advancing
    private func isTeamAdvancing(_ team: LeagueTeam?) -> Bool {
        guard let team = team else { return false }
        
        if leagueManager.currentWeek >= 19 {
            // During playoffs, check if team won their previous matchup
            let prevWeekResults = leagueManager.bracketManager.getResults(for: leagueManager.currentWeek - 1)
            return prevWeekResults.contains { $0.winner.logoName == team.logoName }
        }
        
        return false
    }
    
    // Helper function to check if it's the user's team
    private func isUserTeam(_ team: LeagueTeam?) -> Bool {
        guard let team = team else { return false }
        return team.logoName == selectedTeam.logoName
    }
    
    // Helper function to get team color based on elimination status
    private func getTeamColor(_ team: LeagueTeam?) -> Color {
        guard let team = team else { return .secondary }
        
        if leagueManager.currentWeek >= 19 {
            // Check if team was eliminated in any previous round
            for week in 19..<leagueManager.currentWeek {
                let weekResults = leagueManager.bracketManager.getResults(for: week)
                if weekResults.contains(where: { $0.loser.logoName == team.logoName }) {
                    return .red.opacity(0.7) // Eliminated teams shown in faded red
                }
            }
            
            // Check if team won in the current round
            let currentWeekResults = leagueManager.bracketManager.getResults(for: leagueManager.currentWeek)
            if currentWeekResults.contains(where: { $0.winner.logoName == team.logoName }) {
                return .green // Winners shown in green
            }
            
            // Check if team is playing in current round
            let currentBracket = leagueManager.bracketManager.getCurrentBracket()
            if currentBracket.contains(where: { 
                $0.homeTeam.logoName == team.logoName || 
                $0.awayTeam.logoName == team.logoName 
            }) {
                return .primary // Active teams shown in primary color
            }
            
            // #1 seed in wildcard round gets primary color
            if leagueManager.currentWeek == 19 {
                let teams = team.conference == "NCFT" ? nfcPlayoffTeams : afcPlayoffTeams
                if !teams.isEmpty && teams[0].logoName == team.logoName {
                    return .primary
                }
            }
        }
        
        return isUserTeam(team) ? .blue : .primary
    }
    
    // Helper function to get wild card matchups
    private func getWildCardMatchup(conference: String, index: Int) -> (homeTeam: LeagueTeam, awayTeam: LeagueTeam, homeTeamSeed: Int, awayTeamSeed: Int)? {
        // For weeks after wild card round (20+), show the completed wild card matchups
        if leagueManager.currentWeek >= 20 {
            let wildCardResults = leagueManager.bracketManager.getResults(for: 19)
            let wildCardMatchups = wildCardResults.filter { result in
                conference == "NFC" ? result.winner.conference == "NCFT" : result.winner.conference == "ACFT"
            }.map { result in
                (winner: result.winner, loser: result.loser, winnerSeed: getOriginalSeed(result.winner, in: conference == "NFC" ? nfcPlayoffTeams : afcPlayoffTeams), loserSeed: getOriginalSeed(result.loser, in: conference == "NFC" ? nfcPlayoffTeams : afcPlayoffTeams))
            }.sorted { $0.winnerSeed < $1.winnerSeed }
            
            if index < wildCardMatchups.count {
                let matchup = wildCardMatchups[index]
                return (homeTeam: matchup.winner, awayTeam: matchup.loser,
                       homeTeamSeed: matchup.winnerSeed, awayTeamSeed: matchup.loserSeed)
            }
        }
        // During wild card round (week 19), show current matchups
        else if leagueManager.currentWeek == 19 {
            let currentBracket = leagueManager.bracketManager.getCurrentBracket()
            let wildCardMatchups = currentBracket.filter { matchup in
                matchup.week == 19 && 
                (conference == "NFC" ? matchup.homeTeam.conference == "NCFT" : matchup.homeTeam.conference == "ACFT")
            }
            
            if index < wildCardMatchups.count {
                let matchup = wildCardMatchups[index]
                return (homeTeam: matchup.homeTeam, awayTeam: matchup.awayTeam,
                       homeTeamSeed: matchup.homeTeamSeed, awayTeamSeed: matchup.awayTeamSeed)
            }
        }
        
        return nil
    }
    
    // Helper function to get divisional matchups
    private func getDivisionalMatchup(conference: String, index: Int) -> (homeTeam: LeagueTeam, awayTeam: LeagueTeam?, homeTeamSeed: Int, awayTeamSeed: Int?)? {
        let teams = conference == "NFC" ? nfcPlayoffTeams : afcPlayoffTeams
        guard !teams.isEmpty else { return nil }
        
        // For weeks after divisional round (21+), show the completed divisional matchups
        if leagueManager.currentWeek >= 21 {
            let divisionalResults = leagueManager.bracketManager.getResults(for: 20)
            let divisionalMatchups = divisionalResults.filter { result in
                conference == "NFC" ? result.winner.conference == "NCFT" : result.winner.conference == "ACFT"
            }.map { result in
                (winner: result.winner, loser: result.loser, winnerSeed: getOriginalSeed(result.winner, in: teams), loserSeed: getOriginalSeed(result.loser, in: teams))
            }.sorted { $0.winnerSeed < $1.winnerSeed }
            
            if index < divisionalMatchups.count {
                let matchup = divisionalMatchups[index]
                return (homeTeam: matchup.winner, awayTeam: matchup.loser,
                       homeTeamSeed: matchup.winnerSeed, awayTeamSeed: matchup.loserSeed)
            }
        }
        // During divisional round (week 20), show current matchups
        else if leagueManager.currentWeek == 20 {
            let divisionalBracket = leagueManager.bracketManager.getCurrentBracket()
            let divisionalMatchups = divisionalBracket.filter { matchup in
                matchup.week == 20 && 
                (conference == "NFC" ? matchup.homeTeam.conference == "NCFT" : matchup.homeTeam.conference == "ACFT")
            }.sorted { $0.homeTeamSeed < $1.homeTeamSeed }
            
            if index < divisionalMatchups.count {
                let matchup = divisionalMatchups[index]
                return (homeTeam: matchup.homeTeam, awayTeam: matchup.awayTeam,
                       homeTeamSeed: matchup.homeTeamSeed, awayTeamSeed: matchup.awayTeamSeed)
            }
        }
        // Before and during wildcard round, show #1 seed and potential matchups
        else {
            if index == 0 {
                let firstSeedTeam = teams[0]
                
                if leagueManager.currentWeek == 19 {
                    // During wildcard, check if any wildcard games are completed to show potential opponent
                    let wildCardResults = leagueManager.bracketManager.getResults(for: 19)
                    let lowestAdvancing = wildCardResults.filter { result in
                        conference == "NFC" ? result.winner.conference == "NCFT" : result.winner.conference == "ACFT"
                    }.sorted { 
                        getOriginalSeed($0.winner, in: teams) > getOriginalSeed($1.winner, in: teams) 
                    }.first
                    
                    if let opponent = lowestAdvancing {
                        // Show #1 seed vs lowest advancing seed
                        return (homeTeam: firstSeedTeam, awayTeam: opponent.winner,
                               homeTeamSeed: 1, awayTeamSeed: getOriginalSeed(opponent.winner, in: teams))
                    }
                }
                
                // If no games completed or before playoffs, just show #1 seed
                return (homeTeam: firstSeedTeam, awayTeam: nil, homeTeamSeed: 1, awayTeamSeed: nil)
            }
        }
        
        return nil
    }

// Helper function to get original seed of a team
private func getOriginalSeed(_ team: LeagueTeam, in teams: [LeagueTeam]) -> Int {
    // First check if team is #1 seed (they don't play in wildcard)
    if team.logoName == teams[0].logoName {
        return 1
    }
    
    // Check wildcard matchups for original seeding
    let wildCardBracket = leagueManager.bracketManager.getCurrentBracket().filter { $0.week == 19 }
    if let wildCardMatchup = wildCardBracket.first(where: { 
        $0.homeTeam.logoName == team.logoName || $0.awayTeam.logoName == team.logoName 
    }) {
        if wildCardMatchup.homeTeam.logoName == team.logoName {
            return wildCardMatchup.homeTeamSeed
        } else {
            return wildCardMatchup.awayTeamSeed
        }
    }
    
    // If not found in wildcard (shouldn't happen), fallback to position in teams array
    if let index = teams.firstIndex(where: { $0.logoName == team.logoName }) {
        return index + 1
    }
    
    return 0
}
    
    // Helper function to get conference championship matchups
    private func getConferenceChampionship(conference: String) -> (homeTeam: LeagueTeam, awayTeam: LeagueTeam, homeTeamSeed: Int, awayTeamSeed: Int)? {
        let teams = conference == "NFC" ? nfcPlayoffTeams : afcPlayoffTeams
        guard !teams.isEmpty else { return nil }

        // For weeks after conference championships (22+), show the completed conference championship matchups
        if leagueManager.currentWeek >= 22 {
            let conferenceResults = leagueManager.bracketManager.getResults(for: 21)
            let conferenceMatchup = conferenceResults.first { result in
                conference == "NFC" ? result.winner.conference == "NCFT" : result.winner.conference == "ACFT"
            }
            
            if let matchup = conferenceMatchup {
                let winnerSeed = getOriginalSeed(matchup.winner, in: teams)
                let loserSeed = getOriginalSeed(matchup.loser, in: teams)
                // Higher seed (lower number) should be home team
                if winnerSeed < loserSeed {
                    return (homeTeam: matchup.winner, awayTeam: matchup.loser,
                           homeTeamSeed: winnerSeed, awayTeamSeed: loserSeed)
                } else {
                    return (homeTeam: matchup.loser, awayTeam: matchup.winner,
                           homeTeamSeed: loserSeed, awayTeamSeed: winnerSeed)
                }
            }
        }
        // During conference championships (week 21), show current matchups
        else if leagueManager.currentWeek == 21 {
            let currentBracket = leagueManager.bracketManager.getCurrentBracket()
            let conferenceMatchups = currentBracket.filter { matchup in
                matchup.week == 21 && 
                (conference == "NFC" ? matchup.homeTeam.conference == "NCFT" : matchup.homeTeam.conference == "ACFT")
            }
            
            if let matchup = conferenceMatchups.first {
                let homeSeed = getOriginalSeed(matchup.homeTeam, in: teams)
                let awaySeed = getOriginalSeed(matchup.awayTeam, in: teams)
                return (homeTeam: matchup.homeTeam, awayTeam: matchup.awayTeam,
                       homeTeamSeed: homeSeed, awayTeamSeed: awaySeed)
            }
        }
        // During divisional round (week 20), show advancing teams
        else if leagueManager.currentWeek == 20 {
            let divisionalResults = leagueManager.bracketManager.getResults(for: 20)
            let winners = divisionalResults.filter { result in
                conference == "NFC" ? result.winner.conference == "NCFT" : result.winner.conference == "ACFT"
            }.map { result in
                (team: result.winner, seed: getOriginalSeed(result.winner, in: teams))
            }.sorted { $0.seed < $1.seed }
            
            if winners.count >= 2 {
                return (homeTeam: winners[0].team, awayTeam: winners[1].team,
                       homeTeamSeed: winners[0].seed, awayTeamSeed: winners[1].seed)
            }
        }
        
        return nil
    }
    
    // Helper function to get super bowl matchup
    private func getSuperBowlMatchup() -> (homeTeam: LeagueTeam, awayTeam: LeagueTeam, homeTeamSeed: Int, awayTeamSeed: Int)? {
        if leagueManager.currentWeek >= 22 {
            // During Super Bowl, show actual matchup
            let currentBracket = leagueManager.bracketManager.getCurrentBracket()
            let superBowlMatchups = currentBracket.filter { $0.week == 22 }
            
            if let matchup = superBowlMatchups.first {
                return (homeTeam: matchup.homeTeam, awayTeam: matchup.awayTeam,
                       homeTeamSeed: matchup.homeTeamSeed, awayTeamSeed: matchup.awayTeamSeed)
            }
        } else if leagueManager.currentWeek == 21 {
            // During conference championships, check for completed games to show advancing teams
            let championshipResults = leagueManager.bracketManager.getResults(for: 21)
            let nfcWinner = championshipResults.first { result in
                result.winner.conference == "NCFT"
            }
            let afcWinner = championshipResults.first { result in
                result.winner.conference == "ACFT"
            }
            
            if let nfc = nfcWinner?.winner, let afc = afcWinner?.winner {
                return (homeTeam: nfc, awayTeam: afc,
                       homeTeamSeed: getOriginalSeed(nfc, in: nfcPlayoffTeams),
                       awayTeamSeed: getOriginalSeed(afc, in: afcPlayoffTeams))
            }
        }
        
        return nil
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                HStack(alignment: .center, spacing: geometry.size.width * 0.05) {
                    // First Column - Wild Card Round
                    VStack {
                        // NFCT Wild Card Games
                        VStack(spacing: 20) {
                            ForEach(0..<3) { index in
                                PlayoffMatchupRow(
                                    topTeam: getNFCTeamBySeed(index + 2),
                                    bottomTeam: getNFCTeamBySeed(7 - index),
                                    topSeed: index + 2,
                                    bottomSeed: 7 - index,
                                    selectedTeam: selectedTeam
                                )
                            }
                        }
                        
                        Spacer()
                            .frame(height: 30)
                        
                        // Wild Card Logo
                        Image(roundLogos[0])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60)
                        
                        Spacer()
                            .frame(height: 30)
                        
                        // AFCT Wild Card Games
                        VStack(spacing: 20) {
                            ForEach(0..<3) { index in
                                PlayoffMatchupRow(
                                    topTeam: getAFCTeamBySeed(index + 2),
                                    bottomTeam: getAFCTeamBySeed(7 - index),
                                    topSeed: index + 2,
                                    bottomSeed: 7 - index,
                                    selectedTeam: selectedTeam
                                )
                            }
                        }
                    }
                    .frame(width: geometry.size.width * 0.2)
                    
                    // Second Column - Divisional Round
                    VStack {
                        // NFCT Divisional Games
                        VStack(spacing: 20) {
                            // First Divisional Matchup (#1 seed vs lowest remaining)
                            PlayoffMatchupRow(
                                topTeam: getDivisionalMatchup(conference: "NFC", index: 0)?.homeTeam,
                                bottomTeam: getDivisionalMatchup(conference: "NFC", index: 0)?.awayTeam,
                                topSeed: getDivisionalMatchup(conference: "NFC", index: 0)?.homeTeamSeed,
                                bottomSeed: getDivisionalMatchup(conference: "NFC", index: 0)?.awayTeamSeed,
                                selectedTeam: selectedTeam
                            )
                            
                            // Second Divisional Matchup (higher remaining seeds)
                            PlayoffMatchupRow(
                                topTeam: getDivisionalMatchup(conference: "NFC", index: 1)?.homeTeam,
                                bottomTeam: getDivisionalMatchup(conference: "NFC", index: 1)?.awayTeam,
                                topSeed: getDivisionalMatchup(conference: "NFC", index: 1)?.homeTeamSeed,
                                bottomSeed: getDivisionalMatchup(conference: "NFC", index: 1)?.awayTeamSeed,
                                selectedTeam: selectedTeam
                            )
                        }
                        
                        Spacer()
                            .frame(height: 30)
                        
                        // Divisional Logo
                        Image(roundLogos[1])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60)
                        
                        Spacer()
                            .frame(height: 30)
                        
                        // AFCT Divisional Games
                        VStack(spacing: 20) {
                            // First Divisional Matchup (#1 seed vs lowest remaining)
                            PlayoffMatchupRow(
                                topTeam: getDivisionalMatchup(conference: "AFC", index: 0)?.homeTeam,
                                bottomTeam: getDivisionalMatchup(conference: "AFC", index: 0)?.awayTeam,
                                topSeed: getDivisionalMatchup(conference: "AFC", index: 0)?.homeTeamSeed,
                                bottomSeed: getDivisionalMatchup(conference: "AFC", index: 0)?.awayTeamSeed,
                                selectedTeam: selectedTeam
                            )
                            
                            // Second Divisional Matchup (higher remaining seeds)
                            PlayoffMatchupRow(
                                topTeam: getDivisionalMatchup(conference: "AFC", index: 1)?.homeTeam,
                                bottomTeam: getDivisionalMatchup(conference: "AFC", index: 1)?.awayTeam,
                                topSeed: getDivisionalMatchup(conference: "AFC", index: 1)?.homeTeamSeed,
                                bottomSeed: getDivisionalMatchup(conference: "AFC", index: 1)?.awayTeamSeed,
                                selectedTeam: selectedTeam
                            )
                        }
                    }
                    .frame(width: geometry.size.width * 0.2)
                    
                    // Third Column - Conference Championships
                    VStack {
                        // NFCT Championship Game Container
                        PlayoffMatchupRow(
                            topTeam: getConferenceChampionship(conference: "NFC")?.homeTeam,
                            bottomTeam: getConferenceChampionship(conference: "NFC")?.awayTeam,
                            topSeed: getConferenceChampionship(conference: "NFC")?.homeTeamSeed,
                            bottomSeed: getConferenceChampionship(conference: "NFC")?.awayTeamSeed,
                            selectedTeam: selectedTeam
                        )
                        
                        Spacer()
                            .frame(height: 30)
                        
                        // NCFT Championship Logo
                        Image(roundLogos[2])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60)
                        
                        Spacer()
                            .frame(height: 60)
                        
                        // ACFT Championship Logo
                        Image("conferencechampionship2_logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60)
                        
                        Spacer()
                            .frame(height: 30)
                        
                        // AFCT Championship Game Container
                        PlayoffMatchupRow(
                            topTeam: getConferenceChampionship(conference: "AFC")?.homeTeam,
                            bottomTeam: getConferenceChampionship(conference: "AFC")?.awayTeam,
                            topSeed: getConferenceChampionship(conference: "AFC")?.homeTeamSeed,
                            bottomSeed: getConferenceChampionship(conference: "AFC")?.awayTeamSeed,
                            selectedTeam: selectedTeam
                        )
                    }
                    .frame(width: geometry.size.width * 0.2)
                    
                    // Fourth Column - League Championship
                    VStack {
                        // Top Container (NCFT Winner)
                        SingleTeamRow(
                            team: getSuperBowlMatchup()?.homeTeam,
                            seed: getSuperBowlMatchup()?.homeTeamSeed,
                            selectedTeam: selectedTeam
                        )
                        
                        Spacer()
                            .frame(height: 30)
                        
                        // League Championship Logo
                        Image(roundLogos[3])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60)
                        
                        Spacer()
                            .frame(height: 30)
                        
                        // Bottom Container (ACFT Winner)
                        SingleTeamRow(
                            team: getSuperBowlMatchup()?.awayTeam,
                            seed: getSuperBowlMatchup()?.awayTeamSeed,
                            selectedTeam: selectedTeam
                        )
                    }
                    .frame(width: geometry.size.width * 0.2)
                }
                .padding()
                
                Spacer()
            }
        }
    }
    
    // Update the team getters in the view to use the new functions
    private func getNFCTeamBySeed(_ seed: Int) -> LeagueTeam? {
        getTeamBySeed(conference: "NFC", seed: seed)
    }
    
    private func getAFCTeamBySeed(_ seed: Int) -> LeagueTeam? {
        getTeamBySeed(conference: "AFC", seed: seed)
    }
}

// MARK: - Playoff Matchup Row
struct PlayoffMatchupRow: View {
    let topTeam: LeagueTeam?
    let bottomTeam: LeagueTeam?
    let topSeed: Int?
    let bottomSeed: Int?
    let selectedTeam: TeamData
    
    private func isUserTeam(_ team: LeagueTeam?) -> Bool {
        guard let team = team else { return false }
        return team.logoName == selectedTeam.logoName
    }
    
    var body: some View {
        VStack(spacing: 1) {
            // Top Team
            HStack(spacing: 12) {
                if let team = topTeam {
                    HStack(spacing: 8) {
                        // Seed number
                        if let seed = topSeed {
                            Text("#\(seed)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color(hex: TeamColorMapping.getColors(for: team.logoName).primary))
                                )
                        }
                        
                        Image(team.logoName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(hex: TeamColorMapping.getColors(for: team.logoName).primary).opacity(0.2),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                } else {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 24, height: 24)
                        
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 32, height: 32)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Bottom Team
            HStack(spacing: 12) {
                if let team = bottomTeam {
                    HStack(spacing: 8) {
                        // Seed number
                        if let seed = bottomSeed {
                            Text("#\(seed)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color(hex: TeamColorMapping.getColors(for: team.logoName).primary))
                                )
                        }
                        
                        Image(team.logoName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(hex: TeamColorMapping.getColors(for: team.logoName).primary).opacity(0.2),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                } else {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 24, height: 24)
                        
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 32, height: 32)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Conference Champion Row
struct ConferenceChampionRow: View {
    let team: LeagueTeam?
    let isUserTeam: Bool
    let selectedTeam: TeamData
    
    var body: some View {
        HStack(spacing: 12) {
            if let team = team {
                HStack(spacing: 8) {
                    Image(team.logoName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hex: TeamColorMapping.getColors(for: team.logoName).primary).opacity(0.2),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            } else {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 32, height: 32)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

// Add this new view for single team display
struct SingleTeamRow: View {
    let team: LeagueTeam?
    let seed: Int?
    let selectedTeam: TeamData
    
    private func isUserTeam(_ team: LeagueTeam?) -> Bool {
        guard let team = team else { return false }
        return team.logoName == selectedTeam.logoName
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let team = team {
                HStack(spacing: 8) {
                    // Seed number
                    if let seed = seed {
                        Text("#\(seed)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color(hex: TeamColorMapping.getColors(for: team.logoName).primary))
                            )
                    }
                    
                    Image(team.logoName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hex: TeamColorMapping.getColors(for: team.logoName).primary).opacity(0.2),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            } else {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 32, height: 32)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    PlayoffBracketView(
        leagueManager: LeagueManager(),
        selectedTeam: TeamData.createTeamFromData(name: "Chicago")
    )
}
                                
                                