import SwiftUI

// MARK: - LeagueHub Action Buttons View
struct LeagueHubActionButtonsView: View {
    let currentLeague: ObservableLeague
    let leagueManager: LeagueManager
    let currentWeek: Int
    let opponentName: String
    let userGameCompleted: Bool
    let isSimulating: Bool
    let isAdvancingWeek: Bool
    let isProcessingOffseason: Bool
    let isReadyForPostseason: Bool
    let onMainActionButtonPressed: () -> Void
    let onAdvanceToOffseason: () -> Void
    @State private var showGateAlert: Bool = false
    @State private var gateAlertMessage: String = ""
    
    var body: some View {
        let teamColors = TeamColorMapping.getColors(for: currentLeague.teamLogoName)
        
        return VStack(spacing: 24) {
            // Main action button
            // iOS 26: flat color + glass, no gradient
            TeamGlassButton(
                title: getMainActionButtonText(),
                background: Color(hex: teamColors.primary),
                textColor: .white,
                height: 56,
                corner: Corner.large,
                action: handleMainActionPressed,
                // Keep other gates (sim/advance/training-camp), but allow tap to show alert for roster/cap
                disabled: (isSimulating || isAdvancingWeek || !canAdvanceFromTrainingCamp())
            )
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)
            
            // Offseason button (only show when season is truly complete)
            if opponentName == "Season Complete" && currentWeek >= 22 {
                TeamGlassButton(
                    title: isProcessingOffseason ? "Processing..." : "Advance to Offseason",
                    background: .green,
                    textColor: .white,
                    height: 50,
                    corner: Corner.medium,
                    action: onAdvanceToOffseason,
                    disabled: (isSimulating || isAdvancingWeek || isProcessingOffseason)
                )
                .padding(.horizontal, 24)
                .frame(maxWidth: 560)
            }
        }
        .alert("Cannot Advance", isPresented: $showGateAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(gateAlertMessage)
        })
    }
    
    // MARK: - Helper Functions
    private func getMainActionButtonText() -> String {
        // Check training camp requirements first
        if currentLeague.isInTrainingCamp && !canAdvanceFromTrainingCamp() {
            guard let userTeam = leagueManager.userTeam else { return "Start Season" }
            
            if userTeam.players.count > 65 {
                return "Cut to 65 Players First"
            } else if userTeam.capSpace <= 0 {
                return "Reduce Roster to 65 or fewer"
            } else {
                return "Complete Training Camp"
            }
        }
        // Gate by 53-man + cap ≥ -$5M
        if !userTeamMeets53AndCap() { return "Fix Roster/Cap First" }
        
        if currentWeek == 0 {
            return "Start Season"
        } else if opponentName == "Advance to Post-Season" {
            return "Advance to Post-Season"
        } else if currentWeek >= 19 {
            // Playoff stage - Check elimination status first
            if opponentName == "Eliminated - Watching Playoffs" {
                if currentWeek >= 22 {
                    return "Season Complete"
                } else {
                    return "Advance to \(currentWeek == 19 ? "Divisional Round" : currentWeek == 20 ? "Conference Championship" : "League Championship")"
                }
            }
            
            // Handle other playoff scenarios
            if currentWeek == 22 {
                // League Championship week
                if opponentName == "Season Complete" {
                    return "Season Complete"
                } else if userGameCompleted {
                    return "Season Complete"
                } else {
                    return "Play League Championship Game"
                }
            } else if currentWeek == 21 {
                // Conference Championship week
                if userGameCompleted {
                    return "Advance to League Championship"
                } else {
                    return "Play Conference Championship Game"
                }
            } else if currentWeek == 20 {
                // Divisional week
                if userGameCompleted {
                    return "Advance to Conference Championship"
                } else {
                    return "Play Divisional Game"
                }
            } else {
                // Wild Card week
                if opponentName == "First Round Bye" {
                    return "Advance to Divisional Round"
                } else if userGameCompleted {
                    return "Advance to Divisional Round"
                } else {
                    return "Play Wild Card Game"
                }
            }
        } else if userGameCompleted {
            return "Advance Week"
        } else if opponentName == "BYE" {
            return "Simulate Week"
        } else {
            return "Play Game"
        }
    }
    
    private func canAdvanceFromTrainingCamp() -> Bool {
        return LeagueHubHelpers.canAdvanceFromTrainingCamp(currentLeague: currentLeague, leagueManager: leagueManager)
    }

    private func userTeamMeets53AndCap() -> Bool {
        guard let user = leagueManager.userTeam else { return false }
        let meetsCount = user.players.count == 53
        let meetsCap = (NFLCapData.salaryCap - user.totalSalarySpending) >= -5_000_000
        return meetsCount && meetsCap
    }

    private func handleMainActionPressed() {
        // If user fails 53/cap rule, show blocking alert instead of performing the action
        if !userTeamMeets53AndCap() {
            guard let user = leagueManager.userTeam else { return }
            let count = user.players.count
            let capSpace = NFLCapData.salaryCap - user.totalSalarySpending
            var reasons: [String] = []
            if count != 53 {
                reasons.append("Roster must be exactly 53 players (current: \(count)).")
            }
            if capSpace < -5_000_000 {
                reasons.append("Cap must be at least -$5M (current: \(formatCapSpace(capSpace))).")
            }
            gateAlertMessage = reasons.joined(separator: "\n\n")
            showGateAlert = true
            return
        }
        onMainActionButtonPressed()
    }

    private func formatCapSpace(_ cap: Int) -> String {
        // Compact millions with sign, matches other places in the app
        let millions = Double(cap) / 1_000_000.0
        let absStr = String(format: "%.0fM", abs(millions))
        return cap < 0 ? "-\u{0024}\(absStr)" : "\u{0024}\(absStr)"
    }
}

// MARK: - Training Camp Cuts Button
struct LeagueHubTrainingCampCutsButton: View {
    let onTrainingCampCutsPressed: () -> Void
    
    var body: some View {
        Button {
            print("🔧 Training Camp Cuts button pressed")
            onTrainingCampCutsPressed()
        } label: {
            HStack {
                Image(systemName: "scissors")
                    .font(.title3)
                
                Text("Training Camp Cuts")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.orange, in: RoundedRectangle(cornerRadius: Corner.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Corner.medium, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }
} 