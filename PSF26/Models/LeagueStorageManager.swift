import Foundation
import Combine

@MainActor
class LeagueStorageManager: ObservableObject {
    static let shared = LeagueStorageManager()
    
    @Published var savedLeagues: [League] = []
    
    private let documentsDirectory: URL
    private let leaguesDirectory: URL
    private let maxSaveSlots = 10
    private let historyDirectoryName = "History"
    
    private init() {
        // Get documents directory
        documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                     in: .userDomainMask).first!
        
        // Create leagues subdirectory
        leaguesDirectory = documentsDirectory.appendingPathComponent("Leagues")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: leaguesDirectory,
                                               withIntermediateDirectories: true)
        
        // Load existing leagues
        loadAllLeagues()
        
        // Clean up any duplicate save files
        cleanupDuplicateSaves()
    }
    
    // MARK: - Save Operations
    
    func saveLeague(_ league: League) throws {
        var leagueToSave = league
        
        // Use league ID for consistent filename - each league gets its own file
        let filename = "league_\(league.id.uuidString).json"
        let fileURL = leaguesDirectory.appendingPathComponent(filename)
        
        // Update last played date
        leagueToSave.lastPlayedDate = Date()
        
        // For legacy compatibility, assign a slot number if needed for display
        if leagueToSave.saveSlotNumber == nil {
            leagueToSave.saveSlotNumber = findDisplaySlot(for: league.id)
        }
        
        // Encode and save (this will overwrite existing file for this league)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(leagueToSave)
        try data.write(to: fileURL)
        
        print("💾 Saved league '\(league.teamName)' to file: \(filename)")
        
        // Reload leagues
        loadAllLeagues()
    }
    
    // MARK: - Load Operations
    
    func loadLeague(from slot: Int) throws -> League? {
        // Legacy method - kept for compatibility
        let filename = "league_slot_\(slot).json"
        let fileURL = leaguesDirectory.appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(League.self, from: data)
    }
    
    func loadLeague(by id: UUID) throws -> League? {
        let filename = "league_\(id.uuidString).json"
        let fileURL = leaguesDirectory.appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(League.self, from: data)
    }
    
    private func loadAllLeagues() {
        savedLeagues = []
        
        // Load all league files from the directory
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: leaguesDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs {
                if fileURL.pathExtension == "json" &&
                   (fileURL.lastPathComponent.hasPrefix("league_") || fileURL.lastPathComponent.hasPrefix("league_slot_")) {
                    
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let league = try decoder.decode(League.self, from: data)
                        savedLeagues.append(league)
                    } catch {
                        print("⚠️ Failed to load league from \(fileURL.lastPathComponent): \(error)")
                    }
                }
            }
        } catch {
            print("⚠️ Failed to read leagues directory: \(error)")
        }
        
        // Sort by last played date
        savedLeagues.sort { $0.lastPlayedDate > $1.lastPlayedDate }
        
        print("📂 Loaded \(savedLeagues.count) leagues")
    }
    
    // MARK: - Delete Operations
    
    func deleteLeague(at slot: Int) throws {
        // Legacy method - kept for compatibility
        let filename = "league_slot_\(slot).json"
        let fileURL = leaguesDirectory.appendingPathComponent(filename)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        
        // Reload leagues
        loadAllLeagues()
    }
    
    func deleteLeague(_ league: League) throws {
        let filename = "league_\(league.id.uuidString).json"
        let fileURL = leaguesDirectory.appendingPathComponent(filename)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            print("🗑️ Deleted league '\(league.teamName)' file: \(filename)")
        }
        
        // Phase 2: Also delete associated player data files
        do {
            try PlayerDataManager.shared.deleteLeaguePlayerData(leagueId: league.id)
            print("🗑️ ✅ Deleted player data files for league '\(league.teamName)'")
        } catch {
            print("🗑️ ⚠️ Failed to delete player data for league '\(league.teamName)': \(error)")
            // Don't fail league deletion if player data cleanup fails
        }
        
        // Reload leagues
        loadAllLeagues()
    }
    
    // MARK: - Debug/Testing Methods
    
    func deleteAllLeagues() throws {
        // Phase 2: Delete all player data files first
        for league in savedLeagues {
            do {
                try PlayerDataManager.shared.deleteLeaguePlayerData(leagueId: league.id)
            } catch {
                print("🗑️ ⚠️ Failed to delete player data for league '\(league.teamName)': \(error)")
            }
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: leaguesDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs {
                if fileURL.pathExtension == "json" &&
                   (fileURL.lastPathComponent.hasPrefix("league_") || fileURL.lastPathComponent.hasPrefix("league_slot_")) {
                    try FileManager.default.removeItem(at: fileURL)
                    print("🗑️ Deleted save file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("⚠️ Failed to delete all leagues: \(error)")
            throw error
        }
        
        // Clear in-memory leagues and reload
        savedLeagues.removeAll()
        loadAllLeagues()
        print("🧹 All league save files and player data deleted successfully")
    }
    
    // MARK: - Helper Methods
    
    private func findAvailableSlot() -> Int? {
        // Legacy method - kept for compatibility
        let usedSlots = savedLeagues.compactMap { $0.saveSlotNumber }
        
        for slot in 1...maxSaveSlots {
            if !usedSlots.contains(slot) {
                return slot
            }
        }
        
        return nil
    }
    
    private func findDisplaySlot(for leagueId: UUID) -> Int {
        // Check if this league already has a display slot
        if let existingLeague = savedLeagues.first(where: { $0.id == leagueId }),
           let existingSlot = existingLeague.saveSlotNumber {
            return existingSlot
        }
        
        // Find next available display slot for UI purposes
        let usedSlots = savedLeagues.compactMap { $0.saveSlotNumber }
        
        for slot in 1...maxSaveSlots {
            if !usedSlots.contains(slot) {
                return slot
            }
        }
        
        // If all slots used, just return a number based on count
        return savedLeagues.count + 1
    }
    
    func hasAvailableSlots() -> Bool {
        // With ID-based saving, we don't have slot limits anymore
        return true
    }
    
    // MARK: - Cleanup Methods
    
    func cleanupDuplicateSaves() {
        // Remove duplicate saves for the same league ID
        var filesToDelete: [URL] = []
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: leaguesDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            
            // Group files by league ID and keep only the most recent
            var leagueFiles: [UUID: [(url: URL, date: Date)]] = [:]
            
            for fileURL in fileURLs {
                if fileURL.pathExtension == "json" && fileURL.lastPathComponent.hasPrefix("league_") {
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let league = try decoder.decode(League.self, from: data)
                        
                        let modificationDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                        
                        if leagueFiles[league.id] == nil {
                            leagueFiles[league.id] = []
                        }
                        leagueFiles[league.id]?.append((url: fileURL, date: modificationDate))
                        
                    } catch {
                        print("⚠️ Failed to read league file \(fileURL.lastPathComponent) for cleanup: \(error)")
                    }
                }
            }
            
            // For each league, keep only the most recent file
            for (leagueId, files) in leagueFiles {
                if files.count > 1 {
                    let sortedFiles = files.sorted { $0.date > $1.date }
                    let _ = sortedFiles.prefix(1)
                    let filesToRemove = Array(sortedFiles.dropFirst())
                    
                    print("🧹 Found \(files.count) files for league \(leagueId), keeping most recent")
                    
                    for fileInfo in filesToRemove {
                        filesToDelete.append(fileInfo.url)
                    }
                }
            }
            
            // Delete duplicate files
            for fileURL in filesToDelete {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("🗑️ Deleted duplicate save: \(fileURL.lastPathComponent)")
                } catch {
                    print("⚠️ Failed to delete duplicate save \(fileURL.lastPathComponent): \(error)")
                }
            }
            
            if !filesToDelete.isEmpty {
                print("🧹 Cleanup complete: removed \(filesToDelete.count) duplicate save files")
                loadAllLeagues() // Reload after cleanup
            }
            
        } catch {
            print("⚠️ Failed to cleanup duplicate saves: \(error)")
        }
    }
}

// MARK: - Weekly History Snapshots

extension LeagueStorageManager {
    struct WeeklyHistorySnapshot: Codable {
        // Decodable note: do not assign a default here; let the decoder overwrite it.
        let schemaVersion: Int
        let leagueId: UUID
        let week: Int
        let createdAt: Date
        let userTeamLogoName: String
        let gameResults: [String: GameResult]
    }

    /// Writes a compact weekly snapshot for history browsing.
    /// This runs off the main thread and won't affect UI/gameplay.
    func writeWeeklyHistorySnapshot(
        leagueId: UUID,
        week: Int,
        userTeamLogoName: String,
        gameResults: [String: GameResult]
    ) async {
        // Skip empty snapshots
        guard !gameResults.isEmpty else {
            print("📜 Skipping history snapshot for week \(week): no game results")
            return
        }
        let historyRoot = leaguesDirectory
            .appendingPathComponent(leagueId.uuidString)
            .appendingPathComponent(historyDirectoryName)
        do {
            try FileManager.default.createDirectory(at: historyRoot, withIntermediateDirectories: true)
            let filename = String(format: "week_%02d.json", week)
            let fileURL = historyRoot.appendingPathComponent(filename)

            // Do not overwrite an existing snapshot for the same week
            if FileManager.default.fileExists(atPath: fileURL.path) {
                print("📜 History snapshot already exists for week \(week): \(filename) — leaving as is")
                return
            }

            let snapshot = WeeklyHistorySnapshot(
                schemaVersion: 1,
                leagueId: leagueId,
                week: week,
                createdAt: Date(),
                userTeamLogoName: userTeamLogoName,
                gameResults: gameResults
            )

            let data = try JSONEncoder().encode(snapshot)
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                DispatchQueue.global(qos: .utility).async {
                    do {
                        try data.write(to: fileURL, options: Data.WritingOptions.atomic)
                        cont.resume()
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
            print("📜 Saved weekly history snapshot: week \(week) → \(fileURL.lastPathComponent)")
        } catch {
            print("⚠️ Failed to save weekly history snapshot for week \(week): \(error)")
        }
    }
}

// MARK: - Error Types

enum LeagueStorageError: LocalizedError {
    case noAvailableSlots
    case saveFailure
    case loadFailure
    
    var errorDescription: String? {
        switch self {
        case .noAvailableSlots:
            return "No available save slots. Please delete an existing league."
        case .saveFailure:
            return "Failed to save league data."
        case .loadFailure:
            return "Failed to load league data."
        }
    }
}
