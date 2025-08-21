import SwiftUI

// MARK: - LeagueHub Simulation Progress View
struct LeagueHubSimulationProgressView: View {
    let isSimulating: Bool
    let simulationProgress: Double
    let currentWeek: Int
    let leagueManager: LeagueManager
    
    var body: some View {
        VStack(spacing: 8) {
            if isSimulating {
                VStack(spacing: 4) {
                    // Show current week being simulated
                    Text("Simulating Week \(currentWeek)")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.bottom, 2)
                    
                    // Show latest user game result if available
                    if let result = leagueManager.latestUserGameResult {
                        Text("Week \(result.week): \(result.userScore) - \(result.opponentScore) vs \(result.opponent)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.bottom, 4)
                    }
                    
                    // Progress bar
                    ProgressView(value: simulationProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                    
                    // Progress text
                    Text("\(Int(simulationProgress * 100))% Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .animation(.easeInOut, value: isSimulating)
        .animation(.easeInOut, value: simulationProgress)
        .animation(.easeInOut, value: currentWeek)
    }
}

// MARK: - Season Recap Processing Overlay
struct LeagueHubSeasonRecapProcessingOverlay: View {
    let isProcessingOffseason: Bool
    let offseasonProcessingProgress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animation
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                        .symbolEffect(.pulse)
                    
                    Text("Season Recap Week")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Generating season highlights...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                // Progress bar
                VStack(spacing: 8) {
                    ProgressView(value: offseasonProcessingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .frame(maxWidth: 200)
                    
                    Text("\(Int(offseasonProcessingProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(40)
            .glassCard()
        }
    }
} 