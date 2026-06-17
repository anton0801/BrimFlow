import SwiftUI

@main
struct BrimFlowApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegateApp

    var body: some Scene {
        WindowGroup {
            SplashView()
        }
    }
}

final class ConfluenceDesk {

    private var intakeBuffer: [AnyHashable: Any] = [:]
    private var tributaryBuffer: [AnyHashable: Any] = [:]
    private var fuseTimer: Timer?

    func takeIntake(_ data: [AnyHashable: Any]) {
        intakeBuffer = data
        scheduleFuse()
        if !tributaryBuffer.isEmpty { performFuse() }
    }

    func takeTributaries(_ data: [AnyHashable: Any]) {
        guard !UserDefaults.standard.bool(forKey: BrimDictKey.primed) else { return }
        tributaryBuffer = data
        NotificationCenter.default.post(
            name: .tributariesArrived,
            object: nil,
            userInfo: ["deeplinksData": data]
        )
        fuseTimer?.invalidate()
        if !intakeBuffer.isEmpty { performFuse() }
    }

    private func scheduleFuse() {
        fuseTimer?.invalidate()
        fuseTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.performFuse()
        }
    }

    private func performFuse() {
        var combined = intakeBuffer
        for (k, v) in tributaryBuffer {
            let prefixed = "deep_\(k)"
            if combined[prefixed] == nil {
                combined[prefixed] = v
            }
        }
        NotificationCenter.default.post(
            name: .intakeArrived,
            object: nil,
            userInfo: ["conversionData": combined]
        )
    }
}

final class SpillReaper {

    func capture(_ payload: [AnyHashable: Any]) {
        guard let url = extract(payload) else { return }
        UserDefaults.standard.set(url, forKey: BrimDictKey.pushURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            NotificationCenter.default.post(
                name: .downspoutURL,
                object: nil,
                userInfo: ["temp_url": url]
            )
        }
    }

    private func extract(_ payload: [AnyHashable: Any]) -> String? {
        if let direct = payload["url"] as? String { return direct }
        if let nested = payload["data"] as? [String: Any],
           let url = nested["url"] as? String { return url }
        if let aps = payload["aps"] as? [String: Any],
           let nested = aps["data"] as? [String: Any],
           let url = nested["url"] as? String { return url }
        if let custom = payload["custom"] as? [String: Any],
           let url = custom["url"] as? String { return url }
        return nil
    }
}
