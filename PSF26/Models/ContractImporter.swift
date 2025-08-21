import Foundation

// MARK: - ContractImporter
// Parses PFL2025DATA.csv and applies per-player APY and Development to league rosters.
// Uses contractAPY_M when present; falls back to (contractTotalValue_M / contractYears) when APY missing.
// Values are in millions; converted to dollars and floored at NFL minimum (~$750k).

enum ContractImporter {
    struct Entry {
        let salary: Int?
        let development: String?
    }

    // Toggle verbose logs while integrating
    nonisolated(unsafe) static var verboseLogs = false

    // Locate the CSV bundled with the app
    nonisolated static func locateCSV() -> URL? {
        if let url = Bundle.main.url(forResource: "PFL2025DATA", withExtension: "csv") {
            return url
        }
        // Fallback: check Documents directory (allow user to sideload the CSV)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let docURL = docs?.appendingPathComponent("PFL2025DATA.csv"), FileManager.default.fileExists(atPath: docURL.path) {
            return docURL
        }
        if verboseLogs { print("📄 ContractImporter: CSV not found (bundle or documents)") }
        return nil
    }

    // Main entry: read and apply to teams
    @MainActor
    static func applyContracts(from url: URL, to teams: inout [LeagueTeam]) {
        guard let data = try? Data(contentsOf: url), let csv = String(data: data, encoding: .utf8) else {
            if verboseLogs { print("❌ ContractImporter: Failed to read CSV at \(url)") }
            return
        }

        let mapper = CSVMapper()
        let map = mapper.parse(csv: csv)
        if verboseLogs { print("📄 ContractImporter: Parsed entries for \(map.count) teams") }

        // Apply to rosters
        for i in 0..<teams.count {
            var team = teams[i]
            let key = normalizedTeamKey(fromInternal: team.logoName)
            guard let teamEntries = map[key] else { continue }

            var updatedPlayers: [PlayerData] = []
            updatedPlayers.reserveCapacity(team.players.count)

            for p in team.players {
                let pk = PlayerKey(first: p.firstName, last: p.lastName, jersey: p.number)
                if let entry = teamEntries[pk] {
                    let minSalary = 750_000
                    let salary = entry.salary.map { max($0, minSalary) }
                    let updated = p.with(actualSalary: salary, development: entry.development)
                    updatedPlayers.append(updated)
                } else {
                    updatedPlayers.append(p)
                }
            }

            team.players = updatedPlayers
            teams[i] = team
        }
    }

    // Normalize team names from CSV to internal keys
    nonisolated static func normalizedTeamKey(fromCSV team: String) -> String {
        let t = team.trimmingCharacters(in: .whitespacesAndNewlines)
        let map: [String: String] = [
            "Los Angeles N": "LAN",
            "Los Angeles A": "LAA",
            "New York A": "NYA",
            "New York N": "NYN",
            "Green Bay": "GreenBay",
            "New England": "NewEngland",
            "San Francisco": "SanFrancisco",
            "Tampa Bay": "TampaBay",
            "Kansas City": "KansasCity",
            "New Orleans": "NewOrleans"
        ]
        if let mapped = map[t] { return mapped }
        // Default: remove spaces
        return t.replacingOccurrences(of: " ", with: "")
    }

    // Convert internal key to same canonical used above to look up entries
    nonisolated static func normalizedTeamKey(fromInternal key: String) -> String {
        // Already using internal keys like "LAN", "LAA", "NYA", "NYN", "GreenBay", etc.
        return key
    }

    // MARK: - CSV mapping
    struct PlayerKey: Hashable {
        let first: String
        let last: String
        let jersey: Int
    }

    struct CSVMapper {
        func parse(csv: String) -> [String: [PlayerKey: Entry]] {
            var result: [String: [PlayerKey: Entry]] = [:]
            let lines = csv.split(whereSeparator: { $0.isNewline })
            guard let headerLine = lines.first else { return result }
            let headers = headerLine.split(separator: ",").map { String($0) }

            // Column indices we care about
            let idxFirst = headers.firstIndex(of: "firstName")
            let idxLast = headers.firstIndex(of: "lastName")
            let idxTeam = headers.firstIndex(of: "Team")
            let idxJersey = headers.firstIndex(of: "jerseyNum")
            let idxYears = headers.firstIndex(of: "contractYears")
            let idxTotalM = headers.firstIndex(of: "contractTotalValue_M")
            let idxApyM = headers.firstIndex(of: "contractAPY_M")
            let idxDev = headers.firstIndex(of: "Development")

            // Fast exit if essential columns missing
            guard let iF = idxFirst, let iL = idxLast, let iT = idxTeam, let iJ = idxJersey else { return result }

            for line in lines.dropFirst() {
                // Simple split — dataset doesn't include quoted commas in the name fields
                let cols = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
                if cols.count <= max(iF, iL, iT, iJ) { continue }

                let first = cols[safe: iF] ?? ""
                let last = cols[safe: iL] ?? ""
                let csvTeam = cols[safe: iT] ?? ""
                let teamKey = normalizedTeamKey(fromCSV: csvTeam)
                guard let jersey = Int(cols[safe: iJ] ?? "") else { continue }

                // Salary normalization — CSV may provide values in dollars, thousands, or millions.
                let apyRaw = ContractImporter.parseDouble(cols[safe: idxApyM])
                let years = ContractImporter.parseDouble(cols[safe: idxYears])
                let totalRaw = ContractImporter.parseDouble(cols[safe: idxTotalM])
                let salaryDollars: Int? = {
                    if let apy = apyRaw { return ContractImporter.toDollars(fromMixedCSVUnit: apy) }
                    if let t = totalRaw, let y = years, y > 0 { return ContractImporter.toDollars(fromMixedCSVUnit: t / y) }
                    return nil
                }()

                let devRaw = cols[safe: idxDev]?.trimmingCharacters(in: .whitespacesAndNewlines)
                let dev = (devRaw?.isEmpty == true) ? nil : devRaw

                var dict = result[teamKey] ?? [:]
                dict[PlayerKey(first: first, last: last, jersey: jersey)] = Entry(salary: salaryDollars, development: dev)
                result[teamKey] = dict
            }
            return result
        }
    }

    // MARK: - Build full rosters from PFL2025DATA.csv (use CSV as the ONLY source)
    nonisolated static func buildRosters(from url: URL) -> [String: [PlayerData]] {
        guard let data = try? Data(contentsOf: url), let csv = String(data: data, encoding: .utf8) else {
            if verboseLogs { print("❌ ContractImporter: Failed to read CSV for rosters at \(url)") }
            return [:]
        }

        var result: [String: [PlayerData]] = [:]
        let lines = csv.split(whereSeparator: { $0.isNewline })
        guard let headerLine = lines.first else { return result }
        let headers = headerLine.split(separator: ",").map { String($0) }

        // Column indices
        let iF = headers.firstIndex(of: "firstName")
        let iL = headers.firstIndex(of: "lastName")
        let iT = headers.firstIndex(of: "Team")
        let iPos = headers.firstIndex(of: "Position")
        let iAge = headers.firstIndex(of: "age")
        let iOverall = headers.firstIndex(of: "overallRating")
        let iJersey = headers.firstIndex(of: "jerseyNum")
        let iHeight = headers.firstIndex(of: "height")
        let idxYears = headers.firstIndex(of: "contractYears")
        let idxTotalM = headers.firstIndex(of: "contractTotalValue_M")
        let idxApyM = headers.firstIndex(of: "contractAPY_M")
        let idxDev = headers.firstIndex(of: "Development")

        guard let cF = iF, let cL = iL, let cT = iT, let cPos = iPos, let cAge = iAge, let cOverall = iOverall, let cJersey = iJersey else {
            if verboseLogs { print("❌ ContractImporter: Missing required columns for roster build") }
            return result
        }

        for line in lines.dropFirst() {
            let cols = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
            if cols.count <= max(cF, cL, cT, cPos, cAge, cOverall, cJersey) { continue }

            let first = cols[safe: cF] ?? ""
            let last = cols[safe: cL] ?? ""
            let csvTeam = cols[safe: cT] ?? ""
            let pos = cols[safe: cPos] ?? ""
            let age = parseInt(cols[safe: cAge]) ?? 24
            let overall = parseInt(cols[safe: cOverall]) ?? 75
            guard let jersey = parseInt(cols[safe: cJersey]) else { continue }
            let heightInches = parseHeightToInches(cols[safe: iHeight]) ?? 72

            // Salary normalization — CSV may be dollars or millions. Convert to dollars.
            let apyRaw = parseDouble(cols[safe: idxApyM])
            let years = parseDouble(cols[safe: idxYears])
            let totalRaw = parseDouble(cols[safe: idxTotalM])
            let salaryDollars: Int? = {
                if let apy = apyRaw { return ContractImporter.toDollars(fromMixedCSVUnit: apy) }
                if let t = totalRaw, let y = years, y > 0 { return ContractImporter.toDollars(fromMixedCSVUnit: t / y) }
                return nil
            }()

            let devRaw = cols[safe: idxDev]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let dev = (devRaw?.isEmpty == true) ? nil : devRaw

            let teamKey = normalizedTeamKey(fromCSV: csvTeam)
            var players = result[teamKey] ?? []
            players.append(PlayerData(
                firstName: first,
                lastName: last,
                position: pos,
                number: jersey,
                overall: overall,
                age: age,
                actualSalary: salaryDollars,
                height: heightInches,
                development: dev
            ))
            result[teamKey] = players
        }

        if verboseLogs {
            let totals = result.mapValues { $0.count }
            print("📄 ContractImporter: Built CSV rosters for \(totals.count) teams → sizes: \(totals)")
        }
        return result
    }
}

// MARK: - Safe subscript helper
nonisolated private extension Array where Element == String {
    subscript(safe index: Int?) -> String? {
        guard let i = index, i >= 0, i < count else { return nil }
        return self[i]
    }
}

// MARK: - Parsing helpers
nonisolated private extension ContractImporter {
    static func parseDouble(_ s: String?) -> Double? {
        guard let s else { return nil }
        let cleaned = s
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "M", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }

    /// Converts a CSV numeric that may be expressed as dollars or millions into dollars.
    /// Heuristic: values < 1000 are treated as millions; larger numbers are assumed dollars already.
    static func toDollars(fromMixedCSVUnit value: Double) -> Int {
        if value < 1_000 { // e.g., 1.25 → $1.25M
            return Int((value * 1_000_000.0).rounded())
        } else {
            return Int(value.rounded())
        }
    }

    static func parseInt(_ s: String?) -> Int? {
        guard let s else { return nil }
        let cleaned = s.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(cleaned)
    }

    static func parseHeightToInches(_ s: String?) -> Int? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        // Accept formats like 6'2" or 6-2 or 74
        if let inches = Int(s) { return inches }
        var feet = 0, inches = 0
        let str = s.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "’", with: "'")
        if let quoteIdx = str.firstIndex(of: "'") {
            let f = String(str[..<quoteIdx])
            let rest = String(str[str.index(after: quoteIdx)...])
            feet = Int(f.trimmingCharacters(in: .whitespaces)) ?? 0
            inches = Int(rest.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")) ?? 0
        } else if str.contains("-") {
            let comps = str.split(separator: "-")
            if comps.count == 2 {
                feet = Int(comps[0]) ?? 0
                inches = Int(comps[1]) ?? 0
            }
        }
        return feet > 0 ? (feet * 12 + inches) : nil
    }
}


