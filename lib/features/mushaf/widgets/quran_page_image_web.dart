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
}

String _buildPageCss(int? selectedId, int? playingId) {
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
    svg path:not(.ayahPolygon) {
      fill: #000000 !important;
    }
    ${selectedId != null ? '''
    #verse-$selectedId {
      fill: #E9C176 !important;
      fill-opacity: 0.25 !important;
    }
    ''' : ''}
    ${playingId != null ? '''
    #verse-$playingId {
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
}) {
  final viewType = 'quran-svg-page-$pageNum-$fullWidth';

  // Always refresh callbacks and IDs
  final state = _pageStates.putIfAbsent(pageNum, () => _SvgPageState());
  state.onTap = onTap;
  state.onVerseTapped = onVerseTapped;
  state.selectedVerseId = selectedVerseId;
  state.playingVerseId = playingVerseId;

  // Dynamically update highlights if container style is already rendered
  if (state.container != null) {
    final style = state.container!.querySelector('style');
    if (style != null) {
      style.text = _buildPageCss(selectedVerseId, playingVerseId);
    }
    
    // Auto-scroll the active verse (playing or selected) into view (centered)
    final activeId = playingVerseId ?? selectedVerseId;
    if (activeId != null) {
      html.window.animationFrame.then((_) {
        final element = state.container!.querySelector('#verse-$activeId');
        if (element != null) {
          element.scrollIntoView(html.ScrollAlignment.CENTER);
        }
      });
    }
  }

  if (!_pageStates.containsKey(pageNum) || state.container == null) {
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
      _loadSvgIntoContainer(container, pageNum, state, fullWidth);
      return container;
    });
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

  return HtmlElementView(viewType: viewType);
}

void _loadSvgIntoContainer(
  html.DivElement container,
  int pageNum,
  _SvgPageState state,
  bool fullWidth,
) {
  // Show loading indicator while fetching
  container.children.clear();
  final loader = html.DivElement()
    ..style.color = '#B8860B'
    ..style.fontFamily = 'sans-serif'
    ..style.fontSize = '14px'
    ..text = 'Loading page $pageNum…';
  container.append(loader);

  final paddedPage = pageNum.toString().padLeft(3, '0');
  final url =
      'https://cdn.jsdelivr.net/gh/quranpedia/quran-svg@main/mushafs/hafs/kfqc/svg/$paddedPage.svg';

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
      ..style.backgroundColor = 'transparent';

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
        ..width = 'auto'
        ..height = 'auto';
      svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
    }

    final style = html.StyleElement()
      ..text = _buildPageCss(state.selectedVerseId, state.playingVerseId);
    container.append(style);
    container.append(svgWrapper);

    // Auto-scroll the active verse (playing or selected) into view (centered) after load
    final activeId = state.playingVerseId ?? state.selectedVerseId;
    if (activeId != null) {
      Future.delayed(const Duration(milliseconds: 150), () {
        final element = container.querySelector('#verse-$activeId');
        if (element != null) {
          element.scrollIntoView(html.ScrollAlignment.CENTER);
        }
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
