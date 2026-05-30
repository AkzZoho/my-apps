import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Modal,
  Platform,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import { StatusBar } from "expo-status-bar";
import { kuriService } from "./src/services/kuriService";
import { AppData, ChatMessage, Group, Invitation, KuriPlan, User } from "./src/types";

const emptyData: AppData = {
  users: [], groups: [], invitations: [], kuris: [], chatMessages: [], notifications: [],
};

type AuthMode = "login" | "signup";
type Tab = "committee" | "members" | "chat" | "kuri";
type Member = { userId: string; role: "admin" | "member"; user: User };

const C = {
  bg: "#020817",
  surface: "#0f172a",
  border: "#1e293b",
  borderStrong: "#334155",
  inputBg: "#0b1222",
  primary: "#22d3ee",
  primaryFg: "#083344",
  primaryMid: "#0e7490",
  primaryLight: "#164e63",
  text: "#e2e8f0",
  textSub: "#cbd5e1",
  textMuted: "#94a3b8",
  textDim: "#64748b",
  accent: "#67e8f9",
  warn: "#fde68a",
  danger: "#ef4444",
  dangerDark: "#7f1d1d",
  dangerFg: "#fee2e2",
  blueDark: "#1d4ed8",
  blueFg: "#dbeafe",
  greenDark: "#14532d",
  greenFg: "#dcfce7",
  green: "#22c55e",
} as const;

const AVATAR_COLORS = ["#0e7490", "#7e22ce", "#166534", "#1d4ed8", "#be185d", "#b45309"];
const MAX_W = Platform.OS === "web" ? 680 : undefined;
const IS_IOS = Platform.OS === "ios";

// ─── Primitives ───────────────────────────────────────────────────────────────

function Avatar({ name, size = 36 }: { name: string; size?: number }) {
  const initials = name.split(" ").map((w) => w[0] ?? "").join("").toUpperCase().slice(0, 2);
  const bg = AVATAR_COLORS[name.charCodeAt(0) % AVATAR_COLORS.length];
  return (
    <View style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: bg, alignItems: "center", justifyContent: "center" }}>
      <Text style={{ color: "#fff", fontWeight: "800", fontSize: size * 0.36 }}>{initials}</Text>
    </View>
  );
}

function Badge({ label, color, bg }: { label: string; color: string; bg: string }) {
  return (
    <View style={{ backgroundColor: bg, borderRadius: 999, paddingHorizontal: 8, paddingVertical: 3 }}>
      <Text style={{ color, fontSize: 11, fontWeight: "700" }}>{label}</Text>
    </View>
  );
}

function EmptyState({ icon, text }: { icon: string; text: string }) {
  return (
    <View style={{ alignItems: "center", paddingVertical: 40 }}>
      <Text style={{ fontSize: 44, marginBottom: 12 }}>{icon}</Text>
      <Text style={{ color: C.textMuted, textAlign: "center", lineHeight: 22, maxWidth: 260, fontSize: 14 }}>{text}</Text>
    </View>
  );
}

function Panel({ title, subtitle, children, noPad }: {
  title?: string; subtitle?: string; children: React.ReactNode; noPad?: boolean;
}) {
  return (
    <View style={s.panel}>
      {(title || subtitle) && (
        <View style={s.panelHead}>
          {title && <Text style={s.panelTitle}>{title}</Text>}
          {subtitle && <Text style={s.panelSub}>{subtitle}</Text>}
        </View>
      )}
      {noPad ? children : <View style={s.panelBody}>{children}</View>}
    </View>
  );
}

function Field({
  label, value, onChangeText, placeholder, keyboardType, multiline, autoFocus,
}: {
  label: string; value: string; onChangeText: (v: string) => void;
  placeholder?: string; keyboardType?: "default" | "email-address" | "numeric";
  multiline?: boolean; autoFocus?: boolean;
}) {
  return (
    <View style={{ marginBottom: 14 }}>
      <Text style={s.label}>{label}</Text>
      <TextInput
        style={[s.input, multiline && { height: 80, textAlignVertical: "top" as const }]}
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder}
        placeholderTextColor={C.textDim}
        keyboardType={keyboardType}
        multiline={multiline}
        autoCapitalize="none"
        autoCorrect={false}
        autoFocus={autoFocus}
      />
    </View>
  );
}

type BtnVariant = "primary" | "ghost" | "danger" | "outline" | "blue" | "green";
type BtnSize = "sm" | "md" | "lg";

function Btn({ label, onPress, variant = "primary", size = "md", disabled, full }: {
  label: string; onPress: () => void; variant?: BtnVariant;
  size?: BtnSize; disabled?: boolean; full?: boolean;
}) {
  const bg: Record<BtnVariant, string> = {
    primary: C.primary, ghost: "transparent", danger: C.dangerDark,
    outline: "transparent", blue: C.blueDark, green: C.greenDark,
  };
  const fg: Record<BtnVariant, string> = {
    primary: C.primaryFg, ghost: C.textSub, danger: C.dangerFg,
    outline: C.textSub, blue: C.blueFg, green: C.greenFg,
  };
  const bw: Record<BtnVariant, number> = {
    primary: 0, ghost: 1, danger: 0, outline: 1, blue: 0, green: 0,
  };
  const bc: Record<BtnVariant, string> = {
    primary: "transparent", ghost: C.borderStrong, danger: "transparent",
    outline: C.borderStrong, blue: "transparent", green: "transparent",
  };
  const py: Record<BtnSize, number> = { sm: 9, md: 12, lg: 15 };
  const fs: Record<BtnSize, number> = { sm: 13, md: 14, lg: 15 };
  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={disabled}
      activeOpacity={0.72}
      style={[s.btn, {
        backgroundColor: bg[variant],
        paddingVertical: py[size],
        borderWidth: bw[variant],
        borderColor: bc[variant],
        opacity: disabled ? 0.4 : 1,
        alignSelf: full ? "stretch" : "auto" as any,
      }]}
    >
      <Text style={[s.btnText, { color: fg[variant], fontSize: fs[size] }]}>{label}</Text>
    </TouchableOpacity>
  );
}

// ─── Tab Bar ──────────────────────────────────────────────────────────────────

const TABS: { id: Tab; label: string; emoji: string }[] = [
  { id: "committee", label: "Committee", emoji: "🏛" },
  { id: "members",   label: "Members",   emoji: "👥" },
  { id: "chat",      label: "Chat",      emoji: "💬" },
  { id: "kuri",      label: "Kuri",      emoji: "💰" },
];

function TabBar({ active, onChange }: { active: Tab; onChange: (t: Tab) => void }) {
  return (
    <View style={s.tabBar}>
      {TABS.map((t) => {
        const on = active === t.id;
        return (
          <TouchableOpacity key={t.id} onPress={() => onChange(t.id)} style={s.tabItem} activeOpacity={0.7}>
            <View style={[s.tabPill, on && s.tabPillOn]}>
              <Text style={{ fontSize: 19 }}>{t.emoji}</Text>
            </View>
            <Text style={[s.tabLabel, on && s.tabLabelOn]}>{t.label}</Text>
          </TouchableOpacity>
        );
      })}
    </View>
  );
}

// ─── Tab Views (OUTSIDE App — prevents unmount/remount on every re-render) ────

type CommitteeTabProps = {
  committee: Group;
  members: Member[];
  myRole: "admin" | "member";
  kuris: KuriPlan[];
  msgCount: number;
  pendingInvites: Invitation[];
  onEdit: () => void;
};

function CommitteeTabView({ committee, members, myRole, kuris, msgCount, pendingInvites, onEdit }: CommitteeTabProps) {
  return (
    <ScrollView
      style={s.tabContent}
      contentContainerStyle={{ paddingBottom: 24 }}
      showsVerticalScrollIndicator={false}
      keyboardShouldPersistTaps="handled"
    >
      <View style={s.hero}>
        <View style={s.heroTop}>
          <View style={s.heroIcon}>
            <Text style={s.heroIconText}>{committee.name.slice(0, 2).toUpperCase()}</Text>
          </View>
          <View style={{ flex: 1, marginLeft: 12 }}>
            <Text style={s.heroName} numberOfLines={2}>{committee.name}</Text>
            {committee.description ? (
              <Text style={s.heroDesc} numberOfLines={2}>{committee.description}</Text>
            ) : null}
          </View>
          {myRole === "admin" && (
            <TouchableOpacity style={s.editBtn} onPress={onEdit} activeOpacity={0.7}>
              <Text style={s.editBtnText}>Edit</Text>
            </TouchableOpacity>
          )}
        </View>
        <View style={s.statsRow}>
          {[
            { val: members.length, lbl: "Members" },
            { val: kuris.length,   lbl: "Kuri Plans" },
            { val: msgCount,       lbl: "Messages" },
          ].map((st, i) => (
            <React.Fragment key={st.lbl}>
              {i > 0 && <View style={s.statDivider} />}
              <View style={s.stat}>
                <Text style={s.statVal}>{st.val}</Text>
                <Text style={s.statLbl}>{st.lbl}</Text>
              </View>
            </React.Fragment>
          ))}
        </View>
      </View>

      <View style={s.roleRow}>
        <Text style={s.meta}>Your role: </Text>
        <Badge
          label={myRole === "admin" ? "Admin" : "Member"}
          color={myRole === "admin" ? C.warn : C.accent}
          bg={myRole === "admin" ? "#431407" : C.primaryLight}
        />
      </View>

      {kuris.length > 0 && (
        <Panel title="Kuri Plans" noPad>
          {kuris.map((k) => (
            <View key={k.id} style={s.rowItem}>
              <View style={s.rowItemIcon}><Text style={{ fontSize: 16 }}>💰</Text></View>
              <View style={{ flex: 1 }}>
                <Text style={s.rowItemName}>{k.name}</Text>
                <Text style={s.rowItemMeta}>₹{k.contributionAmount.toLocaleString()} / mo · starts {k.startDate}</Text>
              </View>
              <Badge label={`${k.participantUserIds.length}p`} color={C.accent} bg={C.primaryLight} />
            </View>
          ))}
        </Panel>
      )}

      {pendingInvites.length > 0 && myRole === "admin" && (
        <Panel title="Pending Invitations" noPad>
          {pendingInvites.map((inv) => (
            <View key={inv.id} style={s.rowItem}>
              <View style={s.rowItemIcon}><Text style={{ fontSize: 16 }}>✉️</Text></View>
              <View style={{ flex: 1 }}>
                <Text style={s.rowItemName} numberOfLines={1}>{inv.inviteeName || inv.inviteeEmail}</Text>
                <Text style={s.rowItemMeta} numberOfLines={1}>{inv.inviteeEmail}</Text>
              </View>
              <View style={s.codePill}><Text style={s.codeText}>{inv.inviteCode}</Text></View>
            </View>
          ))}
        </Panel>
      )}
    </ScrollView>
  );
}

type MembersTabProps = {
  members: Member[];
  pendingInvites: Invitation[];
  myRole: "admin" | "member";
  currentUserId: string;
  onInvite: () => void;
  onMemberAction: (userId: string) => void;
};

function MembersTabView({ members, pendingInvites, myRole, currentUserId, onInvite, onMemberAction }: MembersTabProps) {
  return (
    <ScrollView
      style={s.tabContent}
      contentContainerStyle={{ paddingBottom: 24 }}
      showsVerticalScrollIndicator={false}
      keyboardShouldPersistTaps="handled"
    >
      <View style={s.sectionHead}>
        <Text style={s.sectionTitle}>Members ({members.length})</Text>
        {myRole === "admin" && (
          <TouchableOpacity style={s.inviteChipBtn} onPress={onInvite} activeOpacity={0.7}>
            <Text style={s.inviteChipText}>+ Invite</Text>
          </TouchableOpacity>
        )}
      </View>

      {members.length === 0
        ? <EmptyState icon="👥" text="No members yet. Invite someone to get started!" />
        : members.map((m) => (
          <View key={m.user.id} style={s.memberCard}>
            <Avatar name={m.user.name} size={46} />
            <View style={s.memberInfo}>
              <View style={s.memberNameRow}>
                <Text style={s.memberName} numberOfLines={1}>{m.user.name}</Text>
                <Badge
                  label={m.role === "admin" ? "Admin" : "Member"}
                  color={m.role === "admin" ? C.warn : C.textMuted}
                  bg={m.role === "admin" ? "#431407" : C.border}
                />
              </View>
              <Text style={s.memberEmail} numberOfLines={1}>{m.user.email}</Text>
            </View>
            {myRole === "admin" && m.user.id !== currentUserId && (
              <TouchableOpacity
                style={s.moreBtn}
                onPress={() => onMemberAction(m.user.id)}
                activeOpacity={0.7}
                hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
              >
                <Text style={s.moreBtnText}>•••</Text>
              </TouchableOpacity>
            )}
          </View>
        ))
      }

      {pendingInvites.length > 0 && (
        <>
          <View style={s.dividerRow}>
            <Text style={s.dividerText}>Awaiting ({pendingInvites.length})</Text>
          </View>
          {pendingInvites.map((inv) => (
            <View key={inv.id} style={[s.memberCard, { opacity: 0.6 }]}>
              <View style={{ width: 46, height: 46, borderRadius: 23, backgroundColor: C.border, alignItems: "center", justifyContent: "center" }}>
                <Text style={{ fontSize: 20 }}>✉️</Text>
              </View>
              <View style={s.memberInfo}>
                <Text style={s.memberName} numberOfLines={1}>{inv.inviteeName || "Invited Member"}</Text>
                <Text style={s.memberEmail} numberOfLines={1}>{inv.inviteeEmail}</Text>
              </View>
              <Badge label="Pending" color="#f59e0b" bg="#451a03" />
            </View>
          ))}
        </>
      )}
    </ScrollView>
  );
}

type ChatTabProps = {
  chatMessages: ChatMessage[];
  currentUser: User;
  chatText: string;
  onChangeText: (t: string) => void;
  onSend: () => void;
  scrollRef: React.RefObject<ScrollView | null>;
  onFocusChange: (v: boolean) => void;
};

function ChatTabView({ chatMessages, currentUser, chatText, onChangeText, onSend, scrollRef, onFocusChange }: ChatTabProps) {
  return (
    <KeyboardAvoidingView
      style={{ flex: 1 }}
      behavior={IS_IOS ? "padding" : "height"}
      keyboardVerticalOffset={IS_IOS ? 92 : 0}
    >
      <View style={{ flex: 1, backgroundColor: C.bg }}>
        <ScrollView
          ref={scrollRef}
          style={{ flex: 1 }}
          contentContainerStyle={{ padding: 12, paddingBottom: 8 }}
          onContentSizeChange={() => scrollRef.current?.scrollToEnd({ animated: false })}
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode="none"
          showsVerticalScrollIndicator={false}
        >
          {chatMessages.length === 0
            ? <EmptyState icon="💬" text="No messages yet. Say hello!" />
            : chatMessages.map((m) => {
              const own = m.senderUserId === currentUser.id;
              const time = new Date(m.createdAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
              return (
                <View key={m.id} style={[s.msgRow, own ? s.msgOwn : s.msgOther]}>
                  {!own && (
                    <View style={{ marginRight: 6, alignSelf: "flex-end", marginBottom: 2 }}>
                      <Avatar name={m.senderName} size={26} />
                    </View>
                  )}
                  <View style={[s.bubble, own ? s.bubbleOwn : s.bubbleOther]}>
                    {!own && <Text style={s.bubbleSender}>{m.senderName}</Text>}
                    <Text style={[s.bubbleText, own && s.bubbleTextOwn]}>{m.text}</Text>
                    <Text style={[s.bubbleTime, own && s.bubbleTimeOwn]}>{time}</Text>
                  </View>
                </View>
              );
            })
          }
        </ScrollView>

        {/* Input bar — alignItems:center ensures button and input are vertically centred */}
        <View style={s.chatBar}>
          <TextInput
            style={s.chatInput}
            value={chatText}
            onChangeText={onChangeText}
            placeholder="Type a message…"
            placeholderTextColor={C.textDim}
            returnKeyType="send"
            blurOnSubmit={false}
            onSubmitEditing={onSend}
            autoCorrect={false}
            autoCapitalize="none"
            onFocus={() => onFocusChange(true)}
            onBlur={() => onFocusChange(false)}
          />
          <TouchableOpacity
            style={[s.sendBtn, !chatText.trim() && s.sendBtnOff]}
            onPress={onSend}
            disabled={!chatText.trim()}
            activeOpacity={0.75}
          >
            <Text style={s.sendIcon}>▶</Text>
          </TouchableOpacity>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}

type KuriTabProps = {
  myKuris: KuriPlan[];
  members: Member[];
  kuriName: string; setKuriName: (v: string) => void;
  kuriAmount: string; setKuriAmount: (v: string) => void;
  kuriDate: string; setKuriDate: (v: string) => void;
  kuriParticipantIds: string[];
  onOpenPicker: () => void;
  notifRules: Array<{ id: string; channel: "email" | "in_app"; beforeDays: string; emails: string }>;
  setNotifRules: React.Dispatch<React.SetStateAction<Array<{ id: string; channel: "email" | "in_app"; beforeDays: string; emails: string }>>>;
  onCreateKuri: () => void;
};

function KuriTabView({
  myKuris, kuriName, setKuriName, kuriAmount, setKuriAmount, kuriDate, setKuriDate,
  kuriParticipantIds, onOpenPicker, notifRules, setNotifRules, onCreateKuri,
}: KuriTabProps) {
  return (
    <ScrollView
      style={s.tabContent}
      contentContainerStyle={{ paddingBottom: 24 }}
      showsVerticalScrollIndicator={false}
      keyboardShouldPersistTaps="handled"
    >
      {myKuris.length > 0 && (
        <Panel title="Your Kuri Plans" noPad>
          {myKuris.map((k) => (
            <View key={k.id} style={s.kuriCard}>
              <View style={s.kuriCardTop}>
                <View style={{ flex: 1 }}>
                  <Text style={s.kuriCardName}>{k.name}</Text>
                  <Text style={s.kuriCardDate}>Starts {k.startDate}</Text>
                </View>
                <View style={s.kuriAmtBox}>
                  <Text style={s.kuriAmtVal}>₹{k.contributionAmount.toLocaleString()}</Text>
                  <Text style={s.kuriAmtLbl}>per month</Text>
                </View>
              </View>
              <View style={s.kuriCardRow}>
                <Text style={s.kuriMeta}>Participants</Text>
                <Text style={s.kuriVal}>{k.participantUserIds.length} people</Text>
              </View>
              <View style={s.kuriCardRow}>
                <Text style={s.kuriMeta}>Currency</Text>
                <Text style={s.kuriVal}>{k.currency}</Text>
              </View>
            </View>
          ))}
        </Panel>
      )}

      <Panel title="Create Kuri Plan" subtitle="Set up a new savings rotation">
        <Field label="Plan Name" value={kuriName} onChangeText={setKuriName} placeholder="e.g. Monthly Circle" />
        <Field label="Contribution (₹ per month)" value={kuriAmount} onChangeText={setKuriAmount} placeholder="5000" keyboardType="numeric" />
        <Field label="Start Date (YYYY-MM-DD)" value={kuriDate} onChangeText={setKuriDate} placeholder={new Date().toISOString().slice(0, 10)} />

        <Text style={s.label}>Participants</Text>
        <TouchableOpacity style={s.pickerTrigger} onPress={onOpenPicker} activeOpacity={0.7}>
          <Text style={kuriParticipantIds.length > 0 ? s.pickerTriggerActive : s.pickerTriggerPlaceholder}>
            {kuriParticipantIds.length > 0 ? `${kuriParticipantIds.length} selected` : "Choose participants"}
          </Text>
          <Text style={{ color: C.primary, fontSize: 18 }}>›</Text>
        </TouchableOpacity>

        <View style={s.ruleHeader}>
          <Text style={s.label}>Notification Rules</Text>
          <TouchableOpacity
            style={s.addRuleBtn}
            activeOpacity={0.7}
            onPress={() => setNotifRules((p) => [...p, { id: `r${Date.now()}`, channel: "in_app", beforeDays: "1", emails: "" }])}
          >
            <Text style={s.addRuleBtnText}>+ Add Rule</Text>
          </TouchableOpacity>
        </View>

        {notifRules.map((r) => (
          <View key={r.id} style={s.ruleCard}>
            <View style={s.ruleRow}>
              <TouchableOpacity
                style={[s.ruleChannelBtn, { flex: 1 }]}
                activeOpacity={0.7}
                onPress={() => setNotifRules((p) => p.map((x) => x.id === r.id ? { ...x, channel: x.channel === "email" ? "in_app" : "email" } : x))}
              >
                <Text style={s.ruleChannelText}>{r.channel === "email" ? "📧 Email" : "📱 In-App"}</Text>
              </TouchableOpacity>
              <View style={{ width: 90, marginLeft: 10 }}>
                <Text style={[s.label, { marginBottom: 4 }]}>Days Before</Text>
                <TextInput
                  style={s.input}
                  value={r.beforeDays}
                  onChangeText={(v) => setNotifRules((p) => p.map((x) => x.id === r.id ? { ...x, beforeDays: v } : x))}
                  keyboardType="numeric"
                  placeholderTextColor={C.textDim}
                />
              </View>
              <TouchableOpacity
                style={s.ruleDelBtn}
                activeOpacity={0.7}
                onPress={() => setNotifRules((p) => p.filter((x) => x.id !== r.id))}
              >
                <Text style={s.ruleDelText}>✕</Text>
              </TouchableOpacity>
            </View>
            {r.channel === "email" && (
              <Field
                label="Email Recipients (comma-separated)"
                value={r.emails}
                onChangeText={(v) => setNotifRules((p) => p.map((x) => x.id === r.id ? { ...x, emails: v } : x))}
                placeholder="a@b.com, c@d.com"
                keyboardType="email-address"
              />
            )}
          </View>
        ))}

        <View style={{ height: 6 }} />
        <Btn label="Create Kuri Plan" onPress={onCreateKuri} size="lg" full />
      </Panel>
    </ScrollView>
  );
}

// ─── App ──────────────────────────────────────────────────────────────────────

export default function App() {
  const [data, setData] = useState<AppData>(emptyData);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [authMode, setAuthMode] = useState<AuthMode>("login");
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<Tab>("committee");

  // Auth form
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");

  // No-committee form
  const [committeeName, setCommitteeName] = useState("");
  const [committeeDesc, setCommitteeDesc] = useState("");
  const [memberEmail, setMemberEmail] = useState("");
  const [memberEmails, setMemberEmails] = useState<string[]>([]);

  // Chat — use ref for focus to avoid re-render on keyboard show/hide
  const [chatText, setChatText] = useState("");
  const chatScrollRef = useRef<ScrollView>(null);
  const chatFocusedRef = useRef(false);

  // Kuri form
  const [kuriName, setKuriName] = useState("");
  const [kuriAmount, setKuriAmount] = useState("");
  const [kuriDate, setKuriDate] = useState("");
  const [kuriParticipantIds, setKuriParticipantIds] = useState<string[]>([]);
  const [participantPickerOpen, setParticipantPickerOpen] = useState(false);
  const [notifRules, setNotifRules] = useState<
    Array<{ id: string; channel: "email" | "in_app"; beforeDays: string; emails: string }>
  >([{ id: "r1", channel: "in_app", beforeDays: "2", emails: "" }]);

  // Modals
  const [editOpen, setEditOpen] = useState(false);
  const [editName, setEditName] = useState("");
  const [editDesc, setEditDesc] = useState("");
  const [addMemberOpen, setAddMemberOpen] = useState(false);
  const [addMemberEmail, setAddMemberEmail] = useState("");
  const [memberActionId, setMemberActionId] = useState<string | null>(null);
  const [notifsOpen, setNotifsOpen] = useState(false);

  // Runtime meta-tag injection for web/iOS PWA
  useEffect(() => {
    if (Platform.OS !== "web" || typeof document === "undefined") return;
    const vp = document.querySelector("meta[name='viewport']");
    if (vp) vp.setAttribute("content", "width=device-width, initial-scale=1, viewport-fit=cover");
    const metas: [string, string][] = [
      ["apple-mobile-web-app-capable", "yes"],
      ["apple-mobile-web-app-status-bar-style", "black-translucent"],
      ["theme-color", "#020817"],
    ];
    metas.forEach(([n, content]) => {
      if (!document.querySelector(`meta[name="${n}"]`)) {
        const m = document.createElement("meta");
        m.name = n; m.content = content;
        document.head.appendChild(m);
      }
    });
  }, []);

  // Restore login session from localStorage
  useEffect(() => {
    if (typeof window !== "undefined") {
      const saved = window.localStorage.getItem("kuri_session_user");
      if (saved) { try { setCurrentUser(JSON.parse(saved) as User); } catch {} }
    }
  }, []);

  // Persist login session
  useEffect(() => {
    if (typeof window === "undefined") return;
    if (currentUser) {
      window.localStorage.setItem("kuri_session_user", JSON.stringify(currentUser));
    } else {
      window.localStorage.removeItem("kuri_session_user");
    }
  }, [currentUser]);

  const init = async () => {
    setLoading(true);
    try {
      const withTimeout = <T,>(p: Promise<T>, fallback: T) =>
        Promise.race([p, new Promise<T>((res) => setTimeout(() => res(fallback), 8000))]);
      await withTimeout(kuriService.generateMonthlyInAppNotifications(), undefined);
      const loaded = await withTimeout(kuriService.getData(), emptyData);
      setData(loaded);
    } catch {
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { void init(); }, []);

  const refresh = useCallback(async () => {
    try { setData(await kuriService.getData()); } catch {}
  }, []);

  const activeCommittee = useMemo<Group | undefined>(() => {
    if (!currentUser) return undefined;
    return data.groups.find((g) => g.members.some((m) => m.userId === currentUser.id));
  }, [currentUser, data.groups]);

  // Auto-refresh chat without re-rendering (ref-based focus guard)
  useEffect(() => {
    if (activeTab !== "chat" || !activeCommittee) return;
    const id = setInterval(() => { if (!chatFocusedRef.current) void refresh(); }, 4000);
    return () => clearInterval(id);
  }, [activeTab, activeCommittee, refresh]);

  const members = useMemo<Member[]>(() => {
    if (!activeCommittee) return [];
    return activeCommittee.members
      .map((m) => { const u = data.users.find((u) => u.id === m.userId); return u ? { ...m, user: u } : null; })
      .filter(Boolean) as Member[];
  }, [activeCommittee, data.users]);

  const myRole = useMemo<"admin" | "member">(() => {
    if (!activeCommittee || !currentUser) return "member";
    return activeCommittee.members.find((m) => m.userId === currentUser.id)?.role ?? "member";
  }, [activeCommittee, currentUser]);

  const myKuris = useMemo<KuriPlan[]>(() => {
    if (!activeCommittee) return [];
    return data.kuris.filter((k) => k.groupId === activeCommittee.id);
  }, [activeCommittee, data.kuris]);

  const chatMessages = useMemo<ChatMessage[]>(() => {
    if (!activeCommittee) return [];
    return data.chatMessages
      .filter((m) => m.groupId === activeCommittee.id)
      .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
  }, [activeCommittee, data.chatMessages]);

  const myNotifs = useMemo(() => {
    if (!currentUser) return [];
    return data.notifications
      .filter((n) => n.userId === currentUser.id)
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, 15);
  }, [currentUser, data.notifications]);

  const unreadCount = useMemo(() => myNotifs.filter((n) => !n.read).length, [myNotifs]);

  const pendingInvites = useMemo<Invitation[]>(() => {
    if (!activeCommittee) return [];
    return data.invitations.filter((i) => i.groupId === activeCommittee.id && i.status === "pending");
  }, [activeCommittee, data.invitations]);

  const invitedForMe = useMemo<Invitation[]>(() => {
    if (!currentUser) return [];
    return data.invitations.filter(
      (i) => i.status === "pending" && i.inviteeEmail.toLowerCase() === currentUser.email.toLowerCase()
    );
  }, [currentUser, data.invitations]);

  const selectedMember = useMemo(
    () => members.find((m) => m.user.id === memberActionId) ?? null,
    [memberActionId, members]
  );

  // ── Actions ───────────────────────────────────────────────────────────────

  const doSignup = async () => {
    if (!name.trim() || !email.trim()) { Alert.alert("Missing fields", "Enter your name and email."); return; }
    const user = await kuriService.createUser(name, email);
    setCurrentUser(user);
    await refresh();
  };

  const doLogin = () => {
    if (!email.trim()) { Alert.alert("Missing email", "Enter your email address."); return; }
    const user = data.users.find((u) => u.email.toLowerCase() === email.trim().toLowerCase());
    if (!user) { Alert.alert("Not found", "No account with that email. Please sign up first."); return; }
    setCurrentUser(user);
  };

  const addEmailChip = () => {
    const v = memberEmail.trim().toLowerCase();
    if (!v || memberEmails.includes(v)) return;
    setMemberEmails((p) => [...p, v]);
    setMemberEmail("");
  };

  const createCommittee = async () => {
    if (!currentUser) return;
    if (!committeeName.trim()) { Alert.alert("Missing name", "Enter a committee name."); return; }
    await kuriService.createGroup(committeeName, currentUser.id, memberEmails, committeeDesc);
    setCommitteeName(""); setCommitteeDesc(""); setMemberEmails([]);
    await refresh();
  };

  const joinCommittee = async (code: string) => {
    if (!currentUser) return;
    try {
      await kuriService.joinGroupByInviteCode(code, currentUser.name, currentUser.email);
      await refresh();
      Alert.alert("Joined!", "You are now a member of the committee.");
    } catch (e: unknown) { Alert.alert("Error", e instanceof Error ? e.message : "Failed."); }
  };

  const sendChat = async () => {
    if (!currentUser || !activeCommittee || !chatText.trim()) return;
    const t = chatText.trim();
    setChatText("");
    await kuriService.sendGroupMessage(activeCommittee.id, currentUser.id, t);
    await refresh();
    setTimeout(() => chatScrollRef.current?.scrollToEnd({ animated: true }), 80);
  };

  const createKuri = async () => {
    if (!currentUser || !activeCommittee) return;
    const amount = Number(kuriAmount);
    if (!kuriName.trim() || !kuriDate.trim() || Number.isNaN(amount) || amount <= 0) {
      Alert.alert("Missing fields", "Enter plan name, amount > 0, and start date (YYYY-MM-DD).");
      return;
    }
    try {
      await kuriService.createKuri(
        activeCommittee.id, currentUser.id, kuriName, amount, "INR", kuriDate,
        kuriParticipantIds,
        { rules: notifRules.map((r) => ({ channel: r.channel, beforeDays: Number(r.beforeDays || "0"), emailRecipients: r.emails.split(",").map((v) => v.trim().toLowerCase()).filter(Boolean) })) }
      );
      setKuriName(""); setKuriAmount(""); setKuriDate(""); setKuriParticipantIds([]);
      setNotifRules([{ id: "r1", channel: "in_app", beforeDays: "2", emails: "" }]);
      await refresh();
      Alert.alert("Created!", "Kuri plan created successfully.");
    } catch (e: unknown) { Alert.alert("Error", e instanceof Error ? e.message : "Failed."); }
  };

  const openEdit = () => {
    if (activeCommittee) { setEditName(activeCommittee.name); setEditDesc(activeCommittee.description ?? ""); }
    setEditOpen(true);
  };

  const saveEdit = async () => {
    if (!currentUser || !activeCommittee) return;
    try {
      await kuriService.updateGroupDetails(activeCommittee.id, currentUser.id, editName, editDesc);
      await refresh(); setEditOpen(false);
    } catch (e: unknown) { Alert.alert("Error", e instanceof Error ? e.message : "Failed."); }
  };

  const inviteMember = async () => {
    if (!currentUser || !activeCommittee || !addMemberEmail.trim()) {
      Alert.alert("Missing email", "Enter an email address."); return;
    }
    try {
      await kuriService.addMemberByEmail(activeCommittee.id, currentUser.id, addMemberEmail);
      setAddMemberEmail(""); setAddMemberOpen(false);
      await refresh(); Alert.alert("Invited!", `Invitation sent to ${addMemberEmail}.`);
    } catch (e: unknown) { Alert.alert("Error", e instanceof Error ? e.message : "Failed."); }
  };

  const doRemoveMember = (uid: string, uname: string) => {
    Alert.alert("Remove Member", `Remove ${uname} from the committee?`, [
      { text: "Cancel", style: "cancel" },
      {
        text: "Remove", style: "destructive", onPress: async () => {
          try {
            if (!currentUser || !activeCommittee) return;
            await kuriService.removeMember(activeCommittee.id, currentUser.id, uid);
            setMemberActionId(null); await refresh();
          } catch (e: unknown) { Alert.alert("Error", e instanceof Error ? e.message : "Failed."); }
        },
      },
    ]);
  };

  // ── Loading ────────────────────────────────────────────────────────────────

  if (loading) {
    return (
      <SafeAreaView style={s.safe}>
        <StatusBar style="light" />
        <View style={s.splash}>
          <View style={s.logoMark}><Text style={s.logoText}>C</Text></View>
          <Text style={s.brand}>Committee App</Text>
          <ActivityIndicator color={C.primary} size="large" style={{ marginTop: 32 }} />
          <Text style={[s.meta, { marginTop: 10, fontSize: 14 }]}>Loading…</Text>
        </View>
      </SafeAreaView>
    );
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  if (!currentUser) {
    return (
      <SafeAreaView style={s.safe}>
        <StatusBar style="light" />
        <KeyboardAvoidingView style={{ flex: 1 }} behavior={IS_IOS ? "padding" : undefined}>
          <ScrollView
            contentContainerStyle={s.authShell}
            keyboardShouldPersistTaps="handled"
            showsVerticalScrollIndicator={false}
          >
            <View style={s.authTop}>
              <View style={s.logoMark}><Text style={s.logoText}>C</Text></View>
              <Text style={s.brand}>Committee App</Text>
              <Text style={s.heroText}>
                Manage savings committees, invite members, chat live, and track Kuri plans.
              </Text>
            </View>
            <View style={s.authCard}>
              <View style={s.authToggle}>
                {(["login", "signup"] as AuthMode[]).map((m) => (
                  <TouchableOpacity
                    key={m}
                    style={[s.authTab, authMode === m && s.authTabOn]}
                    onPress={() => setAuthMode(m)}
                    activeOpacity={0.7}
                  >
                    <Text style={[s.authTabText, authMode === m && s.authTabTextOn]}>
                      {m === "login" ? "Sign In" : "Sign Up"}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
              {authMode === "signup" && (
                <Field label="Full Name" value={name} onChangeText={setName} placeholder="Your full name" />
              )}
              <Field
                label="Email Address"
                value={email}
                onChangeText={setEmail}
                placeholder="you@example.com"
                keyboardType="email-address"
              />
              <Btn
                label={authMode === "login" ? "Sign In" : "Create Account"}
                onPress={authMode === "login" ? doLogin : doSignup}
                size="lg"
                full
              />
            </View>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    );
  }

  // ── No Committee ───────────────────────────────────────────────────────────

  if (!activeCommittee) {
    return (
      <SafeAreaView style={s.safe}>
        <StatusBar style="light" />
        <ScrollView
          contentContainerStyle={s.page}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <View style={s.topBar}>
            <View style={s.topLeft}>
              <Avatar name={currentUser.name} size={42} />
              <View style={{ marginLeft: 10 }}>
                <Text style={s.topName} numberOfLines={1}>{currentUser.name}</Text>
                <Text style={s.topEmail} numberOfLines={1}>{currentUser.email}</Text>
              </View>
            </View>
            <Btn label="Sign Out" variant="ghost" size="sm" onPress={() => setCurrentUser(null)} />
          </View>

          {invitedForMe.length > 0 && (
            <Panel title="🎉 You're Invited!" subtitle="Join a committee using your invite code" noPad>
              {invitedForMe.map((inv) => (
                <View key={inv.id} style={s.inviteRow}>
                  <View style={{ flex: 1 }}>
                    <Text style={s.inviteCode}>{inv.inviteCode}</Text>
                    <Text style={s.meta}>Tap Join to accept</Text>
                  </View>
                  <Btn label="Join →" onPress={() => joinCommittee(inv.inviteCode)} size="md" variant="green" />
                </View>
              ))}
            </Panel>
          )}

          <Panel title="Create a Committee" subtitle="Start your own savings group">
            <Field label="Committee Name" value={committeeName} onChangeText={setCommitteeName} placeholder="e.g. Family Savings Circle" />
            <Field label="Description (optional)" value={committeeDesc} onChangeText={setCommitteeDesc} placeholder="Brief description" multiline />
            <View style={s.inlineRow}>
              <View style={{ flex: 1 }}>
                <Field label="Invite Members" value={memberEmail} onChangeText={setMemberEmail} placeholder="member@example.com" keyboardType="email-address" />
              </View>
              <TouchableOpacity style={s.addEmailBtn} onPress={addEmailChip} activeOpacity={0.7}>
                <Text style={s.addEmailBtnText}>+</Text>
              </TouchableOpacity>
            </View>
            {memberEmails.length > 0 && (
              <View style={s.chips}>
                {memberEmails.map((m) => (
                  <TouchableOpacity key={m} style={s.chip} onPress={() => setMemberEmails((p) => p.filter((x) => x !== m))} activeOpacity={0.7}>
                    <Text style={s.chipText}>{m}</Text>
                    <Text style={s.chipX}>×</Text>
                  </TouchableOpacity>
                ))}
              </View>
            )}
            <Btn label="Create Committee" onPress={createCommittee} size="lg" full />
          </Panel>
        </ScrollView>
      </SafeAreaView>
    );
  }

  // ── Main App ───────────────────────────────────────────────────────────────

  return (
    <SafeAreaView style={s.safe}>
      <StatusBar style="light" />

      <View style={s.header}>
        <View style={s.headerLeft}>
          <Avatar name={currentUser.name} size={38} />
          <View style={{ marginLeft: 10, flex: 1 }}>
            <Text style={s.headerName} numberOfLines={1}>{currentUser.name}</Text>
            <Text style={s.headerSub} numberOfLines={1}>{activeCommittee.name}</Text>
          </View>
        </View>
        <View style={s.headerRight}>
          <TouchableOpacity style={s.notifBtn} onPress={() => setNotifsOpen(true)} activeOpacity={0.7}>
            <Text style={{ fontSize: 22 }}>🔔</Text>
            {unreadCount > 0 && (
              <View style={s.notifBadge}>
                <Text style={s.notifBadgeText}>{unreadCount > 9 ? "9+" : unreadCount}</Text>
              </View>
            )}
          </TouchableOpacity>
          <Btn label="Sign Out" variant="ghost" size="sm" onPress={() => setCurrentUser(null)} />
        </View>
      </View>

      <View style={{ flex: 1 }}>
        {activeTab === "committee" && (
          <CommitteeTabView
            committee={activeCommittee}
            members={members}
            myRole={myRole}
            kuris={myKuris}
            msgCount={chatMessages.length}
            pendingInvites={pendingInvites}
            onEdit={openEdit}
          />
        )}
        {activeTab === "members" && (
          <MembersTabView
            members={members}
            pendingInvites={pendingInvites}
            myRole={myRole}
            currentUserId={currentUser.id}
            onInvite={() => setAddMemberOpen(true)}
            onMemberAction={setMemberActionId}
          />
        )}
        {activeTab === "chat" && (
          <ChatTabView
            chatMessages={chatMessages}
            currentUser={currentUser}
            chatText={chatText}
            onChangeText={setChatText}
            onSend={sendChat}
            scrollRef={chatScrollRef}
            onFocusChange={(v) => { chatFocusedRef.current = v; }}
          />
        )}
        {activeTab === "kuri" && (
          <KuriTabView
            myKuris={myKuris}
            members={members}
            kuriName={kuriName} setKuriName={setKuriName}
            kuriAmount={kuriAmount} setKuriAmount={setKuriAmount}
            kuriDate={kuriDate} setKuriDate={setKuriDate}
            kuriParticipantIds={kuriParticipantIds}
            onOpenPicker={() => setParticipantPickerOpen(true)}
            notifRules={notifRules} setNotifRules={setNotifRules}
            onCreateKuri={createKuri}
          />
        )}
      </View>

      <TabBar active={activeTab} onChange={setActiveTab} />

      {/* ── Edit Committee ── */}
      <Modal visible={editOpen} transparent animationType="slide">
        <View style={s.overlay}>
          <TouchableOpacity style={{ flex: 1 }} onPress={() => setEditOpen(false)} activeOpacity={1} />
          <View style={s.sheet}>
            <View style={s.handle} />
            <ScrollView keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
              <Text style={s.sheetTitle}>Edit Committee</Text>
              <Field label="Committee Name" value={editName} onChangeText={setEditName} />
              <Field label="Description" value={editDesc} onChangeText={setEditDesc} multiline />
              <Btn label="Save Changes" onPress={saveEdit} size="lg" full />
              <View style={{ height: 10 }} />
              <Btn label="Cancel" variant="outline" onPress={() => setEditOpen(false)} size="lg" full />
              <View style={{ height: 20 }} />
            </ScrollView>
          </View>
        </View>
      </Modal>

      {/* ── Invite Member ── */}
      <Modal visible={addMemberOpen} transparent animationType="slide">
        <View style={s.overlay}>
          <TouchableOpacity style={{ flex: 1 }} onPress={() => { setAddMemberOpen(false); setAddMemberEmail(""); }} activeOpacity={1} />
          <View style={s.sheetSm}>
            <View style={s.handle} />
            <Text style={s.sheetTitle}>Invite Member</Text>
            <Field
              label="Email Address"
              value={addMemberEmail}
              onChangeText={setAddMemberEmail}
              placeholder="member@example.com"
              keyboardType="email-address"
              autoFocus
            />
            <Btn label="Send Invitation" onPress={inviteMember} size="lg" full />
            <View style={{ height: 10 }} />
            <Btn label="Cancel" variant="outline" onPress={() => { setAddMemberOpen(false); setAddMemberEmail(""); }} size="lg" full />
            <View style={{ height: 20 }} />
          </View>
        </View>
      </Modal>

      {/* ── Member Actions ── */}
      <Modal visible={!!memberActionId} transparent animationType="slide">
        <View style={s.overlay}>
          <TouchableOpacity style={{ flex: 1 }} onPress={() => setMemberActionId(null)} activeOpacity={1} />
          <View style={s.sheetSm}>
            <View style={s.handle} />
            {selectedMember && (
              <>
                <View style={s.memberActionHead}>
                  <Avatar name={selectedMember.user.name} size={52} />
                  <View style={{ marginLeft: 14, flex: 1 }}>
                    <Text style={s.memberActionName} numberOfLines={1}>{selectedMember.user.name}</Text>
                    <Text style={s.memberActionEmail} numberOfLines={1}>{selectedMember.user.email}</Text>
                  </View>
                </View>
                <Btn
                  label="Remove from Committee"
                  variant="danger"
                  size="lg"
                  full
                  onPress={() => doRemoveMember(selectedMember.user.id, selectedMember.user.name)}
                />
                <View style={{ height: 10 }} />
              </>
            )}
            <Btn label="Cancel" variant="outline" size="lg" full onPress={() => setMemberActionId(null)} />
            <View style={{ height: 20 }} />
          </View>
        </View>
      </Modal>

      {/* ── Participant Picker ── */}
      <Modal visible={participantPickerOpen} transparent animationType="slide">
        <View style={s.overlay}>
          <TouchableOpacity style={{ flex: 1 }} onPress={() => setParticipantPickerOpen(false)} activeOpacity={1} />
          <View style={s.sheet}>
            <View style={s.handle} />
            <Text style={s.sheetTitle}>Select Participants</Text>
            <ScrollView style={{ maxHeight: 360 }} showsVerticalScrollIndicator={false}>
              {members.map((m) => {
                const sel = kuriParticipantIds.includes(m.user.id);
                return (
                  <TouchableOpacity
                    key={m.user.id}
                    style={[s.pickerRow, sel && s.pickerRowSel]}
                    onPress={() => setKuriParticipantIds((p) =>
                      p.includes(m.user.id) ? p.filter((id) => id !== m.user.id) : [...p, m.user.id]
                    )}
                    activeOpacity={0.7}
                  >
                    <Avatar name={m.user.name} size={38} />
                    <View style={{ flex: 1, marginLeft: 10 }}>
                      <Text style={s.pickerName}>{m.user.name}</Text>
                      <Text style={s.pickerEmail}>{m.user.email}</Text>
                    </View>
                    <View style={[s.checkbox, sel && s.checkboxSel]}>
                      {sel && <Text style={s.checkmark}>✓</Text>}
                    </View>
                  </TouchableOpacity>
                );
              })}
            </ScrollView>
            <View style={{ height: 16 }} />
            <Btn
              label={kuriParticipantIds.length > 0 ? `Confirm (${kuriParticipantIds.length})` : "Confirm"}
              onPress={() => setParticipantPickerOpen(false)}
              size="lg"
              full
            />
            <View style={{ height: 20 }} />
          </View>
        </View>
      </Modal>

      {/* ── Notifications ── */}
      <Modal visible={notifsOpen} transparent animationType="slide">
        <View style={s.overlay}>
          <TouchableOpacity style={{ flex: 1 }} onPress={() => setNotifsOpen(false)} activeOpacity={1} />
          <View style={s.sheet}>
            <View style={s.handle} />
            <Text style={s.sheetTitle}>Notifications</Text>
            <ScrollView style={{ maxHeight: 420 }} showsVerticalScrollIndicator={false}>
              {myNotifs.length === 0
                ? <EmptyState icon="🔔" text="No notifications yet." />
                : myNotifs.map((n) => (
                  <View key={n.id} style={[s.notifItem, !n.read && s.notifItemUnread]}>
                    <View style={{ flex: 1 }}>
                      <Text style={s.notifItemTitle}>{n.title}</Text>
                      <Text style={s.notifItemMsg}>{n.message.replace(/ref:.*/, "").trim()}</Text>
                    </View>
                    {!n.read && <View style={s.unreadDot} />}
                  </View>
                ))
              }
            </ScrollView>
            <View style={{ height: 16 }} />
            <Btn label="Close" variant="outline" onPress={() => setNotifsOpen(false)} size="lg" full />
            <View style={{ height: 20 }} />
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: C.bg },

  splash: { flex: 1, alignItems: "center", justifyContent: "center" },
  logoMark: { width: 72, height: 72, borderRadius: 36, backgroundColor: C.primaryMid, alignItems: "center", justifyContent: "center", marginBottom: 14 },
  logoText: { color: "#fff", fontSize: 34, fontWeight: "900" },
  brand: { color: C.text, fontSize: 30, fontWeight: "900" },

  authShell: { flexGrow: 1, width: "100%", maxWidth: MAX_W, alignSelf: "center", justifyContent: "center", padding: 20, paddingBottom: 40 },
  authTop: { alignItems: "center", marginBottom: 28 },
  heroText: { color: C.textMuted, fontSize: 14, textAlign: "center", lineHeight: 21, marginTop: 8, maxWidth: 280 },
  authCard: { backgroundColor: C.surface, borderRadius: 20, borderWidth: 1, borderColor: C.border, padding: 18 },
  authToggle: { flexDirection: "row", backgroundColor: C.bg, borderRadius: 12, padding: 4, marginBottom: 18 },
  authTab: { flex: 1, paddingVertical: 10, borderRadius: 9, alignItems: "center" },
  authTabOn: { backgroundColor: C.primaryMid },
  authTabText: { color: C.textMuted, fontWeight: "700", fontSize: 14 },
  authTabTextOn: { color: "#fff" },

  page: { width: "100%", maxWidth: MAX_W, alignSelf: "center", padding: 16, paddingBottom: 40 },
  topBar: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 18 },
  topLeft: { flexDirection: "row", alignItems: "center", flex: 1, marginRight: 8 },
  topName: { color: C.text, fontWeight: "800", fontSize: 16 },
  topEmail: { color: C.textMuted, fontSize: 12 },

  header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: 14, paddingVertical: 10, borderBottomWidth: 1, borderBottomColor: C.border, backgroundColor: C.surface },
  headerLeft: { flexDirection: "row", alignItems: "center", flex: 1, marginRight: 8 },
  headerRight: { flexDirection: "row", alignItems: "center", gap: 6 },
  headerName: { color: C.text, fontWeight: "800", fontSize: 15 },
  headerSub: { color: C.textMuted, fontSize: 12 },

  tabBar: { flexDirection: "row", backgroundColor: C.surface, borderTopWidth: 1, borderTopColor: C.border, paddingTop: 6, paddingBottom: Platform.OS === "web" ? 10 : 4 },
  tabItem: { flex: 1, alignItems: "center", paddingVertical: 2 },
  tabPill: { width: 52, height: 30, borderRadius: 15, alignItems: "center", justifyContent: "center" },
  tabPillOn: { backgroundColor: C.primaryLight },
  tabLabel: { color: C.textDim, fontSize: 10, fontWeight: "600", marginTop: 3 },
  tabLabelOn: { color: C.primary },
  tabContent: { flex: 1, paddingHorizontal: 14, paddingTop: 14 },

  panel: { backgroundColor: C.surface, borderRadius: 16, borderWidth: 1, borderColor: C.border, marginBottom: 14, overflow: "hidden" },
  panelHead: { paddingHorizontal: 14, paddingTop: 14, paddingBottom: 6 },
  panelTitle: { color: C.text, fontSize: 17, fontWeight: "800" },
  panelSub: { color: C.textMuted, fontSize: 13, marginTop: 2, marginBottom: 4 },
  panelBody: { padding: 14, paddingTop: 10 },

  label: { color: C.textMuted, fontSize: 13, fontWeight: "600", marginBottom: 5 },
  input: { borderWidth: 1, borderColor: C.borderStrong, backgroundColor: C.inputBg, color: C.text, borderRadius: 10, paddingVertical: 12, paddingHorizontal: 14, fontSize: 16 },

  inlineRow: { flexDirection: "row", gap: 8, alignItems: "flex-end" },
  addEmailBtn: { width: 46, height: 46, backgroundColor: C.primaryLight, borderRadius: 10, alignItems: "center", justifyContent: "center", marginBottom: 14 },
  addEmailBtnText: { color: C.primary, fontSize: 22, fontWeight: "800" },
  chips: { flexDirection: "row", flexWrap: "wrap", gap: 6, marginBottom: 14 },
  chip: { backgroundColor: C.border, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 6, flexDirection: "row", alignItems: "center", gap: 4 },
  chipText: { color: C.textSub, fontSize: 12 },
  chipX: { color: C.textMuted, fontSize: 14, fontWeight: "700" },

  btn: { borderRadius: 12, alignItems: "center", paddingHorizontal: 16 },
  btnText: { fontWeight: "800" },

  meta: { color: C.textMuted, fontSize: 13 },

  inviteRow: { flexDirection: "row", alignItems: "center", padding: 16, gap: 14 },
  inviteCode: { color: C.warn, fontSize: 22, fontWeight: "900", letterSpacing: 2, marginBottom: 2 },

  editBtn: { backgroundColor: C.primaryLight, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 7, flexShrink: 0 },
  editBtnText: { color: C.primary, fontSize: 13, fontWeight: "700" },

  hero: { backgroundColor: C.surface, borderRadius: 16, borderWidth: 1, borderColor: C.border, marginBottom: 14, overflow: "hidden" },
  heroTop: { flexDirection: "row", alignItems: "flex-start", padding: 14, paddingBottom: 12 },
  heroIcon: { width: 52, height: 52, borderRadius: 14, backgroundColor: C.primaryMid, alignItems: "center", justifyContent: "center", flexShrink: 0 },
  heroIconText: { color: "#fff", fontSize: 20, fontWeight: "900" },
  heroName: { color: C.text, fontSize: 18, fontWeight: "800", marginBottom: 2 },
  heroDesc: { color: C.textMuted, fontSize: 13, lineHeight: 18 },
  statsRow: { flexDirection: "row", borderTopWidth: 1, borderTopColor: C.border, paddingVertical: 14 },
  stat: { flex: 1, alignItems: "center" },
  statVal: { color: C.primary, fontSize: 22, fontWeight: "900" },
  statLbl: { color: C.textMuted, fontSize: 11, marginTop: 2 },
  statDivider: { width: 1, backgroundColor: C.border },
  roleRow: { flexDirection: "row", alignItems: "center", marginBottom: 14, paddingHorizontal: 2 },

  rowItem: { flexDirection: "row", alignItems: "center", padding: 12, borderTopWidth: 1, borderTopColor: C.border, gap: 10 },
  rowItemIcon: { width: 34, height: 34, borderRadius: 8, backgroundColor: C.border, alignItems: "center", justifyContent: "center", flexShrink: 0 },
  rowItemName: { color: C.text, fontWeight: "700", fontSize: 14 },
  rowItemMeta: { color: C.textMuted, fontSize: 12, marginTop: 2 },
  codePill: { backgroundColor: "#431407", borderRadius: 8, paddingHorizontal: 8, paddingVertical: 4, flexShrink: 0 },
  codeText: { color: C.warn, fontWeight: "800", letterSpacing: 1, fontSize: 12 },

  sectionHead: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 12 },
  sectionTitle: { color: C.text, fontSize: 16, fontWeight: "800" },
  inviteChipBtn: { backgroundColor: C.blueDark, borderRadius: 20, paddingHorizontal: 14, paddingVertical: 8 },
  inviteChipText: { color: C.blueFg, fontSize: 13, fontWeight: "700" },

  memberCard: { flexDirection: "row", alignItems: "center", backgroundColor: C.surface, borderRadius: 14, borderWidth: 1, borderColor: C.border, padding: 12, marginBottom: 8, gap: 12 },
  memberInfo: { flex: 1, minWidth: 0 },
  memberNameRow: { flexDirection: "row", alignItems: "center", gap: 8, marginBottom: 3 },
  memberName: { color: C.text, fontWeight: "700", fontSize: 14, flexShrink: 1 },
  memberEmail: { color: C.textMuted, fontSize: 12 },
  moreBtn: { width: 38, height: 38, borderRadius: 10, backgroundColor: C.border, alignItems: "center", justifyContent: "center", flexShrink: 0 },
  moreBtnText: { color: C.textSub, fontWeight: "700", letterSpacing: 1 },
  dividerRow: { paddingVertical: 10, paddingHorizontal: 2 },
  dividerText: { color: C.textDim, fontSize: 11, fontWeight: "700", textTransform: "uppercase", letterSpacing: 0.6 },

  // Chat — alignItems:center keeps button perfectly vertically centred with input
  chatBar: { flexDirection: "row", alignItems: "center", paddingHorizontal: 12, paddingVertical: 10, gap: 8, borderTopWidth: 1, borderTopColor: C.border, backgroundColor: C.surface },
  chatInput: { flex: 1, backgroundColor: C.inputBg, borderWidth: 1, borderColor: C.borderStrong, borderRadius: 22, paddingHorizontal: 16, paddingVertical: 11, color: C.text, fontSize: 16, lineHeight: 20 },
  sendBtn: { width: 44, height: 44, borderRadius: 22, backgroundColor: C.primary, alignItems: "center", justifyContent: "center", flexShrink: 0 },
  sendBtnOff: { backgroundColor: C.border },
  sendIcon: { color: C.primaryFg, fontSize: 15, fontWeight: "900" },
  msgRow: { flexDirection: "row", marginBottom: 10, alignItems: "flex-end" },
  msgOwn: { justifyContent: "flex-end" },
  msgOther: { justifyContent: "flex-start" },
  bubble: { maxWidth: "78%", borderRadius: 18, padding: 10, paddingHorizontal: 13 },
  bubbleOwn: { backgroundColor: C.primaryMid, borderBottomRightRadius: 4 },
  bubbleOther: { backgroundColor: C.surface, borderWidth: 1, borderColor: C.border, borderBottomLeftRadius: 4 },
  bubbleSender: { color: C.accent, fontSize: 11, fontWeight: "700", marginBottom: 3 },
  bubbleText: { color: C.text, fontSize: 15, lineHeight: 21 },
  bubbleTextOwn: { color: "#e0f9ff" },
  bubbleTime: { color: C.textDim, fontSize: 10, marginTop: 4, textAlign: "right" },
  bubbleTimeOwn: { color: "#a5f3fc" },

  // Kuri
  kuriCard: { borderTopWidth: 1, borderTopColor: C.border },
  kuriCardTop: { flexDirection: "row", alignItems: "flex-start", padding: 14, paddingBottom: 8 },
  kuriCardName: { color: C.text, fontWeight: "800", fontSize: 15, marginBottom: 2 },
  kuriCardDate: { color: C.textMuted, fontSize: 12 },
  kuriAmtBox: { alignItems: "flex-end", flexShrink: 0 },
  kuriAmtVal: { color: C.primary, fontSize: 20, fontWeight: "900" },
  kuriAmtLbl: { color: C.textMuted, fontSize: 11 },
  kuriCardRow: { flexDirection: "row", justifyContent: "space-between", paddingHorizontal: 14, paddingVertical: 7, borderTopWidth: 1, borderTopColor: C.border },
  kuriMeta: { color: C.textMuted, fontSize: 13 },
  kuriVal: { color: C.textSub, fontSize: 13, fontWeight: "700" },

  pickerTrigger: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", borderWidth: 1, borderColor: C.borderStrong, backgroundColor: C.inputBg, borderRadius: 10, paddingVertical: 12, paddingHorizontal: 14, marginBottom: 14 },
  pickerTriggerPlaceholder: { color: C.textDim, fontSize: 16 },
  pickerTriggerActive: { color: C.text, fontSize: 16, fontWeight: "600" },
  ruleHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 8 },
  addRuleBtn: { backgroundColor: C.blueDark, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 },
  addRuleBtnText: { color: C.blueFg, fontSize: 12, fontWeight: "700" },
  ruleCard: { backgroundColor: C.inputBg, borderRadius: 10, borderWidth: 1, borderColor: C.borderStrong, padding: 12, marginBottom: 8 },
  ruleRow: { flexDirection: "row", alignItems: "center", gap: 8, marginBottom: 8 },
  ruleChannelBtn: { borderWidth: 1, borderColor: C.borderStrong, borderRadius: 8, paddingVertical: 12, paddingHorizontal: 12 },
  ruleChannelText: { color: C.text, fontWeight: "600" },
  ruleDelBtn: { width: 40, height: 40, borderRadius: 8, backgroundColor: C.dangerDark, alignItems: "center", justifyContent: "center", flexShrink: 0 },
  ruleDelText: { color: C.dangerFg, fontWeight: "700" },

  overlay: { flex: 1, backgroundColor: "rgba(2,6,23,0.82)", justifyContent: "flex-end" },
  sheet: { backgroundColor: C.surface, borderTopLeftRadius: 24, borderTopRightRadius: 24, borderWidth: 1, borderBottomWidth: 0, borderColor: C.borderStrong, padding: 20, maxHeight: "90%", width: "100%", maxWidth: MAX_W, alignSelf: "center" },
  sheetSm: { backgroundColor: C.surface, borderTopLeftRadius: 24, borderTopRightRadius: 24, borderWidth: 1, borderBottomWidth: 0, borderColor: C.borderStrong, padding: 20, width: "100%", maxWidth: MAX_W, alignSelf: "center" },
  handle: { width: 40, height: 4, borderRadius: 2, backgroundColor: C.borderStrong, alignSelf: "center", marginBottom: 16 },
  sheetTitle: { color: C.text, fontSize: 20, fontWeight: "800", marginBottom: 16 },

  memberActionHead: { flexDirection: "row", alignItems: "center", backgroundColor: C.inputBg, borderRadius: 14, padding: 14, marginBottom: 16 },
  memberActionName: { color: C.text, fontWeight: "800", fontSize: 16 },
  memberActionEmail: { color: C.textMuted, fontSize: 12, marginTop: 2 },

  pickerRow: { flexDirection: "row", alignItems: "center", padding: 12, borderRadius: 12, borderWidth: 1, borderColor: C.border, marginBottom: 8, backgroundColor: C.inputBg },
  pickerRowSel: { borderColor: C.primary, backgroundColor: C.primaryLight },
  pickerName: { color: C.text, fontWeight: "700" },
  pickerEmail: { color: C.textMuted, fontSize: 12 },
  checkbox: { width: 24, height: 24, borderRadius: 6, borderWidth: 2, borderColor: C.borderStrong, alignItems: "center", justifyContent: "center", flexShrink: 0 },
  checkboxSel: { backgroundColor: C.primary, borderColor: C.primary },
  checkmark: { color: C.primaryFg, fontWeight: "900", fontSize: 13 },

  notifBtn: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  notifBadge: { position: "absolute", top: 4, right: 4, minWidth: 16, height: 16, borderRadius: 8, backgroundColor: C.danger, alignItems: "center", justifyContent: "center", paddingHorizontal: 3 },
  notifBadgeText: { color: "#fff", fontSize: 10, fontWeight: "700" },
  notifItem: { flexDirection: "row", alignItems: "center", borderWidth: 1, borderColor: C.border, borderRadius: 12, padding: 12, marginBottom: 8, backgroundColor: C.inputBg, gap: 10 },
  notifItemUnread: { borderColor: C.primaryMid, backgroundColor: "#0a1829" },
  notifItemTitle: { color: C.text, fontWeight: "700", fontSize: 14, marginBottom: 3 },
  notifItemMsg: { color: C.textMuted, fontSize: 13, lineHeight: 18 },
  unreadDot: { width: 8, height: 8, borderRadius: 4, backgroundColor: C.primary, flexShrink: 0 },
});
