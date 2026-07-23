import 'package:aqademiq/shared/widgets/markdown_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flattens the rendered text of every [RichText] in the tree, so assertions can
/// check what a reader actually sees rather than the widget structure.
String _rendered(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((w) => w.text.toPlainText())
    .join('\n');

/// True when any span in the tree carries a style satisfying `predicate` on `text`.
bool _hasStyled(
  WidgetTester tester,
  String text,
  bool Function(TextStyle style) predicate,
) {
  var found = false;
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan &&
          span.text == text &&
          span.style != null &&
          predicate(span.style!)) {
        found = true;
      }
      return true;
    });
  }
  return found;
}

Future<void> _pump(WidgetTester tester, String markdown) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownText(
            markdown,
            style: const TextStyle(fontSize: 12, color: Color(0xFF000000)),
          ),
        ),
      ),
    );

void main() {
  group('MarkdownText', () {
    testWidgets('renders bold without leaking asterisks', (tester) async {
      await _pump(tester, 'A **bold** word.');
      expect(_rendered(tester), contains('A bold word.'));
      expect(_rendered(tester), isNot(contains('**')));
      expect(
        _hasStyled(tester, 'bold', (s) => s.fontWeight == FontWeight.w800),
        isTrue,
      );
    });

    testWidgets('renders italic and inline code', (tester) async {
      await _pump(tester, 'An *emphasis* and `some_code`.');
      expect(_rendered(tester), contains('An emphasis and some_code.'));
      expect(
        _hasStyled(tester, 'emphasis', (s) => s.fontStyle == FontStyle.italic),
        isTrue,
      );
    });

    testWidgets('leaves underscores in identifiers alone', (tester) async {
      // `_italics_` are deliberately unsupported: Ada quotes field names like
      // these, and treating them as emphasis silently ate the underscores.
      await _pump(tester, 'Send consent_given and duration_seconds.');
      expect(
        _rendered(tester),
        contains('Send consent_given and duration_seconds.'),
      );
    });

    testWidgets('numbers an ordered list and keeps inline bold', (tester) async {
      await _pump(
        tester,
        '1. **Supervised Learning:** learns from labelled data.\n'
        '2. **Unsupervised Learning:** finds hidden structure.',
      );
      final text = _rendered(tester);
      expect(text, contains('1.'));
      expect(text, contains('2.'));
      expect(text, contains('Supervised Learning:'));
      expect(text, isNot(contains('**')));
      expect(
        _hasStyled(
          tester,
          'Supervised Learning:',
          (s) => s.fontWeight == FontWeight.w800,
        ),
        isTrue,
      );
    });

    testWidgets('renders bullets with a marker', (tester) async {
      await _pump(tester, '- first\n- second');
      final text = _rendered(tester);
      expect(text, contains('•'));
      expect(text, contains('first'));
      expect(text, contains('second'));
      expect(text, isNot(contains('- first')));
    });

    testWidgets('renders headings larger than body text', (tester) async {
      await _pump(tester, '## Heading\n\nBody.');
      expect(_rendered(tester), contains('Heading'));
      expect(_rendered(tester), isNot(contains('##')));
      expect(
        _hasStyled(tester, 'Heading', (s) => (s.fontSize ?? 0) > 12),
        isTrue,
      );
    });

    testWidgets('folds hard-wrapped lines into one paragraph', (tester) async {
      await _pump(tester, 'This sentence was\nwrapped by the model.');
      expect(_rendered(tester), contains('This sentence was wrapped by the model.'));
    });

    testWidgets('a bold line start is not mistaken for a bullet', (tester) async {
      await _pump(tester, '**Machine Learning (ML)** is a branch of AI.');
      expect(_rendered(tester), contains('Machine Learning (ML) is a branch of AI.'));
      expect(_rendered(tester), isNot(contains('•')));
    });

    testWidgets('unmatched markers degrade to literal text', (tester) async {
      await _pump(tester, 'A stray ** marker and 2 * 3 = 6.');
      expect(_rendered(tester), contains('A stray ** marker and 2 * 3 = 6.'));
    });

    testWidgets('plain prose is unchanged', (tester) async {
      await _pump(tester, "Nice progress! You're on a 5-day streak.");
      expect(_rendered(tester), contains("Nice progress! You're on a 5-day streak."));
    });
  });

  group('MarkdownText — extended syntax', () {
    testWidgets('renders a horizontal rule instead of literal dashes', (tester) async {
      await _pump(tester, 'Above\n\n---\n\nBelow');
      final text = _rendered(tester);
      expect(text, contains('Above'));
      expect(text, contains('Below'));
      expect(text, isNot(contains('---')));
    });

    testWidgets('strikethrough', (tester) async {
      await _pump(tester, 'This is ~~wrong~~ right.');
      expect(_rendered(tester), contains('This is wrong right.'));
      expect(_rendered(tester), isNot(contains('~~')));
      expect(
        _hasStyled(tester, 'wrong', (s) => s.decoration == TextDecoration.lineThrough),
        isTrue,
      );
    });

    testWidgets('superscript and subscript drop their markers', (tester) async {
      await _pump(tester, 'E = mc^2^ and H~2~O.');
      final text = _rendered(tester);
      expect(text, contains('2'));
      expect(text, isNot(contains('^2^')));
      expect(text, isNot(contains('~2~')));
    });

    testWidgets('blockquote', (tester) async {
      await _pump(tester, '> Start small.');
      expect(_rendered(tester), contains('Start small.'));
      expect(_rendered(tester), isNot(contains('>')));
    });

    testWidgets('fenced code block keeps its body verbatim', (tester) async {
      await _pump(tester, 'Try:\n```dart\nfinal x = 1;\n```');
      expect(_rendered(tester), contains('final x = 1;'));
      expect(_rendered(tester), isNot(contains('```')));
    });

    testWidgets('link renders its text, not the URL syntax', (tester) async {
      await _pump(tester, 'See [the docs](https://example.com) for more.');
      final text = _rendered(tester);
      expect(text, contains('See the docs for more.'));
      expect(text, isNot(contains('](')));
      expect(text, isNot(contains('https://example.com')));
    });

    testWidgets(r'inline maths unwraps $…$ and maps LaTeX', (tester) async {
      await _pump(tester, r'A query ($Q$) times $\alpha$ over $\frac{a}{b}$.');
      final text = _rendered(tester);
      expect(text, isNot(contains(r'$')));
      expect(text, contains('Q'));
      expect(text, contains('α'));
      expect(text, contains('a⁄b'));
      expect(text, isNot(contains(r'\alpha')));
      expect(text, isNot(contains(r'\frac')));
    });

    testWidgets('maths superscripts become Unicode', (tester) async {
      await _pump(tester, r'Complexity is $O(n^2)$ and $x^{10}$.');
      final text = _rendered(tester);
      expect(text, contains('n²'));
      expect(text, contains('x¹⁰'));
    });

    testWidgets('unmappable superscripts keep their caret form', (tester) async {
      // Half-converted output would be worse than leaving the notation alone.
      await _pump(tester, r'Value $x^{qz}$ here.');
      expect(_rendered(tester), contains('x^qz'));
    });

    testWidgets('table renders cells without pipes or the separator row',
        (tester) async {
      await _pump(
        tester,
        '| Type | Use |\n|------|-----|\n| Supervised | labelled |',
      );
      final text = _rendered(tester);
      expect(text, contains('Type'));
      expect(text, contains('Supervised'));
      expect(text, contains('labelled'));
      expect(text, isNot(contains('|')));
      expect(text, isNot(contains('---')));
    });

    testWidgets('a dashed rule is not parsed as bullets', (tester) async {
      await _pump(tester, '- - -');
      expect(_rendered(tester), isNot(contains('•')));
    });

    testWidgets('display maths on its own line unwraps', (tester) async {
      await _pump(tester, r'$$E = mc^2$$');
      final text = _rendered(tester);
      expect(text, isNot(contains(r'$')));
      expect(text, contains('mc²'));
    });
  });
}
