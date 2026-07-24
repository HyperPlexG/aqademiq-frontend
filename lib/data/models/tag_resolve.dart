import 'tag.dart';

/// Resolve a task's stored tag reference to a [Tag] for Plan chips / overflow.
///
/// The wire `category` / `Task.tagId` is normally the study-tag UUID. Older rows
/// (and Ada proposals) may store a label or legacy enum instead — match those
/// case-insensitively by label so a valid tag is never shown as raw "other".
Tag? resolveStudyTag(Iterable<Tag> tags, String? tagRef) {
  if (tagRef == null) return null;
  final key = tagRef.trim();
  if (key.isEmpty) return null;

  for (final t in tags) {
    if (t.id == key) return t;
  }

  final lower = key.toLowerCase();
  for (final t in tags) {
    if (t.label.toLowerCase() == lower) return t;
  }
  return null;
}

/// Display label when a [Tag] may already be resolved (cards / overflow).
///
/// Prefer the resolved study-tag label; otherwise show the stored ref unless it
/// is a known empty/legacy placeholder (`other` / `general`).
String studyTagLabel(Tag? tag, String? tagRef, {String fallback = 'Untagged'}) {
  if (tag != null) return tag.label;

  final key = tagRef?.trim() ?? '';
  if (key.isEmpty) return fallback;

  // Legacy coerced value — never present it as if the user chose it.
  if (key.toLowerCase() == 'other' || key.toLowerCase() == 'general') {
    return fallback;
  }
  return key;
}

/// Display label looking up from the full study-tag list.
String studyTagLabelFromTags(Iterable<Tag> tags, String? tagRef, {String fallback = 'Untagged'}) {
  return studyTagLabel(resolveStudyTag(tags, tagRef), tagRef, fallback: fallback);
}
