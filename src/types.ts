export type Role = "admin" | "member";

export interface User {
  id: string;
  name: string;
  email: string;
}

export interface GroupMember {
  userId: string;
  role: Role;
  joinedAt: string;
}

export interface Group {
  id: string;
  name: string;
  description?: string;
  createdBy: string;
  members: GroupMember[];
  createdAt: string;
}

export interface Invitation {
  id: string;
  groupId: string;
  invitedBy: string;
  inviteeName: string;
  inviteeEmail: string;
  inviteCode: string;
  status: "pending" | "accepted" | "expired";
  createdAt: string;
  acceptedAt?: string;
  acceptedByUserId?: string;
}

export interface KuriPlan {
  id: string;
  groupId: string;
  name: string;
  contributionAmount: number;
  currency: string;
  startDate: string;
  participantUserIds: string[];
  notificationConfig: {
    rules: Array<{
      channel: "email" | "in_app";
      beforeDays: number;
      emailRecipients: string[];
    }>;
  };
  createdBy: string;
  createdAt: string;
}

export interface ChatMessage {
  id: string;
  groupId: string;
  senderUserId: string;
  senderName: string;
  text: string;
  createdAt: string;
}

export interface InAppNotification {
  id: string;
  groupId: string;
  kuriId: string;
  userId: string;
  title: string;
  message: string;
  createdAt: string;
  read: boolean;
}

export interface AppData {
  users: User[];
  groups: Group[];
  invitations: Invitation[];
  kuris: KuriPlan[];
  chatMessages: ChatMessage[];
  notifications: InAppNotification[];
}
