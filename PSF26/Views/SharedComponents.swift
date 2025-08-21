import SwiftUI
import Combine

// MARK: - Reusable View Modifiers

// MARK: - Team UI Color Resolver (shared by headers and buttons)
struct TeamUIResolver {
    // Explicit banner preference map (logoName keys)
    // light -> prefer secondary; dark -> prefer primary
    static let lightTeams: Set<String> = [
        "Chicago", "Seattle", "Miami", "Houston", "Tennessee", "LAA"
    ]
    static let darkTeams: Set<String> = [
        "Detroit", "GreenBay", "Minnesota", "Dallas", "NYN", "Philadelphia",
        "Washington", "TampaBay", "Arizona", "LAN", "SanFrancisco", "Buffalo",
        "NewEngland", "NYA", "Cleveland", "Indianapolis", "Jacksonville",
        "KansasCity", "LasVegas", // swaps moved here per Jay
        "Atlanta", "Carolina", "NewOrleans", "Baltimore", "Cincinnati", "Pittsburgh", "Denver"
    ]

    static func bannerHex(for logoName: String) -> String {
        let colors = TeamColorMapping.getColors(for: logoName)
        let primaryHex = colors.primary
        let secondaryHex = colors.secondary

        if lightTeams.contains(logoName) {
            if !secondaryHex.trimmingCharacters(in: .whitespaces).isEmpty { return secondaryHex }
        } else if darkTeams.contains(logoName) {
            if !primaryHex.trimmingCharacters(in: .whitespaces).isEmpty { return primaryHex }
        }

        // Fallback to lighter of the two by luminance
        let lp = luminance(hex: primaryHex)
        let ls = luminance(hex: secondaryHex)
        return ls >= lp ? secondaryHex : primaryHex
    }

    private static func luminance(hex: String) -> Double {
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
}

struct GameCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .roundedBackground(Color.blue.opacity(0.1), radius: Corner.large)
            .shadow(radius: 5)
    }
}

struct TeamGradientButtonStyle: ViewModifier {
    let teamName: String
    let shadowColor: Color
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: TeamColorMapping.getColors(for: teamName).primary),
                        Color(hex: TeamColorMapping.getColors(for: teamName).secondary)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .continuousClip(Corner.large)
            .shadow(color: shadowColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct LeagueGradientButtonStyle: ViewModifier {
    let colors: [Color]
    let shadowColor: Color
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .continuousClip(Corner.large)
            .shadow(color: shadowColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - iOS 26 Compatibility Layer

struct LiquidGlassBackground: ViewModifier {
    let style: LiquidGlassStyle
    
    enum LiquidGlassStyle {
        case subtle, prominent, background
    }
    
    func body(content: Content) -> some View {
        content
            .background {
                if #available(iOS 26.0, *) {
                    // Future iOS 26 Liquid Glass implementation
                    Color.clear.background(.ultraThinMaterial)
                } else {
                    // Fallback for current iOS versions
                    switch style {
                    case .subtle:
                        Color.clear.background(.ultraThinMaterial)
                    case .prominent:
                        Color.clear.background(.regularMaterial)
                    case .background:
                        Color.clear.background(.thickMaterial)
                    }
                }
            }
    }
}

// MARK: - Subtle Present/Dismiss Wrapper
/// Minimal fade/scale wrapper to soften full-screen transitions without feeling "animated".
struct FadeInPresenting<Content: View>: View {
    enum Style { case soft, softer }
    let style: Style
    @ViewBuilder let content: () -> Content
    @State private var appear = false
    
    var body: some View {
        content()
            .opacity(appear ? 1 : 0)
            .scaleEffect(appear ? 1.0 : (style == .soft ? 0.985 : 0.99))
            .animation(.easeOut(duration: style == .soft ? 0.18 : 0.14), value: appear)
            .onAppear { appear = true }
    }
}

// MARK: - Reusable Components

struct TeamLogoView: View {
    let teamLogoName: String
    let customLogoData: Data?
    let size: CGFloat
    
    init(teamLogoName: String, customLogoData: Data? = nil, size: CGFloat = 80) {
        self.teamLogoName = teamLogoName
        self.customLogoData = customLogoData
        self.size = size
    }
    
    var body: some View {
        Group {
            if let customLogoData = customLogoData,
               let uiImage = UIImage(data: customLogoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(teamLogoName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct TeamHeaderCard: View {
    let teamName: String
    let teamLogoName: String
    let customLogoData: Data?
    let record: (wins: Int, losses: Int, ties: Int)
    let currentWeek: Int
    
    var body: some View {
        HStack {
            TeamLogoView(
                teamLogoName: teamLogoName,
                customLogoData: customLogoData,
                size: 80
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text(teamName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(formatRecord(record))
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                
                if currentWeek > 0 {
                    Text("Week \(currentWeek)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
        }
        .padding()
        .background(headerBackground)
        .continuousClip(Corner.large)
    }
    
    private func formatRecord(_ record: (wins: Int, losses: Int, ties: Int)) -> String {
        if record.ties > 0 {
            return "\(record.wins)-\(record.losses)-\(record.ties)"
        } else {
            return "\(record.wins)-\(record.losses)"
        }
    }
}

extension TeamHeaderCard {
    @ViewBuilder
    private var headerBackground: some View {
        let bannerHex = TeamUIResolver.bannerHex(for: teamLogoName)
        let color = Color(hex: bannerHex)
        RoundedRectangle(cornerRadius: Corner.large, style: .continuous)
            .fill(color)
            .overlay(
                RoundedRectangle(cornerRadius: Corner.large, style: .continuous)
                    .fill(color.opacity(0.10))
                    .blendMode(.multiply)
            )
            .saturation(1.12)
    }
}

struct ActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    let style: ButtonStyleType
    
    enum ButtonStyleType {
        case team(String)        // teamLogoName
        case league(Color)       // flat league tint
    }
    
    var body: some View {
        Button(action: action) {
            buttonModifier
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var buttonModifier: some View {
        switch style {
        case .team(let teamName):
            let banner = TeamUIResolver.bannerHex(for: teamName)
            TeamGlassButton(
                title: title,
                background: Color(hex: banner),
                textColor: .white,
                height: 56,
                corner: Corner.large,
                action: action
            )
        case .league(let tint):
            TeamGlassButton(
                title: title,
                background: tint,
                textColor: .white,
                height: 56,
                corner: Corner.large,
                action: action
            )
        }
    }
}

struct SectionHeaderView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

// MARK: - Performance Optimized List Components

struct OptimizedListRow<Content: View>: View {
    let id: String
    let content: Content
    
    init(id: String, @ViewBuilder content: () -> Content) {
        self.id = id
        self.content = content()
    }
    
    var body: some View {
        content
            .id(id) // Helps SwiftUI optimize updates
    }
}

// MARK: - Hub Roster Inline Section (positions-only chips on Hub Team Roster view)
struct HubRosterInlineSection: View {
    let teamData: TeamData
    let leagueId: UUID?
    @State private var selectedPosition: String = "Overview"

    var body: some View {
        VStack(spacing: 12) {
            RosterManagementView(
                team: .constant(teamData),
                selectedPosition: $selectedPosition,
                leagueId: leagueId,
                includeAllChip: false,
                unitFilterMode: false,
                showSalaryInCells: false,
                embedInScrollView: true
            )
        }
    }
}

// MARK: - View Extensions

extension View {
    func gameCardStyle() -> some View {
        modifier(GameCardStyle())
    }
    
    func teamGradientButton(teamName: String) -> some View {
        modifier(TeamGradientButtonStyle(
            teamName: teamName,
            shadowColor: Color(hex: TeamColorMapping.getColors(for: teamName).primary)
        ))
    }
    
    func leagueGradientButton(colors: [Color], shadowColor: Color) -> some View {
        modifier(LeagueGradientButtonStyle(colors: colors, shadowColor: shadowColor))
    }
    
    func liquidGlass(_ style: LiquidGlassBackground.LiquidGlassStyle = .subtle) -> some View {
        modifier(LiquidGlassBackground(style: style))
    }
    
    // New convenience methods for standard cards
    func standardCard(_ style: StandardCard<Self>.CardStyle = .ultraThin16) -> some View {
        StandardCard(style: style) { self }
    }
    
    func teamColorCard(teamColor: String, cornerRadius: CGFloat = 12) -> some View {
        TeamColorCard(teamColor: teamColor, cornerRadius: cornerRadius) { self }
    }
    
    // Performance optimization for lists
    func optimizedListItem() -> some View {
        self
            .id(UUID()) // Provide stable identity for list performance
    }
}

// MARK: - iOS 26 Tab Bar Enhancements

struct iOS26TabBarEnhancements: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Configure iOS 26 Liquid Glass tab bar appearance
                let appearance = UITabBarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.backgroundColor = UIColor.clear
                
                // Apply enhanced appearance for iOS 26 compatibility
                if #available(iOS 26.0, *) {
                    // Future iOS 26 Liquid Glass implementation
                    UITabBar.appearance().standardAppearance = appearance
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                    UITabBar.appearance().isTranslucent = true
                } else {
                    // Enhanced fallback for current iOS versions
                    UITabBar.appearance().standardAppearance = appearance
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                    UITabBar.appearance().isTranslucent = true
                }
            }
    }
}

// MARK: - Performance Optimization Helpers

class StateContainer: ObservableObject {
    // Group related @State variables to reduce view invalidation
    @Published var gameState = GameStateData()
    @Published var uiState = UIStateData()
    
    struct GameStateData {
        var opponentName = "Season Setup"
        var opponentLogoName = ""
        var opponentRecord = (wins: 0, losses: 0, ties: 0)
        var isHomeGame = true
        var currentWeek = 0
    }
    
    struct UIStateData {
        var selectedTab: LeagueTab = .hub
        var isSimulating = false
        var simulationProgress = 0.0
        var showingAlerts = AlertStateData()
    }
    
    struct AlertStateData {
        var showingTeamSchedule = false
        var showingLeagueSchedule = false
        var showingLeagueStandings = false
        var showingCoachInfo = false
        var showingAllCoaches = false
        var showingSaveAlert = false
        var saveAlertMessage = ""
        var showingExitConfirmation = false
    }
    
    enum LeagueTab: String, CaseIterable {
        case team = "Team"
        case league = "League"
        case hub = "Hub"
        case history = "History"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .team: return "person.3.fill"
            case .league: return "chart.bar.fill"
            case .hub: return "house.fill"
            case .history: return "book.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
}

// MARK: - Standard Card Components

struct StandardCard<Content: View>: View {
    let content: Content
    let style: CardStyle
    
    enum CardStyle {
        case ultraThin16    // .ultraThinMaterial, cornerRadius: 16
        case ultraThin12    // .ultraThinMaterial, cornerRadius: 12
        case regular10      // .regularMaterial, cornerRadius: 10
        case systemGray12   // .systemGray6, cornerRadius: 12
        case custom(Material, CGFloat)
    }
    
    init(style: CardStyle = .ultraThin16, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }
    
    var body: some View {
        content
            .background(backgroundMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
    }
    
    private var backgroundMaterial: Material {
        switch style {
        case .ultraThin16, .ultraThin12:
            return .ultraThinMaterial
        case .regular10:
            return .regularMaterial
        case .systemGray12:
            return .ultraThinMaterial // Material palette remains; keep consistent depth
        case .custom(let material, _):
            return material
        }
    }
    
    private var cornerRadius: CGFloat {
        switch style {
        case .ultraThin16:
            return Corner.large
        case .ultraThin12, .systemGray12:
            return Corner.medium
        case .regular10:
            return 10
        case .custom(_, let radius):
            return radius
        }
    }
}

struct TeamColorCard<Content: View>: View {
    let content: Content
    let teamColor: String
    let cornerRadius: CGFloat
    
    init(teamColor: String, cornerRadius: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.teamColor = teamColor
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Color(hex: teamColor), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let style: CardStyle
    
    enum CardStyle {
        case standard
        case highlighted(Color)
        case team(String) // team color
    }
    
    init(title: String, value: String, subtitle: String? = nil, style: CardStyle = .standard) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(textColor)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(backgroundView)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .standard:
            StandardCard(style: .ultraThin12) { Color.clear }
        case .highlighted(let color):
            RoundedRectangle(cornerRadius: Corner.medium, style: .continuous)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: Corner.medium, style: .continuous)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        case .team(let teamColor):
            TeamColorCard(teamColor: teamColor) { Color.clear }
        }
    }
    
    private var textColor: Color {
        switch style {
        case .standard:
            return .primary
        case .highlighted(let color):
            return color
        case .team(_):
            return .white
        }
    }
}

// MARK: - List Performance Components

struct OptimizedPlayerRow: View, Equatable {
    let player: PlayerRowData
    let teamColor: String
    let teamLogoName: String?
    let leagueId: UUID?
    let onPlayerUpdated: (() -> Void)?
    @StateObject private var detailViewState = PlayerDetailViewStateManager.shared
    @State private var showingPlayerDetail = false
    @State private var showingEditMode = false
    @State private var editablePlayer: EditablePlayerData?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    struct PlayerRowData: Equatable {
        let id: String
        let name: String
        let position: String
        let number: Int
        let overall: Int
        let age: Int
        
        var firstName: String {
            let components = name.components(separatedBy: " ")
            return components.first ?? ""
        }
        
        var lastName: String {
            let components = name.components(separatedBy: " ")
            return components.count > 1 ? components.dropFirst().joined(separator: " ") : ""
        }
        
        var playerData: PlayerData {
            PlayerData(
                firstName: firstName,
                lastName: lastName,
                position: position,
                number: number,
                overall: overall,
                age: age
            )
        }
        
        static func == (lhs: PlayerRowData, rhs: PlayerRowData) -> Bool {
            lhs.id == rhs.id && lhs.overall == rhs.overall && lhs.age == rhs.age && lhs.name == rhs.name
        }
    }
    
    static func == (lhs: OptimizedPlayerRow, rhs: OptimizedPlayerRow) -> Bool {
        lhs.player.id == rhs.player.id
    }
    
    var body: some View {
        NavigationLink {
            PlayerDetailView(
                player: player.playerData,
                teamLogoName: teamLogoName ?? "",
                leagueId: leagueId,
                isEditable: leagueId != nil,
                leagueManager: nil
            )
        } label: {
            HStack(spacing: 12) {
                // Position Badge
                Text(player.position)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 20)
                    .background(Color(hex: teamColor), in: RoundedRectangle(cornerRadius: 4))
                
                // Player Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("#\(player.number) • Age \(player.age)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Overall Rating
                Text("\(player.overall)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(overallColor)
                
                // Navigation indicator (only show if tappable)
                if teamLogoName != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .disabled(teamLogoName == nil)
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private var overallColor: Color {
        // Use consistent red-to-green gradient based on rating
        let normalizedRating = max(0.0, min(1.0, Double(player.overall - 60) / 35.0))
        
        // Interpolate between red and green
        let red = 1.0 - normalizedRating
        let green = normalizedRating
        
        return Color(red: red, green: green, blue: 0.0)
    }
}

// MARK: - Specialized Button Components

struct GameActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    let color: Color
    let isDisabled: Bool
    
    init(title: String, systemImage: String, color: Color, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color, in: RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isDisabled)
    }
}

struct PrimaryGameButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.blue, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - iOS 26: Tint-only Glass Button (no gradient)

struct TeamTintGlassButton: View {
    let title: String
    let dark: Color         // team primary (darker)
    let light: Color        // team light (often white or secondary)
    let height: CGFloat
    let corner: CGFloat
    let action: () -> Void
    var disabled: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(light)
                .shadow(color: .black.opacity(0.65), radius: 2.0, x: 0, y: 1.3)
                .frame(maxWidth: .infinity, minHeight: height)
        }
        .glassEffect(.regular.tint(dark).interactive(), in: shape)
        .clipShape(shape)
        .contentShape(shape)
        .compositingGroup()
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 10)
        .overlay(
            Group {
                if disabled {
                    shape
                        .fill(Color.black.opacity(0.12))
                        .overlay(
                            shape.stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                }
            }
        )
        .hoverEffect(.lift)
        .disabled(disabled)
        .saturation(disabled ? 0.12 : 1.0)
        .opacity(disabled ? 0.55 : 1.0)
    }
}

// MARK: - Generic Team Glass Button (explicit bg/text colors)

struct TeamGlassButton: View {
    let title: String
    let background: Color
    let textColor: Color
    let height: CGFloat
    let corner: CGFloat
    let action: () -> Void
    var disabled: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textColor)
                // Strong dark shadow to keep white text readable on bright team colors
                .shadow(color: .black.opacity(0.65), radius: 2.0, x: 0, y: 1.3)
                .frame(maxWidth: .infinity, minHeight: height)
        }
        .glassEffect(.regular.tint(background).interactive(), in: shape)
        .clipShape(shape)
        .contentShape(shape)
        .compositingGroup()
        .shadow(color: background.opacity(0.32), radius: 18, x: 0, y: 12)
        .overlay(
            Group {
                if disabled {
                    shape
                        .fill(Color.black.opacity(0.12))
                        .overlay(
                            shape.stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                }
            }
        )
        .hoverEffect(.lift)
        .disabled(disabled)
        .saturation(disabled ? 0.12 : 1.0)
        .opacity(disabled ? 0.55 : 1.0)
    }
}

// MARK: - Standard team button convenience

struct StandardTeamGlassButton: View {
    let title: String
    let teamLogoName: String
    let height: CGFloat
    let corner: CGFloat
    let action: () -> Void
    var disabled: Bool = false

    var body: some View {
        let banner = TeamUIResolver.bannerHex(for: teamLogoName)
        TeamGlassButton(
            title: title,
            background: Color(hex: banner), // match header banner color exactly
            textColor: .white,
            height: height,
            corner: corner,
            action: action,
            disabled: disabled
        )
    }
}

// MARK: - Non-interactive Glass Label (for use as Button label to avoid nested buttons)
struct TeamGlassLabel: View {
    let title: String
    let background: Color
    let textColor: Color
    let height: CGFloat
    let corner: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(textColor)
            .shadow(color: .black.opacity(0.65), radius: 2.0, x: 0, y: 1.3)
            .frame(maxWidth: .infinity, minHeight: height)
            .glassEffect(.regular.tint(background).interactive(), in: shape)
            .clipShape(shape)
            .contentShape(shape)
            .compositingGroup()
    }
}

extension View {
    func teamGlassButton(
        _ title: String,
        teamLogoName: String,
        height: CGFloat = 48,
        corner: CGFloat = 12,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            StandardTeamGlassButton(
                title: title,
                teamLogoName: teamLogoName,
                height: height,
                corner: corner,
                action: action,
                disabled: disabled
            )
        }
    }
}

// MARK: - Common Color Palettes

struct ColorPalettes {
    static let leagueSchedule = [
        Color(red: 0.08, green: 0.09, blue: 0.16), // Dark navy blue
        Color(red: 0.52, green: 0.08, blue: 0.14)  // Dark red
    ]
    
    static let leagueStandings = [
        Color(red: 0.12, green: 0.15, blue: 0.25), // Dark blue-gray
        Color(red: 0.08, green: 0.12, blue: 0.20)  // Darker blue
    ]
    
    static let leagueCoaches = [
        Color(red: 0.15, green: 0.08, blue: 0.25), // Dark purple
        Color(red: 0.08, green: 0.15, blue: 0.20)  // Dark teal
    ]
} 

// MARK: - Lightweight Loading Overlay
struct LoadingOverlay: View {
    let title: String
    let subtitle: String?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Corner.large, style: .continuous))
        }
        .transition(.opacity)
    }
}