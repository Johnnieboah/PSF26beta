import Foundation

struct Team: Codable, Identifiable {
    let name: String
    let schedule: [Game]
    
    var id: String { name }
}

struct Game: Codable, Identifiable {
    let week: Int
    let homeTeam: String
    let awayTeam: String
    let neutralSite: String?
    
    var id: String {
        "\(week)_\(homeTeam)_\(awayTeam)"
    }
} 