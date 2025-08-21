import Foundation

// MARK: - Player Data Model
struct PlayerData: Identifiable, Codable {
    let id = UUID()
    let firstName: String
    let lastName: String
    let position: String
    let number: Int
    let overall: Int
    let age: Int
    let height: Int
    
    // Optional salary information for enhanced features
    var actualSalary: Int?
    // Development trait from PFL2025DATA.csv (e.g., Normal, Slow, Fast, Elite)
    var development: String?
    
    enum CodingKeys: String, CodingKey {
        case firstName, lastName, position, number, overall, age, actualSalary, height, development
    }
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var playerId: String {
        "\(firstName)_\(lastName)_\(number)"
    }
    
    // Enhanced salary calculation that uses actual salary when available
    var estimatedSalary: Int {
        // Use stored actual salary if available
        if let salary = actualSalary {
            return salary
        }
        return estimateBasicSalary()
    }

    var capHit: Int { actualSalary ?? estimateBasicSalary() }
    
    // Basic salary estimation fallback
    private func estimateBasicSalary() -> Int {
        // More realistic salary estimation based on overall rating and position
        let baseMultiplier: Double
        switch position {
        case "QB": baseMultiplier = 2.5
        case "LT", "RT": baseMultiplier = 1.8
        case "DE", "EDGE": baseMultiplier = 1.6
        case "WR", "CB": baseMultiplier = 1.4
        case "RB", "TE", "SS", "FS": baseMultiplier = 1.2
        case "C", "LG", "RG", "DT", "MLB": baseMultiplier = 1.1
        case "K", "P": baseMultiplier = 0.3
        default: baseMultiplier = 1.0
        }
        
        // More realistic base calculation: use overall rating more reasonably
        // Average NFL salary is around $2.8M, so scale from that
        let averageSalary = 2_800_000.0
        let overallFactor = Double(overall) / 80.0 // 80 overall = average player
        let baseSalary = averageSalary * overallFactor * baseMultiplier
        
        return max(750_000, Int(baseSalary)) // Minimum NFL salary
    }
    
    // Convenience initializer for basic player creation (maintains backward compatibility)
    init(firstName: String, lastName: String, position: String, number: Int, overall: Int, age: Int, height: Int = 72) {
        self.firstName = firstName
        self.lastName = lastName
        self.position = position
        self.number = number
        self.overall = overall
        self.age = age
        self.height = height
        self.actualSalary = nil
        self.development = nil
    }
    
    // Enhanced initializer with salary information
    init(firstName: String, lastName: String, position: String, number: Int, overall: Int, age: Int, actualSalary: Int?, height: Int = 72, development: String? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.position = position
        self.number = number
        self.overall = overall
        self.age = age
        self.actualSalary = actualSalary
        self.height = height
        self.development = development
    }
    
    // MARK: - Sample Data for previews/testing
    static var samplePlayer: PlayerData {
        PlayerData(
            firstName: "John",
            lastName: "Doe",
            position: "QB",
            number: 12,
            overall: 85,
            age: 27,
            actualSalary: 8000000,
            height: 75,
            development: "Normal"
        )
    }
}

// MARK: - Equatable Conformance
extension PlayerData: Equatable {
    static func == (lhs: PlayerData, rhs: PlayerData) -> Bool {
        return lhs.firstName == rhs.firstName &&
               lhs.lastName == rhs.lastName &&
               lhs.position == rhs.position &&
               lhs.number == rhs.number &&
               lhs.overall == rhs.overall &&
               lhs.age == rhs.age &&
               lhs.actualSalary == rhs.actualSalary &&
               lhs.height == rhs.height &&
               lhs.development == rhs.development
    }
} 

// MARK: - Copy helpers
extension PlayerData {
    func with(actualSalary: Int?) -> PlayerData {
        var copy = self
        copy.actualSalary = actualSalary
        return copy
    }
    func with(development: String?) -> PlayerData {
        var copy = self
        copy.development = development
        return copy
    }
    func with(actualSalary: Int?, development: String?) -> PlayerData {
        var copy = self
        copy.actualSalary = actualSalary
        copy.development = development
        return copy
    }
}
