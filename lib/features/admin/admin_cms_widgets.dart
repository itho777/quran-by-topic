import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reusable admin inline-edit dialog
// ─────────────────────────────────────────────────────────────────────────────
class AdminEditDialog extends StatefulWidget {
  final String title;
  final String initialText;
  final Future<void> Function(String newText) onSave;
  final bool multiline;

  const AdminEditDialog({
    super.key,
    required this.title,
    required this.initialText,
    required this.onSave,
    this.multiline = true,
  });

  /// Convenience: show the dialog and return true if saved.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String initialText,
    required Future<void> Function(String newText) onSave,
    bool multiline = true,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AdminEditDialog(
        title: title,
        initialText: initialText,
        onSave: onSave,
        multiline: multiline,
      ),
    );
  }

  @override
  State<AdminEditDialog> createState() => _AdminEditDialogState();
}

class _AdminEditDialogState extends State<AdminEditDialog> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Text cannot be empty');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.onSave(text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(widget.title,
                style: const TextStyle(color: AppTheme.onSurface, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              maxLines: widget.multiline ? 8 : 1,
              style: const TextStyle(color: AppTheme.onSurface, fontSize: 13, height: 1.6),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surfaceContainer,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.outline)),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: save a translation/transliteration row to Supabase
// ─────────────────────────────────────────────────────────────────────────────
Future<void> adminUpdateTranslation({
  required int verseId,
  required String sourceId,
  required String newText,
}) async {
  await Supabase.instance.client
      .from('translations')
      .update({'text': newText})
      .eq('verse_id', verseId)
      .eq('source_id', sourceId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: save a tafsir row to Supabase
// ─────────────────────────────────────────────────────────────────────────────
Future<void> adminUpdateTafsir({
  required int verseId,
  required String tafsirId,
  required String newText,
}) async {
  await Supabase.instance.client
      .from('tafsirs')
      .update({'text': newText})
      .eq('verse_id', verseId)
      .eq('tafsir_id', tafsirId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: save an asbabun_nuzul row to Supabase
// ─────────────────────────────────────────────────────────────────────────────
Future<void> adminUpdateNuzul({
  required int verseId,
  required String source,
  required String newText,
}) async {
  await Supabase.instance.client
      .from('asbabun_nuzul')
      .update({'text': newText})
      .eq('verse_id', verseId)
      .eq('source', source);
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: update a site_config key
// ─────────────────────────────────────────────────────────────────────────────
Future<void> adminUpdateSiteConfig(String key, String value) async {
  await Supabase.instance.client
      .from('site_config')
      .upsert({'key': key, 'value': value, 'updated_at': DateTime.now().toIso8601String()});
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline edit button — shown only to admins, next to content
// ─────────────────────────────────────────────────────────────────────────────
class AdminEditButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;

  const AdminEditButton({super.key, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.secondary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.edit_outlined, size: 13, color: AppTheme.secondary),
        ),
      ),
    );
  }
}
