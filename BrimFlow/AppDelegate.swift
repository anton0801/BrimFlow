import UIKit
import FirebaseCore
import FirebaseMessaging
import AppTrackingTransparency
import UserNotifications
import AppsFlyerLib

final class AppDelegate: UIResponder, UIApplicationDelegate {

    private lazy var sequencer = BootSequencer(host: self)

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        sequencer.runColdStages()

        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            sequencer.spillReaper.capture(remote)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onActivation),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    @objc private func onActivation() {
        sequencer.runWarmStage()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        messaging.token { token, err in
            guard err == nil, let t = token else { return }
            UserDefaults.standard.set(t, forKey: BrimDictKey.fcm)
            UserDefaults.standard.set(t, forKey: BrimDictKey.push)
            UserDefaults(suiteName: BrimGazetteer.suiteBasin)?.set(t, forKey: "shared_fcm")
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        sequencer.spillReaper.capture(notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        sequencer.spillReaper.capture(response.notification.request.content.userInfo)
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        sequencer.spillReaper.capture(userInfo)
        completionHandler(.newData)
    }
}

extension AppDelegate: AppsFlyerLibDelegate, DeepLinkDelegate {
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        sequencer.confluence.takeIntake(data)
    }

    func onConversionDataFail(_ error: Error) {
        sequencer.confluence.takeIntake([
            "error": true,
            "error_desc": error.localizedDescription
        ])
    }

    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status, let link = result.deepLink else { return }
        sequencer.confluence.takeTributaries(link.clickEvent)
    }
}

final class BootSequencer {

    private weak var host: AppDelegate?

    let confluence = ConfluenceDesk()
    let spillReaper = SpillReaper()

    init(host: AppDelegate) {
        self.host = host
    }

    func runColdStages() {
        configureStage()
        registerStage()
    }

    func runWarmStage() {
        activateStage()
    }

    private func configureStage() {
        FirebaseApp.configure()

        let sdk = AppsFlyerLib.shared()
        sdk.appsFlyerDevKey = BrimGazetteer.trackerKey
        sdk.appleAppID = BrimGazetteer.appCode
        sdk.delegate = host
        sdk.deepLinkDelegate = host
        sdk.isDebug = false
    }

    private func registerStage() {
        Messaging.messaging().delegate = host
        UNUserNotificationCenter.current().delegate = host
        UIApplication.shared.registerForRemoteNotifications()
    }

    private func activateStage() {
        if #available(iOS 14, *) {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    AppsFlyerLib.shared().start()
                    UserDefaults.standard.set(status.rawValue, forKey: "att_status")
                }
            }
        } else {
            AppsFlyerLib.shared().start()
        }
    }
}
