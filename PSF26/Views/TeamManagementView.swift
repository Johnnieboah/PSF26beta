import SwiftUI
import Combine
import PhotosUI

struct TeamManagementView: View {
    let teamName: String
    let conference: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ManagementTab = .roster
    @State private var team: TeamData
    @Namespace private var tabNamespace
    @Namespace private var glassNamespace
    
    enum ManagementTab: String, CaseIterable {
        case roster = "Roster"
        case schedule = "Schedule"
        case league = "Settings"
        
        var icon: String {
            switch self {
            case .roster: return "person.3.fill"
            case .schedule: return "calendar.badge.clock"
            case .league: return "gearshape.fill"
            }
        }
    }
    
    init(teamName: String, conference: String) {
        self.teamName = teamName
        self.conference = conference
        self._team = State(initialValue: TeamData.createTeamFromData(name: teamName))
    }
    
    var body: some View {
        // Native TabView with Liquid Glass and iOS 26 Full-Screen Swipe Back
        TabView(selection: $selectedTab) {
            // Roster Tab (with Overview as default)
            ScrollView {
                VStack(spacing: 0) {
                    SimplifiedTeamHeaderView(team: team)
                    
                    VStack(spacing: 20) {
                        RosterManagementView(team: $team)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
            }
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollBounceBehavior(.basedOnSize)
            .tabItem {
                Image(systemName: "person.3.fill")
                Text("Roster")
            }
            .tag(ManagementTab.roster)
            
            // Schedule Tab
            ScrollView {
                VStack(spacing: 0) {
                    SimplifiedTeamHeaderView(team: team)
                    
                    VStack(spacing: 20) {
                        SeasonScheduleView(team: team)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
            }
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollBounceBehavior(.basedOnSize)
            .tabItem {
                Image(systemName: "calendar.badge.clock")
                Text("Schedule")
            }
            .tag(ManagementTab.schedule)
            
            // Settings Tab
            ScrollView {
                VStack(spacing: 0) {
                    SimplifiedTeamHeaderView(team: team)
                    
                    VStack(spacing: 20) {
                        LeagueSetupView(team: team)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
            }
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollBounceBehavior(.basedOnSize)
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Settings")
            }
            .tag(ManagementTab.league)
        }
        .navigationTitle(TeamData.getTeamDisplayName(teamName))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            // Configure native iOS 26 Liquid Glass tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor.clear
            
            // Apply Liquid Glass effect
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().isTranslucent = true
        }
    }
}

// MARK: - Simplified Team Header View
struct SimplifiedTeamHeaderView: View {
    let team: TeamData
    
    var body: some View {
        headerContent
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.top, 10)
            .background(
                teamGradientBackground
                    .ignoresSafeArea(.all)
            )
    }
    
    private var headerContent: some View {
        HStack {
            Spacer()
            
            Image(team.logoName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    private var teamGradientBackground: some View {
        GeometryReader { geometry in
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: team.primaryColor), location: 0.0),
                    .init(color: Color(hex: team.secondaryColor), location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: geometry.size.width + 100)
            .offset(x: -50)
        }
    }
}

// MARK: - Team Data Model
struct TeamData {
    let name: String
    let logoName: String
    let primaryColor: String
    let secondaryColor: String
    var players: [PlayerData]
    var schedule: [GameData]
    var leagueSettings: LeagueSettings
    
    static func createTeamFromData(name: String) -> TeamData {
        let colors = TeamColorMapping.getColors(for: name)
        let masterLoader = MasterDataLoader.shared
        
        return TeamData(
            name: getTeamDisplayName(name),
            logoName: name,
            primaryColor: colors.primary,
            secondaryColor: colors.secondary,
            players: loadRosterFromMasterData(teamName: name, masterLoader: masterLoader),
            schedule: loadScheduleFromMasterData(teamName: name, masterLoader: masterLoader),
            leagueSettings: LeagueSettings.defaultSettings()
        )
    }
    
    static func loadRosterFromMasterData(teamName: String, masterLoader: MasterDataLoader) -> [PlayerData] {
        // Always try to load from master data first
        let realPlayers = masterLoader.getPlayers(for: teamName)
        
        if !realPlayers.isEmpty {
            return realPlayers.map { player in
                PlayerData(
                    firstName: player.firstName,
                    lastName: player.lastName,
                    position: player.position,
                    number: Int(player.jerseyNum) ?? 1,
                    overall: player.overallInt,
                    age: player.ageInt
                )
            }
        } else {
            // Fallback to sample data only if no real data is available
            print("⚠️ No real data found for \(teamName), using sample data")
            return generateSamplePlayers()
        }
    }
    
    static func loadScheduleFromMasterData(teamName: String, masterLoader: MasterDataLoader) -> [GameData] {
        // Always try to load from master data first
        let realSchedule = masterLoader.getSchedule(for: teamName)
        
        if !realSchedule.isEmpty {
            return realSchedule.map { game in
                GameData(
                    week: game.week,
                    opponent: simplifyOpponentName(game.opponent),
                    isHome: game.isHome,
                    date: "Week \(game.week)",
                    time: TeamData.getGameTime(for: game.week)
                )
            }
        } else {
            // Fallback to sample data only if no real data is available
            print("⚠️ No real schedule found for \(teamName), using sample data")
            return generateSampleSchedule()
        }
    }
    
    static func simplifyOpponentName(_ fullOpponentName: String) -> String {
        // Convert full team names to short display names
        let teamNameMapping: [String: String] = [
            "Kansas City Chiefs": "Chiefs",
            "San Francisco 49ers": "49ers",
            "Miami Dolphins": "Dolphins",
            "Dallas Cowboys": "Cowboys",
            "Chicago Bears": "Bears",
            "Detroit Lions": "Lions",
            "Green Bay Packers": "Packers",
            "Minnesota Vikings": "Vikings",
            "New York Giants": "Giants",
            "Philadelphia Eagles": "Eagles",
            "Washington Commanders": "Commanders",
            "Atlanta Falcons": "Falcons",
            "Carolina Panthers": "Panthers",
            "New Orleans Saints": "Saints",
            "Tampa Bay Buccaneers": "Buccaneers",
            "Arizona Cardinals": "Cardinals",
            "Los Angeles Rams": "Rams",
            "Seattle Seahawks": "Seahawks",
            "Baltimore Ravens": "Ravens",
            "Cincinnati Bengals": "Bengals",
            "Cleveland Browns": "Browns",
            "Pittsburgh Steelers": "Steelers",
            "Buffalo Bills": "Bills",
            "New England Patriots": "Patriots",
            "New York Jets": "Jets",
            "Houston Texans": "Texans",
            "Indianapolis Colts": "Colts",
            "Jacksonville Jaguars": "Jaguars",
            "Tennessee Titans": "Titans",
            "Denver Broncos": "Broncos",
            "Las Vegas Raiders": "Raiders",
            "Los Angeles Chargers": "Chargers"
        ]
        
        return teamNameMapping[fullOpponentName] ?? fullOpponentName
    }
    
    static func getGameTime(for week: Int) -> String {
        let gameTimes = [
            "1:00 PM", "1:00 PM", "4:05 PM", "4:25 PM",
            "8:15 PM", "8:20 PM", "7:00 PM"
        ]
        
        // Different time slots for different weeks to make it realistic
        switch week {
        case 1...4:
            return ["1:00 PM", "4:05 PM", "8:15 PM"].randomElement() ?? "1:00 PM"
        case 5...8:
            return ["1:00 PM", "4:25 PM", "8:20 PM"].randomElement() ?? "1:00 PM"
        case 9...13:
            return ["1:00 PM", "4:05 PM", "7:00 PM"].randomElement() ?? "1:00 PM"
        case 14...17:
            return ["1:00 PM", "4:25 PM", "8:15 PM"].randomElement() ?? "1:00 PM"
        default:
            return "1:00 PM"
        }
    }
    
    static func getTeamDisplayName(_ teamName: String) -> String {
        switch teamName {
        case "Chicago": return "Chicago Bears"
        case "Detroit": return "Detroit Lions"
        case "GreenBay": return "Green Bay Packers"
        case "Minnesota": return "Minnesota Vikings"
        case "Dallas": return "Dallas Cowboys"
        case "NYN": return "New York Giants"
        case "Philadelphia": return "Philadelphia Eagles"
        case "Washington": return "Washington Commanders"
        case "Atlanta": return "Atlanta Falcons"
        case "Carolina": return "Carolina Panthers"
        case "NewOrleans": return "New Orleans Saints"
        case "TampaBay": return "Tampa Bay Buccaneers"
        case "Arizona": return "Arizona Cardinals"
        case "LAN": return "Los Angeles Rams"
        case "SanFrancisco": return "San Francisco 49ers"
        case "Seattle": return "Seattle Seahawks"
        case "Baltimore": return "Baltimore Ravens"
        case "Cincinnati": return "Cincinnati Bengals"
        case "Cleveland": return "Cleveland Browns"
        case "Pittsburgh": return "Pittsburgh Steelers"
        case "Buffalo": return "Buffalo Bills"
        case "Miami": return "Miami Dolphins"
        case "NewEngland": return "New England Patriots"
        case "NYA": return "New York Jets"
        case "Houston": return "Houston Texans"
        case "Indianapolis": return "Indianapolis Colts"
        case "Jacksonville": return "Jacksonville Jaguars"
        case "Tennessee": return "Tennessee Titans"
        case "Denver": return "Denver Broncos"
        case "KansasCity": return "Kansas City Chiefs"
        case "LasVegas": return "Las Vegas Raiders"
        case "LAA": return "Los Angeles Chargers"
        default: return teamName
        }
    }
}

// MARK: - Player Data Model
struct PlayerData: Identifiable {
    let id = UUID()
    let firstName: String
    let lastName: String
    let position: String
    let number: Int
    let overall: Int
    let age: Int
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

// MARK: - Game Data Model
struct GameData: Identifiable {
    let id = UUID()
    let week: Int
    let opponent: String
    let isHome: Bool
    let date: String
    let time: String
}

// MARK: - League Settings Model
struct LeagueSettings {
    var seasonLength: Int
    var playoffTeams: Int
    var injuriesEnabled: Bool
    var tradeDeadline: Int
    var salaryCapEnabled: Bool
    
    static func defaultSettings() -> LeagueSettings {
        return LeagueSettings(
            seasonLength: 17,
            playoffTeams: 14,
            injuriesEnabled: true,
            tradeDeadline: 10,
            salaryCapEnabled: true
        )
    }
}

// MARK: - 1. Roster Management View (Updated)
struct RosterManagementView: View {
    @Binding var team: TeamData
    @State private var selectedPosition: String = "Overview"
    @StateObject private var masterDataLoader = MasterDataLoader.shared
    
    private var positions: [String] {
        let basePositions = ["Overview"]
        let madddenPositionOrder = ["QB", "RB", "FB", "WR", "TE", "LT", "LG", "C", "RG", "RT", "MLB", "ROLB", "LOLB", "EDGE", "DE", "DT", "CB", "SS", "FS", "K", "P"]
        
        let realPlayers = masterDataLoader.getPlayers(for: team.logoName)
        
        if !realPlayers.isEmpty {
            let realPositions = Set(realPlayers.map { $0.position })
            let orderedPositions = madddenPositionOrder.filter { realPositions.contains($0) }
            return basePositions + orderedPositions
        } else {
            return basePositions + madddenPositionOrder
        }
    }
    
    private var filteredPlayers: [PlayerData] {
        let realPlayers = masterDataLoader.getPlayers(for: team.logoName)
        
        let playersToUse: [PlayerData]
        if !realPlayers.isEmpty {
            playersToUse = realPlayers.map { player in
                PlayerData(
                    firstName: player.firstName,
                    lastName: player.lastName,
                    position: player.position,
                    number: Int(player.jerseyNum) ?? 1,
                    overall: player.overallInt,
                    age: player.ageInt
                )
            }
        } else {
            playersToUse = team.players
        }
        
        if selectedPosition == "Overview" {
            return [] // Return empty for overview - we'll show the overview cards instead
        } else {
            return playersToUse.filter { $0.position == selectedPosition }.sorted { $0.overall > $1.overall }
        }
    }
    
    var body: some View {
        rosterContent
    }
    
    private var rosterContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            rosterHeader
            positionFilter
            
            if selectedPosition == "Overview" {
                teamOverviewContent
            } else {
                playerList
            }
        }
    }
    
    private var rosterHeader: some View {
        HStack {
            Image(systemName: selectedPosition == "Overview" ? "chart.bar.fill" : "person.3.fill")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text(selectedPosition == "Overview" ? "Team Overview" : "Team Roster")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            if masterDataLoader.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    if selectedPosition == "Overview" {
                        Text("Team Stats")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(filteredPlayers.count) Players")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if masterDataLoader.isDataLoaded {
                        Text("Real Data")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
    
    private var teamOverviewContent: some View {
        let teamPlayers = getTeamPlayers()
        let teamOveralls = calculateTeamOveralls(players: teamPlayers)
        let topPlayers = getTopPlayers(players: teamPlayers)
        
        return VStack(alignment: .leading, spacing: 24) {
            // Team Overalls Section
            TeamOverallsCard(
                teamOveralls: teamOveralls,
                teamColor: team.primaryColor
            )
            
            // Top Players Section
            TopPlayersCard(
                players: topPlayers,
                teamColor: team.primaryColor
            )
            
            // Team Stats Section
            TeamStatsCard(
                playerCount: teamPlayers.count,
                scheduleCount: team.schedule.count,
                teamColor: team.primaryColor
            )
        }
    }
    
    private func getTeamPlayers() -> [PlayerData] {
        let realPlayers = masterDataLoader.getPlayers(for: team.logoName)
        
        if !realPlayers.isEmpty {
            return realPlayers.map { player in
                PlayerData(
                    firstName: player.firstName,
                    lastName: player.lastName,
                    position: player.position,
                    number: Int(player.jerseyNum) ?? 1,
                    overall: player.overallInt,
                    age: player.ageInt
                )
            }
        } else {
            return team.players
        }
    }
    
    private func calculateTeamOveralls(players: [PlayerData]) -> (offense: Int, defense: Int, overall: Int) {
        let offensivePositions = ["QB", "RB", "FB", "WR", "TE", "LT", "LG", "C", "RG", "RT"]
        let defensivePositions = ["MLB", "ROLB", "LOLB", "EDGE", "DE", "DT", "CB", "SS", "FS"]
        
        let offensivePlayers = players.filter { offensivePositions.contains($0.position) }
        let defensivePlayers = players.filter { defensivePositions.contains($0.position) }
        
        let offenseOverall = offensivePlayers.isEmpty ? 0 : offensivePlayers.map { $0.overall }.reduce(0, +) / offensivePlayers.count
        let defenseOverall = defensivePlayers.isEmpty ? 0 : defensivePlayers.map { $0.overall }.reduce(0, +) / defensivePlayers.count
        let teamOverall = players.isEmpty ? 0 : players.map { $0.overall }.reduce(0, +) / players.count
        
        return (offenseOverall, defenseOverall, teamOverall)
    }
    
    private func getTopPlayers(players: [PlayerData]) -> [PlayerData] {
        return Array(players.sorted { $0.overall > $1.overall }.prefix(5))
    }
    
    private var positionFilter: some View {
        filterScrollView
            .padding(.horizontal, -16)
    }
    
    private var filterScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            filterButtons
                .padding(.horizontal, 16)
        }
    }
    
    private var filterButtons: some View {
        HStack(spacing: 8) {
            ForEach(positions, id: \.self) { position in
                filterButton(for: position)
            }
        }
    }
    
    private func filterButton(for position: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedPosition = position
            }
        }) {
            Text(position)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(selectedPosition == position ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedPosition == position ? .primary : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectedPosition == position)
    }
    
    private var playerList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredPlayers) { player in
                PlayerRowView(player: player, teamColor: "primary")
            }
        }
    }
}

// MARK: - Player Row View
struct PlayerRowView: View {
    let player: PlayerData
    let teamColor: String
    
    var body: some View {
        playerRowContent
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(playerRowBackground)
    }
    
    private var playerRowContent: some View {
        HStack(spacing: 16) {
            jerseyNumber
            playerInfo
            Spacer()
            overallRating
        }
    }
    
    private var jerseyNumber: some View {
        Text("#\(player.number)")
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(.primary)
            )
            .shadow(color: .primary.opacity(0.3), radius: 2, x: 0, y: 1)
    }
    
    private var playerInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(player.fullName)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                Text(player.position)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Age: \(player.age)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var overallRating: some View {
        VStack(spacing: 2) {
            Text("OVR")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(player.overall)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ratingColor(player.overall))
        }
    }
    
    private var playerRowBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.primary.opacity(0.2), lineWidth: 1)
            )
    }
    
    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 0..<70:
            return .red
        case 70..<90:
            // Green gradient from light (70) to dark (89)
            let normalizedRating = Double(rating - 70) / 19.0 // 0.0 to 1.0
            return Color.green.opacity(0.6 + (normalizedRating * 0.4))
        case 90...99:
            // Gold gradient from bright (90) to dark (99)
            let normalizedRating = Double(rating - 90) / 9.0 // 0.0 to 1.0
            let hue = 0.15 // Gold hue
            let saturation = 0.8 + (normalizedRating * 0.2) // 0.8 to 1.0
            let brightness = 1.0 - (normalizedRating * 0.3) // 1.0 to 0.7
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        default:
            return .gray
        }
    }
}

// MARK: - 2. Season Schedule View
struct SeasonScheduleView: View {
    let team: TeamData
    @State private var selectedWeek: Int?
    @StateObject private var masterDataLoader = MasterDataLoader.shared
    
    private var scheduleGames: [GameData] {
        let realSchedule = masterDataLoader.getSchedule(for: team.logoName)
        
        if !realSchedule.isEmpty {
            // Create 18-week schedule including bye weeks (NFL has 18 weeks total, 17 games + 1 bye)
            var allWeeks: [GameData] = []
            let gamesByWeek = Dictionary(grouping: realSchedule) { $0.week }
            
            // NFL season spans weeks 1-18
            for week in 1...18 {
                if let games = gamesByWeek[week], let game = games.first {
                    allWeeks.append(GameData(
                        week: game.week,
                        opponent: TeamData.simplifyOpponentName(game.opponent),
                        isHome: game.isHome,
                        date: "Week \(game.week)",
                        time: TeamData.getGameTime(for: game.week)
                    ))
                } else {
                    // Missing week - this is a bye week
                    allWeeks.append(GameData(
                        week: week,
                        opponent: "BYE",
                        isHome: true,
                        date: "Week \(week)",
                        time: ""
                    ))
                }
            }
            return allWeeks
        } else {
            // Fallback to sample data if no real schedule available
            return team.schedule
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(Color(hex: team.primaryColor))
                
                Text("Season Schedule")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(scheduleGames.filter { $0.opponent != "BYE" }.count) Games")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if masterDataLoader.isDataLoaded && !masterDataLoader.getSchedule(for: team.logoName).isEmpty {
                        Text("Real Schedule")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                }
            }
            
            LazyVStack(spacing: 12) {
                ForEach(scheduleGames) { game in
                    if game.opponent == "BYE" {
                        ByeWeekRowView(
                            week: game.week,
                            teamColor: team.primaryColor,
                            isSelected: selectedWeek == game.week
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedWeek = selectedWeek == game.week ? nil : game.week
                            }
                        }
                    } else {
                        EnhancedGameRowView(
                            game: game,
                            teamColor: team.primaryColor,
                            isSelected: selectedWeek == game.week
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedWeek = selectedWeek == game.week ? nil : game.week
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Game Row View (Updated)
struct EnhancedGameRowView: View {
    let game: GameData
    let teamColor: String
    let isSelected: Bool
    let onTap: () -> Void
    
    private var opponentTeamName: String {
        // Convert opponent display name back to short name for logo/color lookup
        let opponentMapping: [String: String] = [
            "Chiefs": "KansasCity",
            "49ers": "SanFrancisco",
            "Dolphins": "Miami",
            "Cowboys": "Dallas",
            "Bears": "Chicago",
            "Lions": "Detroit",
            "Packers": "GreenBay",
            "Vikings": "Minnesota",
            "Giants": "NYN",
            "Eagles": "Philadelphia",
            "Commanders": "Washington",
            "Falcons": "Atlanta",
            "Panthers": "Carolina",
            "Saints": "NewOrleans",
            "Buccaneers": "TampaBay",
            "Cardinals": "Arizona",
            "Rams": "LAN",
            "Seahawks": "Seattle",
            "Ravens": "Baltimore",
            "Bengals": "Cincinnati",
            "Browns": "Cleveland",
            "Steelers": "Pittsburgh",
            "Bills": "Buffalo",
            "Patriots": "NewEngland",
            "Jets": "NYA",
            "Texans": "Houston",
            "Colts": "Indianapolis",
            "Jaguars": "Jacksonville",
            "Titans": "Tennessee",
            "Broncos": "Denver",
            "Raiders": "LasVegas",
            "Chargers": "LAA"
        ]
        
        return opponentMapping[game.opponent] ?? game.opponent
    }
    
    private var opponentColors: TeamColorMapping.TeamColors {
        return TeamColorMapping.getColors(for: opponentTeamName)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Main game content with opponent logo and gradient - no outer background
                HStack(spacing: 16) {
                    // Week number inside gradient
                    Text("Week \(game.week)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                    
                    Spacer()
                    
                    // Game status and opponent
                    HStack(spacing: 12) {
                        Text(game.isHome ? "vs" : "@")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        
                        // Opponent team logo
                        Image(opponentTeamName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        
                        Text(game.opponent)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    // Opponent team gradient background
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: opponentColors.primary), location: 0.0),
                            .init(color: Color(hex: opponentColors.secondary), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Expanded content when selected
                if isSelected {
                    VStack(spacing: 8) {
                        Divider()
                            .padding(.horizontal, 20)
                        
                        HStack {
                            Button("Simulate") {
                                print("Simulating Week \(game.week)")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: teamColor))
                            )
                            
                            Spacer()
                            
                            Button("View Details") {
                                print("Viewing details for Week \(game.week)")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: teamColor))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Bye Week Row View (Updated)
struct ByeWeekRowView: View {
    let week: Int
    let teamColor: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Bye week content - no outer background, centered
                HStack {
                    Spacer()
                    
                    HStack(spacing: 16) {
                        // Week number inside gradient
                        Text("Week \(week)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                            
                            Text("BYE")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    // Subtle gradient for bye week
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.secondary.opacity(0.6), location: 0.0),
                            .init(color: Color.secondary.opacity(0.4), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Expanded content when selected
                if isSelected {
                    VStack(spacing: 8) {
                        Divider()
                            .padding(.horizontal, 20)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Team gets a week off")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Text("• Players recover from injuries")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("• Extra time to prepare for next game")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - 3. League Setup View
struct LeagueSetupView: View {
    let team: TeamData
    @State private var leagueSettings: LeagueSettings
    @State private var startLeagueButtonIsPressed = false
    
    // Team Customization Settings
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var teamLogo: UIImage?
    @State private var showingImageError = false
    @State private var imageErrorMessage = ""
    @State private var primaryColor: Color = .blue
    @State private var secondaryColor: Color = .red
    @State private var thirdColor: Color = .white
    
    // Gameplay Settings
    @State private var difficulty: String = "Pro"
    @State private var autoSave: Bool = true
    @State private var acceleratedClock: Bool = false
    @State private var gameSpeed: String = "Normal"
    @State private var autoSetDepthChart: Bool = true
    @State private var autoFillTeam: Bool = false
    
    // Gameplay Settings Enums
    enum GameDifficulty: String, CaseIterable {
        case rookie = "Rookie"
        case semiPro = "Semi-Pro"
        case pro = "Pro"
        case hallOfFame = "Hall of Fame"
        
        var description: String {
            switch self {
            case .rookie: return "Easy gameplay, forgiving AI"
            case .semiPro: return "Moderate difficulty"
            case .pro: return "Challenging gameplay"
            case .hallOfFame: return "Maximum difficulty, legendary"
            }
        }
        
        var toGlobalDifficulty: PSF26.GameDifficulty {
            switch self {
            case .rookie: return .rookie
            case .semiPro: return .semiPro
            case .pro: return .pro
            case .hallOfFame: return .hallOfFame
            }
        }
    }
    
    enum GameSpeed: String, CaseIterable {
        case slow = "Slow"
        case normal = "Normal"
        case fast = "Fast"
        
        var description: String {
            switch self {
            case .slow: return "Detailed animations"
            case .normal: return "Standard pace"
            case .fast: return "Quick simulations"
            }
        }
        
        var toGlobalSpeed: PSF26.GameSpeed {
            switch self {
            case .slow: return .slow
            case .normal: return .normal
            case .fast: return .fast
            }
        }
    }
    
    init(team: TeamData) {
        self.team = team
        self._leagueSettings = State(initialValue: team.leagueSettings)
        
        // Initialize team colors based on current team
        let teamColors = TeamColorMapping.getColors(for: team.logoName)
        self._primaryColor = State(initialValue: Color(hex: teamColors.primary))
        self._secondaryColor = State(initialValue: Color(hex: teamColors.secondary))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: team.primaryColor))
                
                Text("Team Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Team Customization Section
            teamCustomizationSection
            
            // Gameplay Settings Section
            gameplaySettingsSection
            
            // League Rules Section
            leagueRulesSection
            
            // Start League Button
            startLeagueButton
            
        }
        .alert("Image Error", isPresented: $showingImageError) {
            Button("OK") { }
        } message: {
            Text(imageErrorMessage)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadSelectedImage(from: newItem)
            }
        }
    }
    
    // MARK: - Team Customization Section
    private var teamCustomizationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "Team Customization",
                icon: "paintbrush.fill",
                color: Color(hex: team.primaryColor)
            )
            
            VStack(spacing: 16) {
                // Team Logo Upload
                teamLogoSection
                
                // Team Colors
                teamColorsSection
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: team.primaryColor).opacity(0.3), lineWidth: 1.5)
            )
        }
    }
    
    private var teamLogoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Team Logo")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                // Current Logo Display
                Group {
                    if let teamLogo = teamLogo {
                        Image(uiImage: teamLogo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(team.logoName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .frame(width: 80, height: 80)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.secondary.opacity(0.3), lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Label("Choose Image", systemImage: "photo.on.rectangle")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(hex: team.primaryColor), in: RoundedRectangle(cornerRadius: 8))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("• Max size: 512x512 pixels")
                        Text("• PNG format only")
                        Text("• Square aspect ratio recommended")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    private var teamColorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Team Colors")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                colorPickerRow(
                    title: "Primary Color",
                    description: "Main team color for uniforms and UI",
                    color: $primaryColor
                )
                
                colorPickerRow(
                    title: "Secondary Color",
                    description: "Accent color for details and highlights",
                    color: $secondaryColor
                )
                
                colorPickerRow(
                    title: "Third Color",
                    description: "Additional color for trim and text",
                    color: $thirdColor
                )
            }
            
            // Color Preview
            HStack(spacing: 12) {
                Text("Preview:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(primaryColor)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .fill(secondaryColor)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .fill(thirdColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Spacer()
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Gameplay Settings Section
    private var gameplaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "Gameplay Settings",
                icon: "gamecontroller.fill",
                color: .green
            )
            
            VStack(spacing: 16) {
                pickerSetting(
                    title: "Difficulty",
                    description: "Gameplay difficulty level",
                    selection: $difficulty,
                    options: GameDifficulty.allCases.map { $0.rawValue },
                    icon: "flame.fill"
                )
                
                toggleSetting(
                    title: "Auto Save",
                    description: "Automatically save progress after each game",
                    isOn: $autoSave,
                    icon: "externaldrive.fill"
                )
                
                toggleSetting(
                    title: "Auto Set Depth Chart",
                    description: "Automatically organize players by overall rating",
                    isOn: $autoSetDepthChart,
                    icon: "chart.bar.fill"
                )
                
                toggleSetting(
                    title: "Auto Fill Team",
                    description: "Automatically fill empty roster spots with free agents",
                    isOn: $autoFillTeam,
                    icon: "person.3.sequence.fill"
                )
                
                pickerSetting(
                    title: "Game Speed",
                    description: "Game speed and simulation settings",
                    selection: $gameSpeed,
                    options: GameSpeed.allCases.map { $0.rawValue },
                    icon: "clock.fill"
                )
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.green.opacity(0.3), lineWidth: 1.5)
            )
        }
    }
    
    // MARK: - League Rules Section
    private var leagueRulesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "League Rules",
                icon: "scroll.fill",
                color: .orange
            )
            
            VStack(spacing: 16) {
                toggleSetting(
                    title: "Player Injuries",
                    description: "Players can get injured during games",
                    isOn: Binding(
                        get: { leagueSettings.injuriesEnabled },
                        set: { leagueSettings.injuriesEnabled = $0 }
                    ),
                    icon: "cross.case.fill"
                )
                
                toggleSetting(
                    title: "Salary Cap",
                    description: "Teams must manage salary cap limits",
                    isOn: Binding(
                        get: { leagueSettings.salaryCapEnabled },
                        set: { leagueSettings.salaryCapEnabled = $0 }
                    ),
                    icon: "dollarsign.circle.fill"
                )
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.orange.opacity(0.3), lineWidth: 1.5)
            )
        }
    }
    
    // MARK: - Start League Button
    private var startLeagueButton: some View {
        NavigationLink {
            LeagueGameplayView(
                selectedTeam: team,
                settings: LeagueGameplaySettings(
                    difficulty: GameDifficulty(rawValue: difficulty)!.toGlobalDifficulty,
                    autoSave: autoSave,
                    autoSetDepthChart: autoSetDepthChart,
                    autoFillTeam: autoFillTeam,
                    injuriesEnabled: leagueSettings.injuriesEnabled,
                    salaryCapEnabled: leagueSettings.salaryCapEnabled,
                    acceleratedClock: acceleratedClock,
                    gameSpeed: GameSpeed(rawValue: gameSpeed)!.toGlobalSpeed
                )
            )
        } label: {
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Start League with \(TeamData.getTeamDisplayName(team.logoName))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: team.primaryColor), location: 0.0),
                        .init(color: Color(hex: team.secondaryColor), location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .shadow(color: Color(hex: team.primaryColor).opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
    
    // MARK: - Helper Views
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private func colorPickerRow(title: String, description: String, color: Binding<Color>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ColorPicker("", selection: color)
                .frame(width: 40, height: 30)
        }
        .padding(.vertical, 4)
    }
    
    private func toggleSetting(title: String, description: String, isOn: Binding<Bool>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .tint(.blue)
        }
        .padding(.vertical, 4)
    }
    
    private func pickerSetting(title: String, description: String, selection: Binding<String>, options: [String], icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        HStack {
                            Text(option)
                            if selection.wrappedValue == option {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selection.wrappedValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Image Processing
    private func loadSelectedImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    showImageError("Unable to load image data")
                }
                return
            }
            
            guard let image = UIImage(data: data) else {
                await MainActor.run {
                    showImageError("Invalid image format")
                }
                return
            }
            
            // Check if it's a PNG
            guard data.starts(with: [0x89, 0x50, 0x4E, 0x47]) else {
                await MainActor.run {
                    showImageError("Please select a PNG image")
                }
                return
            }
            
            // Check dimensions
            let maxSize: CGFloat = 512
            if image.size.width > maxSize || image.size.height > maxSize {
                await MainActor.run {
                    showImageError("Image must be 512x512 pixels or smaller")
                }
                return
            }
            
            // Process and resize image if needed
            let processedImage = await processImage(image)
            
            await MainActor.run {
                self.teamLogo = processedImage
            }
            
        } catch {
            await MainActor.run {
                showImageError("Error loading image: \(error.localizedDescription)")
            }
        }
    }
    
    private func processImage(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let targetSize = CGSize(width: 512, height: 512)
                
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                let processedImage = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: targetSize))
                }
                
                continuation.resume(returning: processedImage)
            }
        }
    }
    
    private func showImageError(_ message: String) {
        imageErrorMessage = message
        showingImageError = true
        selectedPhotoItem = nil
    }
}

// MARK: - Team Overalls Card
struct TeamOverallsCard: View {
    let teamOveralls: (offense: Int, defense: Int, overall: Int)
    let teamColor: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Team Ratings")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                OverallStatView(
                    title: "Offense",
                    rating: teamOveralls.offense,
                    color: .blue
                )
                
                OverallStatView(
                    title: "Defense",
                    rating: teamOveralls.defense,
                    color: .red
                )
                
                OverallStatView(
                    title: "Overall",
                    rating: teamOveralls.overall,
                    color: Color(hex: teamColor)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: teamColor).opacity(0.3), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Overall Stat View
struct OverallStatView: View {
    let title: String
    let rating: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(rating)")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(ratingColor(rating))
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 0..<70:
            return .red
        case 70..<90:
            // Green gradient from light (70) to dark (89)
            let normalizedRating = Double(rating - 70) / 19.0 // 0.0 to 1.0
            return Color.green.opacity(0.6 + (normalizedRating * 0.4))
        case 90...99:
            // Gold gradient from bright (90) to dark (99)
            let normalizedRating = Double(rating - 90) / 9.0 // 0.0 to 1.0
            let hue = 0.15 // Gold hue
            let saturation = 0.8 + (normalizedRating * 0.2) // 0.8 to 1.0
            let brightness = 1.0 - (normalizedRating * 0.3) // 1.0 to 0.7
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        default:
            return .gray
        }
    }
}

// MARK: - Top Players Card
struct TopPlayersCard: View {
    let players: [PlayerData]
    let teamColor: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                
                Text("Top 5 Players")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    TopPlayerRowView(
                        player: player,
                        rank: index + 1,
                        teamColor: teamColor
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: teamColor).opacity(0.3), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Top Player Row View
struct TopPlayerRowView: View {
    let player: PlayerData
    let rank: Int
    let teamColor: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color(hex: teamColor))
                )
            
            // Player Info
            VStack(alignment: .leading, spacing: 2) {
                Text(player.fullName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text(player.position)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("#\(player.number)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Overall Rating
            Text("\(player.overall)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ratingColor(player.overall))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
        )
    }
    
    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 0..<70:
            return .red
        case 70..<90:
            // Green gradient from light (70) to dark (89)
            let normalizedRating = Double(rating - 70) / 19.0 // 0.0 to 1.0
            return Color.green.opacity(0.6 + (normalizedRating * 0.4))
        case 90...99:
            // Gold gradient from bright (90) to dark (99)
            let normalizedRating = Double(rating - 90) / 9.0 // 0.0 to 1.0
            let hue = 0.15 // Gold hue
            let saturation = 0.8 + (normalizedRating * 0.2) // 0.8 to 1.0
            let brightness = 1.0 - (normalizedRating * 0.3) // 1.0 to 0.7
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        default:
            return .gray
        }
    }
}

// MARK: - Team Stats Card
struct TeamStatsCard: View {
    let playerCount: Int
    let scheduleCount: Int
    let teamColor: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color(hex: teamColor))
                
                Text("Team Info")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text("\(playerCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: teamColor))
                    
                    Text("Players")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(scheduleCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: teamColor))
                    
                    Text("Games")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: teamColor).opacity(0.3), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Sample Data Generation (Temporary until JSON loading is implemented)
extension TeamData {
    static func generateSamplePlayers() -> [PlayerData] {
        let positions = ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "DB", "K"]
        let firstNames = ["John", "Mike", "David", "Chris", "Ryan", "Alex", "Matt", "Josh", "Nick", "Tom", "Jake", "Sam", "Ben", "Luke", "Tyler"]
        let lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson"]
        
        var players: [PlayerData] = []
        var usedNumbers: Set<Int> = []
        
        for _ in 0..<53 {
            var number: Int
            repeat {
                number = Int.random(in: 1...99)
            } while usedNumbers.contains(number)
            usedNumbers.insert(number)
            
            let player = PlayerData(
                firstName: firstNames.randomElement()!,
                lastName: lastNames.randomElement()!,
                position: positions.randomElement()!,
                number: number,
                overall: Int.random(in: 55...95),
                age: Int.random(in: 22...35)
            )
            players.append(player)
        }
        
        return players.sorted { $0.number < $1.number }
    }
    
    static func generateSampleSchedule() -> [GameData] {
        let opponents = [
            "Patriots", "Dolphins", "Bills", "Steelers", "Ravens", "Browns", "Bengals",
            "Colts", "Titans", "Jaguars", "Texans", "Chiefs", "Chargers", "Raiders",
            "Broncos", "Cowboys", "Giants"
        ]
        
        var schedule: [GameData] = []
        
        for week in 1...17 {
            let game = GameData(
                week: week,
                opponent: opponents.randomElement()!,
                isHome: Bool.random(),
                date: "Sep \(week + 7)",
                time: ["1:00 PM", "4:25 PM", "8:20 PM"].randomElement()!
            )
            schedule.append(game)
        }
        
        return schedule
    }
}

#Preview {
    NavigationStack {
        TeamManagementView(teamName: "Chicago", conference: "NFC")
    }
}
