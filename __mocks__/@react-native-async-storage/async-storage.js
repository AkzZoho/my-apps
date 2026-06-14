const store = {};

const AsyncStorage = {
  getItem: jest.fn(async (key) => store[key] ?? null),
  setItem: jest.fn(async (key, value) => { store[key] = value; }),
  removeItem: jest.fn(async (key) => { delete store[key]; }),
  clear: jest.fn(async () => { Object.keys(store).forEach((k) => delete store[k]); }),
  getAllKeys: jest.fn(async () => Object.keys(store)),
  multiGet: jest.fn(async (keys) => keys.map((k) => [k, store[k] ?? null])),
  multiSet: jest.fn(async (pairs) => { pairs.forEach(([k, v]) => { store[k] = v; }); }),
};

export default AsyncStorage;
