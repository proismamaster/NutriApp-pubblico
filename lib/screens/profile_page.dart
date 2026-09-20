import 'dart:convert';
import 'package:flutter/material.dart';
import '../logic/limiti_corpo.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/user_provider.dart';
import '../models/physical_measurement.dart';
import '../services/api_services.dart';
import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import '../widgets/modern_loader.dart';
import '../widgets/nutri_select.dart';


class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    if (user != null) {
      _nameController.text = user.firstName ?? '';
      _surnameController.text = user.lastName ?? '';
      _heightController.text = user.height != null && user.height! > 0
          ? user.height!.toStringAsFixed(0)
          : '';
      _weightController.text = user.currentWeight > 0
          ? user.currentWeight.toStringAsFixed(1)
          : '';
      _selectedDate = user.birthDate;

      // Solo maschio o femmina (15/09): il sesso entra nel calcolo delle
      // calorie. Un account con "other"/"undisclosed" di prima parte senza
      // scelta, e il salvataggio la chiede.
      String? dbGender = user.gender;
      if (dbGender == 'male' || dbGender == 'Maschio' || dbGender == 'Uomo') {
        _selectedGender = 'Maschio';
      } else if (dbGender == 'female' || dbGender == 'Femmina' || dbGender == 'Donna') {
        _selectedGender = 'Femmina';
      } else {
        _selectedGender = null;
      }

      if (user.profileImage != null && user.profileImage!.isNotEmpty) {
        _base64Image = user.profileImage;
      }
    }
    _nameController.addListener(_markDirty);
    _surnameController.addListener(_markDirty);
    _heightController.addListener(_markDirty);
    _weightController.addListener(_markDirty);
  }

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedGender;
  String? _base64Image;
  bool _dirty = false;
  bool _isSaving = false;

  /// Ricostruisce ad OGNI battuta, non solo alla prima.
  ///
  /// PERCHE' (bug segnalato il 2026-09-12): qui c'era `if (!_dirty) setState`.
  /// Il `setState` scattava solo al primo carattere digitato; dal secondo in
  /// poi il campo si aggiornava da se' (ce lo pensa il suo controller) ma il
  /// resto della schermata no. Risultato: scritta un'altezza non valida e poi
  /// corretta, l'errore rosso e il pulsante "Controlla i campi sopra"
  /// restavano quelli di prima e il salvataggio era bloccato per un valore
  /// che nel frattempo era giusto. Tutto cio' che in build() legge il testo
  /// dei controller (errore altezza/peso, BMI, `_canSave`) dipende da questo
  /// rebuild: la condizione che lo saltava era il bug.
  void _markDirty() {
    if (mounted) setState(() => _dirty = true);
  }

  Color _getAvatarColor() {
    if (_selectedGender == 'Maschio') return Colors.blue.shade100;
    if (_selectedGender == 'Femmina') return Colors.pink.shade100;
    return Theme.of(context).colorScheme.primaryContainer;
  }

  Color _getIconColor() {
    if (_selectedGender == 'Maschio') return Colors.blue.shade800;
    if (_selectedGender == 'Femmina') return Colors.pink.shade800;
    return Theme.of(context).colorScheme.primary;
  }

  String get _initials {
    final n = _nameController.text.trim();
    final s = _surnameController.text.trim();
    final buf = StringBuffer();
    if (n.isNotEmpty) buf.write(n[0].toUpperCase());
    if (s.isNotEmpty) buf.write(s[0].toUpperCase());
    return buf.isEmpty ? '—' : buf.toString();
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  /// Eta' calcolata dalla data di nascita — mostrata accanto al campo,
  /// stesso calcolo del mockup Profile (anno corrente meno anno di nascita,
  /// corretto se il compleanno di quest'anno non e' ancora passato).
  int? get _age {
    final d = _selectedDate;
    if (d == null) return null;
    final today = DateTime.now();
    int age = today.year - d.year;
    if (today.month < d.month || (today.month == d.month && today.day < d.day)) {
      age -= 1;
    }
    return age;
  }

  double? get _heightValue => double.tryParse(_heightController.text.replaceAll(',', '.').trim());
  double? get _weightValue => double.tryParse(_weightController.text.replaceAll(',', '.').trim());

  /// Errore mostrato accanto al campo altezza.
  ///
  /// Include ora anche il campo VUOTO (2026-09-12): l'altezza e' obbligatoria
  /// per salvare (`_canSave`), ma finche' questo escludeva il caso vuoto il
  /// pulsante diceva "Controlla i campi sopra" senza che nessun campo fosse
  /// segnalato — un blocco senza spiegazione. La condizione `_dirty` evita di
  /// accogliere con un errore rosso chi apre la pagina e non ha ancora
  /// toccato niente.
  bool get _heightShowError => _dirty && !_heightValid;

  bool get _heightValid => LimitiCorpo.erroreAltezza(_heightValue) == null;

  /// Il peso resta opzionale (si puo' salvare il profilo senza), ma se c'e'
  /// qualcosa scritto deve essere un numero positivo: prima un "abc" o uno
  /// "0" facevano scrivere il resto del profilo e scartare il peso in
  /// silenzio, con il messaggio verde "Profilo salvato con successo".
  /// Stessi limiti della registrazione, da LimitiCorpo (30-300 kg dal 14/09).
  bool get _weightValid {
    if (_weightController.text.trim().isEmpty) return true;
    return LimitiCorpo.errorePeso(_weightValue) == null;
  }

  bool get _weightShowError => _dirty && !_weightValid;

  /// BMI e fascia — calcolati solo con dati validi, mai un valore
  /// approssimato quando altezza/peso non sono ancora stati compilati.
  ({double bmi, String bandKey})? get _bmiInfo {
    final h = _heightValue;
    final w = _weightValue;
    if (h == null || w == null || !_heightValid || LimitiCorpo.errorePeso(w) != null) return null;
    final meters = h / 100;
    final bmi = w / (meters * meters);
    final bandKey = bmi < 18.5
        ? 'profile_bmi_underweight'
        : bmi < 25
            ? 'profile_bmi_healthy'
            : bmi < 30
                ? 'profile_bmi_overweight'
                : 'profile_bmi_obese';
    return (bmi: bmi, bandKey: bandKey);
  }

  bool get _canSave =>
      _dirty &&
      _heightValid &&
      _weightValid &&
      _nameController.text.trim().isNotEmpty &&
      _surnameController.text.trim().isNotEmpty &&
      _selectedGender != null;

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: LimitiCorpo.dataInizialeCalendario(_selectedDate),
      firstDate: LimitiCorpo.nascitaPiuLontana(),
      lastDate: LimitiCorpo.nascitaPiuRecente(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dirty = true;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

      if (pickedFile != null) {
        // La foto va sul server (2026-09-05), non piu' codificata dentro il
        // profilo: `profile_image` viaggia a ogni lettura dell'account, e una
        // foto codificata la faceva pesare decine di volte tanto. E' la stessa
        // strada che sulle ricette si era gia' rotta.
        //
        // `_base64Image` conserva il nome storico ma ora contiene un
        // indirizzo: e' letto in piu' punti e rinominarlo qui avrebbe toccato
        // codice estraneo a questa modifica. Chi lo disegna usa
        // nutriImageProvider(), che accetta entrambe le forme — per questo le
        // foto salvate prima continuano a vedersi senza convertire niente.
        final esito = await ApiServices.uploadImage(
          userMail: ref.read(userProvider)?.email ?? '',
          file: File(pickedFile.path),
        );
        if (!mounted) return;
        if (esito.url == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Foto non caricata: ${esito.errore}'),
              backgroundColor: const Color(0xFFB4553C),
              duration: const Duration(seconds: 6),
            ),
          );
          return;
        }
        setState(() {
          _base64Image = esito.url;
          _dirty = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.get(ref.read(appSettingsProvider).language, 'Errore durante la selezione dell\'immagine')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final lang = ref.read(appSettingsProvider).language;
    final user = ref.read(userProvider);
    if (user == null) return;

    String? dbGender;
    if (_selectedGender == 'Maschio') {
      dbGender = 'male';
    } else if (_selectedGender == 'Femmina') {
      dbGender = 'female';
    }

    setState(() => _isSaving = true);
    String? error = await ref.read(userProvider.notifier).updateUserProfile(
          firstName: _nameController.text.trim(),
          lastName: _surnameController.text.trim(),
          height: _heightValue,
          gender: dbGender,
          birthDate: _selectedDate,
          profileImage: _base64Image,
        );

    // Il peso passa da updateGoals (stesso percorso della home), non da
    // updateUserProfile: e' un obiettivo/scalare sul profilo, non un campo
    // anagrafico. Salviamo anche uno storico datato (savePhysicalMeasurement,
    // vedi home_page.dart) cosi' il trend a 7 giorni resta coerente.
    // Solo il peso, e il suo esito si mostra (15/09): prima un rifiuto del
    // server passava in silenzio sotto "Profilo salvato con successo".
    final newWeight = _weightValue;
    if (error == null && newWeight != null && newWeight > 0 && newWeight != user.currentWeight) {
      error = await ref.read(userProvider.notifier).updateWeight(newWeight);
      if (error == null) {
        await ApiServices.savePhysicalMeasurement(
          PhysicalMeasurement(date: DateTime.now(), weight: newWeight),
          user.email,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (error == null) _dirty = false;
    });
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Translations.get(lang, 'Profilo salvato con successo!')),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  /// Riga d'errore sotto la coppia altezza/peso — una sola forma per
  /// entrambi i campi, invece di ricopiare icona, spaziatura e colore.
  Widget _fieldError(ColorScheme scheme, String testo) => Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          children: [
            Icon(Icons.error, size: 16, color: scheme.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(testo, style: TextStyle(fontSize: 12.5, color: scheme.error)),
            ),
          ],
        ),
      );

  InputDecoration _fieldDecoration(BuildContext context, {String? suffixText, bool invalid = false}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      filled: true,
      fillColor: scheme.surface,
      suffixText: suffixText,
      suffixStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: invalid ? scheme.error.withValues(alpha: .5) : scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: invalid ? scheme.error.withValues(alpha: .5) : scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: invalid ? scheme.error : scheme.primary, width: 1.5),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    final scheme = Theme.of(context).colorScheme;
    final bmi = _bmiInfo;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: scheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              Translations.get(lang, 'Il mio profilo'),
              style: TextStyle(color: scheme.primary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            elevation: 0,
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 57,
                                  backgroundColor: _getAvatarColor(),
                                  backgroundImage: _base64Image != null
                                      ? MemoryImage(base64Decode(_base64Image!))
                                      : null,
                                  child: _base64Image == null
                                      ? Text(
                                          _initials,
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: _getIconColor(),
                                          ),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _pickProfileImage,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: scheme.surface, width: 3),
                                      ),
                                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 17),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              Translations.get(lang, 'profile_tap_change_photo'),
                              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      _fieldLabel(Translations.get(lang, 'Nome')),
                      TextField(controller: _nameController, decoration: _fieldDecoration(context)),
                      const SizedBox(height: 16),

                      _fieldLabel(Translations.get(lang, 'Cognome')),
                      TextField(controller: _surnameController, decoration: _fieldDecoration(context)),
                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel(Translations.get(lang, 'Altezza')),
                                TextField(
                                  // Chiave usata dal test di regressione
                                  // `test/schermate_layout_test.dart`.
                                  key: const Key('profilo_altezza'),
                                  controller: _heightController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _fieldDecoration(context, suffixText: Translations.get(lang, 'cm'), invalid: _heightShowError),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel(Translations.get(lang, 'Peso')),
                                TextField(
                                  key: const Key('profilo_peso'),
                                  controller: _weightController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _fieldDecoration(context, suffixText: Translations.get(lang, 'kg'), invalid: _weightShowError),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_heightShowError) _fieldError(scheme, Translations.get(lang, 'profile_height_error')),
                      if (_weightShowError) _fieldError(scheme, Translations.get(lang, 'profile_weight_error')),
                      const SizedBox(height: 16),

                      _fieldLabel(Translations.get(lang, 'Data di nascita')),
                      InkWell(
                        onTap: _selectDate,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDate != null
                                    ? _formatDate(_selectedDate!)
                                    : Translations.get(lang, 'Seleziona data'),
                                style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
                              ),
                              Row(
                                children: [
                                  if (_age != null)
                                    Text(
                                      '$_age ${Translations.get(lang, 'save_years_old')}',
                                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                                    ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _fieldLabel(Translations.get(lang, 'Sesso')),
                      // Foglio dal basso (18/09), come ogni altro select
                      // dell'app: il menu del vecchio DropdownButton copriva il
                      // campo stesso e mezza pagina (screenshot di Ismail).
                      NutriSelect<String>(
                        key: const Key('profilo_sesso'),
                        titolo: Translations.get(lang, 'Sesso'),
                        valore: _selectedGender,
                        segnaposto: Translations.get(lang, 'Sesso'),
                        opzioni: [
                          NutriOpzione('Femmina', Translations.get(lang, 'Femmina')),
                          NutriOpzione('Maschio', Translations.get(lang, 'Maschio')),
                        ],
                        onCambiato: (value) => setState(() {
                          _selectedGender = value;
                          _dirty = true;
                        }),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(alpha: .5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.monitor_weight_outlined, size: 20, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bmi == null
                                        ? Translations.get(lang, 'profile_bmi_missing')
                                        : 'BMI ${bmi.bmi.toStringAsFixed(1)} · ${Translations.get(lang, bmi.bandKey)}',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    Translations.get(lang, 'profile_bmi_note'),
                                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(top: BorderSide(color: scheme.outlineVariant)),
                ),
                child: Material(
                  color: _canSave
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _canSave ? _save : null,
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _canSave
                                ? Icons.check
                                : _dirty
                                    ? Icons.error_outline
                                    : Icons.cloud_done_outlined,
                            size: 20,
                            color: _canSave ? Colors.white : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _canSave
                                ? Translations.get(lang, 'save_changes')
                                : _dirty
                                    ? Translations.get(lang, 'save_check_fields')
                                    : Translations.get(lang, 'save_all_saved'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _canSave ? Colors.white : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isSaving)
          VeloDiCaricamento(messaggio: Translations.get(lang, 'Salvataggio in corso...')),
      ],
    );
  }
}
