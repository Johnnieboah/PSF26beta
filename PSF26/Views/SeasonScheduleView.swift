import SwiftUI

// MARK: - Season Schedule View
struct SeasonScheduleView: View {
    let team: TeamData
    @State private var selectedWeek: Int?
    @StateObject private var masterDataLoader = MasterDataLoader.shared
    @State private var presentedGame: GameData?
    
    // Non-bye game count for header label
    private var nonByeCount: Int {
        scheduleGames.filter { $0.opponent != "BYE" }.count
    }

    private var scheduleGames: [GameData] {
        let realSchedule = masterDataLoader.getSchedule(for: team.logoName)
        
        if !realSchedule.isEmpty {
            // Create 18-week schedule including bye weeks (NFL has 18 weeks total, 17 games + 1 bye)
            var allWeeks: [GameData] = []
            let gamesByWeek = Dictionary(grouping: realSchedule) { $0.week }
            
            // NFL season spans weeks 1-18
            for week in 1...18 {
                if let games = gamesByWeek[week], let game = games.first {
                    // Always create clean game data without checking for results
                    let gameData = GameData(
                        week: game.week,
                        opponent: TeamData.simplifyOpponentName(game.opponent),
                        isHome: game.isHome,
                        date: "Week \(game.week)",
                        time: TeamData.getGameTime(for: game.week)
                    )
                    // NOTE: No game results are loaded here - this ensures clean schedules
                    
                    allWeeks.append(gameData)
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
    
    // Re-order for 3 columns with vertical groupings:
    // Col 1: weeks 1-6, Col 2: 7-12, Col 3: 13-18
    private var orderedGridGames: [GameData] {
        let byWeek = Dictionary(uniqueKeysWithValues: scheduleGames.map { ($0.week, $0) })
        var out: [GameData] = []
        for r in 1...6 {
            if let g1 = byWeek[r] { out.append(g1) }
            if let g2 = byWeek[r + 6] { out.append(g2) }
            if let g3 = byWeek[r + 12] { out.append(g3) }
        }
        return out
    }

    // 2-column ordering for wider cells: Col 1 weeks 1-9, Col 2 weeks 10-18
    private var orderedGridGames2Col: [GameData] {
        let byWeek = Dictionary(uniqueKeysWithValues: scheduleGames.map { ($0.week, $0) })
        var out: [GameData] = []
        for r in 1...9 {
            if let g1 = byWeek[r] { out.append(g1) }
            if let g2 = byWeek[r + 9] { out.append(g2) }
        }
        return out
    }
    
    // Helper: get opponent logo name by week to disambiguate NYG/NYJ, LA teams, etc.
    private func getOpponentLogoName(week: Int, opponent: String) -> String {
        // Get the full opponent name from schedule
        let realSchedule = masterDataLoader.getSchedule(for: team.logoName)
        
        // Prefer exact week match first
        if let matchingGame = realSchedule.first(where: { $0.week == week }) {
            // Convert full team name to logo name
            let logoMapping: [String: String] = [
                "Kansas City Chiefs": "KansasCity",
                "San Francisco 49ers": "SanFrancisco",
                "Miami Dolphins": "Miami",
                "Dallas Cowboys": "Dallas",
                "Chicago Bears": "Chicago",
                "Detroit Lions": "Detroit",
                "Green Bay Packers": "GreenBay",
                "Minnesota Vikings": "Minnesota",
                "New York Giants": "NYN",
                "Philadelphia Eagles": "Philadelphia",
                "Washington Commanders": "Washington",
                "Atlanta Falcons": "Atlanta",
                "Carolina Panthers": "Carolina",
                "New Orleans Saints": "NewOrleans",
                "Tampa Bay Buccaneers": "TampaBay",
                "Arizona Cardinals": "Arizona",
                "Los Angeles Rams": "LAN",
                "Seattle Seahawks": "Seattle",
                "Baltimore Ravens": "Baltimore",
                "Cincinnati Bengals": "Cincinnati",
                "Cleveland Browns": "Cleveland",
                "Pittsburgh Steelers": "Pittsburgh",
                "Buffalo Bills": "Buffalo",
                "New England Patriots": "NewEngland",
                "New York Jets": "NYA",
                "Houston Texans": "Houston",
                "Indianapolis Colts": "Indianapolis",
                "Jacksonville Jaguars": "Jacksonville",
                "Tennessee Titans": "Tennessee",
                "Denver Broncos": "Denver",
                "Las Vegas Raiders": "LasVegas",
                "Los Angeles Chargers": "LAA"
            ]
            
            return logoMapping[matchingGame.opponent] ?? ""
        }
        
        // Fallback mapping for simplified names (if schedule lookup failed)
        let simplifiedMapping: [String: String] = [
            "Kansas City": "KansasCity",
            "San Francisco": "SanFrancisco",
            "Miami": "Miami",
            "Dallas": "Dallas",
            "Chicago": "Chicago",
            "Detroit": "Detroit",
            "Green Bay": "GreenBay",
            "Minnesota": "Minnesota",
            "New York": "NYN", // Default to Giants
            "Philadelphia": "Philadelphia",
            "Washington": "Washington",
            "Atlanta": "Atlanta",
            "Carolina": "Carolina",
            "New Orleans": "NewOrleans",
            "Tampa Bay": "TampaBay",
            "Arizona": "Arizona",
            "Los Angeles": "LAN", // Default to Rams
            "Seattle": "Seattle",
            "Baltimore": "Baltimore",
            "Cincinnati": "Cincinnati",
            "Cleveland": "Cleveland",
            "Pittsburgh": "Pittsburgh",
            "Buffalo": "Buffalo",
            "New England": "NewEngland",
            "Houston": "Houston",
            "Indianapolis": "Indianapolis",
            "Jacksonville": "Jacksonville",
            "Tennessee": "Tennessee",
            "Denver": "Denver",
            "Las Vegas": "LasVegas"
        ]
        
        return simplifiedMapping[opponent] ?? ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            scheduleHeader
            gridAllWeeks
        }
        .padding(.bottom, 28) // keep cards from stretching under the tab bar
        .sheet(item: $presentedGame) { game in
            GameDetailSheet(
                game: game,
                opponentLogoName: getOpponentLogoName(week: game.week, opponent: game.opponent),
                teamColor: team.primaryColor,
                userTeamLogoName: team.logoName
            )
            // Give the sheet more room by default to "fill out" the popup
            .presentationDetents([.fraction(0.8), .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private var scheduleHeader: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let primary = Color(hex: team.primaryColor)
        return HStack {
            Spacer(minLength: 0)
            Text("Season Schedule")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 1.5, x: 0, y: 1)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(alignment: .center) {
            // Light team color base + Liquid Glass overlay; same size as before
            shape
                .fill(primary)
                .brightness(0.18) // lighten the team color for a softer card tone
                .overlay(
                    shape
                        .fill(Color.clear)
                        .glassEffect(.regular.tint(primary).interactive(), in: shape)
                )
                .shadow(color: primary.opacity(0.35), radius: 12, x: 0, y: 8)
        }
        .clipShape(shape)
        .contentShape(shape)
    }
    
    private var gridAllWeeks: some View {
        GeometryReader { geo in
            // Three columns, sideways wide rounded rectangles
            // Increase cell height to give logos breathing room, compensate by reducing spacing
            let spacing: CGFloat = 10
            let cellH: CGFloat = 64
            let columns = Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: spacing), count: 3)
            GlassEffectContainer(spacing: spacing) {
                LazyVGrid(columns: columns, alignment: .center, spacing: spacing) {
                    ForEach(orderedGridGames, id: \.week) { game in
                    if game.opponent == "BYE" {
                        // BYE uses the same no-background layout as other weeks
                        ByeWeekGridCell(week: game.week)
                                .onTapGesture { presentedGame = game }
                        } else {
                            let logo = getOpponentLogoName(week: game.week, opponent: game.opponent)
                            let tint = Color(hex: TeamColorMapping.getColors(for: logo).primary)
                            GameGridCell(
                                game: game,
                                opponentLogoName: logo,
                                isHome: game.isHome,
                                tint: tint
                            )
                            .onTapGesture { presentedGame = game }
                        }
                    }
                }
            }
            .padding(.horizontal, 0)
            .frame(width: geo.size.width)
            .frame(height: (cellH * 6) + (spacing * 5)) // 6 rows visible, no scrolling
        }
        .frame(height: (64 * 6) + (7 * 5))
    }
}

// MARK: - Enhanced Game Row View
struct EnhancedGameRowView: View {
    let game: GameData
    let teamColor: String
    let opponentLogoName: String
    let isSelected: Bool
    let onTap: () -> Void
    
    // Cache opponent team colors to avoid repeated calculations
    private var opponentColors: TeamColorMapping.TeamColors {
        TeamColorMapping.getColors(for: opponentLogoName)
    }

    // Resolve a safe, visible tint color for the card background.
    // Prefers opponent secondary; falls back to opponent primary; if both are unusable (white/empty),
    // fall back to a light tint of the current team color so cards never look plain white.
    private var resolvedTint: Color {
        let secondaryHex = opponentColors.secondary.lowercased()
        let primaryHex = opponentColors.primary.lowercased()

        func isWhite(_ hex: String) -> Bool {
            return hex == "ffffff" || hex == "#ffffff" || hex == "fff"
        }
        func isEmpty(_ hex: String) -> Bool { hex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        // Choose base hex (now prefer PRIMARY; fall back to SECONDARY; then team color)
        let chosenHex: String
        if opponentLogoName.isEmpty {
            // Mapping failed; try primary first, then secondary
            if !isEmpty(primaryHex) && !isWhite(primaryHex) {
                chosenHex = primaryHex
            } else if !isEmpty(secondaryHex) && !isWhite(secondaryHex) {
                chosenHex = secondaryHex
            } else {
                chosenHex = teamColor
            }
        } else if !isEmpty(primaryHex) && !isWhite(primaryHex) {
            chosenHex = primaryHex
        } else if !isEmpty(secondaryHex) && !isWhite(secondaryHex) {
            chosenHex = secondaryHex
        } else {
            chosenHex = teamColor
        }

        // Build color; if we still ended on white for any reason, use team color instead
        if isWhite(chosenHex) {
            return Color(hex: teamColor)
        }
        return Color(hex: chosenHex)
    }

    // Resolve display text for opponent supporting custom names in future
    private func displayName(for game: GameData) -> String {
        game.opponent // today this is already the city; placeholder for future custom mapping
    }
    
    var body: some View {
        Button(action: onTap) {
            gameRowContent
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .drawingGroup() // Optimize rendering by flattening into single layer
    }
    
    private var gameRowContent: some View {
        VStack(spacing: 16) {
            gameHeader
            
            if isSelected {
                gameDetails
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(alignment: .center) {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            // Solid base tint (non‑pastel) so opponent color reads strongly under glass
            shape
                .fill(resolvedTint)
                .overlay(
                    shape
                        .fill(Color.clear)
                        .glassEffect(.regular.tint(resolvedTint).interactive(), in: shape)
                )
                .shadow(color: resolvedTint.opacity(0.25), radius: 8, x: 0, y: 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color(hex: teamColor).opacity(0.12), radius: 4, x: 0, y: 2)
    }
    
    private var gameHeader: some View {
        HStack(spacing: 16) {
            weekBadge
            
            // Opponent Logo
            if !opponentLogoName.isEmpty {
                Image(opponentLogoName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .compositingGroup() // keep single layer for perf; no shadows on image
            }
            
            gameInfo
            Spacer()
            homeAwayIndicator
        }
    }
    
    private var weekBadge: some View {
        Text("\(game.week)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.black)
            .frame(width: 32, height: 32)
            .background(Color.white, in: Circle())
    }
    
    private var gameInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayName(for: game))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            if game.isCompleted, let homeScore = game.homeScore, let awayScore = game.awayScore {
                // Show final score
                HStack(spacing: 8) {
                    if game.isHome {
                        Text("\(homeScore) - \(awayScore)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } else {
                        Text("\(awayScore) - \(homeScore)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("Final")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            } else {
                // Show date and time
                HStack(spacing: 8) {
                    Text(game.date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    
                    if !game.time.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text(game.time)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
        }
        .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1) // Single shadow for entire group
    }
    
    private var homeAwayIndicator: some View {
        VStack(spacing: 4) {
            Image(systemName: game.isHome ? "house.fill" : "airplane")
                .font(.title3)
                .foregroundColor(.white)
            
            Text(game.isHome ? "HOME" : "AWAY")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
        }
        .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1) // Single shadow for entire group
    }
    
    private var gameDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(.white.opacity(0.3))
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 16) {
                        DetailItem(icon: "calendar", text: game.date)
                        
                        if !game.time.isEmpty {
                            DetailItem(icon: "clock", text: game.time)
                        }
                        
                        DetailItem(
                            icon: game.isHome ? "house.fill" : "airplane",
                            text: game.isHome ? "Home Game" : "Away Game"
                        )
                    }
                }
                
                Spacer()
            }
        }
        .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1) // Single shadow for entire details section
    }
}

// MARK: - Compact Grid Cell (No-scroll schedule)
private struct GameGridCell: View {
    let game: GameData
    let opponentLogoName: String
    let isHome: Bool
    var tint: Color? = nil

    // Compute perceived luminance from a hex for contrast decisions
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
            let base = cleaned.count == 8 ? int & 0x00FFFFFF : int
            r = Double((base >> 16) & 0xFF) / 255.0
            g = Double((base >> 8) & 0xFF) / 255.0
            b = Double(base & 0xFF) / 255.0
        default:
            r = 1; g = 1; b = 1
        }
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    
    var body: some View {
        // No background bubble — content only (as in the reference screenshot)
        HStack(spacing: 8) {
            // Roman numeral above the logo row; no overlap
            VStack(spacing: 2) {
                Text(roman(game.week))
                    .font(.footnote)
                    .fontWeight(.heavy)
                    .foregroundColor(.primary)
                    .padding(.top, 1) // lower slightly toward center

                HStack(spacing: 6) {
                    Text(isHome ? "V" : "@")
                        .font(.callout)
                        .fontWeight(.heavy)
                        .foregroundColor(.primary)
                    if !opponentLogoName.isEmpty {
                        Image(opponentLogoName)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .fixedSize(horizontal: false, vertical: false)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .offset(y: -1) // raise logo a touch for visual center
                            .padding(2)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8) // slightly tighter cell for fewer overdraws
        .contentShape(Rectangle()) // ensure hit test area is full pill
        .frame(height: 60)
    }
}

private struct ByeWeekGridCell: View {
    let week: Int
    
    var body: some View {
        HStack(spacing: 8) {
            // Mirror regular cell layout: roman above, centered row content below
            VStack(spacing: 2) {
                Text(roman(week))
                    .font(.footnote)
                    .fontWeight(.heavy)
                    .foregroundColor(.primary)
                    .padding(.top, 1)

                HStack(spacing: 6) {
                    // No V/@ for BYE — just a centered BYE label acting like a logo
                    Text("BYE")
                        .font(.title3) // bigger for visual parity with logos
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(height: 40) // match logo row height
                        .offset(y: -1)     // match logo visual centering tweak
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .frame(height: 60)
        .background(Color.clear)
        .clipped(antialiased: false)
    }
}

// MARK: - Roman numerals for week badges
@inline(__always)
private func roman(_ n: Int) -> String {
    // Works for 1..3999, our use is 1..18
    let values = [1000,900,500,400,100,90,50,40,10,9,5,4,1]
    let numerals = ["M","CM","D","CD","C","XC","L","XL","X","IX","V","IV","I"]
    var num = max(1, min(3999, n))
    var result = ""
    for (v, s) in zip(values, numerals) {
        while num >= v { result += s; num -= v }
        if num == 0 { break }
    }
    return result
}

// MARK: - Game Detail Half‑Sheet
private struct GameDetailSheet: View {
    let game: GameData
    let opponentLogoName: String
    let teamColor: String
    let userTeamLogoName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Centered title (no logo), with Roman numeral week underneath
            VStack(spacing: 4) {
                Text(game.opponent)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Text("Week \(roman(game.week))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            
            Divider()
            
            // Center the time and home/away under the header; omit week here
            VStack(spacing: 6) {
                if !game.time.isEmpty {
                    Label(game.time, systemImage: "clock")
                }
                Label(game.isHome ? "Home" : "Away", systemImage: game.isHome ? "house.fill" : "airplane")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)

            // Opponent snapshot
            OpponentSnapshotView(opponentLogoName: opponentLogoName)

            // Your team snapshot (same look, placed underneath)
            UserTeamSnapshotView(teamLogoName: userTeamLogoName)
        }
        .padding(20)
    }
}

// MARK: - Opponent Snapshot (uses shared ratings calc so numbers match everywhere)
private struct OpponentSnapshotView: View {
    let opponentLogoName: String
    @State private var rating: (off: Int, def: Int, ovr: Int) = (0, 0, 0)
    @State private var topPlayers: [MasterPlayer] = []

    // Convert MasterPlayer[] → PlayerData[] to reuse the roster/selection calculation logic
    private func convertToPlayerData(_ players: [MasterPlayer]) -> [PlayerData] {
        players.map { p in
            PlayerData(
                firstName: p.firstName,
                lastName: p.lastName,
                position: p.position,
                number: Int(p.jerseyNum) ?? 1,
                overall: p.overallInt,
                age: p.ageInt
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 14) {
                if !opponentLogoName.isEmpty {
                    Image(opponentLogoName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 52, height: 52)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Opponent Snapshot")
                        .font(.headline)
                    HStack(spacing: 10) {
                        RatingBadge(label: "OFF", value: rating.off)
                        RatingBadge(label: "DEF", value: rating.def)
                        RatingBadge(label: "OVR", value: rating.ovr)
                    }
                }
                Spacer()
            }

            // Rating bars (bigger)
            VStack(spacing: 10) {
                RatingBarRow(label: "Offense", system: "bolt.fill", value: rating.off)
                RatingBarRow(label: "Defense", system: "shield.fill", value: rating.def)
                RatingBarRow(label: "Overall", system: "star.fill", value: rating.ovr)
            }

            // Top players
            if !topPlayers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Players")
                        .font(.subheadline).fontWeight(.semibold)
                    HStack(spacing: 12) {
                        ForEach(topPlayers, id: \._idCompat) { p in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.fullName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                Text("\(p.position) • \(p.overallInt)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            } else {
                Text("No opponent data available yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(
            // Use Liquid Glass on the card background (never on images)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task {
            // Pull players from master data (fast if cached), convert to PlayerData,
            // then use the shared TeamRatingsCalculator so it matches roster view values.
            let cached = MasterDataLoader.shared.getPlayers(for: opponentLogoName)
            let source = !cached.isEmpty ? cached : await MasterDataLoader.shared.getPlayersAsync(for: opponentLogoName)
            topPlayers = Array(source.sorted { $0.overallInt > $1.overallInt }.prefix(3))

            let playerData = convertToPlayerData(source)
            let calc = TeamRatingsCalculator.calculateTeamOveralls(for: opponentLogoName, players: playerData)
            rating = (calc.offense, calc.defense, calc.overall)

        }
    }
}

// Larger progress / meter row for ratings (0-99)
private struct RatingBarRow: View {
    let label: String
    let system: String
    let value: Int
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: system)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 18)
            Text(label)
                .font(.subheadline)
                .frame(width: 70, alignment: .leading)
            ProgressView(value: Double(max(0, min(100, value))), total: 100)
                .tint(.blue)
                .frame(maxWidth: .infinity)
            Text("\(value)")
                .font(.subheadline).fontWeight(.semibold)
                .frame(width: 34, alignment: .trailing)
        }
    }
}

// Mirror snapshot for the user's team using the same layout
private struct UserTeamSnapshotView: View {
    let teamLogoName: String
    @State private var rating: (off: Int, def: Int, ovr: Int) = (0, 0, 0)
    @State private var topPlayers: [MasterPlayer] = []

    private func convertToPlayerData(_ players: [MasterPlayer]) -> [PlayerData] {
        players.map { p in
            PlayerData(
                firstName: p.firstName,
                lastName: p.lastName,
                position: p.position,
                number: Int(p.jerseyNum) ?? 1,
                overall: p.overallInt,
                age: p.ageInt
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                if !teamLogoName.isEmpty {
                    Image(teamLogoName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 52, height: 52)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Team Snapshot")
                        .font(.headline)
                    HStack(spacing: 10) {
                        RatingBadge(label: "OFF", value: rating.off)
                        RatingBadge(label: "DEF", value: rating.def)
                        RatingBadge(label: "OVR", value: rating.ovr)
                    }
                }
                Spacer()
            }

            VStack(spacing: 10) {
                RatingBarRow(label: "Offense", system: "bolt.fill", value: rating.off)
                RatingBarRow(label: "Defense", system: "shield.fill", value: rating.def)
                RatingBarRow(label: "Overall", system: "star.fill", value: rating.ovr)
            }

            if !topPlayers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Players")
                        .font(.subheadline).fontWeight(.semibold)
                    HStack(spacing: 12) {
                        ForEach(topPlayers, id: \._idCompat) { p in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.fullName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                Text("\(p.position) • \(p.overallInt)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            } else {
                Text("No team data available yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task {
            let cached = MasterDataLoader.shared.getPlayers(for: teamLogoName)
            let source = !cached.isEmpty ? cached : await MasterDataLoader.shared.getPlayersAsync(for: teamLogoName)
            topPlayers = Array(source.sorted { $0.overallInt > $1.overallInt }.prefix(3))

            let playerData = convertToPlayerData(source)
            let calc = TeamRatingsCalculator.calculateTeamOveralls(for: teamLogoName, players: playerData)
            rating = (calc.offense, calc.defense, calc.overall)
        }
    }
}

private struct RatingBadge: View {
    let label: String
    let value: Int
    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text("\(value)").font(.subheadline).fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(.systemBackground)))
    }
}

// Small helpers
private extension Array where Element == Int {
    func averageRounded() -> Int { guard !isEmpty else { return 0 }; return Int((reduce(0, +) * 100) / count) / 100 }
}
private extension MasterPlayer {
    var _idCompat: String { id }
}
// MARK: - Bye Week Row View
struct ByeWeekRowView: View {
    let week: Int
    let teamColor: String
    
    var body: some View {
        HStack(spacing: 16) {
            weekBadge
            byeInfo
            Spacer()
            restIcon
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(alignment: .center) {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            // Clear glass pill like unpressable buttons (no strong tint, subtle material)
            shape
                .fill(Color.clear)
                .overlay(
                    shape
                        .fill(Color.clear)
                        .glassEffect(.regular, in: shape)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var weekBadge: some View {
        Text("\(week)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.black)
            .frame(width: 32, height: 32)
            .background(Color.white, in: Circle())
    }
    
    private var byeInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bye Week")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("No game scheduled")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var restIcon: some View {
        VStack(spacing: 4) {
            Image(systemName: "bed.double.fill")
                .font(.title3)
                .foregroundColor(.primary)
            
            Text("REST")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Detail Item Helper
struct DetailItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
        }
        // Shadow is now applied at the parent level for better performance
    }
 
} 