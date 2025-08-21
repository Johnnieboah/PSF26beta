import Foundation

// MARK: - Enhanced Global Game Player Stats Manager
class GlobalGamePlayerStatsManager {
    static let shared = GlobalGamePlayerStatsManager()
    
    private var gamePlayerStats: [UUID: [GamePlayerStats]] = [:]
    private let maxCacheSize = 500 // Limit cached games to prevent memory bloat
    private var accessTimes: [UUID: Date] = [:]
    
    private init() {}
    
    func storeGamePlayerStats(gameId: UUID, stats: [GamePlayerStats]) {
        // Implement LRU cache eviction if needed
        if gamePlayerStats.count >= maxCacheSize {
            evictOldestEntries()
        }
        
        gamePlayerStats[gameId] = stats
        accessTimes[gameId] = Date()
    }
    
    func getGamePlayerStats(gameId: UUID) -> [GamePlayerStats]? {
        accessTimes[gameId] = Date() // Update access time
        return gamePlayerStats[gameId]
    }
    
    func removeGamePlayerStats(gameId: UUID) {
        gamePlayerStats.removeValue(forKey: gameId)
        accessTimes.removeValue(forKey: gameId)
    }
    
    func clearAllStats() {
        gamePlayerStats.removeAll()
        accessTimes.removeAll()
    }
    
    func getAllGameIds() -> [UUID] {
        return Array(gamePlayerStats.keys)
    }
    
    func getTotalGamesWithStats() -> Int {
        return gamePlayerStats.count
    }
    
    // MARK: - Memory Management
    private func evictOldestEntries() {
        let sortedByAccess = accessTimes.sorted { $0.value < $1.value }
        let toRemove = sortedByAccess.prefix(maxCacheSize / 4) // Remove 25% of entries
        
        for (gameId, _) in toRemove {
            gamePlayerStats.removeValue(forKey: gameId)
            accessTimes.removeValue(forKey: gameId)
        }
        
        print("🧹 Evicted \(toRemove.count) old game stats from cache")
    }
    
    // Batch operations for efficiency
    func storeMultipleGameStats(_ statsMap: [UUID: [GamePlayerStats]]) {
        let currentTime = Date()
        
        for (gameId, stats) in statsMap {
            gamePlayerStats[gameId] = stats
            accessTimes[gameId] = currentTime
        }
        
        // Check if we need to evict after batch insert
        if gamePlayerStats.count >= maxCacheSize {
            evictOldestEntries()
        }
    }
    
    func getMemoryUsage() -> (gameCount: Int, playerCount: Int, estimatedMB: Double) {
        let gameCount = gamePlayerStats.count
        let playerCount = gamePlayerStats.values.reduce(0) { $0 + $1.count }
        let estimatedMB = Double(playerCount * 500) / (1024 * 1024) // Rough estimate
        
        return (gameCount: gameCount, playerCount: playerCount, estimatedMB: estimatedMB)
    }
} 