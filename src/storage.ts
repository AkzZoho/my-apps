import AsyncStorage from "@react-native-async-storage/async-storage";
import { AppData } from "./types";

const APP_STORAGE_KEY = "project_kuri_data_v1";

const defaultData: AppData = {
  users: [],
  groups: [],
  invitations: [],
  kuris: [],
  chatMessages: [],
  notifications: []
};

export const loadData = async (): Promise<AppData> => {
  const raw = await AsyncStorage.getItem(APP_STORAGE_KEY);
  if (!raw) return defaultData;
  try {
    const parsed = JSON.parse(raw) as Partial<AppData>;
    return {
      users: Array.isArray(parsed.users) ? parsed.users : [],
      groups: Array.isArray(parsed.groups) ? parsed.groups : [],
      invitations: Array.isArray(parsed.invitations) ? parsed.invitations : [],
      kuris: Array.isArray(parsed.kuris) ? parsed.kuris : [],
      chatMessages: Array.isArray(parsed.chatMessages) ? parsed.chatMessages : [],
      notifications: Array.isArray(parsed.notifications) ? parsed.notifications : []
    };
  } catch {
    return defaultData;
  }
};

export const saveData = async (data: AppData): Promise<void> => {
  await AsyncStorage.setItem(APP_STORAGE_KEY, JSON.stringify(data));
};
