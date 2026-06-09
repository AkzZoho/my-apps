import 'dart:async';
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
  bool _refreshing = false;
  AppL10n? _l10n;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing || !mounted) return;
    setState(() => _refreshing = true);
    try {
      final fresh = await dataService.getData();
      if (mounted) ref.read(appDataProvider.notifier).updateState(fresh);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

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

  Future<void> _confirmReopen(BuildContext context, AppL10n l10n, KuriAuction auction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) {
        final cc = dCtx.colors;
        return AlertDialog(
          backgroundColor: cc.surface,
          title: Text(l10n.reopenAuction,
              style: TextStyle(color: cc.warn, fontWeight: FontWeight.bold)),
          content: Text(
            '${formatMonthKey(auction.month)} — Winner and prize data will be cleared. Bids will be kept.',
            style: TextStyle(color: cc.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(l10n.reopenAuction,
                  style: TextStyle(color: cc.warn, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await dataService.reopenAuction(auction.id, widget.currentUserId);
      final fresh = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(fresh);
      if (mounted) showSuccess(context, l10n.auctionOpen);
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _closeAuction(KuriAuction auction, AppData data) async {
    final winnerId = await showAppBottomSheet<String>(
      context,
      _SelectWinnerSheet(auction: auction, data: data),
    );
    if (winnerId == null || !mounted) return;
    setState(() => _loading = true);
    try {
      await dataService.closeAuction(auction.id, widget.currentUserId, winnerId);
      final fresh = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(fresh);
      if (mounted) showSuccess(context, _l10n!.auctionClosed);
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
        appBar: AppBar(
          title: Text(l10n.auction),
          actions: [
            if (_refreshing)
              Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _refresh,
              ),
          ],
        ),
        body: data == null
            ? Center(child: CircularProgressIndicator(color: c.primary))
            : RefreshIndicator(
                onRefresh: _refresh,
                color: c.primary,
                child: _buildBody(context, c, l10n, data),
              ),
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
              .map((a) => _buildClosedAuctionCard(context, c, l10n, data, widget.kuri, a)),
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
          // Moopan sees all participants with per-member bid/status
          if (widget.currentUserId == kuri.createdBy) ...[
            ...kuri.participantUserIds.map((uid) {
              final user = data.users.firstWhere(
                (u) => u.id == uid,
                orElse: () => AppUser(id: uid, name: uid, email: ''),
              );
              final existingBid = auction.bids.firstWhere(
                (b) => b.userId == uid,
                orElse: () => AuctionBid(userId: '', discountAmount: 0, bidAt: ''),
              );
              final hasBid = existingBid.userId.isNotEmpty;
              final alreadyWon = data.auctions.any((a) =>
                  a.kuriId == kuri.id && a.status == 'closed' && a.winnerId == uid);
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
                    if (hasBid)
                      TextButton(
                        onPressed: () => showAppBottomSheet(
                          context,
                          _AdminBidSheet(
                            auction: auction,
                            kuri: kuri,
                            member: user,
                            pool: pool,
                            onDone: () async {
                              final fresh = await dataService.getData();
                              if (mounted) ref.read(appDataProvider.notifier).updateState(fresh);
                            },
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '₹${existingBid.discountAmount.toInt()} ✎',
                          style: TextStyle(
                              color: c.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      )
                    else if (alreadyWon)
                      Text(l10n.winner,
                          style: TextStyle(color: c.textMuted, fontSize: 12))
                    else
                      TextButton(
                        onPressed: () => showAppBottomSheet(
                          context,
                          _AdminBidSheet(
                            auction: auction,
                            kuri: kuri,
                            member: user,
                            pool: pool,
                            onDone: () async {
                              final fresh = await dataService.getData();
                              if (mounted) ref.read(appDataProvider.notifier).updateState(fresh);
                            },
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(l10n.placeBid,
                            style: TextStyle(fontSize: 12, color: c.primary)),
                      ),
                  ],
                ),
              );
            }),
            Divider(color: c.border, height: 16),
          ] else if (auction.bids.isEmpty)
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
          // Moopan: close auction only; member: place their own bid
          if (widget.currentUserId == kuri.createdBy)
            ElevatedButton.icon(
              onPressed: () => _closeAuction(auction, data),
              icon: const Icon(Icons.lock_outline, size: 16),
              label: Text(l10n.closeAuction),
            )
          else
            OutlinedButton.icon(
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
        ],
      ),
    );
  }

  Widget _buildClosedAuctionCard(
    BuildContext context,
    AppColors c,
    AppL10n l10n,
    AppData data,
    KuriPlan kuri,
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
                Expanded(
                  child: Text(
                    '${l10n.winner}: ${winner.name}',
                    style: TextStyle(color: c.text, fontSize: 13),
                  ),
                ),
                if (widget.currentUserId == kuri.createdBy)
                  TextButton.icon(
                    onPressed: () => _confirmReopen(context, l10n, auction),
                    icon: Icon(Icons.lock_open_outlined, size: 14, color: c.warn),
                    label: Text(l10n.reopenAuction,
                        style: TextStyle(fontSize: 12, color: c.warn)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.warn.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.warn.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${l10n.winner}: ${winner.name}',
                  style: TextStyle(
                      color: c.text, fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (auction.prizeAmount != null || auction.dividendPerMember != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                if (auction.prizeAmount != null)
                  Text(
                    '₹${auction.prizeAmount!.toInt()} ${l10n.prizeAmount.toLowerCase()}',
                    style: TextStyle(color: c.green, fontSize: 11),
                  ),
                if (auction.prizeAmount != null && auction.dividendPerMember != null &&
                    (auction.dividendPerMember ?? 0) > 0)
                  Text(' · ', style: TextStyle(color: c.textDim, fontSize: 11)),
                if (auction.dividendPerMember != null && (auction.dividendPerMember ?? 0) > 0)
                  Text(
                    '₹${auction.dividendPerMember!.toInt()} ${l10n.dividendPerMember.toLowerCase()}',
                    style: TextStyle(color: c.primary, fontSize: 11),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── _SelectWinnerSheet ───────────────────────────────────────────────────────

class _SelectWinnerSheet extends ConsumerStatefulWidget {
  final KuriAuction auction;
  final AppData data;

  const _SelectWinnerSheet({required this.auction, required this.data});

  @override
  ConsumerState<_SelectWinnerSheet> createState() => _SelectWinnerSheetState();
}

class _SelectWinnerSheetState extends ConsumerState<_SelectWinnerSheet> {
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    // Pre-select highest bidder
    if (widget.auction.bids.isNotEmpty) {
      final top = [...widget.auction.bids]
        ..sort((a, b) => b.discountAmount.compareTo(a.discountAmount));
      _selectedUserId = top.first.userId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    final sortedBids = [...widget.auction.bids]
      ..sort((a, b) => b.discountAmount.compareTo(a.discountAmount));

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                l10n.selectWinner,
                style: TextStyle(
                    color: c.text, fontSize: 16, fontWeight: FontWeight.bold),
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
            formatMonthKey(widget.auction.month),
            style: TextStyle(color: c.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...sortedBids.map((bid) {
            final user = widget.data.users.firstWhere(
              (u) => u.id == bid.userId,
              orElse: () => AppUser(id: bid.userId, name: bid.userId, email: ''),
            );
            final isTop = bid.userId == sortedBids.first.userId;
            final isSelected = _selectedUserId == bid.userId;
            return GestureDetector(
              onTap: () => setState(() => _selectedUserId = bid.userId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected
                      ? c.primary.withOpacity(0.1)
                      : c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? c.primary : c.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    AvatarWidget(name: user.name, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              style: TextStyle(
                                  color: c.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          Text(
                            '₹${bid.discountAmount.toInt()} discount',
                            style: TextStyle(color: c.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (isTop)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.warn.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Highest',
                            style: TextStyle(
                                color: c.warn,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    Radio<String>(
                      value: bid.userId,
                      groupValue: _selectedUserId,
                      activeColor: c.primary,
                      onChanged: (v) =>
                          setState(() => _selectedUserId = v),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _selectedUserId == null
                ? null
                : () => Navigator.pop(context, _selectedUserId),
            icon: const Icon(Icons.lock_outline, size: 16),
            label: Text(l10n.closeAuction),
          ),
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

// ─── Admin: place a bid on behalf of a member ────────────────────────────────

class _AdminBidSheet extends ConsumerStatefulWidget {
  final KuriAuction auction;
  final KuriPlan kuri;
  final AppUser member;
  final double pool;
  final VoidCallback onDone;

  const _AdminBidSheet({
    required this.auction,
    required this.kuri,
    required this.member,
    required this.pool,
    required this.onDone,
  });

  @override
  ConsumerState<_AdminBidSheet> createState() => _AdminBidSheetState();
}

class _AdminBidSheetState extends ConsumerState<_AdminBidSheet> {
  final _amountCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.auction.bids.firstWhere(
      (b) => b.userId == widget.member.id,
      orElse: () => AuctionBid(userId: '', discountAmount: 0, bidAt: ''),
    );
    if (existing.userId.isNotEmpty) {
      _amountCtrl.text = existing.discountAmount.toInt().toString();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppL10n(ref.read(localeProvider));
    final amount = double.tryParse(_amountCtrl.text.trim());
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
      await dataService.placeBid(widget.auction.id, widget.member.id, amount);
      widget.onDone();
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.bidForMember,
                      style: TextStyle(
                          color: c.text,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${widget.member.name} · ${formatMonthKey(widget.auction.month)}',
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
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
