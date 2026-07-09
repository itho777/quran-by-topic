import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme.dart';

// CDN base — same source used by the web version
const _kCdnBase =
    'https://cdn.jsdelivr.net/gh/quranpedia/quran-svg@main/mushafs/hafs/kfqc/svg';

// In-memory SVG text cache (survives widget rebuilds, cleared on hot-restart)
final Map<int, String> _memCache = {};

// ─────────────────────────────────────────────────────────────────────────────
// CSS / JS — identical to quran_page_image_web.dart
// ─────────────────────────────────────────────────────────────────────────────
const _kSharedScript = r'''
var _styleEl = null;

function _buildCss(sel, play) {
  return [
    '.ayahPolygon{fill:#000!important;fill-opacity:0!important;cursor:pointer!important;pointer-events:auto!important;transition:fill .2s,fill-opacity .2s}',
    'svg *:not(.ayahPolygon){pointer-events:none!important}',
    'svg path:not(.ayahPolygon){fill:#000!important}',
    sel != null ? '#verse-'+sel+'{fill:#E9C176!important;fill-opacity:0.25!important}' : '',
    play != null ? '#verse-'+play+'{fill:#95D1D1!important;fill-opacity:0.30!important}' : '',
  ].join('');
}

function _initSvg() {
  var svgEl = document.querySelector('#wrap svg');
  if (!svgEl) return;
  svgEl.style.width  = '100%';
  svgEl.style.height = 'auto';
  svgEl.setAttribute('preserveAspectRatio', 'xMidYMin meet');

  _styleEl = document.createElement('style');
  _styleEl.textContent = _buildCss(null, null);
  svgEl.insertBefore(_styleEl, svgEl.firstChild);

  document.getElementById('wrap').addEventListener('click', function(e) {
    var t = e.target;
    while (t && t.id !== 'wrap') {
      var s = t.getAttribute('surah');
      var a = t.getAttribute('ayah');
      if (s && a && s !== '' && a !== '') {
        window.location.href = 'verse://' + s + '/' + a;
        return;
      }
      t = t.parentElement;
    }
    window.location.href = 'tap://page';
  });
}

// Called by Flutter via runJavaScript to live-update highlights and scroll them into view
window.updateHighlight = function(sel, play) {
  if (_styleEl) _styleEl.textContent = _buildCss(sel, play);
  var activeId = play !== null ? play : sel;
  if (activeId !== null) {
    setTimeout(function() {
      var el = document.getElementById('verse-' + activeId);
      if (el) {
        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }, 80);
  }
};
''';

// ─────────────────────────────────────────────────────────────────────────────
// HTML builder — SVG always embedded inline (no iframe src, no fetch in JS)
// ─────────────────────────────────────────────────────────────────────────────
String _buildHtml(String svgText, bool fullWidth) {
  final overflow  = fullWidth ? 'auto' : 'hidden';
  final wrapStyle = fullWidth
      ? 'width:100%;'
      : 'width:100vw;height:100vh;display:flex;align-items:center;justify-content:center;';
  final svgStyle = fullWidth
      ? 'width:100%;height:auto;display:block;'
      : 'max-width:100%;max-height:100%;width:auto;height:auto;display:block;';

  return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:100%;height:100%;overflow:$overflow;background:transparent;touch-action:pan-y}
#wrap{$wrapStyle}
svg{$svgStyle}
</style>
</head>
<body>
<div id="wrap">$svgText</div>
<script>$_kSharedScript</script>
<script>_initSvg();</script>
</body>
</html>
''';
}

// ─────────────────────────────────────────────────────────────────────────────
// SVG loader — memory cache → disk cache → CDN download
// ─────────────────────────────────────────────────────────────────────────────

Future<String?> _localCacheDir() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final mushaf = Directory('${dir.path}/mushaf');
    if (!await mushaf.exists()) await mushaf.create(recursive: true);
    return mushaf.path;
  } catch (_) {
    return null;
  }
}

/// Loads the SVG for [pageNum]:
///   1. In-memory cache  (instant)
///   2. App-documents disk cache (fast, survives app restarts)
///   3. CDN download + save to disk
///
/// Returns null if offline and not cached.
Future<String?> _loadSvg(int pageNum) async {
  // 1. Memory
  if (_memCache.containsKey(pageNum)) return _memCache[pageNum];

  final padded = pageNum.toString().padLeft(3, '0');

  // 2. Disk
  final cacheDir = await _localCacheDir();
  if (cacheDir != null) {
    final file = File('$cacheDir/$padded.svg');
    if (await file.exists()) {
      final text = await file.readAsString();
      _memCache[pageNum] = text;
      return text;
    }
  }

  // 3. CDN
  try {
    final url = '$_kCdnBase/$padded.svg';
    final response = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final text = response.body;
      _memCache[pageNum] = text;
      // Save to disk in background
      if (cacheDir != null) {
        File('$cacheDir/$padded.svg').writeAsString(text).ignore();
      }
      return text;
    }
  } catch (_) {}

  return null; // offline, not cached
}

// ─────────────────────────────────────────────────────────────────────────────
// Public API — same signature as the web version
// ─────────────────────────────────────────────────────────────────────────────

/// Builds the native (Android / iOS) Mushaf page widget.
///
/// Pages are served via WebView (same HTML/CSS/JS as the web version) so that
/// CSS class-selectors and verse highlighting work identically.
/// SVGs are cached on disk after first load, so subsequent views are instant.
Widget buildQuranPageImage(
  BuildContext context,
  int pageNum, {
  VoidCallback? onTap,
  void Function(double relX, double relY)? onTapWithPosition,
  void Function(int surah, int ayah)? onVerseTapped,
  int? selectedVerseId,
  int? playingVerseId,
  bool fullWidth = false,
}) {
  return _QuranPageWebView(
    pageNum:         pageNum,
    onTap:           onTap,
    onVerseTapped:   onVerseTapped,
    selectedVerseId: selectedVerseId,
    playingVerseId:  playingVerseId,
    fullWidth:       fullWidth,
  );
}

class _QuranPageWebView extends StatefulWidget {
  final int pageNum;
  final VoidCallback? onTap;
  final void Function(int surah, int ayah)? onVerseTapped;
  final int? selectedVerseId;
  final int? playingVerseId;
  final bool fullWidth;

  const _QuranPageWebView({
    required this.pageNum,
    this.onTap,
    this.onVerseTapped,
    this.selectedVerseId,
    this.playingVerseId,
    this.fullWidth = false,
  });

  @override
  State<_QuranPageWebView> createState() => _QuranPageWebViewState();
}

class _QuranPageWebViewState extends State<_QuranPageWebView> {
  late WebViewController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loaded = true);
          _pushHighlight();
        },
        onNavigationRequest: (req) {
          final uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.navigate;

          if (uri.scheme == 'verse') {
            widget.onTap?.call();
            final surah = int.tryParse(uri.host) ?? 0;
            final ayah  = int.tryParse(uri.pathSegments.firstOrNull ?? '') ?? 0;
            if (surah > 0 && ayah > 0) widget.onVerseTapped?.call(surah, ayah);
            return NavigationDecision.prevent;
          }
          if (uri.scheme == 'tap') {
            widget.onTap?.call();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));
    _loadPage();
  }

  Future<void> _loadPage() async {
    if (mounted) setState(() => _loaded = false);

    final svgText = await _loadSvg(widget.pageNum);
    if (!mounted) return;

    if (svgText != null) {
      _controller.loadHtmlString(_buildHtml(svgText, widget.fullWidth));
    } else {
      // Offline fallback
      _controller.loadHtmlString('''
<!DOCTYPE html>
<html>
<body style="display:flex;align-items:center;justify-content:center;
             height:100vh;margin:0;font-family:sans-serif;color:#888;
             text-align:center;padding:24px;box-sizing:border-box">
  <div>
    <div style="font-size:36px;margin-bottom:12px">&#x1F4F4;</div>
    <p>Page ${widget.pageNum} not available offline.</p>
    <p style="font-size:12px;margin-top:8px">Connect to the internet to load Mushaf pages.</p>
  </div>
</body>
</html>''');
    }
  }

  void _pushHighlight() {
    final selJs  = widget.selectedVerseId  != null ? '${widget.selectedVerseId}'  : 'null';
    final playJs = widget.playingVerseId   != null ? '${widget.playingVerseId}'   : 'null';
    _controller.runJavaScript(
        'if(window.updateHighlight) window.updateHighlight($selJs, $playJs);');
  }

  @override
  void didUpdateWidget(_QuranPageWebView old) {
    super.didUpdateWidget(old);

    if (old.pageNum != widget.pageNum || old.fullWidth != widget.fullWidth) {
      _loadPage();
      return;
    }
    if (old.selectedVerseId != widget.selectedVerseId ||
        old.playingVerseId  != widget.playingVerseId) {
      _pushHighlight();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_loaded)
          Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      ],
    );
  }
}
