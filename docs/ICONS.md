# Icons

The v11 design replaces Material icons with the **Aqademiq icon pack**: a 24 × 24
grid, 1.75 stroke, round caps and joins, outline by default and fill only when
selected or active.

## Source of truth

| What | Where |
| --- | --- |
| Geometry, roles, fill variants (107 glyphs) | `prototypes/v11/aq-icons.js` (`window.AQ.ICONS`) |
| Tier-2 task icons (16, two layers) | `prototypes/v11/aq-task-icons.js` (`window.AQT.TASKS`) |
| Material → aq table, ice set, the derived `aqx_ring` | `prototypes/v11/app.jsx` (`AQ_MAP`, `AQ_ICE_GLYPHS`) |

The Dart is generated from those files. **Never edit `*.g.dart` by hand.**

```sh
node tool/generate_aq_icons.js                    # regenerate + verify
node tool/generate_aq_icons.js --sheet=out.html   # also write a contact sheet
node tool/generate_aq_icons.js --check            # verify only
```

Node built-ins only, no install. The generator loads the browser files in a `vm`
sandbox, normalises every path to absolute `M/L/C/Z` (arcs become cubics of at
most 90°), and fails if any normalised curve strays more than 0.01 grid units
from the original. The current maximum is 0.0027. The contact sheet puts the
original SVG, the normalised data and an overlay of the two side by side, so
you can check them by eye. If the JS gains a layer key or role the generator
doesn't know, it stops with an error instead of dropping it.

| File | Contents |
| --- | --- |
| `lib/shared/icons/aq_glyph.dart` | `AqGlyph`, `AqLayer`, `AqRole`, `AqTaskGlyph`, path decoding |
| `lib/shared/icons/aq_icons.g.dart` | `AqIcons` (glyphs, `byName`, `materialToAq`, `materialGaps`, `ice`), `AqTaskIcons` |
| `lib/shared/icons/aq_glyphs.g.dart` | path data (`part of` the above) |
| `lib/shared/icons/aq_icon.dart` | `AqIcon`, `AqTaskIcon`, `AqResolvedIcon`, `AqGlyphPainter`; exports all of the above |
| `lib/shared/icons/aq_material_icons.dart` | hand-curated Material fallbacks |

## Using it

```dart
import '../../shared/icons/aq_icon.dart';

AqIcon(AqIcons.planner)                        // outline, IconTheme colour, 24 px
AqIcon(AqIcons.planner, fill: true, size: 26)  // selected tab
AqIcon(AqIcons.check, strokeWidth: 2.4)        // the prototype's sw= override
AqIcon(AqIcons.cubeSession, progress: left)    // timer layer drawn to `left`
AqIcon.named('schedule')                       // Material name → AqIcons.time
AqIcon.named('check_circle:fill')              // aq name, fill variant
AqIcon.named('mi:graphic_eq')                  // force the Material glyph
AqTaskIcon(AqTaskIcons.exam)                   // tag ink (light) / hue (dark)
AqTaskIcon(AqTaskIcons.byLabel['Exam']!)       // look up by study-tag label
```

`AqIcon.named` resolves names the way the prototype's `Ic` does. A Material name
goes through `AqIcons.materialToAq`. A `:fill` suffix picks the fill variant,
`task_<name>` picks a task icon, and `mi:<name>` always draws Material. Gaps in
the pack (`AqIcons.materialGaps`) and unmapped names fall back to
`AqMaterialIcons.byName`, which uses the Outlined style. An unknown name draws an
empty box and logs `[aq] no glyph …` in debug builds.

Roles (`AqRole`) are painted like the SVG:

- **body**: filled in the fill variant.
- **knock**: erased from the fill variant with `saveLayer` + `BlendMode.dstOut`, so
  the background shows through.
- **cut**: the slash clears a gap of `strokeWidth + 3` through every other layer,
  then draws itself.
- **paint** layers are always filled.
- **timer** layers draw only the `progress` fraction of their length, starting at
  the top centre and running clockwise.

## The ice-colour rule

`freeze`, `thaw`, `never_open` and `shield` (`AqIcons.ice`) are the app-freeze
glyphs, and they never follow an accent swap. If one of them is drawn in the theme
accent (`context.colors.accent`), from an explicit `color:` or from the
`IconTheme`, it is drawn in `AqIcon.iceColor` (`#6B5CF0`, `--aq-ice`) instead. Any
other colour is used as given. `AqIcon.iceOnDarkColor` (`#CBBCFD`) is the hero ice
colour on OLED black, but nothing applies it automatically: use it explicitly
where the design does.
