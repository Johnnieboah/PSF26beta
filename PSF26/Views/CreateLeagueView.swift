import SwiftUI

struct CreateLeagueView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Header
                        headerSection
                        
                        // League Options
                        leagueOptionsSection
                        
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
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
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .symbolEffect(.bounce, options: .speed(0.3).repeat(.continuous))
            
            Text("Create New League")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Choose how to start your football journey")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
            createDefaultLeague()
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
    
    private func createDefaultLeague() {
        // TODO: Implement default league creation
        alertMessage = "Creating default league with 32 NFL teams..."
        showingAlert = true
        
        // Simulate creation delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}

#Preview {
    CreateLeagueView()
}
