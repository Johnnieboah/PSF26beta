import SwiftUI
import Combine
import PhotosUI

struct TeamManagementView: View {
    let teamName: String
    let conference: String
    let leagueId: UUID?
    @StateObject private var coreLeagueManager = CoreLeagueManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ManagementTab = .roster
    @State private var team: TeamData
    @State private var selectedPosition: String = "Overview"
    @State private var refreshTrigger = UUID()
    @Namespace private var tabNamespace
    @Namespace private var glassNamespace
    @State private var showStartAccessory: Bool = false
    @State private var showStartAccessorySettings: Bool = false
    
    
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
    
    init(teamName: String, conference: String, leagueId: UUID? = nil) {
        self.teamName = teamName
        self.conference = conference
        self.leagueId = leagueId
        self._team = State(initialValue: TeamData.createTeamFromData(name: teamName, leagueId: leagueId))
    }
    
    var body: some View {
        // Native TabView; toolbar configured for iOS 26 polish without changing layout
        TabView(selection: $selectedTab) {
            // Roster Tab (with Overview as default) — add banner header and extend to top
            OptimizedListRow(id: "roster-\(teamName)") {
                ScrollView {
                    VStack(spacing: 0) {
                        // Start League bubble directly under the logo/header (moved below header)
                        SimplifiedTeamHeaderView(team: team)

                        if showStartAccessory {
                            HStack {
                                Spacer()
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Start league with \(team.displayName)?")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    Button {
                                        startLeagueFromTeamManagement()
                                    } label: {
                                        Text("Yes").font(.headline).foregroundColor(.white)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color(hex: TeamColorMapping.getColors(for: team.logoName).secondary))
                                    Button {
                                        withAnimation(.spring()) { showStartAccessory = false }
                                    } label: { Image(systemName: "xmark") }
                                    .buttonStyle(.bordered)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(hex: TeamColorMapping.getColors(for: team.logoName).primary))
                                )
                                .glassEffect(.regular.tint(Color(hex: TeamColorMapping.getColors(for: team.logoName).primary)).interactive())
                                Spacer()
                            }
                            .padding(.top, 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            // Collapsed handle exactly under the header
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation(.spring()) { showStartAccessory = true }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Start League")
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color(hex: TeamColorMapping.getColors(for: team.logoName).secondary))
                                    )
                                    .glassEffect(.regular.tint(Color(hex: TeamColorMapping.getColors(for: team.logoName).secondary)).interactive())
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                            .padding(.top, 12)
                        }
                        

                        VStack(spacing: 16) {
                            // Positions-only browsing in TeamManagement: no Offense/Defense grouping
                            RosterManagementView(
                                team: $team,
                                selectedPosition: $selectedPosition,
                                leagueId: leagueId,
                                includeAllChip: false,
                                unitFilterMode: false,
                                showSalaryInCells: true,
                                embedInScrollView: false // parent already scrolls; avoid nested scroll view so chips receive taps
                            )
                            // Single Start League CTA at bottom of roster tab only when Overview is selected
                            // (Removed inline toggle to keep the control only above header)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                    .scrollTargetLayout()
                }
                .scrollClipDisabled()
                .scrollTargetBehavior(.viewAligned)
                .scrollBounceBehavior(.basedOnSize)
            }
            .tabItem {
                Image(systemName: "person.3.fill")
                Text("Roster")
            }
            .tag(ManagementTab.roster)
            
            // Schedule Tab
            OptimizedListRow(id: "schedule-\(teamName)") {
                ScrollView {
                    VStack(spacing: 0) {
                        SimplifiedTeamHeaderView(team: team)
                        
                        VStack(spacing: 16) {
                            SeasonScheduleView(team: team)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    }
                    .scrollTargetLayout()
                }
                .scrollDisabled(true) // schedule grid is single view without scrolling
            }
            .tabItem {
                Image(systemName: "calendar.badge.clock")
                Text("Schedule")
            }
            .tag(ManagementTab.schedule)
            
            // Settings Tab
            OptimizedListRow(id: "settings-\(teamName)") {
                ScrollView {
                    VStack(spacing: 0) {
                        SimplifiedTeamHeaderView(team: team)
                        // Start League bubble in settings area (under header, beside title row)
                        if !showStartAccessorySettings {
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation(.spring()) { showStartAccessorySettings = true }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Start League")
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color(hex: TeamColorMapping.getColors(for: team.logoName).secondary))
                                    )
                                    .glassEffect(.regular.tint(Color(hex: TeamColorMapping.getColors(for: team.logoName).secondary)).interactive())
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                            .padding(.top, 12)
                        }
                        if showStartAccessorySettings {
                            HStack {
                                Spacer()
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18, weight: .semibold))
                                    Text("Start league with \(team.displayName)?").font(.system(size: 15, weight: .semibold, design: .rounded))
                                    Button { startLeagueFromTeamManagement() } label: { Text("Yes").font(.headline).foregroundColor(.white) }
                                        .buttonStyle(.borderedProminent)
                                        .tint(Color(hex: TeamColorMapping.getColors(for: team.logoName).secondary))
                                    Button { withAnimation(.spring()) { showStartAccessorySettings = false } } label: { Image(systemName: "xmark") }
                                        .buttonStyle(.bordered)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(hex: TeamColorMapping.getColors(for: team.logoName).primary))
                                )
                                .glassEffect(.regular.tint(Color(hex: TeamColorMapping.getColors(for: team.logoName).primary)).interactive())
                                Spacer()
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        VStack(spacing: 10) {
                            LeagueSetupView(team: team)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                    }
                    .scrollTargetLayout()
                }
                .scrollClipDisabled()
                .scrollTargetBehavior(.viewAligned)
                .scrollBounceBehavior(.basedOnSize)
                .liquidGlass(.subtle)
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Settings")
            }
            .tag(ManagementTab.league)
        }
        .modifier(iOS26TabBarEnhancements())
        // Use default nav bar appearance with the team/city name
        .navigationTitle(team.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(.automatic, for: .navigationBar)
        // Hub presentation is centralized in MainMenuView to avoid duplicate navigation updates.
        // After pendingLeague is set by CoreLeagueManager, present the hub
        // Remove local fullScreenCover; hub presentation is centralized via MainMenuView
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MasterDataLoaded"))) { _ in
            // Master data has finished loading - refresh empty cached data first
            print("🔄 TeamManagementView: Master data loaded - checking if refresh needed for \(team.logoName)")
            PlayerDataManager.shared.refreshEmptyCachedTeams()
            
            // Also refresh team data if it's using sample data
            if team.players.isEmpty || team.players.first?.firstName == "Sample" {
                print("🔄 TeamManagementView: Refreshing team data for \(team.logoName)")
                team = TeamData.createTeamFromData(name: teamName, leagueId: leagueId)
            }
        }

    }

}

// MARK: - Private helpers
private extension TeamManagementView {
    func startLeagueFromTeamManagement() {
        // Create default settings (mirror LeagueSetupView defaults)
        let settings = LeagueSetupSettings(
            difficulty: "Pro",
            autoSave: true,
            autoSetDepthChart: true,
            autoFillTeam: false,
            injuriesEnabled: true,
            salaryCapEnabled: true,
            gameSpeed: "Normal"
        )

        Task { @MainActor in
            print("▶️ StartLeague pressed from TeamManagementView for \(team.logoName)")
            await CoreLeagueManager.shared.startNewLeague(
                teamName: team.name,
                logoName: team.logoName,
                customLogoData: nil,
                settings: settings
            )
        }
    }
}

// Local luminance helper for toolbar contrast
@inline(__always)
private func colorLuminance(hex: String) -> Double {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&int)
    let r, g, b: Double
    switch cleaned.count {
    case 3:
        r = Double((int >> 8) & 0xF) * 17.0 / 255.0
        g = Double((int >> 4) & 0xF) * 17.0 / 255.0
        b = Double(int & 0xF) * 17.0 / 255.0
    case 6, 8:
        let hasAlpha = cleaned.count == 8
        let base = hasAlpha ? int & 0x00FFFFFF : int
        r = Double((base >> 16) & 0xFF) / 255.0
        g = Double((base >> 8) & 0xFF) / 255.0
        b = Double(base & 0xFF) / 255.0
    default:
        r = 1; g = 1; b = 1
    }
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
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
                teamSolidBackground
                    .ignoresSafeArea(.all)
            )
    }
    
    // Prefer an explicit banner preference per team. If a team is marked "light",
    // use its secondary color; if marked "dark", use its primary color. Otherwise,
    // fallback to whichever is lighter by luminance. Central mapping lives in TeamUIResolver.
    private func lightTeamColorHex() -> String {
        TeamUIResolver.bannerHex(for: team.logoName)
    }

    private func luminance(hex: String) -> Double {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: Double
        switch cleaned.count {
        case 3:
            r = Double((int >> 8) & 0xF) * 17.0 / 255.0
            g = Double((int >> 4) & 0xF) * 17.0 / 255.0
            b = Double(int & 0xF) * 17.0 / 255.0
        case 6, 8:
            // if 8, assume AARRGGBB and ignore alpha
            let hasAlpha = cleaned.count == 8
            let base = hasAlpha ? int & 0x00FFFFFF : int
            r = Double((base >> 16) & 0xFF) / 255.0
            g = Double((base >> 8) & 0xFF) / 255.0
            b = Double(base & 0xFF) / 255.0
        default:
            r = 1; g = 1; b = 1
        }
        // sRGB perceived luminance
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    
    private var headerContent: some View {
        HStack {
            Spacer()
            
            Image(team.logoName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                // Keep a modest shadow in the header per design
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    private var teamSolidBackground: some View {
        GeometryReader { proxy in
            // Single light team color (identity-aware)
            let base = Color(hex: lightTeamColorHex())
            Rectangle()
                .fill(base)
                // Subtle multiply pass to enrich saturation without turning it into a gradient
                .overlay(
                    Rectangle()
                        .fill(base)
                        .opacity(0.10)
                        .blendMode(.multiply)
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .saturation(1.15) // small global boost for more punch
        }
    }
}

// MARK: - Team Data Model
struct TeamData {
    let name: String
    let logoName: String
    let primaryColor: String
    let secondaryColor: String
    var customDisplayName: String? = nil
    var players: [PlayerData]
    var schedule: [GameData]
    var leagueSettings: LeagueSettings
    
    var asLeagueTeam: LeagueTeam {
        LeagueTeam.createFromTeamData(self)
    }
    
    // Display name prioritizes a user-provided custom name; falls back to city-only name
    var displayName: String {
        if let custom = customDisplayName, !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            return custom
        }
        return TeamData.getTeamCityName(logoName)
    }
    
    static func createTeamFromData(name: String, leagueId: UUID? = nil, isTrainingCamp: Bool = false) -> TeamData {
        let colors = TeamColorMapping.getColors(for: name)
        let masterLoader = MasterDataLoader.shared
        
        return TeamData(
            name: getTeamDisplayName(name),
            logoName: name,
            primaryColor: colors.primary,
            secondaryColor: colors.secondary,
            players: loadRosterFromMasterData(teamName: name, masterLoader: masterLoader, leagueId: leagueId, isTrainingCamp: isTrainingCamp),
            schedule: loadScheduleFromMasterData(teamName: name, masterLoader: masterLoader),
            leagueSettings: LeagueSettings.defaultSettings()
        )
    }
    
    static func loadRosterFromMasterData(teamName: String, masterLoader: MasterDataLoader, leagueId: UUID? = nil, isTrainingCamp: Bool = false) -> [PlayerData] {
        // Phase 3: Use hybrid loading approach
        let players = PlayerDataManager.shared.getPlayers(for: teamName, leagueId: leagueId)
        
        if !players.isEmpty {
            return players
        } else {
            // Final fallback to sample data only if no real data is available
            print("⚠️ No real data found for \(teamName), using sample data")
            return generateSamplePlayers(isTrainingCamp: isTrainingCamp)
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
        // Convert full team names to city names only
        let teamNameMapping: [String: String] = [
            "Kansas City Chiefs": "Kansas City",
            "San Francisco 49ers": "San Francisco",
            "Miami Dolphins": "Miami",
            "Dallas Cowboys": "Dallas",
            "Chicago Bears": "Chicago",
            "Detroit Lions": "Detroit",
            "Green Bay Packers": "Green Bay",
            "Minnesota Vikings": "Minnesota",
            "New York Giants": "New York",
            "Philadelphia Eagles": "Philadelphia",
            "Washington Commanders": "Washington",
            "Atlanta Falcons": "Atlanta",
            "Carolina Panthers": "Carolina",
            "New Orleans Saints": "New Orleans",
            "Tampa Bay Buccaneers": "Tampa Bay",
            "Arizona Cardinals": "Arizona",
            "Los Angeles Rams": "Los Angeles",
            "Seattle Seahawks": "Seattle",
            "Baltimore Ravens": "Baltimore",
            "Cincinnati Bengals": "Cincinnati",
            "Cleveland Browns": "Cleveland",
            "Pittsburgh Steelers": "Pittsburgh",
            "Buffalo Bills": "Buffalo",
            "New England Patriots": "New England",
            "New York Jets": "New York",
            "Houston Texans": "Houston",
            "Indianapolis Colts": "Indianapolis",
            "Jacksonville Jaguars": "Jacksonville",
            "Tennessee Titans": "Tennessee",
            "Denver Broncos": "Denver",
            "Las Vegas Raiders": "Las Vegas",
            "Los Angeles Chargers": "Los Angeles"
        ]
        
        return teamNameMapping[fullOpponentName] ?? fullOpponentName
    }
    
    static func getGameTime(for week: Int) -> String {
        let timeslots = [
            "1:00 PM", "1:00 PM", "4:05 PM", "4:25 PM",
            "8:15 PM", "8:20 PM", "7:00 PM"
        ]
        
        // Generate deterministic time based on week number
        let timeIndex = (week - 1) % timeslots.count
        return timeslots[timeIndex]
    }
    
    static func getTeamDisplayName(_ teamName: String) -> String {
        return getTeamCityName(teamName)
    }
    
    static func getTeamCityName(_ teamName: String) -> String {
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

// MARK: - Game Data Model
struct GameData: Identifiable {
    let id = UUID()
    let week: Int
    let opponent: String
    let isHome: Bool
    let date: String
    let time: String
    var homeScore: Int?
    var awayScore: Int?
    var isCompleted: Bool = false
    
    var userTeamScore: Int? {
        guard let homeScore = homeScore, let awayScore = awayScore else { return nil }
        return isHome ? homeScore : awayScore
    }
    
    var opponentScore: Int? {
        guard let homeScore = homeScore, let awayScore = awayScore else { return nil }
        return isHome ? awayScore : homeScore
    }
    
    var userTeamWon: Bool? {
        guard let userScore = userTeamScore, let oppScore = opponentScore else { return nil }
        return userScore > oppScore
    }
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

// MARK: - 1. Roster Management View (Extracted to RosterManagementView.swift)
// RosterManagementView is now in its own file for better organization

// MARK: - Player Row View (Legacy - being replaced with OptimizedPlayerRow)
struct PlayerRowView: View {
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
            return playersToUse.filter { $0.position == selectedPosition }.sorted { 
                if $0.overall != $1.overall {
                    return $0.overall > $1.overall
                }
                return $0.fullName < $1.fullName // Stable tie-breaker
            }
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
        HStack(spacing: 12) {
            Spacer(minLength: 0)

            Text("Team Overview")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Menu {
                ForEach(positions, id: \.self) { position in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            selectedPosition = position
                        }
                    } label: {
                        HStack {
                            Text(position)
                            if selectedPosition == position {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedPosition)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }
    
    private var teamOverviewContent: some View {
        let teamPlayers = getTeamPlayers()
        let teamOveralls = calculateTeamOverallsWithCache(players: teamPlayers, leagueId: nil)
        let topPlayers = getTopPlayers(players: teamPlayers)
        
        // Debug logging for team overalls
        let _ = print(" \(team.name) Enhanced Overalls - Offense: \(teamOveralls.offense), Defense: \(teamOveralls.defense), Overall: \(teamOveralls.overall)")
        
        return VStack(alignment: .leading, spacing: 24) {
            // Team Overalls Section (title now centered and renamed inside the card)
            TeamOverallsCard(
                teamOveralls: teamOveralls,
                teamColor: team.primaryColor
            )

            // Top Players Section
            TopPlayersCard(
                players: topPlayers,
                teamColor: team.primaryColor
            )
            
            // Removed Team Stats bubble entirely per request
        }
    }
    
    // MARK: - Phase 6: Updated to use hybrid data loading  
    private func getTeamPlayers() -> [PlayerData] {
        // Use balanced players for team selection to ensure accurate roster display
        let players = PlayerDataManager.shared.getBalancedPlayersForTeamSelection(for: team.logoName)
        
        if !players.isEmpty {
            // Log the actual player count and verify consistency
            print("👥 📊 TeamManagementView: \(team.logoName) displaying \(players.count) players")
            if players.count == 60 {
                print("👥 ✅ TeamManagementView: \(team.logoName) has exactly 60 players as expected")
            } else {
                print("👥 ⚠️ TeamManagementView: \(team.logoName) has \(players.count) players, expected 60")
            }
            return players
        } else {
            // Final fallback to original team data
            print("👥 ⚠️ TeamManagementView: Falling back to original team data for \(team.logoName)")
            return team.players
        }
    }
    
    private func calculateTeamOverallsWithCache(players: [PlayerData], leagueId: UUID?) -> (offense: Int, defense: Int, overall: Int) {
        // For team selection (no league context), check cache first to ensure consistency
        if leagueId == nil {
            if let cachedRatings = PlayerDataManager.shared.getCachedTeamOverallRatings(for: team.logoName) {
                print("📊 📋 Using cached team overall ratings for \(team.logoName): O:\(cachedRatings.offense) D:\(cachedRatings.defense) Overall:\(cachedRatings.overall)")
                return cachedRatings
            }
        }
        
        let offensivePositions = ["QB", "RB", "FB", "WR", "TE", "LT", "LG", "C", "RG", "RT"]
        let defensivePositions = ["MLB", "ROLB", "LOLB", "EDGE", "DE", "DT", "CB", "SS", "FS"]
        
        let offensivePlayers = players.filter { offensivePositions.contains($0.position) }
        let defensivePlayers = players.filter { defensivePositions.contains($0.position) }
        
        // Calculate raw unit ratings first
        let rawOffenseRating = calculateEnhancedUnitRating(players: offensivePlayers, isOffense: true)
        let rawDefenseRating = calculateEnhancedUnitRating(players: defensivePlayers, isOffense: false)
        
        // Apply consistent normalization to both unit ratings to bring them to realistic ranges
        let offenseOverall = normalizeUnitRating(Double(rawOffenseRating), players: offensivePlayers, teamName: team.logoName)
        let defenseOverall = normalizeUnitRating(Double(rawDefenseRating), players: defensivePlayers, teamName: team.logoName)
        
        // Calculate special teams rating
        let specialTeamsPlayers = players.filter { ["K", "P"].contains($0.position) }
        let specialTeamsRating = calculateSpecialTeamsRating(players: specialTeamsPlayers)
        
        // Team overall is now a logical combination of the unit ratings
        // Weight the units (Offense: 45%, Defense: 45%, Special Teams: 10%)
        let rawTeamRating = (Double(offenseOverall) * 0.45) + (Double(defenseOverall) * 0.45) + (specialTeamsRating * 0.10)
        
        // Minor adjustment for team overall (should be close to weighted average)
        let teamOverall = Int(round(rawTeamRating))
        
        let finalRatings = (offenseOverall, defenseOverall, teamOverall)
        
        // Cache the ratings for team selection to ensure consistency
        if leagueId == nil {
            PlayerDataManager.shared.cacheTeamOverallRatings(for: team.logoName, ratings: finalRatings)
        }
        
        return finalRatings
    }
    
    /// Normalizes unit ratings (offense/defense) to realistic NFL ranges with increased variance
    private func normalizeUnitRating(_ rawRating: Double, players: [PlayerData], teamName: String) -> Int {
        // Expanded range for more variance (70-95 instead of 75-95)
        let minUnitRating = 70.0
        let maxUnitRating = 95.0
        
        // Calculate depth and quality factors for this unit
        let sortedPlayers = players.sorted { $0.overall > $1.overall }
        let topPlayers = Array(sortedPlayers.prefix(min(8, sortedPlayers.count))) // Top 8 for unit
        let topPlayerAverage = topPlayers.isEmpty ? rawRating : Double(topPlayers.map { $0.overall }.reduce(0, +)) / Double(topPlayers.count)
        
        // More aggressive combination to increase variance
        let enhancedRating = (rawRating * 0.6) + (topPlayerAverage * 0.4)
        
        // Apply team-specific adjustments to create proper variance
        let teamAdjustment = getTeamStrengthAdjustment(teamName: teamName)
        let adjustedRating = enhancedRating + teamAdjustment
        
        // Add variance amplification based on team strength
        let strengthMultiplier = calculateStrengthMultiplier(enhancedRating: adjustedRating)
        let amplifiedRating = adjustedRating * strengthMultiplier
        
        // Wider normalization range for more spread
        let normalizedValue = (amplifiedRating - 60.0) / 35.0 // Wider range for more variance
        let clampedValue = max(0.0, min(1.0, normalizedValue))
        
        let finalRating = minUnitRating + (clampedValue * (maxUnitRating - minUnitRating))
        
        return Int(round(finalRating))
    }
    
    /// Calculates a strength multiplier to amplify differences between good and bad teams
    private func calculateStrengthMultiplier(enhancedRating: Double) -> Double {
        // Amplify the differences - make good teams better and bad teams worse
        if enhancedRating >= 85 {
            return 1.15  // Elite teams get a boost
        } else if enhancedRating >= 80 {
            return 1.08  // Good teams get moderate boost
        } else if enhancedRating >= 75 {
            return 1.02  // Average teams stay roughly the same
        } else if enhancedRating >= 70 {
            return 0.95  // Below average teams get slightly penalized
        } else {
            return 0.88  // Bad teams get more heavily penalized
        }
    }
    
    private func normalizeTeamRating(_ rawRating: Double, allPlayers: [PlayerData]) -> Int {
        // Optimized for 60-player rosters - calculate team depth and talent variance
        let sortedPlayers = allPlayers.sorted { $0.overall > $1.overall }
        
        // Adjusted for 60-player rosters: use more starters/key players (top 28 instead of 22)
        let topPlayersCount = min(28, sortedPlayers.count) // Increased for 60-player rosters
        let topPlayers = Array(sortedPlayers.prefix(topPlayersCount))
        
        // Calculate additional factors optimized for 60-player rosters
        let topPlayerAverage = topPlayers.isEmpty ? rawRating : Double(topPlayers.map { $0.overall }.reduce(0, +)) / Double(topPlayers.count)
        let depthQuality = calculateDepthQuality60Player(allPlayers: allPlayers)
        let talentVariance = calculateTalentVariance60Player(allPlayers: allPlayers)
        
        // Adjusted weights for 60-player rosters - emphasize top talent more due to smaller roster
        let enhancedRating = (rawRating * 0.45) + (topPlayerAverage * 0.40) + (depthQuality * 0.10) + (talentVariance * 0.05)
        
        // Apply team-specific adjustments based on recent performance and known strengths
        let teamAdjustment = getTeamStrengthAdjustment(teamName: team.logoName)
        let finalEnhancedRating = enhancedRating + teamAdjustment
        
        // Adjusted range mapping for 60-player rosters - raised to realistic NFL levels
        let minRating = 78.0  // Raised floor to realistic NFL minimum
        let maxRating = 94.0  // Raised ceiling to allow elite teams to shine
        let normalizedValue = (finalEnhancedRating - 60.0) / 30.0 // Adjusted base and range for higher ratings
        let clampedValue = max(0.0, min(1.0, normalizedValue))
        
        let finalRating = minRating + (clampedValue * (maxRating - minRating))
        
        return Int(round(finalRating))
    }
    
    private func getTeamStrengthAdjustment(teamName: String) -> Double {
        // Enhanced team-specific adjustments with increased variance to spread teams out
        // More aggressive adjustments to prevent clustering in the middle
        switch teamName {
        // Elite Tier - Super Bowl Champions & Perennial Contenders (88-95 range)
        case "Philadelphia": return 12.0  // Super Bowl winners - elite across the board
        case "KansasCity": return 11.0    // Mahomes + championship pedigree
        case "Buffalo": return 10.0      // Josh Allen + consistently elite
        case "SanFrancisco": return 9.5  // Elite roster construction
        
        // Very Strong Tier - Playoff Contenders (85-89 range)
        case "Baltimore": return 8.5     // Lamar + strong defense
        case "Cincinnati": return 8.0    // Burrow + elite receiving corps
        case "Miami": return 7.0         // High-powered offense
        case "Dallas": return 6.5        // Talented but inconsistent
        case "Detroit": return 6.0       // Rising with good coaching
        
        // Good Tier - Solid Teams (82-85 range)
        case "GreenBay": return 5.0      // Solid with good QB play
        case "Seattle": return 4.5       // Consistent playoff team
        case "Minnesota": return 4.0     // Good roster, coaching
        case "LAN": return 3.5           // Rams with McVay
        case "Jacksonville": return 3.0  // Young team improving
        
        // Average Tier - Middle of Pack (78-82 range)
        case "Pittsburgh": return 2.0    // Solid but aging
        case "Cleveland": return 1.5     // Inconsistent talent
        case "Indianapolis": return 0.5  // Rebuilding mode
        case "Atlanta": return 0.0       // Middle of the pack
        case "TampaBay": return -0.5     // Post-Brady transition
        case "LasVegas": return -1.0     // Underachieving
        case "LAA": return -1.5          // Chargers - talented but disappointing
        case "NewOrleans": return -2.0   // Saints - aging roster
        case "NYN": return -2.5          // Giants - limited talent
        
        // Below Average Tier - Rebuilding Teams (72-76 range)
        case "Houston": return -3.5      // Young team, still building
        case "Tennessee": return -4.0    // Down year, roster issues
        case "NYA": return -4.5          // Jets - disappointing with talent
        case "Denver": return -5.0       // Inconsistent, QB questions
        case "NewEngland": return -5.5   // Post-Brady struggles
        case "Washington": return -6.0   // Rebuilding, limited talent
        
        // Poor Tier - Bottom Feeders (68-72 range)
        case "Chicago": return -7.0      // Rebuilding, picked 10th overall
        case "Carolina": return -8.0     // Panthers - major rebuild
        case "Arizona": return -9.0      // Cardinals - bottom tier roster
        
        default: return 0.0              // Unknown team
        }
    }
    
    private func calculateDepthQuality(allPlayers: [PlayerData]) -> Double {
        // Measure how good the depth players are (positions 23-53)
        let sortedPlayers = allPlayers.sorted { $0.overall > $1.overall }
        let depthPlayers = Array(sortedPlayers.dropFirst(22))
        
        if depthPlayers.isEmpty { return 70.0 }
        
        let depthAverage = Double(depthPlayers.map { $0.overall }.reduce(0, +)) / Double(depthPlayers.count)
        return depthAverage
    }
    
    private func calculateTalentVariance(allPlayers: [PlayerData]) -> Double {
        // Enhanced talent variance - rewards teams with elite players more heavily
        let overalls = allPlayers.map { Double($0.overall) }
        let average = overalls.reduce(0, +) / Double(overalls.count)
        
        // Count elite players (90+) and penalize teams with too many low-rated players
        let elitePlayers = overalls.filter { $0 >= 90.0 }.count
        let lowRatedPlayers = overalls.filter { $0 < 70.0 }.count
        
        // Calculate standard variance
        let variance = overalls.reduce(0) { sum, overall in
            sum + pow(overall - average, 2)
        } / Double(overalls.count)
        
        // Enhanced bonus system
        let baseVariance = sqrt(variance) * 2.0
        let eliteBonus = Double(elitePlayers) * 1.5  // Big bonus for elite players
        let lowRatedPenalty = Double(lowRatedPlayers) * -0.8  // Penalty for too many low players
        
        return baseVariance + eliteBonus + lowRatedPenalty
    }
    
    /// Optimized depth quality calculation for 60-player rosters
    private func calculateDepthQuality60Player(allPlayers: [PlayerData]) -> Double {
        let sortedPlayers = allPlayers.sorted { $0.overall > $1.overall }
        
        // For 60-player rosters, consider depth in tiers
        let tier1Count = min(12, sortedPlayers.count) // Elite starters
        let tier2Count = min(20, sortedPlayers.count) // Quality depth
        let tier3Count = min(35, sortedPlayers.count) // Serviceable players
        
        let tier1Players = Array(sortedPlayers.prefix(tier1Count))
        let tier2Players = Array(sortedPlayers.prefix(tier2Count).dropFirst(tier1Count))
        let tier3Players = Array(sortedPlayers.prefix(tier3Count).dropFirst(tier2Count))
        
        // Calculate weighted depth score with higher base values
        let tier1Average = tier1Players.isEmpty ? 75.0 : Double(tier1Players.map { $0.overall }.reduce(0, +)) / Double(tier1Players.count)
        let tier2Average = tier2Players.isEmpty ? 70.0 : Double(tier2Players.map { $0.overall }.reduce(0, +)) / Double(tier2Players.count)
        let tier3Average = tier3Players.isEmpty ? 65.0 : Double(tier3Players.map { $0.overall }.reduce(0, +)) / Double(tier3Players.count)
        
        // Weight tiers appropriately for 60-player rosters
        let depthScore = (tier1Average * 0.5) + (tier2Average * 0.3) + (tier3Average * 0.2)
        
        // Normalize to 0-15 range for higher impact
        return (depthScore - 65.0) / 2.0
    }
    
    /// Optimized talent variance calculation for 60-player rosters
    private func calculateTalentVariance60Player(allPlayers: [PlayerData]) -> Double {
        guard allPlayers.count >= 10 else { return 0.0 }
        
        let overalls = allPlayers.map { Double($0.overall) }
        let average = overalls.reduce(0, +) / Double(overalls.count)
        let variance = overalls.map { pow($0 - average, 2) }.reduce(0, +) / Double(overalls.count)
        
        // Count elite and low-rated players adjusted for 60-player rosters
        let elitePlayers = allPlayers.filter { $0.overall >= 85 }.count
        let lowRatedPlayers = allPlayers.filter { $0.overall <= 55 }.count
        
        // Adjusted bonus system for 60-player rosters
        let baseVariance = sqrt(variance) * 1.8  // Slightly reduced impact
        let eliteBonus = Double(elitePlayers) * 1.2  // Reduced bonus for elite players
        let lowRatedPenalty = Double(lowRatedPlayers) * -0.6  // Reduced penalty
        
        return baseVariance + eliteBonus + lowRatedPenalty
    }
    
    private func calculateEnhancedUnitRating(players: [PlayerData], isOffense: Bool) -> Int {
        guard !players.isEmpty else { return 75 } // Raised base minimum
        
        // Enhanced position weights - QB impact increased significantly
        let positionWeights: [String: Double] = isOffense ? [
            "QB": 4.5,      // Quarterback has massive impact on team success
            "LT": 2.5, "RT": 2.2,  // Tackle protection crucial
            "WR": 2.0,      // Primary receivers
            "RB": 1.8,      // Running game impact
            "TE": 1.5,      // Versatile weapon
            "C": 1.4,       // Center of the line
            "LG": 1.2, "RG": 1.2,  // Guards
            "FB": 0.9       // Fullback (less common)
        ] : [
            "CB": 2.5,      // Cover elite receivers
            "EDGE": 2.3,    // Pass rush game-changer
            "MLB": 2.0,     // Run defense/coverage anchor
            "DE": 1.8,      // Pass rush/run stop
            "SS": 1.6, "FS": 1.6,  // Safety coverage
            "DT": 1.5,      // Interior rush/run stop
            "ROLB": 1.4, "LOLB": 1.4  // Outside linebackers
        ]
        
        // Group players by position and get top players at each position
        let playersByPosition = Dictionary(grouping: players) { $0.position }
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        for (position, positionPlayers) in playersByPosition {
            let weight = positionWeights[position] ?? 1.0
            let sortedPlayers = positionPlayers.sorted { $0.overall > $1.overall }
            
            // Optimized for 60-player rosters: consider appropriate depth per position
            let depthToConsider = getOptimalDepthForPosition(position: position, availablePlayers: sortedPlayers.count)
            let playersToConsider = Array(sortedPlayers.prefix(depthToConsider))
            
            // Adjusted depth weighting for 60-player rosters
            for (index, player) in playersToConsider.enumerated() {
                let depthMultiplier: Double
                switch index {
                case 0: depthMultiplier = 1.0      // Starter
                case 1: depthMultiplier = 0.5      // Primary backup
                case 2: depthMultiplier = 0.25     // Secondary backup
                default: depthMultiplier = 0.1     // Deep depth
                }
                
                let playerWeight = weight * depthMultiplier
                weightedSum += Double(player.overall) * playerWeight
                totalWeight += playerWeight
            }
        }
        
        let unitRating = totalWeight > 0 ? weightedSum / totalWeight : 75.0 // Raised fallback
        return Int(round(unitRating))
    }
    
    /// Determines optimal depth to consider for each position in 60-player rosters
    private func getOptimalDepthForPosition(position: String, availablePlayers: Int) -> Int {
        // Optimized depth consideration for 60-player rosters
        let optimalDepth: Int
        
        switch position {
        // Key positions need more depth consideration
        case "QB": optimalDepth = min(3, availablePlayers)  // All QBs matter
        case "RB": optimalDepth = min(4, availablePlayers)  // RB rotation important
        case "WR": optimalDepth = min(5, availablePlayers)  // WR depth crucial
        case "CB": optimalDepth = min(4, availablePlayers)  // CB depth important
        
        // Important positions with moderate depth
        case "LT", "RT", "EDGE", "MLB": optimalDepth = min(3, availablePlayers)
        
        // Standard positions
        case "TE", "DE", "DT", "SS", "FS": optimalDepth = min(3, availablePlayers)
        
        // Interior line and linebackers
        case "C", "LG", "RG", "ROLB", "LOLB": optimalDepth = min(2, availablePlayers)
        
        // Specialists
        case "K", "P", "FB": optimalDepth = min(1, availablePlayers)
        
        default: optimalDepth = min(2, availablePlayers)
        }
        
        return max(1, optimalDepth) // Always consider at least the starter
    }
    
    private func calculateSpecialTeamsRating(players: [PlayerData]) -> Double {
        let kickers = players.filter { $0.position == "K" }
        let punters = players.filter { $0.position == "P" }
        
        let kickerRating = kickers.isEmpty ? 78.0 : Double(kickers.max { $0.overall < $1.overall }?.overall ?? 78)
        let punterRating = punters.isEmpty ? 78.0 : Double(punters.max { $0.overall < $1.overall }?.overall ?? 78)
        
        return (kickerRating + punterRating) / 2.0
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
                OptimizedPlayerRow(
                    player: OptimizedPlayerRow.PlayerRowData(
                        id: "\(player.number)-\(player.lastName)",
                        name: player.fullName,
                        position: player.position,
                        number: player.number,
                        overall: player.overall,
                        age: player.age
                    ),
                    teamColor: team.primaryColor,
                    teamLogoName: nil,
                    leagueId: nil,
                    onPlayerUpdated: nil
                )
            }
        }
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
            }
            .padding(20)
            .roundedBackground(.ultraThinMaterial, radius: Corner.large)
            .overlay(
                RoundedRectangle(cornerRadius: Corner.large, style: .continuous)
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
                .roundedBackground(Color(.systemGray6), radius: Corner.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: Corner.medium, style: .continuous)
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
                            .roundedBackground(Color(hex: team.primaryColor), radius: Corner.small)
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
            .roundedBackground(.ultraThinMaterial, radius: Corner.large)
            .overlay(
                RoundedRectangle(cornerRadius: Corner.large, style: .continuous)
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
            .roundedBackground(.ultraThinMaterial, radius: Corner.large)
            .overlay(
                RoundedRectangle(cornerRadius: Corner.large, style: .continuous)
                    .stroke(.orange.opacity(0.3), lineWidth: 1.5)
            )
        }
    }
    
    // MARK: - Start League Button (deprecated in favor of header bubble)
    private var startLeagueButton: some View { EmptyView() }
    
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

// MARK: - Team Overalls Card (Moved to TeamOverviewCards.swift)

// MARK: - Overall Stat View (Moved to TeamOverviewCards.swift)

// MARK: - Top Players Card (Moved to TeamOverviewCards.swift)

// MARK: - Top Player Row View (Moved to TeamOverviewCards.swift)

// MARK: - Team Stats Card (Moved to TeamOverviewCards.swift)

// MARK: - Sample Data Generation (Temporary until JSON loading is implemented)
extension TeamData {
    static func generateSamplePlayers(isTrainingCamp: Bool = false) -> [PlayerData] {
        // Generate consistent sample players (only used as fallback)
        let firstNames = [
            "Aaron", "Adrian", "Alex", "Andrew", "Anthony", "Antonio", "Ben", "Brandon", "Brian", "Calvin",
            "Cameron", "Carlos", "Chris", "Christian", "Dak", "Daniel", "David", "Derek", "DeAndre", "Eric",
            "Frank", "George", "Henry", "Isaiah", "Ivan", "Jack", "Jalen", "James", "Jason", "Jaylen",
            "Jordan", "Josh", "Justin", "Kyle", "Lamar", "Luke", "Marcus", "Mark", "Mason", "Matt",
            "Michael", "Mike", "Nathan", "Nick", "Oscar", "Patrick", "Paul", "Quinn", "Robert", "Ryan",
            "Sam", "Steve", "Tanner", "Tom", "Tony", "Travis", "Trevor", "Tyler", "Victor", "Zach"
        ]
        let lastNames = [
            "Adams", "Allen", "Anderson", "Baker", "Bell", "Brown", "Clark", "Davis", "Evans", "Fisher",
            "Garcia", "Green", "Hall", "Harris", "Hill", "Jackson", "Johnson", "Jones", "King", "Lee",
            "Lewis", "Martin", "Miller", "Moore", "Nelson", "Parker", "Phillips", "Quinn", "Roberts", "Robinson",
            "Rodriguez", "Smith", "Taylor", "Thomas", "Thompson", "Turner", "Walker", "White", "Williams", "Wilson",
            "Wood", "Wright", "Young", "Campbell", "Carter", "Collins", "Cooper", "Edwards", "Ellis", "Foster"
        ]
        let positions = ["QB", "RB", "WR", "TE", "LT", "LG", "C", "RG", "RT", "DE", "DT", "MLB", "CB", "SS", "FS", "K", "P"]
        
        var players: [PlayerData] = []
        var usedNumbers: Set<Int> = []
        
        // Generate appropriate number of players (60 for training camp, 53 for regular season)
        let playerCount = isTrainingCamp ? 60 : 53
        for i in 0..<playerCount {
            // Use index-based deterministic selection instead of random
            let firstNameIndex = i % firstNames.count
            let lastNameIndex = (i * 7) % lastNames.count  // Different multiplier for variety
            let positionIndex = i % positions.count
            
            // Generate deterministic jersey number
            var number = (i + 1)
            while usedNumbers.contains(number) {
                number += 1
                if number > 99 { number = 1 }
            }
            usedNumbers.insert(number)
            
            // Generate deterministic overall and age based on index
            let overall = 55 + (i * 7) % 40  // Range 55-95
            let age = 22 + (i * 3) % 14      // Range 22-35
            
            let player = PlayerData(
                firstName: firstNames[firstNameIndex],
                lastName: lastNames[lastNameIndex],
                position: positions[positionIndex],
                number: number,
                overall: overall,
                age: age
            )
            players.append(player)
        }
        
        return players.sorted { $0.number < $1.number }
    }
    
    static func generateSampleSchedule() -> [GameData] {
        let opponents = ["Dallas", "Philadelphia", "Washington", "New York", "Green Bay", "Minnesota", "Detroit",
                        "Tampa Bay", "New Orleans", "Atlanta", "Carolina", "San Francisco", "Seattle", "Arizona",
                        "Los Angeles", "Kansas City", "Buffalo"]
        
        var schedule: [GameData] = []
        
        // Generate 17 games deterministically
        for week in 1...17 {
            let opponentIndex = (week - 1) % opponents.count
            let isHome = week % 2 == 1  // Alternating home/away pattern
            
            let game = GameData(
                week: week,
                opponent: opponents[opponentIndex],
                isHome: isHome,
                date: "Week \(week)",
                time: getGameTime(for: week)
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
