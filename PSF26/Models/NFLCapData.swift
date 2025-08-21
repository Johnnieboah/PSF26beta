import Foundation

// MARK: - Real NFL Cap Data

struct NFLCapData {
    // 2025 NFL Salary Cap (target): $279.2 million per team
    static let salaryCap: Int = 279_200_000
    
    // Real team cap spending based on NFL cap space data from CSV
    // Adjusted to ensure adequate cap space for training camp cuts with dead money
    static let teamCapSpending: [String: Int] = [
        // AFC East
        "NewEngland": 241_073_147,    // New England (59.6M space - no adjustment needed)
        "Buffalo": 233_800_301,       // Buffalo (was over cap, +$10M adjustment)
        "Miami": 219_974_605,         // Miami (was $964K space, +$10M adjustment)
        "NYA": 180_251_620,           // New York Jets (29.6M space - no adjustment needed)
        
        // AFC North
        "Baltimore": 219_365_082,     // Baltimore (was 15M space, +$15M adjustment to get to 21M)
        "Cincinnati": 246_309_251,    // Cincinnati (9.1M space, +$6M adjustment)
        "Cleveland": 223_692_550,     // Cleveland (was 17.6M space, +$17M adjustment to get to 32M)
        "Pittsburgh": 236_991_767,    // Pittsburgh (was 17.6M space, +$17M adjustment to get to 18M)
        
        // AFC South
        "Houston": 215_043_407,       // Houston (was 14.7M space, +$15M adjustment to get to 40M)
        "Indianapolis": 244_033_223,  // Indianapolis (was 19.4M space, +$19M adjustment to get to 11M)
        "Jacksonville": 213_838_845,  // Jacksonville (18.8M space - no adjustment needed)
        "Tennessee": 203_313_187,     // Tennessee (was 29.7M space, +$30M adjustment to get to 52M)
        
        // AFC West
        "Denver": 220_582_236,        // Denver (was 12.6M space, +$13M adjustment to get to 35M)
        "KansasCity": 232_709_479,    // Kansas City (was 20M space, +$20M adjustment to get to 23M)
        "LasVegas": 208_804_967,      // Las Vegas (was 30.9M space, +$30M adjustment to get to 47M)
        "LAA": 202_827_843,           // Los Angeles Chargers (was 27.3M space, +$27M adjustment to get to 53M)
        
        // NFC East
        "Dallas": 213_752_488,        // Dallas (was 31.8M space, +$31M adjustment to get to 42M)
        "NYN": 248_402_037,           // New York Giants (was 3.8M space, +$10M adjustment)
        "Philadelphia": 152_507_462,  // Philadelphia (was 30.5M space, +$30M adjustment to get to 103M)
        "Washington": 241_754_454,    // Washington (was 21.1M space, +$21M adjustment to get to 14M)
        
        // NFC North
        "Chicago": 242_207_721,       // Chicago (was 13.2M space, +$25M adjustment to get to 13M)
        "Detroit": 183_027_446,       // Detroit (was 48M space, +$48M adjustment to get to 72M)
        "GreenBay": 191_352_192,      // Green Bay (was 35.1M space, +$35M adjustment to get to 64M)
        "Minnesota": 220_388_688,     // Minnesota (was 23.5M space, +$24M adjustment to get to 35M)
        
        // NFC South
        "Atlanta": 261_794_623,       // Atlanta (was 5M space, +$10M adjustment)
        "Carolina": 232_283_924,      // Carolina (was 16.7M space, +$17M adjustment to get to 23M)
        "NewOrleans": 155_255_291,    // New Orleans (was 22.3M space, +$22M adjustment to get to 100M)
        "TampaBay": 197_378_121,      // Tampa Bay (was 26.2M space, +$26M adjustment to get to 58M)
        
        // NFC West
        "Arizona": 214_742_808,       // Arizona (was 35.5M space, +$35M adjustment to get to 41M)
        "LAN": 191_058_975,           // Los Angeles Rams (was 19.5M space, +$19M adjustment to get to 64M)
        "SanFrancisco": 154_267_436,  // San Francisco (was 45.4M space, +$45M adjustment to get to 101M)
        "Seattle": 143_618_379        // Seattle (was 34.9M space, +$35M adjustment to get to 112M)
    ]
    
    static func getCapSpending(for teamLogo: String) -> Int {
        return teamCapSpending[teamLogo] ?? 240_000_000 // Default fallback
    }
    
    static func getCapSpace(for teamLogo: String) -> Int {
        let spending = getCapSpending(for: teamLogo)
        return salaryCap - spending
    }
    
    static func isOverCap(for teamLogo: String) -> Bool {
        return getCapSpending(for: teamLogo) > salaryCap
    }
    
    // Get all teams sorted by available cap space (most to least)
    static func getTeamsByCapSpace() -> [(teamLogo: String, capSpace: Int)] {
        return teamCapSpending.map { (teamLogo: $0.key, capSpace: salaryCap - $0.value) }
            .sorted { $0.capSpace > $1.capSpace }
    }
    
    // Get teams that are over the salary cap
    static func getOverCapTeams() -> [String] {
        return teamCapSpending.compactMap { teamLogo, spending in
            spending > salaryCap ? teamLogo : nil
        }
    }
} 