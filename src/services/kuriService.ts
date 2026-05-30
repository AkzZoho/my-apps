import { loadData, saveData } from "../storage";
import { AppData, ChatMessage, Group, Invitation, KuriPayment, KuriPlan, User } from "../types";
import { makeId, makeInviteCode, nowIso } from "../utils";

export class KuriService {
  async getData(): Promise<AppData> {
    return loadData();
  }

  async createUser(name: string, email: string): Promise<User> {
    const data = await loadData();
    const existing = data.users.find(
      (u) => u.email.trim().toLowerCase() === email.trim().toLowerCase()
    );
    if (existing) return existing;

    const user: User = {
      id: makeId("usr"),
      name: name.trim(),
      email: email.trim().toLowerCase()
    };
    data.users.push(user);
    await saveData(data);
    return user;
  }

  async createGroup(
    groupName: string,
    adminUserId: string,
    initialMemberEmails: string[] = [],
    description = ""
  ): Promise<Group> {
    const data = await loadData();
    const group: Group = {
      id: makeId("grp"),
      name: groupName.trim(),
      description: description.trim(),
      createdBy: adminUserId,
      createdAt: nowIso(),
      members: [{ userId: adminUserId, role: "admin", joinedAt: nowIso() }]
    };
    data.groups.push(group);

    for (const rawEmail of initialMemberEmails) {
      const email = rawEmail.trim().toLowerCase();
      if (!email) continue;
      const invitation: Invitation = {
        id: makeId("inv"),
        groupId: group.id,
        invitedBy: adminUserId,
        inviteeName: email.split("@")[0],
        inviteeEmail: email,
        inviteCode: makeInviteCode(),
        status: "pending",
        createdAt: nowIso()
      };
      data.invitations.push(invitation);
    }

    await saveData(data);
    return group;
  }

  async inviteUser(
    groupId: string,
    invitedBy: string,
    inviteeName: string,
    inviteeEmail: string
  ): Promise<Invitation> {
    const data = await loadData();
    const invitation: Invitation = {
      id: makeId("inv"),
      groupId,
      invitedBy,
      inviteeName: inviteeName.trim(),
      inviteeEmail: inviteeEmail.trim().toLowerCase(),
      inviteCode: makeInviteCode(),
      status: "pending",
      createdAt: nowIso()
    };
    data.invitations.push(invitation);
    await saveData(data);
    return invitation;
  }

  async joinGroupByInviteCode(
    inviteCode: string,
    userName: string,
    userEmail: string
  ): Promise<{ group: Group; user: User }> {
    const data = await loadData();
    const invitation = data.invitations.find(
      (inv) => inv.inviteCode === inviteCode.trim().toUpperCase()
    );
    if (!invitation || invitation.status !== "pending") {
      throw new Error("Invalid or already used invite code.");
    }

    const group = data.groups.find((g) => g.id === invitation.groupId);
    if (!group) throw new Error("Group not found.");

    let user = data.users.find(
      (u) => u.email.trim().toLowerCase() === userEmail.trim().toLowerCase()
    );
    if (!user) {
      user = {
        id: makeId("usr"),
        name: userName.trim(),
        email: userEmail.trim().toLowerCase()
      };
      data.users.push(user);
    }

    const alreadyMember = group.members.some((m) => m.userId === user!.id);
    if (!alreadyMember) {
      group.members.push({ userId: user.id, role: "member", joinedAt: nowIso() });
    }

    invitation.status = "accepted";
    invitation.acceptedAt = nowIso();
    invitation.acceptedByUserId = user.id;

    await saveData(data);
    return { group, user };
  }

  async createKuri(
    groupId: string,
    createdBy: string,
    name: string,
    contributionAmount: number,
    currency: string,
    startDate: string,
    participantUserIds: string[],
    notificationConfig: {
      rules: Array<{
        channel: "email" | "in_app";
        beforeDays: number;
        emailRecipients: string[];
      }>;
    }
  ): Promise<KuriPlan> {
    const data = await loadData();
    const group = data.groups.find((g) => g.id === groupId);
    if (!group) throw new Error("Group not found.");

    const isMember = group.members.some((m) => m.userId === createdBy);
    if (!isMember) throw new Error("Only group members can create a Kuri.");

    const uniqueParticipants = Array.from(new Set(participantUserIds));
    const allMembers = new Set(group.members.map((m) => m.userId));
    const validParticipants = uniqueParticipants.filter((id) => allMembers.has(id));

    const kuri: KuriPlan = {
      id: makeId("kuri"),
      groupId,
      createdBy,
      name: name.trim(),
      contributionAmount,
      currency: currency.trim().toUpperCase(),
      startDate,
      participantUserIds: validParticipants,
      notificationConfig,
      createdAt: nowIso()
    };
    data.kuris.push(kuri);
    await saveData(data);
    return kuri;
  }

  async sendGroupMessage(groupId: string, senderUserId: string, text: string): Promise<ChatMessage> {
    const data = await loadData();
    const group = data.groups.find((g) => g.id === groupId);
    if (!group) throw new Error("Group not found.");

    const user = data.users.find((u) => u.id === senderUserId);
    if (!user) throw new Error("User not found.");

    const isMember = group.members.some((m) => m.userId === senderUserId);
    if (!isMember) throw new Error("Only members can chat.");

    const msg: ChatMessage = {
      id: makeId("msg"),
      groupId,
      senderUserId,
      senderName: user.name,
      text: text.trim(),
      createdAt: nowIso()
    };
    data.chatMessages.push(msg);
    await saveData(data);
    return msg;
  }

  async updateGroupDetails(groupId: string, actorUserId: string, name: string, description: string) {
    const data = await loadData();
    const group = data.groups.find((g) => g.id === groupId);
    if (!group) throw new Error("Committee not found.");
    if (group.createdBy !== actorUserId) throw new Error("Only committee admin can edit details.");
    group.name = name.trim();
    group.description = description.trim();
    await saveData(data);
    return group;
  }

  async addMemberByEmail(groupId: string, actorUserId: string, email: string): Promise<Invitation> {
    const data = await loadData();
    const group = data.groups.find((g) => g.id === groupId);
    if (!group) throw new Error("Committee not found.");
    if (group.createdBy !== actorUserId) throw new Error("Only committee admin can add members.");

    const cleaned = email.trim().toLowerCase();
    if (!cleaned) throw new Error("Email is required.");
    const existingUser = data.users.find((u) => u.email === cleaned);
    if (existingUser && group.members.some((m) => m.userId === existingUser.id)) {
      throw new Error("User is already a member.");
    }

    const invitation: Invitation = {
      id: makeId("inv"),
      groupId,
      invitedBy: actorUserId,
      inviteeName: cleaned.split("@")[0],
      inviteeEmail: cleaned,
      inviteCode: makeInviteCode(),
      status: "pending",
      createdAt: nowIso()
    };
    data.invitations.push(invitation);
    await saveData(data);
    return invitation;
  }

  async removeMember(groupId: string, actorUserId: string, memberUserId: string) {
    const data = await loadData();
    const group = data.groups.find((g) => g.id === groupId);
    if (!group) throw new Error("Committee not found.");
    if (group.createdBy !== actorUserId) throw new Error("Only committee admin can remove members.");
    if (group.createdBy === memberUserId) throw new Error("Admin cannot be removed.");
    group.members = group.members.filter((m) => m.userId !== memberUserId);
    await saveData(data);
    return group;
  }

  async deleteKuri(kuriId: string, actorUserId: string): Promise<void> {
    const data = await loadData();
    const kuri = data.kuris.find((k) => k.id === kuriId);
    if (!kuri) throw new Error("Kuri plan not found.");
    if (kuri.createdBy !== actorUserId) throw new Error("Only the creator can delete a Kuri plan.");
    data.kuris = data.kuris.filter((k) => k.id !== kuriId);
    data.payments = (data.payments || []).filter((p) => p.kuriId !== kuriId);
    await saveData(data);
  }

  async updateKuriPaymentInfo(
    kuriId: string,
    actorUserId: string,
    upiId: string,
    upiQrBase64?: string
  ): Promise<KuriPlan> {
    const data = await loadData();
    const kuri = data.kuris.find((k) => k.id === kuriId);
    if (!kuri) throw new Error("Kuri plan not found.");
    if (kuri.createdBy !== actorUserId) throw new Error("Only the creator can update payment info.");
    kuri.upiId = upiId.trim();
    if (upiQrBase64 !== undefined) kuri.upiQrBase64 = upiQrBase64;
    await saveData(data);
    return kuri;
  }

  async submitPayment(
    kuriId: string,
    userId: string,
    month: string,
    transactionId: string,
    amount: number,
    receiptBase64?: string,
    receiptFileName?: string
  ): Promise<KuriPayment> {
    const data = await loadData();
    const kuri = data.kuris.find((k) => k.id === kuriId);
    if (!kuri) throw new Error("Kuri plan not found.");

    if (!Array.isArray(data.payments)) data.payments = [];
    const existing = data.payments.find(
      (p) => p.kuriId === kuriId && p.userId === userId && p.month === month
    );
    if (existing && existing.status === "approved") {
      throw new Error("Payment for this month is already approved.");
    }

    const payment: KuriPayment = {
      id: makeId("pay"),
      kuriId,
      userId,
      month,
      transactionId: transactionId.trim().toUpperCase(),
      amount,
      receiptBase64,
      receiptFileName,
      status: "submitted",
      submittedAt: nowIso(),
    };

    if (existing) {
      // Replace rejected/previous submission with new one
      data.payments = data.payments.filter(
        (p) => !(p.kuriId === kuriId && p.userId === userId && p.month === month)
      );
    }
    data.payments.push(payment);
    await saveData(data);
    return payment;
  }

  async reviewPayment(
    paymentId: string,
    actorUserId: string,
    approved: boolean,
    notes?: string
  ): Promise<KuriPayment> {
    const data = await loadData();
    if (!Array.isArray(data.payments)) data.payments = [];
    const payment = data.payments.find((p) => p.id === paymentId);
    if (!payment) throw new Error("Payment not found.");

    const kuri = data.kuris.find((k) => k.id === payment.kuriId);
    if (!kuri) throw new Error("Kuri plan not found.");
    if (kuri.createdBy !== actorUserId) throw new Error("Only the Kuri creator can review payments.");

    payment.status = approved ? "approved" : "rejected";
    payment.reviewedAt = nowIso();
    payment.reviewedBy = actorUserId;
    if (notes) payment.notes = notes.trim();

    await saveData(data);
    return payment;
  }

  async generateMonthlyInAppNotifications(today = new Date()) {
    const data = await loadData();
    const day = today.getDate();
    const ym = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}`;

    for (const kuri of data.kuris) {
      const paymentDay = new Date(kuri.startDate).getDate();
      const rules = Array.isArray(kuri.notificationConfig?.rules) ? kuri.notificationConfig.rules : [];
      const activeInAppRule = rules.find(
        (r) => r.channel === "in_app" && paymentDay - Number(r.beforeDays || 0) === day
      );
      if (!activeInAppRule) continue;

      for (const userId of kuri.participantUserIds) {
        const dedupeKey = `${kuri.id}:${userId}:${ym}:${day}`;
        const exists = data.notifications.some(
          (n) =>
            n.kuriId === kuri.id &&
            n.userId === userId &&
            n.message.includes(dedupeKey)
        );
        if (exists) continue;
        data.notifications.push({
          id: makeId("ntf"),
          groupId: kuri.groupId,
          kuriId: kuri.id,
          userId,
          title: `Kuri Reminder: ${kuri.name}`,
          message: `Please make your monthly payment. ref:${dedupeKey}`,
          createdAt: nowIso(),
          read: false
        });
      }
    }

    await saveData(data);
  }
}

export const kuriService = new KuriService();
