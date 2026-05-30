export const nowIso = () => new Date().toISOString();

export const makeId = (prefix: string) =>
  `${prefix}_${Math.random().toString(36).slice(2, 10)}`;

export const makeInviteCode = () =>
  Math.random().toString(36).slice(2, 8).toUpperCase();
