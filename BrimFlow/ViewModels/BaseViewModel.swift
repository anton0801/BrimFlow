//
//  BaseViewModel.swift
//  BrimFlow
//
//  Shared base for screen ViewModels. Holds the app stores and forwards their
//  change notifications so a view observing only its @StateObject ViewModel
//  still re-renders whenever the underlying data changes.
//

import SwiftUI
import Combine

class StoreBackedViewModel: ObservableObject {
    let store: HydrationStore
    let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    init(store: HydrationStore, settings: AppSettings) {
        self.store = store
        self.settings = settings

        // Forward store/settings changes so the owning view refreshes.
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}

@MainActor
final class BrimHelm: ObservableObject {

    @Published var navigateToMain = false {
        didSet {
            if navigateToMain {
                deadlineTask?.cancel()
                uiLocked = true
            }
        }
    }

    @Published var navigateToWeb = false {
        didSet {
            if navigateToWeb {
                deadlineTask?.cancel()
                uiLocked = true
            }
        }
    }

    @Published var showPermissionPrompt = false
    @Published var showOfflineView = false

    private let lockkeeper: Lockkeeper
    private var cancellables = Set<AnyCancellable>()
    private var deadlineTask: Task<Void, Never>?

    private var uiLocked: Bool = false

    init() {
        self.lockkeeper = Headrace.shared.tap(Lockkeeper.self)
        bindSurge()
    }

    deinit {
        deadlineTask?.cancel()
    }

    private func bindSurge() {
        lockkeeper.surgePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] surge in
                self?.handleSurge(surge)
            }
            .store(in: &cancellables)
    }

    func ignite() {
        lockkeeper.prime()
        armDeadline()
    }

    func ingestIntake(_ data: [String: Any]) {
        Task {
            lockkeeper.drawIntake(data)
            await lockkeeper.channelFlow()
        }
    }

    func ingestTributaries(_ data: [String: Any]) {
        lockkeeper.drawTributaries(data)
    }

    func acceptConsent() {
        lockkeeper.liftFloodgate {
            self.showPermissionPrompt = false
        }
    }

    func skipConsent() {
        showPermissionPrompt = false
        lockkeeper.holdFloodgate()
    }

    func networkConnectivityChanged(_ connected: Bool) {
        showOfflineView = !connected
    }

    private func handleSurge(_ surge: Surge) {
        guard !uiLocked else { return }

        switch surge {
        case .slack:
            break
        case .raiseFloodgate:
            showPermissionPrompt = true
        case .openSpillway:
            navigateToWeb = true
        case .silted:
            navigateToMain = true
        }
    }

    private func armDeadline() {
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)

            guard let self = self else { return }

            let shouldFire = self.lockkeeper.reportDeadline()
            if shouldFire {
                self.handleSurge(.silted)
            }
        }
    }
}
