import 'dart:math';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import '../models.dart';
import 'auth_service.dart';

// Generates "YYYY-MM" keys from startDate up to (and including) current month.
List<String> _elapsedMonths(String startDateStr) {
  final months = <String>[];
  try {
    final start = DateTime.parse(startDateStr);
    final now = DateTime.now();
    var cur = DateTime(start.year, start.month);
    final end = DateTime(now.year, now.month);
    while (!cur.isAfter(end)) {
      months.add('${cur.year}-${cur.month.toString().padLeft(2, '0')}');
      cur = DateTime(cur.year, cur.month + 1);
    }
  } catch (_) {}
  return months;
}

String makeId(String prefix) {
  final rand = Random.secure();
  final bytes = List.generate(3, (_) => rand.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '$prefix-$hex';
}

String makeInviteCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random.secure();
  return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
}

String nowIso() => DateTime.now().toUtc().toIso8601String();

String _monthLabel(String month) {
  try {
    final p = month.split('-');
    const names = ['', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
    return '${names[int.parse(p[1])]} ${p[0]}';
  } catch (_) {
    return month;
  }
}

class DataService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref('appData');

  Future<AppData> getData() async {
    final snapshot = await _ref.get();
    if (!snapshot.exists || snapshot.value == null) {
      return AppData.empty();
    }
    final raw = snapshot.value;
    if (raw is Map) {
      return AppData.fromJson(Map<dynamic, dynamic>.from(raw));
    }
    return AppData.empty();
  }

  Future<void> saveData(AppData data) async {
    await _ref.set(data.toJson());
  }

  Future<AppUser> createUser(String name, String email) async {
    final data = await getData();
    final cleaned = email.trim().toLowerCase();
    final existing = data.users.firstWhere(
      (u) => u.email.trim().toLowerCase() == cleaned,
      orElse: () => AppUser(id: '', name: '', email: ''),
    );
    if (existing.id.isNotEmpty) return existing;

    final user = AppUser(
      id: makeId('usr'),
      name: name.trim(),
      email: cleaned,
    );
    final newData = data.copyWith(users: [...data.users, user]);
    await saveData(newData);
    return user;
  }

  Future<Group> createGroup(
    String groupName,
    String adminUserId,
    List<String> initialMemberEmails,
    String description,
  ) async {
    final data = await getData();
    final now = nowIso();
    final group = Group(
      id: makeId('grp'),
      name: groupName.trim(),
      description: description.trim(),
      createdBy: adminUserId,
      createdAt: now,
      members: [GroupMember(userId: adminUserId, role: 'admin', joinedAt: now)],
    );

    final invitations = List<Invitation>.from(data.invitations);
    for (final rawEmail in initialMemberEmails) {
      final email = rawEmail.trim().toLowerCase();
      if (email.isEmpty) continue;
      final invitation = Invitation(
        id: makeId('inv'),
        groupId: group.id,
        invitedBy: adminUserId,
        inviteeName: email.split('@')[0],
        inviteeEmail: email,
        inviteCode: makeInviteCode(),
        status: 'pending',
        createdAt: now,
      );
      invitations.add(invitation);
    }

    final newData = data.copyWith(
      groups: [...data.groups, group],
      invitations: invitations,
    );
    await saveData(newData);
    return group;
  }

  Future<({Group group, AppUser user})> joinGroupByInviteCode(
    String inviteCode,
    String userName,
    String userEmail,
  ) async {
    final data = await getData();
    final code = inviteCode.trim().toUpperCase();
    final invIdx = data.invitations.indexWhere(
      (inv) => inv.inviteCode == code && inv.status == 'pending',
    );
    if (invIdx < 0) throw Exception('Invalid or already used invite code.');

    final invitation = data.invitations[invIdx];
    final groupIdx = data.groups.indexWhere((g) => g.id == invitation.groupId);
    if (groupIdx < 0) throw Exception('Group not found.');

    final group = data.groups[groupIdx];
    final cleaned = userEmail.trim().toLowerCase();

    AppUser user;
    final existingIdx = data.users.indexWhere(
      (u) => u.email.trim().toLowerCase() == cleaned,
    );
    List<AppUser> updatedUsers = List.from(data.users);
    if (existingIdx >= 0) {
      user = data.users[existingIdx];
    } else {
      user = AppUser(id: makeId('usr'), name: userName.trim(), email: cleaned);
      updatedUsers.add(user);
    }

    final alreadyMember = group.members.any((m) => m.userId == user.id);
    final updatedMembers = List<GroupMember>.from(group.members);
    if (!alreadyMember) {
      updatedMembers.add(GroupMember(userId: user.id, role: 'member', joinedAt: nowIso()));
    }

    final updatedGroup = group.copyWith(members: updatedMembers);
    final updatedGroups = List<Group>.from(data.groups);
    updatedGroups[groupIdx] = updatedGroup;

    final updatedInvitations = List<Invitation>.from(data.invitations);
    updatedInvitations[invIdx] = Invitation(
      id: invitation.id,
      groupId: invitation.groupId,
      invitedBy: invitation.invitedBy,
      inviteeName: invitation.inviteeName,
      inviteeEmail: invitation.inviteeEmail,
      inviteCode: invitation.inviteCode,
      status: 'accepted',
      createdAt: invitation.createdAt,
      acceptedAt: nowIso(),
      acceptedByUserId: user.id,
    );

    await saveData(data.copyWith(
      users: updatedUsers,
      groups: updatedGroups,
      invitations: updatedInvitations,
    ));
    return (group: updatedGroup, user: user);
  }

  Future<Invitation> addMemberByEmail(
    String groupId,
    String actorId,
    String email,
  ) async {
    final data = await getData();
    final groupIdx = data.groups.indexWhere((g) => g.id == groupId);
    if (groupIdx < 0) throw Exception('Committee not found.');
    final group = data.groups[groupIdx];
    if (group.createdBy != actorId) throw Exception('Only committee admin can add members.');

    final cleaned = email.trim().toLowerCase();
    if (cleaned.isEmpty) throw Exception('Email is required.');

    final existingUser = data.users.firstWhere(
      (u) => u.email == cleaned,
      orElse: () => AppUser(id: '', name: '', email: ''),
    );
    if (existingUser.id.isNotEmpty && group.members.any((m) => m.userId == existingUser.id)) {
      throw Exception('User is already a member.');
    }
    if (data.invitations.any((i) =>
        i.groupId == groupId && i.inviteeEmail == cleaned && i.status == 'pending')) {
      throw Exception('An invitation has already been sent to this email.');
    }

    final invitation = Invitation(
      id: makeId('inv'),
      groupId: groupId,
      invitedBy: actorId,
      inviteeName: cleaned.split('@')[0],
      inviteeEmail: cleaned,
      inviteCode: makeInviteCode(),
      status: 'pending',
      createdAt: nowIso(),
    );
    await saveData(data.copyWith(invitations: [...data.invitations, invitation]));
    return invitation;
  }

  Future<Group> removeMember(String groupId, String actorId, String memberId) async {
    final data = await getData();
    final groupIdx = data.groups.indexWhere((g) => g.id == groupId);
    if (groupIdx < 0) throw Exception('Committee not found.');
    final group = data.groups[groupIdx];
    if (group.createdBy != actorId) throw Exception('Only committee admin can remove members.');
    if (group.createdBy == memberId) throw Exception('Admin cannot be removed.');

    final updatedGroup = group.copyWith(
      members: group.members.where((m) => m.userId != memberId).toList(),
    );
    final updatedGroups = List<Group>.from(data.groups);
    updatedGroups[groupIdx] = updatedGroup;
    await saveData(data.copyWith(groups: updatedGroups));
    return updatedGroup;
  }

  Future<ChatMessage> sendGroupMessage(
    String groupId,
    String senderUserId,
    String text,
  ) async {
    final data = await getData();
    final group = data.groups.firstWhere(
      (g) => g.id == groupId,
      orElse: () => Group(id: '', name: '', createdBy: '', members: [], createdAt: ''),
    );
    if (group.id.isEmpty) throw Exception('Group not found.');

    final user = data.users.firstWhere(
      (u) => u.id == senderUserId,
      orElse: () => AppUser(id: '', name: '', email: ''),
    );
    if (user.id.isEmpty) throw Exception('User not found.');

    if (!group.members.any((m) => m.userId == senderUserId)) {
      throw Exception('Only members can chat.');
    }

    final msg = ChatMessage(
      id: makeId('msg'),
      groupId: groupId,
      senderUserId: senderUserId,
      senderName: user.name,
      text: text.trim(),
      createdAt: nowIso(),
    );
    await saveData(data.copyWith(chatMessages: [...data.chatMessages, msg]));
    return msg;
  }

  Future<KuriPlan> createKuri({
    required String name,
    required double amount,
    required String currency,
    required String startDate,
    required List<String> participantIds,
    String upiId = '',
    String? qrBase64,
    required String createdBy,
    String kuriType = 'lelam',
    double moopanCommissionPercent = 5.0,
    double maxDiscountPercent = 30.0,
    int prizePaidWithinDays = 7,
  }) async {
    final data = await getData();

    final uniqueParticipants = participantIds.toSet().toList();
    if (!uniqueParticipants.contains(createdBy)) {
      uniqueParticipants.add(createdBy);
    }

    final kuri = KuriPlan(
      id: makeId('kuri'),
      groupId: null,
      name: name.trim(),
      contributionAmount: amount,
      currency: currency.toUpperCase(),
      startDate: startDate,
      participantUserIds: uniqueParticipants,
      notificationConfig: NotificationConfig(rules: [
        NotificationRule(channel: 'in_app', beforeDays: 3, emailRecipients: []),
      ]),
      createdBy: createdBy,
      createdAt: nowIso(),
      upiId: upiId.trim(),
      upiQrBase64: qrBase64,
      kuriType: kuriType,
      moopanCommissionPercent: moopanCommissionPercent,
      maxDiscountPercent: maxDiscountPercent,
      prizePaidWithinDays: prizePaidWithinDays,
    );
    final creator = data.users.firstWhere(
      (u) => u.id == createdBy,
      orElse: () => AppUser(id: '', name: 'Someone', email: ''),
    );
    final invitedIds = uniqueParticipants.where((id) => id != createdBy).toList();
    final inviteNotifs = invitedIds
        .map((id) => InAppNotification(
              id: makeId('notif'),
              kuriId: kuri.id,
              userId: id,
              title: 'Added to Kuri',
              message: 'You have been added to "${kuri.name}"',
              createdAt: nowIso(),
              read: false,
            ))
        .toList();
    await saveData(data.copyWith(
      kuris: [...data.kuris, kuri],
      notifications: [...data.notifications, ...inviteNotifs],
    ));
    // Send invite emails — fire and forget (don't fail Kuri creation if email fails)
    for (final id in invitedIds) {
      final user = data.users.firstWhere((u) => u.id == id, orElse: () => AppUser(id: '', name: '', email: ''));
      if (user.email.isNotEmpty) {
        AuthService.sendKuriInviteEmail(
          to: user.email,
          kuriName: kuri.name,
          inviterName: creator.name,
          monthlyAmount: kuri.contributionAmount,
        ).catchError((_) {});
      }
    }
    // Auto-approve creator's contributions for all elapsed months
    await ensureCreatorPayments(kuri.id);
    return kuri;
  }

  Future<KuriPlan> updateKuriParticipants(
    String kuriId,
    String actorId,
    List<String> participantIds,
  ) async {
    final data = await getData();
    final idx = data.kuris.indexWhere((k) => k.id == kuriId);
    if (idx < 0) throw Exception('Kuri plan not found.');
    final kuri = data.kuris[idx];
    if (kuri.createdBy != actorId) throw Exception('Only the creator can manage participants.');
    final previousIds = kuri.participantUserIds.toSet();
    final unique = participantIds.toSet().toList();
    if (!unique.contains(actorId)) unique.add(actorId);
    final updated = kuri.copyWith(participantUserIds: unique);
    final updatedKuris = List<KuriPlan>.from(data.kuris);
    updatedKuris[idx] = updated;
    final actor = data.users.firstWhere(
      (u) => u.id == actorId,
      orElse: () => AppUser(id: '', name: 'Someone', email: ''),
    );
    final newlyAdded = unique.where((id) => !previousIds.contains(id) && id != actorId).toList();
    final inviteNotifs = newlyAdded
        .map((id) => InAppNotification(
              id: makeId('notif'),
              kuriId: kuriId,
              userId: id,
              title: 'Added to Kuri',
              message: 'You have been added to "${kuri.name}"',
              createdAt: nowIso(),
              read: false,
            ))
        .toList();
    await saveData(data.copyWith(
      kuris: updatedKuris,
      notifications: [...data.notifications, ...inviteNotifs],
    ));
    // Send invite emails — fire and forget
    for (final id in newlyAdded) {
      final user = data.users.firstWhere((u) => u.id == id, orElse: () => AppUser(id: '', name: '', email: ''));
      if (user.email.isNotEmpty) {
        AuthService.sendKuriInviteEmail(
          to: user.email,
          kuriName: kuri.name,
          inviterName: actor.name,
          monthlyAmount: kuri.contributionAmount,
        ).catchError((_) {});
      }
    }
    return updated;
  }

  Future<KuriAuction> openAuction(String kuriId, String month, String actorId) async {
    final data = await getData();
    final kuri = data.kuris.firstWhere((k) => k.id == kuriId,
        orElse: () => KuriPlan(id: '', name: '', contributionAmount: 0, currency: 'INR', startDate: '', participantUserIds: [], notificationConfig: NotificationConfig(rules: []), createdBy: '', createdAt: ''));
    if (kuri.id.isEmpty) throw Exception('Kuri not found.');
    if (kuri.createdBy != actorId) throw Exception('Only the Moopan can open an auction.');
    if (data.auctions.any((a) => a.kuriId == kuriId && a.month == month && a.status == 'open')) {
      throw Exception('An auction is already open for this month.');
    }
    if (data.auctions.any((a) => a.kuriId == kuriId && a.month == month && a.status == 'closed')) {
      throw Exception('Winner already declared for this month.');
    }
    final auction = KuriAuction(
      id: makeId('auc'),
      kuriId: kuriId,
      month: month,
      status: 'open',
      bids: [],
      createdAt: nowIso(),
    );
    final notifs = kuri.participantUserIds
        .where((id) => id != actorId)
        .map((id) => InAppNotification(
              id: makeId('notif'),
              kuriId: kuriId,
              userId: id,
              title: 'Auction Open',
              message: 'Auction is open for $month in "${kuri.name}". Place your bid!',
              createdAt: nowIso(),
              read: false,
            ))
        .toList();
    await saveData(data.copyWith(
      auctions: [...data.auctions, auction],
      notifications: [...data.notifications, ...notifs],
    ));
    return auction;
  }

  Future<KuriAuction> placeBid(String auctionId, String userId, double discountAmount) async {
    final data = await getData();
    final idx = data.auctions.indexWhere((a) => a.id == auctionId);
    if (idx < 0) throw Exception('Auction not found.');
    final auction = data.auctions[idx];
    if (auction.status != 'open') throw Exception('Auction is not open.');
    final kuri = data.kuris.firstWhere((k) => k.id == auction.kuriId,
        orElse: () => KuriPlan(id: '', name: '', contributionAmount: 0, currency: 'INR', startDate: '', participantUserIds: [], notificationConfig: NotificationConfig(rules: []), createdBy: '', createdAt: ''));
    if (kuri.id.isEmpty) throw Exception('Kuri not found.');
    final alreadyWon = data.auctions.any((a) =>
        a.kuriId == auction.kuriId && a.status == 'closed' && a.winnerId == userId);
    if (alreadyWon) throw Exception('You have already won an auction in this Kuri.');
    final maxDiscount = kuri.contributionAmount * kuri.participantUserIds.length * kuri.maxDiscountPercent / 100;
    if (discountAmount > maxDiscount) {
      throw Exception('Bid of ₹${discountAmount.toInt()} exceeds max allowed ₹${maxDiscount.toInt()}.');
    }
    if (discountAmount <= 0) throw Exception('Bid must be greater than zero.');
    final updatedBids = [...auction.bids.where((b) => b.userId != userId),
      AuctionBid(userId: userId, discountAmount: discountAmount, bidAt: nowIso())];
    final updatedAuctions = List<KuriAuction>.from(data.auctions);
    updatedAuctions[idx] = auction.copyWith(bids: updatedBids);
    await saveData(data.copyWith(auctions: updatedAuctions));
    return updatedAuctions[idx];
  }

  Future<KuriAuction> closeAuction(String auctionId, String actorId) async {
    final data = await getData();
    final idx = data.auctions.indexWhere((a) => a.id == auctionId);
    if (idx < 0) throw Exception('Auction not found.');
    final auction = data.auctions[idx];
    if (auction.status != 'open') throw Exception('Auction is not open.');
    final kuri = data.kuris.firstWhere((k) => k.id == auction.kuriId,
        orElse: () => KuriPlan(id: '', name: '', contributionAmount: 0, currency: 'INR', startDate: '', participantUserIds: [], notificationConfig: NotificationConfig(rules: []), createdBy: '', createdAt: ''));
    if (kuri.id.isEmpty) throw Exception('Kuri not found.');
    if (kuri.createdBy != actorId) throw Exception('Only the Moopan can close an auction.');
    if (auction.bids.isEmpty) throw Exception('No bids have been placed yet.');
    final sortedBids = [...auction.bids]..sort((a, b) => b.discountAmount.compareTo(a.discountAmount));
    final winner = sortedBids.first;
    final pool = kuri.contributionAmount * kuri.participantUserIds.length;
    final commission = pool * kuri.moopanCommissionPercent / 100;
    final prizeAmount = pool - winner.discountAmount - commission;
    final numOthers = kuri.participantUserIds.length - 1;
    final dividend = numOthers > 0 ? winner.discountAmount / numOthers : 0.0;
    final updated = auction.copyWith(
      status: 'closed',
      winnerId: winner.userId,
      winningDiscount: winner.discountAmount,
      prizeAmount: prizeAmount,
      dividendPerMember: dividend,
      closedAt: nowIso(),
    );
    final updatedAuctions = List<KuriAuction>.from(data.auctions);
    updatedAuctions[idx] = updated;
    final winnerUser = data.users.firstWhere((u) => u.id == winner.userId, orElse: () => AppUser(id: '', name: 'Someone', email: ''));
    final notifWinner = InAppNotification(
      id: makeId('notif'),
      kuriId: kuri.id,
      userId: winner.userId,
      title: 'You won the auction!',
      message: 'You won the ${ _monthLabel(auction.month)} auction for "${kuri.name}". Prize: ₹${prizeAmount.toInt()}',
      createdAt: nowIso(),
      read: false,
    );
    final otherNotifs = kuri.participantUserIds
        .where((id) => id != winner.userId && id != actorId)
        .map((id) => InAppNotification(
              id: makeId('notif'),
              kuriId: kuri.id,
              userId: id,
              title: 'Auction result',
              message: '${winnerUser.name} won the ${_monthLabel(auction.month)} auction. Your dividend: ₹${dividend.toStringAsFixed(2)}',
              createdAt: nowIso(),
              read: false,
            ))
        .toList();
    await saveData(data.copyWith(
      auctions: updatedAuctions,
      notifications: [...data.notifications, notifWinner, ...otherNotifs],
    ));
    return updated;
  }

  Future<KuriAuction> declareChangathaWinner(
      String kuriId, String month, String actorId, String winnerId) async {
    final data = await getData();
    final kuri = data.kuris.firstWhere((k) => k.id == kuriId,
        orElse: () => KuriPlan(id: '', name: '', contributionAmount: 0, currency: 'INR', startDate: '', participantUserIds: [], notificationConfig: NotificationConfig(rules: []), createdBy: '', createdAt: ''));
    if (kuri.id.isEmpty) throw Exception('Kuri not found.');
    if (kuri.createdBy != actorId) throw Exception('Only the Moopan can declare winners.');
    if (data.auctions.any((a) => a.kuriId == kuriId && a.month == month && a.status == 'closed')) {
      throw Exception('Winner already declared for this month.');
    }
    final alreadyWon = data.auctions.any((a) =>
        a.kuriId == kuriId && a.status == 'closed' && a.winnerId == winnerId);
    if (alreadyWon) throw Exception('This participant has already won a previous month.');
    final pool = kuri.contributionAmount * kuri.participantUserIds.length;
    final commission = pool * kuri.moopanCommissionPercent / 100;
    final prizeAmount = pool - commission;
    final auction = KuriAuction(
      id: makeId('auc'),
      kuriId: kuriId,
      month: month,
      status: 'closed',
      bids: [],
      winnerId: winnerId,
      winningDiscount: 0,
      prizeAmount: prizeAmount,
      dividendPerMember: 0,
      createdAt: nowIso(),
      closedAt: nowIso(),
    );
    final winnerUser = data.users.firstWhere((u) => u.id == winnerId, orElse: () => AppUser(id: '', name: 'Someone', email: ''));
    final notifWinner = InAppNotification(
      id: makeId('notif'),
      kuriId: kuri.id,
      userId: winnerId,
      title: 'You won the draw!',
      message: 'You were drawn as winner for ${_monthLabel(month)} in "${kuri.name}". Prize: ₹${prizeAmount.toInt()}',
      createdAt: nowIso(),
      read: false,
    );
    final otherNotifs = kuri.participantUserIds
        .where((id) => id != winnerId)
        .map((id) => InAppNotification(
              id: makeId('notif'),
              kuriId: kuri.id,
              userId: id,
              title: 'Draw result',
              message: '${winnerUser.name} was drawn as winner for ${_monthLabel(month)} in "${kuri.name}"',
              createdAt: nowIso(),
              read: false,
            ))
        .toList();
    await saveData(data.copyWith(
      auctions: [...data.auctions, auction],
      notifications: [...data.notifications, notifWinner, ...otherNotifs],
    ));
    return auction;
  }

  Future<void> deleteAccount(String userId) async {
    final data = await getData();
    final updatedKuris = data.kuris.map((k) {
      if (!k.participantUserIds.contains(userId)) return k;
      return k.copyWith(
        participantUserIds: k.participantUserIds.where((id) => id != userId).toList(),
      );
    }).toList();
    await saveData(data.copyWith(
      users: data.users.where((u) => u.id != userId).toList(),
      notifications: data.notifications.where((n) => n.userId != userId).toList(),
      payments: data.payments.where((p) => p.userId != userId).toList(),
      kuris: updatedKuris,
    ));
  }

  Future<void> deleteKuri(String kuriId, String actorId) async {
    final data = await getData();
    final kuri = data.kuris.firstWhere(
      (k) => k.id == kuriId,
      orElse: () => KuriPlan(
        id: '',
        name: '',
        contributionAmount: 0,
        currency: 'INR',
        startDate: '',
        participantUserIds: [],
        notificationConfig: NotificationConfig(rules: []),
        createdBy: '',
        createdAt: '',
      ),
    );
    if (kuri.id.isEmpty) throw Exception('Kuri plan not found.');
    if (kuri.createdBy != actorId) throw Exception('Only the creator can delete a Kuri plan.');

    await saveData(data.copyWith(
      kuris: data.kuris.where((k) => k.id != kuriId).toList(),
      payments: data.payments.where((p) => p.kuriId != kuriId).toList(),
    ));
  }

  // Auto-create approved payments for the creator for each elapsed month.
  // Safe to call repeatedly — skips months that already have a payment record.
  Future<void> ensureCreatorPayments(String kuriId) async {
    final data = await getData();
    final idx = data.kuris.indexWhere((k) => k.id == kuriId);
    if (idx < 0) return;
    final kuri = data.kuris[idx];
    final months = _elapsedMonths(kuri.startDate);
    final existingMonths = data.payments
        .where((p) => p.kuriId == kuriId && p.userId == kuri.createdBy)
        .map((p) => p.month)
        .toSet();
    final newPayments = months
        .where((m) => !existingMonths.contains(m))
        .map((m) => KuriPayment(
              id: makeId('pay'),
              kuriId: kuriId,
              userId: kuri.createdBy,
              month: m,
              transactionId: 'CREATOR',
              amount: kuri.contributionAmount,
              status: 'approved',
              submittedAt: nowIso(),
            ))
        .toList();
    if (newPayments.isEmpty) return;
    await saveData(data.copyWith(payments: [...data.payments, ...newPayments]));
  }

  Future<KuriPlan> updateKuriPaymentInfo(
    String kuriId,
    String actorId,
    String upiId,
    String? qrBase64,
  ) async {
    final data = await getData();
    final idx = data.kuris.indexWhere((k) => k.id == kuriId);
    if (idx < 0) throw Exception('Kuri plan not found.');
    final kuri = data.kuris[idx];
    if (kuri.createdBy != actorId) throw Exception('Only the creator can update payment info.');

    final updated = kuri.copyWith(
      upiId: upiId.trim(),
      upiQrBase64: qrBase64 ?? kuri.upiQrBase64,
    );
    final updatedKuris = List<KuriPlan>.from(data.kuris);
    updatedKuris[idx] = updated;
    await saveData(data.copyWith(kuris: updatedKuris));
    return updated;
  }

  Future<KuriPlan> updateKuriSettings(
    String kuriId,
    String actorId, {
    required double moopanCommissionPercent,
    required double maxDiscountPercent,
    required int prizePaidWithinDays,
  }) async {
    final data = await getData();
    final idx = data.kuris.indexWhere((k) => k.id == kuriId);
    if (idx < 0) throw Exception('Kuri plan not found.');
    final kuri = data.kuris[idx];
    if (kuri.createdBy != actorId) throw Exception('Only the Moopan can update Kuri settings.');
    final updated = kuri.copyWith(
      moopanCommissionPercent: moopanCommissionPercent,
      maxDiscountPercent: maxDiscountPercent,
      prizePaidWithinDays: prizePaidWithinDays,
    );
    final updatedKuris = List<KuriPlan>.from(data.kuris);
    updatedKuris[idx] = updated;
    await saveData(data.copyWith(kuris: updatedKuris));
    return updated;
  }

  Future<KuriPayment> submitPayment({
    required String kuriId,
    required String userId,
    required String month,
    required String transactionId,
    required double amount,
    required String receiptBase64,
    required String receiptFileName,
  }) async {
    final data = await getData();
    final kuri = data.kuris.firstWhere(
      (k) => k.id == kuriId,
      orElse: () => KuriPlan(
        id: '',
        name: '',
        contributionAmount: 0,
        currency: 'INR',
        startDate: '',
        participantUserIds: [],
        notificationConfig: NotificationConfig(rules: []),
        createdBy: '',
        createdAt: '',
      ),
    );
    if (kuri.id.isEmpty) throw Exception('Kuri plan not found.');
    if (receiptBase64.isEmpty) throw Exception('Receipt is required.');
    if (transactionId.trim().isEmpty) throw Exception('Transaction ID is required.');

    final existing = data.payments.firstWhere(
      (p) => p.kuriId == kuriId && p.userId == userId && p.month == month,
      orElse: () => KuriPayment(
        id: '',
        kuriId: '',
        userId: '',
        month: '',
        transactionId: '',
        amount: 0,
        status: '',
        submittedAt: '',
      ),
    );
    if (existing.id.isNotEmpty && existing.status == 'approved') {
      throw Exception('Payment for this month is already approved.');
    }

    final payment = KuriPayment(
      id: makeId('pay'),
      kuriId: kuriId,
      userId: userId,
      month: month,
      transactionId: transactionId.trim().toUpperCase(),
      amount: amount,
      receiptBase64: receiptBase64,
      receiptFileName: receiptFileName,
      status: 'submitted',
      submittedAt: nowIso(),
    );

    List<KuriPayment> updatedPayments = data.payments
        .where((p) => !(p.kuriId == kuriId && p.userId == userId && p.month == month))
        .toList();
    updatedPayments.add(payment);
    await saveData(data.copyWith(payments: updatedPayments));
    return payment;
  }

  Future<KuriPayment> reviewPayment(
    String paymentId,
    String actorId,
    bool approved,
    String? notes,
  ) async {
    final data = await getData();
    final idx = data.payments.indexWhere((p) => p.id == paymentId);
    if (idx < 0) throw Exception('Payment not found.');
    final payment = data.payments[idx];

    final kuri = data.kuris.firstWhere(
      (k) => k.id == payment.kuriId,
      orElse: () => KuriPlan(
        id: '',
        name: '',
        contributionAmount: 0,
        currency: 'INR',
        startDate: '',
        participantUserIds: [],
        notificationConfig: NotificationConfig(rules: []),
        createdBy: '',
        createdAt: '',
      ),
    );
    if (kuri.id.isEmpty) throw Exception('Kuri plan not found.');
    if (kuri.createdBy != actorId) throw Exception('Only the Kuri creator can review payments.');

    final updated = payment.copyWith(
      status: approved ? 'approved' : 'rejected',
      reviewedAt: nowIso(),
      reviewedBy: actorId,
      notes: notes?.trim(),
    );
    final updatedPayments = List<KuriPayment>.from(data.payments);
    updatedPayments[idx] = updated;
    await saveData(data.copyWith(payments: updatedPayments));
    return updated;
  }

  // Encode bytes to base64 with data URI prefix
  static String encodeImageToBase64(List<int> bytes, String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    String mime = 'image/jpeg';
    if (ext == 'png') mime = 'image/png';
    if (ext == 'gif') mime = 'image/gif';
    if (ext == 'webp') mime = 'image/webp';
    final encoded = base64Encode(bytes);
    return 'data:$mime;base64,$encoded';
  }
}

final dataService = DataService();
