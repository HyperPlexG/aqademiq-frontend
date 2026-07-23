import 'package:flutter/material.dart';

import '../../core/theme/app_text.dart';

/// Renders the Markdown an LLM actually emits — emphasis, code, headings, lists,
/// rules, quotes, tables, links, and light LaTeX — as styled text.
///
/// Deliberately hand-rolled rather than pulling in a package: `flutter_markdown`
/// is discontinued, and every alternative would still need re-theming onto the
/// design tokens (Plus Jakarta Sans / JetBrains Mono, semantic colours).
///
/// **Maths is approximated, not typeset.** `$…$` is unwrapped and common LaTeX
/// is mapped to Unicode (`\frac{a}{b}` → `a⁄b`, `x^2` → `x²`, `\alpha` → `α`).
/// That covers the inline notation Ada uses when explaining a formula; it is not
/// a TeX engine, and a full derivation will still look rough.
///
/// Unsupported syntax degrades to literal text rather than being swallowed, so a
/// malformed response renders exactly as the old plain `Text` did.
class MarkdownText extends StatelessWidget {
  const MarkdownText(
    this.data, {
    required this.style,
    super.key,
    this.muted,
    this.accent,
  });

  /// Raw Markdown.
  final String data;

  /// Base body style; headings, code and maths derive from it.
  final TextStyle style;

  /// Colour for list markers, rules and quote bars. Defaults to [style]'s colour.
  final Color? muted;

  /// Colour for links. Defaults to [style]'s colour.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(data.trim());
    if (blocks.isEmpty) return Text(data, style: style);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: _gapBefore(blocks[i], blocks[i - 1])),
          _block(blocks[i]),
        ],
      ],
    );
  }

  /// Tighter spacing between items of the same list; roomier between sections.
  double _gapBefore(_Block block, _Block previous) {
    if (block.isListItem && previous.isListItem) return 3;
    if (block.kind == _Kind.rule || previous.kind == _Kind.rule) return 10;
    return 8;
  }

  Widget _block(_Block block) {
    final dim = muted ?? style.color;
    switch (block.kind) {
      case _Kind.rule:
        return Container(height: 1, color: dim?.withValues(alpha: 0.35));

      case _Kind.heading:
        return Text.rich(
          TextSpan(children: _inline(block.text, _headingStyle(block.level))),
        );

      case _Kind.quote:
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 2, color: dim?.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: _inline(
                      block.text,
                      style.copyWith(fontStyle: FontStyle.italic, color: dim),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case _Kind.code:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: dim?.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              block.text,
              style: AppText.mono(
                size: (style.fontSize ?? 12) - 1,
                color: style.color,
              ).copyWith(height: 1.45),
            ),
          ),
        );

      case _Kind.table:
        return _table(block.rows, dim);

      case _Kind.bullet:
      case _Kind.ordered:
        final marker = block.kind == _Kind.ordered ? '${block.number}.' : '•';
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(left: block.indent * 10.0),
              child: SizedBox(
                width: block.kind == _Kind.ordered ? 18 : 12,
                child: Text(
                  marker,
                  style: style.copyWith(color: dim, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Flexible(
              child: Text.rich(TextSpan(children: _inline(block.text, style))),
            ),
          ],
        );

      case _Kind.paragraph:
        return Text.rich(TextSpan(children: _inline(block.text, style)));
    }
  }

  /// Tables scroll horizontally — a chat bubble is far too narrow to fit one.
  Widget _table(List<List<String>> rows, Color? dim) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < rows.length; r++)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: (dim ?? const Color(0x00000000)).withValues(alpha: 0.25),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final cell in rows[r])
                    Container(
                      width: 96,
                      padding: const EdgeInsets.only(right: 8),
                      child: Text.rich(
                        TextSpan(
                          children: _inline(
                            cell,
                            r == 0
                                ? style.copyWith(fontWeight: FontWeight.w800)
                                : style,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  TextStyle _headingStyle(int level) => style.copyWith(
        fontSize: (style.fontSize ?? 12) + (level == 1 ? 3 : (level == 2 ? 2 : 1)),
        fontWeight: FontWeight.w800,
        height: 1.3,
      );

  List<InlineSpan> _inline(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in _inlinePattern.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start), style: base));
      }
      spans.add(_span(m, base));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: base));
    }
    return spans;
  }

  InlineSpan _span(RegExpMatch m, TextStyle base) {
    final size = base.fontSize ?? 12;
    if (m.group(1) != null) {
      return TextSpan(text: m.group(1), style: base.copyWith(fontWeight: FontWeight.w800));
    }
    if (m.group(2) != null) {
      return TextSpan(text: m.group(2), style: base.copyWith(fontStyle: FontStyle.italic));
    }
    if (m.group(3) != null) {
      return TextSpan(
        text: m.group(3),
        style: base.copyWith(decoration: TextDecoration.lineThrough),
      );
    }
    if (m.group(4) != null) return _shifted(m.group(4)!, base, up: true);
    if (m.group(5) != null) return _shifted(m.group(5)!, base, up: false);
    if (m.group(6) != null) {
      return TextSpan(
        text: m.group(6),
        style: AppText.mono(size: size - 1, color: base.color),
      );
    }
    if (m.group(7) != null) {
      // The URL (group 8) is intentionally not tappable here: opening links from
      // model output is a separate decision from rendering it.
      return TextSpan(
        text: m.group(7),
        style: base.copyWith(
          color: accent ?? base.color,
          decoration: TextDecoration.underline,
          decorationColor: (accent ?? base.color)?.withValues(alpha: 0.5),
        ),
      );
    }
    if (m.group(9) != null) {
      return TextSpan(
        text: _mathToUnicode(m.group(9)!),
        style: base.copyWith(fontStyle: FontStyle.italic),
      );
    }
    return TextSpan(text: m[0], style: base);
  }

  /// True super/subscript via a baseline shift, so it works for any content
  /// rather than only the characters Unicode happens to provide.
  InlineSpan _shifted(String text, TextStyle base, {required bool up}) {
    final size = base.fontSize ?? 12;
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Transform.translate(
        offset: Offset(0, up ? -size * 0.32 : size * 0.16),
        child: Text(text, style: base.copyWith(fontSize: size * 0.72)),
      ),
    );
  }
}

// ---------------------------------------------------------------- inline scan

/// Ordered alternation — longer delimiters must precede their prefixes (`**`
/// before `*`, `~~` before `~`) or the shorter one wins and eats the text.
///
/// Emphasis delimiters must hug their content (`\S` immediately inside each
/// marker), which is CommonMark's rule and keeps arithmetic intact: without it
/// `2 * 3 = 6` parsed as an emphasis run and the asterisks disappeared.
///
/// `_underscore_` italics are intentionally unsupported: Ada quotes identifiers
/// such as `consent_given`, and treating those as emphasis ate the underscores.
final RegExp _inlinePattern = RegExp(
  r'\*\*(\S(?:[^\n]*?\S)?)\*\*' //        1 bold
  r'|\*(\S(?:[^*\n]*?\S)?)\*' //          2 italic
  r'|~~(\S(?:[^\n]*?\S)?)~~' //           3 strikethrough
  r'|\^([^\s^]+)\^' //                    4 superscript  x^2^
  r'|~([^\s~]+)~' //                      5 subscript    H~2~O
  r'|`([^`\n]+?)`' //                     6 inline code
  r'|\[([^\]\n]+)\]\(([^)\s]+)\)' //      7 link text, 8 url
  r'|\$([^$\n]+?)\$', //                  9 inline maths
);

const _superscripts = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶',
  '7': '⁷', '8': '⁸', '9': '⁹', '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽',
  ')': '⁾', 'n': 'ⁿ', 'i': 'ⁱ', 'x': 'ˣ', 'y': 'ʸ', 'a': 'ᵃ', 'b': 'ᵇ',
  'c': 'ᶜ', 'd': 'ᵈ', 'k': 'ᵏ', 'm': 'ᵐ', 'p': 'ᵖ', 't': 'ᵗ',
};

const _subscripts = {
  '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄', '5': '₅', '6': '₆',
  '7': '₇', '8': '₈', '9': '₉', '+': '₊', '-': '₋', '=': '₌', '(': '₍',
  ')': '₎', 'a': 'ₐ', 'e': 'ₑ', 'i': 'ᵢ', 'j': 'ⱼ', 'k': 'ₖ', 'l': 'ₗ',
  'm': 'ₘ', 'n': 'ₙ', 'o': 'ₒ', 'p': 'ₚ', 'r': 'ᵣ', 's': 'ₛ', 't': 'ₜ',
  'u': 'ᵤ', 'v': 'ᵥ', 'x': 'ₓ',
};

const _latexSymbols = {
  r'\times': '×', r'\cdot': '·', r'\div': '÷', r'\pm': '±', r'\mp': '∓',
  r'\leq': '≤', r'\geq': '≥', r'\neq': '≠', r'\approx': '≈', r'\equiv': '≡',
  r'\infty': '∞', r'\sum': 'Σ', r'\prod': 'Π', r'\int': '∫', r'\partial': '∂',
  r'\nabla': '∇', r'\sqrt': '√', r'\in': '∈', r'\notin': '∉', r'\subset': '⊂',
  r'\forall': '∀', r'\exists': '∃', r'\rightarrow': '→', r'\to': '→',
  r'\Rightarrow': '⇒', r'\leftarrow': '←', r'\alpha': 'α', r'\beta': 'β',
  r'\gamma': 'γ', r'\delta': 'δ', r'\epsilon': 'ε', r'\theta': 'θ',
  r'\lambda': 'λ', r'\mu': 'μ', r'\pi': 'π', r'\rho': 'ρ', r'\sigma': 'σ',
  r'\tau': 'τ', r'\phi': 'φ', r'\omega': 'ω', r'\Delta': 'Δ', r'\Sigma': 'Σ',
  r'\Omega': 'Ω', r'\ldots': '…', r'\cdots': '⋯',
};

final RegExp _fracPattern = RegExp(r'\\frac\s*\{([^{}]*)\}\s*\{([^{}]*)\}');
final RegExp _sqrtPattern = RegExp(r'\\sqrt\s*\{([^{}]*)\}');
final RegExp _supPattern = RegExp(r'\^\{([^{}]*)\}|\^(\w)');
final RegExp _subPattern = RegExp(r'_\{([^{}]*)\}|_(\w)');

/// Best-effort LaTeX → Unicode. Anything unrecognised is left as written, which
/// is strictly better than dropping it.
String _mathToUnicode(String input) {
  var s = input.trim();
  s = s.replaceAllMapped(_fracPattern, (m) => '${m[1]}⁄${m[2]}');
  s = s.replaceAllMapped(_sqrtPattern, (m) => '√(${m[1]})');
  _latexSymbols.forEach((tex, glyph) => s = s.replaceAll(tex, glyph));
  s = s.replaceAllMapped(_supPattern, (m) => _map(m[1] ?? m[2] ?? '', _superscripts, '^'));
  s = s.replaceAllMapped(_subPattern, (m) => _map(m[1] ?? m[2] ?? '', _subscripts, '_'));
  return s.replaceAll('{', '').replaceAll('}', '').replaceAll(r'\,', ' ').trim();
}

/// Maps every character, or falls back to the original notation if any character
/// has no Unicode form — a half-converted `x²ʸ?` is worse than `x^{2y}`.
String _map(String text, Map<String, String> table, String marker) {
  final out = StringBuffer();
  for (final ch in text.split('')) {
    final mapped = table[ch.toLowerCase()];
    if (mapped == null) return '$marker$text';
    out.write(mapped);
  }
  return out.toString();
}

// ---------------------------------------------------------------- block scan

enum _Kind { paragraph, heading, bullet, ordered, rule, quote, code, table }

class _Block {
  _Block(
    this.kind,
    this.text, {
    this.level = 1,
    this.number = 1,
    this.indent = 0,
    this.rows = const [],
  });

  final _Kind kind;
  final String text;
  final int level;
  final int number;
  final int indent;
  final List<List<String>> rows;

  bool get isListItem => kind == _Kind.bullet || kind == _Kind.ordered;
}

final RegExp _headingPattern = RegExp(r'^(#{1,6})\s+(.*)$');
final RegExp _bulletPattern = RegExp(r'^(\s*)[-*+•]\s+(.*)$');
final RegExp _orderedPattern = RegExp(r'^(\s*)(\d{1,3})[.)]\s+(.*)$');
final RegExp _rulePattern = RegExp(r'^\s*([-*_])\s*(\1\s*){2,}$');
final RegExp _quotePattern = RegExp(r'^\s*>\s?(.*)$');
final RegExp _fencePattern = RegExp(r'^\s*```');
final RegExp _displayMathPattern = RegExp(r'^\s*\$\$(.*)\$\$\s*$');

/// Line-based block parse. Consecutive plain lines fold into one paragraph so
/// hard-wrapped model output does not render as a stack of one-line blocks.
List<_Block> _parseBlocks(String source) {
  final blocks = <_Block>[];
  final paragraph = <String>[];
  final lines = source.split('\n');

  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(_Block(_Kind.paragraph, paragraph.join(' ').trim()));
    paragraph.clear();
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trimRight();

    if (line.trim().isEmpty) {
      flush();
      continue;
    }

    // Fenced code — consume through the closing fence (or end of input).
    if (_fencePattern.hasMatch(line)) {
      flush();
      final body = <String>[];
      i++;
      while (i < lines.length && !_fencePattern.hasMatch(lines[i])) {
        body.add(lines[i]);
        i++;
      }
      blocks.add(_Block(_Kind.code, body.join('\n')));
      continue;
    }

    // `---` before the bullet rule: `- - -` is a rule, not three list items.
    if (_rulePattern.hasMatch(line)) {
      flush();
      blocks.add(_Block(_Kind.rule, ''));
      continue;
    }

    final display = _displayMathPattern.firstMatch(line);
    if (display != null) {
      flush();
      blocks.add(_Block(_Kind.paragraph, '\$${display.group(1)!.trim()}\$'));
      continue;
    }

    final heading = _headingPattern.firstMatch(line);
    if (heading != null) {
      flush();
      blocks.add(_Block(
        _Kind.heading,
        heading.group(2)!.trim(),
        level: heading.group(1)!.length,
      ));
      continue;
    }

    final quote = _quotePattern.firstMatch(line);
    if (quote != null) {
      flush();
      blocks.add(_Block(_Kind.quote, quote.group(1)!.trim()));
      continue;
    }

    // Table: a pipe row, with the next line either a separator or another row.
    if (line.trimLeft().startsWith('|') && line.contains('|', 1)) {
      flush();
      final rows = <List<String>>[];
      while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
        final cells = _cells(lines[i]);
        // `|---|---|` is alignment scaffolding, not data.
        if (!cells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c.trim()))) {
          rows.add(cells);
        }
        i++;
      }
      i--;
      blocks.add(_Block(_Kind.table, '', rows: rows));
      continue;
    }

    final ordered = _orderedPattern.firstMatch(line);
    if (ordered != null) {
      flush();
      blocks.add(_Block(
        _Kind.ordered,
        ordered.group(3)!.trim(),
        number: int.tryParse(ordered.group(2)!) ?? 1,
        indent: (ordered.group(1)!.length / 2).floor(),
      ));
      continue;
    }

    final bullet = _bulletPattern.firstMatch(line);
    // `*emphasis*` or `**bold**` at line start would otherwise read as a bullet.
    if (bullet != null && !line.trimLeft().startsWith('**')) {
      flush();
      blocks.add(_Block(
        _Kind.bullet,
        bullet.group(2)!.trim(),
        indent: (bullet.group(1)!.length / 2).floor(),
      ));
      continue;
    }

    paragraph.add(line.trim());
  }
  flush();
  return blocks;
}

List<String> _cells(String row) {
  var line = row.trim();
  if (line.startsWith('|')) line = line.substring(1);
  if (line.endsWith('|')) line = line.substring(0, line.length - 1);
  return line.split('|').map((c) => c.trim()).toList();
}
