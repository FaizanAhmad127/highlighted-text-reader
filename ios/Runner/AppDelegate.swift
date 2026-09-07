import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        applyAppCheckDebugTokenIfNeeded()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        applyAppCheckDebugTokenIfNeeded()
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }

    private func applyAppCheckDebugTokenIfNeeded() {
        #if DEBUG
        if let token = Bundle.main.object(forInfoDictionaryKey: "AppCheckDebugToken") as? String {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !trimmed.hasPrefix("$(") {
                setenv("AppCheckDebugToken", trimmed, 1)
                setenv("FIRAAppCheckDebugToken", trimmed, 1)
            }
        }
        #endif
    }
}
