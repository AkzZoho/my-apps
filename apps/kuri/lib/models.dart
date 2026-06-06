class AppUser {
  final String id;
  final String name;
  final String email;

  AppUser({required this.id, required this.name, required this.email});

  factory AppUser.fromJson(Map<dynamic, dynamic> json) => AppUser(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};

  AppUser copyWith({String? id, String? name, String? email}) => AppUser(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
      );
}

class GroupMember {
  final String userId;
  final String role; // "admin" | "member"
  final String joinedAt;

  GroupMember({required this.userId, required this.role, required this.joinedAt});

  factory GroupMember.fromJson(Map<dynamic, dynamic> json) => GroupMember(
        userId: json['userId']?.toString() ?? '',
        role: json['role']?.toString() ?? 'member',
        joinedAt: json['joinedAt']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'userId': userId, 'role': role, 'joinedAt': joinedAt};
}

class Group {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final List<GroupMember> members;
  final String createdAt;

  Group({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    required this.members,
    required this.createdAt,
  });

  factory Group.fromJson(Map<dynamic, dynamic> json) {
    final rawMembers = json['members'];
    List<GroupMember> members = [];
    if (rawMembers is List) {
      members = rawMembers
          .where((m) => m != null)
          .map((m) => GroupMember.fromJson(Map<dynamic, dynamic>.from(m as Map)))
          .toList();
    } else if (rawMembers is Map) {
      members = rawMembers.values
          .where((m) => m != null)
          .map((m) => GroupMember.fromJson(Map<dynamic, dynamic>.from(m as Map)))
          .toList();
    }
    return Group(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      createdBy: json['createdBy']?.toString() ?? '',
      members: members,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'createdBy': createdBy,
        'members': members.map((m) => m.toJson()).toList(),
        'createdAt': createdAt,
      };

  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    List<GroupMember>? members,
    String? createdAt,
  }) =>
      Group(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        createdBy: createdBy ?? this.createdBy,
        members: members ?? this.members,
        createdAt: createdAt ?? this.createdAt,
      );
}

class Invitation {
  final String id;
  final String groupId;
  final String invitedBy;
  final String inviteeName;
  final String inviteeEmail;
  final String inviteCode;
  final String status; // "pending" | "accepted" | "expired"
  final String createdAt;
  final String? acceptedAt;
  final String? acceptedByUserId;

  Invitation({
    required this.id,
    required this.groupId,
    required this.invitedBy,
    required this.inviteeName,
    required this.inviteeEmail,
    required this.inviteCode,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.acceptedByUserId,
  });

  factory Invitation.fromJson(Map<dynamic, dynamic> json) => Invitation(
        id: json['id']?.toString() ?? '',
        groupId: json['groupId']?.toString() ?? '',
        invitedBy: json['invitedBy']?.toString() ?? '',
        inviteeName: json['inviteeName']?.toString() ?? '',
        inviteeEmail: json['inviteeEmail']?.toString() ?? '',
        inviteCode: json['inviteCode']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        createdAt: json['createdAt']?.toString() ?? '',
        acceptedAt: json['acceptedAt']?.toString(),
        acceptedByUserId: json['acceptedByUserId']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'invitedBy': invitedBy,
        'inviteeName': inviteeName,
        'inviteeEmail': inviteeEmail,
        'inviteCode': inviteCode,
        'status': status,
        'createdAt': createdAt,
        'acceptedAt': acceptedAt,
        'acceptedByUserId': acceptedByUserId,
      };
}

class NotificationRule {
  final String channel;
  final int beforeDays;
  final List<String> emailRecipients;

  NotificationRule({
    required this.channel,
    required this.beforeDays,
    required this.emailRecipients,
  });

  factory NotificationRule.fromJson(Map<dynamic, dynamic> json) {
    final recs = json['emailRecipients'];
    List<String> recipients = [];
    if (recs is List) {
      recipients = recs.map((e) => e.toString()).toList();
    }
    return NotificationRule(
      channel: json['channel']?.toString() ?? 'in_app',
      beforeDays: (json['beforeDays'] as num?)?.toInt() ?? 0,
      emailRecipients: recipients,
    );
  }

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'beforeDays': beforeDays,
        'emailRecipients': emailRecipients,
      };
}

class NotificationConfig {
  final List<NotificationRule> rules;

  NotificationConfig({required this.rules});

  factory NotificationConfig.fromJson(Map<dynamic, dynamic> json) {
    final rawRules = json['rules'];
    List<NotificationRule> rules = [];
    if (rawRules is List) {
      rules = rawRules
          .where((r) => r != null)
          .map((r) => NotificationRule.fromJson(Map<dynamic, dynamic>.from(r as Map)))
          .toList();
    }
    return NotificationConfig(rules: rules);
  }

  Map<String, dynamic> toJson() => {
        'rules': rules.map((r) => r.toJson()).toList(),
      };
}

class KuriPlan {
  final String id;
  final String? groupId;
  final String name;
  final double contributionAmount;
  final String currency;
  final String startDate;
  final List<String> participantUserIds;
  final NotificationConfig notificationConfig;
  final String createdBy;
  final String createdAt;
  final String? upiId;
  final String? upiQrBase64;
  final String kuriType; // 'lelam' | 'changatha'
  final double moopanCommissionPercent;
  final double maxDiscountPercent;
  final int prizePaidWithinDays;

  KuriPlan({
    required this.id,
    this.groupId,
    required this.name,
    required this.contributionAmount,
    required this.currency,
    required this.startDate,
    required this.participantUserIds,
    required this.notificationConfig,
    required this.createdBy,
    required this.createdAt,
    this.upiId,
    this.upiQrBase64,
    this.kuriType = 'lelam',
    this.moopanCommissionPercent = 5.0,
    this.maxDiscountPercent = 30.0,
    this.prizePaidWithinDays = 7,
  });

  factory KuriPlan.fromJson(Map<dynamic, dynamic> json) {
    final rawParticipants = json['participantUserIds'];
    List<String> participants = [];
    if (rawParticipants is List) {
      participants = rawParticipants.map((e) => e.toString()).toList();
    } else if (rawParticipants is Map) {
      participants = rawParticipants.values.map((e) => e.toString()).toList();
    }

    final rawNotifConfig = json['notificationConfig'];
    NotificationConfig notifConfig = NotificationConfig(rules: []);
    if (rawNotifConfig is Map) {
      notifConfig = NotificationConfig.fromJson(Map<dynamic, dynamic>.from(rawNotifConfig));
    }

    return KuriPlan(
      id: json['id']?.toString() ?? '',
      groupId: json['groupId']?.toString(),
      name: json['name']?.toString() ?? '',
      contributionAmount: (json['contributionAmount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      startDate: json['startDate']?.toString() ?? '',
      participantUserIds: participants,
      notificationConfig: notifConfig,
      createdBy: json['createdBy']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      upiId: json['upiId']?.toString(),
      upiQrBase64: json['upiQrBase64']?.toString(),
      kuriType: json['kuriType']?.toString() ?? 'lelam',
      moopanCommissionPercent: (json['moopanCommissionPercent'] as num?)?.toDouble() ?? 5.0,
      maxDiscountPercent: (json['maxDiscountPercent'] as num?)?.toDouble() ?? 30.0,
      prizePaidWithinDays: (json['prizePaidWithinDays'] as num?)?.toInt() ?? 7,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'name': name,
        'contributionAmount': contributionAmount,
        'currency': currency,
        'startDate': startDate,
        'participantUserIds': participantUserIds,
        'notificationConfig': notificationConfig.toJson(),
        'createdBy': createdBy,
        'createdAt': createdAt,
        'upiId': upiId,
        'upiQrBase64': upiQrBase64,
        'kuriType': kuriType,
        'moopanCommissionPercent': moopanCommissionPercent,
        'maxDiscountPercent': maxDiscountPercent,
        'prizePaidWithinDays': prizePaidWithinDays,
      };

  KuriPlan copyWith({
    String? id,
    String? groupId,
    String? name,
    double? contributionAmount,
    String? currency,
    String? startDate,
    List<String>? participantUserIds,
    NotificationConfig? notificationConfig,
    String? createdBy,
    String? createdAt,
    String? upiId,
    String? upiQrBase64,
    String? kuriType,
    double? moopanCommissionPercent,
    double? maxDiscountPercent,
    int? prizePaidWithinDays,
  }) =>
      KuriPlan(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        name: name ?? this.name,
        contributionAmount: contributionAmount ?? this.contributionAmount,
        currency: currency ?? this.currency,
        startDate: startDate ?? this.startDate,
        participantUserIds: participantUserIds ?? this.participantUserIds,
        notificationConfig: notificationConfig ?? this.notificationConfig,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        upiId: upiId ?? this.upiId,
        upiQrBase64: upiQrBase64 ?? this.upiQrBase64,
        kuriType: kuriType ?? this.kuriType,
        moopanCommissionPercent: moopanCommissionPercent ?? this.moopanCommissionPercent,
        maxDiscountPercent: maxDiscountPercent ?? this.maxDiscountPercent,
        prizePaidWithinDays: prizePaidWithinDays ?? this.prizePaidWithinDays,
      );
}

class KuriPayment {
  final String id;
  final String kuriId;
  final String userId;
  final String month;
  final String transactionId;
  final double amount;
  final String? receiptBase64;
  final String? receiptFileName;
  final String status; // "submitted" | "approved" | "rejected"
  final String submittedAt;
  final String? reviewedAt;
  final String? reviewedBy;
  final String? notes;

  KuriPayment({
    required this.id,
    required this.kuriId,
    required this.userId,
    required this.month,
    required this.transactionId,
    required this.amount,
    this.receiptBase64,
    this.receiptFileName,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.notes,
  });

  factory KuriPayment.fromJson(Map<dynamic, dynamic> json) => KuriPayment(
        id: json['id']?.toString() ?? '',
        kuriId: json['kuriId']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        month: json['month']?.toString() ?? '',
        transactionId: json['transactionId']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        receiptBase64: json['receiptBase64']?.toString(),
        receiptFileName: json['receiptFileName']?.toString(),
        status: json['status']?.toString() ?? 'submitted',
        submittedAt: json['submittedAt']?.toString() ?? '',
        reviewedAt: json['reviewedAt']?.toString(),
        reviewedBy: json['reviewedBy']?.toString(),
        notes: json['notes']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kuriId': kuriId,
        'userId': userId,
        'month': month,
        'transactionId': transactionId,
        'amount': amount,
        'receiptBase64': receiptBase64,
        'receiptFileName': receiptFileName,
        'status': status,
        'submittedAt': submittedAt,
        'reviewedAt': reviewedAt,
        'reviewedBy': reviewedBy,
        'notes': notes,
      };

  KuriPayment copyWith({
    String? id,
    String? kuriId,
    String? userId,
    String? month,
    String? transactionId,
    double? amount,
    String? receiptBase64,
    String? receiptFileName,
    String? status,
    String? submittedAt,
    String? reviewedAt,
    String? reviewedBy,
    String? notes,
  }) =>
      KuriPayment(
        id: id ?? this.id,
        kuriId: kuriId ?? this.kuriId,
        userId: userId ?? this.userId,
        month: month ?? this.month,
        transactionId: transactionId ?? this.transactionId,
        amount: amount ?? this.amount,
        receiptBase64: receiptBase64 ?? this.receiptBase64,
        receiptFileName: receiptFileName ?? this.receiptFileName,
        status: status ?? this.status,
        submittedAt: submittedAt ?? this.submittedAt,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        reviewedBy: reviewedBy ?? this.reviewedBy,
        notes: notes ?? this.notes,
      );
}

class ChatMessage {
  final String id;
  final String groupId;
  final String senderUserId;
  final String senderName;
  final String text;
  final String createdAt;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderUserId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<dynamic, dynamic> json) => ChatMessage(
        id: json['id']?.toString() ?? '',
        groupId: json['groupId']?.toString() ?? '',
        senderUserId: json['senderUserId']?.toString() ?? '',
        senderName: json['senderName']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
        createdAt: json['createdAt']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'senderUserId': senderUserId,
        'senderName': senderName,
        'text': text,
        'createdAt': createdAt,
      };
}

class InAppNotification {
  final String id;
  final String? groupId;
  final String? kuriId;
  final String userId;
  final String title;
  final String message;
  final String createdAt;
  final bool read;

  InAppNotification({
    required this.id,
    this.groupId,
    this.kuriId,
    required this.userId,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.read,
  });

  factory InAppNotification.fromJson(Map<dynamic, dynamic> json) => InAppNotification(
        id: json['id']?.toString() ?? '',
        groupId: json['groupId']?.toString(),
        kuriId: json['kuriId']?.toString(),
        userId: json['userId']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        createdAt: json['createdAt']?.toString() ?? '',
        read: json['read'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'kuriId': kuriId,
        'userId': userId,
        'title': title,
        'message': message,
        'createdAt': createdAt,
        'read': read,
      };
}

// ─── Auction Models ───────────────────────────────────────────────────────────

class AuctionBid {
  final String userId;
  final double discountAmount;
  final String bidAt;

  AuctionBid({required this.userId, required this.discountAmount, required this.bidAt});

  factory AuctionBid.fromJson(Map<dynamic, dynamic> json) => AuctionBid(
        userId: json['userId']?.toString() ?? '',
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
        bidAt: json['bidAt']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'discountAmount': discountAmount,
        'bidAt': bidAt,
      };

  AuctionBid copyWith({String? userId, double? discountAmount, String? bidAt}) =>
      AuctionBid(
        userId: userId ?? this.userId,
        discountAmount: discountAmount ?? this.discountAmount,
        bidAt: bidAt ?? this.bidAt,
      );
}

class KuriAuction {
  final String id;
  final String kuriId;
  final String month; // 'YYYY-MM'
  final String status; // 'open' | 'closed'
  final List<AuctionBid> bids;
  final String? winnerId;
  final double? winningDiscount;
  final double? prizeAmount;
  final double? dividendPerMember;
  final String createdAt;
  final String? closedAt;

  KuriAuction({
    required this.id,
    required this.kuriId,
    required this.month,
    required this.status,
    required this.bids,
    this.winnerId,
    this.winningDiscount,
    this.prizeAmount,
    this.dividendPerMember,
    required this.createdAt,
    this.closedAt,
  });

  factory KuriAuction.fromJson(Map<dynamic, dynamic> json) {
    final rawBids = json['bids'];
    List<AuctionBid> bids = [];
    if (rawBids is List) {
      bids = rawBids
          .where((b) => b != null)
          .map((b) => AuctionBid.fromJson(Map<dynamic, dynamic>.from(b as Map)))
          .toList();
    } else if (rawBids is Map) {
      bids = rawBids.values
          .where((b) => b != null)
          .map((b) => AuctionBid.fromJson(Map<dynamic, dynamic>.from(b as Map)))
          .toList();
    }
    return KuriAuction(
      id: json['id']?.toString() ?? '',
      kuriId: json['kuriId']?.toString() ?? '',
      month: json['month']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      bids: bids,
      winnerId: json['winnerId']?.toString(),
      winningDiscount: (json['winningDiscount'] as num?)?.toDouble(),
      prizeAmount: (json['prizeAmount'] as num?)?.toDouble(),
      dividendPerMember: (json['dividendPerMember'] as num?)?.toDouble(),
      createdAt: json['createdAt']?.toString() ?? '',
      closedAt: json['closedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kuriId': kuriId,
        'month': month,
        'status': status,
        'bids': bids.map((b) => b.toJson()).toList(),
        'winnerId': winnerId,
        'winningDiscount': winningDiscount,
        'prizeAmount': prizeAmount,
        'dividendPerMember': dividendPerMember,
        'createdAt': createdAt,
        'closedAt': closedAt,
      };

  KuriAuction copyWith({
    String? id,
    String? kuriId,
    String? month,
    String? status,
    List<AuctionBid>? bids,
    String? winnerId,
    double? winningDiscount,
    double? prizeAmount,
    double? dividendPerMember,
    String? createdAt,
    String? closedAt,
  }) =>
      KuriAuction(
        id: id ?? this.id,
        kuriId: kuriId ?? this.kuriId,
        month: month ?? this.month,
        status: status ?? this.status,
        bids: bids ?? this.bids,
        winnerId: winnerId ?? this.winnerId,
        winningDiscount: winningDiscount ?? this.winningDiscount,
        prizeAmount: prizeAmount ?? this.prizeAmount,
        dividendPerMember: dividendPerMember ?? this.dividendPerMember,
        createdAt: createdAt ?? this.createdAt,
        closedAt: closedAt ?? this.closedAt,
      );
}

// ─── AppData ──────────────────────────────────────────────────────────────────

class AppData {
  final List<AppUser> users;
  final List<Group> groups;
  final List<Invitation> invitations;
  final List<KuriPlan> kuris;
  final List<KuriPayment> payments;
  final List<ChatMessage> chatMessages;
  final List<InAppNotification> notifications;
  final List<KuriAuction> auctions;

  AppData({
    required this.users,
    required this.groups,
    required this.invitations,
    required this.kuris,
    required this.payments,
    required this.chatMessages,
    required this.notifications,
    required this.auctions,
  });

  factory AppData.empty() => AppData(
        users: [],
        groups: [],
        invitations: [],
        kuris: [],
        payments: [],
        chatMessages: [],
        notifications: [],
        auctions: [],
      );

  factory AppData.fromJson(Map<dynamic, dynamic> json) {
    List<T> parseList<T>(dynamic raw, T Function(Map<dynamic, dynamic>) fromJson) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .where((e) => e != null)
            .map((e) => fromJson(Map<dynamic, dynamic>.from(e as Map)))
            .toList();
      }
      if (raw is Map) {
        return raw.values
            .where((e) => e != null)
            .map((e) => fromJson(Map<dynamic, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    }

    return AppData(
      users: parseList(json['users'], AppUser.fromJson),
      groups: parseList(json['groups'], Group.fromJson),
      invitations: parseList(json['invitations'], Invitation.fromJson),
      kuris: parseList(json['kuris'], KuriPlan.fromJson),
      payments: parseList(json['payments'], KuriPayment.fromJson),
      chatMessages: parseList(json['chatMessages'], ChatMessage.fromJson),
      notifications: parseList(json['notifications'], InAppNotification.fromJson),
      auctions: parseList(json['auctions'], KuriAuction.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'users': users.map((u) => u.toJson()).toList(),
        'groups': groups.map((g) => g.toJson()).toList(),
        'invitations': invitations.map((i) => i.toJson()).toList(),
        'kuris': kuris.map((k) => k.toJson()).toList(),
        'payments': payments.map((p) => p.toJson()).toList(),
        'chatMessages': chatMessages.map((m) => m.toJson()).toList(),
        'notifications': notifications.map((n) => n.toJson()).toList(),
        'auctions': auctions.map((a) => a.toJson()).toList(),
      };

  AppData copyWith({
    List<AppUser>? users,
    List<Group>? groups,
    List<Invitation>? invitations,
    List<KuriPlan>? kuris,
    List<KuriPayment>? payments,
    List<ChatMessage>? chatMessages,
    List<InAppNotification>? notifications,
    List<KuriAuction>? auctions,
  }) =>
      AppData(
        users: users ?? this.users,
        groups: groups ?? this.groups,
        invitations: invitations ?? this.invitations,
        kuris: kuris ?? this.kuris,
        payments: payments ?? this.payments,
        chatMessages: chatMessages ?? this.chatMessages,
        notifications: notifications ?? this.notifications,
        auctions: auctions ?? this.auctions,
      );
}
