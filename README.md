# Project Kuri

Mobile-first membership app for local groups with invite-based onboarding and Kuri (money saving plan) creation.

## MVP Features

- Admin can create a group with a custom group name.
- Admin can invite users (email + name).
- Invitations generate join codes (and shareable deep-link style URLs).
- Members can join a group using invite code.
- Group dashboard with members list.
- Group can create Kuri plans.

## Tech Stack

- React Native + Expo (Android + iOS support from a single codebase)
- TypeScript
- AsyncStorage (local persistence for MVP demo)

## Product Flows

1. Admin creates group.
2. Admin invites members.
3. Members open app and join with invite code.
4. Group members can view group + active Kuris.
5. Admin/member creates a Kuri plan.

## Run (after scaffold install)

```bash
npm install
npm run start
```

Then open in Expo Go on Android or iOS.

## Phase 2 Suggestions (Kuri Rules Engine)

- Contribution frequency (daily/weekly/monthly)
- Fixed vs variable contribution amount
- Member payout order strategies
- Late payment rules and penalties
- Auto-reminders and payment tracking
- Wallet/payment gateway integration
