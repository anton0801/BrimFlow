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
