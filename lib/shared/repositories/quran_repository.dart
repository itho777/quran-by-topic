import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../models/surah.dart';

final quranRepositoryProvider = Provider<QuranRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return QuranRepository(client);
});

class QuranRepository {
  final SupabaseClient _client;

  QuranRepository(this._client);

  /// Fetch all 114 Surahs ordered by ID.
  Future<List<Surah>> getSurahs() async {
    final response = await _client
        .from('surahs')
        .select('*')
        .order('id', ascending: true);
    
    return (response as List).map((json) => Surah.fromJson(json)).toList();
  }

  /// Fetch verses of a Surah joined with the selected translation.
  Future<List<Map<String, dynamic>>> getVersesWithTranslation({
    required int suraId,
    required String translationSourceId,
  }) async {
    final response = await _client
        .from('verses')
        .select('*, translations(text)')
        .eq('sura_id', suraId)
        .eq('translations.source_id', translationSourceId)
        .order('ayah_number', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Search for an exact word using the Supabase search_exact_word RPC function.
  Future<List<Map<String, dynamic>>> searchExactWord({
    required String query,
    required String langCode,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.rpc('search_exact_word', params: {
      'search_query': query,
      'lang_code': langCode,
      'limit_val': limit,
      'offset_val': offset,
    });

    return List<Map<String, dynamic>>.from(response);
  }
}
