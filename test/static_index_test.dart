import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_id/core/static_index_service.dart';

void main() {
  group('StaticIndexService Tests', () {
    final service = StaticIndexService.instance;

    setUp(() {
      // Set up a mock search index
      service.setIndexForTesting({
        'patience': '1:1,2:15',
        'judgment': '1:1,1:2,3:4',
        'merciful': '1:1,2:15,3:4',
        'sabrun': '2:15,10:2',
        'salam': '1:1',
      });
    });

    test('isReady should be true when index is populated', () {
      expect(service.isReady, isTrue);
    });

    test('Exact match queries search and score correctly', () async {
      final results = await service.search('patience');
      expect(results, isNotEmpty);
      expect(results.length, equals(2));

      // Scoring: exact matches get 2 points
      expect(results[0].verseKey, equals('1:1'));
      expect(results[0].score, equals(2));

      expect(results[1].verseKey, equals('2:15'));
      expect(results[1].score, equals(2));
    });

    test('Multiple words matching combination queries', () async {
      final results = await service.search('judgment merciful');
      expect(results, isNotEmpty);

      // 'judgment' matches: 1:1, 1:2, 3:4
      // 'merciful' matches: 1:1, 2:15, 3:4
      // 1:1 has both: score should be 4
      // 3:4 has both: score should be 4
      // 1:2 has 'judgment': score should be 2
      // 2:15 has 'merciful': score should be 2
      
      final resultKeys = results.map((r) => r.verseKey).toList();
      expect(resultKeys, containsAll(['1:1', '3:4', '1:2', '2:15']));

      final first = results.firstWhere((r) => r.verseKey == '1:1');
      expect(first.score, equals(4));

      final third = results.firstWhere((r) => r.verseKey == '1:2');
      expect(third.score, equals(2));
    });

    test('Prefix search logic works (length >= 4)', () async {
      // 'pati' is a prefix of 'patience', length 4
      final results = await service.search('pati');
      expect(results, isNotEmpty);
      
      // Prefix match score is 1 point
      expect(results[0].verseKey, equals('1:1'));
      expect(results[0].score, equals(1));
    });

    test('Tokenizer ignores short words and stop words', () async {
      // 'the' is a stop word, 'of' is a stop word, 'it' is too short (< 3 chars)
      final results = await service.search('the of it');
      expect(results, isEmpty);
    });

    test('Arabic Unicode support tokenizes correctly', () async {
      // 'sabrun' and 'salam'
      final results = await service.search('salam');
      expect(results, isNotEmpty);
      expect(results[0].verseKey, equals('1:1'));
    });
  });
}
