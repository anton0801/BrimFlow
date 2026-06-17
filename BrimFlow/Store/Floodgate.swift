import Foundation
import UIKit
import UserNotifications

protocol Floodgate {
    func liftBarrier() async -> Bool
    func wireDownspout()
}

final class NotificationFloodgate: Floodgate {

    func liftBarrier() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let weir = SingleWeir()
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, error in
                if let error = error {
                    print("\(BrimGazetteer.logRipple) Floodgate error: \(error)")
                }
                DispatchQueue.main.async {
                    guard weir.trySpill() else { return }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func wireDownspout() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

final class SingleWeir {
    private var spilled = false
    private let lock = NSLock()

    func trySpill() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !spilled else { return false }
        spilled = true
        return true
    }
}
