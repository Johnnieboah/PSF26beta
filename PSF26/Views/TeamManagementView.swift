import SwiftUI
import Combine

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
        ZStack {
            // Background
            Color(.systemBackground).ignoresSafeArea()
            
            // Native TabView with Liquid Glass
            TabView(selection: $selectedTab) {
                // Roster Tab (with Overview as default)
                NavigationStack {
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
                    .navigationBarHidden(true)
                }
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Roster")
                }
                .tag(ManagementTab.roster)
                
                // Schedule Tab
                NavigationStack {
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
                    .navigationBarHidden(true)
                }
                .tabItem {
                    Image(systemName: "calendar.badge.clock")
                    Text("Schedule")
                }
                .tag(ManagementTab.schedule)
                
                // Settings Tab
                NavigationStack {
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
                    .navigationBarHidden(true)
                }
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(ManagementTab.league)
            }
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
            
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("Teams")
                                .font(.body)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.lift)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 100 && abs(value.translation.height) < 50 {
                        dismiss()
                    }
                }
        )
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
            return realSchedule.map { game in
                GameData(
                    week: game.week,
                    opponent: TeamData.simplifyOpponentName(game.opponent),
                    isHome: game.isHome,
                    date: "Week \(game.week)",
                    time: TeamData.getGameTime(for: game.week)
                )
            }
        } else {
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
                    Text("\(scheduleGames.count) Games")
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
                    GameRowView(
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

// MARK: - Game Row View
struct GameRowView: View {
    let game: GameData
    let teamColor: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack {
                    Text("Week \(game.week)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: teamColor))
                    
                    Spacer()
                    
                    Text(game.date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    HStack(spacing: 8) {
                        Text(game.isHome ? "vs" : "@")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(game.opponent)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text(game.time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if isSelected {
                    VStack(spacing: 8) {
                        Divider()
                        
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
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: teamColor).opacity(isSelected ? 0.5 : 0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
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
    
    init(team: TeamData) {
        self.team = team
        self._leagueSettings = State(initialValue: team.leagueSettings)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: team.primaryColor))
                
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                SettingsGroupView(title: "Season Settings", teamColor: team.primaryColor) {
                    SettingRowView(
                        title: "Season Length",
                        value: "\(leagueSettings.seasonLength) games",
                        teamColor: team.primaryColor
                    ) {
                        print("Show picker")
                    }
                    
                    SettingRowView(
                        title: "Playoff Teams",
                        value: "\(leagueSettings.playoffTeams) teams",
                        teamColor: team.primaryColor
                    ) {
                        print("Show picker")
                    }
                    
                    SettingRowView(
                        title: "Trade Deadline",
                        value: "Week \(leagueSettings.tradeDeadline)",
                        teamColor: team.primaryColor
                    ) {
                        print("Show picker")
                    }
                }
                
                SettingsGroupView(title: "Gameplay Settings", teamColor: team.primaryColor) {
                    ToggleSettingRowView(
                        title: "Injuries",
                        description: "Players can get injured during games",
                        isOn: Binding(
                            get: { leagueSettings.injuriesEnabled },
                            set: { leagueSettings.injuriesEnabled = $0 }
                        ),
                        teamColor: team.primaryColor
                    )
                    
                    ToggleSettingRowView(
                        title: "Salary Cap",
                        description: "Teams must manage salary cap limits",
                        isOn: Binding(
                            get: { leagueSettings.salaryCapEnabled },
                            set: { leagueSettings.salaryCapEnabled = $0 }
                        ),
                        teamColor: team.primaryColor
                    )
                }
            }
        }
    }
}

// MARK: - Settings Group View
struct SettingsGroupView<Content: View>: View {
    let title: String
    let teamColor: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                content
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: teamColor).opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Setting Row View
struct SettingRowView: View {
    let title: String
    let value: String
    let teamColor: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: teamColor))
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toggle Setting Row View
struct ToggleSettingRowView: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let teamColor: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(Color(hex: teamColor))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
        .sensoryFeedback(.selection, trigger: isOn)
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
            let lightness = 0.7 - (normalizedRating * 0.4) // 0.7 to 0.3
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
