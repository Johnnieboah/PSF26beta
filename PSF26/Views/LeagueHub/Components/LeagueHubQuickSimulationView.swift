import SwiftUI

// MARK: - LeagueHub Quick Simulation View
struct LeagueHubQuickSimulationView: View {
    let currentWeek: Int
    let opponentName: String
    let isReadyForPostseason: Bool
    let isSimulating: Bool
    let isAdvancingWeek: Bool
    let teamLogoName: String
    let onSimToNextWeek: () -> Void
    let onSimToMidSeason: () -> Void
    let onSimToPlayoffs: () -> Void
    
    var body: some View {
        let teamColors = TeamColorMapping.getColors(for: teamLogoName)
        
        return VStack(spacing: 16) {
            // Container title
            VStack(alignment: .leading, spacing: 8) {
                Text("Advance to…")
                    .font(.title2.weight(.bold))
                Text("Choose how far to simulate")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            
            // Regular Season Quick Sim Buttons
            if currentWeek < 19 {
                HStack(spacing: 16) {
                    // Sim to Next Week
                    quickSimButton(
                        title: "Next Week",
                        action: onSimToNextWeek,
                        isEnabled: currentWeek < 18 && opponentName != "Season Complete",
                        teamColors: teamColors
                    )
                    
                    // Sim to Mid-Season
                    quickSimButton(
                        title: "Midseason",
                        action: onSimToMidSeason,
                        isEnabled: currentWeek < 9 && opponentName != "Season Complete",
                        teamColors: teamColors
                    )
                }
                
                HStack(spacing: 16) {
                    // Sim to Playoffs
                    quickSimButton(
                        title: "Playoffs",
                        action: onSimToPlayoffs,
                        isEnabled: currentWeek < 18 && !isReadyForPostseason,
                        teamColors: teamColors
                    )
                    
                    // Sim to Offseason (disabled for now)
                    quickSimButton(
                        title: "Offseason",
                        action: { },
                        isEnabled: false,
                        teamColors: teamColors
                    )
                }
            }
        }
    }
    
    private func quickSimButton(title: String,
                                action: @escaping () -> Void,
                                isEnabled: Bool,
                                teamColors: TeamColorMapping.TeamColors,
                                isHighlighted: Bool = false) -> some View {
        // Use light team color as background with dark text (inverse of Play Game)
        let light = Color(hex: teamColors.secondary)
        // Removed unused variable 'dark' to silence warning

        // Force white text everywhere per request; retain strong dark shadow in component
        return TeamGlassButton(
            title: title,
            background: isEnabled ? light : Color.gray.opacity(0.35),
            textColor: .white,
            height: isHighlighted ? 58 : 54,
            corner: Corner.medium,
            action: action,
            disabled: (!isEnabled || isSimulating || isAdvancingWeek)
        )
    }
} 