import AsyncStorage from "@react-native-async-storage/async-storage";
import { kuriService } from "../src/services/kuriService";
import { AppData } from "../src/types";

function makeStore(initial: Partial<AppData> = {}) {
  const data: AppData = {
    users: [],
    groups: [],
    invitations: [],
    kuris: [],
    payments: [],
    chatMessages: [],
    notifications: [],
    ...initial,
  };
  let raw = JSON.stringify(data);
  (AsyncStorage.getItem as jest.Mock).mockImplementation(async () => raw);
  (AsyncStorage.setItem as jest.Mock).mockImplementation(async (_k: string, v: string) => { raw = v; });
}

beforeEach(() => {
  jest.clearAllMocks();
  makeStore();
});

describe("createUser", () => {
  it("creates a new user and returns it", async () => {
    const user = await kuriService.createUser("Alice", "alice@example.com");
    expect(user.name).toBe("Alice");
    expect(user.email).toBe("alice@example.com");
    expect(user.id).toMatch(/^usr_/);
  });

  it("normalises email to lowercase", async () => {
    const user = await kuriService.createUser("Bob", "BOB@EXAMPLE.COM");
    expect(user.email).toBe("bob@example.com");
  });

  it("returns existing user when email already registered", async () => {
    const u1 = await kuriService.createUser("Alice", "alice@example.com");
    const u2 = await kuriService.createUser("Alice Duplicate", "alice@example.com");
    expect(u1.id).toBe(u2.id);
    expect(u2.name).toBe("Alice");
  });
});

describe("createGroup", () => {
  it("creates a group with the admin as first member", async () => {
    const admin = await kuriService.createUser("Admin", "admin@example.com");
    const group = await kuriService.createGroup("Test Circle", admin.id, [], "A test");
    expect(group.name).toBe("Test Circle");
    expect(group.description).toBe("A test");
    expect(group.createdBy).toBe(admin.id);
    expect(group.members).toHaveLength(1);
    expect(group.members[0].role).toBe("admin");
  });

  it("creates pending invitations for initial member emails", async () => {
    const admin = await kuriService.createUser("Admin", "admin@example.com");
    await kuriService.createGroup("Circle", admin.id, ["member@test.com"], "");
    const data = await kuriService.getData();
    expect(data.invitations).toHaveLength(1);
    expect(data.invitations[0].inviteeEmail).toBe("member@test.com");
    expect(data.invitations[0].status).toBe("pending");
  });
});

describe("sendGroupMessage", () => {
  it("adds a message to the group", async () => {
    const user = await kuriService.createUser("User", "user@example.com");
    const group = await kuriService.createGroup("Circle", user.id, [], "");
    const msg = await kuriService.sendGroupMessage(group.id, user.id, "Hello!");
    expect(msg.text).toBe("Hello!");
    expect(msg.senderName).toBe("User");
    expect(msg.groupId).toBe(group.id);
    const data = await kuriService.getData();
    expect(data.chatMessages).toHaveLength(1);
  });

  it("throws if sender is not a group member", async () => {
    const admin = await kuriService.createUser("Admin", "admin@example.com");
    const outsider = await kuriService.createUser("Outsider", "out@example.com");
    const group = await kuriService.createGroup("Circle", admin.id, [], "");
    await expect(kuriService.sendGroupMessage(group.id, outsider.id, "Hi")).rejects.toThrow("Only members can chat.");
  });
});

describe("joinGroupByInviteCode", () => {
  it("joins a group using a valid invite code", async () => {
    const admin = await kuriService.createUser("Admin", "admin@example.com");
    const group = await kuriService.createGroup("Circle", admin.id, ["invited@example.com"], "");
    const data = await kuriService.getData();
    const inv = data.invitations[0];
    const invitee = await kuriService.createUser("Invited", "invited@example.com");
    await kuriService.joinGroupByInviteCode(inv.inviteCode, invitee.name, invitee.email);
    const updated = await kuriService.getData();
    const updatedGroup = updated.groups.find((g) => g.id === group.id)!;
    expect(updatedGroup.members).toHaveLength(2);
    const acceptedInv = updated.invitations.find((i) => i.id === inv.id)!;
    expect(acceptedInv.status).toBe("accepted");
  });

  it("throws for an invalid invite code", async () => {
    await expect(kuriService.joinGroupByInviteCode("BADCOD", "X", "x@test.com"))
      .rejects.toThrow("Invalid or already used invite code.");
  });
});

describe("removeMember", () => {
  it("removes a member from the group", async () => {
    const admin = await kuriService.createUser("Admin", "admin@example.com");
    const member = await kuriService.createUser("Member", "member@example.com");
    const group = await kuriService.createGroup("Circle", admin.id, [], "");
    // Manually add member to group via inviteCode path
    const inv = await kuriService.inviteUser(group.id, admin.id, "Member", "member@example.com");
    await kuriService.joinGroupByInviteCode(inv.inviteCode, member.name, member.email);
    await kuriService.removeMember(group.id, admin.id, member.id);
    const data = await kuriService.getData();
    const g = data.groups.find((x) => x.id === group.id)!;
    expect(g.members.some((m) => m.userId === member.id)).toBe(false);
  });

  it("throws if non-admin tries to remove a member", async () => {
    const admin = await kuriService.createUser("Admin", "admin@example.com");
    const member = await kuriService.createUser("Member", "member@example.com");
    const group = await kuriService.createGroup("Circle", admin.id, [], "");
    await expect(kuriService.removeMember(group.id, member.id, admin.id))
      .rejects.toThrow("Only committee admin can remove members.");
  });
});

describe("createKuri", () => {
  it("creates a kuri plan for a group member", async () => {
    const user = await kuriService.createUser("User", "user@example.com");
    const group = await kuriService.createGroup("Circle", user.id, [], "");
    const kuri = await kuriService.createKuri(
      group.id, user.id, "Monthly Plan", 5000, "INR", "2025-01-01",
      [user.id], { rules: [{ channel: "in_app", beforeDays: 2, emailRecipients: [] }] }
    );
    expect(kuri.name).toBe("Monthly Plan");
    expect(kuri.contributionAmount).toBe(5000);
    expect(kuri.currency).toBe("INR");
    const data = await kuriService.getData();
    expect(data.kuris).toHaveLength(1);
  });

  it("throws if creator is not a group member", async () => {
    const admin = await kuriService.createUser("Admin", "admin@example.com");
    const outsider = await kuriService.createUser("Out", "out@example.com");
    const group = await kuriService.createGroup("Circle", admin.id, [], "");
    await expect(
      kuriService.createKuri(group.id, outsider.id, "Plan", 1000, "INR", "2025-01-01", [], { rules: [] })
    ).rejects.toThrow("Only group members can create a Kuri.");
  });
});

describe("updateGroupDetails", () => {
  it("updates name and description", async () => {
    const admin = await kuriService.createUser("Admin", "admin@example.com");
    const group = await kuriService.createGroup("Old Name", admin.id, [], "Old desc");
    await kuriService.updateGroupDetails(group.id, admin.id, "New Name", "New desc");
    const data = await kuriService.getData();
    const g = data.groups.find((x) => x.id === group.id)!;
    expect(g.name).toBe("New Name");
    expect(g.description).toBe("New desc");
  });

  it("throws if non-admin tries to update", async () => {
    const admin = await kuriService.createUser("Admin", "admin@example.com");
    const other = await kuriService.createUser("Other", "other@example.com");
    const group = await kuriService.createGroup("Circle", admin.id, [], "");
    await expect(kuriService.updateGroupDetails(group.id, other.id, "X", ""))
      .rejects.toThrow("Only committee admin can edit details.");
  });
});

describe("generateMonthlyInAppNotifications", () => {
  it("creates in-app notifications for matching kuri rules", async () => {
    const user = await kuriService.createUser("User", "user@example.com");
    const group = await kuriService.createGroup("Circle", user.id, [], "");
    // Start date on the 15th, rule fires 2 days before = day 13
    await kuriService.createKuri(
      group.id, user.id, "Plan", 1000, "INR", "2025-01-15",
      [user.id], { rules: [{ channel: "in_app", beforeDays: 2, emailRecipients: [] }] }
    );
    const testDate = new Date("2025-01-13");
    await kuriService.generateMonthlyInAppNotifications(testDate);
    const data = await kuriService.getData();
    expect(data.notifications.length).toBeGreaterThan(0);
    expect(data.notifications[0].userId).toBe(user.id);
    expect(data.notifications[0].read).toBe(false);
  });

  it("does not create duplicate notifications for the same day", async () => {
    const user = await kuriService.createUser("User", "user@example.com");
    const group = await kuriService.createGroup("Circle", user.id, [], "");
    await kuriService.createKuri(
      group.id, user.id, "Plan", 1000, "INR", "2025-02-15",
      [user.id], { rules: [{ channel: "in_app", beforeDays: 2, emailRecipients: [] }] }
    );
    const testDate = new Date("2025-02-13");
    await kuriService.generateMonthlyInAppNotifications(testDate);
    await kuriService.generateMonthlyInAppNotifications(testDate);
    const data = await kuriService.getData();
    expect(data.notifications).toHaveLength(1);
  });
});
