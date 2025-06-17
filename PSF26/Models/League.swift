import Foundation
import Combine

class League: ObservableObject {
    @Published private(set) var teams: [Team] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private var teamCache: [String: Team] = [:]
    
    func loadLeague(from url: URL) async {
        isLoading = true
        error = nil
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let teamsDict = try decoder.decode([String: Team].self, from: data)
            
            // Convert dictionary to array and sort by team name
            teams = teamsDict.map { $0.value }.sorted { $0.name < $1.name }
            
            // Build caches
            buildCaches()
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    private func buildCaches() {
        teamCache.removeAll()
        for team in teams {
            teamCache[team.name] = team
        }
    }
    
    // MARK: - Data Access Methods
    
    func getTeam(named name: String) -> Team? {
        return teamCache[name]
    }
    
    func getSchedule(for team: String) -> [Game] {
        return teamCache[team]?.schedule ?? []
    }
    
    // MARK: - Export Methods
    
    func exportToJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            return try encoder.encode(teams)
        } catch {
            self.error = error
            return nil
        }
    }
} 