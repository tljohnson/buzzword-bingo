import Foundation

let path = CommandLine.arguments.dropFirst().first ?? "build/coverage.json"
let data = try Data(contentsOf: URL(fileURLWithPath: path))
let report = try JSONSerialization.jsonObject(with: data) as! [String: Any]
let targets = report["targets"] as! [[String: Any]]
let files = targets.flatMap { $0["files"] as? [[String: Any]] ?? [] }
let core = files.filter {
    let name = $0["name"] as? String ?? ""
    return ["GameEngine.swift", "GameStore.swift"].contains(name)
}
guard core.count == 2 else { fatalError("Expected engine and store coverage") }
let executable = core.reduce(0) { $0 + ($1["executableLines"] as? Int ?? 0) }
let covered = core.reduce(0) { $0 + ($1["coveredLines"] as? Int ?? 0) }
let coverage = executable > 0 ? Double(covered) / Double(executable) : 0
print(String(format: "Core line coverage: %.2f%% (%d/%d)", coverage * 100, covered, executable))
if coverage < 0.70 { exit(1) }
