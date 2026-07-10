---
id: 008
title: New group + 1-1 DM flows
status: todo
created: 2026-07-10
depends_on: [006, 007]
---

## Goal
Full chat matrix within a company: users create named group rooms and start 1-1 DMs with company members (self-DM and cross-company rejected), and both appear in the inbox with bidirectional messaging.

## Context
See `plans/basic-chat-poc.md` sections "High-level user flows D" (lines 52–56), "1-1 uniqueness" (lines 157–162), and "Chunk 8" (lines 362–369).

Critical constraints:
- New group form (name) → `Chat.create_group_room/2` → open room.
- New DM: picker lists company members via `Chat.list_company_users/1`, **excludes the current user** → `find_or_create_direct_room/2` → open room.
- Reject self-DM and cross-company in the UI (disable self option; cross-company members aren't listed).
- A↔B and B↔A resolve to the same `:direct` room.
- Both new rooms appear in the inbox; messages bidirectional.

## Acceptance criteria
- [ ] "New group" form (room name) creates a `:group` room via `Chat.create_group_room/2` and opens it
- [ ] "New message" DM picker lists company members via `Chat.list_company_users/1` and excludes the current user
- [ ] Starting a DM calls `Chat.find_or_create_direct_room/2` and opens the room
- [ ] Self-DM is blocked in the UI (current user not listed / option disabled)
- [ ] Cross-company members are not listed (cannot DM across companies)
- [ ] A↔B and B↔A resolve to the same direct room
- [ ] Created group + DM rooms appear in the inbox
- [ ] Messages flow bidirectionally in the new rooms
- [ ] Forms built with `to_form/2` and unique DOM ids
- [ ] Context + LiveView tests: A DMs B same company (bidirectional); self-DM blocked; cross-company username not listed/cannot DM; A↔B == B↔A — via element assertions