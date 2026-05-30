import React, { useEffect, useMemo, useState } from "react";
import {
  Alert,
  Modal,
  Platform,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View
} from "react-native";
import { StatusBar } from "expo-status-bar";
import { kuriService } from "./src/services/kuriService";
import { AppData, ChatMessage, Group, User } from "./src/types";

const emptyData: AppData = {
  users: [],
  groups: [],
  invitations: [],
  kuris: [],
  chatMessages: [],
  notifications: []
};

type AuthMode = "login" | "signup";

export default function App() {
  const [data, setData] = useState<AppData>(emptyData);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [authMode, setAuthMode] = useState<AuthMode>("login");

  const [name, setName] = useState("");
  const [email, setEmail] = useState("");

  const [committeeName, setCommitteeName] = useState("");
  const [committeeDescription, setCommitteeDescription] = useState("");
  const [memberEmail, setMemberEmail] = useState("");
  const [memberEmails, setMemberEmails] = useState<string[]>([]);

  const [chatText, setChatText] = useState("");

  const [kuriName, setKuriName] = useState("");
  const [kuriAmount, setKuriAmount] = useState("");
  const [kuriDate, setKuriDate] = useState("");
  const [kuriParticipantIds, setKuriParticipantIds] = useState<string[]>([]);
  const [participantPickerOpen, setParticipantPickerOpen] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [notificationRules, setNotificationRules] = useState<
    Array<{ id: string; channel: "email" | "in_app"; beforeDays: string; emails: string }>
  >([{ id: "r1", channel: "in_app", beforeDays: "2", emails: "" }]);

  const [editOpen, setEditOpen] = useState(false);
  const [memberActionUserId, setMemberActionUserId] = useState<string | null>(null);
  const [addMemberOpen, setAddMemberOpen] = useState(false);
  const [addMemberEmail, setAddMemberEmail] = useState("");

  useEffect(() => {
    void refreshData();
  }, []);

  const refreshData = async () => {
    await kuriService.generateMonthlyInAppNotifications();
    const loaded = await kuriService.getData();
    setData(loaded);
  };

  const activeCommittee = useMemo<Group | undefined>(() => {
    if (!currentUser) return undefined;
    return data.groups.find((g) => g.members.some((m) => m.userId === currentUser.id));
  }, [currentUser, data.groups]);

  useEffect(() => {
    if (!activeCommittee) return;
    setCommitteeName(activeCommittee.name);
    setCommitteeDescription(activeCommittee.description ?? "");
  }, [activeCommittee]);

  const committeeMembers = useMemo(() => {
    if (!activeCommittee) return [];
    return activeCommittee.members
      .map((m) => {
        const user = data.users.find((u) => u.id === m.userId);
        return user ? { ...m, user } : null;
      })
      .filter(Boolean) as Array<{ userId: string; role: "admin" | "member"; user: User }>;
  }, [activeCommittee, data.users]);

  const myNotifications = useMemo(() => {
    if (!currentUser) return [];
    return data.notifications
      .filter((n) => n.userId === currentUser.id)
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, 8);
  }, [currentUser, data.notifications]);

  const pendingInvitees = useMemo(() => {
    if (!activeCommittee) return [];
    return data.invitations.filter((inv) => inv.groupId === activeCommittee.id && inv.status === "pending");
  }, [activeCommittee, data.invitations]);

  const chatMessages = useMemo<ChatMessage[]>(() => {
    if (!activeCommittee) return [];
    return data.chatMessages
      .filter((m) => m.groupId === activeCommittee.id)
      .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
  }, [activeCommittee, data.chatMessages]);

  const invitedForMe = useMemo(() => {
    if (!currentUser) return [];
    return data.invitations.filter(
      (inv) => inv.status === "pending" && inv.inviteeEmail.toLowerCase() === currentUser.email.toLowerCase()
    );
  }, [currentUser, data.invitations]);

  const doSignup = async () => {
    if (!name.trim() || !email.trim()) {
      Alert.alert("Missing fields", "Enter your name and email.");
      return;
    }
    const user = await kuriService.createUser(name, email);
    setCurrentUser(user);
    await refreshData();
  };

  const doLogin = () => {
    if (!email.trim()) {
      Alert.alert("Missing email", "Enter your email.");
      return;
    }
    const user = data.users.find((u) => u.email === email.trim().toLowerCase());
    if (!user) {
      Alert.alert("Account not found", "Please signup first.");
      return;
    }
    setCurrentUser(user);
  };

  const addMemberEmailChip = () => {
    const cleaned = memberEmail.trim().toLowerCase();
    if (!cleaned || memberEmails.includes(cleaned)) return;
    setMemberEmails((prev) => [...prev, cleaned]);
    setMemberEmail("");
  };

  const createCommittee = async () => {
    if (!currentUser) return;
    if (!committeeName.trim()) {
      Alert.alert("Missing name", "Enter a committee name.");
      return;
    }
    await kuriService.createGroup(committeeName, currentUser.id, memberEmails, committeeDescription);
    setCommitteeName("");
    setCommitteeDescription("");
    setMemberEmails([]);
    await refreshData();
  };

  const joinCommittee = async (inviteCode: string) => {
    if (!currentUser) return;
    await kuriService.joinGroupByInviteCode(inviteCode, currentUser.name, currentUser.email);
    await refreshData();
    Alert.alert("Joined", "You are now a committee member.");
  };

  const sendChat = async () => {
    if (!currentUser || !activeCommittee || !chatText.trim()) return;
    await kuriService.sendGroupMessage(activeCommittee.id, currentUser.id, chatText);
    setChatText("");
    await refreshData();
  };

  const createKuri = async () => {
    if (!currentUser || !activeCommittee) return;
    const amount = Number(kuriAmount);
    if (!kuriName.trim() || !kuriDate.trim() || Number.isNaN(amount)) {
      Alert.alert("Missing fields", "Enter kuri name, amount and start date (YYYY-MM-DD).");
      return;
    }
    const rules = notificationRules.map((r) => ({
      channel: r.channel,
      beforeDays: Number(r.beforeDays || "0"),
      emailRecipients: r.emails
        .split(",")
        .map((v) => v.trim().toLowerCase())
        .filter(Boolean)
    }));

    await kuriService.createKuri(
      activeCommittee.id,
      currentUser.id,
      kuriName,
      amount,
      "INR",
      kuriDate,
      kuriParticipantIds,
      {
        rules
      }
    );
    setKuriName("");
    setKuriAmount("");
    setKuriDate("");
    setKuriParticipantIds([]);
    await refreshData();
  };

  const updateCommittee = async () => {
    if (!currentUser || !activeCommittee) return;
    await kuriService.updateGroupDetails(
      activeCommittee.id,
      currentUser.id,
      committeeName,
      committeeDescription
    );
    await refreshData();
    Alert.alert("Success", "Changes saved");
  };

  const addMemberFromPopup = async () => {
    if (!currentUser || !activeCommittee) return;
    await kuriService.addMemberByEmail(activeCommittee.id, currentUser.id, addMemberEmail);
    setAddMemberEmail("");
    setAddMemberOpen(false);
    await refreshData();
    Alert.alert("Success", "Invite sent");
  };

  const removeMember = async (memberUserId: string) => {
    if (!currentUser || !activeCommittee) return;
    await kuriService.removeMember(activeCommittee.id, currentUser.id, memberUserId);
    setMemberActionUserId(null);
    await refreshData();
    Alert.alert("Success", "Member removed");
  };

  if (!currentUser) {
    return (
      <SafeAreaView style={styles.safe}>
        <StatusBar style="light" />
        <View style={styles.authShell}>
          <View style={styles.formPanel}>
            <Text style={styles.brand}>Committee App</Text>
            <Text style={styles.heroText}>Create Committees. Invite Members. Chat Live. Start Kuri Plans.</Text>
            {authMode === "login" ? (
              <>
                <Field label="Email" value={email} onChangeText={setEmail} />
                <PrimaryButton text="Login" onPress={doLogin} />
                <TouchableOpacity style={styles.authSwitch} onPress={() => setAuthMode("signup")}>
                  <Text style={styles.authSwitchText}>New user? Signup</Text>
                </TouchableOpacity>
              </>
            ) : (
              <>
                <Field label="Name" value={name} onChangeText={setName} />
                <Field label="Email" value={email} onChangeText={setEmail} />
                <PrimaryButton text="Create Account" onPress={doSignup} />
                <TouchableOpacity style={styles.authSwitch} onPress={() => setAuthMode("login")}>
                  <Text style={styles.authSwitchText}>Already have an account? Login</Text>
                </TouchableOpacity>
              </>
            )}
          </View>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar style="light" />
      <ScrollView contentContainerStyle={styles.page}>
        <View style={styles.topBar}>
          <Text style={styles.h1}>Hi {currentUser.name}</Text>
          <TouchableOpacity style={styles.ghostBtn} onPress={() => setCurrentUser(null)}>
            <Text style={styles.ghostBtnText}>Logout</Text>
          </TouchableOpacity>
        </View>

        {!activeCommittee ? (
          <>
            <Panel title="Create Committee">
              <Field label="Committee Name" value={committeeName} onChangeText={setCommitteeName} />
              <Field
                label="Description (Optional)"
                value={committeeDescription}
                onChangeText={setCommitteeDescription}
              />
              <View style={styles.inlineRow}>
                <View style={styles.flex}>
                  <Field label="Initial Member Email" value={memberEmail} onChangeText={setMemberEmail} />
                </View>
                <TouchableOpacity style={styles.iconBtn} onPress={addMemberEmailChip}>
                  <Text style={styles.iconBtnText}>+</Text>
                </TouchableOpacity>
              </View>
              <View style={styles.chips}>
                {memberEmails.map((m) => (
                  <View key={m} style={styles.chip}>
                    <Text style={styles.chipText}>{m}</Text>
                  </View>
                ))}
              </View>
              <PrimaryButton text="Create Committee" onPress={createCommittee} />
            </Panel>
            {invitedForMe.length > 0 ? (
              <Panel title="Pending Invitations">
                {invitedForMe.map((inv) => (
                  <View key={inv.id} style={styles.inviteCard}>
                    <Text style={styles.meta}>Invite Code</Text>
                    <Text style={styles.code}>{inv.inviteCode}</Text>
                    <PrimaryButton text="Join Committee" onPress={() => joinCommittee(inv.inviteCode)} />
                  </View>
                ))}
              </Panel>
            ) : null}
          </>
        ) : (
          <>
            <Panel title={`Committee: ${activeCommittee.name}`}>
              <Text style={styles.meta}>Members: {activeCommittee.members.length}</Text>
              <Text style={styles.meta}>{activeCommittee.description?.trim() || "No description yet."}</Text>
              <View style={{ marginTop: 10 }}>
                <PrimaryButton text="Edit" compact onPress={() => setEditOpen(true)} />
              </View>
            </Panel>

            <View style={styles.grid}>
              <Panel title="Live Chat">
                <View style={styles.chatBox}>
                  {chatMessages.length === 0 ? (
                    <Text style={styles.meta}>No messages yet.</Text>
                  ) : (
                    chatMessages.map((m) => (
                      <View key={m.id} style={styles.msg}>
                        <Text style={styles.msgName}>{m.senderName}</Text>
                        <Text style={styles.msgBody}>{m.text}</Text>
                      </View>
                    ))
                  )}
                </View>
                <Field label="Message" value={chatText} onChangeText={setChatText} />
                <PrimaryButton text="Send" onPress={sendChat} />
              </Panel>

              <Panel title="Create Kuri (Optional)">
                <Field label="Kuri Name" value={kuriName} onChangeText={setKuriName} />
                <Field label="Contribution Amount" value={kuriAmount} onChangeText={setKuriAmount} />
                <Field label="Start Date (YYYY-MM-DD)" value={kuriDate} onChangeText={setKuriDate} />
                <Text style={styles.subLabel}>Select Participants</Text>
                <TouchableOpacity style={styles.dropdownBtn} onPress={() => setParticipantPickerOpen(true)}>
                  <Text style={styles.dropdownBtnText}>
                    {kuriParticipantIds.length > 0
                      ? `${kuriParticipantIds.length} selected`
                      : "Choose participants"}
                  </Text>
                </TouchableOpacity>
                <Text style={styles.subLabel}>Notifications (Subform)</Text>
                <View style={styles.subformTable}>
                  {notificationRules.map((r) => (
                    <View key={r.id} style={styles.notifySubRow}>
                      <View style={styles.notifyColSmall}>
                        <Text style={styles.label}>Channel</Text>
                        <TouchableOpacity
                          style={styles.dropdownBtn}
                          onPress={() =>
                            setNotificationRules((prev) =>
                              prev.map((x) =>
                                x.id === r.id
                                  ? { ...x, channel: x.channel === "email" ? "in_app" : "email" }
                                  : x
                              )
                            )
                          }
                        >
                          <Text style={styles.dropdownBtnText}>{r.channel === "email" ? "Email" : "In App"}</Text>
                        </TouchableOpacity>
                      </View>
                      <View style={styles.notifyColSmall}>
                        <Text style={styles.label}>Before N Days</Text>
                        <TextInput
                          style={styles.input}
                          value={r.beforeDays}
                          onChangeText={(v) =>
                            setNotificationRules((prev) =>
                              prev.map((x) => (x.id === r.id ? { ...x, beforeDays: v } : x))
                            )
                          }
                        />
                      </View>
                      <View style={styles.notifyColLarge}>
                        <Text style={styles.label}>Emails (for Email channel)</Text>
                        <TextInput
                          style={styles.input}
                          value={r.emails}
                          onChangeText={(v) =>
                            setNotificationRules((prev) =>
                              prev.map((x) => (x.id === r.id ? { ...x, emails: v } : x))
                            )
                          }
                        />
                      </View>
                      <TouchableOpacity
                        style={styles.rowDelete}
                        onPress={() =>
                          setNotificationRules((prev) => prev.filter((x) => x.id !== r.id))
                        }
                      >
                        <Text style={styles.rowDeleteText}>X</Text>
                      </TouchableOpacity>
                    </View>
                  ))}
                </View>
                <TouchableOpacity
                  style={styles.addTinyBtn}
                  onPress={() =>
                    setNotificationRules((prev) => [
                      ...prev,
                      { id: `r${Date.now()}`, channel: "in_app", beforeDays: "1", emails: "" }
                    ])
                  }
                >
                  <Text style={styles.addTinyBtnText}>+ Add Notification Rule</Text>
                </TouchableOpacity>
                <PrimaryButton text="Create Kuri" onPress={createKuri} />
              </Panel>
            </View>
          </>
        )}
      </ScrollView>

      <View style={styles.bellWrap}>
        <TouchableOpacity style={styles.bellBtn} onPress={() => setNotificationsOpen(true)}>
          <Text style={styles.bellIcon}>🔔</Text>
          {myNotifications.length > 0 ? (
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{myNotifications.length}</Text>
            </View>
          ) : null}
        </TouchableOpacity>
      </View>

      <Modal visible={editOpen} transparent animationType="fade">
        <View style={styles.modalBackdrop}>
          <View style={styles.modalCard}>
            <Text style={styles.panelTitle}>Edit Committee</Text>
            <Field label="Committee Name" value={committeeName} onChangeText={setCommitteeName} />
            <Field label="Description" value={committeeDescription} onChangeText={setCommitteeDescription} />
            <PrimaryButton text="Update" onPress={updateCommittee} />

            <View style={styles.subformHead}>
              <Text style={styles.subformTitle}>Current Members</Text>
              <TouchableOpacity style={styles.addTinyBtn} onPress={() => setAddMemberOpen(true)}>
                <Text style={styles.addTinyBtnText}>+ Add</Text>
              </TouchableOpacity>
            </View>
            <View style={styles.subformTable}>
              {committeeMembers.map((m) => (
                <View key={m.user.id} style={styles.subformRow}>
                  <View style={styles.flex}>
                    <Text style={styles.rowName}>{m.user.name}</Text>
                    <Text style={styles.rowEmail}>{m.user.email}</Text>
                  </View>
                  <TouchableOpacity style={styles.rowEdit} onPress={() => setMemberActionUserId(m.user.id)}>
                    <Text style={styles.rowEditText}>✎</Text>
                  </TouchableOpacity>
                </View>
              ))}
              {pendingInvitees.map((inv) => (
                <View key={inv.id} style={styles.subformRowPending}>
                  <View style={styles.flex}>
                    <Text style={styles.rowName}>{inv.inviteeName || "Invited Member"}</Text>
                    <Text style={styles.rowEmail}>{inv.inviteeEmail}</Text>
                  </View>
                  <View style={styles.pendingTag}>
                    <Text style={styles.pendingTagText}>Invited</Text>
                  </View>
                </View>
              ))}
            </View>

            <TouchableOpacity style={styles.closeBtn} onPress={() => setEditOpen(false)}>
              <Text style={styles.closeBtnText}>Close</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      <Modal visible={addMemberOpen} transparent animationType="fade">
        <View style={styles.modalBackdrop}>
          <View style={styles.smallModal}>
            <Text style={styles.panelTitle}>Add Member</Text>
            <Field label="Member Email" value={addMemberEmail} onChangeText={setAddMemberEmail} />
            <PrimaryButton text="Add Member" onPress={addMemberFromPopup} />
            <TouchableOpacity style={styles.closeBtn} onPress={() => setAddMemberOpen(false)}>
              <Text style={styles.closeBtnText}>Cancel</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      <Modal visible={!!memberActionUserId} transparent animationType="fade">
        <View style={styles.modalBackdrop}>
          <View style={styles.smallModal}>
            <Text style={styles.panelTitle}>Member Actions</Text>
            <PrimaryButton text="Add Member" onPress={() => { setMemberActionUserId(null); setAddMemberOpen(true); }} />
            <TouchableOpacity
              style={styles.deleteBtn}
              onPress={() => {
                if (memberActionUserId) void removeMember(memberActionUserId);
              }}
            >
              <Text style={styles.deleteBtnText}>Delete Member</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.closeBtn} onPress={() => setMemberActionUserId(null)}>
              <Text style={styles.closeBtnText}>Close</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      <Modal visible={participantPickerOpen} transparent animationType="fade">
        <View style={styles.modalBackdrop}>
          <View style={styles.smallModal}>
            <Text style={styles.panelTitle}>Select Participants</Text>
            <ScrollView style={{ maxHeight: 280 }}>
              {committeeMembers.map((m) => {
                const selected = kuriParticipantIds.includes(m.user.id);
                return (
                  <TouchableOpacity
                    key={m.user.id}
                    style={styles.participantRow}
                    onPress={() =>
                      setKuriParticipantIds((prev) =>
                        prev.includes(m.user.id)
                          ? prev.filter((id) => id !== m.user.id)
                          : [...prev, m.user.id]
                      )
                    }
                  >
                    <Text style={styles.rowName}>{m.user.name}</Text>
                    <Text style={styles.rowEmail}>{selected ? "Selected" : "Tap to select"}</Text>
                  </TouchableOpacity>
                );
              })}
            </ScrollView>
            <TouchableOpacity style={styles.closeBtn} onPress={() => setParticipantPickerOpen(false)}>
              <Text style={styles.closeBtnText}>Done</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      <Modal visible={notificationsOpen} transparent animationType="fade">
        <View style={styles.modalBackdrop}>
          <View style={styles.smallModal}>
            <Text style={styles.panelTitle}>Notifications</Text>
            <ScrollView style={{ maxHeight: 320 }}>
              {myNotifications.length === 0 ? (
                <Text style={styles.meta}>No notifications yet.</Text>
              ) : (
                myNotifications.map((n) => (
                  <View key={n.id} style={styles.notifyRow}>
                    <Text style={styles.msgName}>{n.title}</Text>
                    <Text style={styles.rowEmail}>{n.message.replace(/ref:.*/, "").trim()}</Text>
                  </View>
                ))
              )}
            </ScrollView>
            <TouchableOpacity style={styles.closeBtn} onPress={() => setNotificationsOpen(false)}>
              <Text style={styles.closeBtnText}>Close</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <View style={styles.panel}>
      <Text style={styles.panelTitle}>{title}</Text>
      {children}
    </View>
  );
}

function Field({
  label,
  value,
  onChangeText
}: {
  label: string;
  value: string;
  onChangeText: (text: string) => void;
}) {
  return (
    <View style={{ marginBottom: 10 }}>
      <Text style={styles.label}>{label}</Text>
      <TextInput style={styles.input} value={value} onChangeText={onChangeText} />
    </View>
  );
}

function PrimaryButton({
  text,
  onPress,
  compact
}: {
  text: string;
  onPress: () => void;
  compact?: boolean;
}) {
  return (
    <TouchableOpacity style={[styles.primaryBtn, compact ? styles.primaryBtnCompact : undefined]} onPress={onPress}>
      <Text style={styles.primaryBtnText}>{text}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: "#020817" },
  page: {
    width: "100%",
    maxWidth: Platform.OS === "web" ? 1100 : 560,
    alignSelf: "center",
    padding: 20,
    paddingBottom: 40
  },
  topBar: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 16 },
  h1: { color: "#eef2ff", fontSize: 28, fontWeight: "800" },
  ghostBtn: { borderWidth: 1, borderColor: "#334155", borderRadius: 999, paddingHorizontal: 14, paddingVertical: 8 },
  ghostBtnText: { color: "#cbd5e1", fontWeight: "700" },
  grid: { flexDirection: Platform.OS === "web" ? "row" : "column", gap: 14 },
  panel: {
    flex: 1,
    backgroundColor: "#0f172a",
    borderRadius: 16,
    borderWidth: 1,
    borderColor: "#1e293b",
    padding: 14,
    marginBottom: 14
  },
  panelTitle: { color: "#e2e8f0", fontSize: 18, fontWeight: "800", marginBottom: 10 },
  label: { color: "#94a3b8", marginBottom: 4, fontWeight: "600" },
  input: {
    borderWidth: 1,
    borderColor: "#334155",
    backgroundColor: "#0b1222",
    color: "#e2e8f0",
    borderRadius: 10,
    paddingVertical: 11,
    paddingHorizontal: 12
  },
  primaryBtn: {
    backgroundColor: "#22d3ee",
    borderRadius: 10,
    paddingVertical: 12,
    alignItems: "center",
    marginTop: 4
  },
  primaryBtnCompact: { width: 92, paddingVertical: 9 },
  primaryBtnText: { color: "#083344", fontWeight: "800" },
  meta: { color: "#94a3b8", marginBottom: 4 },
  chatBox: { maxHeight: 240, borderWidth: 1, borderColor: "#1e293b", borderRadius: 10, padding: 10, marginBottom: 10 },
  msg: { marginBottom: 8 },
  msgName: { color: "#67e8f9", fontWeight: "700" },
  msgBody: { color: "#e2e8f0" },
  authShell: {
    flex: 1,
    width: "100%",
    maxWidth: Platform.OS === "web" ? 480 : 560,
    alignSelf: "center",
    flexDirection: "column",
    justifyContent: "center",
    padding: 20
  },
  brand: { color: "#e2e8f0", fontSize: 38, fontWeight: "900", marginBottom: 10 },
  heroText: { color: "#94a3b8", fontSize: 16, lineHeight: 24 },
  formPanel: { backgroundColor: "#0f172a", borderRadius: 16, borderWidth: 1, borderColor: "#1e293b", padding: 20 },
  authSwitch: { marginTop: 14, alignItems: "center" },
  authSwitchText: { color: "#67e8f9", fontWeight: "700" },
  inlineRow: { flexDirection: "row", gap: 8, alignItems: "flex-end" },
  flex: { flex: 1 },
  iconBtn: { backgroundColor: "#164e63", borderRadius: 10, width: 44, height: 44, alignItems: "center", justifyContent: "center", marginBottom: 10 },
  iconBtnText: { color: "#cffafe", fontSize: 20, fontWeight: "800" },
  chips: { flexDirection: "row", flexWrap: "wrap", gap: 6, marginBottom: 10 },
  chip: { backgroundColor: "#1e293b", borderRadius: 999, paddingHorizontal: 10, paddingVertical: 6 },
  chipText: { color: "#cbd5e1", fontSize: 12 },
  chipActive: { backgroundColor: "#0e7490" },
  chipTextActive: { color: "#ecfeff", fontWeight: "700" },
  subLabel: { color: "#cbd5e1", fontWeight: "700", marginBottom: 8, marginTop: 2 },
  togglePill: {
    backgroundColor: "#1e293b",
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginBottom: 10
  },
  togglePillOn: { backgroundColor: "#0e7490" },
  togglePillText: { color: "#e2e8f0", fontWeight: "700" },
  dropdownBtn: {
    borderWidth: 1,
    borderColor: "#334155",
    backgroundColor: "#0b1222",
    borderRadius: 10,
    paddingVertical: 11,
    paddingHorizontal: 12,
    marginBottom: 10
  },
  dropdownBtnText: { color: "#e2e8f0", fontWeight: "600" },
  notifySubRow: {
    borderBottomWidth: 1,
    borderBottomColor: "#1e293b",
    padding: 10,
    backgroundColor: "#0b1222"
  },
  notifyColSmall: { marginBottom: 8 },
  notifyColLarge: { marginBottom: 8 },
  rowDelete: {
    alignSelf: "flex-end",
    backgroundColor: "#7f1d1d",
    borderRadius: 6,
    paddingHorizontal: 8,
    paddingVertical: 5
  },
  rowDeleteText: { color: "#fee2e2", fontWeight: "700" },
  inviteCard: { borderWidth: 1, borderColor: "#334155", borderRadius: 10, padding: 10, marginBottom: 8 },
  code: { color: "#fde68a", fontSize: 18, fontWeight: "800", marginBottom: 8 },
  editRow: { marginTop: 8 },
  modalBackdrop: { flex: 1, backgroundColor: "rgba(2,6,23,0.72)", justifyContent: "center", padding: 16 },
  modalCard: {
    backgroundColor: "#0f172a",
    borderRadius: 16,
    borderWidth: 1,
    borderColor: "#334155",
    padding: 14,
    maxHeight: "90%"
  },
  smallModal: {
    backgroundColor: "#0f172a",
    borderRadius: 16,
    borderWidth: 1,
    borderColor: "#334155",
    padding: 14
  },
  subformHead: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 12, marginBottom: 8 },
  subformTitle: { color: "#e2e8f0", fontWeight: "700" },
  addTinyBtn: { backgroundColor: "#1d4ed8", borderRadius: 8, paddingHorizontal: 10, paddingVertical: 7 },
  addTinyBtnText: { color: "#dbeafe", fontWeight: "700" },
  subformTable: { borderWidth: 1, borderColor: "#334155", borderRadius: 10, overflow: "hidden" },
  subformRow: {
    flexDirection: "row",
    alignItems: "center",
    padding: 10,
    borderBottomWidth: 1,
    borderBottomColor: "#1e293b",
    backgroundColor: "#0b1222"
  },
  subformRowPending: {
    flexDirection: "row",
    alignItems: "center",
    padding: 10,
    borderBottomWidth: 1,
    borderBottomColor: "#1e293b",
    backgroundColor: "#0a1527"
  },
  rowName: { color: "#e2e8f0", fontWeight: "700" },
  rowEmail: { color: "#94a3b8", fontSize: 12 },
  rowEdit: { width: 36, height: 36, borderRadius: 8, backgroundColor: "#1e293b", alignItems: "center", justifyContent: "center" },
  rowEditText: { color: "#cbd5e1", fontSize: 16, fontWeight: "700" },
  participantRow: {
    borderWidth: 1,
    borderColor: "#334155",
    borderRadius: 10,
    padding: 10,
    marginBottom: 8
  },
  pendingTag: { backgroundColor: "#1d4ed8", borderRadius: 999, paddingHorizontal: 10, paddingVertical: 6 },
  pendingTagText: { color: "#dbeafe", fontSize: 12, fontWeight: "700" },
  closeBtn: { marginTop: 10, borderWidth: 1, borderColor: "#334155", borderRadius: 10, paddingVertical: 11, alignItems: "center" },
  closeBtnText: { color: "#cbd5e1", fontWeight: "700" },
  deleteBtn: { marginTop: 8, backgroundColor: "#7f1d1d", borderRadius: 10, paddingVertical: 11, alignItems: "center" },
  deleteBtnText: { color: "#fee2e2", fontWeight: "800" },
  notifyRow: {
    borderWidth: 1,
    borderColor: "#334155",
    borderRadius: 10,
    padding: 10,
    marginBottom: 8,
    backgroundColor: "#0b1222"
  },
  bellWrap: { position: "absolute", top: 12, right: 16 },
  bellBtn: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: "#0f172a",
    borderWidth: 1,
    borderColor: "#334155",
    alignItems: "center",
    justifyContent: "center"
  },
  bellIcon: { fontSize: 18 },
  badge: {
    position: "absolute",
    top: -5,
    right: -5,
    minWidth: 18,
    height: 18,
    borderRadius: 9,
    backgroundColor: "#ef4444",
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 4
  },
  badgeText: { color: "#fff", fontSize: 11, fontWeight: "700" }
});
