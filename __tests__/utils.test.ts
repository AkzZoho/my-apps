import { makeId, makeInviteCode, nowIso } from "../src/utils";

describe("nowIso", () => {
  it("returns a valid ISO 8601 string", () => {
    const result = nowIso();
    expect(() => new Date(result)).not.toThrow();
    expect(new Date(result).toISOString()).toBe(result);
  });

  it("returns a string close to the current time", () => {
    const before = Date.now();
    const result = nowIso();
    const after = Date.now();
    const ts = new Date(result).getTime();
    expect(ts).toBeGreaterThanOrEqual(before);
    expect(ts).toBeLessThanOrEqual(after);
  });
});

describe("makeId", () => {
  it("starts with the given prefix followed by underscore", () => {
    expect(makeId("usr")).toMatch(/^usr_/);
    expect(makeId("grp")).toMatch(/^grp_/);
    expect(makeId("msg")).toMatch(/^msg_/);
  });

  it("generates unique IDs on repeated calls", () => {
    const ids = new Set(Array.from({ length: 100 }, () => makeId("x")));
    expect(ids.size).toBe(100);
  });

  it("returns a string with non-empty suffix", () => {
    const id = makeId("pfx");
    const suffix = id.slice("pfx_".length);
    expect(suffix.length).toBeGreaterThan(0);
  });
});

describe("makeInviteCode", () => {
  it("returns a string of length 6", () => {
    expect(makeInviteCode()).toHaveLength(6);
  });

  it("returns only uppercase alphanumeric characters", () => {
    const code = makeInviteCode();
    expect(code).toMatch(/^[A-Z0-9]{6}$/);
  });

  it("generates codes that differ across calls", () => {
    const codes = new Set(Array.from({ length: 50 }, () => makeInviteCode()));
    expect(codes.size).toBeGreaterThan(1);
  });
});
