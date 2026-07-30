import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

// KFQC Mushaf page aspect ratio: viewBox="0 0 345 550"
const _kPageAspectRatio = 550.0 / 345.0;

// Tracks which page view-types have been registered with HtmlElementView.
// We use one HtmlElementView per page slot (reused by swapping SVG content).
final Map<int, _SvgPageState> _pageStates = {};

class _SvgPageState {
  html.Element? container;
  void Function(int surah, int ayah)? onVerseTapped;
  VoidCallback? onTap;
  int? selectedVerseId;
  int? playingVerseId;
  double panelHeight = 0.0; // Height of the bottom panel overlay (px)
  String? currentEdition;
}

String _getSvgUrl(int pageNum, String edition) {
  final paddedPage = pageNum.toString().padLeft(3, '0');
  switch (edition) {
    case 'warsh_kfqc':
      return 'https://cdn.jsdelivr.net/gh/quranpedia/quran-svg@main/mushafs/warsh/kfqc/svg/$paddedPage.svg';
    case 'douri_kfqc':
      return 'https://cdn.jsdelivr.net/gh/quranpedia/quran-svg@main/mushafs/douri/kfqc/svg/$paddedPage.svg';
    case 'batoulapps':
      return 'https://cdn.jsdelivr.net/gh/batoulapps/quran-svg@master/svg/$paddedPage.svg';
    case 'tajweed_css':
    case 'hafs_kfqc':
    default:
      return 'https://cdn.jsdelivr.net/gh/quranpedia/quran-svg@main/mushafs/hafs/kfqc/svg/$paddedPage.svg';
  }
}

String _buildPageCss(int? selectedId, int? playingId, {String mushafEdition = 'hafs_kfqc'}) {
  final isTajweed = mushafEdition == 'tajweed_css';
  return '''
    .ayahPolygon {
      fill: #000 !important;
      fill-opacity: 0 !important;
      cursor: pointer !important;
      pointer-events: auto !important;
      transition: fill 0.2s, fill-opacity 0.2s;
    }
    svg *:not(.ayahPolygon) {
      pointer-events: none !important;
    }
    ${isTajweed ? '''
    /* Dynamic Tajweed Rule Color Overrides */
    svg [class*="madd"], svg [data-tajweed="madd"] { fill: #E74C3C !important; }
    svg [class*="ghunnah"], svg [data-tajweed="ghunnah"] { fill: #27AE60 !important; }
    svg [class*="qalqalah"], svg [data-tajweed="qalqalah"] { fill: #2980B9 !important; }
    svg [class*="ikhfa"], svg [data-tajweed="ikhfa"] { fill: #8E44AD !important; }
    svg [class*="idgham"], svg [data-tajweed="idgham"] { fill: #E67E22 !important; }
    svg [class*="slnt"], svg [class*="silent"], svg [data-tajweed="silent"] { fill: #95A5A6 !important; }
    ''' : '''
    svg path:not(.ayahPolygon) {
      fill: #000000 !important;
    }
    '''}
    ${selectedId != null ? '''
    #verse-$selectedId, #verse-$selectedId .ayahPolygon {
      fill: #E9C176 !important;
      fill-opacity: 0.25 !important;
    }
    ''' : ''}
    ${playingId != null ? '''
    #verse-$playingId, #verse-$playingId .ayahPolygon {
      fill: #95D1D1 !important;
      fill-opacity: 0.3 !important;
    }
    ''' : ''}
  ''';
}

Widget buildQuranPageImage(
  BuildContext context,
  int pageNum, {
  VoidCallback? onTap,
  void Function(double relX, double relY)? onTapWithPosition,
  void Function(int surah, int ayah)? onVerseTapped,
  int? selectedVerseId,
  int? playingVerseId,
  bool fullWidth = false,
  double? viewportWidth,
  double panelHeight = 0.0,
  String mushafEdition = 'hafs_kfqc',
}) {
  if (mushafEdition == 'tajweed_qcf4') {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = fullWidth
        ? (viewportWidth ?? MediaQuery.of(context).size.width)
        : MediaQuery.of(context).size.width;
    final h = w * _kPageAspectRatio;
    return SizedBox(
      width: w,
      height: h,
      child: TajweedPageWidget(
        pageNumber: pageNum,
        isDark: isDark,
      ),
    );
  }

  final viewType = 'quran-svg-page-$pageNum-$fullWidth-$mushafEdition';

  // Always refresh callbacks and IDs
  final state = _pageStates.putIfAbsent(pageNum, () => _SvgPageState());
  state.onTap = onTap;
  state.onVerseTapped = onVerseTapped;
  state.selectedVerseId = selectedVerseId;
  state.playingVerseId = playingVerseId;
  state.panelHeight = panelHeight;

  // Dynamically update highlights or reload if edition changed
  if (state.container != null) {
    if (state.currentEdition != mushafEdition) {
      state.currentEdition = mushafEdition;
      _loadSvgIntoContainer(state.container as html.DivElement, pageNum, state, fullWidth, mushafEdition);
    } else {
      final style = state.container!.querySelector('style');
      if (style != null) {
        style.text = _buildPageCss(selectedVerseId, playingVerseId, mushafEdition: mushafEdition);
      }
    }
    
    // Auto-scroll the active verse into the visible area above the panel
    final activeId = playingVerseId ?? selectedVerseId;
    if (activeId != null) {
      html.window.animationFrame.then((_) {
        _scrollVerseIntoView(state, activeId);
      });
    }
  }

  if (!_pageStates.containsKey(pageNum) || state.container == null) {
    try {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.display = 'flex'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center'
          ..style.overflowY = 'hidden'
          ..style.overflowX = 'hidden'
          ..style.backgroundColor = 'transparent'
          ..style.cursor = 'pointer';

        state.container = container;
        _loadSvgIntoContainer(container, pageNum, state, fullWidth, mushafEdition);
        return container;
      });
    } catch (e) {
      // Ignore if already registered
      print('View factory $viewType already registered or failed: $e');
    }
  }

  if (fullWidth) {
    final w = viewportWidth ?? MediaQuery.of(context).size.width;
    final h = w * _kPageAspectRatio;
    return SizedBox(
      width:  w,
      height: h,
      child:  HtmlElementView(viewType: viewType),
    );
  }

  // Without explicit constraints, HtmlElementView collapses to 0x0 in Flutter Web
  // because it has no intrinsic size. Wrapping it in AspectRatio ensures it fills
  // the available space while maintaining the correct shape.
  return AspectRatio(
    aspectRatio: 345.0 / 550.0,
    child: HtmlElementView(viewType: viewType),
  );
}

void _loadSvgIntoContainer(
  html.DivElement container,
  int pageNum,
  _SvgPageState state,
  bool fullWidth,
  String mushafEdition,
) {
  state.currentEdition = mushafEdition;
  // Show loading indicator while fetching
  container.children.clear();
  final loader = html.DivElement()
    ..style.color = '#B8860B'
    ..style.fontFamily = 'sans-serif'
    ..style.fontSize = '14px'
    ..text = 'Loading page $pageNum…';
  container.append(loader);

  final url = _getSvgUrl(pageNum, mushafEdition);

  html.HttpRequest.getString(url).then((svgText) {
    container.children.clear();

    // Wrap SVG in a div that sizes itself to fill the container while
    // The SizedBox in Flutter already sizes the HtmlElementView to the correct
    // aspect ratio, so the wrapper always fills 100% of the available space.
    final svgWrapper = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.backgroundColor = '#FBF9F1';

    svgWrapper.setInnerHtml(
      svgText,
      validator: html.NodeValidatorBuilder.common()
        ..allowSvg()
        ..allowElement('svg', attributes: [
          'xmlns',
          'xmlns:ayah',
          'viewBox',
          'version',
          'xml:space',
          'width',
          'height',
          'style',
        ])
        ..allowElement('g', attributes: [
          'id',
          'class',
          'transform',
          'ayah:x',
          'ayah:y',
          'surah',
          'ayah',
          'number',
          'fill',
          'fill-opacity',
          'cursor',
        ])
        ..allowElement('path', attributes: [
          'class',
          'id',
          'd',
          'fill',
          'fill-rule',
          'fill-opacity',
          'cursor',
          'surah',
          'ayah',
          'number',
        ])
        ..allowElement('use', attributes: ['href', 'x', 'y', 'xlink:href'])
        ..allowElement('defs', attributes: [])
        ..allowElement('rect', attributes: [
          'x',
          'y',
          'width',
          'height',
          'fill',
          'fill-opacity',
          'cursor',
        ]),
    );

    // The SVG element — always use max-width/max-height to scale to fit its container
    final svg = svgWrapper.querySelector('svg');
    if (svg != null) {
      svg.style
        ..maxWidth = '100%'
        ..maxHeight = '100%'
        ..width = '100%'
        ..height = '100%';
      svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
    }

    final style = html.StyleElement()
      ..text = _buildPageCss(state.selectedVerseId, state.playingVerseId);
    container.append(style);
    container.append(svgWrapper);

    // Auto-scroll the active verse into the visible area above the panel after load
    final activeId = state.playingVerseId ?? state.selectedVerseId;
    if (activeId != null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _scrollVerseIntoView(state, activeId);
      });
    }

    // Attach click handler on the wrapper so it catches bubbled events from all SVG children.
    svgWrapper.onClick.listen((event) {
      state.onTap?.call();

      // Walk up from the target to find an element with surah/ayah attributes.
      // The ayahPolygon paths have surah="" and ayah="" attributes directly.
      html.Element? target = event.target as html.Element?;
      int? surah, ayah;

      while (target != null && target != svgWrapper) {
        final s = target.getAttribute('surah');
        final a = target.getAttribute('ayah');
        if (s != null && a != null && s.isNotEmpty && a.isNotEmpty) {
          surah = int.tryParse(s);
          ayah = int.tryParse(a);
          break;
        }
        target = target.parent;
      }

      if (surah != null && ayah != null) {
        state.onVerseTapped?.call(surah, ayah);
      }
    });
  }).catchError((e) {
    container.children.clear();
    final fallback = html.ImageElement()
      ..src =
          'https://quran.ksu.edu.sa/png_big/$pageNum.png'
      ..style.maxWidth = '100%'
      ..style.maxHeight = '100%'
      ..style.objectFit = 'contain';
    container.append(fallback);
  });
}

/// Scrolls the browser window so the verse element is visible above the
/// bottom panel overlay. Uses [getBoundingClientRect] to get the verse's
/// screen position, then scrolls if needed so it is centered in the
/// visible area above the panel.
void _scrollVerseIntoView(_SvgPageState state, int verseId) {
  final element = state.container?.querySelector('#verse-$verseId');
  if (element == null) return;

  final rect = element.getBoundingClientRect();
  final viewportHeight = html.window.innerHeight?.toDouble() ?? 0.0;
  final panelH = state.panelHeight;
  // Visible height of the viewport above the panel
  final visibleH = viewportHeight - panelH;

  // Centre of the verse element in viewport coordinates
  final verseCenter = (rect.top + rect.bottom) / 2;
  // Desired centre: middle of the visible area above the panel
  final targetCenter = visibleH / 2;
  final scrollDelta = verseCenter - targetCenter;

  if (scrollDelta.abs() > 8) {
    html.window.scrollBy({
      'top': scrollDelta,
      'behavior': 'smooth',
    });
  }
}
