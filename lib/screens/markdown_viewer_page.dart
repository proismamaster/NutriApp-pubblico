import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import '../widgets/modern_loader.dart';

class MarkdownViewerPage extends ConsumerStatefulWidget {
  final String title;
  final String
  assetPathPrefix; // e.g. 'assets/docs/privacy' or 'assets/docs/guida'

  const MarkdownViewerPage({
    super.key,
    required this.title,
    required this.assetPathPrefix,
  });

  @override
  ConsumerState<MarkdownViewerPage> createState() => _MarkdownViewerPageState();
}

class _MarkdownViewerPageState extends ConsumerState<MarkdownViewerPage> {
  String _markdownData = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    final lang = ref.read(appSettingsProvider).language;
    String langCode = 'en'; // default
    if (lang == 'Italiano') {
      langCode = 'it';
    } else if (lang == '简体中文') {
      langCode = 'zh';
    } else if (lang == 'العربية') {
      langCode = 'ar';
    }

    String path = '${widget.assetPathPrefix}_$langCode.md';
    String data = '';

    try {
      data = await rootBundle.loadString(path);
    } catch (e) {
      // Fallback to Italian if specific language not found
      try {
        path = '${widget.assetPathPrefix}_it.md';
        data = await rootBundle.loadString(path);
      } catch (e2) {
        data = '# Errore\nImpossibile caricare il documento.';
      }
    }

    if (mounted) {
      setState(() {
        _markdownData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          Translations.get(lang, widget.title),
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const ModernLoader()
          : Markdown(
              data: _markdownData,
              styleSheet: MarkdownStyleSheet(
                h1: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                h2: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                p: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
    );
  }
}
