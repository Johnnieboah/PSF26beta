import SwiftUI

struct LoadLeagueView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var selectedSlotToDelete: Int?
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showingLoadConfirmation = false
    @State private var selectedSlotToLoad: SaveSlot?
    @State private var showingCreateLeague = false
    
    // Sample save data for the three slots
    @State private var saveSlots: [SaveSlot] = [
        SaveSlot(
            slotNumber: 1,
            leagueName: "Pure Football League",
            lastSaved: Date().addingTimeInterval(-86400), // 1 day ago
            teamCount: 32,
            currentSeason: 2025,
            currentWeek: 8,
            isOccupied: true,
            userTeam: NFLTeam.chiefs,
            record: "7-1",
            playoffStatus: nil
        ),
        SaveSlot(
            slotNumber: 2,
            leagueName: "Pure Football League",
            lastSaved: Date().addingTimeInterval(-259200), // 3 days ago
            teamCount: 32,
            currentSeason: 2025,
            currentWeek: 12,
            isOccupied: true,
            userTeam: NFLTeam.bills,
            record: "9-3",
            playoffStatus: nil
        ),
        SaveSlot(
            slotNumber: 3,
            leagueName: nil,
            lastSaved: nil,
            teamCount: 0,
            currentSeason: 0,
            currentWeek: 0,
            isOccupied: false,
            userTeam: nil,
            record: nil,
            playoffStatus: nil
        )
    ]
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Header
                        headerSection
                        
                        // Save Slots
                        saveSlotSection
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("Load League")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Load League", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Delete Save", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let slot = selectedSlotToDelete {
                    deleteSaveSlot(slot)
                }
            }
        } message: {
            Text("Are you sure you want to delete this save? This action cannot be undone.")
        }
        .alert("Load League", isPresented: $showingLoadConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Load") {
                if let slot = selectedSlotToLoad {
                    loadLeague(slot)
                }
            }
        } message: {
            if let slot = selectedSlotToLoad {
                Text("Load '\(slot.leagueName ?? "Unknown League")' from Slot \(slot.slotNumber)?")
            }
        }
        .sheet(isPresented: $showingCreateLeague) {
            CreateLeagueView()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .symbolEffect(.bounce, options: .speed(0.3).repeat(.continuous))
            
            Text("Load League")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Choose a saved league to continue")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Save Slots Section
    private var saveSlotSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.green)
                    .symbolEffect(.variableColor, options: .repeat(.continuous))
                Text("Save Slots")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            
            // Use List for proper swipe actions
            List {
                ForEach(saveSlots.indices, id: \.self) { index in
                    saveSlotRow(saveSlots[index])
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }
            .listStyle(PlainListStyle())
            .frame(height: CGFloat(saveSlots.count * 140)) // Approximate height
            .scrollDisabled(true)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func saveSlotRow(_ slot: SaveSlot) -> some View {
        Group {
            if slot.isOccupied {
                // Occupied slot - gradient button with swipe action
                Button {
                    showLoadConfirmation(for: slot)
                } label: {
                    // Team-branded gradient with all information
                    if let team = slot.userTeam {
                        VStack(spacing: 12) {
                            // Top row: Slot number and last played
                            HStack {
                                Text("Slot \(slot.slotNumber)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                                    .shadow(color: .black.opacity(0.8), radius: 3, x: 1, y: 1)
                                
                                Spacer()
                                
                                Text(formatDate(slot.lastSaved))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .shadow(color: .black.opacity(0.8), radius: 3, x: 1, y: 1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            
                            // Main content row: Logo, team info, record
                            HStack {
                                // Team logo
                                Image(team.logoName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .shadow(color: .black.opacity(0.6), radius: 4, x: 2, y: 2)
                                    .padding(.leading, 16)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(slot.leagueName ?? "Unknown League")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.9), radius: 3, x: 1, y: 1)
                                    
                                    Text("\(team.city) \(team.name)")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                        .shadow(color: .black.opacity(0.8), radius: 3, x: 1, y: 1)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(slot.record ?? "0-0")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.9), radius: 3, x: 1, y: 1)
                                    
                                    Text("Record")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .shadow(color: .black.opacity(0.8), radius: 3, x: 1, y: 1)
                                }
                                .padding(.trailing, 16)
                            }
                            
                            // Bottom row: Season and Week info
                            HStack {
                                Text("Season \(romanNumeral(slot.currentSeason - 2024)) - (\(String(slot.currentSeason)))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.8), radius: 3, x: 1, y: 1)
                                
                                Spacer()
                                
                                Text("Week \(slot.currentWeek)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.8), radius: 3, x: 1, y: 1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [team.primaryColor, team.secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteSaveSlot(slot.slotNumber)
                    } label: {
                        Image(systemName: "trash")
                            .font(.title2)
                    }
                    .tint(.red)
                }
                
            } else {
                // Empty slot
                Button {
                    showingCreateLeague = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.dashed")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        
                        Text("Slot \(slot.slotNumber) - Empty")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("No saved league")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "plus")
                            Text("Create New League")
                            Spacer()
                        }
                        .padding()
                        .foregroundColor(.blue)
                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func statItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        
        let formatter = DateFormatter()
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 86400 { // Less than 1 day
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        } else if timeInterval < 604800 { // Less than 1 week
            let days = Int(timeInterval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else {
            // Custom format without commas
            formatter.dateFormat = "MMM d yyyy"
            return formatter.string(from: date)
        }
    }
    
    private func romanNumeral(_ number: Int) -> String {
        let values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
        let numerals = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
        
        var result = ""
        var num = number
        
        for (value, numeral) in zip(values, numerals) {
            let count = num / value
            if count > 0 {
                result += String(repeating: numeral, count: count)
                num -= count * value
            }
        }
        
        return result
    }
    
    // MARK: - Actions
    
    private func loadLeague(_ slot: SaveSlot) {
        // TODO: Implement actual league loading
        alertMessage = "Loading '\(slot.leagueName ?? "Unknown League")' from Slot \(slot.slotNumber)..."
        showingAlert = true
        
        // Simulate loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
    
    private func deleteSaveSlot(_ slotNumber: Int) {
        if let index = saveSlots.firstIndex(where: { $0.slotNumber == slotNumber }) {
            saveSlots[index] = SaveSlot(
                slotNumber: slotNumber,
                leagueName: nil,
                lastSaved: nil,
                teamCount: 0,
                currentSeason: 0,
                currentWeek: 0,
                isOccupied: false,
                userTeam: nil,
                record: nil,
                playoffStatus: nil
            )
        }
        
        alertMessage = "Save slot \(slotNumber) has been deleted."
        showingAlert = true
    }
    
    private func createNewLeague(in slotNumber: Int) {
        showingCreateLeague = true
    }
    
    private func showLoadConfirmation(for slot: SaveSlot) {
        selectedSlotToLoad = slot
        showingLoadConfirmation = true
    }
    
    private func showDeleteConfirmation(for slotNumber: Int) {
        selectedSlotToDelete = slotNumber
        showingDeleteAlert = true
    }
}

// MARK: - Save Slot Data Model
struct SaveSlot {
    let slotNumber: Int
    let leagueName: String?
    let lastSaved: Date?
    let teamCount: Int
    let currentSeason: Int
    let currentWeek: Int
    let isOccupied: Bool
    let userTeam: NFLTeam?
    let record: String?
    let playoffStatus: String?
}

// MARK: - NFL Team Data Model
struct NFLTeam {
    let name: String
    let city: String
    let logoName: String
    let primaryColor: Color
    let secondaryColor: Color
    
    // Sample teams - using actual logo names from assets
    static let chiefs = NFLTeam(
        name: "Chiefs",
        city: "Kansas City",
        logoName: "KansasCity", // Updated to match actual asset
        primaryColor: Color(red: 0.89, green: 0.11, blue: 0.13), // Chiefs Red
        secondaryColor: Color(red: 1.0, green: 0.76, blue: 0.04) // Chiefs Gold
    )
    
    static let cowboys = NFLTeam(
        name: "Cowboys",
        city: "Dallas",
        logoName: "Dallas", // Updated to match actual asset
        primaryColor: Color(red: 0.0, green: 0.13, blue: 0.4), // Cowboys Navy
        secondaryColor: Color(red: 0.53, green: 0.66, blue: 0.8) // Cowboys Silver/Blue
    )
    
    static let patriots = NFLTeam(
        name: "Patriots",
        city: "New England",
        logoName: "NewEngland", // Updated to match actual asset
        primaryColor: Color(red: 0.0, green: 0.13, blue: 0.4), // Patriots Navy
        secondaryColor: Color(red: 0.78, green: 0.09, blue: 0.16) // Patriots Red
    )
    
    static let packers = NFLTeam(
        name: "Packers",
        city: "Green Bay",
        logoName: "GreenBay", // Updated to match actual asset
        primaryColor: Color(red: 0.13, green: 0.37, blue: 0.12), // Packers Green
        secondaryColor: Color(red: 1.0, green: 0.76, blue: 0.04) // Packers Gold
    )
    
    static let steelers = NFLTeam(
        name: "Steelers",
        city: "Pittsburgh",
        logoName: "Pittsburgh",
        primaryColor: Color(red: 0.0, green: 0.0, blue: 0.0), // Steelers Black
        secondaryColor: Color(red: 1.0, green: 0.76, blue: 0.04) // Steelers Gold
    )
    
    static let ravens = NFLTeam(
        name: "Ravens",
        city: "Baltimore",
        logoName: "Baltimore",
        primaryColor: Color(red: 0.16, green: 0.11, blue: 0.31), // Ravens Purple
        secondaryColor: Color(red: 0.0, green: 0.0, blue: 0.0) // Ravens Black
    )
    
    static let bengals = NFLTeam(
        name: "Bengals",
        city: "Cincinnati",
        logoName: "Cincinnati",
        primaryColor: Color(red: 0.95, green: 0.38, blue: 0.09), // Bengals Orange
        secondaryColor: Color(red: 0.0, green: 0.0, blue: 0.0) // Bengals Black
    )
    
    static let browns = NFLTeam(
        name: "Browns",
        city: "Cleveland",
        logoName: "Cleveland",
        primaryColor: Color(red: 0.31, green: 0.18, blue: 0.09), // Browns Brown
        secondaryColor: Color(red: 0.95, green: 0.38, blue: 0.09) // Browns Orange
    )
    
    static let bills = NFLTeam(
        name: "Bills",
        city: "Buffalo",
        logoName: "Buffalo",
        primaryColor: Color(red: 0.0, green: 0.24, blue: 0.59), // Bills Blue
        secondaryColor: Color(red: 0.78, green: 0.09, blue: 0.16) // Bills Red
    )
    
    static let dolphins = NFLTeam(
        name: "Dolphins",
        city: "Miami",
        logoName: "Miami",
        primaryColor: Color(red: 0.0, green: 0.51, blue: 0.56), // Dolphins Aqua
        secondaryColor: Color(red: 0.95, green: 0.38, blue: 0.09) // Dolphins Orange
    )
    
    // All teams array for easy access
    static let allTeams: [NFLTeam] = [
        chiefs, cowboys, patriots, packers, steelers, ravens,
        bengals, browns, bills, dolphins
    ]
}

#Preview {
    LoadLeagueView()
}
