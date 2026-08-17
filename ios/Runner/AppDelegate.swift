import Flutter
import UIKit

private let channelName = "com.mergeempirefc.app/legacy_save"

// Matches @capacitor/preferences: UserDefaults.standard, keys prefixed with
// the group name and a dot. Android does not prefix — do not unify these.
private let legacySaveKey = "CapacitorStorage.mergeEmpireFC_save_native"

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: channelName,
                                       binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "readLegacySave":
        result(UserDefaults.standard.string(forKey: legacySaveKey))
      case "writeLegacySaveForTest":
        // Test-only seam, mirroring how the Capacitor build wrote the key.
        let value = (call.arguments as? [String: Any])?["value"] as? String
        if let value {
          UserDefaults.standard.set(value, forKey: legacySaveKey)
        } else {
          UserDefaults.standard.removeObject(forKey: legacySaveKey)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
