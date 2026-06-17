import Foundation
import AppsFlyerLib
import FirebaseCore
import FirebaseMessaging
import WebKit

protocol Conduit {
    func pump(cargo: [String: Any]) async throws -> String
}

final class HTTPConduit: Conduit {

    private let session: URLSession
    private let cadence: [Double] = [90.0, 180.0, 360.0]

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    private var browserAgent: String = WKWebView().value(forKey: "userAgent") as? String ?? ""

    func pump(cargo: [String: Any]) async throws -> String {
        guard let endpoint = URL(string: BrimGazetteer.backendWeir) else {
            throw Eddy.dryBed(at: "conduit.url")
        }

        var body: [String: Any] = cargo
        body["os"] = "iOS"
        body["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        body["bundle_id"] = Bundle.main.bundleIdentifier ?? ""
        body["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        body["store_id"] = "id\(BrimGazetteer.appCode)"
        body["push_token"] = UserDefaults.standard.string(forKey: BrimDictKey.push)
            ?? Messaging.messaging().fcmToken
        body["locale"] = Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(browserAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var lastEddy: Error?

        for (idx, pause) in cadence.enumerated() {
            do {
                return try await singlePump(request)
            } catch let eddy as Eddy {
                if eddy.isSealed {
                    throw eddy
                }
                if case .flumeJammed(let coolDown) = eddy {
                    try await Task.sleep(nanoseconds: UInt64(coolDown * 1_000_000_000))
                    continue
                }
                lastEddy = eddy
                if idx < cadence.count - 1 {
                    try await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
                }
            } catch {
                lastEddy = error
                if idx < cadence.count - 1 {
                    try await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
                }
            }
        }

        if let lastEddy = lastEddy {
            throw lastEddy
        }
        throw Eddy.currentLost(stage: "conduit.exhausted")
    }

    private func singlePump(_ request: URLRequest) async throws -> String {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw Eddy.currentLost(stage: "conduit.response")
        }

        if http.statusCode == 404 {
            throw Eddy.weirSealed(httpCode: 404)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Eddy.siltedTelemetry(at: "conduit.json")
        }

        guard let ok = json["ok"] as? Bool else {
            throw Eddy.siltedTelemetry(at: "conduit.missingOk")
        }

        if !ok {
            throw Eddy.lockClosed(reason: "okFalse")
        }

        guard let url = json["url"] as? String, !url.isEmpty else {
            throw Eddy.siltedTelemetry(at: "conduit.missingURL")
        }

        return url
    }
}
