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
                // Roster Tab
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
        }
    }
}

// MARK: - Simplified Team Header View
struct SimplifiedTeamHeaderView: View {
    let team: TeamData
    
    var body: some View {
        headerContent
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .background(teamGradientBackground)
    }
    
    private var headerContent: some View {
        HStack(spacing: 20) {
            // Team Logo
            Image(team.logoName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Team City Name
            VStack(alignment: .leading, spacing: 8) {
                Text(getTeamCityName(team.logoName))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 2)
            }
            
            Spacer()
        }
    }
    
    private var teamGradientBackground: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(hex: team.primaryColor), location: 0.0),
                .init(color: Color(hex: team.secondaryColor), location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func getTeamCityName(_ teamName: String) -> String {
        switch teamName {
        case "Chicago": return "Chicago"
        case "Detroit": return "Detroit"
        case "GreenBay": return "Green Bay"
        case "Minnesota": return "Minnesota"
        case "Dallas": return "Dallas"
        case "NYN": return "New York"
        case "Philadelphia": return "Philadelphia"
        case "Washington": return "Washington"
        case "Atlanta": return "Atlanta"
        case "Carolina": return "Carolina"
        case "NewOrleans": return "New Orleans"
        case "TampaBay": return "Tampa Bay"
        case "Arizona": return "Arizona"
        case "LAN": return "Los Angeles"
        case "SanFrancisco": return "San Francisco"
        case "Seattle": return "Seattle"
        case "Baltimore": return "Baltimore"
        case "Cincinnati": return "Cincinnati"
        case "Cleveland": return "Cleveland"
        case "Pittsburgh": return "Pittsburgh"
        case "Buffalo": return "Buffalo"
        case "Miami": return "Miami"
        case "NewEngland": return "New England"
        case "NYA": return "New York"
        case "Houston": return "Houston"
        case "Indianapolis": return "Indianapolis"
        case "Jacksonville": return "Jacksonville"
        case "Tennessee": return "Tennessee"
        case "Denver": return "Denver"
        case "KansasCity": return "Kansas City"
        case "LasVegas": return "Las Vegas"
        case "LAA": return "Los Angeles"
        default: return teamName
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
        if masterLoader.isDataLoaded {
            let realPlayers = masterLoader.getPlayers(for: teamName)
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
            // Fallback to sample data while loading
            return generateSamplePlayers()
        }
    }
    
    static func loadScheduleFromMasterData(teamName: String, masterLoader: MasterDataLoader) -> [GameData] {
        if masterLoader.isDataLoaded {
            let realSchedule = masterLoader.getSchedule(for: teamName)
            return realSchedule.map { game in
                GameData(
                    week: game.week,
                    opponent: game.opponent,
                    isHome: game.isHome,
                    date: "Week \(game.week)", // Simplified for now
                    time: ["1:00 PM", "4:25 PM", "8:20 PM"].randomElement()! // Placeholder times
                )
            }
        } else {
            // Fallback to sample data while loading
            return generateSampleSchedule()
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

// MARK: - 1. Roster Management View
struct RosterManagementView: View {
    @Binding var team: TeamData
    @State private var selectedPosition: String = "All"
    @StateObject private var masterDataLoader = MasterDataLoader.shared
    
    private var positions: [String] {
        let basePositions = ["All"]
        
        if masterDataLoader.isDataLoaded {
            let realPlayers = masterDataLoader.getPlayers(for: team.logoName)
            let realPositions = Set(realPlayers.map { $0.position })
            return basePositions + Array(realPositions).sorted()
        } else {
            // Fallback positions while data loads
            return basePositions + ["QB", "RB", "FB", "WR", "TE", "LT", "LG", "C", "RG", "RT", "DT", "DE", "ROLB", "MLB", "LOLB", "EDGE", "CB", "SS", "FS", "K", "P"]
        }
    }
    
    private var filteredPlayers: [PlayerData] {
        let playersToUse: [PlayerData]
        
        // Use real data if available, otherwise use sample data
        if masterDataLoader.isDataLoaded {
            let realPlayers = masterDataLoader.getPlayers(for: team.logoName)
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
        
        if selectedPosition == "All" {
            return playersToUse.sorted { $0.overall > $1.overall }
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
            playerList
        }
    }
    
    private var rosterHeader: some View {
        HStack {
            Image(systemName: "person.3.fill")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("Team Roster")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            if masterDataLoader.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Text("\(filteredPlayers.count) Players")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
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
        case 90...99: return .green
        case 80...89: return .blue
        case 70...79: return .orange
        case 60...69: return .yellow
        default: return .gray
        }
    }
}

// MARK: - 2. Season Schedule View
struct SeasonScheduleView: View {
    let team: TeamData
    @State private var selectedWeek: Int?
    
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
                
                Text("17 Games")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(team.schedule) { game in
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
