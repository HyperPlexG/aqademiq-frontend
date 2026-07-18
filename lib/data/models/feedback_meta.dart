import 'package:meta/meta.dart';

/// Board configuration from `GET /feedback/meta` — the set of statuses and
/// categories, with display labels and colors, that the backend recognises.
/// Loaded once when the board opens and used to drive the filter pills
/// (INTEGRATION.md §4 step 1). Hand-written / codegen-free like the rest of the
/// feedback feature.
@immutable
class FeedbackMeta {
  const FeedbackMeta({this.statuses = const [], this.categories = const []});

  final List<FeedbackStatusMeta> statuses;
  final List<FeedbackCategoryMeta> categories;
}

/// One status key with its label, color and whether it appears on the roadmap.
@immutable
class FeedbackStatusMeta {
  const FeedbackStatusMeta({
    required this.key,
    required this.label,
    this.color,
    this.onRoadmap = false,
  });

  final String key;
  final String label;

  /// Hex color string from the backend (e.g. `#5CBBFF`), if provided. The UI
  /// prefers its own theme-aware color and treats this as advisory.
  final String? color;
  final bool onRoadmap;
}

/// One category key with its display label.
@immutable
class FeedbackCategoryMeta {
  const FeedbackCategoryMeta({required this.key, required this.label});

  final String key;
  final String label;
}
