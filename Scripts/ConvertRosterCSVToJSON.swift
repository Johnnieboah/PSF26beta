#!/usr/bin/env swift
import Foundation

// Roster CSV → JSON converter
// Usage:
//   swift Scripts/ConvertRosterCSVToJSON.swift --csv /abs/path/PFL2025DATA.csv --out /abs/path/Roster2025.json
// If args omitted, defaults to:
//   CSV:  /Users/jd/Documents/PSF26/PFL2025DATA.csv
//   JSON: /Users/jd/Documents/PSF26/PSF26/Roster2025.json

struct PlayerAttributes: Codable {
    let speed: Int?
    let agility: Int?
    let awareness: Int?
    let strength: Int?
    let stamina: Int?
    let injury: Int?

    let carrying: Int?
    let trucking: Int?
    let catching: Int?
    let breakTackle: Int?
    let jukeMove: Int?
    let spinMove: Int?
    let stiffArm: Int?
    let acceleration: Int?
    let changeOfDirection: Int?

    let throwPower: Int?
    let throwAccuracyShort: Int?
    let throwAccuracyMid: Int?
    let throwAccuracyDeep: Int?
    let throwOnTheRun: Int?
    let throwUnderPressure: Int?
    let playAction: Int?

    let tackle: Int?
    let blockShedding: Int?
    let zoneCoverage: Int?
    let manCoverage: Int?
    let pursuit: Int?
    let finesseMoves: Int?
    let powerMoves: Int?
    let press: Int?
    let jumping: Int?

    let passBlock: Int?
    let runBlock: Int?
    let impactBlocking: Int?

    let kickPower: Int?
    let kickAccuracy: Int?

    let release: Int?
    let catchInTraffic: Int?
    let spectacularCatch: Int?

    let shortRouteRunning: Int?
    let mediumRouteRunning: Int?
    let deepRouteRunning: Int?

    let playRecognition: Int?
    let toughness: Int?
    let hitPower: Int?
    let bCVision: Int?
    let passBlockPower: Int?
    let runBlockPower: Int?
    let passBlockFinesse: Int?
    let runBlockFinesse: Int?
}

struct Player: Codable {
    // Match MasterPlayer coding keys
    let firstName: String
    let lastName: String
    var position: String
    let team: String
    let college: String
    let age: String
    let overall: String
    let height: String
    let weight: String
    let handedness: String
    let jerseyNum: String
    let yearsPro: String
    let history: [String]
    let attributes: PlayerAttributes
    let actualSalary: Int?
}

func parseArgs() -> (csvPath: String, outPath: String) {
    var csv: String = "/Users/jd/Documents/PSF26/PFL2025DATA_FINAL_CORRECTED.csv"
    var out: String = "/Users/jd/Documents/PSF26/PSF26/Roster2025.json"
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--csv":
            if let v = iterator.next() { csv = v }
        case "--out":
            if let v = iterator.next() { out = v }
        default:
            break
        }
    }
    return (csv, out)
}

let teamFullNameMap: [String: String] = [
    // AFC
    "Baltimore": "Baltimore Ravens",
    "Buffalo": "Buffalo Bills",
    "Cincinnati": "Cincinnati Bengals",
    "Cleveland": "Cleveland Browns",
    "Denver": "Denver Broncos",
    "Houston": "Houston Texans",
    "Indianapolis": "Indianapolis Colts",
    "Jacksonville": "Jacksonville Jaguars",
    "Kansas City": "Kansas City Chiefs",
    "Las Vegas": "Las Vegas Raiders",
    "Los Angeles A": "Los Angeles Chargers", // A = AFC
    "Miami": "Miami Dolphins",
    "New England": "New England Patriots",
    "New York A": "New York Jets",          // A = AFC
    "Pittsburgh": "Pittsburgh Steelers",
    "Tennessee": "Tennessee Titans",

    // NFC
    "Arizona": "Arizona Cardinals",
    "Atlanta": "Atlanta Falcons",
    "Carolina": "Carolina Panthers",
    "Chicago": "Chicago Bears",
    "Dallas": "Dallas Cowboys",
    "Detroit": "Detroit Lions",
    "Green Bay": "Green Bay Packers",
    "Los Angeles N": "Los Angeles Rams",     // N = NFC
    "Minnesota": "Minnesota Vikings",
    "New Orleans": "New Orleans Saints",
    "New York N": "New York Giants",         // N = NFC
    "Philadelphia": "Philadelphia Eagles",
    "San Francisco": "San Francisco 49ers",
    "Seattle": "Seattle Seahawks",
    "Tampa Bay": "Tampa Bay Buccaneers",
    "Washington": "Washington Commanders"
]

func mapTeam(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if let mapped = teamFullNameMap[trimmed] { return mapped }
    return teamFullNameMap.first { key, _ in key.caseInsensitiveCompare(trimmed) == .orderedSame }?.value
}

func mapHandedness(_ raw: String) -> String {
    // Jay: 1 = Right, 0 = Left. Default Right if unknown
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if t == "0" { return "Left" }
    if t == "1" { return "Right" }
    return "Right"
}

func intAt(_ cols: [String], _ index: Int?) -> Int? {
    guard let i = index, i >= 0, i < cols.count else { return nil }
    let v = cols[i].trimmingCharacters(in: .whitespacesAndNewlines)
    return Int(v)
}

func strAt(_ cols: [String], _ index: Int?, default def: String = "") -> String {
    guard let i = index, i >= 0, i < cols.count else { return def }
    return cols[i].trimmingCharacters(in: .whitespacesAndNewlines)
}

func loadCSV(_ path: String) throws -> (header: [String], rows: [[String]]) {
    let data = try String(contentsOfFile: path, encoding: .utf8)
    var lines = data.split(whereSeparator: { $0.isNewline }).map(String.init)
    guard !lines.isEmpty else { return ([], []) }
    let header = lines.removeFirst().split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
    let rows = lines.map { line in
        line.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
    }
    return (header, rows)
}

func indexMap(_ header: [String]) -> [String: Int] {
    var map: [String: Int] = [:]
    for (i, key) in header.enumerated() { map[key] = i }
    return map
}

func makeAttributes(cols: [String], idx: [String: Int]) -> PlayerAttributes {
    func gi(_ k: String) -> Int? { intAt(cols, idx[k]) }
    return PlayerAttributes(
        speed: gi("stats/speed/value"),
        agility: gi("stats/agility/value"),
        awareness: gi("stats/awareness/value"),
        strength: gi("stats/strength/value"),
        stamina: gi("stats/stamina/value"),
        injury: gi("stats/injury/value"),
        carrying: gi("stats/carrying/value"),
        trucking: gi("stats/trucking/value"),
        catching: gi("stats/catching/value"),
        breakTackle: gi("stats/breakTackle/value"),
        jukeMove: gi("stats/jukeMove/value"),
        spinMove: gi("stats/spinMove/value"),
        stiffArm: gi("stats/stiffArm/value"),
        acceleration: gi("stats/acceleration/value"),
        changeOfDirection: gi("stats/changeOfDirection/value"),
        throwPower: gi("stats/throwPower/value"),
        throwAccuracyShort: gi("stats/throwAccuracyShort/value"),
        throwAccuracyMid: gi("stats/throwAccuracyMid/value"),
        throwAccuracyDeep: gi("stats/throwAccuracyDeep/value"),
        throwOnTheRun: gi("stats/throwOnTheRun/value"),
        throwUnderPressure: gi("stats/throwUnderPressure/value"),
        playAction: gi("stats/playAction/value"),
        tackle: gi("stats/tackle/value"),
        blockShedding: gi("stats/blockShedding/value"),
        zoneCoverage: gi("stats/zoneCoverage/value"),
        manCoverage: gi("stats/manCoverage/value"),
        pursuit: gi("stats/pursuit/value"),
        finesseMoves: gi("stats/finesseMoves/value"),
        powerMoves: gi("stats/powerMoves/value"),
        press: gi("stats/press/value"),
        jumping: gi("stats/jumping/value"),
        passBlock: gi("stats/passBlock/value"),
        runBlock: gi("stats/runBlock/value"),
        impactBlocking: gi("stats/impactBlocking/value"),
        kickPower: gi("stats/kickPower/value"),
        kickAccuracy: gi("stats/kickAccuracy/value"),
        release: gi("stats/release/value"),
        catchInTraffic: gi("stats/catchInTraffic/value"),
        spectacularCatch: gi("stats/spectacularCatch/value"),
        shortRouteRunning: gi("stats/shortRouteRunning/value"),
        mediumRouteRunning: gi("stats/mediumRouteRunning/value"),
        deepRouteRunning: gi("stats/deepRouteRunning/value"),
        playRecognition: gi("stats/playRecognition/value"),
        toughness: gi("stats/toughness/value"),
        hitPower: gi("stats/hitPower/value"),
        bCVision: gi("stats/bCVision/value"),
        passBlockPower: gi("stats/passBlockPower/value"),
        runBlockPower: gi("stats/runBlockPower/value"),
        passBlockFinesse: gi("stats/passBlockFinesse/value"),
        runBlockFinesse: gi("stats/runBlockFinesse/value")
    )
}

func buildPlayer(cols: [String], idx: [String: Int]) -> Player? {
    let f = strAt(cols, idx["firstName"])
    let l = strAt(cols, idx["lastName"])
    let teamRaw = strAt(cols, idx["Team"])
    guard !f.isEmpty, !l.isEmpty, !teamRaw.isEmpty, let fullTeam = mapTeam(teamRaw) else { return nil }
    let position = strAt(cols, idx["Position"]) // cleaned later in-app
    let college = strAt(cols, idx["college"], default: "Unknown")
    let age = strAt(cols, idx["age"], default: "25")
    let overall = strAt(cols, idx["overallRating"], default: "50")
    let height = strAt(cols, idx["height"], default: "72")
    let weight = strAt(cols, idx["weight"], default: "200")
    let handedness = mapHandedness(strAt(cols, idx["handedness"], default: "1"))
    let jersey = strAt(cols, idx["jerseyNum"], default: "0")
    let yearsPro = strAt(cols, idx["yearsPro"], default: "0")
    let attrs = makeAttributes(cols: cols, idx: idx)
    // Salary: use APY (millions) when available, else current-year as APY, convert to dollars
    var actualSalary: Int? = nil
    if let apyM = Double(strAt(cols, idx["contractAPY_M"])) {
        actualSalary = Int(apyM * 1_000_000.0)
    } else if let totalM = Double(strAt(cols, idx["contractTotalValue_M"])) , let years = Int(strAt(cols, idx["contractYears"])) , years > 0 {
        actualSalary = Int((totalM * 1_000_000.0) / Double(years))
    }
    return Player(
        firstName: f,
        lastName: l,
        position: position,
        team: fullTeam,
        college: college,
        age: age,
        overall: overall,
        height: height,
        weight: weight,
        handedness: handedness,
        jerseyNum: jersey,
        yearsPro: yearsPro,
        history: [],
        attributes: attrs,
        actualSalary: actualSalary
    )
}

func main() throws {
    let (csvPath, outPath) = parseArgs()
    let (header, rows) = try loadCSV(csvPath)
    if header.isEmpty { throw NSError(domain: "CSV", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty CSV header"]) }
    let idx = indexMap(header)

    var roster: [String: [Player]] = [:] // fullTeamName -> players
    var kept = 0
    var skipped = 0

    for cols in rows {
        guard let p = buildPlayer(cols: cols, idx: idx) else {
            skipped += 1
            continue
        }
        roster[p.team, default: []].append(p)
        kept += 1
    }

    // Sort players within teams by overall desc then lastName asc for readability
    for (team, players) in roster {
        let sorted = players.sorted { (a, b) -> Bool in
            let oa = Int(a.overall) ?? 0
            let ob = Int(b.overall) ?? 0
            if oa != ob { return oa > ob }
            if a.lastName != b.lastName { return a.lastName < b.lastName }
            return a.firstName < b.firstName
        }
        roster[team] = sorted
    }

    // Ensure output directory exists
    let outURL = URL(fileURLWithPath: outPath)
    try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(roster)
    try data.write(to: outURL, options: .atomic)

    FileHandle.standardError.write(Data("\n✅ Roster JSON written: \(outURL.path)\n📊 Players kept: \(kept), skipped: \(skipped)\n\n".utf8))
}

do { try main() } catch {
    FileHandle.standardError.write(Data("❌ Conversion failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}


