import SwiftUI
import Combine

struct TeamSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedConference: Conference?
    @State private var selectedTeam: String? = nil
    @Namespace private var teamMorphingNamespace
    @StateObject private var imageCache = ImageCache()
    
    enum Conference: String, CaseIterable {
        case nfc = "NFC"
        case afc = "AFC"
        
        var logoName: String {
            switch self {
            case .nfc: return "conferencelogo1"
            case .afc: return "conferencelogo2"
            }
        }
        
        var color: Color {
            switch self {
            case .nfc: return .blue
            case .afc: return .red
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Select Your Team")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 10)
                    
                    // Conference Selection
                    ConferenceSelectionView(selectedConference: $selectedConference)
                        .padding(.top, selectedConference == nil ? 80 : 0)
                    
                    // Team Grid (only show if conference is selected)
                    if let conference = selectedConference {
                        EnhancedTeamGridView(
                            conference: conference,
                            selectedTeam: $selectedTeam,
                            imageCache: imageCache,
                            namespace: teamMorphingNamespace
                        )
                        
                        // Continue Button (only show if team is selected)
                        if let selectedTeam = selectedTeam {
                            Button(action: {
                                print("Selected team: \(selectedTeam)")
                            }) {
                                ContinueButtonContent(selectedTeam: selectedTeam)
                            }
                            .padding(.top, 20)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Choose Conference")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear {
            let allTeams = NFLTeams.allTeams
            imageCache.preloadImages(for: allTeams)
        }
    }
}

// MARK: - Simple Conference Selection View (from reference)
struct ConferenceSelectionView: View {
    @Binding var selectedConference: TeamSelectionView.Conference?
    
    var body: some View {
        VStack(spacing: 20) {
            // Always show the logos, but animate their size, position, and opacity
            HStack(spacing: selectedConference == nil ? 40 : 35) {
                ForEach(TeamSelectionView.Conference.allCases, id: \.self) { conference in
                    Button(action: {
                        withAnimation(.spring(response: 0.9, dampingFraction: 0.8, blendDuration: 0)) {
                            selectedConference = conference
                        }
                    }) {
                        Image(conference.logoName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(
                                width: selectedConference == nil ? 120 : 85,
                                height: selectedConference == nil ? 120 : 85
                            )
                            .opacity(getLogoOpacity(for: conference))
                            .shadow(
                                color: .black.opacity(0.2), 
                                radius: selectedConference == nil ? 8 : 6, 
                                x: 0, 
                                y: selectedConference == nil ? 4 : 3
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .sensoryFeedback(.selection, trigger: selectedConference == conference)
                }
            }
            .padding(.horizontal, 30)
            .offset(y: selectedConference == nil ? 0 : -20) // Move up to center between texts
        }
    }
    
    private func getLogoOpacity(for conference: TeamSelectionView.Conference) -> Double {
        if selectedConference == nil {
            return 1.0 // Both logos fully visible when no selection
        } else {
            return selectedConference == conference ? 1.0 : 0.3 // Selected logo full, other faded
        }
    }
}

// MARK: - Image Cache for Performance
@MainActor
class ImageCache: ObservableObject {
    @Published private var cache: [String: UIImage] = [:]
    private let maxCacheSize = 50
    
    func getImage(for team: String) -> UIImage? {
        return cache[team]
    }
    
    func setImage(_ image: UIImage, for team: String) {
        if cache.count >= maxCacheSize {
            let keysToRemove = Array(cache.keys.prefix(10))
            keysToRemove.forEach { cache.removeValue(forKey: $0) }
        }
        cache[team] = image
    }
    
    func preloadImages(for teams: [String]) {
        Task {
            for team in teams {
                if cache[team] == nil {
                    if let image = UIImage(named: team) {
                        await MainActor.run {
                            cache[team] = image
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Team Grid View
struct EnhancedTeamGridView: View {
    let conference: TeamSelectionView.Conference
    @Binding var selectedTeam: String?
    @ObservedObject var imageCache: ImageCache
    let namespace: Namespace.ID
    
    private var divisions: [NFLDivision] {
        switch conference {
        case .nfc:
            return [
                NFLDivision(name: "NFC North", teams: ["Chicago", "Detroit", "GreenBay", "Minnesota"]),
                NFLDivision(name: "NFC East", teams: ["Dallas", "NYN", "Philadelphia", "Washington"]),
                NFLDivision(name: "NFC South", teams: ["Atlanta", "Carolina", "NewOrleans", "TampaBay"]),
                NFLDivision(name: "NFC West", teams: ["Arizona", "LAN", "SanFrancisco", "Seattle"])
            ]
        case .afc:
            return [
                NFLDivision(name: "AFC North", teams: ["Baltimore", "Cincinnati", "Cleveland", "Pittsburgh"]),
                NFLDivision(name: "AFC East", teams: ["Buffalo", "Miami", "NewEngland", "NYA"]),
                NFLDivision(name: "AFC South", teams: ["Houston", "Indianapolis", "Jacksonville", "Tennessee"]),
                NFLDivision(name: "AFC West", teams: ["Denver", "KansasCity", "LasVegas", "LAA"])
            ]
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("\(conference.rawValue) Teams")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 16) {
                ForEach(divisions.indices, id: \.self) { divisionIndex in
                    HStack(spacing: 16) {
                        ForEach(divisions[divisionIndex].teams, id: \.self) { team in
                            OptimizedTeamLogoButton(
                                team: team,
                                selectedTeam: $selectedTeam,
                                imageCache: imageCache,
                                namespace: namespace
                            )
                        }
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 50)
        }
        .scrollClipDisabled()
        .scrollTargetBehavior(.viewAligned)
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Optimized Team Logo Button
struct OptimizedTeamLogoButton: View {
    let team: String
    @Binding var selectedTeam: String?
    @ObservedObject var imageCache: ImageCache
    let namespace: Namespace.ID
    
    @State private var isPressed = false
    @State private var imageLoaded = false
    
    private var isSelected: Bool {
        selectedTeam == team
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedTeam = team
            }
        }) {
            Group {
                if let cachedImage = imageCache.getImage(for: team) {
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .opacity(imageLoaded ? 1.0 : 0.0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                imageLoaded = true
                            }
                        }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .frame(width: 64, height: 64)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(teamTintColor)
                        )
                }
            }
            .opacity(isSelected ? 1.0 : 0.4)
            .scaleEffect(isSelected ? 1.1 : (isPressed ? 0.95 : 1.0))
            .shadow(color: isSelected ? .black.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: isPressed)
        }
        .buttonStyle(.plain)
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
        .hoverEffect(.lift)
        .sensoryFeedback(.selection, trigger: isSelected)
        .task {
            if imageCache.getImage(for: team) == nil {
                if let image = UIImage(named: team) {
                    imageCache.setImage(image, for: team)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        imageLoaded = true
                    }
                }
            } else {
                imageLoaded = true
            }
        }
    }
    
    private var teamTintColor: Color {
        let colors = TeamColorMapping.getColors(for: team)
        return Color(hex: colors.primary)
    }
}

// MARK: - Press Events Modifier
struct PressEvents: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                if pressing {
                    onPress()
                } else {
                    onRelease()
                }
            }, perform: {})
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEvents(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - NFL Data Structures
struct NFLDivision {
    let name: String
    let teams: [String]
}

struct NFLTeams {
    static let allTeams = [
        // NFC
        "Chicago", "Detroit", "GreenBay", "Minnesota",
        "Dallas", "NYN", "Philadelphia", "Washington",
        "Atlanta", "Carolina", "NewOrleans", "TampaBay",
        "Arizona", "LAN", "SanFrancisco", "Seattle",
        // AFC
        "Baltimore", "Cincinnati", "Cleveland", "Pittsburgh",
        "Buffalo", "Miami", "NewEngland", "NYA",
        "Houston", "Indianapolis", "Jacksonville", "Tennessee",
        "Denver", "KansasCity", "LasVegas", "LAA"
    ]
}

// MARK: - Continue Button Content
struct ContinueButtonContent: View {
    let selectedTeam: String
    
    var body: some View {
        let teamColors = TeamColorMapping.getColors(for: selectedTeam)
        
        HStack(spacing: 12) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.title2)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                .symbolEffect(.bounce, value: selectedTeam)
            
            Text("Continue with \(getTeamDisplayName(selectedTeam))")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: teamColors.primary), location: 0.0),
                            .init(color: Color(hex: teamColors.secondary), location: 0.5),
                            .init(color: Color(hex: teamColors.secondary), location: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            Color.white.opacity(0.4),
                            lineWidth: 1.5
                        )
                )
                .shadow(
                    color: Color(hex: teamColors.primary).opacity(0.4),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal, 30)
        .hoverEffect(.lift)
        .sensoryFeedback(.selection, trigger: selectedTeam)
    }
    
    private func getTeamDisplayName(_ teamName: String) -> String {
        switch teamName {
        case "Chicago": return "Chicago"
        case "Detroit": return "Detroit"
        case "GreenBay": return "Green Bay"
        case "Minnesota": return "Minnesota"
        case "Dallas": return "Dallas"
        case "NYN": return "New York N"
        case "Philadelphia": return "Philadelphia"
        case "Washington": return "Washington"
        case "Atlanta": return "Atlanta"
        case "Carolina": return "Carolina"
        case "NewOrleans": return "New Orleans"
        case "TampaBay": return "Tampa Bay"
        case "Arizona": return "Arizona"
        case "LAN": return "Los Angeles N"
        case "SanFrancisco": return "San Francisco"
        case "Seattle": return "Seattle"
        case "Baltimore": return "Baltimore"
        case "Cincinnati": return "Cincinnati"
        case "Cleveland": return "Cleveland"
        case "Pittsburgh": return "Pittsburgh"
        case "Buffalo": return "Buffalo"
        case "Miami": return "Miami"
        case "NewEngland": return "New England"
        case "NYA": return "New York A"
        case "Houston": return "Houston"
        case "Indianapolis": return "Indianapolis"
        case "Jacksonville": return "Jacksonville"
        case "Tennessee": return "Tennessee"
        case "Denver": return "Denver"
        case "KansasCity": return "Kansas City"
        case "LasVegas": return "Las Vegas"
        case "LAA": return "Los Angeles A"
        default: return teamName
        }
    }
}

// MARK: - Team Color Mapping
struct TeamColorMapping {
    struct TeamColors {
        let primary: String
        let secondary: String
        let accent: String
    }
    
    static func getColors(for teamName: String) -> TeamColors {
        let normalizedName = teamName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch normalizedName {
        // NFC NORTH
        case "chicago":
            return TeamColors(primary: "#0B162A", secondary: "#C83803", accent: "#FFFFFF")
        case "detroit":
            return TeamColors(primary: "#0076B6", secondary: "#B0B7BC", accent: "#000000")
        case "greenbay":
            return TeamColors(primary: "#203731", secondary: "#FFB612", accent: "#FFFFFF")
        case "minnesota":
            return TeamColors(primary: "#4F2683", secondary: "#FFC62F", accent: "#FFFFFF")
            
        // NFC EAST
        case "dallas":
            return TeamColors(primary: "#003594", secondary: "#041E42", accent: "#869397")
        case "nyn":
            return TeamColors(primary: "#0B2265", secondary: "#A71930", accent: "#A5ACAF")
        case "philadelphia":
            return TeamColors(primary: "#004C54", secondary: "#A5ACAF", accent: "#ACC0C6")
        case "washington":
            return TeamColors(primary: "#5A1414", secondary: "#FFB612", accent: "#FFFFFF")
            
        // NFC SOUTH
        case "atlanta":
            return TeamColors(primary: "#A71930", secondary: "#000000", accent: "#A5ACAF")
        case "carolina":
            return TeamColors(primary: "#0085CA", secondary: "#101820", accent: "#BFC0BF")
        case "neworleans":
            return TeamColors(primary: "#D3BC8D", secondary: "#101820", accent: "#FFFFFF")
        case "tampabay":
            return TeamColors(primary: "#D50A0A", secondary: "#FF7900", accent: "#0A0A08")
            
        // NFC WEST
        case "arizona":
            return TeamColors(primary: "#97233F", secondary: "#000000", accent: "#FFB612")
        case "lan":
            return TeamColors(primary: "#003594", secondary: "#FFA300", accent: "#FFFFFF")
        case "sanfrancisco":
            return TeamColors(primary: "#AA0000", secondary: "#B3995D", accent: "#FFFFFF")
        case "seattle":
            return TeamColors(primary: "#002244", secondary: "#69BE28", accent: "#A5ACAF")
            
        // AFC NORTH
        case "baltimore":
            return TeamColors(primary: "#241773", secondary: "#000000", accent: "#9E7C0C")
        case "cincinnati":
            return TeamColors(primary: "#FB4F14", secondary: "#000000", accent: "#FFFFFF")
        case "cleveland":
            return TeamColors(primary: "#311D00", secondary: "#FF3C00", accent: "#FFFFFF")
        case "pittsburgh":
            return TeamColors(primary: "#FFB612", secondary: "#101820", accent: "#C60C30")
            
        // AFC EAST
        case "buffalo":
            return TeamColors(primary: "#00338D", secondary: "#C60C30", accent: "#FFFFFF")
        case "miami":
            return TeamColors(primary: "#008E97", secondary: "#FC4C02", accent: "#005778")
        case "newengland":
            return TeamColors(primary: "#002244", secondary: "#C60C30", accent: "#B0B7BC")
        case "nya":
            return TeamColors(primary: "#125740", secondary: "#FFFFFF", accent: "#000000")
            
        // AFC SOUTH
        case "houston":
            return TeamColors(primary: "#03202F", secondary: "#A71930", accent: "#FFFFFF")
        case "indianapolis":
            return TeamColors(primary: "#002C5F", secondary: "#A2AAAD", accent: "#FFFFFF")
        case "jacksonville":
            return TeamColors(primary: "#006778", secondary: "#9F792C", accent: "#101820")
        case "tennessee":
            return TeamColors(primary: "#0C2340", secondary: "#4B92DB", accent: "#C8102E")
            
        // AFC WEST
        case "denver":
            return TeamColors(primary: "#FB4F14", secondary: "#002244", accent: "#FFFFFF")
        case "kansascity":
            return TeamColors(primary: "#E31837", secondary: "#FFB81C", accent: "#FFFFFF")
        case "lasvegas":
            return TeamColors(primary: "#000000", secondary: "#A5ACAF", accent: "#FFFFFF")
        case "laa":
            return TeamColors(primary: "#0080C6", secondary: "#FFC20E", accent: "#FFFFFF")
            
        default:
            return TeamColors(primary: "#003065", secondary: "#FF001E", accent: "#FFFFFF")
        }
    }
}

// MARK: - Color Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    TeamSelectionView()
}
