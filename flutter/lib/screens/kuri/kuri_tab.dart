import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import 'create_kuri_sheet.dart';
import 'kuri_detail_screen.dart';

class KuriTab extends ConsumerWidget {
  const KuriTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final appDataAsync = ref.watch(appDataProvider);

    return appDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: primaryColor)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: dangerColor))),
      data: (data) {
        if (user == null) return const SizedBox();

        final myKuris = data.kuris.where((k) =>
            k.participantUserIds.contains(user.id) || k.createdBy == user.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Scaffold(
          backgroundColor: bgColor,
          body: myKuris.isEmpty
              ? const EmptyState(
                  icon: Icons.currency_rupee,
                  title: 'No Kuris yet',
                  subtitle: 'Create your first savings plan',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: myKuris.length,
                  itemBuilder: (ctx, i) {
                    final kuri = myKuris[i];
                    final approvedPayments = data.payments
                        .where((p) => p.kuriId == kuri.id && p.status == 'approved')
                        .toList();
                    final totalCollected = approvedPayments.fold<double>(
                        0, (sum, p) => sum + p.amount);

                    return AppCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => KuriDetailScreen(kuriId: kuri.id),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  kuri.name,
                                  style: const TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (kuri.createdBy == user.id)
                                const StatusBadge(label: 'Creator', color: primaryColor),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _InfoChip(
                                icon: Icons.currency_rupee,
                                label: '${kuri.contributionAmount.toInt()}/mo',
                              ),
                              const SizedBox(width: 8),
                              _InfoChip(
                                icon: Icons.people_outline,
                                label: '${kuri.participantUserIds.length} participants',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Started: ${formatDate(kuri.startDate)}',
                                style: const TextStyle(color: textDim, fontSize: 12),
                              ),
                              Text(
                                'Collected: ₹${totalCollected.toInt()}',
                                style: const TextStyle(color: greenColor, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showAppBottomSheet(context, const CreateKuriSheet()),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textMuted),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
