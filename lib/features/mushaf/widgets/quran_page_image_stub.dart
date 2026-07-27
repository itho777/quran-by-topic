import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:quran_library/quran_library.dart';
import '../../../core/theme.dart';

// CDN base — same source used by the web version
const _kCdnBase =
    'https://cdn.jsdelivr.net/gh/quranpedia/quran-svg@main/mushafs/hafs/kfqc/svg';

// In-memory SVG text cache (survives widget rebuilds, cleared on hot-restart)
final Map<String, String> _memCache = {};

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

// ─────────────────────────────────────────────────────────────────────────────
// CSS / JS — identical to quran_page_image_web.dart
// ─────────────────────────────────────────────────────────────────────────────
String _buildPageCssScript(String edition) {
  final isTajweed = edition == 'tajweed_css';
  final tajweedCss = isTajweed ? '''
    svg [class*="madd"], svg [data-tajweed="madd"] { fill: #E74C3C !important; }
    svg [class*="ghunnah"], svg [data-tajweed="ghunnah"] { fill: #27AE60 !important; }
    svg [class*="qalqalah"], svg [data-tajweed="qalqalah"] { fill: #2980B9 !important; }
    svg [class*="ikhfa"], svg [data-tajweed="ikhfa"] { fill: #8E44AD !important; }
    svg [class*="idgham"], svg [data-tajweed="idgham"] { fill: #E67E22 !important; }
    svg [class*="slnt"], svg [class*="silent"], svg [data-tajweed="silent"] { fill: #95A5A6 !important; }
  ''' : 'svg path:not(.ayahPolygon){fill:#000!important}';

  return '''
var _styleEl = null;

function _buildCss(sel, play) {
  return [
    '.ayahPolygon{fill:#000!important;fill-opacity:0!important;cursor:pointer!important;pointer-events:auto!important;transition:fill .2s,fill-opacity .2s}',
    'svg *:not(.ayahPolygon){pointer-events:none!important}',
    '$tajweedCss',
    sel != null ? '#verse-'+sel+',#verse-'+sel+' .ayahPolygon{fill:#E9C176!important;fill-opacity:0.25!important}' : '',
    play != null ? '#verse-'+play+',#verse-'+play+' .ayahPolygon{fill:#95D1D1!important;fill-opacity:0.30!important}' : '',
  ].join('');
}

function _initSvg() {
  var svgEl = document.querySelector('#wrap svg');
  if (!svgEl) return;
  svgEl.style.maxWidth  = '100%';
  svgEl.style.maxHeight = '100%';
  svgEl.style.width     = 'auto';
  svgEl.style.height    = 'auto';
  svgEl.setAttribute('preserveAspectRatio', 'xMidYMid meet');

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
}

const _kPageAspectRatio = 550.0 / 345.0;

String _buildHtml(String svgText, bool fullWidth, String edition) {
  const overflow = 'hidden';
  const wrapStyle =
      'width:100%;height:100%;display:flex;align-items:center;justify-content:center;';
  const svgStyle =
      'max-width:100%;max-height:100%;width:auto;height:auto;display:block;';

  return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:100%;height:100%;overflow:$overflow;background:transparent;touch-action:none}
#wrap{$wrapStyle}
svg{$svgStyle}
</style>
</head>
<body>
<div id="wrap">$svgText</div>
<script>${_buildPageCssScript(edition)}</script>
<script>_initSvg();</script>
</body>
</html>
''';
}

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

Future<String?> _loadSvg(int pageNum, String edition) async {
  final cacheKey = '$edition-$pageNum';
  if (_memCache.containsKey(cacheKey)) return _memCache[cacheKey];

  final padded = pageNum.toString().padLeft(3, '0');
  final fileName = '$edition-$padded.svg';

  final cacheDir = await _localCacheDir();
  if (cacheDir != null) {
    final file = File('$cacheDir/$fileName');
    if (await file.exists()) {
      final text = await file.readAsString();
      _memCache[cacheKey] = text;
      return text;
    }
  }

  try {
    final url = _getSvgUrl(pageNum, edition);
    final response = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final text = response.body;
      _memCache[cacheKey] = text;
      if (cacheDir != null) {
        File('$cacheDir/$fileName').writeAsString(text).ignore();
      }
      return text;
    }
  } catch (_) {}

  return null;
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
  // On Android/iOS: use the native QPC Tajweed font engine
  if (!kIsWeb && mushafEdition == 'tajweed_qcf4') {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = fullWidth
        ? (viewportWidth ?? MediaQuery.of(context).size.width)
        : MediaQuery.of(context).size.width;
    final h = w * _kPageAspectRatio;
    return SizedBox(
      width: w,
      height: h,
      child: QuranPagesScreen(
        isDark: isDark,
        startPage: pageNum,
        endPage: pageNum,
        parentContext: context,
      ),
    );
  }

  if (fullWidth) {
    final w = viewportWidth ?? MediaQuery.of(context).size.width;
    final h = w * _kPageAspectRatio;
    return SizedBox(
      width:  w,
      height: h,
      child:  _QuranPageWebView(
        pageNum:         pageNum,
        onTap:           onTap,
        onVerseTapped:   onVerseTapped,
        selectedVerseId: selectedVerseId,
        playingVerseId:  playingVerseId,
        fullWidth:       fullWidth,
        mushafEdition:   mushafEdition,
      ),
    );
  }
  return _QuranPageWebView(
    pageNum:         pageNum,
    onTap:           onTap,
    onVerseTapped:   onVerseTapped,
    selectedVerseId: selectedVerseId,
    playingVerseId:  playingVerseId,
    fullWidth:       fullWidth,
    mushafEdition:   mushafEdition,
  );
}

class _QuranPageWebView extends StatefulWidget {
  final int pageNum;
  final VoidCallback? onTap;
  final void Function(int surah, int ayah)? onVerseTapped;
  final int? selectedVerseId;
  final int? playingVerseId;
  final bool fullWidth;
  final String mushafEdition;

  const _QuranPageWebView({
    required this.pageNum,
    this.onTap,
    this.onVerseTapped,
    this.selectedVerseId,
    this.playingVerseId,
    this.fullWidth = false,
    this.mushafEdition = 'hafs_kfqc',
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

    final svgText = await _loadSvg(widget.pageNum, widget.mushafEdition);
    if (!mounted) return;

    if (svgText != null) {
      _controller.loadHtmlString(_buildHtml(svgText, widget.fullWidth, widget.mushafEdition));
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

    if (old.pageNum != widget.pageNum ||
        old.fullWidth != widget.fullWidth ||
        old.mushafEdition != widget.mushafEdition) {
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
