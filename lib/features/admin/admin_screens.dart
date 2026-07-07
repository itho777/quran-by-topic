import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import 'admin_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Generic admin list screen — reused for translations, tafsirs, nuzul
// Pass table name + display columns
// ─────────────────────────────────────────────────────────────────────────────
class AdminTagsScreen extends StatefulWidget {
  const AdminTagsScreen({super.key});

  @override
  State<AdminTagsScreen> createState() => _AdminTagsScreenState();
}

class _AdminTagsScreenState extends State<AdminTagsScreen> {
  List<Map<String, dynamic>> _tags = [];
  bool _loading = true;
  String _searchQuery = '';
  String _filterLang = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await Supabase.instance.client
        .from('tags')
        .select()
        .order('id');
    final list = List<Map<String, dynamic>>.from(res);
    setState(() {
      _tags = list;
      _loading = false;
    });
  }

  Future<void> _delete(String id, String lang) async {
    final confirm = await showAdminConfirmDialog(context, 'Delete tag "$id" ($lang)?');
    if (!confirm) return;
    await Supabase.instance.client.from('tags').delete().eq('id', id).eq('lang', lang);
    _load();
  }

  List<Map<String, dynamic>> get _filtered {
    return _tags.where((t) {
      final matchSearch = _searchQuery.isEmpty ||
          (t['id'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (t['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      final matchLang = _filterLang == 'all' || t['lang'] == _filterLang;
      return matchSearch && matchLang;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: adminAppBar(context, 'Tags', onRefresh: _load),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
        icon: Icon(Icons.add),
        label: const Text('New Tag', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showTagForm(context),
      ),
      body: Column(
        children: [
          AdminSearchBar(
            hint: 'Search tags...',
            onChanged: (v) => setState(() => _searchQuery = v),
            trailing: _LangFilter(
              value: _filterLang,
              onChanged: (v) => setState(() => _filterLang = v),
            ),
          ),
          AdminCountBar(total: _tags.length, filtered: _filtered.length, label: 'tags'),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final t = _filtered[i];
                      return AdminListTile(
                        leading: _LangBadge(t['lang'] as String),
                        title: t['name'] as String,
                        subtitle: t['id'] as String,
                        onEdit: () => _showTagForm(context, existing: t),
                        onDelete: () => _delete(t['id'] as String, t['lang'] as String),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showTagForm(BuildContext context, {Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TagFormSheet(
        existing: existing,
        onSaved: _load,
      ),
    );
  }
}

class _TagFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _TagFormSheet({this.existing, required this.onSaved});

  @override
  State<_TagFormSheet> createState() => _TagFormSheetState();
}

class _TagFormSheetState extends State<_TagFormSheet> {
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _lang = 'id';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _idCtrl.text = widget.existing!['id'] as String;
      _nameCtrl.text = widget.existing!['name'] as String;
      _lang = widget.existing!['lang'] as String;
    }
  }

  Future<void> _save() async {
    if (_idCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final data = {'id': _idCtrl.text.trim(), 'name': _nameCtrl.text.trim(), 'lang': _lang};
    if (widget.existing != null) {
      await Supabase.instance.client.from('tags').upsert(data);
    } else {
      await Supabase.instance.client.from('tags').insert(data);
    }
    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AdminFormSheet(
      title: isEdit ? 'Edit Tag' : 'New Tag',
      saving: _saving,
      onSave: _save,
      fields: [
        AdminFormField(label: 'Tag ID (slug)', controller: _idCtrl, enabled: !isEdit, hint: 'e.g. iman'),
        const SizedBox(height: 12),
        AdminFormField(label: 'Display Name', controller: _nameCtrl, hint: 'e.g. Faith / Iman'),
        const SizedBox(height: 12),
        _LangSelector(value: _lang, onChanged: (v) => setState(() => _lang = v)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Translation Screen
// ─────────────────────────────────────────────────────────────────────────────
class AdminTranslationsScreen extends StatefulWidget {
  const AdminTranslationsScreen({super.key});

  @override
  State<AdminTranslationsScreen> createState() => _AdminTranslationsScreenState();
}

class _AdminTranslationsScreenState extends State<AdminTranslationsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _searchQuery = '';
  String _filterSource = 'all';

  static const _sources = ['all', 'id.kemenag', 'en.sahih', 'en.yusufali', 'en.pickthall'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await Supabase.instance.client
        .from('translations')
        .select('id, verse_key, source_id, text')
        .order('verse_key')
        .limit(200);
    setState(() {
      _rows = List<Map<String, dynamic>>.from(res);
      _loading = false;
    });
  }

  Future<void> _delete(int id) async {
    final confirm = await showAdminConfirmDialog(context, 'Delete this translation entry?');
    if (!confirm) return;
    await Supabase.instance.client.from('translations').delete().eq('id', id);
    _load();
  }

  List<Map<String, dynamic>> get _filtered => _rows.where((r) {
    final matchSearch = _searchQuery.isEmpty ||
        (r['verse_key'] as String).contains(_searchQuery) ||
        (r['text'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
    final matchSrc = _filterSource == 'all' || r['source_id'] == _filterSource;
    return matchSearch && matchSrc;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: adminAppBar(context, 'Translations', onRefresh: _load),
      body: Column(
        children: [
          AdminSearchBar(
            hint: 'Search by verse key or text...',
            onChanged: (v) => setState(() => _searchQuery = v),
            trailing: _SourceFilter(
              sources: _sources,
              value: _filterSource,
              onChanged: (v) => setState(() => _filterSource = v),
            ),
          ),
          AdminCountBar(total: _rows.length, filtered: _filtered.length, label: 'entries (showing first 200)'),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final r = _filtered[i];
                      return AdminListTile(
                        leading: _SourceBadge(r['source_id'] as String),
                        title: r['verse_key'] as String,
                        subtitle: (r['text'] as String).length > 80
                            ? '${(r['text'] as String).substring(0, 80)}…'
                            : r['text'] as String,
                        onEdit: () => _showEditSheet(context, r),
                        onDelete: () => _delete(r['id'] as int),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext ctx, Map<String, dynamic> row) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextEditSheet(
        title: 'Edit Translation',
        table: 'translations',
        id: row['id'] as int,
        verseKey: row['verse_key'] as String,
        sourceId: row['source_id'] as String,
        initialText: row['text'] as String,
        onSaved: _load,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Tafsir Screen
// ─────────────────────────────────────────────────────────────────────────────
class AdminTafsirsScreen extends StatefulWidget {
  const AdminTafsirsScreen({super.key});

  @override
  State<AdminTafsirsScreen> createState() => _AdminTafsirsScreenState();
}

class _AdminTafsirsScreenState extends State<AdminTafsirsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _searchQuery = '';
  String _filterSource = 'all';

  static const _sources = ['all', 'id.jalalayn', 'en.katsir', 'id.kemenag'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await Supabase.instance.client
        .from('tafsirs')
        .select('id, verse_key, source_id, text')
        .order('verse_key')
        .limit(200);
    setState(() {
      _rows = List<Map<String, dynamic>>.from(res);
      _loading = false;
    });
  }

  Future<void> _delete(int id) async {
    final confirm = await showAdminConfirmDialog(context, 'Delete this tafsir entry?');
    if (!confirm) return;
    await Supabase.instance.client.from('tafsirs').delete().eq('id', id);
    _load();
  }

  List<Map<String, dynamic>> get _filtered => _rows.where((r) {
    final matchSearch = _searchQuery.isEmpty ||
        (r['verse_key'] as String).contains(_searchQuery) ||
        (r['text'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
    final matchSrc = _filterSource == 'all' || r['source_id'] == _filterSource;
    return matchSearch && matchSrc;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: adminAppBar(context, 'Tafsirs', onRefresh: _load),
      body: Column(
        children: [
          AdminSearchBar(
            hint: 'Search by verse key or text...',
            onChanged: (v) => setState(() => _searchQuery = v),
            trailing: _SourceFilter(
              sources: _sources,
              value: _filterSource,
              onChanged: (v) => setState(() => _filterSource = v),
            ),
          ),
          AdminCountBar(total: _rows.length, filtered: _filtered.length, label: 'entries (showing first 200)'),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final r = _filtered[i];
                      return AdminListTile(
                        leading: _SourceBadge(r['source_id'] as String),
                        title: r['verse_key'] as String,
                        subtitle: (r['text'] as String).length > 80
                            ? '${(r['text'] as String).substring(0, 80)}…'
                            : r['text'] as String,
                        onEdit: () => _showEditSheet(context, r),
                        onDelete: () => _delete(r['id'] as int),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext ctx, Map<String, dynamic> row) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextEditSheet(
        title: 'Edit Tafsir',
        table: 'tafsirs',
        id: row['id'] as int,
        verseKey: row['verse_key'] as String,
        sourceId: row['source_id'] as String,
        initialText: row['text'] as String,
        onSaved: _load,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Asbabun Nuzul Screen
// ─────────────────────────────────────────────────────────────────────────────
class AdminNuzulScreen extends StatefulWidget {
  const AdminNuzulScreen({super.key});

  @override
  State<AdminNuzulScreen> createState() => _AdminNuzulScreenState();
}

class _AdminNuzulScreenState extends State<AdminNuzulScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _searchQuery = '';
  String _filterSource = 'all';

  static const _sources = ['all', 'en.wahidi', 'id.kemenag_nuzul'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await Supabase.instance.client
        .from('asbabun_nuzul')
        .select('id, verse_key, source_id, text')
        .order('verse_key')
        .limit(200);
    setState(() {
      _rows = List<Map<String, dynamic>>.from(res);
      _loading = false;
    });
  }

  Future<void> _delete(int id) async {
    final confirm = await showAdminConfirmDialog(context, 'Delete this Asbabun Nuzul entry?');
    if (!confirm) return;
    await Supabase.instance.client.from('asbabun_nuzul').delete().eq('id', id);
    _load();
  }

  List<Map<String, dynamic>> get _filtered => _rows.where((r) {
    final matchSearch = _searchQuery.isEmpty ||
        (r['verse_key'] as String).contains(_searchQuery) ||
        (r['text'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
    final matchSrc = _filterSource == 'all' || r['source_id'] == _filterSource;
    return matchSearch && matchSrc;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: adminAppBar(context, 'Asbabun Nuzul', onRefresh: _load),
      body: Column(
        children: [
          AdminSearchBar(
            hint: 'Search by verse key or text...',
            onChanged: (v) => setState(() => _searchQuery = v),
            trailing: _SourceFilter(
              sources: _sources,
              value: _filterSource,
              onChanged: (v) => setState(() => _filterSource = v),
            ),
          ),
          AdminCountBar(total: _rows.length, filtered: _filtered.length, label: 'entries (showing first 200)'),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final r = _filtered[i];
                      return AdminListTile(
                        leading: _SourceBadge(r['source_id'] as String),
                        title: r['verse_key'] as String,
                        subtitle: (r['text'] as String).length > 80
                            ? '${(r['text'] as String).substring(0, 80)}…'
                            : r['text'] as String,
                        onEdit: () => _showEditSheet(context, r),
                        onDelete: () => _delete(r['id'] as int),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext ctx, Map<String, dynamic> row) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextEditSheet(
        title: 'Edit Asbabun Nuzul',
        table: 'asbabun_nuzul',
        id: row['id'] as int,
        verseKey: row['verse_key'] as String,
        sourceId: row['source_id'] as String,
        initialText: row['text'] as String,
        onSaved: _load,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared: Edit text sheet for translations / tafsirs / nuzul
// ─────────────────────────────────────────────────────────────────────────────
class _TextEditSheet extends StatefulWidget {
  final String title;
  final String table;
  final int id;
  final String verseKey;
  final String sourceId;
  final String initialText;
  final VoidCallback onSaved;
  const _TextEditSheet({
    required this.title,
    required this.table,
    required this.id,
    required this.verseKey,
    required this.sourceId,
    required this.initialText,
    required this.onSaved,
  });

  @override
  State<_TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<_TextEditSheet> {
  late TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await Supabase.instance.client
        .from(widget.table)
        .update({'text': _ctrl.text.trim()})
        .eq('id', widget.id);
    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormSheet(
      title: widget.title,
      saving: _saving,
      onSave: _save,
      fields: [
        Row(children: [
          _SourceBadge(widget.sourceId),
          const SizedBox(width: 8),
          Text(widget.verseKey,
              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 12),
        AdminFormField(
          label: 'Text',
          controller: _ctrl,
          maxLines: 8,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _LangBadge extends StatelessWidget {
  final String lang;
  const _LangBadge(this.lang);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: lang == 'en' ? AppTheme.secondary.withValues(alpha: 0.15) : AppTheme.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      lang.toUpperCase(),
      style: TextStyle(
        color: lang == 'en' ? AppTheme.secondary : AppTheme.primary,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge(this.source);

  Color get _color => source.startsWith('en.')
      ? AppTheme.secondary
      : AppTheme.primary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      source,
      style: TextStyle(color: _color, fontSize: 9, fontWeight: FontWeight.bold),
    ),
  );
}

class _LangFilter extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _LangFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _FilterChips(
    options: const ['all', 'en', 'id'],
    value: value,
    onChanged: onChanged,
  );
}

class _SourceFilter extends StatelessWidget {
  final List<String> sources;
  final String value;
  final ValueChanged<String> onChanged;
  const _SourceFilter({required this.sources, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonHideUnderline(
    child: DropdownButton<String>(
      value: value,
      dropdownColor: AppTheme.surfaceContainer,
      icon: Icon(Icons.filter_list, color: AppTheme.outline, size: 16),
      style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
      onChanged: (v) { if (v != null) onChanged(v); },
      items: sources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
    ),
  );
}

class _FilterChips extends StatelessWidget {
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  const _FilterChips({required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    children: options.map((o) {
      final active = o == value;
      return GestureDetector(
        onTap: () => onChanged(o),
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? AppTheme.primary.withValues(alpha: 0.5) : Colors.transparent),
          ),
          child: Text(
            o.toUpperCase(),
            style: TextStyle(
              color: active ? AppTheme.primary : AppTheme.outline,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class _LangSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _LangSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('LANGUAGE', style: TextStyle(color: AppTheme.outline, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
      const SizedBox(height: 8),
      Row(
        children: ['id', 'en'].map((lang) {
          final active = lang == value;
          return GestureDetector(
            onTap: () => onChanged(lang),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: active ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: active ? AppTheme.primary.withValues(alpha: 0.5) : Colors.transparent),
              ),
              child: Text(
                lang.toUpperCase(),
                style: TextStyle(color: active ? AppTheme.primary : AppTheme.outline, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          );
        }).toList(),
      ),
    ],
  );
}
