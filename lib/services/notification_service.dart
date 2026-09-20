import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Fuso orario pronto: senza, `tz.local` lancia LateInitializationError e
  /// ogni promemoria programmato fa esplodere la pagina delle notifiche
  /// (test di release 19/09).
  bool _fusoPronto = false;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) {
        // Gestire il click sulla notifica se necessario
      },
    );

    tz_data.initializeTimeZones();
    try {
      final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint("Errore fuso orario, uso UTC: $e");
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    _fusoPronto = true;
  }

  /// Rimette in piedi il fuso orario se l'avvio non c'e' stato o e' fallito.
  Future<bool> _assicuraFuso() async {
    if (_fusoPronto) return true;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
      _fusoPronto = true;
      return true;
    } catch (e) {
      debugPrint('Fuso orario non disponibile: $e');
      return false;
    }
  }

  /// Chiede il permesso di notificare e dice se e' stato concesso.
  ///
  /// PERCHE' RESTITUISCE UN VALORE (2026-09-05): prima non lo faceva, e
  /// l'esito veniva buttato via. Se l'utente negava — o semplicemente non
  /// rispondeva — l'app continuava a mostrare gli interruttori dei promemoria
  /// come se fossero attivi e a "programmare" avvisi che il sistema scartava
  /// in silenzio. Da fuori si vedeva solo "le notifiche non funzionano", senza
  /// nessun modo di capire perche'.
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ok = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return ok ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ok = await android?.requestNotificationsPermission();
      // Gli avvisi a orario esatto sono un permesso SEPARATO da Android 12:
      // senza, il sistema li rimanda "quando gli conviene" e un promemoria
      // per le 12:00 puo' arrivare a meta' pomeriggio. Se l'utente lo nega
      // le notifiche arrivano lo stesso, solo meno puntuali: non lo trattiamo
      // come un fallimento.
      await android?.requestExactAlarmsPermission();
      return ok ?? false;
    }
    // Sulle altre piattaforme il plugin non chiede niente: non c'e' un
    // permesso da negare, quindi non e' un fallimento.
    return true;
  }

  /// True se il sistema consegnerebbe una notifica adesso.
  Future<bool> permessiConcessi() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Senza fuso orario non si programma niente, ma non si butta all'aria la
    // pagina: prima ogni promemoria lanciava LateInitializationError.
    if (!await _assicuraFuso()) return;
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutriapp_reminders',
          'Promemoria NutriApp',
          channelDescription: 'Canale per i promemoria di pasti e acqua',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
