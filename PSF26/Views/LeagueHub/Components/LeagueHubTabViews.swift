import SwiftUI

// MARK: - League Hub Tab Views

struct LeagueHubTeamTabView: View {
    @ObservedObject var currentLeague: ObservableLeague
    @ObservedObject var leagueManager: LeagueManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Team Header
                VStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                    Text("Team Management")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                }
                .padding(.top, 20)
                
                // Team Content
                VStack(spacing: 16) {
                    SectionHeaderView(
                        title: "Your Team: \(TeamData.getTeamDisplayName(currentLeague.teamLogoName))",
                        subtitle: "Manage your roster, view stats, and make decisions"
                    )
                    
                    // Quick Team Actions
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 280), spacing: 16)
                    ], spacing: 16) {
                        
                        ActionButton(
                            title: "Team Roster",
                            systemImage: "person.2.fill",
                            action: { 
                                NotificationCenter.default.post(name: .presentTeamRoster, object: nil)
                            },
                            style: .team(currentLeague.teamLogoName)
                        )
                        
                        ActionButton(
                            title: "Team Stats",
                            systemImage: "chart.bar.fill",
                            action: { 
                                // TODO: Navigate to team stats
                            },
                            style: .team(currentLeague.teamLogoName)
                        )
                        
                        ActionButton(
                            title: "Schedule",
                            systemImage: "calendar.badge.clock",
                            action: { 
                                // TODO: Navigate to schedule
                            },
                            style: .team(currentLeague.teamLogoName)
                        )
                        
                        ActionButton(
                            title: "Free Agents",
                            systemImage: "person.badge.plus",
                            action: { 
                                // TODO: Navigate to free agents
                            },
                            style: .team(currentLeague.teamLogoName)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity)
                    
                    // Team Record Display
                    if currentLeague.currentWeek > 1 {
                        VStack(spacing: 8) {
                            Text("Current Record")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 16) {
                                VStack {
                                    Text("\(currentLeague.wins)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                    Text("Wins")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    Text("\(currentLeague.losses)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                    Text("Losses")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if currentLeague.ties > 0 {
                                    VStack {
                                        Text("\(currentLeague.ties)")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.orange)
                                        Text("Ties")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .roundedBackground(.ultraThinMaterial, radius: Corner.medium)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .iOS26Enhanced()
    }
}

struct LeagueHubLeagueTabView: View {
    @ObservedObject var currentLeague: ObservableLeague
    @ObservedObject var leagueManager: LeagueManager
    @ObservedObject var stateManager: LeagueHubStateManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // League Header
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                    Text("League Overview")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                }
                .padding(.top, 20)
                
                // League Content
                VStack(spacing: 16) {
                    SectionHeaderView(
                        title: "Week \(currentLeague.currentWeek) - Season \(leagueManager.currentSeasonNumber)",
                        subtitle: "League-wide information and standings"
                    )
                    
                    // Quick League Actions
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 280), spacing: 16)
                    ], spacing: 16) {
                        
                        ActionButton(
                            title: "Standings",
                            systemImage: "list.number",
                            action: { 
                                // TODO: Navigate to standings
                            },
                            style: .league(Color(red: 0.02, green: 0.25, blue: 0.70))
                        )
                        
                        ActionButton(
                            title: "League Stats",
                            systemImage: "chart.line.uptrend.xyaxis",
                            action: { 
                                // TODO: Navigate to league stats
                            },
                            style: .league(Color(red: 0.02, green: 0.25, blue: 0.70))
                        )
                        
                        ActionButton(
                            title: "League Schedule",
                            systemImage: "calendar",
                            action: { 
                                // TODO: Navigate to league schedule
                            },
                            style: .league(Color(red: 0.02, green: 0.25, blue: 0.70))
                        )
                        
                        ActionButton(
                            title: "Playoff Picture",
                            systemImage: "trophy.circle",
                            action: { 
                                // TODO: Navigate to playoff picture
                            },
                            style: .league(Color(red: 0.02, green: 0.25, blue: 0.70))
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity)
                    
                    // (Removed) Current Status card per request
                }
            }
            .padding(.bottom, 20)
        }
        .iOS26Enhanced()
    }
    
    private func getStageLabel() -> String {
        let week = currentLeague.currentWeek
        switch week {
        case 1...17:
            return "Regular Season"
        case 18:
            return "Wild Card Round"
        case 19:
            return "Divisional Round"
        case 20:
            return "Conference Championships"
        case 21:
            return "Super Bowl"
        default:
            return "Offseason"
        }
    }
}

// MARK: - Supporting Views
// SectionHeaderView is already defined in SharedComponents.swift
