import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../l10n.dart';
import '../models.dart';
import '../providers/providers.dart';
import '../services/data_service.dart';
import '../widgets/common.dart';

// ─── KuriAuctionScreen ────────────────────────────────────────────────────────

class KuriAuctionScreen extends ConsumerStatefulWidget {
  final KuriPlan kuri;
  final String currentUserId;

  const KuriAuctionScreen({
    super.key,
    required this.kuri,
    required this.currentUserId,
  });

  @override
  ConsumerState<KuriAuctionScreen> createState() => _KuriAuctionScreenState();
}

class _KuriAuctionScreenState extends ConsumerState<KuriAuctionScreen> {
  bool _loading = false;
  AppL10n? _l10n;

  Future<void> _openAuction(String month) async {
    setState(() => _loading = true);
    try {
      await dataService.openAuction(widget.kuri.id, month, widget.currentUserId);
      final fresh = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(fresh);
      if (mounted) showSuccess(context, '${_l10n!.auctionOpen} — ${formatMonthKey(month)}');
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _closeAuction(KuriAuction auction) async {
    final l10n = _l10n!;
    final confirmed = await confirmDialog(
      context,
      title: l10n.closeAuction,
      message: '${l10n.closeAuction}?',
      confirmLabel: l10n.closeAuction,
    );
    if (!confirmed || !mounted) return;
    setState(() => _loading = true);
    try {
      await dataService.closeAuction(auction.id, widget.currentUserId);
      final fresh = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(fresh);
      if (mounted) showSuccess(context, l10n.auctionClosed);
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    _l10n = l10n;
    final data = ref.watch(appDataProvider).valueOrNull;

    return LoadingOverlay(
      loading: _loading,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: Text(l10n.auction)),
        body: data == null
            ? Center(child: CircularProgressIndicator(color: c.primary))
            : _buildBody(context, c, l10n, data),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, AppColors c, AppL10n l10n, AppData data) {
    final kuri = data.kuris.firstWhere(
      (k) => k.id == widget.kuri.id,
      orElse: () => widget.kuri,
    );
    final kuriAuctions = data.auctions
        .where((a) => a.kuriId == kuri.id)
        .toList()
      ..sort((a, b) => b.month.compareTo(a.month));

    final elapsedMonths = generateMonths(kuri.startDate, includeFuture: false);
    final closedMonths = kuriAuctions
        .where((a) => a.status == 'closed')
        .map((a) => a.month)
        .toSet();

    String? activeMonth;
    for (final m in elapsedMonths) {
      if (!closedMonths.contains(m)) {
        activeMonth = m;
        break;
      }
    }

    final openAuction = kuriAuctions.firstWhere(
      (a) => a.status == 'open',
      orElse: () => KuriAuction(
        id: '',
        kuriId: '',
        month: '',
        status: '',
        bids: [],
        createdAt: '',
      ),
    );
    final hasOpenAuction = openAuction.id.isNotEmpty;

    final closedAuctions = kuriAuctions.where((a) => a.status == 'closed').toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildInfoCard(context, c, l10n, kuri),
        const SizedBox(height: 12),
        _buildActiveSection(
            context, c, l10n, data, kuri, activeMonth, openAuction, hasOpenAuction),
        if (closedAuctions.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionTitle(l10n.auctionHistory),
          ...closedAuctions
              .map((a) => _buildClosedAuctionCard(context, c, l10n, data, a)),
        ],
      ],
    );
  }

  Widget _buildInfoCard(
      BuildContext context, AppColors c, AppL10n l10n, KuriPlan kuri) {
    final pool = kuri.contributionAmount * kuri.participantUserIds.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, color: c.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                kuri.name,
                style: TextStyle(
                    color: c.text, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: l10n.pool,
            value: '₹${pool.toInt()}',
            c: c,
          ),
          _InfoRow(
            label: l10n.moopanCommissionLabel,
            value: '${kuri.moopanCommissionPercent}%',
            c: c,
          ),
          _InfoRow(
            label: 'Max discount',
            value: '${kuri.maxDiscountPercent}%  (₹${(pool * kuri.maxDiscountPercent / 100).toInt()})',
            c: c,
          ),
          _InfoRow(
            label: 'Prize paid within',
            value: '${kuri.prizePaidWithinDays} days',
            c: c,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSection(
    BuildContext context,
    AppColors c,
    AppL10n l10n,
    AppData data,
    KuriPlan kuri,
    String? activeMonth,
    KuriAuction openAuction,
    bool hasOpenAuction,
  ) {
    if (activeMonth == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: c.green, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'All months up to date.',
                style: TextStyle(color: c.textMuted, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    if (hasOpenAuction && openAuction.month == activeMonth) {
      return _buildOpenAuctionCard(context, c, l10n, data, kuri, openAuction);
    }

    return _buildNoAuctionCard(context, c, l10n, kuri, activeMonth);
  }

  Widget _buildNoAuctionCard(
    BuildContext context,
    AppColors c,
    AppL10n l10n,
    KuriPlan kuri,
    String month,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, color: c.textMuted, size: 16),
              const SizedBox(width: 6),
              Text(
                formatMonthKey(month),
                style: TextStyle(
                    color: c.text, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const Spacer(),
              StatusBadge(label: l10n.noAuctionYet, color: c.textDim),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openAuction(month),
            icon: const Icon(Icons.gavel, size: 16),
            label: Text('${l10n.openAuctionFor} ${formatMonthKey(month)}'),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenAuctionCard(
    BuildContext context,
    AppColors c,
    AppL10n l10n,
    AppData data,
    KuriPlan kuri,
    KuriAuction auction,
  ) {
    final pool = kuri.contributionAmount * kuri.participantUserIds.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, color: c.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                formatMonthKey(auction.month),
                style: TextStyle(
                    color: c.text, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const Spacer(),
              StatusBadge(label: l10n.auctionOpen, color: c.primary),
            ],
          ),
          const SizedBox(height: 12),
          if (auction.bids.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.noBids,
                style: TextStyle(color: c.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            ...auction.bids.map((bid) {
              final user = data.users.firstWhere(
                (u) => u.id == bid.userId,
                orElse: () =>
                    AppUser(id: bid.userId, name: bid.userId, email: ''),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    AvatarWidget(name: user.name, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(user.name,
                          style: TextStyle(color: c.text, fontSize: 13)),
                    ),
                    Text(
                      '₹${bid.discountAmount.toInt()} ${l10n.discountAmount.replaceAll(' (₹)', '')}',
                      style: TextStyle(
                          color: c.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ],
                ),
              );
            }),
            Divider(color: c.border, height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showAppBottomSheet(
                    context,
                    _BidSheet(
                      auction: auction,
                      kuri: kuri,
                      userId: widget.currentUserId,
                      pool: pool,
                    ),
                  ).then((_) async {
                    final fresh = await dataService.getData();
                    if (mounted) {
                      ref.read(appDataProvider.notifier).updateState(fresh);
                    }
                  }),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.placeBid),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _closeAuction(auction),
                  icon: const Icon(Icons.lock_outline, size: 16),
                  label: Text(l10n.closeAuction,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClosedAuctionCard(
    BuildContext context,
    AppColors c,
    AppL10n l10n,
    AppData data,
    KuriAuction auction,
  ) {
    final winner = auction.winnerId != null
        ? data.users.firstWhere(
            (u) => u.id == auction.winnerId,
            orElse: () =>
                AppUser(id: auction.winnerId!, name: auction.winnerId!, email: ''),
          )
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                formatMonthKey(auction.month),
                style: TextStyle(
                    color: c.text, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              StatusBadge(label: l10n.auctionClosed, color: c.textDim),
            ],
          ),
          if (winner != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.emoji_events, color: c.warn, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${l10n.winner}: ${winner.name}',
                  style: TextStyle(color: c.text, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    label: l10n.prizeAmount,
                    value: '₹${auction.prizeAmount?.toInt() ?? 0}',
                    c: c,
                    compact: true,
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    label: l10n.dividendPerMember,
                    value: '₹${auction.dividendPerMember?.toInt() ?? 0}',
                    c: c,
                    compact: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── _BidSheet ────────────────────────────────────────────────────────────────

class _BidSheet extends ConsumerStatefulWidget {
  final KuriAuction auction;
  final KuriPlan kuri;
  final String userId;
  final double pool;

  const _BidSheet({
    required this.auction,
    required this.kuri,
    required this.userId,
    required this.pool,
  });

  @override
  ConsumerState<_BidSheet> createState() => _BidSheetState();
}

class _BidSheetState extends ConsumerState<_BidSheet> {
  final _amountCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppL10n(ref.read(localeProvider));
    final raw = _amountCtrl.text.trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      showError(context, l10n.validAmount);
      return;
    }
    final maxDiscount = widget.pool * widget.kuri.maxDiscountPercent / 100;
    if (amount > maxDiscount) {
      showError(context, l10n.bidExceedsMax);
      return;
    }
    setState(() => _loading = true);
    try {
      await dataService.placeBid(widget.auction.id, widget.userId, amount);
      final fresh = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(fresh);
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, l10n.yourBid);
      }
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    final maxDiscount = widget.pool * widget.kuri.maxDiscountPercent / 100;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${l10n.placeBid} — ${formatMonthKey(widget.auction.month)}',
                style: TextStyle(
                    color: c.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: c.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Max: ₹${maxDiscount.toInt()} (${widget.kuri.maxDiscountPercent.toInt()}% of ${l10n.pool})',
            style: TextStyle(color: c.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: TextStyle(color: c.text),
            decoration: InputDecoration(
              labelText: l10n.discountAmount,
              prefixText: '₹',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: c.primaryFg, strokeWidth: 2),
                  )
                : Text(l10n.placeBid),
          ),
        ],
      ),
    );
  }
}

// ─── AuctionMemberBanner ──────────────────────────────────────────────────────

class AuctionMemberBanner extends ConsumerWidget {
  final KuriPlan kuri;
  final KuriAuction auction;
  final String currentUserId;

  const AuctionMemberBanner({
    super.key,
    required this.kuri,
    required this.auction,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    final pool = kuri.contributionAmount * kuri.participantUserIds.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.gavel, color: Colors.teal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.auctionOpen} — ${formatMonthKey(auction.month)}',
                  style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                Text(
                  '${auction.bids.length} bid(s) · Max ₹${(pool * kuri.maxDiscountPercent / 100).toInt()}',
                  style: TextStyle(color: c.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => showAppBottomSheet(
              context,
              _BidSheet(
                auction: auction,
                kuri: kuri,
                userId: currentUserId,
                pool: pool,
              ),
            ).then((_) async {
              final fresh = await dataService.getData();
              if (context.mounted) {
                ref.read(appDataProvider.notifier).updateState(fresh);
              }
            }),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(l10n.placeBid),
          ),
        ],
      ),
    );
  }
}

// ─── MonthWinnerChip ──────────────────────────────────────────────────────────

class MonthWinnerChip extends ConsumerWidget {
  final KuriAuction auction;
  final AppData data;

  const MonthWinnerChip({super.key, required this.auction, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    if (auction.winnerId == null) return const SizedBox.shrink();

    final winner = data.users.firstWhere(
      (u) => u.id == auction.winnerId,
      orElse: () =>
          AppUser(id: auction.winnerId!, name: auction.winnerId!, email: ''),
    );

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.warn.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.warn.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🏆', style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            '${l10n.winner}: ${winner.name}',
            style: TextStyle(
                color: c.text, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          if (auction.prizeAmount != null) ...[
            Text(' · ', style: TextStyle(color: c.textDim, fontSize: 12)),
            Text(
              '₹${auction.prizeAmount!.toInt()} ${l10n.prizeAmount.toLowerCase()}',
              style: TextStyle(color: c.green, fontSize: 12),
            ),
          ],
          if (auction.dividendPerMember != null) ...[
            Text(' · ', style: TextStyle(color: c.textDim, fontSize: 12)),
            Text(
              '₹${auction.dividendPerMember!.toInt()} ${l10n.dividendPerMember.toLowerCase()}',
              style: TextStyle(color: c.primary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── _InfoRow ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final AppColors c;
  final bool compact;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.c,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 2 : 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
                color: c.textMuted, fontSize: compact ? 11 : 12),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                  color: c.text,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
