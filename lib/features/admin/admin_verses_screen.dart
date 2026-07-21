import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminVersesScreen extends StatefulWidget {
  const AdminVersesScreen({super.key});

  @override
  State<AdminVersesScreen> createState() => _AdminVersesScreenState();
}

class _AdminVersesScreenState extends State<AdminVersesScreen>
    with SingleTickerProviderStateMixin {
  final _db = Supabase.instance.client;

  List<Map<String, dynamic>> _surahs = [];
  int _selectedSurahId = 1;
  String _selectedSurahName = 'Al-Fatiha';
  List<Map<String, dynamic>> _verses = [];
  bool _loadingVerses = false;
  Map<String, dynamic>? _selectedVerse;
  bool _loadingDetail = false;
  bool _saving = false;

  late TextEditingController _ctrlTransId;
  late TextEditingController _ctrlTransEn;
  late TextEditingController _ctrlTafsirJalalayn;
  late TextEditingController _ctrlTafsirKatsir;
  late TextEditingController _ctrlNuzul;

  String _verseSearch = '';
  late TabController _editTabController;

  @override
  void initState() {
    super.initState();
    _editTabController = TabController(length: 3, vsync: this);
    _ctrlTransId = TextEditingController();
    _ctrlTransEn = TextEditingController();
    _ctrlTafsirJalalayn = TextEditingController();
    _ctrlTafsirKatsir = TextEditingController();
    _ctrlNuzul = TextEditingController();
    _loadSurahs();
  }

  @override
  void dispose() {
    _editTabController.dispose();
    _ctrlTransId.dispose();
    _ctrlTransEn.dispose();
    _ctrlTafsirJalalayn.dispose();
    _ctrlTafsirKatsir.dispose();
    _ctrlNuzul.dispose();
    super.dispose();
  }

  Future<void> _loadSurahs() async {
    final res = await _db.from('surahs').select('id, name_en, name_id').order('id');
    if (!mounted) return;
    setState(() => _surahs = List<Map<String, dynamic>>.from(res));
    _loadVerses(_selectedSurahId);
  }

  Future<void> _loadVerses(int surahId) async {
    setState(() { _loadingVerses = true; _selectedVerse = null; });
    final res = await _db
        .from('verses')
        .select('id, sura_id, ayah_number, text_ar')
        .eq('sura_id', surahId)
        .order('ayah_number');
    if (!mounted) return;
    setState(() {
      _verses = List<Map<String, dynamic>>.from(res);
      _loadingVerses = false;
    });
  }

  Future<void> _loadVerseDetail(Map<String, dynamic> verse) async {
    setState(() { _selectedVerse = verse; _loadingDetail = true; });
    _ctrlTransId.clear(); _ctrlTransEn.clear();
    _ctrlTafsirJalalayn.clear(); _ctrlTafsirKatsir.clear(); _ctrlNuzul.clear();

    final verseId = verse['id'] as int;
    try {
      final results = await Future.wait([
        _db.from('translations').select('source_id, text').eq('verse_id', verseId),
        _db.from('tafsirs').select('tafsir_id, text').eq('verse_id', verseId),
        _db.from('asbabun_nuzul').select('source, text').eq('verse_id', verseId),
      ]);

      final trans = Map.fromEntries(
        List<Map<String, dynamic>>.from(results[0])
            .map((r) => MapEntry(r['source_id'] as String, r['text'] as String)),
      );
      final tafsirs = Map.fromEntries(
        List<Map<String, dynamic>>.from(results[1])
            .map((r) => MapEntry(r['tafsir_id'] as String, r['text'] as String)),
      );
      final nuzul = Map.fromEntries(
        List<Map<String, dynamic>>.from(results[2])
            .map((r) => MapEntry(r['source'] as String, r['text'] as String)),
      );

      if (!mounted) return;
      setState(() {
        _ctrlTransId.text = trans['id.kemenag'] ?? '';
        _ctrlTransEn.text = trans['en.sahih'] ?? trans['en.sahih-international'] ?? '';
        _ctrlTafsirJalalayn.text = tafsirs['id.jalalayn'] ?? '';
        _ctrlTafsirKatsir.text = tafsirs['en.katsir'] ?? tafsirs['en.ibn-kathir'] ?? '';
        _ctrlNuzul.text = nuzul['en.wahidi'] ?? nuzul['id.wahidi'] ?? '';
        _loadingDetail = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  Future<void> _saveVerseDetail() async {
    final verse = _selectedVerse;
    if (verse == null) return;
    final verseId = verse['id'] as int;
    setState(() => _saving = true);

    Future<void> upsertTrans(String sid, String text) async {
      if (text.isEmpty) return;
      await _db.from('translations').upsert(
        {'verse_id': verseId, 'source_id': sid, 'text': text},
        onConflict: 'verse_id,source_id',
      );
    }

    Future<void> upsertTafsir(String tid, String text) async {
      if (text.isEmpty) return;
      await _db.from('tafsirs').upsert(
        {'verse_id': verseId, 'tafsir_id': tid, 'text': text},
        onConflict: 'verse_id,tafsir_id',
      );
    }

    try {
      await Future.wait([
        upsertTrans('id.kemenag', _ctrlTransId.text.trim()),
        upsertTrans('en.sahih', _ctrlTransEn.text.trim()),
        upsertTafsir('id.jalalayn', _ctrlTafsirJalalayn.text.trim()),
        upsertTafsir('en.katsir', _ctrlTafsirKatsir.text.trim()),
        if (_ctrlNuzul.text.trim().isNotEmpty)
          _db.from('asbabun_nuzul').upsert(
            {'verse_id': verseId, 'source': 'en.wahidi', 'text': _ctrlNuzul.text.trim()},
            onConflict: 'verse_id,source',
          ),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verse saved successfully'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Map<String, dynamic>> get _filteredVerses {
    if (_verseSearch.isEmpty) return _verses;
    final q = _verseSearch.toLowerCase();
    return _verses.where((v) =>
      v['ayah_number'].toString().contains(q) ||
      (v['text_ar'] as String? ?? '').contains(q),
    ).toList();
  }

  String get _selectedVerseKey {
    final v = _selectedVerse;
    if (v == null) return '';
    return '$_selectedSurahId:${v['ayah_number']}';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Verse Content Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () {
              _loadVerses(_selectedSurahId);
              if (_selectedVerse != null) _loadVerseDetail(_selectedVerse!);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildWideLayout() => Row(children: [
    SizedBox(width: 300, child: _buildVerseListPanel()),
    const VerticalDivider(width: 1, thickness: 1),
    Expanded(child: _buildEditPane()),
  ]);

  Widget _buildNarrowLayout() {
    if (_selectedVerse == null) return _buildVerseListPanel();
    return _buildEditPane();
  }

  Widget _buildVerseListPanel() => Column(children: [
    // Surah picker
    Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: _surahs.isEmpty
          ? const LinearProgressIndicator()
          : DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: _selectedSurahId,
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _selectedSurahId = val;
                    _selectedSurahName = _surahs.firstWhere((s) => s['id'] == val)['name_en'] as String;
                  });
                  _loadVerses(val);
                },
                items: _surahs.map((s) => DropdownMenuItem(
                  value: s['id'] as int,
                  child: Text('${s['id']}. ${s['name_en']}', overflow: TextOverflow.ellipsis),
                )).toList(),
              ),
            ),
    ),
    // Search box
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search by ayah number…',
          prefixIcon: const Icon(Icons.search, size: 18),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (q) => setState(() => _verseSearch = q),
      ),
    ),
    // Verse list
    Expanded(
      child: _loadingVerses
          ? const Center(child: CircularProgressIndicator())
          : _filteredVerses.isEmpty
              ? Center(child: Text('No verses found',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline)))
              : ListView.builder(
                  itemCount: _filteredVerses.length,
                  itemBuilder: (ctx, i) {
                    final v = _filteredVerses[i];
                    final isSelected = _selectedVerse?['id'] == v['id'];
                    final cs = Theme.of(context).colorScheme;
                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      selectedTileColor: cs.primary.withValues(alpha: 0.1),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected
                            ? cs.primary.withValues(alpha: 0.15)
                            : cs.surfaceContainerHighest,
                        child: Text(
                          '${v['ayah_number']}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? cs.primary : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      title: Text(
                        ((v['text_ar'] as String? ?? '').length > 45
                            ? '${(v['text_ar'] as String).substring(0, 45)}…'
                            : v['text_ar'] as String? ?? ''),
                        style: const TextStyle(fontFamily: 'Noto Naskh Arabic', fontSize: 13, height: 1.8),
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _loadVerseDetail(v),
                    );
                  },
                ),
    ),
  ]);

  Widget _buildEditPane() {
    if (_selectedVerse == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.touch_app_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 14),
          Text('Select a verse to edit its content',
              style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ]),
      );
    }
    if (_loadingDetail) return const Center(child: CircularProgressIndicator());

    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      // Pane header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: cs.surfaceContainerLow,
        child: Row(children: [
          if (MediaQuery.of(context).size.width <= 700)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _selectedVerse = null),
            ),
          if (MediaQuery.of(context).size.width <= 700) const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_selectedVerseKey,
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Text(_selectedSurahName,
              style: TextStyle(color: cs.outline, fontSize: 12)),
          const Spacer(),
          FilledButton.icon(
            onPressed: _saving ? null : _saveVerseDetail,
            icon: _saving
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 16),
            label: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ]),
      ),
      // Arabic display
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: cs.surfaceContainerHighest,
        child: Text(
          _selectedVerse!['text_ar'] as String? ?? '',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Noto Naskh Arabic', fontSize: 20, height: 2.0),
        ),
      ),
      // Tabs
      TabBar(
        controller: _editTabController,
        labelColor: cs.primary,
        unselectedLabelColor: cs.outline,
        indicatorColor: cs.primary,
        tabs: const [
          Tab(text: 'Translations'),
          Tab(text: 'Tafsirs'),
          Tab(text: 'Asbabun Nuzul'),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _editTabController,
          children: [
            _buildTranslationsTab(),
            _buildTafsirsTab(),
            _buildNuzulTab(),
          ],
        ),
      ),
    ]);
  }

  Widget _buildTranslationsTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel('Indonesian Translation (Kemenag)'),
      _textArea(_ctrlTransId, 6, 'id.kemenag'),
      const SizedBox(height: 16),
      _fieldLabel('English Translation (Sahih Int.)'),
      _textArea(_ctrlTransEn, 6, 'en.sahih'),
    ]),
  );

  Widget _buildTafsirsTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel('Tafsir Jalalayn (Indonesian)'),
      _textArea(_ctrlTafsirJalalayn, 8, 'id.jalalayn'),
      const SizedBox(height: 16),
      _fieldLabel('Tafsir Ibn Kathir (English)'),
      _textArea(_ctrlTafsirKatsir, 8, 'en.katsir'),
    ]),
  );

  Widget _buildNuzulTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel('Asbabun Nuzul (Al-Wahidi)'),
      _textArea(_ctrlNuzul, 12, 'en.wahidi'),
    ]),
  );

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    )),
  );

  Widget _textArea(TextEditingController ctrl, int lines, String hint) =>
    TextField(
      controller: ctrl,
      maxLines: lines,
      style: const TextStyle(fontSize: 13, height: 1.6),
      decoration: InputDecoration(
        hintText: 'source: $hint',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
}
