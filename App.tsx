import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  Image,
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
import { AppData, ChatMessage, Group, Invitation, KuriPayment, KuriPlan, User } from "./src/types";
import {
  AppLogo, IcoBell, IcoCalendar, IcoChat, IcoCheck, IcoCopy, IcoEdit,
  IcoImage, IcoKuri, IcoCommittee, IcoMembers, IcoMore, IcoPlus, IcoQr,
  IcoReceipt, IcoSend, IcoSignOut, IcoTrash, IcoUpload, IcoX,
} from "./src/icons";

const emptyData: AppData = {
  users: [], groups: [], invitations: [], kuris: [], payments: [], chatMessages: [], notifications: [],
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

// ─── Date helpers ─────────────────────────────────────────────────────────────

const MONTHS_SHORT = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

function daysInMonth(month: number, year: number) {
  return new Date(year, month, 0).getDate();
}

function formatDateDisplay(iso: string) {
  if (!iso || !iso.match(/^\d{4}-\d{2}-\d{2}$/)) return "";
  const [y, m, d] = iso.split("-").map(Number);
  return `${String(d).padStart(2, "0")} ${MONTHS_SHORT[m - 1]} ${y}`;
}

// ─── Push notification helpers (web only) ────────────────────────────────────

function requestPushPermission() {
  if (Platform.OS !== "web" || typeof Notification === "undefined") return;
  if (Notification.permission === "default") {
    Notification.requestPermission().catch(() => {});
  }
}

function firePushNotification(title: string, body: string) {
  if (Platform.OS !== "web" || typeof Notification === "undefined") return;
  if (Notification.permission !== "granted") return;
  try { new Notification(title, { body, silent: false }); } catch {}
}

// ─── Date picker column ───────────────────────────────────────────────────────

const COL_ITEM_H = 48;

function ColPicker({ items, selected, onSelect, renderLabel }: {
  items: number[]; selected: number;
  onSelect: (v: number) => void; renderLabel: (v: number) => string;
}) {
  const scrollRef = useRef<ScrollView>(null);
  const didMount = useRef(false);

  useEffect(() => {
    const idx = items.indexOf(selected);
    if (idx < 0) return;
    const delay = didMount.current ? 0 : 80;
    setTimeout(() => {
      scrollRef.current?.scrollTo({ y: idx * COL_ITEM_H, animated: didMount.current });
    }, delay);
    didMount.current = true;
  }, [selected, items.length]); // re-scroll when items length changes (day list after month change)

  return (
    <View style={{ flex: 1, position: "relative" }}>
      {/* centre-row highlight */}
      <View
        pointerEvents="none"
        style={{
          position: "absolute", top: COL_ITEM_H * 2, left: 3, right: 3,
          height: COL_ITEM_H, borderRadius: 10,
          backgroundColor: C.primaryLight, borderWidth: 1, borderColor: C.primaryMid,
        }}
      />
      <ScrollView
        ref={scrollRef}
        style={{ height: COL_ITEM_H * 5 }}
        contentContainerStyle={{ paddingVertical: COL_ITEM_H * 2 }}
        showsVerticalScrollIndicator={false}
        snapToInterval={COL_ITEM_H}
        decelerationRate="fast"
        onMomentumScrollEnd={(e) => {
          const idx = Math.round(e.nativeEvent.contentOffset.y / COL_ITEM_H);
          const clamped = Math.max(0, Math.min(idx, items.length - 1));
          onSelect(items[clamped]);
        }}
        onScrollEndDrag={(e) => {
          const idx = Math.round(e.nativeEvent.contentOffset.y / COL_ITEM_H);
          const clamped = Math.max(0, Math.min(idx, items.length - 1));
          onSelect(items[clamped]);
        }}
      >
        {items.map((v) => (
          <TouchableOpacity
            key={v}
            style={{ height: COL_ITEM_H, alignItems: "center", justifyContent: "center" }}
            onPress={() => onSelect(v)}
            activeOpacity={0.7}
          >
            <Text style={[
              { color: C.textDim, fontSize: 16 },
              v === selected && { color: C.primary, fontSize: 18, fontWeight: "700" },
            ]}>
              {renderLabel(v)}
            </Text>
          </TouchableOpacity>
        ))}
      </ScrollView>
    </View>
  );
}

// ─── Date picker modal ────────────────────────────────────────────────────────

function DatePickerModal({ visible, value, onChange, onClose }: {
  visible: boolean; value: string; onChange: (d: string) => void; onClose: () => void;
}) {
  const now = new Date();
  const cy = now.getFullYear();

  const parseISO = (s: string) => {
    if (s?.match(/^\d{4}-\d{2}-\d{2}$/)) {
      const [y, m, d] = s.split("-").map(Number);
      return { y, m, d };
    }
    return { y: cy, m: now.getMonth() + 1, d: now.getDate() };
  };

  const init = parseISO(value);
  const [selYear, setSelYear]   = useState(init.y);
  const [selMonth, setSelMonth] = useState(init.m);
  const [selDay, setSelDay]     = useState(init.d);

  // Reset when opened
  useEffect(() => {
    if (visible) { const p = parseISO(value); setSelYear(p.y); setSelMonth(p.m); setSelDay(p.d); }
  }, [visible]);

  const maxDay = daysInMonth(selMonth, selYear);
  const yearList  = useMemo(() => Array.from({ length: 6 }, (_, i) => cy + i), [cy]);
  const monthList = useMemo(() => Array.from({ length: 12 }, (_, i) => i + 1), []);
  const dayList   = useMemo(() => Array.from({ length: maxDay }, (_, i) => i + 1), [maxDay]);

  useEffect(() => { if (selDay > maxDay) setSelDay(maxDay); }, [maxDay]);

  const preview = `${String(Math.min(selDay, maxDay)).padStart(2, "0")} ${MONTHS_SHORT[selMonth - 1]} ${selYear}`;

  const confirm = () => {
    const d = String(Math.min(selDay, maxDay)).padStart(2, "0");
    const m = String(selMonth).padStart(2, "0");
    onChange(`${selYear}-${m}-${d}`);
    onClose();
  };

  return (
    <Modal visible={visible} transparent animationType="slide">
      <View style={s.overlay}>
        <TouchableOpacity style={{ flex: 1 }} onPress={onClose} activeOpacity={1} />
        <View style={s.sheet}>
          <View style={s.handle} />
          <Text style={s.sheetTitle}>Select Start Date</Text>

          <View style={{ flexDirection: "row", marginBottom: 6 }}>
            {["DAY", "MONTH", "YEAR"].map((lbl) => (
              <Text key={lbl} style={{ flex: 1, textAlign: "center", color: C.textMuted, fontSize: 11, fontWeight: "700", letterSpacing: 0.5 }}>
                {lbl}
              </Text>
            ))}
          </View>

          <View style={{ flexDirection: "row", gap: 6 }}>
            <ColPicker items={dayList}   selected={selDay}   onSelect={setSelDay}   renderLabel={(v) => String(v).padStart(2, "0")} />
            <ColPicker items={monthList} selected={selMonth} onSelect={setSelMonth} renderLabel={(v) => MONTHS_SHORT[v - 1]} />
            <ColPicker items={yearList}  selected={selYear}  onSelect={setSelYear}  renderLabel={(v) => String(v)} />
          </View>

          <View style={s.datePreviewRow}>
            <Text style={s.datePreviewLabel}>Selected</Text>
            <Text style={s.datePreviewValue}>{preview}</Text>
          </View>

          <Btn label="Confirm Date" onPress={confirm} size="lg" full />
          <View style={{ height: 10 }} />
          <Btn label="Cancel" variant="outline" onPress={onClose} size="lg" full />
          <View style={{ height: 20 }} />
        </View>
      </View>
    </Modal>
  );
}

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

type TabDef = { id: Tab; label: string; Icon: (p: { color: string; size: number }) => React.ReactElement };
const TABS: TabDef[] = [
  { id: "committee", label: "Committee", Icon: ({ color, size }) => <IcoCommittee color={color} size={size} /> },
  { id: "members",   label: "Members",   Icon: ({ color, size }) => <IcoMembers   color={color} size={size} /> },
  { id: "chat",      label: "Chat",      Icon: ({ color, size }) => <IcoChat      color={color} size={size} /> },
  { id: "kuri",      label: "Kuri",      Icon: ({ color, size }) => <IcoKuri      color={color} size={size} /> },
];

function TabBar({ active, onChange }: { active: Tab; onChange: (t: Tab) => void }) {
  return (
    <View nativeID="tab-bar-safe" style={s.tabBar}>
      {TABS.map((t) => {
        const on = active === t.id;
        return (
          <TouchableOpacity key={t.id} onPress={() => onChange(t.id)} style={s.tabItem} activeOpacity={0.7}>
            <View style={[s.tabPill, on && s.tabPillOn]}>
              <t.Icon color={on ? C.primary : C.textDim} size={20} />
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

type NotifRule = { id: string; channel: "email" | "in_app"; beforeDays: string; emails: string };

type KuriTabProps = {
  myKuris: KuriPlan[];
  members: Member[];
  currentUserEmail: string;
  currentUserId: string;
  kuriName: string; setKuriName: (v: string) => void;
  kuriAmount: string; setKuriAmount: (v: string) => void;
  kuriDate: string; setKuriDate: (v: string) => void;
  kuriUpiId: string; setKuriUpiId: (v: string) => void;
  kuriQrBase64: string | undefined; setKuriQrBase64: (v: string | undefined) => void;
  kuriParticipantIds: string[];
  onOpenPicker: () => void;
  notifRules: NotifRule[];
  setNotifRules: React.Dispatch<React.SetStateAction<NotifRule[]>>;
  onCreateKuri: () => void;
  onManageKuri: (kuriId: string) => void;
};

function KuriTabView({
  myKuris, currentUserEmail, currentUserId, kuriName, setKuriName, kuriAmount, setKuriAmount,
  kuriDate, setKuriDate, kuriUpiId, setKuriUpiId, kuriQrBase64, setKuriQrBase64,
  kuriParticipantIds, onOpenPicker,
  notifRules, setNotifRules, onCreateKuri, onManageKuri,
}: KuriTabProps) {
  const [datePickerOpen, setDatePickerOpen] = useState(false);
  const dateDisplay = formatDateDisplay(kuriDate);

  const step = (ruleId: string, delta: number) =>
    setNotifRules((p) => p.map((x) =>
      x.id === ruleId ? { ...x, beforeDays: String(Math.max(0, Math.min(30, Number(x.beforeDays || "0") + delta))) } : x
    ));

  return (
    <View style={{ flex: 1 }}>
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
                    <Text style={s.kuriCardDate}>Starts {formatDateDisplay(k.startDate) || k.startDate}</Text>
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
                  <Text style={s.kuriMeta}>UPI</Text>
                  <Text style={[s.kuriVal, !k.upiId && { color: C.textDim }]}>
                    {k.upiId || (k.createdBy === currentUserId ? "Not set" : "—")}
                  </Text>
                </View>
                <TouchableOpacity
                  style={s.kuriManageBtn}
                  onPress={() => onManageKuri(k.id)}
                  activeOpacity={0.7}
                >
                  <IcoMore color={C.primary} size={16} />
                  <Text style={s.kuriManageBtnText}>
                    {k.createdBy === currentUserId ? "Manage Plan" : "Payments"}
                  </Text>
                </TouchableOpacity>
              </View>
            ))}
          </Panel>
        )}

        <Panel title="Create Kuri Plan" subtitle="Set up a new savings rotation">
          <Field label="Plan Name" value={kuriName} onChangeText={setKuriName} placeholder="e.g. Monthly Circle" />
          <Field label="Contribution (₹ per month)" value={kuriAmount} onChangeText={setKuriAmount} placeholder="5000" keyboardType="numeric" />

          {/* Date picker trigger */}
          <Text style={s.label}>Start Date</Text>
          <TouchableOpacity style={s.dateTrigger} onPress={() => setDatePickerOpen(true)} activeOpacity={0.7}>
            <View style={{ flexDirection: "row", alignItems: "center", gap: 8 }}>
              <Text style={{ fontSize: 20 }}>📅</Text>
              <Text style={dateDisplay ? s.dateTriggerActive : s.dateTriggerPlaceholder}>
                {dateDisplay || "Select start date"}
              </Text>
            </View>
            <Text style={{ color: C.primary, fontSize: 13, fontWeight: "600" }}>
              {dateDisplay ? "Change" : "Pick"}
            </Text>
          </TouchableOpacity>

          {/* UPI ID (required) */}
          <View style={{ marginBottom: 6 }}>
            <Text style={s.label}>
              Your UPI ID <Text style={{ color: C.danger }}>*</Text>
            </Text>
            <TextInput
              style={s.input}
              value={kuriUpiId}
              onChangeText={setKuriUpiId}
              placeholder="example@upi (members pay to this)"
              placeholderTextColor={C.textDim}
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType="email-address"
            />
          </View>

          {/* QR Code upload */}
          <Text style={[s.label, { marginBottom: 6 }]}>Payment QR Code <Text style={{ color: C.textDim, fontWeight: "400" }}>(optional)</Text></Text>
          <TouchableOpacity
            style={[s.uploadBox, { marginBottom: 14 }]}
            onPress={() => webPickFile("image/*", 500 * 1024, (b64) => setKuriQrBase64(b64))}
            activeOpacity={0.75}
          >
            {kuriQrBase64 ? (
              <View style={{ flexDirection: "row", alignItems: "center", gap: 10 }}>
                <Image source={{ uri: kuriQrBase64 }} style={{ width: 52, height: 52, borderRadius: 6, backgroundColor: "#fff" }} resizeMode="contain" />
                <View style={{ flex: 1 }}>
                  <Text style={{ color: C.green, fontWeight: "700", fontSize: 13 }}>QR code uploaded</Text>
                  <TouchableOpacity onPress={() => setKuriQrBase64(undefined)}>
                    <Text style={{ color: C.danger, fontSize: 12, marginTop: 2 }}>✕ Remove</Text>
                  </TouchableOpacity>
                </View>
              </View>
            ) : (
              <View style={{ flexDirection: "row", alignItems: "center", gap: 10 }}>
                <IcoQr color={C.textMuted} size={26} />
                <Text style={{ color: C.textMuted, fontSize: 13 }}>Upload your QR code image (max 500KB)</Text>
              </View>
            )}
          </TouchableOpacity>

          {/* Participants */}
          <Text style={s.label}>Participants</Text>
          <TouchableOpacity style={s.pickerTrigger} onPress={onOpenPicker} activeOpacity={0.7}>
            <Text style={kuriParticipantIds.length > 0 ? s.pickerTriggerActive : s.pickerTriggerPlaceholder}>
              {kuriParticipantIds.length > 0 ? `${kuriParticipantIds.length} selected` : "Choose participants"}
            </Text>
            <Text style={{ color: C.primary, fontSize: 18 }}>›</Text>
          </TouchableOpacity>

          {/* Notification rules */}
          <View style={s.ruleHeader}>
            <Text style={s.label}>Notification Rules</Text>
            <TouchableOpacity
              style={s.addRuleBtn}
              activeOpacity={0.7}
              onPress={() => setNotifRules((p) => [...p, { id: `r${Date.now()}`, channel: "in_app", beforeDays: "2", emails: "" }])}
            >
              <Text style={s.addRuleBtnText}>+ Add Rule</Text>
            </TouchableOpacity>
          </View>

          {notifRules.map((r) => (
            <View key={r.id} style={s.ruleCard}>
              {/* Channel chips */}
              <View style={s.ruleChipRow}>
                {([
                  { val: "in_app", label: "📱 In-App" },
                  { val: "email",  label: "📧 Email"  },
                ] as const).map((opt) => (
                  <TouchableOpacity
                    key={opt.val}
                    style={[s.ruleChip, r.channel === opt.val && s.ruleChipOn]}
                    onPress={() => setNotifRules((p) => p.map((x) => x.id === r.id ? { ...x, channel: opt.val } : x))}
                    activeOpacity={0.7}
                  >
                    <Text style={[s.ruleChipText, r.channel === opt.val && s.ruleChipTextOn]}>
                      {opt.label}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>

              {/* Days stepper */}
              <View style={s.ruleDaysRow}>
                <Text style={s.ruleDaysText}>Notify </Text>
                <TouchableOpacity style={s.stepBtn} onPress={() => step(r.id, -1)} activeOpacity={0.7}>
                  <Text style={s.stepBtnText}>−</Text>
                </TouchableOpacity>
                <View style={s.stepValBox}>
                  <Text style={s.stepValText}>{r.beforeDays || "0"}</Text>
                </View>
                <TouchableOpacity style={s.stepBtn} onPress={() => step(r.id, 1)} activeOpacity={0.7}>
                  <Text style={s.stepBtnText}>+</Text>
                </TouchableOpacity>
                <Text style={s.ruleDaysText}> days before</Text>
              </View>

              {/* What this rule does */}
              <View style={s.ruleInfoBox}>
                {r.channel === "in_app" ? (
                  <Text style={s.ruleInfoText}>🔔 Notification appears in your bell icon</Text>
                ) : (
                  <Text style={s.ruleInfoText}>📧 Email sent to: <Text style={{ color: C.text, fontWeight: "700" }}>{currentUserEmail}</Text></Text>
                )}
              </View>

              {/* Extra recipients if email */}
              {r.channel === "email" && (
                <View style={{ marginTop: 10 }}>
                  <Text style={[s.label, { fontSize: 12, marginBottom: 5 }]}>
                    Additional recipients{" "}
                    <Text style={{ fontWeight: "400", color: C.textDim }}>(optional)</Text>
                  </Text>
                  <TextInput
                    style={s.input}
                    value={r.emails}
                    onChangeText={(v) => setNotifRules((p) => p.map((x) => x.id === r.id ? { ...x, emails: v } : x))}
                    placeholder="other@email.com, another@email.com"
                    placeholderTextColor={C.textDim}
                    keyboardType="email-address"
                    autoCapitalize="none"
                    autoCorrect={false}
                  />
                </View>
              )}

              {/* Remove rule */}
              <TouchableOpacity
                style={s.ruleRemoveBtn}
                onPress={() => setNotifRules((p) => p.filter((x) => x.id !== r.id))}
                activeOpacity={0.7}
              >
                <Text style={s.ruleRemoveText}>✕ Remove rule</Text>
              </TouchableOpacity>
            </View>
          ))}

          <View style={{ height: 6 }} />
          <Btn label="Create Kuri Plan" onPress={onCreateKuri} size="lg" full />
        </Panel>
      </ScrollView>

      <DatePickerModal
        visible={datePickerOpen}
        value={kuriDate}
        onChange={setKuriDate}
        onClose={() => setDatePickerOpen(false)}
      />
    </View>
  );
}

// ─── Kuri payment helpers ─────────────────────────────────────────────────────

function getMonthRange(startDate: string): string[] {
  if (!startDate.match(/^\d{4}-\d{2}-\d{2}$/)) return [];
  const [sy, sm] = startDate.split("-").map(Number);
  const now = new Date();
  const ey = now.getFullYear(), em = now.getMonth() + 1;
  const months: string[] = [];
  let y = sy, m = sm;
  while ((y < ey || (y === ey && m <= em)) && months.length < 36) {
    months.push(`${y}-${String(m).padStart(2, "0")}`);
    m++; if (m > 12) { m = 1; y++; }
  }
  return months;
}

function fmtMonth(ym: string) {
  const [y, m] = ym.split("-").map(Number);
  return `${MONTHS_SHORT[m - 1]} ${y}`;
}

function extractTxnId(text: string): string {
  const pats = [
    /UTR\s*(?:No\.?|#|:)?\s*([A-Z0-9]{10,22})/i,
    /Transaction\s*(?:ID|No\.?|Ref)\s*:?\s*([A-Z0-9]{10,22})/i,
    /Reference\s*(?:No\.?)?\s*:?\s*([A-Z0-9]{10,22})/i,
    /UPI\s*(?:Ref|ID|Txn)\s*:?\s*([A-Z0-9]{10,22})/i,
    /Ref\s*:?\s*([A-Z0-9]{10,22})/i,
    /\b([0-9]{12})\b/,
    /\b(T[0-9]{11})\b/,
    /\b([A-Z]{4}[0-9]{14,18})\b/,
  ];
  for (const p of pats) {
    const m = text.match(p);
    if (m) return (m[1] || m[0]).trim().toUpperCase();
  }
  return "";
}

function webPickFile(
  accept: string,
  maxBytes: number,
  onDone: (b64: string, name: string, text?: string) => void
) {
  if (Platform.OS !== "web" || typeof document === "undefined") return;
  const inp = document.createElement("input");
  inp.type = "file"; inp.accept = accept; inp.style.display = "none";
  document.body.appendChild(inp);
  inp.onchange = (e: Event) => {
    const file = (e.target as HTMLInputElement).files?.[0];
    document.body.removeChild(inp);
    if (!file) return;
    if (file.size > maxBytes) {
      Alert.alert("File too large", `Maximum size is ${Math.round(maxBytes / 1024)}KB`);
      return;
    }
    const r = new FileReader();
    r.onload = () => {
      const b64 = r.result as string;
      if (file.type.includes("pdf") || file.type.startsWith("text/")) {
        const tr = new FileReader();
        tr.onload = () => onDone(b64, file.name, (tr.result as string) || "");
        tr.readAsText(file);
      } else {
        onDone(b64, file.name);
      }
    };
    r.readAsDataURL(file);
  };
  inp.click();
}

// ─── Kuri Manage Modal ────────────────────────────────────────────────────────

type KuriManageModalProps = {
  visible: boolean;
  kuri: KuriPlan | null;
  currentUser: User;
  members: Member[];
  payments: KuriPayment[];
  isCreator: boolean;
  onClose: () => void;
  onDelete: (id: string, name: string) => void;
  onSaveUpi: (kuriId: string, upiId: string, qr?: string) => Promise<void>;
  onSubmitPayment: (kuriId: string, month: string, txnId: string, amt: number, rcpt: string, rcptName: string) => Promise<void>;
  onReviewPayment: (paymentId: string, approved: boolean, notes?: string) => Promise<void>;
};

function KuriManageModal({
  visible, kuri, currentUser, members, payments, isCreator,
  onClose, onDelete, onSaveUpi, onSubmitPayment, onReviewPayment,
}: KuriManageModalProps) {
  // Creator tabs: "receipts" | "settings"
  // Member: single view (no tabs)
  const [creatorTab, setCreatorTab] = useState<"receipts" | "settings">("receipts");
  const [upiId, setUpiId] = useState("");
  const [qrB64, setQrB64] = useState<string | undefined>(undefined);
  const [savingUpi, setSavingUpi] = useState(false);

  // Month-level submission state
  const [submitMonth, setSubmitMonth] = useState<string | null>(null);
  const [txnId, setTxnId] = useState("");
  const [receiptB64, setReceiptB64] = useState("");
  const [receiptName, setReceiptName] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [autoExtracted, setAutoExtracted] = useState(false);

  // Review state (creator only)
  const [reviewingPaymentId, setReviewingPaymentId] = useState<string | null>(null);
  const [rejNotes, setRejNotes] = useState("");

  useEffect(() => {
    if (!visible || !kuri) return;
    setUpiId(kuri.upiId || "");
    setQrB64(kuri.upiQrBase64);
    setCreatorTab("receipts");
    setSubmitMonth(null);
    setTxnId(""); setReceiptB64(""); setReceiptName(""); setAutoExtracted(false);
    setReviewingPaymentId(null); setRejNotes("");
  }, [visible, kuri?.id]);

  if (!kuri) return null;

  const months = getMonthRange(kuri.startDate);
  const myPayments = payments.filter((p) => p.kuriId === kuri.id && p.userId === currentUser.id);
  const allPayments = payments.filter((p) => p.kuriId === kuri.id);
  const getMyPayment = (m: string) => myPayments.find((p) => p.month === m);
  const getMonthSubmissions = (m: string) => allPayments.filter((p) => p.month === m && p.status === "submitted");
  const getMonthApproved = (m: string) => allPayments.filter((p) => p.month === m && p.status === "approved").length;

  const handleSaveUpi = async () => {
    if (!upiId.trim()) { Alert.alert("Required", "Enter your UPI ID."); return; }
    setSavingUpi(true);
    try { await onSaveUpi(kuri.id, upiId.trim(), qrB64); Alert.alert("Saved!", "Payment info updated."); }
    catch (e: unknown) { Alert.alert("Error", e instanceof Error ? e.message : "Failed."); }
    finally { setSavingUpi(false); }
  };

  const handlePickReceipt = () =>
    webPickFile("image/*,application/pdf,.pdf", 2 * 1024 * 1024, (b64, name, text) => {
      setReceiptB64(b64); setReceiptName(name);
      if (text) { const f = extractTxnId(text); if (f) { setTxnId(f); setAutoExtracted(true); } }
    });

  const handleSubmitPayment = async () => {
    if (!receiptB64) { Alert.alert("Receipt required", "Please upload your payment receipt or screenshot."); return; }
    if (!txnId.trim()) { Alert.alert("Required", "Enter the UPI / UTR transaction ID."); return; }
    if (!submitMonth) return;
    setSubmitting(true);
    try {
      await onSubmitPayment(kuri.id, submitMonth, txnId, kuri.contributionAmount, receiptB64, receiptName);
      setSubmitMonth(null); setTxnId(""); setReceiptB64(""); setReceiptName(""); setAutoExtracted(false);
      Alert.alert("Submitted!", "Receipt submitted. Awaiting creator's confirmation.");
    } catch (e: unknown) { Alert.alert("Error", e instanceof Error ? e.message : "Failed."); }
    finally { setSubmitting(false); }
  };

  const copyUpi = () => {
    if (Platform.OS === "web" && typeof navigator !== "undefined" && navigator.clipboard) {
      navigator.clipboard.writeText(kuri.upiId || "").then(() => Alert.alert("Copied!", "UPI ID copied.")).catch(() => {});
    }
  };

  const statusColor = (st: KuriPayment["status"]) =>
    st === "approved" ? C.green : st === "rejected" ? C.danger : C.warn;
  const statusLabel = (st: KuriPayment["status"]) =>
    st === "approved" ? "Confirmed" : st === "rejected" ? "Rejected" : "Pending review";
  const memberName = (uid: string) => members.find((m) => m.user.id === uid)?.user.name ?? uid;

  const reviewingPayment = allPayments.find((p) => p.id === reviewingPaymentId);

  return (
    <Modal visible={visible} transparent animationType="slide">
      <View style={s.overlay}>
        <TouchableOpacity style={{ flex: 1 }} onPress={onClose} activeOpacity={1} />
        <View style={[s.sheet, { maxHeight: "94%", paddingBottom: 0 }]}>
          <View style={s.handle} />

          {/* ── Header ── */}
          <View style={{ flexDirection: "row", alignItems: "flex-start", marginBottom: 10, paddingHorizontal: 2 }}>
            <View style={{ flex: 1 }}>
              <Text style={[s.sheetTitle, { marginBottom: 2 }]} numberOfLines={1}>{kuri.name}</Text>
              <Text style={[s.meta, { fontSize: 12 }]}>
                ₹{kuri.contributionAmount.toLocaleString()} / mo · {kuri.participantUserIds.length} members
              </Text>
            </View>
            {isCreator && (
              <TouchableOpacity
                style={[s.iconBtn, { backgroundColor: C.dangerDark }]}
                onPress={() => onDelete(kuri.id, kuri.name)}
                activeOpacity={0.7}
              >
                <IcoTrash color={C.dangerFg} size={16} />
              </TouchableOpacity>
            )}
          </View>

          {/* ── Creator tabs ── */}
          {isCreator && (
            <View style={[s.subTabRow, { marginBottom: 10 }]}>
              {([
                { id: "receipts" as const, lbl: "Receipts" },
                { id: "settings" as const, lbl: "Settings" },
              ]).map((t) => (
                <TouchableOpacity
                  key={t.id}
                  style={[s.subTab, creatorTab === t.id && s.subTabOn]}
                  onPress={() => setCreatorTab(t.id)}
                  activeOpacity={0.7}
                >
                  <Text style={[s.subTabText, creatorTab === t.id && s.subTabTextOn]}>{t.lbl}</Text>
                </TouchableOpacity>
              ))}
            </View>
          )}

          {/* ── UPI banner for members ── */}
          {!isCreator && kuri.upiId && (
            <View style={s.upiPayBanner}>
              <View style={{ flex: 1 }}>
                <Text style={s.upiPayLabel}>Pay to</Text>
                <Text style={s.upiPayValue} selectable numberOfLines={1}>{kuri.upiId}</Text>
              </View>
              <TouchableOpacity style={s.upiCopyBtn} onPress={copyUpi} activeOpacity={0.7}>
                <IcoCopy color={C.primary} size={16} />
                <Text style={s.upiCopyText}>Copy</Text>
              </TouchableOpacity>
              {kuri.upiQrBase64 && (
                <Image source={{ uri: kuri.upiQrBase64 }} style={s.upiQrThumb} resizeMode="contain" />
              )}
            </View>
          )}

          {/* ── Content ScrollView (fixed maxHeight, never flex:1) ── */}
          <ScrollView
            style={{ maxHeight: 460 }}
            showsVerticalScrollIndicator={false}
            keyboardShouldPersistTaps="handled"
          >
            {/* ══ CREATOR: RECEIPTS TAB ══ */}
            {isCreator && creatorTab === "receipts" && (
              <View style={{ paddingTop: 4 }}>
                {months.length === 0 ? (
                  <View style={{ alignItems: "center", paddingVertical: 28 }}>
                    <Text style={s.meta}>No months yet — plan starts in the future.</Text>
                  </View>
                ) : months.map((m) => {
                  const submissions = getMonthSubmissions(m);
                  const approved = getMonthApproved(m);
                  const total = kuri.participantUserIds.length;
                  const allPaid = approved >= total && total > 0;
                  return (
                    <View key={m} style={s.monthRow}>
                      <View style={{ flex: 1 }}>
                        <Text style={s.monthLabel}>{fmtMonth(m)}</Text>
                        <Text style={s.monthSub}>
                          {approved}/{total} confirmed
                          {submissions.length > 0 ? ` · ${submissions.length} awaiting review` : ""}
                        </Text>
                      </View>
                      {allPaid ? (
                        <View style={[s.statusPill, { backgroundColor: C.greenDark }]}>
                          <IcoCheck color={C.green} size={11} />
                          <Text style={[s.statusPillText, { color: C.green }]}>All paid</Text>
                        </View>
                      ) : submissions.length > 0 ? (
                        <TouchableOpacity style={s.reviewBtn} onPress={() => { setReviewingPaymentId(submissions[0].id); setRejNotes(""); }} activeOpacity={0.7}>
                          <Text style={s.reviewBtnText}>Review {submissions.length > 1 ? `(${submissions.length})` : ""}</Text>
                        </TouchableOpacity>
                      ) : null}
                    </View>
                  );
                })}
              </View>
            )}

            {/* ══ CREATOR: SETTINGS TAB ══ */}
            {isCreator && creatorTab === "settings" && (
              <View style={{ paddingTop: 8 }}>
                <Text style={s.label}>UPI ID <Text style={{ color: C.danger }}>*</Text></Text>
                <TextInput
                  style={[s.input, { marginBottom: 6 }]}
                  value={upiId}
                  onChangeText={setUpiId}
                  placeholder="example@upi"
                  placeholderTextColor={C.textDim}
                  autoCapitalize="none"
                  autoCorrect={false}
                  keyboardType="email-address"
                />
                <Text style={[s.meta, { marginBottom: 16, fontSize: 12 }]}>Members use this UPI ID to send payments directly.</Text>

                <Text style={s.label}>Payment QR Code <Text style={{ color: C.textDim, fontWeight: "400", fontSize: 12 }}>(optional)</Text></Text>
                <TouchableOpacity
                  style={s.uploadBox}
                  onPress={() => webPickFile("image/*", 500 * 1024, (b64) => setQrB64(b64))}
                  activeOpacity={0.75}
                >
                  {qrB64 ? (
                    <View style={{ alignItems: "center", width: "100%", gap: 8 }}>
                      <Image source={{ uri: qrB64 }} style={{ width: 140, height: 140, borderRadius: 8, backgroundColor: "#fff" }} resizeMode="contain" />
                      <Text style={{ color: C.textMuted, fontSize: 12 }}>Tap to replace</Text>
                    </View>
                  ) : (
                    <View style={{ flexDirection: "row", alignItems: "center", gap: 10, paddingVertical: 8 }}>
                      <IcoQr color={C.textMuted} size={32} />
                      <Text style={{ color: C.textMuted, fontSize: 13 }}>Upload QR code (max 500KB)</Text>
                    </View>
                  )}
                </TouchableOpacity>
                {qrB64 && (
                  <TouchableOpacity onPress={() => setQrB64(undefined)} style={{ marginBottom: 10, alignSelf: "flex-start" }}>
                    <Text style={{ color: C.danger, fontSize: 13, fontWeight: "600" }}>✕ Remove QR</Text>
                  </TouchableOpacity>
                )}
                <Btn label={savingUpi ? "Saving…" : "Save Changes"} onPress={handleSaveUpi} disabled={savingUpi} size="lg" full />
                <View style={{ height: 16 }} />
              </View>
            )}

            {/* ══ MEMBER: MONTHLY PAYMENT ROWS ══ */}
            {!isCreator && (
              <View style={{ paddingTop: 4 }}>
                {/* Full QR if available */}
                {kuri.upiQrBase64 && (
                  <View style={{ alignItems: "center", marginBottom: 16 }}>
                    <Text style={[s.label, { marginBottom: 8 }]}>Scan to Pay</Text>
                    <Image source={{ uri: kuri.upiQrBase64 }} style={{ width: 180, height: 180, borderRadius: 10, backgroundColor: "#fff" }} resizeMode="contain" />
                  </View>
                )}

                <Text style={[s.label, { marginBottom: 4 }]}>Monthly Receipts</Text>
                <Text style={[s.meta, { fontSize: 12, marginBottom: 10 }]}>
                  Pay via any UPI app then upload your receipt screenshot as proof.
                </Text>

                {months.length === 0 && (
                  <View style={{ alignItems: "center", paddingVertical: 20 }}>
                    <Text style={s.meta}>Plan hasn't started yet.</Text>
                  </View>
                )}

                {months.map((m) => {
                  const pay = getMyPayment(m);
                  const isOpen = submitMonth === m;
                  return (
                    <View key={m} style={{ marginBottom: 2 }}>
                      <View style={s.monthRow}>
                        <View style={{ flex: 1 }}>
                          <Text style={s.monthLabel}>{fmtMonth(m)}</Text>
                          {pay && (
                            <Text style={[s.monthSub, { color: statusColor(pay.status) }]}>
                              {statusLabel(pay.status)} · Txn: {pay.transactionId}
                            </Text>
                          )}
                          {pay?.notes && pay.status === "rejected" && (
                            <Text style={[s.monthSub, { color: C.danger }]}>Reason: {pay.notes}</Text>
                          )}
                        </View>
                        {(!pay || pay.status === "rejected") && (
                          <TouchableOpacity
                            style={[s.payBtn, isOpen && s.payBtnOpen]}
                            onPress={() => {
                              if (isOpen) { setSubmitMonth(null); }
                              else {
                                setSubmitMonth(m); setTxnId("");
                                setReceiptB64(""); setReceiptName(""); setAutoExtracted(false);
                              }
                            }}
                            activeOpacity={0.7}
                          >
                            <Text style={s.payBtnText}>
                              {isOpen ? "Cancel" : pay?.status === "rejected" ? "Resubmit" : "Submit receipt"}
                            </Text>
                          </TouchableOpacity>
                        )}
                        {pay && pay.status !== "rejected" && (
                          <View style={[s.statusPill, {
                            backgroundColor: pay.status === "approved" ? C.greenDark : "#451a03",
                          }]}>
                            {pay.status === "approved" && <IcoCheck color={C.green} size={11} />}
                            <Text style={[s.statusPillText, { color: statusColor(pay.status) }]}>
                              {statusLabel(pay.status)}
                            </Text>
                          </View>
                        )}
                      </View>

                      {/* Expanded submit form */}
                      {isOpen && (
                        <View style={[s.submitForm, { marginBottom: 8 }]}>
                          {/* Step 1: Transaction ID */}
                          <Text style={[s.label, { fontSize: 12, marginBottom: 4 }]}>
                            Step 1 — UPI / UTR Transaction ID
                            {autoExtracted && <Text style={{ color: C.green }}> ✓ auto-detected</Text>}
                          </Text>
                          <TextInput
                            style={[s.input, { marginBottom: 10 }]}
                            value={txnId}
                            onChangeText={(v) => { setTxnId(v); setAutoExtracted(false); }}
                            placeholder="e.g. 425012345678"
                            placeholderTextColor={C.textDim}
                            autoCapitalize="characters"
                            autoCorrect={false}
                          />

                          {/* Step 2: Receipt upload (required) */}
                          <Text style={[s.label, { fontSize: 12, marginBottom: 4 }]}>
                            Step 2 — Upload receipt screenshot <Text style={{ color: C.danger }}>*</Text>
                          </Text>
                          <TouchableOpacity style={s.uploadBox} onPress={handlePickReceipt} activeOpacity={0.75}>
                            {receiptB64 ? (
                              <View style={{ flexDirection: "row", alignItems: "center", gap: 8, flex: 1 }}>
                                {receiptB64.startsWith("data:image") ? (
                                  <Image source={{ uri: receiptB64 }} style={{ width: 40, height: 40, borderRadius: 6 }} resizeMode="cover" />
                                ) : (
                                  <IcoReceipt color={C.green} size={24} />
                                )}
                                <View style={{ flex: 1 }}>
                                  <Text style={{ color: C.green, fontWeight: "700", fontSize: 13 }} numberOfLines={1}>{receiptName}</Text>
                                  <Text style={{ color: C.textMuted, fontSize: 11 }}>Tap to replace</Text>
                                </View>
                              </View>
                            ) : (
                              <View style={{ flexDirection: "row", alignItems: "center", gap: 10 }}>
                                <IcoUpload color={C.textMuted} size={22} />
                                <View>
                                  <Text style={{ color: C.textMuted, fontSize: 13, fontWeight: "600" }}>Upload payment screenshot</Text>
                                  <Text style={{ color: C.textDim, fontSize: 11 }}>Image or PDF · max 2MB</Text>
                                </View>
                              </View>
                            )}
                          </TouchableOpacity>

                          <Btn
                            label={submitting ? "Submitting…" : `Submit ₹${kuri.contributionAmount.toLocaleString()}`}
                            onPress={handleSubmitPayment}
                            disabled={submitting}
                            size="md" full
                          />
                        </View>
                      )}
                    </View>
                  );
                })}
                <View style={{ height: 8 }} />
              </View>
            )}
          </ScrollView>

          {/* ── Review overlay (creator) ── */}
          {reviewingPayment && (
            <View style={[s.reviewPanel, { position: "absolute", bottom: 0, left: 0, right: 0, maxHeight: "80%", borderTopLeftRadius: 20, borderTopRightRadius: 20 }]}>
              <View style={s.handle} />
              <View style={{ flexDirection: "row", alignItems: "center", marginBottom: 12 }}>
                <Text style={[s.sheetTitle, { flex: 1, fontSize: 16 }]}>
                  {memberName(reviewingPayment.userId)} — {fmtMonth(reviewingPayment.month)}
                </Text>
                <TouchableOpacity onPress={() => { setReviewingPaymentId(null); setRejNotes(""); }} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
                  <IcoX color={C.textMuted} size={20} />
                </TouchableOpacity>
              </View>
              <ScrollView style={{ maxHeight: 340 }} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
                <View style={[s.upiBox, { marginBottom: 10 }]}>
                  <Text style={[s.upiLabel, { marginBottom: 2 }]}>Transaction ID</Text>
                  <Text style={{ color: C.text, fontWeight: "700", fontSize: 15 }}>{reviewingPayment.transactionId}</Text>
                </View>
                {reviewingPayment.receiptBase64?.startsWith("data:image") && (
                  <Image
                    source={{ uri: reviewingPayment.receiptBase64 }}
                    style={{ width: "100%", height: 200, borderRadius: 10, backgroundColor: C.border, marginBottom: 10 }}
                    resizeMode="contain"
                  />
                )}
                {reviewingPayment.receiptFileName && !reviewingPayment.receiptBase64?.startsWith("data:image") && (
                  <View style={[s.upiBox, { flexDirection: "row", alignItems: "center", gap: 8, marginBottom: 10 }]}>
                    <IcoReceipt color={C.textMuted} size={20} />
                    <Text style={{ color: C.textMuted, fontSize: 13 }}>{reviewingPayment.receiptFileName}</Text>
                  </View>
                )}
                <Text style={[s.label, { fontSize: 12, marginBottom: 4 }]}>Rejection note (if rejecting)</Text>
                <TextInput
                  style={[s.input, { marginBottom: 12 }]}
                  value={rejNotes}
                  onChangeText={setRejNotes}
                  placeholder="e.g. Wrong amount, please resubmit"
                  placeholderTextColor={C.textDim}
                />
                <View style={{ flexDirection: "row", gap: 10, marginBottom: 8 }}>
                  <View style={{ flex: 1 }}>
                    <Btn label="✓ Confirm Received" variant="green" size="md" full
                      onPress={() => { onReviewPayment(reviewingPayment.id, true); setReviewingPaymentId(null); setRejNotes(""); }}
                    />
                  </View>
                  <View style={{ flex: 1 }}>
                    <Btn label="✕ Reject" variant="danger" size="md" full
                      onPress={() => { onReviewPayment(reviewingPayment.id, false, rejNotes || undefined); setReviewingPaymentId(null); setRejNotes(""); }}
                    />
                  </View>
                </View>
              </ScrollView>
            </View>
          )}

          {/* Footer */}
          <View style={{ paddingHorizontal: 0, paddingTop: 10, paddingBottom: 14 }}>
            <Btn label="Close" variant="outline" onPress={onClose} size="md" full />
          </View>
        </View>
      </View>
    </Modal>
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

  // Push notification tracking
  const seenNotifIdsRef = useRef(new Set<string>());
  const hasSeededPushRef = useRef(false);

  // Kuri form
  const [kuriName, setKuriName] = useState("");
  const [kuriAmount, setKuriAmount] = useState("");
  const [kuriDate, setKuriDate] = useState("");
  const [kuriUpiId, setKuriUpiId] = useState("");
  const [kuriQrBase64, setKuriQrBase64] = useState<string | undefined>(undefined);
  const [kuriParticipantIds, setKuriParticipantIds] = useState<string[]>([]);
  const [participantPickerOpen, setParticipantPickerOpen] = useState(false);
  const [notifRules, setNotifRules] = useState<
    Array<{ id: string; channel: "email" | "in_app"; beforeDays: string; emails: string }>
  >([{ id: "r1", channel: "in_app", beforeDays: "2", emails: "" }]);

  // Kuri manage modal
  const [managingKuriId, setManagingKuriId] = useState<string | null>(null);

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
    // Fix iOS PWA footer: fill the safe-area strip with app background
    document.body.style.backgroundColor = "#020817";
    document.documentElement.style.backgroundColor = "#020817";
    if (!document.querySelector("#kuri-safe-style")) {
      const style = document.createElement("style");
      style.id = "kuri-safe-style";
      style.textContent = `
        html, body { background: #020817 !important; }
        #tab-bar-safe { padding-bottom: env(safe-area-inset-bottom, 4px) !important; }
      `;
      document.head.appendChild(style);
    }
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
      requestPushPermission();
    } else {
      window.localStorage.removeItem("kuri_session_user");
      hasSeededPushRef.current = false;
      seenNotifIdsRef.current.clear();
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

  // Fire browser push notifications for newly arrived unread notifications
  useEffect(() => {
    if (!currentUser) return;
    const unread = myNotifs.filter((n) => !n.read);
    if (!hasSeededPushRef.current) {
      // First load — seed without pushing so we don't spam on open
      unread.forEach((n) => seenNotifIdsRef.current.add(n.id));
      hasSeededPushRef.current = true;
      return;
    }
    const fresh = unread.filter((n) => !seenNotifIdsRef.current.has(n.id));
    fresh.forEach((n) => {
      firePushNotification(n.title, n.message.replace(/ref:.*/, "").trim());
      seenNotifIdsRef.current.add(n.id);
    });
  }, [myNotifs, currentUser]);

  const pendingInvites = useMemo<Invitation[]>(() => {
    if (!activeCommittee) return [];
    return data.invitations.filter((i) => i.groupId === activeCommittee.id && i.status === "pending");
  }, [activeCommittee, data.invitations]);

  const kuriPayments = useMemo<KuriPayment[]>(() => {
    if (!activeCommittee) return [];
    const groupKuriIds = new Set(myKuris.map((k) => k.id));
    return (data.payments || []).filter((p) => groupKuriIds.has(p.kuriId));
  }, [activeCommittee, myKuris, data.payments]);

  const managingKuri = useMemo(
    () => myKuris.find((k) => k.id === managingKuriId) ?? null,
    [managingKuriId, myKuris]
  );

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
      Alert.alert("Missing fields", "Enter plan name, amount > 0, and start date.");
      return;
    }
    if (!kuriUpiId.trim()) {
      Alert.alert("UPI ID required", "Enter your UPI ID so members can pay you.");
      return;
    }
    try {
      await kuriService.createKuri(
        activeCommittee.id, currentUser.id, kuriName, amount, "INR", kuriDate,
        kuriParticipantIds,
        { rules: notifRules.map((r) => ({ channel: r.channel, beforeDays: Number(r.beforeDays || "0"), emailRecipients: r.emails.split(",").map((v) => v.trim().toLowerCase()).filter(Boolean) })) },
        kuriUpiId,
        kuriQrBase64
      );
      setKuriName(""); setKuriAmount(""); setKuriDate(""); setKuriParticipantIds([]);
      setKuriUpiId(""); setKuriQrBase64(undefined);
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

  const deleteKuri = (kuriId: string, kuriName: string) => {
    Alert.alert("Delete Kuri Plan", `Delete "${kuriName}"? This cannot be undone.`, [
      { text: "Cancel", style: "cancel" },
      {
        text: "Delete", style: "destructive", onPress: async () => {
          if (!currentUser) return;
          try {
            await kuriService.deleteKuri(kuriId, currentUser.id);
            setManagingKuriId(null);
            await refresh();
          } catch (e: unknown) { Alert.alert("Error", e instanceof Error ? e.message : "Failed."); }
        },
      },
    ]);
  };

  const saveKuriUpi = async (kuriId: string, upiId: string, qrBase64?: string) => {
    if (!currentUser) return;
    try {
      await kuriService.updateKuriPaymentInfo(kuriId, currentUser.id, upiId, qrBase64);
      await refresh();
    } catch (e: unknown) { Alert.alert("Error", e instanceof Error ? e.message : "Failed."); }
  };

  const submitKuriPayment = async (
    kuriId: string, month: string, txnId: string,
    amount: number, receiptBase64: string, receiptFileName: string
  ) => {
    if (!currentUser) return;
    await kuriService.submitPayment(kuriId, currentUser.id, month, txnId, amount, receiptBase64, receiptFileName);
    await refresh();
  };

  const reviewKuriPayment = async (paymentId: string, approved: boolean, notes?: string) => {
    if (!currentUser) return;
    try {
      await kuriService.reviewPayment(paymentId, currentUser.id, approved, notes);
      await refresh();
    } catch (e: unknown) { Alert.alert("Error", e instanceof Error ? e.message : "Failed."); }
  };

  // ── Loading ────────────────────────────────────────────────────────────────

  if (loading) {
    return (
      <SafeAreaView style={s.safe}>
        <StatusBar style="light" />
        <View style={s.splash}>
          <AppLogo size={80} />
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
              <AppLogo size={72} />
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
            <IcoBell color={unreadCount > 0 ? C.primary : C.textMuted} size={22} />
            {unreadCount > 0 && (
              <View style={s.notifBadge}>
                <Text style={s.notifBadgeText}>{unreadCount > 9 ? "9+" : unreadCount}</Text>
              </View>
            )}
          </TouchableOpacity>
          <TouchableOpacity
            style={s.iconBtn}
            onPress={() => setCurrentUser(null)}
            activeOpacity={0.7}
            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
          >
            <IcoSignOut color={C.textMuted} size={20} />
          </TouchableOpacity>
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
            currentUserEmail={currentUser.email}
            currentUserId={currentUser.id}
            kuriName={kuriName} setKuriName={setKuriName}
            kuriAmount={kuriAmount} setKuriAmount={setKuriAmount}
            kuriDate={kuriDate} setKuriDate={setKuriDate}
            kuriUpiId={kuriUpiId} setKuriUpiId={setKuriUpiId}
            kuriQrBase64={kuriQrBase64} setKuriQrBase64={setKuriQrBase64}
            kuriParticipantIds={kuriParticipantIds}
            onOpenPicker={() => setParticipantPickerOpen(true)}
            notifRules={notifRules} setNotifRules={setNotifRules}
            onCreateKuri={createKuri}
            onManageKuri={setManagingKuriId}
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

      {/* ── Kuri Manage ── */}
      {currentUser && (
        <KuriManageModal
          visible={!!managingKuriId}
          kuri={managingKuri}
          currentUser={currentUser}
          members={members}
          payments={kuriPayments}
          isCreator={managingKuri?.createdBy === currentUser.id}
          onClose={() => setManagingKuriId(null)}
          onDelete={deleteKuri}
          onSaveUpi={saveKuriUpi}
          onSubmitPayment={submitKuriPayment}
          onReviewPayment={reviewKuriPayment}
        />
      )}

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

  // Date picker trigger
  dateTrigger: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", borderWidth: 1, borderColor: C.borderStrong, backgroundColor: C.inputBg, borderRadius: 10, paddingVertical: 13, paddingHorizontal: 14, marginBottom: 14 },
  dateTriggerPlaceholder: { color: C.textDim, fontSize: 16 },
  dateTriggerActive: { color: C.text, fontSize: 16, fontWeight: "600" },
  datePreviewRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", backgroundColor: C.inputBg, borderRadius: 10, paddingVertical: 12, paddingHorizontal: 14, marginTop: 12, marginBottom: 16 },
  datePreviewLabel: { color: C.textMuted, fontSize: 13 },
  datePreviewValue: { color: C.primary, fontSize: 18, fontWeight: "800" },

  ruleHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 8 },
  addRuleBtn: { backgroundColor: C.blueDark, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 },
  addRuleBtnText: { color: C.blueFg, fontSize: 12, fontWeight: "700" },

  // Redesigned notification rule card
  ruleCard: { backgroundColor: C.inputBg, borderRadius: 12, borderWidth: 1, borderColor: C.borderStrong, padding: 14, marginBottom: 10 },
  ruleChipRow: { flexDirection: "row", gap: 8, marginBottom: 14 },
  ruleChip: { flex: 1, paddingVertical: 10, borderRadius: 10, borderWidth: 1, borderColor: C.borderStrong, alignItems: "center", backgroundColor: C.bg },
  ruleChipOn: { backgroundColor: C.primaryLight, borderColor: C.primary },
  ruleChipText: { color: C.textMuted, fontSize: 14, fontWeight: "600" },
  ruleChipTextOn: { color: C.primary, fontWeight: "700" },
  ruleDaysRow: { flexDirection: "row", alignItems: "center", marginBottom: 12 },
  ruleDaysText: { color: C.textSub, fontSize: 14 },
  stepBtn: { width: 36, height: 36, borderRadius: 8, backgroundColor: C.border, alignItems: "center", justifyContent: "center" },
  stepBtnText: { color: C.text, fontSize: 20, fontWeight: "700", lineHeight: 22 },
  stepValBox: { minWidth: 44, alignItems: "center", paddingHorizontal: 6 },
  stepValText: { color: C.primary, fontSize: 22, fontWeight: "900" },
  ruleInfoBox: { backgroundColor: C.surface, borderRadius: 8, paddingVertical: 10, paddingHorizontal: 12, marginBottom: 4 },
  ruleInfoText: { color: C.textMuted, fontSize: 13, lineHeight: 18 },
  ruleRemoveBtn: { marginTop: 10, alignSelf: "flex-start" },
  ruleRemoveText: { color: C.danger, fontSize: 13, fontWeight: "600" },

  // Old rule styles kept for safety
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

  iconBtn: { width: 36, height: 36, borderRadius: 10, backgroundColor: C.border, alignItems: "center", justifyContent: "center", flexShrink: 0 },
  notifBtn: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  notifBadge: { position: "absolute", top: 4, right: 4, minWidth: 16, height: 16, borderRadius: 8, backgroundColor: C.danger, alignItems: "center", justifyContent: "center", paddingHorizontal: 3 },
  notifBadgeText: { color: "#fff", fontSize: 10, fontWeight: "700" },
  notifItem: { flexDirection: "row", alignItems: "center", borderWidth: 1, borderColor: C.border, borderRadius: 12, padding: 12, marginBottom: 8, backgroundColor: C.inputBg, gap: 10 },
  notifItemUnread: { borderColor: C.primaryMid, backgroundColor: "#0a1829" },
  notifItemTitle: { color: C.text, fontWeight: "700", fontSize: 14, marginBottom: 3 },
  notifItemMsg: { color: C.textMuted, fontSize: 13, lineHeight: 18 },
  unreadDot: { width: 8, height: 8, borderRadius: 4, backgroundColor: C.primary, flexShrink: 0 },

  // Kuri manage btn
  kuriManageBtn: { flexDirection: "row", alignItems: "center", gap: 6, margin: 10, marginTop: 8, alignSelf: "flex-end", backgroundColor: C.primaryLight, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 7 },
  kuriManageBtnText: { color: C.primary, fontSize: 13, fontWeight: "700" },

  // Manage modal sub-tabs
  subTabRow: { flexDirection: "row", backgroundColor: C.bg, borderRadius: 10, padding: 3, marginBottom: 14 },
  subTab: { flex: 1, paddingVertical: 8, borderRadius: 8, alignItems: "center" },
  subTabOn: { backgroundColor: C.primaryLight },
  subTabText: { color: C.textDim, fontSize: 13, fontWeight: "700" },
  subTabTextOn: { color: C.primary },

  // Month payment rows
  monthRow: { flexDirection: "row", alignItems: "center", paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: C.border, gap: 8 },
  monthLabel: { color: C.text, fontWeight: "700", fontSize: 14 },
  monthSub: { color: C.textMuted, fontSize: 12, marginTop: 2 },
  statusPill: { flexDirection: "row", alignItems: "center", gap: 4, borderRadius: 8, paddingHorizontal: 8, paddingVertical: 4, flexShrink: 0 },
  statusPillText: { fontSize: 11, fontWeight: "700" },
  payBtn: { backgroundColor: C.primaryLight, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 7, flexShrink: 0 },
  payBtnOpen: { backgroundColor: C.border },
  payBtnText: { color: C.primary, fontSize: 12, fontWeight: "700" },
  reviewBtn: { backgroundColor: "#451a03", borderRadius: 8, paddingHorizontal: 12, paddingVertical: 7, flexShrink: 0 },
  reviewBtnText: { color: C.warn, fontSize: 12, fontWeight: "700" },

  // Submit form
  submitForm: { backgroundColor: C.inputBg, borderRadius: 12, borderWidth: 1, borderColor: C.borderStrong, padding: 12, marginBottom: 8 },
  uploadBox: { flexDirection: "row", alignItems: "center", borderWidth: 1, borderColor: C.borderStrong, borderStyle: "dashed" as any, borderRadius: 10, padding: 14, marginBottom: 12, backgroundColor: C.bg },

  // Review panel
  reviewPanel: { backgroundColor: C.inputBg, borderRadius: 12, borderWidth: 1, borderColor: C.borderStrong, padding: 14, marginTop: 8 },
  reviewItem: { borderTopWidth: 1, borderTopColor: C.border, paddingTop: 12, marginTop: 8 },

  // UPI info box (generic, used in settings)
  upiBox: { flexDirection: "column", backgroundColor: C.inputBg, borderRadius: 10, borderWidth: 1, borderColor: C.borderStrong, padding: 14, marginBottom: 4 },
  upiLabel: { color: C.textMuted, fontSize: 12, fontWeight: "600" },
  upiValue: { color: C.primary, fontSize: 17, fontWeight: "800", flex: 1 },

  // UPI payment banner (member view top)
  upiPayBanner: { flexDirection: "row", alignItems: "center", backgroundColor: C.primaryLight, borderRadius: 12, borderWidth: 1, borderColor: C.primaryMid, padding: 12, marginBottom: 10, gap: 10 },
  upiPayLabel: { color: C.textMuted, fontSize: 11, fontWeight: "600", textTransform: "uppercase", letterSpacing: 0.5 },
  upiPayValue: { color: C.primary, fontSize: 15, fontWeight: "800" },
  upiCopyBtn: { flexDirection: "row", alignItems: "center", gap: 4, backgroundColor: C.bg, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6, borderWidth: 1, borderColor: C.primaryMid },
  upiCopyText: { color: C.primary, fontSize: 12, fontWeight: "700" },
  upiQrThumb: { width: 44, height: 44, borderRadius: 6, backgroundColor: "#fff", flexShrink: 0 },
});
