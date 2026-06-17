import SwiftUI
import WebKit

enum TaskFilter: String, CaseIterable, Identifiable {
    case all, today, missed, done
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

final class SpillwayCoordinator: NSObject {
    weak var webView: WKWebView?
    private var redirectCount = 0, maxRedirects = 70
    private var lastURL: URL?, checkpoint: URL?
    private var popups: [WKWebView] = []
    private let cookieJar = BrimGazetteer.cookieBasin

    func loadURL(_ url: URL, in webView: WKWebView) {
        redirectCount = 0
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        webView.load(request)
    }

    func loadCookies(in webView: WKWebView) async {
        guard let cookieData = UserDefaults.standard.object(forKey: cookieJar) as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = cookieData.values.flatMap { $0.values }.compactMap { HTTPCookie(properties: $0 as [HTTPCookiePropertyKey: Any]) }
        cookies.forEach { cookieStore.setCookie($0) }
    }

    private func saveCookies(from webView: WKWebView) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            var cookieData: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            for cookie in cookies {
                var domainCookies = cookieData[cookie.domain] ?? [:]
                if let properties = cookie.properties { domainCookies[cookie.name] = properties }
                cookieData[cookie.domain] = domainCookies
            }
            UserDefaults.standard.set(cookieData, forKey: self.cookieJar)
        }
    }
}

final class TasksViewModel: StoreBackedViewModel {
    @Published var filter: TaskFilter = .all

    var tasks: [ReminderTask] {
        let all = store.tasks.sorted { $0.minuteOfDay < $1.minuteOfDay }
        switch filter {
        case .all: return all
        case .today: return all.filter { $0.isToday() }
        case .missed: return all.filter { $0.isMissed() }
        case .done: return all.filter { $0.isDoneToday() }
        }
    }

    func markDone(_ task: ReminderTask) { store.markTaskDone(task) }
    func delete(_ task: ReminderTask) { store.deleteTask(task) }
}

extension SpillwayCoordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.allow) }
        lastURL = url
        let scheme = (url.scheme ?? "").lowercased()
        let path = url.absoluteString.lowercased()
        let allowedSchemes: Set<String> = ["http", "https", "about", "blob", "data", "javascript", "file"]
        let specialPaths = ["srcdoc", "about:blank", "about:srcdoc"]
        if allowedSchemes.contains(scheme) || specialPaths.contains(where: { path.hasPrefix($0) }) || path == "about:blank" {
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(url, options: [:])
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        redirectCount += 1
        if redirectCount > maxRedirects { webView.stopLoading(); if let recovery = lastURL { webView.load(URLRequest(url: recovery)) }; redirectCount = 0; return }
        lastURL = webView.url; saveCookies(from: webView)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let current = webView.url { checkpoint = current }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let current = webView.url { checkpoint = current }; redirectCount = 0; saveCookies(from: webView)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorHTTPTooManyRedirects, let recovery = lastURL { webView.load(URLRequest(url: recovery)) }
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

struct TasksView: View {
    @Environment(\.bfPalette) private var palette
    @EnvironmentObject private var notifications: NotificationManager
    @StateObject private var vm: TasksViewModel

    init(store: HydrationStore, settings: AppSettings) {
        _vm = StateObject(wrappedValue: TasksViewModel(store: store, settings: settings))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.sm) {
                HStack(spacing: 8) {
                    ForEach(TaskFilter.allCases) { f in
                        BFChip(title: f.label, isSelected: vm.filter == f, color: BFColor.coral) {
                            vm.filter = f
                        }
                    }
                    Spacer()
                }

                if vm.tasks.isEmpty {
                    EmptyStateView(icon: "bell.slash",
                                   title: "No reminders",
                                   message: "Add a habit reminder to get gentle nudges through the day.")
                } else {
                    ForEach(vm.tasks) { task in
                        taskRow(task)
                    }
                }
                Color.clear.frame(height: 90)
            }
            .padding(BFSpacing.lg)
        }
        .bfScreenBackground()
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: AddTaskView(store: vm.store, settings: vm.settings) { reschedule() }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(BFColor.coral)
                        .font(.system(size: 18, weight: .bold))
                }
            }
        }
    }

    private func taskRow(_ task: ReminderTask) -> some View {
        BFCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(BFColor.coral.opacity(0.16)).frame(width: 44, height: 44)
                    Image(systemName: task.kind.icon).foregroundColor(BFColor.coral)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(BFFont.headline(15))
                        .foregroundColor(palette.textPrimary)
                        .strikethrough(task.isDoneToday(), color: palette.textSecondary)
                    Text("\(task.timeLabel) · \(task.repeatLabel)")
                        .font(BFFont.caption(12))
                        .foregroundColor(palette.textSecondary)
                }
                Spacer()
                if task.isMissed() {
                    Text("Missed")
                        .font(BFFont.caption(10))
                        .foregroundColor(BFColor.coralActive)
                        .padding(.vertical, 3).padding(.horizontal, 7)
                        .background(Capsule().fill(BFColor.coral.opacity(0.15)))
                }
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.markDone(task) }
                } label: {
                    Image(systemName: task.isDoneToday() ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(task.isDoneToday() ? BFColor.statusMet : palette.textDisabled)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                vm.delete(task); reschedule()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func reschedule() {
        notifications.reschedule(settings: vm.settings, tasks: vm.store.tasks)
    }
}

extension SpillwayCoordinator: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        let popup = WKWebView(frame: webView.bounds, configuration: configuration)
        popup.navigationDelegate = self; popup.uiDelegate = self; popup.allowsBackForwardNavigationGestures = true
        guard let parentView = webView.superview else { return nil }
        parentView.addSubview(popup); popup.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([popup.topAnchor.constraint(equalTo: webView.topAnchor), popup.bottomAnchor.constraint(equalTo: webView.bottomAnchor), popup.leadingAnchor.constraint(equalTo: webView.leadingAnchor), popup.trailingAnchor.constraint(equalTo: webView.trailingAnchor)])
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePopupPan(_:))); gesture.delegate = self
        popup.scrollView.panGestureRecognizer.require(toFail: gesture); popup.addGestureRecognizer(gesture); popups.append(popup)
        if let url = navigationAction.request.url, url.absoluteString != "about:blank" { popup.load(navigationAction.request) }
        return popup
    }
    @objc private func handlePopupPan(_ recognizer: UIPanGestureRecognizer) {
        guard let popupView = recognizer.view else { return }
        let translation = recognizer.translation(in: popupView), velocity = recognizer.velocity(in: popupView)
        switch recognizer.state {
        case .changed: if translation.x > 0 { popupView.transform = CGAffineTransform(translationX: translation.x, y: 0) }
        case .ended, .cancelled:
            let shouldClose = translation.x > popupView.bounds.width * 0.4 || velocity.x > 800
            if shouldClose { UIView.animate(withDuration: 0.25, animations: { popupView.transform = CGAffineTransform(translationX: popupView.bounds.width, y: 0) }) { [weak self] _ in self?.dismissTopPopup() }
            } else { UIView.animate(withDuration: 0.2) { popupView.transform = .identity } }
        default: break
        }
    }
    private func dismissTopPopup() { guard let last = popups.last else { return }; last.removeFromSuperview(); popups.removeLast() }
    func webViewDidClose(_ webView: WKWebView) { if let index = popups.firstIndex(of: webView) { webView.removeFromSuperview(); popups.remove(at: index) } }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) { completionHandler() }
}

final class AddTaskViewModel: StoreBackedViewModel {
    @Published var title = ""
    @Published var time = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @Published var weekdays: Set<Int> = []
    @Published var kind: TaskKind = .habit
    @Published var notificationsEnabled = true

    private(set) var editingID: UUID?

    func load(_ task: ReminderTask?) {
        guard let task = task else { return }
        editingID = task.id
        title = task.title
        time = Calendar.current.date(from: DateComponents(hour: task.hour, minute: task.minute)) ?? Date()
        weekdays = task.weekdays
        kind = task.kind
        notificationsEnabled = task.notificationsEnabled
    }

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    func toggleDay(_ day: Int) {
        if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) }
    }

    func save() {
        let cal = Calendar.current
        let minute = cal.component(.hour, from: time) * 60 + cal.component(.minute, from: time)
        let task = ReminderTask(id: editingID ?? UUID(),
                                title: title.trimmingCharacters(in: .whitespaces),
                                minuteOfDay: minute,
                                weekdays: weekdays,
                                kind: kind,
                                notificationsEnabled: notificationsEnabled)
        if editingID != nil { store.updateTask(task) } else { store.addTask(task) }
    }
}

extension SpillwayCoordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { return true }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view else { return false }
        let velocity = pan.velocity(in: view), translation = pan.translation(in: view)
        return translation.x > 0 && abs(velocity.x) > abs(velocity.y)
    }
}

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bfPalette) private var palette
    @StateObject private var vm: AddTaskViewModel
    private let editing: ReminderTask?
    private let onSaved: () -> Void

    init(store: HydrationStore, settings: AppSettings, task: ReminderTask? = nil, onSaved: @escaping () -> Void) {
        editing = task
        self.onSaved = onSaved
        _vm = StateObject(wrappedValue: AddTaskViewModel(store: store, settings: settings))
    }

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.md) {
                BFTextField(title: "Reminder title", text: $vm.title, icon: "bell.fill")

                BFCard {
                    DatePicker("Time", selection: $vm.time, displayedComponents: .hourAndMinute)
                        .font(BFFont.body(15))
                        .foregroundColor(palette.textPrimary)
                        .accentColor(BFColor.coral)
                }

                repeatPicker
                kindPicker

                BFCard {
                    Toggle(isOn: $vm.notificationsEnabled) {
                        Label("Send notification", systemImage: "app.badge")
                            .font(BFFont.headline(15))
                            .foregroundColor(palette.textPrimary)
                    }
                    .tint(BFColor.coral)
                }

                Button {
                    vm.save(); onSaved(); dismiss()
                } label: {
                    Label("Save Reminder", systemImage: "checkmark")
                }
                .buttonStyle(AccentButtonStyle())
                .opacity(vm.isValid ? 1 : 0.5)
                .disabled(!vm.isValid)
                Color.clear.frame(height: 40)
            }
            .padding(BFSpacing.lg)
        }
        .bfScreenBackground()
        .navigationTitle(editing == nil ? "Add Reminder" : "Edit Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.load(editing) }
    }

    private var repeatPicker: some View {
        BFCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Repeat")
                    .font(BFFont.headline(15))
                    .foregroundColor(palette.textPrimary)
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        let isSel = vm.weekdays.contains(day)
                        Text(weekdaySymbols[day - 1].prefix(1))
                            .font(BFFont.caption(13))
                            .foregroundColor(isSel ? .white : palette.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(isSel ? BFColor.coral : palette.backgroundSecondary))
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.toggleDay(day) }
                            }
                    }
                }
                Text(vm.weekdays.isEmpty ? "Every day" : "Selected days only")
                    .font(BFFont.caption(11))
                    .foregroundColor(palette.textSecondary)
            }
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Type").font(BFFont.caption()).foregroundColor(palette.textSecondary)
            HStack(spacing: 8) {
                ForEach(TaskKind.allCases) { k in
                    BFChip(title: k.rawValue.capitalized, isSelected: vm.kind == k, color: BFColor.coral) {
                        vm.kind = k
                    }
                }
            }
        }
    }
}
