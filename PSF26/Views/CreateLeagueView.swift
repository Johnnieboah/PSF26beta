import SwiftUI

struct CreateLeagueView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showingModeSelection = false
    @State private var showingTeamSelection = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Header
                        headerSection
                        
                        if showingTeamSelection {
                            // Team selection will be handled by navigation
                            EmptyView()
                        } else if showingModeSelection {
                            modeSelectionSection
                        } else {
                            leagueOptionsSection
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("Create League")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $showingTeamSelection) {
                TeamSelectionView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                if showingModeSelection {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingModeSelection = false
                            }
                        }
                    }
                }
            }
        }
        .alert("Create League", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: showingModeSelection ? "person.2.fill" : "plus.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .symbolEffect(.bounce, options: .speed(0.3).repeat(.continuous))
            
            Text(showingModeSelection ? "Choose Your Role" : "Create New League")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(showingModeSelection ? "Select how you want to manage your league" : "Choose how to start your football journey")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var modeSelectionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                    .symbolEffect(.bounce, options: .repeat(.continuous))
                Text("Management Mode")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                // Owner Mode Button (Active)
                ownerModeOption
                
                // Commissioner Mode Button (Grayed Out)
                commissionerModeOption
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var ownerModeOption: some View {
        Button {
            createOwnerModeLeague()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Owner Mode")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Control one team as owner")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
                
                HStack(spacing: 16) {
                    featureItem("Pick Team", "hand.point.up.fill")
                    featureItem("Manage Roster", "person.3.fill")
                    featureItem("Make Trades", "arrow.left.arrow.right")
                }
                .padding(.top, 8)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.green.opacity(0.1), .blue.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var commissionerModeOption: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    .grayscale(1.0)
                    .opacity(0.6)
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Commissioner Mode")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Control all teams and settings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 4) {
                    Text("Coming Soon")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            
            HStack(spacing: 16) {
                featureItem("All Teams", "building.2.fill", isDisabled: true)
                featureItem("League Settings", "gearshape.fill", isDisabled: true)
                featureItem("Full Control", "crown.fill", isDisabled: true)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            Color.secondary.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - League Options Section
    private var leagueOptionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "football.fill")
                    .foregroundColor(.brown)
                    .symbolEffect(.bounce, options: .repeat(.continuous))
                Text("League Options")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                // Default League Button
                defaultLeagueOption
                
                // Create New League Button (Grayed Out)
                createNewLeagueOption
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var defaultLeagueOption: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingModeSelection = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image("leaguelogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default League")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("32 NFL teams, standard rules")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                HStack(spacing: 16) {
                    featureItem("32 Teams", "person.3.fill")
                    featureItem("Standard Rules", "list.bullet")
                    featureItem("Quick Start", "bolt.fill")
                }
                .padding(.top, 8)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.1), .green.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var createNewLeagueOption: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    .grayscale(1.0)
                    .opacity(0.6)
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Create New League")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Custom teams and rules")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 4) {
                    Text("Coming Soon")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            
            HStack(spacing: 16) {
                featureItem("Custom Teams", "gearshape.fill", isDisabled: true)
                featureItem("Custom Rules", "slider.horizontal.3", isDisabled: true)
                featureItem("Advanced Setup", "wrench.and.screwdriver.fill", isDisabled: true)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            Color.secondary.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func featureItem(_ title: String, _ systemImage: String, isDisabled: Bool = false) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isDisabled ? .secondary : .blue)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(isDisabled ? .secondary : .primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Actions
    
    private func createOwnerModeLeague() {
        showingTeamSelection = true
    }
}

#Preview {
    CreateLeagueView()
}
