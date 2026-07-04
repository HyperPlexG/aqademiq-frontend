import 'package:dio/dio.dart';

import '../dtos/tag_dto.dart';
import '../fixtures/fixtures.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

abstract interface class TagsSource {
  Future<List<TagDto>> all();

  /// Create a tag and return the full, updated list.
  Future<List<TagDto>> create(TagDto tag);

  /// Delete a tag by id and return the full, updated list.
  Future<List<TagDto>> delete(String id);
}

class MockTagsSource implements TagsSource {
  /// Mutable in-memory store seeded from fixtures so create/delete persist for
  /// the session (README §7, seam 3).
  final List<TagDto> _tags = [
    ...Fixtures.tags,
    ...Fixtures.studyTagPalette,
  ];

  @override
  Future<List<TagDto>> all() => mockDelay(List.unmodifiable(_tags));

  @override
  Future<List<TagDto>> create(TagDto tag) {
    _tags.add(tag);
    return all();
  }

  @override
  Future<List<TagDto>> delete(String id) {
    _tags.removeWhere((t) => t.id == id);
    return all();
  }
}

/// Live impl — `/v1/study-tags` (contract §12.L). Note deletion is **by label**,
/// so we keep an id→label cache populated on every list/create.
class ApiTagsSource implements TagsSource {
  ApiTagsSource(this._dio);
  final Dio _dio;

  final Map<String, String> _labelById = {};

  @override
  Future<List<TagDto>> all() async {
    final body = await _dio.getMap('/study-tags');
    final tags = listOf(body, 'tags').map(_toDto).toList(growable: false);
    for (final t in tags) {
      _labelById[t.id] = t.label;
    }
    return tags;
  }

  @override
  Future<List<TagDto>> create(TagDto tag) async {
    await _dio.postMap('/study-tags', {
      'label': tag.label,
      if (tag.color.isNotEmpty) 'color': tag.color,
    });
    return all();
  }

  @override
  Future<List<TagDto>> delete(String id) async {
    final label = _labelById[id] ?? id;
    await _dio.deleteMap('/study-tags/${Uri.encodeComponent(label)}');
    return all();
  }

  TagDto _toDto(Map<String, dynamic> j) => TagDto(
        id: j['id'] as String? ?? '',
        label: j['label'] as String? ?? '',
        color: j['color'] as String? ?? '#8E8E93',
      );
}
