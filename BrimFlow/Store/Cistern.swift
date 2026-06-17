import Foundation

protocol Cistern {
    func store(_ log: WatermarkLog)
    func brandSpillway(url: String, mode: String)
    func raisePrimedFlag()
    func draw() -> WatermarkLog
}

final class JSONCistern: Cistern {

    private let fm = FileManager.default
    private let basinDir: URL
    private let homeStore: UserDefaults
    private let suiteStore: UserDefaults

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.basinDir = docs.appendingPathComponent(BrimGazetteer.basinVault, isDirectory: true)
        if !fm.fileExists(atPath: basinDir.path) {
            try? fm.createDirectory(at: basinDir, withIntermediateDirectories: true)
        }
        self.homeStore = UserDefaults.standard
        self.suiteStore = UserDefaults(suiteName: BrimGazetteer.suiteBasin) ?? .standard
    }

    private var watermarkURL: URL {
        basinDir.appendingPathComponent(BrimGazetteer.watermarkFile)
    }

    func store(_ log: WatermarkLog) {
        let murky = MurkyWatermark(
            intake: murkDict(log.intake),
            tributaries: murkDict(log.tributaries),
            spillwayURL: log.spillwayURL,
            spillwayMode: log.spillwayMode,
            dry: log.dry,
            consentSealed: log.consentSealed,
            consentBreached: log.consentBreached,
            consentLoggedAt: log.consentLoggedAt
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        do {
            let data = try encoder.encode(murky)
            try data.write(to: watermarkURL, options: .atomic)
        } catch {
            print("\(BrimGazetteer.logRipple) Cistern store failed: \(error)")
        }

        suiteStore.set(log.consentSealed, forKey: BrimDictKey.consentSealed)
        suiteStore.set(log.consentBreached, forKey: BrimDictKey.consentBreached)
        if let date = log.consentLoggedAt {
            suiteStore.set(date.timeIntervalSince1970, forKey: BrimDictKey.consentLoggedAt)
        }
        homeStore.set(log.consentSealed, forKey: BrimDictKey.consentSealed)
        homeStore.set(log.consentBreached, forKey: BrimDictKey.consentBreached)
        if let date = log.consentLoggedAt {
            homeStore.set(date.timeIntervalSince1970, forKey: BrimDictKey.consentLoggedAt)
        }
    }

    func brandSpillway(url: String, mode: String) {
        suiteStore.set(url, forKey: BrimDictKey.spillwayURL)
        homeStore.set(url, forKey: BrimDictKey.spillwayURL)
        suiteStore.set(mode, forKey: BrimDictKey.spillwayMode)
    }

    func raisePrimedFlag() {
        suiteStore.set(true, forKey: BrimDictKey.primed)
        homeStore.set(true, forKey: BrimDictKey.primed)
    }

    func draw() -> WatermarkLog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        if fm.fileExists(atPath: watermarkURL.path),
           let data = try? Data(contentsOf: watermarkURL),
           let murky = try? decoder.decode(MurkyWatermark.self, from: data) {
            return WatermarkLog(
                intake: clearDict(murky.intake),
                tributaries: clearDict(murky.tributaries),
                spillwayURL: murky.spillwayURL,
                spillwayMode: murky.spillwayMode,
                dry: murky.dry,
                consentSealed: murky.consentSealed,
                consentBreached: murky.consentBreached,
                consentLoggedAt: murky.consentLoggedAt
            )
        }

        return drawFromDefaults()
    }

    private func drawFromDefaults() -> WatermarkLog {
        let spillwayURL = homeStore.string(forKey: BrimDictKey.spillwayURL)
            ?? suiteStore.string(forKey: BrimDictKey.spillwayURL)
        let spillwayMode = suiteStore.string(forKey: BrimDictKey.spillwayMode)
        let primed = suiteStore.bool(forKey: BrimDictKey.primed)

        let sealed = suiteStore.bool(forKey: BrimDictKey.consentSealed)
            || homeStore.bool(forKey: BrimDictKey.consentSealed)
        let breached = suiteStore.bool(forKey: BrimDictKey.consentBreached)
            || homeStore.bool(forKey: BrimDictKey.consentBreached)
        let loggedTs = suiteStore.double(forKey: BrimDictKey.consentLoggedAt)
        let loggedAt: Date? = loggedTs > 0 ? Date(timeIntervalSince1970: loggedTs) : nil

        return WatermarkLog(
            intake: [:],
            tributaries: [:],
            spillwayURL: spillwayURL,
            spillwayMode: spillwayMode,
            dry: !primed,
            consentSealed: sealed,
            consentBreached: breached,
            consentLoggedAt: loggedAt
        )
    }

    private func murkDict(_ dict: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (k, v) in dict { result[k] = murk(v) }
        return result
    }

    private func clearDict(_ dict: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (k, v) in dict { result[k] = clear(v) ?? v }
        return result
    }

    private func murk(_ input: String) -> String {
        let b64 = Data(input.utf8).base64EncodedString()
        return b64
            .replacingOccurrences(of: "+", with: "!")
            .replacingOccurrences(of: "/", with: "*")
    }

    private func clear(_ input: String) -> String? {
        let b64 = input
            .replacingOccurrences(of: "!", with: "+")
            .replacingOccurrences(of: "*", with: "/")
        guard let data = Data(base64Encoded: b64),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }
}

struct MurkyWatermark: Codable {
    let intake: [String: String]
    let tributaries: [String: String]
    let spillwayURL: String?
    let spillwayMode: String?
    let dry: Bool
    let consentSealed: Bool
    let consentBreached: Bool
    let consentLoggedAt: Date?
}
