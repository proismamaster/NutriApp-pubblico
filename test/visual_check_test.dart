// Scratch verification harness — NOT part of the app's test suite intent.
// Renders the standalone presentational widgets touched during the
// mockup-fidelity pass with fake data (no backend needed) and dumps PNG
// screenshots to the scratchpad so they can be looked at directly next to
// the mockup spec. Safe to delete after review.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriapp/widgets/meal_tile.dart';
import 'package:nutriapp/widgets/day_quality_row.dart';
import 'package:nutriapp/widgets/calorie_ring.dart';
import 'package:nutriapp/widgets/paragrafo_ricetta.dart';
import 'package:nutriapp/widgets/nutrient_input_field.dart';
import 'package:nutriapp/models/daily_summary.dart';
import 'package:nutriapp/models/macronutrients.dart';
import 'package:nutriapp/models/fats.dart';
import 'package:nutriapp/models/minerals.dart';
import 'package:nutriapp/models/vitamins.dart';
import 'package:nutriapp/models/user_model.dart';
import 'package:nutriapp/domain/user_provider.dart';
import 'package:nutriapp/screens/goal_page.dart';
import 'package:nutriapp/screens/profile_page.dart';
import 'package:nutriapp/screens/setting_page.dart';
import 'package:nutriapp/screens/setting_notification_page.dart';
import 'package:nutriapp/screens/recipe_list_page.dart';
import 'package:nutriapp/screens/graphic_page.dart';
import 'package:nutriapp/screens/entry_menu_page.dart';
import 'package:nutriapp/screens/manual_entry_page.dart';
import 'package:nutriapp/screens/meal_detail_page.dart';
import 'package:nutriapp/MainLayout.dart';
import 'package:nutriapp/screens/login.dart';
import 'package:nutriapp/screens/signup.dart';
import 'package:nutriapp/screens/add_recipe.dart';
import 'package:nutriapp/screens/detail_of_ricetta.dart';
import 'package:nutriapp/screens/calendar_page.dart';
import 'package:nutriapp/screens/send_us_problem_page.dart';
import 'package:nutriapp/screens/country_language_page.dart';
import 'package:nutriapp/widgets/auth_style.dart';
import 'package:nutriapp/widgets/modern_loader.dart';
import 'package:nutriapp/theme_nutri.dart';
import 'package:nutriapp/models/recipe.dart';
import 'package:nutriapp/models/recipe_ingredient.dart';
import 'package:nutriapp/widgets/grafico_andamento.dart';
import 'package:nutriapp/models/history_point.dart';
import 'package:nutriapp/models/metric_type.dart';
import 'cartella_font.dart';

/// Dove finiscono gli screenshot.
///
/// PERCHE' NON UN PERCORSO SCRITTO A MANO (21/09): qui c'era la cartella
/// temporanea di una vecchia sessione sul computer di Ismail
/// (`C:\Users\ismai\AppData\...\scratchpad\visual_check`). Su Linux quel
/// testo non e' un percorso: `Directory(...).createSync()` crea UNA cartella
/// col nome pieno di barre rovesciate DENTRO il repo, che poi compare fra i
/// file non tracciati e rischia di finire in un commit.
///
/// Si puo' scegliere con `NUTRIAPP_SCREENSHOT_DIR`; senza, si usa la
/// cartella temporanea del sistema, che su ogni macchina esiste ed e' fuori
/// dal repo.
final _outDir = Platform.environment['NUTRIAPP_SCREENSHOT_DIR'] ??
    '${Directory.systemTemp.path}${Platform.pathSeparator}nutriapp_visual_check';

/// Lo STESSO tema dell'app, non una copia scritta a mano.
///
/// PERCHE' (2026-09-07): qui c'era un ThemeData locale, solo chiaro, che non
/// somigliava piu' a quello vero. Gli scatti in modalita' scura mostravano
/// quindi i colori di `Nutri` sopra un ColorScheme chiaro: una combinazione
/// che nell'app non esiste. Una verifica visiva che verifica qualcosa d'altro
/// e' peggio di nessuna verifica.
ThemeData _appTheme() => temaNutri(Nutri.scuro ? Brightness.dark : Brightness.light);

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget child, {
  double width = 412,
  Color? background,
}) async {
  final sfondo = background ?? Nutri.bg;
  final key = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: _appTheme(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: sfondo,
          body: RepaintBoundary(
            key: key,
            child: Container(
              width: width,
              color: sfondo,
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(_outDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

// flutter test's headless binding renders every glyph as a solid "tofu" box
// unless real font files are loaded manually — pulled straight from the SDK
// cache (see cartella_font.dart) so the screenshots show actual readable
// text/icons instead of blocks.
const _loadRealFonts = caricaFontDiProva;

// Utente finto — stessi numeri di riferimento usati nei mockup stessi
// (Profile: "Ismaa Barakata" 174cm; Charts/Goals: 960 kcal, 108/72/32 g)
// cosi' i pesi/percentuali mostrati sono realistici, non zeri spogli.
final _fakeUser = UserModel(
  id: 1,
  email: 'test@example.com',
  firstName: 'Ismaa',
  lastName: 'Barakata',
  height: 174,
  gender: 'male',
  birthDate: DateTime(2007, 9, 17),
  createdAt: DateTime(2026, 1, 1),
  currentWeight: 50.1,
  targetWeight: 48.0,
  calorieGoal: 960,
  carbGoal: 108,
  proteinGoal: 72,
  fatGoal: 32,
);

class _FakeUserNotifier extends UserNotifier {
  @override
  UserModel? build() => _fakeUser;
}

// [scopedChild] must already be wrapped in its own ProviderScope by the
// caller (e.g. `ProviderScope(overrides: [...], child: const GoalsPage())`)
// — riverpod's `Override` type isn't part of this package version's public
// export surface, so it can't be named in a shared helper's signature;
// passing an already-scoped widget sidesteps that entirely.
// Reused by `_snap` for follow-up screenshots (e.g. after opening a bottom
// sheet) within the same test, after the initial `_shootPage` call.
GlobalKey _liveShotKey = GlobalKey();

Future<void> _snap(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = _liveShotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(_outDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _shootPage(
  WidgetTester tester,
  String name,
  Widget scopedChild, {
  int pumps = 12,
  Duration pumpEvery = const Duration(milliseconds: 200),
}) async {
  tester.view.physicalSize = const Size(824, 1784);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  _liveShotKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      // Wraps the WHOLE MaterialApp (not just `home`) so modal bottom
      // sheets/dialogs — pushed into the root Navigator's Overlay, which
      // sits outside `home`'s own subtree — are actually included in the
      // capture instead of silently missing from it.
      key: _liveShotKey,
      child: MaterialApp(
        theme: _appTheme(),
        debugShowCheckedModeBanner: false,
        home: scopedChild,
      ),
    ),
  );
  // Real (mocked or genuinely failing) network I/O doesn't advance on fake
  // widget-test time — give it real wall-clock time to actually settle
  // before pumping again, or a page mid-fetch would screenshot as "stuck
  // loading" instead of its real state.
  await tester.runAsync(() => Future<void>.delayed(pumpEvery * pumps));
  await tester.pump(pumpEvery);

  await _snap(tester, name);
}

void main() {
  setUpAll(() async {
    await _loadRealFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // NotificationsPage.initState() calls the real plugin, which has no
    // platform implementation in a headless test — answer benignly so the
    // page can still render instead of throwing.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'requestNotificationsPermission':
          case 'requestPermissions':
            return true;
          default:
            return null;
        }
      },
    );
  });

  testWidgets('FULL PAGE — Goals', (tester) async {
    await _shootPage(
      tester,
      '10_page_goals',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const GoalsPage(),
      ),
    );
  });

  testWidgets('FULL PAGE — Profile', (tester) async {
    await _shootPage(
      tester,
      '11_page_profile',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const ProfilePage(),
      ),
    );
  });

  testWidgets('FULL PAGE — Settings', (tester) async {
    await _shootPage(
      tester,
      '12_page_settings',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const SettingPage(),
      ),
    );
  });

  testWidgets('FULL PAGE — Notifications', (tester) async {
    await _shootPage(
      tester,
      '13_page_notifications',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const NotificationsPage(),
      ),
    );
  });

  testWidgets('meal tiles grid', (tester) async {
    await _shoot(
      tester,
      '03_home_meal_tiles',
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: [
          MealTile(
            label: 'Colazione',
            icon: Icons.coffee,
            eatenKcal: 212,
            targetKcal: 288,
            hasEntries: true,
            onTap: () {},
            onAdd: () {},
          ),
          MealTile(
            label: 'Pranzo',
            icon: Icons.dinner_dining,
            eatenKcal: 0,
            targetKcal: 336,
            hasEntries: false,
            onTap: () {},
            onAdd: () {},
          ),
          MealTile(
            label: 'Cena',
            icon: Icons.ramen_dining,
            eatenKcal: 420,
            targetKcal: 288,
            hasEntries: true,
            onTap: () {},
            onAdd: () {},
          ),
          MealTile(
            label: 'Snack',
            icon: Icons.cookie,
            eatenKcal: 0,
            targetKcal: 96,
            hasEntries: false,
            onTap: () {},
            onAdd: () {},
          ),
        ],
      ),
    );
  });

  testWidgets('calorie ring', (tester) async {
    await _shoot(
      tester,
      '04_home_calorie_ring',
      const Center(
        child: CalorieRing(
          fraction: 0.62,
          isOverGoal: false,
          centerValue: '365',
          centerLabel: 'left of 960',
        ),
      ),
      width: 200,
    );
  });

  testWidgets('day quality row', (tester) async {
    await _shoot(
      tester,
      '05_home_day_quality',
      DayQualityRow(
        summary: DailySummary(
          totalMacro: const Macronutrients(calories: 800, carbs: 90, proteins: 40, fats: 20),
          totalFats: const Fats(),
          totalMinerals: const Minerals(),
          totalVitamins: const Vitamins(),
          intakeCount: 4,
          avgNutriscoreNum: 1.5,
          avgNova: 2.1,
          avgEcoscoreNum: 2.0,
        ),
      ),
    );
  });

  testWidgets('recipe card', (tester) async {
    await _shoot(
      tester,
      '06_recipe_card',
      ParagrafoRicetta(
        title: 'Overnight oats',
        subtitle: 'Porzione: 2 — 6 ingredienti',
        kcalLabel: '312 kcal a porzione',
        isFavorite: true,
        onFavorite: () {},
        onEdit: () {},
        onDelete: () {},
        onTap: () {},
      ),
    );
  });

  testWidgets('bottom nav shell (MainLayout, reconstructed inline — private class)', (tester) async {
    // _BottomNav in MainLayout.dart is private; this is a byte-for-byte copy
    // of its build() so the fix (filled green Add circle, correct icons,
    // per-tab active color) can be looked at without exporting the class.
    Widget item(IconData? icon, String label, bool selected, ColorScheme scheme) {
      final bool isAdd = icon == null;
      final color = selected ? scheme.primary : scheme.onSurfaceVariant;
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdd)
              Transform.translate(
                offset: const Offset(0, -4),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                  child: Icon(Icons.add, color: scheme.onPrimary, size: 26),
                ),
              )
            else
              Icon(icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: selected ? FontWeight.w500 : FontWeight.normal, color: color)),
          ],
        ),
      );
    }

    await _shoot(
      tester,
      '08_bottom_nav',
      Builder(builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return DecoratedBox(
          decoration: BoxDecoration(color: scheme.surface, border: Border(top: BorderSide(color: scheme.primary.withValues(alpha: .12)))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                item(Icons.home, 'NutriApp', true, scheme),
                item(Icons.calendar_month, 'Calendario', false, scheme),
                item(null, 'Aggiungi', false, scheme),
                item(Icons.bookmark, 'Ricette', false, scheme),
                item(Icons.show_chart, 'Grafici', false, scheme),
              ],
            ),
          ),
        );
      }),
      background: const Color(0xFFFFFFFF),
    );
  });

  testWidgets('filter/sort pills (Add Food, reconstructed inline — private class)', (tester) async {
    // _FilterSortPill in entry_menu_page.dart is private; byte-for-byte copy
    // of its build() to check the bordered-pill + separate count badge fix.
    Widget pill(IconData icon, String label, bool highlighted, int? badgeCount, ColorScheme scheme) {
      final bg = highlighted ? scheme.primaryContainer.withValues(alpha: .55) : scheme.surface;
      final border = highlighted ? scheme.primary : scheme.outlineVariant;
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border, width: 1.5)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 7),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 14))),
            if (badgeCount != null) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
                child: Text('$badgeCount', style: TextStyle(color: scheme.onPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      );
    }

    await _shoot(
      tester,
      '09_add_food_pills',
      Builder(builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Row(
          children: [
            Expanded(child: pill(Icons.tune, 'Filtro', true, 2, scheme)),
            const SizedBox(width: 10),
            Expanded(child: pill(Icons.swap_vert, 'Nutri-Score', false, null, scheme)),
          ],
        );
      }),
    );
  });

  testWidgets('FULL PAGE — Recipes (real network call, unmocked — timing probe)', (tester) async {
    final sw = Stopwatch()..start();
    await _shootPage(
      tester,
      '14_page_recipes',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const RecipeListaPage(),
      ),
    );
    // ignore: avoid_print
    print('Recipes page wall time: ${sw.elapsedMilliseconds}ms');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('FULL PAGE — MainLayout (Home tab, shared chrome)', (tester) async {
    await _shootPage(
      tester,
      '19_page_mainlayout_home',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const MainLayout(),
      ),
    );
  });

  testWidgets('FULL PAGE — Charts', (tester) async {
    await _shootPage(
      tester,
      '15_page_charts',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const GraphicPage(),
      ),
    );
  });

  testWidgets('FULL PAGE — Meal Detail', (tester) async {
    await _shootPage(
      tester,
      '16_page_meal_detail',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const MealDetailPage(mealType: 'Colazione'),
      ),
    );
  });

  testWidgets('FULL PAGE — Add Food (empty state + filter sheet open)', (tester) async {
    await _shootPage(
      tester,
      '17_page_add_food',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const EntryMenuPage(),
      ),
    );
    // Open the Filters bottom sheet to check it in-context, not just the
    // reconstructed fragment from earlier. Default locale in this harness
    // renders English ("Filter"), not Italian.
    final filterPill = find.text('Filter');
    if (tester.any(filterPill)) {
      await tester.tap(filterPill.first);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await _snap(tester, '17b_page_add_food_filter_sheet');
    }
  });

  testWidgets('FULL PAGE — Manual Entry blank form + 100g/portion toggle', (tester) async {
    await _shootPage(
      tester,
      '18_page_manual_entry',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const ManualEntryPage(),
      ),
    );
    // Type into the Name field (first TextFormField on the classic form) and
    // flip the basis toggle, then screenshot again — this is the one change
    // that touches save logic, not just layout, so it's worth seeing it
    // react to real input instead of trusting the code alone.
    final fields = find.byType(TextFormField);
    Future<void> setField(int index, String text) async {
      if (fields.evaluate().length > index) {
        await tester.enterText(fields.at(index), text);
        // The floating-label animation takes ~200ms; a single bare pump()
        // lands mid-transition and the typed text overlaps the label.
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    // Order on the classic form: Name(0), Weight(1), Barcode(2), then the
    // "Per 100g/portion" toggle, then Calories(3), Carbs(4), Protein(5), Fat(6).
    await setField(0, 'Yogurt greco 0%');
    await setField(1, '170');
    final per100gToggle = find.text('Per 100 g');
    if (tester.any(per100gToggle)) {
      await tester.tap(per100gToggle.first);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await setField(3, '57'); // calories per 100g on the label
    await setField(4, '3.6'); // carbs
    await tester.pump(const Duration(milliseconds: 300));
    await _snap(tester, '18b_page_manual_entry_filled');
  });

  testWidgets('nutrient field with dot and kcal readout', (tester) async {
    final c1 = TextEditingController(text: '108');
    final c2 = TextEditingController(text: '72');
    await _shoot(
      tester,
      '07_goals_macro_fields',
      Column(
        children: [
          NutrientInputField(
            label: 'Carboidrati',
            hint: '0',
            suffix: 'g',
            controller: c1,
            dotColor: const Color(0xFF1B7A33),
            trailingHint: '432 kcal',
            outlined: true,
          ),
          NutrientInputField(
            label: 'Proteine',
            hint: '0',
            suffix: 'g',
            controller: c2,
            dotColor: const Color(0xFF4E9A6B),
            trailingHint: '288 kcal',
            outlined: true,
          ),
        ],
      ),
      background: const Color(0xFFF4F7EF),
    );
  });

  // Riproduce ESATTAMENTE lo screenshot mandato da Ismail il 29/08: finestra di
  // 30 giorni con dati su 2 soli giorni, non adiacenti. Prima del fix si vedevano
  // due cerchietti bianchi sospesi nel vuoto (un tratto di un punto solo non
  // disegna ne' linea ne' area) e nessun valore sull'asse Y (l'asse scorreva
  // fuori vista insieme al grafico, largo 30*46 px e aperto sul lato destro).
  testWidgets('grafico storico con dati sparsi (2 giorni su 30)', (tester) async {
    final oggi = DateTime(2026, 8, 29);
    final punti = <HistoryPoint>[
      for (var i = 29; i >= 0; i--)
        () {
          final giorno = oggi.subtract(Duration(days: i));
          // Gli stessi due giorni della segnalazione: 25/08 e 29/08.
          final conDati = giorno.day == 25 || giorno.day == 29;
          return HistoryPoint(
            periodStart: giorno,
            label: '${giorno.day} ${const [
              'Gen','Feb','Mar','Apr','Mag','Giu','Lug','Ago','Set','Ott','Nov','Dic'
            ][giorno.month - 1]}',
            calories: conDati ? (giorno.day == 25 ? 780 : 2130) : 0,
            carbs: conDati ? 210 : 0,
            proteins: conDati ? 95 : 0,
            fats: conDati ? 70 : 0,
            hasData: conDati,
          );
        }(),
    ];

    await _shoot(
      tester,
      'chart_dati_sparsi',
      GraficoAndamento(
        punti: punti,
        metrica: MetricType.calories,
        obiettivo: 2000,
        etichettaObiettivo: 'Obiettivo',
      ),
    );
  });

  // Schermata di accesso ridisegnata sul mockup "NutriApp Login" (29/08).
  testWidgets('FULL PAGE — Login', (tester) async {
    await _shootPage(
      tester,
      '20_page_login',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const LoginPage(),
      ),
    );
  });

  // Registrazione ridisegnata sul mockup "NutriApp Registration" (29/08).
  // Passo 1; il passo 2 si raggiunge compilando, che qui non serve: basta
  // vedere che la nuova intestazione, la barra dei passi e la card foto
  // rendano correttamente.
  testWidgets('FULL PAGE — Registration', (tester) async {
    await _shootPage(
      tester,
      '21_page_registration',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const SignUpPage(),
      ),
    );
  });

  // Edit Recipe ridisegnata sul mockup (30/08). Ricetta finta con tre
  // ingredienti veri, cosi' si vedono card, riepilogo e barra dei macro
  // invece dello stato vuoto.
  testWidgets('FULL PAGE — Edit Recipe', (tester) async {
    final ricetta = Recipe(
      id: '7',
      name: 'Zuppa di lenticchie e pomodoro',
      portion: '4',
      notes: '',
      ingredients: [
        RecipeIngredient(
          name: 'Lenticchie rosse secche',
          unit: 'g',
          weight_g: 200,
          macro: const Macronutrients(calories: 706, carbs: 120, proteins: 48, fats: 2),
          nutriscoreGrade: 'a',
        ),
        RecipeIngredient(
          name: 'Pomodori pelati',
          unit: 'g',
          weight_g: 400,
          macro: const Macronutrients(calories: 96, carbs: 13.6, proteins: 4.8, fats: 0.8),
          nutriscoreGrade: 'a',
        ),
        RecipeIngredient(
          name: 'Olio extravergine di oliva',
          unit: 'g',
          weight_g: 20,
          macro: const Macronutrients(calories: 177, carbs: 0, proteins: 0, fats: 20),
          nutriscoreGrade: 'c',
        ),
      ],
    );
    await _shootPage(
      tester,
      '22_page_edit_recipe',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: CreaRicettaPage(initialRecipe: ricetta),
      ),
    );
  });

  // Modalita' scura: Ismail ha segnalato che restava scura solo la cornice
  // mentre il contenuto rimaneva chiaro. Questi due scatti mostrano la stessa
  // pagina nei due temi, cosi' la differenza si vede invece di doverla dedurre.
  testWidgets('FULL PAGE — Calendario chiaro e scuro', (tester) async {
    for (final scuro in [false, true]) {
      Nutri.applicaTema(scuro ? Brightness.dark : Brightness.light);
      await _shootPage(
        tester,
        scuro ? '23_calendario_scuro' : '23_calendario_chiaro',
        ProviderScope(
          overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
          child: const CalendarioPage(),
        ),
      );
    }
    Nutri.applicaTema(Brightness.light);
  });

  testWidgets('FULL PAGE — Lingua e paese', (tester) async {
    await _shootPage(
      tester,
      '24_lingua_paese',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const LinguaPaesePage(),
      ),
    );
  });

  testWidgets('FULL PAGE — Segnala problema', (tester) async {
    await _shootPage(
      tester,
      '25_segnala_problema',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const SegnalaProblemaPage(),
      ),
    );
  });

  // Le quattro schermate segnalate il 07/09, scattate in SCURO: e' li' che i
  // difetti si vedono (logo Apple invisibile, verdi sbiaditi, fascia pasto
  // fluo, pulsante sovrapposto al titolo) e leggendo il codice non si vedono.
  testWidgets('FULL PAGE — scuro: login, obiettivi, dettaglio pasto', (tester) async {
    Nutri.applicaTema(Brightness.dark);
    await _shootPage(
      tester,
      '26_login_scuro',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const LoginPage(),
      ),
    );
    await _shootPage(
      tester,
      '27_obiettivi_scuro',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const GoalsPage(),
      ),
    );
    await _shootPage(
      tester,
      '28_dettaglio_pasto_scuro',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: const MealDetailPage(mealType: 'Colazione'),
      ),
    );
    // La pagina ricetta, ora UNICA: prima ce n'erano due, una per guardarla e
    // una per registrarla, con aspetti diversi. Due scatti dello stesso
    // widget, coi due valori del flag, per vedere che l'unica differenza sia
    // il blocco pasto/quantita' e il pulsante in fondo.
    final ricettaDemo = Recipe(
      id: '9',
      name: 'Zuppa di lenticchie',
      portion: '4',
      notes: 'Cuocere a fuoco lento per 40 minuti.',
      ingredients: [
        RecipeIngredient(
          name: 'Lenticchie rosse secche',
          unit: 'g',
          weight_g: 200,
          macro: const Macronutrients(calories: 706, carbs: 120, proteins: 48, fats: 2),
        ),
        RecipeIngredient(
          name: 'Pomodori pelati',
          unit: 'g',
          weight_g: 400,
          macro: const Macronutrients(calories: 96, carbs: 13.6, proteins: 4.8, fats: 0.8),
        ),
      ],
    );
    await _shootPage(
      tester,
      '31_ricetta_scuro_consulta',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: RecipeDetailPage(recipe: ricettaDemo, conAggiuntaAlDiario: false),
      ),
    );
    await _shootPage(
      tester,
      '32_ricetta_scuro_aggiungi',
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _FakeUserNotifier())],
        child: RecipeDetailPage(recipe: ricettaDemo),
      ),
    );
    // Il caricamento a tutta pagina, senza velo scuro sopra: e' il caso in cui
    // la scritta spariva, perche' il colore predefinito era un verde scuro
    // fisso e il fondo in scuro e' quasi nero.
    await _shootPage(
      tester,
      '29_caricamento_scuro',
      const ProviderScope(
        child: Scaffold(body: ModernLoader(message: 'Caricamento...')),
      ),
    );
    // Il velo che copre la schermata durante un salvataggio: e' il caso in cui
    // cinque chiamanti passavano Nutri.card pensando "bianco" — vero in
    // chiaro, quasi nero in scuro, quindi scritta invisibile sul velo nero.
    await _shootPage(
      tester,
      '30_velo_caricamento_scuro',
      const ProviderScope(
        child: Scaffold(
          body: Stack(
            children: [
              Center(child: Text('contenuto della schermata sotto')),
              VeloDiCaricamento(messaggio: 'Salvataggio in corso...'),
            ],
          ),
        ),
      ),
    );
    Nutri.applicaTema(Brightness.light);
  });
}
