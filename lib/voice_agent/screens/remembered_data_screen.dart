import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../controllers/app_ctrl.dart';

// ── Colors from LinksScreen for consistent UI ──
const _backgroundColor = Color(0xFFF8FBFF);
const _cardBackground = Color(0xFFF4F8FF);
const _cardBorder = Color(0xFFD6E0EE);
const _titleColor = Color(0xFF2D2D2D);
const _badgeBackground = Color(0xFF3D5A80);
const _bodyTextColor = Color(0xFF2D2D2D);
const _rowBorderColor = Color(0xFFE5E7EB);
const _emptyTextColor = Color(0xFF8C98A6);

final _cardShadow = [
  BoxShadow(
    color: const Color(0x40000000), // #00000040
    offset: const Offset(0, 4),
    blurRadius: 4,
  ),
];

class RememberedDataScreen extends StatefulWidget {
  const RememberedDataScreen({super.key});
  @override
  State<RememberedDataScreen> createState() => _RememberedDataScreenState();
}
class _RememberedDataScreenState extends State<RememberedDataScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppCtrl>().requestProfileSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
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
            child: Selector<AppCtrl, Map<String, List<String>>>(
              selector: (ctx, appCtrl) => appCtrl.profileFields,
              builder: (ctx, fields, _) {
                  final filteredEntries = fields.entries
                      .where((e) => e.key != 'recommended_links')
                      .toList();

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isEmpty = filteredEntries.isEmpty;
                      final contentPadding = const EdgeInsets.fromLTRB(20, 35, 20, 20);
                      final sectionSpacing = 24.0;

                      return SingleChildScrollView(
                        clipBehavior: Clip.none,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding: contentPadding,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // ── Card 1: Header ──
                                  _buildHeaderCard(context, filteredEntries.length),
                                  SizedBox(height: sectionSpacing),

                                  // ── Card 2: Items ──
                                  _buildItemsCard(filteredEntries),

                                  const Spacer(),
                                  SizedBox(height: sectionSpacing),

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
                },
              ),
          ),
        ),
      ),
    );
  }

  // ── Header card ──
  Widget _buildHeaderCard(BuildContext context, int itemCount) {
    final titleStyle = GoogleFonts.sora(
      fontSize: 20,
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
        borderRadius: BorderRadius.circular(20),
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
                    color: _cardBackground.withValues(alpha: 0.5),
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
                    'Remembered',
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
                      const Icon(
                        Icons.storage_rounded, // Database equivalent
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text('items ($itemCount)', style: badgeStyle),
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

  Widget _buildItemsCard(List<MapEntry<String, List<String>>> entries) {
    if (entries.isEmpty) {
      return Container(
        width: 383,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorder),
          boxShadow: _cardShadow,
        ),
        child: Center(
          child: Text(
            'Agent has remembered these details from your conversation.',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 14,
              color: _emptyTextColor,
            ),
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) {
        rows.add(const SizedBox(height: 16));
      }
      final entry = entries[i];
      final label = entry.key.replaceAll('_', ' ');
      final joinedVals = entry.value.join(', ');

      rows.add(
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _rowBorderColor),
            boxShadow: _cardShadow, // individual shadow per item card
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                joinedVals,
                style: GoogleFonts.sora(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _bodyTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  // ── Footer card ──
  Widget _buildFooterCard() {
    return Container(
      width: 338,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
        boxShadow: _cardShadow,
      ),
      child: Text(
        'Signed by your voice agent',
        textAlign: TextAlign.center,
        style: GoogleFonts.sora(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }
}
