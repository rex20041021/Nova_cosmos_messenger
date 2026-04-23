import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nova_cosmos_messenger/models/apod_data.dart';
import 'package:nova_cosmos_messenger/services/apod_service.dart';
import 'package:nova_cosmos_messenger/route/favorites_page.dart';
import 'package:nova_cosmos_messenger/route/chat_history_page.dart';
import 'package:nova_cosmos_messenger/route/apod_detail_page.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _kBg = Color(0xFF050505);
const _kFg = Color(0xFFF6F2EA);
const _kMuted = Color(0x72F6F2EA);
const _kFaint = Color(0x38F6F2EA);
const _kHair = Color(0x14F6F2EA);
const _kAccent = Color(0xFFD9C5A7);
const _kSignal = Color(0xFFE94B2A);

// ── Text styles ──────────────────────────────────────────────────────────────
TextStyle _serif(double size,
        {FontStyle style = FontStyle.normal,
        Color color = _kFg,
        double? height}) =>
    GoogleFonts.instrumentSerif(
        fontSize: size, fontStyle: style, color: color, height: height);

TextStyle _mono(double size,
        {Color color = _kMuted, double letterSpacing = .18}) =>
    GoogleFonts.dmMono(
        fontSize: size,
        color: color,
        letterSpacing: letterSpacing,
        fontWeight: FontWeight.w300);

// ── HomePage ─────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  ApodData? _apod;
  bool _loading = true;

  late final AnimationController _kenBurns;
  late final Animation<double> _kbScale;
  late final Animation<Offset> _kbOffset;

  @override
  void initState() {
    super.initState();
    _kenBurns = AnimationController(
      duration: const Duration(seconds: 24),
      vsync: this,
    )..repeat(reverse: true);

    _kbScale = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _kenBurns, curve: Curves.easeInOut),
    );
    _kbOffset = Tween<Offset>(
      begin: const Offset(-10, -8),
      end: const Offset(10, 8),
    ).animate(CurvedAnimation(parent: _kenBurns, curve: Curves.easeInOut));

    _loadApod();
  }

  @override
  void dispose() {
    _kenBurns.dispose();
    super.dispose();
  }

  Future<void> _loadApod() async {
    try {
      final apod = await ApodService.fetchApod();
      if (mounted) setState(() { _apod = apod; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _openTodayApod() {
    final apod = _apod;
    if (apod == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ApodDetailPage(apod: apod)));
  }

  Future<void> _queryApod() async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            Container(width: 36, height: 4, decoration: BoxDecoration(
              color: _kHair, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            _SheetTile(
              icon: Icons.calendar_today_outlined,
              title: '選擇日期',
              subtitle: '挑一個你想看的日子',
              onTap: () => Navigator.pop(ctx, 'date'),
            ),
            _SheetTile(
              icon: Icons.casino_outlined,
              title: '隨機一天',
              subtitle: '讓 NASA 隨機挑一張給你',
              onTap: () => Navigator.pop(ctx, 'random'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;
    if (mode == 'date') await _queryByDate();
    if (mode == 'random') await _fetchAndShow(() => ApodService.fetchApod(random: true));
  }

  Future<void> _queryByDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1995, 6, 16),
      lastDate: DateTime.now(),
      helpText: '選擇 APOD 日期',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            surface: const Color(0xFF1a1a1a),
            onSurface: _kFg,
            primary: _kAccent,
            onPrimary: _kBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final d = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
    await _fetchAndShow(() => ApodService.fetchApod(date: d));
  }

  Future<void> _fetchAndShow(Future<ApodData> Function() fetcher) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _kAccent)),
    );
    try {
      final apod = await fetcher();
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ApodDetailPage(apod: apod)));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('查詢失敗：$e')),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBrand(),
              const SizedBox(height: 26),
              _buildEyebrow(),
              const SizedBox(height: 14),
              _buildHero(),
              const SizedBox(height: 16),
              _buildMeta(),
              const SizedBox(height: 8),
              _buildTitle(),
              const SizedBox(height: 14),
              _buildDesc(),
              const SizedBox(height: 14),
              _buildViewCta(),
              const SizedBox(height: 34),
              _buildSectionLabel(),
              _buildNavList(),
              const SizedBox(height: 24),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _buildBrand() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Nova',
                    style: _serif(22, style: FontStyle.italic),
                  ),
                  TextSpan(
                    text: ' ✷',
                    style: _serif(14, color: _kAccent),
                  ),
                ],
              ),
            ),
            Text('MESSENGER · MMXXVI', style: _mono(9.5, letterSpacing: .22)),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: _kHair),
      ],
    );
  }

  Widget _buildEyebrow() {
    return Row(
      children: [
        const _PulseDot(),
        const SizedBox(width: 10),
        Text('TODAY IN THE SKY', style: _mono(10, letterSpacing: .22)),
      ],
    );
  }

  Widget _buildHero() {
    return GestureDetector(
      onTap: _apod != null ? _openTodayApod : null,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // image with Ken Burns
              AnimatedBuilder(
                animation: _kenBurns,
                builder: (context, child) => Transform.translate(
                  offset: _kbOffset.value,
                  child: Transform.scale(scale: _kbScale.value, child: child),
                ),
                child: _loading || _apod == null || _apod!.isVideo
                    ? Container(color: const Color(0xFF0b1024))
                    : Image.network(
                        _apod!.url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) =>
                            Container(color: const Color(0xFF0b1024)),
                      ),
              ),
              // gradient overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .3, .7, 1],
                    colors: [
                      Color(0x40000000),
                      Colors.transparent,
                      Colors.transparent,
                      Color(0x80000000),
                    ],
                  ),
                ),
              ),
              // thin border
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              // top labels
              Positioned(
                top: 14, left: 14, right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_apod != null)
                      Text(
                        _apod!.date.replaceAll('-', ' · '),
                        style: _mono(10, color: Colors.white.withValues(alpha: 0.9), letterSpacing: .18),
                      ),
                    Text('APOD',
                        style: _mono(10, color: Colors.white.withValues(alpha: 0.9), letterSpacing: .22)),
                  ],
                ),
              ),
              // bottom attribution
              if (_apod != null && _apod!.copyright != null)
                Positioned(
                  bottom: 14, left: 14,
                  child: Text(
                    'photograph · ${_apod!.copyright!.replaceAll('\n', ' ').trim()}',
                    style: _serif(12,
                        style: FontStyle.italic,
                        color: Colors.white.withValues(alpha: 0.8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // loading indicator
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(
                    color: _kAccent, strokeWidth: 1.5,
                  ),
                ),
              // video placeholder
              if (!_loading && _apod != null && _apod!.isVideo)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_outline, color: _kAccent, size: 48),
                      SizedBox(height: 8),
                      Text('Video APOD', style: TextStyle(color: _kMuted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeta() {
    final date = _apod?.date ?? '—';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Feature · $date', style: _mono(9.5, letterSpacing: .18)),
        Text('NASA APOD', style: _mono(9.5, letterSpacing: .18)),
      ],
    );
  }

  Widget _buildTitle() {
    if (_apod == null) {
      return Text('—', style: _serif(46, style: FontStyle.italic));
    }
    final title = _apod!.title;
    // Try to split last word/phrase into italic accent
    final spaceIdx = title.lastIndexOf(' ');
    final first = spaceIdx > 0 ? title.substring(0, spaceIdx + 1) : '';
    final last = spaceIdx > 0 ? title.substring(spaceIdx + 1) : title;

    return RichText(
      text: TextSpan(
        style: _serif(44, height: .95),
        children: [
          TextSpan(text: first),
          TextSpan(text: last, style: _serif(44, style: FontStyle.italic, color: _kAccent, height: .95)),
        ],
      ),
    );
  }

  Widget _buildDesc() {
    final explanation = _apod?.explanation ?? '';
    final excerpt = explanation.length > 160
        ? '${explanation.substring(0, 160).trim()}…'
        : explanation;
    return Text(
      excerpt,
      style: GoogleFonts.dmMono(
        fontSize: 12,
        fontWeight: FontWeight.w300,
        color: _kMuted,
        height: 1.6,
        letterSpacing: .01,
      ),
    );
  }

  Widget _buildViewCta() {
    if (_apod == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _openTodayApod,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 3),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kFg, width: 1)),
            ),
            child: Row(
              children: [
                Text('VIEW FULL ENTRY', style: _mono(10, color: _kFg, letterSpacing: .22)),
                const SizedBox(width: 8),
                const Text('→', style: TextStyle(color: _kFg, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel() {
    return Row(
      children: [
        Text('CONTINUE', style: _mono(10, letterSpacing: .22)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: _kHair)),
        const SizedBox(width: 10),
        Text('03', style: _mono(10, letterSpacing: .1)),
      ],
    );
  }

  Widget _buildNavList() {
    return Column(
      children: [
        _NavItem(
          number: '01',
          title: 'Dialogues with ',
          titleItalic: 'Nova',
          desc: 'Ask about the cosmos. Keep the thread.',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatHistoryPage()),
          ),
        ),
        _NavItem(
          number: '02',
          title: 'APOD ',
          titleItalic: 'Archive',
          desc: 'Pick a day — or let the sky choose.',
          onTap: _queryApod,
        ),
        _NavItem(
          number: '03',
          title: 'Private ',
          titleItalic: 'Constellation',
          desc: 'The skies you\'ve kept.',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FavoritesPage()),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('NVA / 03', style: _mono(9, color: _kFaint, letterSpacing: .3)),
        Text('© NASA · APOD', style: _mono(9, color: _kFaint, letterSpacing: .18)),
      ],
    );
  }
}

// ── _PulseDot ─────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1, end: .28).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            color: _kSignal,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _kSignal.withValues(alpha: 0.6), blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}

// ── _NavItem ──────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final String number;
  final String title;
  final String titleItalic;
  final String desc;
  final VoidCallback onTap;

  const _NavItem({
    required this.number,
    required this.title,
    required this.titleItalic,
    required this.desc,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) => setState(() => _hovered = false),
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(
          left: _hovered ? 6 : 0,
          top: 18, bottom: 18,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _kHair)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              child: Text(widget.number, style: _mono(10, color: _kFaint, letterSpacing: .05)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: _serif(22),
                      children: [
                        TextSpan(text: widget.title),
                        TextSpan(
                          text: widget.titleItalic,
                          style: _serif(22, style: FontStyle.italic, color: _kAccent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(widget.desc,
                    style: GoogleFonts.dmMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: _kMuted,
                      letterSpacing: .01,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 20,
                color: _hovered ? _kFg : _kFaint,
              ),
              child: const Text('→'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _SheetTile ────────────────────────────────────────────────────────────────

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _kAccent),
      title: Text(title, style: const TextStyle(color: _kFg)),
      subtitle: Text(subtitle, style: const TextStyle(color: _kMuted, fontSize: 12)),
      onTap: onTap,
    );
  }
}
