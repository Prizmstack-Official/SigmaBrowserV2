//
//  NookSettingsService.swift
//  Nook
//
//  Created by Maciek Bagiński on 03/08/2025.
//  Updated by Aether Aurelia on 15/11/2025.
//

import AppKit
import SwiftUI

public enum SidebarPosition: String, CaseIterable, Identifiable {
    case left
    case right

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left:
            return "Left"
        case .right:
            return "Right"
        }
    }

    var icon: String {
        switch self {
        case .left:
            return "sidebar.left"
        case .right:
            return "sidebar.right"
        }
    }
}


@MainActor
@Observable
class NookSettingsService {
    private let userDefaults = UserDefaults.standard
    private let materialKey = "settings.currentMaterialRaw"
    private let searchEngineKey = "settings.searchEngine"
    private let tabUnloadTimeoutKey = "settings.tabUnloadTimeout"
    private let blockXSTKey = "settings.blockCrossSiteTracking"
    private let debugToggleUpdateNotificationKey = "settings.debugToggleUpdateNotification"
    private let askBeforeQuitKey = "settings.askBeforeQuit"
    private let sidebarPositionKey = "settings.sidebarPosition"
    private let topBarAddressViewKey = "settings.topBarAddressView"
    private let showLinkStatusBarKey = "settings.showLinkStatusBar"
    private let pinnedTabsLookKey = "settings.pinnedTabsLook"
    private let siteSearchEntriesKey = "settings.siteSearchEntries"
    private let didFinishOnboardingKey = "settings.didFinishOnboarding"
    private let tabLayoutKey = "settings.tabLayout"
    private let customSearchEnginesKey = "settings.customSearchEngines"

    var currentSettingsTab: SettingsTabs = .general

    var currentMaterialRaw: Int {
        didSet {
            userDefaults.set(currentMaterialRaw, forKey: materialKey)
        }
    }

    var currentMaterial: NSVisualEffectView.Material {
        get {
            NSVisualEffectView.Material(rawValue: currentMaterialRaw)
                ?? .selection
        }
        set { currentMaterialRaw = newValue.rawValue }
    }

    var searchEngineId: String {
        didSet {
            userDefaults.set(searchEngineId, forKey: searchEngineKey)
        }
    }

    var customSearchEngines: [CustomSearchEngine] {
        didSet {
            if let data = try? JSONEncoder().encode(customSearchEngines) {
                userDefaults.set(data, forKey: customSearchEnginesKey)
            }
        }
    }

    /// Resolves the current `searchEngineId` to a query template string.
    /// Checks built-in `SearchProvider` cases first, then custom engines.
    var resolvedSearchEngineTemplate: String {
        if let provider = SearchProvider(rawValue: searchEngineId) {
            return provider.queryTemplate
        }
        if let custom = customSearchEngines.first(where: { $0.id.uuidString == searchEngineId }) {
            return custom.urlTemplate
        }
        return SearchProvider.google.queryTemplate
    }
    
    var tabUnloadTimeout: TimeInterval {
        didSet {
            userDefaults.set(tabUnloadTimeout, forKey: tabUnloadTimeoutKey)
            // Notify compositor manager of timeout change
            NotificationCenter.default.post(name: .tabUnloadTimeoutChanged, object: nil, userInfo: ["timeout": tabUnloadTimeout])
        }
    }

    var blockCrossSiteTracking: Bool {
        didSet {
            userDefaults.set(blockCrossSiteTracking, forKey: blockXSTKey)
            NotificationCenter.default.post(name: .blockCrossSiteTrackingChanged, object: nil, userInfo: ["enabled": blockCrossSiteTracking])
        }
    }
    
    var askBeforeQuit: Bool {
        didSet {
            userDefaults.set(askBeforeQuit, forKey: askBeforeQuitKey)
        }
    }
    
    var sidebarPosition: SidebarPosition {
        didSet {
            userDefaults.set(sidebarPosition.rawValue, forKey: sidebarPositionKey)
        }
    }
    
    var topBarAddressView: Bool {
        didSet {
            userDefaults.set(topBarAddressView, forKey: topBarAddressViewKey)
        }
    }

    var debugToggleUpdateNotification: Bool {
        didSet {
            userDefaults.set(debugToggleUpdateNotification, forKey: debugToggleUpdateNotificationKey)
        }
    }
    
    var showLinkStatusBar: Bool {
        didSet {
            userDefaults.set(showLinkStatusBar, forKey: showLinkStatusBarKey)
        }
    }
    
    var pinnedTabsLook: PinnedTabsConfiguration {
        didSet {
            userDefaults.set(pinnedTabsLook, forKey: pinnedTabsLookKey)
        }
    }

    var siteSearchEntries: [SiteSearchEntry] {
        didSet {
            if let data = try? JSONEncoder().encode(siteSearchEntries) {
                userDefaults.set(data, forKey: siteSearchEntriesKey)
            }
        }
    }
    
    var tabLayout: TabLayout {
        didSet {
            userDefaults.set(tabLayout.rawValue, forKey: tabLayoutKey)
            // When tabs are on top, URL bar can't be in the sidebar
            if tabLayout == .topOfWindow && !topBarAddressView {
                topBarAddressView = true
            }
        }
    }

    var didFinishOnboarding: Bool {
        didSet {
            userDefaults.set(didFinishOnboarding, forKey: didFinishOnboardingKey)
        }
    }

    init() {
        // Register default values
        userDefaults.register(defaults: [
            materialKey: NSVisualEffectView.Material.hudWindow.rawValue,
            searchEngineKey: SearchProvider.google.rawValue,
            // Default tab unload timeout: 60 minutes
            tabUnloadTimeoutKey: 3600.0,
            blockXSTKey: false,
            debugToggleUpdateNotificationKey: false,
            askBeforeQuitKey: true,
            sidebarPositionKey: SidebarPosition.left.rawValue,
            topBarAddressViewKey: false,
            showLinkStatusBarKey: true,
            pinnedTabsLookKey: "large",
            didFinishOnboardingKey: false,
            tabLayoutKey: TabLayout.sidebar.rawValue,
        ])

        // Initialize properties from UserDefaults
        // This will use the registered defaults if no value is set
        self.currentMaterialRaw = userDefaults.integer(forKey: materialKey)

        // searchEngineId: backward compatible — existing "google" string still works
        self.searchEngineId = userDefaults.string(forKey: searchEngineKey) ?? SearchProvider.google.rawValue

        if let ceData = userDefaults.data(forKey: customSearchEnginesKey),
           let decoded = try? JSONDecoder().decode([CustomSearchEngine].self, from: ceData) {
            self.customSearchEngines = decoded
        } else {
            self.customSearchEngines = []
        }
        
        // Initialize tab unload timeout
        self.tabUnloadTimeout = userDefaults.double(forKey: tabUnloadTimeoutKey)
        self.blockCrossSiteTracking = userDefaults.bool(forKey: blockXSTKey)
        self.debugToggleUpdateNotification = userDefaults.bool(forKey: debugToggleUpdateNotificationKey)
        self.askBeforeQuit = userDefaults.bool(forKey: askBeforeQuitKey)
        self.sidebarPosition = SidebarPosition(rawValue: userDefaults.string(forKey: sidebarPositionKey) ?? "left") ?? SidebarPosition.left
        self.topBarAddressView = userDefaults.bool(forKey: topBarAddressViewKey)
        self.showLinkStatusBar = userDefaults.bool(forKey: showLinkStatusBarKey)
        self.pinnedTabsLook = PinnedTabsConfiguration(rawValue: userDefaults.string(forKey: pinnedTabsLookKey) ?? "large") ?? .large
        self.tabLayout = TabLayout(rawValue: userDefaults.string(forKey: tabLayoutKey) ?? TabLayout.sidebar.rawValue) ?? .sidebar
        self.didFinishOnboarding = userDefaults.bool(forKey: didFinishOnboardingKey)

        if let data = userDefaults.data(forKey: siteSearchEntriesKey),
           let decoded = try? JSONDecoder().decode([SiteSearchEntry].self, from: data) {
            self.siteSearchEntries = decoded
        } else {
            self.siteSearchEntries = SiteSearchEntry.defaultSites
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let tabUnloadTimeoutChanged = Notification.Name("tabUnloadTimeoutChanged")
    static let blockCrossSiteTrackingChanged = Notification.Name("blockCrossSiteTrackingChanged")
}

// MARK: - Environment Key
private struct NookSettingsServiceKey: EnvironmentKey {
    @MainActor
    static var defaultValue: NookSettingsService {
        // This should never be called since we always inject from NookApp
        // But EnvironmentKey protocol requires a default value
        return NookSettingsService()
    }
}

extension EnvironmentValues {
    var nookSettings: NookSettingsService {
        get { self[NookSettingsServiceKey.self] }
        set { self[NookSettingsServiceKey.self] = newValue }
    }
}


import AppKit
import Foundation

public let materials: [(name: String, value: NSVisualEffectView.Material)] = [
    ("titlebar", .titlebar),
    ("menu", .menu),
    ("popover", .popover),
    ("sidebar", .sidebar),
    ("headerView", .headerView),
    ("sheet", .sheet),
    ("windowBackground", .windowBackground),
    ("Arc", .hudWindow),
    ("fullScreenUI", .fullScreenUI),
    ("toolTip", .toolTip),
    ("contentBackground", .contentBackground),
    ("underWindowBackground", .underWindowBackground),
    ("underPageBackground", .underPageBackground),
]

public func nameForMaterial(_ material: NSVisualEffectView.Material) -> String {
    materials.first(where: { $0.value == material })?.name
        ?? "raw(\(material.rawValue))"
}

// MARK: - Tab Layout

public enum TabLayout: String, CaseIterable, Identifiable {
    case sidebar
    case topOfWindow

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sidebar: return "Sidebar"
        case .topOfWindow: return "Top of Window"
        }
    }
}
