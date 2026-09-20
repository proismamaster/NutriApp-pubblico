import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Richiesto da flutter_local_notifications su iOS (2026-09-05).
    //
    // Senza questa riga il sistema non consegna niente all'app mentre e' in
    // primo piano, e i promemoria programmati si comportano in modo
    // imprevedibile. E' la causa piu' comune di "le notifiche non funzionano
    // su iPhone" con questo plugin, ed era esattamente il nostro caso:
    // AppDelegate era ancora quello generato da `flutter create`.
    //
    // FlutterAppDelegate implementa gia' UNUserNotificationCenterDelegate:
    // basta dichiararsi tale, non serve altro codice.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
