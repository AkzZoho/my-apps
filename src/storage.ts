import { ref, get, set } from "firebase/database";
import { database } from "./firebase";
import { AppData } from "./types";

const DATA_REF = "appData";

const defaultData: AppData = {
  users: [],
  groups: [],
  invitations: [],
  kuris: [],
  chatMessages: [],
  notifications: [],
};

export const loadData = async (): Promise<AppData> => {
  try {
    const snapshot = await get(ref(database, DATA_REF));
    if (!snapshot.exists()) return { ...defaultData };
    const parsed = snapshot.val() as Partial<AppData>;
    return {
      users: Array.isArray(parsed.users) ? parsed.users : [],
      groups: Array.isArray(parsed.groups) ? parsed.groups : [],
      invitations: Array.isArray(parsed.invitations) ? parsed.invitations : [],
      kuris: Array.isArray(parsed.kuris) ? parsed.kuris : [],
      chatMessages: Array.isArray(parsed.chatMessages) ? parsed.chatMessages : [],
      notifications: Array.isArray(parsed.notifications) ? parsed.notifications : [],
    };
  } catch {
    return { ...defaultData };
  }
};

export const saveData = async (data: AppData): Promise<void> => {
  try {
    await set(ref(database, DATA_REF), data);
  } catch {
    // Firebase write failed silently — data will sync on next successful write
  }
};
