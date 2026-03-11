import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../controllers/app_ctrl.dart';

// ── Certified-links screen palette (from Pencil frame "tl0y5") ──
const _screenGradientStart = Color(0xFFF8FBFF);
const _screenGradientEnd = Color(0xFFE7EEF8);
const _cardBackground = Color(0xFFF4F8FF);
const _cardBorder = Color(0xFFD6E0EE);
const _rowBorderColor = Color(0xFFD6E0EE);
const _badgeBackground = Color(0xFF3D5A80);
const _titleColor = Color(0xFF2D2D2D);
const _bodyTextColor = Color(0xFF2D2D2D);
const _mutedTextColor = Color(0xFF6B7280);
const _statusOpenColor = Color(0xFF0B63FF);
const _statusVerifyingColor = Color(0xFF10B981);
const _statusUnavailableColor = Color(0xFFC53D43);
const _statusIndicatorOpen = Color(0xFF3BC981);
const _statusIndicatorPending = Color(0xFFFFC266);
const _statusIndicatorUnavailable = Color(0xFFFF6D72);
const _inkSplashColor = Color(0xFFB8D0F0);

const _cardRadius = 20.0;
const _cardShadow = [
  BoxShadow(
    color: Color(0x40000000),
    blurRadius: 4,
    offset: Offset(0, 4),
  ),
];

class LinksScreen extends StatelessWidget {
  const LinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF2F7FF), Color(0xFFE3EBF7)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 402),
            child: SafeArea(
              child: Selector<AppCtrl, List<String>>(
                selector: (ctx, appCtrl) =>
                    appCtrl.profileFields['recommended_links'] ?? [],
                builder: (ctx, links, _) {
                  if (links.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No certified links yet. Ask the agent for a recommendation.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 14,
                            height: 1.6,
                            color: const Color(0xFF8C98A6),
                          ),
                        ),
                      ),
                    );
                  }
                  return _CertifiedLinksBody(links: links);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Main body: three separate cards with space-between ──

class _CertifiedLinksBody extends StatefulWidget {
  const _CertifiedLinksBody({required this.links});

  final List<String> links;

  @override
  State<_CertifiedLinksBody> createState() => _CertifiedLinksBodyState();
}

class _CertifiedLinksBodyState extends State<_CertifiedLinksBody> {
  List<_LinkEntry> _entries = [];
  final Map<String, Future<bool>> _availability = {};

  @override
  void initState() {
    super.initState();
    _prepareEntries();
  }

  @override
  void didUpdateWidget(covariant _CertifiedLinksBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.links, widget.links)) {
      _prepareEntries();
    }
  }

  void _prepareEntries() {
    _entries = widget.links
        .map((raw) => _LinkEntry(
              raw.trim().isEmpty ? 'Link' : raw.trim(),
              _normalizeRecommendationLink(raw),
            ))
        .where((entry) => entry.url.isNotEmpty)
        .toList();
    _availability
      ..clear()
      ..addEntries(
          _entries.map((entry) => MapEntry(entry.url, _checkLink(entry.url))));
  }

  Future<bool> _checkLink(String url) async {
    try {
      final uri = Uri.parse(url);
      final response =
          await http.head(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode >= 200 && response.statusCode < 400) {
        return true;
      }
      if (response.statusCode == 405) {
        final fallback =
            await http.get(uri).timeout(const Duration(seconds: 4));
        return fallback.statusCode >= 200 && fallback.statusCode < 400;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          clipBehavior: Clip.none,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Card 1: Header ──
                    _buildHeaderCard(),
                    const SizedBox(height: 16),

                    // ── Card 2: Link rows ──
                    _buildLinksCard(),

                    // Spacer pushes footer to the bottom
                    const Spacer(),
                    const SizedBox(height: 16),

                    // ── Card 3: Footer ──
                    _buildFooterCard(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Header card ──
  Widget _buildHeaderCard() {
    final titleStyle = GoogleFonts.sora(
      fontSize: 22,
      fontWeight: FontWeight.normal,
      color: _titleColor,
    );
    final badgeStyle = GoogleFonts.ibmPlexMono(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      color: Colors.white,
    );

    return Container(
      width: 338,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _cardBorder),
        boxShadow: _cardShadow,
      ),
      child: Row(
        children: [
          // ── Back Button ──
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _cardBackground.withOpacity(0.5), // translucent to see blur
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 22,
                    color: _titleColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // ── Title and Badge ──
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Reference',
                    style: titleStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _badgeBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _BadgeIcon(),
                      const SizedBox(width: 6),
                      Text('links (${_entries.length})', style: badgeStyle),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Links card ──
  Widget _buildLinksCard() {
    final rows = <Widget>[];
    for (var i = 0; i < _entries.length; i++) {
      if (i > 0) {
        rows.add(const SizedBox(height: 16));
      }
      rows.add(_buildRow(_entries[i]));
    }

    return Container(
      width: 338,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _cardBorder),
        boxShadow: _cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }

  // ── Footer card ──
  Widget _buildFooterCard() {
    final footerStyle = GoogleFonts.sora(
      fontSize: 13,
      fontWeight: FontWeight.normal,
      color: _mutedTextColor,
    );

    return Container(
      width: 338,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _cardBorder),
        boxShadow: _cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Text(
        'Signed by your voice agent',
        textAlign: TextAlign.center,
        style: footerStyle,
      ),
    );
  }

  // ── Link row ──
  Widget _buildRow(_LinkEntry entry) {
    final availability = _availability[entry.url];
    if (availability == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<bool>(
      future: availability,
      builder: (context, snapshot) {
        final isPending = snapshot.connectionState != ConnectionState.done;
        final isLive = snapshot.data ?? false;
        final statusLabel =
            isPending ? 'Verifying…' : (isLive ? 'Open' : 'Unavailable');
        final statusColor = isPending
            ? _statusVerifyingColor
            : (isLive ? _statusOpenColor : _statusUnavailableColor);
        final indicatorColor = isPending
            ? _statusIndicatorPending
            : (isLive ? _statusIndicatorOpen : _statusIndicatorUnavailable);
        final onTap = isPending || !isLive
            ? null
            : () => unawaited(_launchRecommendationLink(entry.url));
        final statusStyle = GoogleFonts.ibmPlexMono(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: statusColor,
        );

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _rowBorderColor),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              splashColor: _inkSplashColor.withValues(alpha: 0.6),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _LinkStatusIndicator(indicatorColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _bodyTextColor,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (isPending) ...[
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _statusVerifyingColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(statusLabel, style: statusStyle),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Small widgets ──

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
    );
  }
}

class _LinkStatusIndicator extends StatelessWidget {
  const _LinkStatusIndicator(this.fillColor);

  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ── Utility functions ──

String _normalizeRecommendationLink(String rawLink) {
  final cleaned = rawLink.trim();
  if (cleaned.isEmpty) {
    return '';
  }
  if (RegExp(r'^(http|https)://', caseSensitive: false).hasMatch(cleaned)) {
    return cleaned;
  }
  return 'https://$cleaned';
}

Future<void> _launchRecommendationLink(String url) async {
  if (url.isEmpty) {
    return;
  }
  if (await canLaunchUrlString(url)) {
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }
}

class _LinkEntry {
  const _LinkEntry(this.label, this.url);

  final String label;
  final String url;
}
