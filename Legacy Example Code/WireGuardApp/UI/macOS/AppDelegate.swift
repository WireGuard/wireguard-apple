// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa
import ServiceManagement

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var tunnelsManager: TunnelsManager?
    var tunnelsTracker: TunnelsTracker?
    var statusItemController: StatusItemController?

    var manageTunnelsRootVC: ManageTunnelsRootViewController?
    var manageTunnelsWindowObject: NSWindow?
    var onAppDeactivation: (() -> Void)?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // To workaround a possible AppKit bug that causes the main menu to become unresponsive sometimes
        // (especially when launched through Xcode) if we call setActivationPolicy(.regular) in
        // in applicationDidFinishLaunching, we set it to .prohibited here.
        // Setting it to .regular would fix that problem too, but at this point, we don't know
        // whether the app was launched at login or not, so we're not sure whether we should
        // show the app icon in the dock or not.
        NSApp.setActivationPolicy(.prohibited)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Logger.configureGlobal(tagged: "APP", withFilePath: FileManager.logFileURL?.path)
        registerLoginItem(shouldLaunchAtLogin: true)

        var isLaunchedAtLogin = false
        if let appleEvent = NSAppleEventManager.shared().currentAppleEvent {
            isLaunchedAtLogin = LaunchedAtLoginDetector.isLaunchedAtLogin(openAppleEvent: appleEvent)
        }

        NSApp.mainMenu = MainMenu()
        setDockIconAndMainMenuVisibility(isVisible: !isLaunchedAtLogin)

        TunnelsManager.create { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                ErrorPresenter.showErrorAlert(error: error, from: nil)
            case .success(let tunnelsManager):
                let statusMenu = StatusMenu(tunnelsManager: tunnelsManager)
                statusMenu.windowDelegate = self

                let statusItemController = StatusItemController()
                statusItemController.statusItem.menu = statusMenu

                let tunnelsTracker = TunnelsTracker(tunnelsManager: tunnelsManager)
                tunnelsTracker.statusMenu = statusMenu
                tunnelsTracker.statusItemController = statusItemController

                self.tunnelsManager = tunnelsManager
                self.tunnelsTracker = tunnelsTracker
                self.statusItemController = statusItemController

                if !isLaunchedAtLogin {
                    self.showManageTunnelsWindow(completion: nil)
                }
            }
        }
    }

    @objc func confirmAndQuit() {
        let alert = NSAlert()
        alert.messageText = tr("macConfirmAndQuitAlertMessage")
        if let currentTunnel = tunnelsTracker?.currentTunnel, currentTunnel.status == .active || currentTunnel.status == .activating {
            alert.informativeText = tr(format: "macConfirmAndQuitInfoWithActiveTunnel (%@)", currentTunnel.name)
        } else {
            alert.informativeText = tr("macConfirmAndQuitAlertInfo")
        }
        alert.addButton(withTitle: tr("macConfirmAndQuitAlertCloseWindow"))
        alert.addButton(withTitle: tr("macConfirmAndQuitAlertQuitWireGuard"))

        NSApp.activate(ignoringOtherApps: true)
        if let manageWindow = manageTunnelsWindowObject {
            manageWindow.orderFront(self)
            alert.beginSheetModal(for: manageWindow) { response in
                switch response {
                case .alertFirstButtonReturn:
                    manageWindow.close()
                case .alertSecondButtonReturn:
                    NSApp.terminate(nil)
                default:
                    break
                }
            }
        }
    }

    @objc func quit() {
        if let manageWindow = manageTunnelsWindowObject, manageWindow.attachedSheet != nil {
            NSApp.activate(ignoringOtherApps: true)
            manageWindow.orderFront(self)
            return
        }
        registerLoginItem(shouldLaunchAtLogin: false)
        guard let currentTunnel = tunnelsTracker?.currentTunnel, currentTunnel.status == .active || currentTunnel.status == .activating else {
            NSApp.terminate(nil)
            return
        }
        let alert = NSAlert()
        alert.messageText = tr("macAppExitingWithActiveTunnelMessage")
        alert.informativeText = tr("macAppExitingWithActiveTunnelInfo")
        NSApp.activate(ignoringOtherApps: true)
        if let manageWindow = manageTunnelsWindowObject {
            manageWindow.orderFront(self)
            alert.beginSheetModal(for: manageWindow) { _ in
                NSApp.terminate(nil)
            }
        } else {
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let currentTunnel = tunnelsTracker?.currentTunnel, currentTunnel.status == .active || currentTunnel.status == .activating else {
            return .terminateNow
        }
        guard let appleEvent = NSAppleEventManager.shared().currentAppleEvent else {
            return .terminateNow
        }
        guard MacAppStoreUpdateDetector.isUpdatingFromMacAppStore(quitAppleEvent: appleEvent) else {
            return .terminateNow
        }
        let alert = NSAlert()
        alert.messageText = tr("macAppStoreUpdatingAlertMessage")
        if currentTunnel.isActivateOnDemandEnabled {
            alert.informativeText = tr(format: "macAppStoreUpdatingAlertInfoWithOnDemand (%@)", currentTunnel.name)
        } else {
            alert.informativeText = tr(format: "macAppStoreUpdatingAlertInfoWithoutOnDemand (%@)", currentTunnel.name)
        }
        NSApp.activate(ignoringOtherApps: true)
        if let manageWindow = manageTunnelsWindowObject {
            alert.beginSheetModal(for: manageWindow) { _ in }
        } else {
            alert.runModal()
        }
        return .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
            self?.setDockIconAndMainMenuVisibility(isVisible: false)
        }
        return false
    }

    private func setDockIconAndMainMenuVisibility(isVisible: Bool, completion: (() -> Void)? = nil) {
        let currentActivationPolicy = NSApp.activationPolicy()
        let newActivationPolicy: NSApplication.ActivationPolicy = isVisible ? .regular : .accessory
        guard currentActivationPolicy != newActivationPolicy else {
            if newActivationPolicy == .regular {
                NSApp.activate(ignoringOtherApps: true)
            }
            completion?()
            return
        }
        if newActivationPolicy == .regular && NSApp.isActive {
            // To workaround a possible AppKit bug that causes the main menu to become unresponsive,
            // we should deactivate the app first and then set the activation policy.
            // NSApp.deactivate() doesn't always deactivate the app, so we instead use
            // setActivationPolicy(.prohibited).
            onAppDeactivation = {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                completion?()
            }
            NSApp.setActivationPolicy(.prohibited)
        } else {
            NSApp.setActivationPolicy(newActivationPolicy)
            if newActivationPolicy == .regular {
                NSApp.activate(ignoringOtherApps: true)
            }
            completion?()
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        onAppDeactivation?()
        onAppDeactivation = nil
    }
}

extension AppDelegate {
    @objc func aboutClicked() {
        var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        if let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersion += " (\(appBuild))"
        }
        let appVersionString = [
            tr(format: "macAppVersion (%@)", appVersion),
            tr(format: "macGoBackendVersion (%@)", WIREGUARD_GO_VERSION)
        ].joined(separator: "\n")
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationVersion: appVersionString,
            .version: "",
            .credits: ""
        ])
    }
}

extension AppDelegate: StatusMenuWindowDelegate {
    func showManageTunnelsWindow(completion: ((NSWindow?) -> Void)?) {
        guard let tunnelsManager = tunnelsManager else {
            completion?(nil)
            return
        }
        if manageTunnelsWindowObject == nil {
            manageTunnelsRootVC = ManageTunnelsRootViewController(tunnelsManager: tunnelsManager)
            let window = NSWindow(contentViewController: manageTunnelsRootVC!)
            window.title = tr("macWindowTitleManageTunnels")
            window.setContentSize(NSSize(width: 800, height: 480))
            window.setFrameAutosaveName(NSWindow.FrameAutosaveName("ManageTunnelsWindow")) // Auto-save window position and size
            manageTunnelsWindowObject = window
            tunnelsTracker?.manageTunnelsRootVC = manageTunnelsRootVC
        }
        setDockIconAndMainMenuVisibility(isVisible: true) { [weak manageTunnelsWindowObject] in
            manageTunnelsWindowObject?.makeKeyAndOrderFront(self)
            completion?(manageTunnelsWindowObject)
        }
    }
}

@discardableResult
func registerLoginItem(shouldLaunchAtLogin: Bool) -> Bool {
    let appId = Bundle.main.bundleIdentifier!
    let helperBundleId = "\(appId).login-item-helper"
    return SMLoginItemSetEnabled(helperBundleId as CFString, shouldLaunchAtLogin)
}
