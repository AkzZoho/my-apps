import AsyncStorage from "@react-native-async-storage/async-storage";
import { loadData, saveData } from "../src/storage";
import { AppData } from "../src/types";

const defaultEmpty: AppData = {
  users: [],
  groups: [],
  invitations: [],
  kuris: [],
  payments: [],
  chatMessages: [],
  notifications: [],
};

beforeEach(() => {
  jest.clearAllMocks();
  (AsyncStorage as any).__proto__ && void 0;
  // Reset in-memory store between tests
  (AsyncStorage.clear as jest.Mock)();
});

describe("loadData", () => {
  it("returns default empty data when storage is empty", async () => {
    (AsyncStorage.getItem as jest.Mock).mockResolvedValueOnce(null);
    const data = await loadData();
    expect(data).toEqual(defaultEmpty);
  });

  it("returns parsed data when storage has valid JSON", async () => {
    const stored: AppData = {
      ...defaultEmpty,
      users: [{ id: "usr_1", name: "Alice", email: "alice@test.com" }],
    };
    (AsyncStorage.getItem as jest.Mock).mockResolvedValueOnce(JSON.stringify(stored));
    const data = await loadData();
    expect(data.users).toHaveLength(1);
    expect(data.users[0].name).toBe("Alice");
  });

  it("returns default empty data when storage contains invalid JSON", async () => {
    (AsyncStorage.getItem as jest.Mock).mockResolvedValueOnce("not-valid-json{{{");
    const data = await loadData();
    expect(data).toEqual(defaultEmpty);
  });

  it("fills missing array fields with empty arrays", async () => {
    (AsyncStorage.getItem as jest.Mock).mockResolvedValueOnce(JSON.stringify({ users: [] }));
    const data = await loadData();
    expect(data.groups).toEqual([]);
    expect(data.kuris).toEqual([]);
    expect(data.notifications).toEqual([]);
  });
});

describe("saveData", () => {
  it("serializes data to AsyncStorage", async () => {
    const data: AppData = {
      ...defaultEmpty,
      users: [{ id: "usr_abc", name: "Bob", email: "bob@test.com" }],
    };
    await saveData(data);
    expect(AsyncStorage.setItem).toHaveBeenCalledTimes(1);
    const [key, value] = (AsyncStorage.setItem as jest.Mock).mock.calls[0];
    expect(key).toBe("project_kuri_data_v1");
    const parsed = JSON.parse(value);
    expect(parsed.users[0].name).toBe("Bob");
  });

  it("round-trips data through save and load", async () => {
    const original: AppData = {
      ...defaultEmpty,
      users: [{ id: "usr_rt", name: "Carol", email: "carol@test.com" }],
    };
    let stored: string | null = null;
    (AsyncStorage.setItem as jest.Mock).mockImplementation(async (_k: string, v: string) => { stored = v; });
    (AsyncStorage.getItem as jest.Mock).mockImplementation(async () => stored);

    await saveData(original);
    const loaded = await loadData();
    expect(loaded.users[0].email).toBe("carol@test.com");
  });
});
