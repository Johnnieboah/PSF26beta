import SwiftUI

// MARK: - LeagueHub Team Logos View
struct LeagueHubTeamLogosView: View {
    let currentLeague: ObservableLeague
    let leagueManager: LeagueManager
    let opponentName: String
    let opponentLogoName: String
    let userGameCompleted: Bool
    let userGameScore: (userScore: Int, opponentScore: Int)
    let currentWeek: Int
    let isSimulating: Bool
    // Optional transient result overlay to show final scores briefly after sim
    let resultOverlay: (userLogo: String, oppLogo: String, userScore: Int, oppScore: Int, isBye: Bool)?
    
    private var shouldShowSingleTeamLogo: Bool {
        // Show single team logo for:
        // 1. Regular season bye weeks
        // 2. TBD opponents
        // 3. Preseason (week 0)
        // 4. Empty opponent name
        // 5. Playoff byes (First Round Bye)
        // 6. Season complete
        // 7. Eliminated - watching playoffs
        // While simulating a valid matchup, force the two-logo view so the user always
        // sees both teams during sim regardless of which sim action was used.
        if isSimulating {
            // Still fallback to single only if we have no opponent identity
            return opponentLogoName.isEmpty || opponentName.isEmpty
        }
        return opponentName == "BYE" ||
               opponentName == "TBD" ||
               currentWeek == 0 ||
               opponentName.isEmpty ||
               opponentLogoName.isEmpty ||
               opponentName == "First Round Bye" ||
               opponentName == "Season Complete" ||
               opponentName == "Eliminated - Watching Playoffs"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if shouldShowSingleTeamLogo {
                // Bye Week or Pre-season - Show only user team centered
                VStack(spacing: 16) {
                    // User Team Logo
                    TeamLogoView(
                        teamLogoName: currentLeague.teamLogoName,
                        customLogoData: currentLeague.customLogoData,
                        size: opponentName == "Eliminated - Watching Playoffs" ? 60 : 180
                    )
                    
                    // Team Name and Record
                    VStack(spacing: 8) {
                        Text(TeamData.getTeamCityName(currentLeague.teamLogoName))
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        let record = leagueManager.getTeamRecord(for: currentLeague.teamLogoName)
                        Text("\(record.wins)-\(record.losses)")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Game Week - Show both teams
                VStack(spacing: 16) {
                    HStack(spacing: 40) {
                        // User Team Logo and Info
                        VStack(spacing: 8) {
                            TeamLogoView(
                                teamLogoName: currentLeague.teamLogoName,
                                customLogoData: currentLeague.customLogoData,
                                size: 140
                            )
                            
                            Text(TeamData.getTeamCityName(currentLeague.teamLogoName))
                                .font(.headline)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            let record = leagueManager.getTeamRecord(for: currentLeague.teamLogoName)
                            Text("\(record.wins)-\(record.losses)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if let overlay = resultOverlay, !overlay.isBye {
                                Text("\(overlay.userScore)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(overlay.userScore > overlay.oppScore ? .green : overlay.userScore == overlay.oppScore ? .orange : .red)
                            } else if userGameCompleted {
                                Text("\(userGameScore.userScore)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(userGameScore.userScore > userGameScore.opponentScore ? .green :
                                                   userGameScore.userScore == userGameScore.opponentScore ? .orange : .red)
                            } else if isSimulating {
                                // Show live/brief scores during simulation
                                Text("\(userGameScore.userScore)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(userGameScore.userScore > userGameScore.opponentScore ? .green :
                                                   userGameScore.userScore == userGameScore.opponentScore ? .orange : .red)
                            }
                        }
                        
                        // VS Text
                        VStack(spacing: 8) {
                            if userGameCompleted {
                                Text("FINAL")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("VS")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Week Indicator
                            Text("WEEK \(currentWeek)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.top, 8)
                        }
                        
                        // Opponent Team Logo and Info
                        VStack(spacing: 8) {
                            TeamLogoView(
                                teamLogoName: opponentLogoName,
                                customLogoData: nil,
                                size: 140
                            )
                            
                            Text(TeamData.getTeamCityName(opponentLogoName))
                                .font(.headline)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            let record = leagueManager.getTeamRecord(for: opponentLogoName)
                            Text("\(record.wins)-\(record.losses)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if let overlay = resultOverlay, !overlay.isBye {
                                Text("\(overlay.oppScore)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(overlay.oppScore > overlay.userScore ? .green : overlay.oppScore == overlay.userScore ? .orange : .red)
                            } else if userGameCompleted {
                                Text("\(userGameScore.opponentScore)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(userGameScore.opponentScore > userGameScore.userScore ? .green :
                                                   userGameScore.opponentScore == userGameScore.userScore ? .orange : .red)
                            } else if isSimulating {
                                // Show live/brief scores during simulation
                                Text("\(userGameScore.opponentScore)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(userGameScore.opponentScore > userGameScore.userScore ? .green :
                                                   userGameScore.opponentScore == userGameScore.userScore ? .orange : .red)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Playoff Logo Section
struct LeagueHubPlayoffLogoSection: View {
    let currentWeek: Int
    
    var body: some View {
        VStack(spacing: 12) {
            LeagueHubHelpers.playoffRoundImage(for: currentWeek)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
        }
    }
} 