import Foundation

// MARK: - PlayerData Extensions for Salary Cap
// Note: PlayerData now has built-in salary and contract support in LeagueModels.swift

// MARK: - EditablePlayerData Extensions for Salary Cap

extension EditablePlayerData {
    // Computed properties that use the existing stored properties
    var isRookie: Bool {
        get {
            return contract?.isRookieContract ?? isRookiePlayer
        }
    }
    
    var draftPick: Int? {
        get {
            return contract?.draftPick ?? draftPickNumber
        }
    }
    
    var draftYear: Int? {
        get {
            return draftYearValue ?? {
                // Calculate from years pro and current year
                let currentYear = Calendar.current.component(.year, from: Date())
                return yearsPro == 0 ? currentYear : currentYear - yearsPro
            }()
        }
    }
    
    var contractYearsRemaining: Int {
        get {
            return contract?.yearsRemaining ?? contractYearsLeft
        }
    }
    
    // Current salary - use contract if available, otherwise use stored salary, fallback to estimate
    var currentSalary: Int {
        get {
            return contract?.currentYearSalary ?? (salary > 0 ? salary : estimatedSalary)
        }
    }
    
    // Estimated salary based on player attributes
    var estimatedSalary: Int {
        return SalaryCapManager.estimatePlayerSalary(overall: overall, age: age, position: position)
    }
    
    var playerId: String {
        "\(firstName)_\(lastName)_\(number)"
    }
} 