import SwiftUI

struct PlayoffBracketCompactView: View {
    let leagueManager: LeagueManager
    let selectedTeam: TeamData
    let showRoundLogos: Bool
    let teamLogoSize: CGFloat
    
    init(leagueManager: LeagueManager, selectedTeam: TeamData, showRoundLogos: Bool = true, teamLogoSize: CGFloat = 32) {
        self.leagueManager = leagueManager
        self.selectedTeam = selectedTeam
        self.showRoundLogos = showRoundLogos
        self.teamLogoSize = teamLogoSize
    }
    
    private let roundLogos = ["wildcardround", "divisionalround", "conferencechampionship1_logo", "championshiplogo"]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: geometry.size.width * 0.05) {
                // First Column - Wild Card Round
                VStack {
                    // NFCT Wild Card Games
                    VStack(spacing: 20) {
                        ForEach(0..<3) { index in
                            PlayoffMatchupCompactRow(
                                topTeam: getWildCardMatchup(conference: "NFC", index: index)?.homeTeam,
                                bottomTeam: getWildCardMatchup(conference: "NFC", index: index)?.awayTeam,
                                topSeed: getWildCardMatchup(conference: "NFC", index: index)?.homeTeamSeed,
                                bottomSeed: getWildCardMatchup(conference: "NFC", index: index)?.awayTeamSeed,
                                selectedTeam: selectedTeam,
                                teamLogoSize: teamLogoSize
                            )
                        }
                    }
                    
                    if showRoundLogos {
                        Spacer()
                            .frame(height: 30)
                        
                        // Wild Card Logo
                        Image(roundLogos[0])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60)
                        
                        Spacer()
                            .frame(height: 30)
                    }
                    
                    // AFCT Wild Card Games
                    VStack(spacing: 20) {
                        ForEach(0..<3) { index in
                            PlayoffMatchupCompactRow(
                                topTeam: getWildCardMatchup(conference: "AFC", index: index)?.homeTeam,
                                bottomTeam: getWildCardMatchup(conference: "AFC", index: index)?.awayTeam,
                                topSeed: getWildCardMatchup(conference: "AFC", index: index)?.homeTeamSeed,
                                bottomSeed: getWildCardMatchup(conference: "AFC", index: index)?.awayTeamSeed,
                                selectedTeam: selectedTeam,
                                teamLogoSize: teamLogoSize
                            )
                        }
                    }
                }
                .frame(width: geometry.size.width * 0.2)
                
                // Second Column - Divisional Round
                VStack {
                    // NFCT Divisional Games
                    VStack(spacing: 20) {
                        PlayoffMatchupCompactRow(
                            topTeam: getDivisionalMatchup(conference: "NFC", index: 0)?.homeTeam,
                            bottomTeam: getDivisionalMatchup(conference: "NFC", index: 0)?.awayTeam,
                            topSeed: getDivisionalMatchup(conference: "NFC", index: 0)?.homeTeamSeed,
                            bottomSeed: getDivisionalMatchup(conference: "NFC", index: 0)?.awayTeamSeed,
                            selectedTeam: selectedTeam,
                            teamLogoSize: teamLogoSize
                        )
                        
                        PlayoffMatchupCompactRow(
                            topTeam: getDivisionalMatchup(conference: "NFC", index: 1)?.homeTeam,
                            bottomTeam: getDivisionalMatchup(conference: "NFC", index: 1)?.awayTeam,
                            topSeed: getDivisionalMatchup(conference: "NFC", index: 1)?.homeTeamSeed,
                            bottomSeed: getDivisionalMatchup(conference: "NFC", index: 1)?.awayTeamSeed,
                            selectedTeam: selectedTeam,
                            teamLogoSize: teamLogoSize
                        )
                    }
                    
                    if showRoundLogos {
                        Spacer()
                            .frame(height: 30)
                        
                        // Divisional Logo
                        Image(roundLogos[1])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60)
                        
                        Spacer()
                            .frame(height: 30)
                    }
                    
                    // AFCT Divisional Games
                    VStack(spacing: 20) {
                        PlayoffMatchupCompactRow(
                            topTeam: getDivisionalMatchup(conference: "AFC", index: 0)?.homeTeam,
                            bottomTeam: getDivisionalMatchup(conference: "AFC", index: 0)?.awayTeam,
                            topSeed: getDivisionalMatchup(conference: "AFC", index: 0)?.homeTeamSeed,
                            bottomSeed: getDivisionalMatchup(conference: "AFC", index: 0)?.awayTeamSeed,
                            selectedTeam: selectedTeam,
                            teamLogoSize: teamLogoSize
                        )
                        
                        PlayoffMatchupCompactRow(
                            topTeam: getDivisionalMatchup(conference: "AFC", index: 1)?.homeTeam,
                            bottomTeam: getDivisionalMatchup(conference: "AFC", index: 1)?.awayTeam,
                            topSeed: getDivisionalMatchup(conference: "AFC", index: 1)?.homeTeamSeed,
                            bottomSeed: getDivisionalMatchup(conference: "AFC", index: 1)?.awayTeamSeed,
                            selectedTeam: selectedTeam,
                            teamLogoSize: teamLogoSize
                        )
                    }
                }
                .frame(width: geometry.size.width * 0.2)
                
                // Third Column - Conference Championships
                VStack {
                    // NFCT Championship Game Container
                    PlayoffMatchupCompactRow(
                        topTeam: getConferenceChampionship(conference: "NFC")?.homeTeam,
                        bottomTeam: getConferenceChampionship(conference: "NFC")?.awayTeam,
                        topSeed: getConferenceChampionship(conference: "NFC")?.homeTeamSeed,
                        bottomSeed: getConferenceChampionship(conference: "NFC")?.awayTeamSeed,
                        selectedTeam: selectedTeam,
                        teamLogoSize: teamLogoSize
                    )
                    
                    if showRoundLogos {
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
                    }
                    
                    // AFCT Championship Game Container
                    PlayoffMatchupCompactRow(
                        topTeam: getConferenceChampionship(conference: "AFC")?.homeTeam,
                        bottomTeam: getConferenceChampionship(conference: "AFC")?.awayTeam,
                        topSeed: getConferenceChampionship(conference: "AFC")?.homeTeamSeed,
                        bottomSeed: getConferenceChampionship(conference: "AFC")?.awayTeamSeed,
                        selectedTeam: selectedTeam,
                        teamLogoSize: teamLogoSize
                    )
                }
                .frame(width: geometry.size.width * 0.2)
                
                // Fourth Column - League Championship
                VStack {
                    // Top Container (NCFT Winner)
                    SingleTeamCompactRow(
                        team: getSuperBowlMatchup()?.homeTeam,
                        seed: getSuperBowlMatchup()?.homeTeamSeed,
                        selectedTeam: selectedTeam,
                        teamLogoSize: teamLogoSize
                    )
                    
                    if showRoundLogos {
                        Spacer()
                            .frame(height: 30)
                        
                        // League Championship Logo
                        Image(roundLogos[3])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60)
                        
                        Spacer()
                            .frame(height: 30)
                    }
                    
                    // Bottom Container (ACFT Winner)
                    SingleTeamCompactRow(
                        team: getSuperBowlMatchup()?.awayTeam,
                        seed: getSuperBowlMatchup()?.awayTeamSeed,
                        selectedTeam: selectedTeam,
                        teamLogoSize: teamLogoSize
                    )
                }
                .frame(width: geometry.size.width * 0.2)
            }
        }
    }
    
    // Helper functions from PlayoffBracketView...
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
    
    private func getDivisionalMatchup(conference: String, index: Int) -> (homeTeam: LeagueTeam, awayTeam: LeagueTeam?, homeTeamSeed: Int, awayTeamSeed: Int?)? {
        let teams = conference == "NFC" ? nfcPlayoffTeams : afcPlayoffTeams
        guard !teams.isEmpty else { return nil }
        
        // For weeks after divisional round (21+), show the completed divisional matchups
        if leagueManager.currentWeek >= 21 {
            let divisionalResults = leagueManager.bracketManager.getResults(for: 20)
            let divisionalMatchups = divisionalResults.filter { result in
                conference == "NFC" ? result.winner.conference == "NCFT" : result.winner.conference == "ACFT"
            }.map { result in
                (winner: result.winner, loser: result.loser, 
                 winnerSeed: getOriginalSeed(result.winner, in: teams),
                 loserSeed: getOriginalSeed(result.loser, in: teams))
            }.sorted { $0.winnerSeed < $1.winnerSeed }
            
            if index < divisionalMatchups.count {
                let matchup = divisionalMatchups[index]
                // Higher seed (lower number) should be home team
                if matchup.winnerSeed < matchup.loserSeed {
                    return (homeTeam: matchup.winner, awayTeam: matchup.loser,
                           homeTeamSeed: matchup.winnerSeed, awayTeamSeed: matchup.loserSeed)
                } else {
                    return (homeTeam: matchup.loser, awayTeam: matchup.winner,
                           homeTeamSeed: matchup.loserSeed, awayTeamSeed: matchup.winnerSeed)
                }
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
                let homeSeed = getOriginalSeed(matchup.homeTeam, in: teams)
                let awaySeed = getOriginalSeed(matchup.awayTeam, in: teams)
                return (homeTeam: matchup.homeTeam, awayTeam: matchup.awayTeam,
                       homeTeamSeed: homeSeed, awayTeamSeed: awaySeed)
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
    
    private func getSuperBowlMatchup() -> (homeTeam: LeagueTeam, awayTeam: LeagueTeam, homeTeamSeed: Int, awayTeamSeed: Int)? {
        if leagueManager.currentWeek >= 22 {
            let currentBracket = leagueManager.bracketManager.getCurrentBracket()
            let superBowlMatchups = currentBracket.filter { $0.week == 22 }
            
            if let matchup = superBowlMatchups.first {
                let homeSeed = getOriginalSeed(matchup.homeTeam, in: matchup.homeTeam.conference == "NCFT" ? nfcPlayoffTeams : afcPlayoffTeams)
                let awaySeed = getOriginalSeed(matchup.awayTeam, in: matchup.awayTeam.conference == "NCFT" ? nfcPlayoffTeams : afcPlayoffTeams)
                return (homeTeam: matchup.homeTeam, awayTeam: matchup.awayTeam,
                       homeTeamSeed: homeSeed, awayTeamSeed: awaySeed)
            }
        }
        return nil
    }
    
    private var nfcPlayoffTeams: [LeagueTeam] {
        // Get proper playoff teams from league manager
        let allPlayoffTeams = leagueManager.playoffTeams
        return Array(allPlayoffTeams.suffix(7))  // NFC teams are in second half
    }
    
    private var afcPlayoffTeams: [LeagueTeam] {
        // Get proper playoff teams from league manager
        let allPlayoffTeams = leagueManager.playoffTeams
        return Array(allPlayoffTeams.prefix(7))  // AFC teams are in first half
    }
    
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
}

// MARK: - Compact Row Views
struct PlayoffMatchupCompactRow: View {
    let topTeam: LeagueTeam?
    let bottomTeam: LeagueTeam?
    let topSeed: Int?
    let bottomSeed: Int?
    let selectedTeam: TeamData
    let teamLogoSize: CGFloat
    
    private func isUserTeam(_ team: LeagueTeam?) -> Bool {
        guard let team = team else { return false }
        return team.logoName == selectedTeam.logoName
    }
    
    var body: some View {
        VStack(spacing: 2) {  // Increased from 1
            // Top Team
            HStack(spacing: 8) {
                if let team = topTeam {
                    HStack(spacing: 6) {  // Increased from 4
                        // Seed number
                        if let seed = topSeed {
                            Text("\(seed)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(
                                    Circle()
                                        .fill(Color(hex: TeamColorMapping.getColors(for: team.logoName).primary))
                                )
                        }
                        
                        Image(team.logoName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: teamLogoSize, height: teamLogoSize)
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
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 16, height: 16)
                        
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: teamLogoSize, height: teamLogoSize)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Bottom Team
            HStack(spacing: 8) {
                if let team = bottomTeam {
                    HStack(spacing: 4) {
                        // Seed number
                        if let seed = bottomSeed {
                            Text("\(seed)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(
                                    Circle()
                                        .fill(Color(hex: TeamColorMapping.getColors(for: team.logoName).primary))
                                )
                        }
                        
                        Image(team.logoName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: teamLogoSize, height: teamLogoSize)
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
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 16, height: 16)
                        
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: teamLogoSize, height: teamLogoSize)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SingleTeamCompactRow: View {
    let team: LeagueTeam?
    let seed: Int?
    let selectedTeam: TeamData
    let teamLogoSize: CGFloat
    
    private func isUserTeam(_ team: LeagueTeam?) -> Bool {
        guard let team = team else { return false }
        return team.logoName == selectedTeam.logoName
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let team = team {
                HStack(spacing: 4) {
                    // Seed number
                    if let seed = seed {
                        Text("\(seed)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(Color(hex: TeamColorMapping.getColors(for: team.logoName).primary))
                            )
                    }
                    
                    Image(team.logoName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: teamLogoSize, height: teamLogoSize)
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
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 16, height: 16)
                    
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: teamLogoSize, height: teamLogoSize)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
} 