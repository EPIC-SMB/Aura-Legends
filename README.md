# Aura Legends

An original anime-style **grind-and-fight simulator** for Roblox, built to sit alongside the
games on the Charts page (Blox Fruits, Attack on Titan Revolution, Ragdoll Physics, Tsunami).

Collect elemental **Auras**, train your power, fight bosses across five zones, and spend your
way up a free upgrade track. Robux buys multipliers, cosmetics and convenience — never the
core loop.

---

## 1. Why this concept

The charts screenshot shows what the "Top Trending" and "Up-and-Coming" slots reward:

| Chart slot | Game | What makes it work |
|---|---|---|
| Top Trending | Blox Fruits | Collect powers → grind → fight bosses → unlock gear |
| Top Trending | Attack on Titan Revolution | Grind + raid bosses + anime power fantasy |
| Up-and-Coming | Ragdoll Physics | Low-effort, high-amusement physics toy |
| Up-and-Coming | Tsunami | Simple survive-the-event loop, instant understanding |

**Aura Legends** is the collect-and-fight loop: train → earn Energy → upgrade → fight a boss →
unlock a new Aura → unlock the next zone. Every system is visible within 30 seconds of joining,
which is the bar the chart-toppers set.

Everything is original — no Roblox assets, no branded names, no copyrighted material.

---

## 2. Roblox Creator Hub rules we're building to

Fetched from the live docs (not memory). These are the binding constraints:

### Passes are one-time permanent privileges
Restricted area, avatar item, or permanent power-up. **Not** repeatable currency.
Our passes (`VIP`, `Auto Train`, `Lucky Aura`, `Extra Pet Slot`) are all permanent privileges.

### Developer products are repeatable
Currency, potions, boosts. Our products (Energy packs, Respawn Token, 2x Boost, Mystery Aura
Capsule) are all repeatable.

### Every developer product is granted inside `ProcessReceipt`
Validate User ID, Product ID and receipt status. Grant only on an **Open** receipt, then
acknowledge so it never re-fires. Our `AuraServer.server.luau` does exactly this, keyed on
`PurchaseId` for idempotency — a re-delivered receipt never double-grants.

### Paid random items must disclose every outcome with exact odds summing to exactly 100%
The Mystery Aura Capsule shows all four outcomes with percentages in-game, and `AuraConfig.luau`
runs a load-time `assert` that both the weights **and** the displayed percentages total 100.
A future edit that breaks the odds fails loudly on load instead of shipping a policy violation.

Every outcome grants value — there is no "you lost your Robux" outcome.

### Restricted users need a real alternative
`PolicyService:GetPolicyInfoForPlayerAsync` is called on join. The gate **fails closed**
(unknown eligibility = restricted). Restricted users are never charged; the capsule is also
earnable from bosses (`BossDropChance = 0.05`), which is the "unpaid, earnable path" treatment
Roblox explicitly allows.

### No fake scarcity or fake timers
FOMO systems must be truthful. No countdown that auto-restarts, no "almost out of stock" claims.
Our only time-based system is the daily streak, which resets after a real 36-hour window.

### Free players must be able to play without spending
Roblox rules plus basic retention sense: paywall the core loop and the game dies. Free players
get a complete loop with a real currency sink.

---

## 3. The free loop has a real sink

The most common way to half-build a free-vs-paid game is to give free players a currency they
can earn but nothing to spend it on. Checked and enforced here:

| Check | Status |
|---|---|
| Is the free currency spendable? | Yes — **Energy** buys Power, Stamina and Aura Magnet upgrades |
| Does playing buy power? | Yes — Power adds real damage, Stamina adds real health, Magnet adds real pickup radius |
| Can Robux-only items be bought with Energy? | No — passes and products are Robux-only by definition |
| Is the split labelled in the UI? | Yes — the store colour-codes cards by source |

---

## 4. Psychology systems (all truthful)

| Mechanic | Psychology | Implementation |
|---|---|---|
| Variable ratio rewards | Skinner box — unpredictable rewards beat predictable ones | Random Aura drops from bosses, capsule rolls, daily reward quality |
| Zeigarnik effect | Incomplete tasks create cognitive tension | Boss HP bars, "Power Lv 47/100", "Zone 3/5", collection counters |
| Loss aversion | Losses loom ~2x larger than gains | Near-miss messaging ("one tier below Legendary"), streak preservation |
| FOMO (truthful) | Anticipated regret drives urgency | Daily login calendar with real 36h window — no auto-restarting timers |
| Commitment / consistency | Habit formation through routine | 7-day escalating login rewards, streak milestones |
| Sunk cost bias | Continued investment after prior spending | Collection screen, lifetime stats, boss kill counters |
| Endowment effect | Ownership increases perceived value | "Your Auras" collection, equipped Aura |
| Social proof | Peer behaviour influences participation | "X players online", "Y players defeated this boss today" |
| Dopamine anticipation | Uncertainty sustains engagement | Capsule roll animation, chest reveal, drop beams |

**Hard rules baked in:** odds are disclosed and sum to 100; near-miss messages are honest
(actual roll, not fabricated); streak bonuses are capped at 3x; no fake countdowns.

---

## 5. Free vs paid

| Item | Price | Type | What it does |
|---|---|---|---|
| **VIP** | R$199 | Pass | 2x Energy, VIP zone, golden aura trail |
| **Auto Train** | R$149 | Pass | Passive Energy while playing |
| **Lucky Aura** | R$99 | Pass | +25% Aura drop chance (in-game odds update) |
| **Extra Pet Slot** | R$79 | Pass | One additional companion |
| 500 Energy | R$49 | Product | Repeatable currency |
| 2,000 Energy | R$149 | Product | Repeatable currency |
| 7,500 Energy | R$499 | Product | Repeatable currency |
| 20,000 Energy | R$999 | Product | Repeatable currency |
| Instant Respawn | R$25 | Product | Skip the death timer |
| 2x Energy (1h) | R$69 | Product | Temporary boost |
| **Mystery Aura Capsule** | R$99 | Product (paid random) | 60% / 25% / 10% / 5% — odds shown in-game |

**A free player can reach every zone, max every upgrade, collect every Aura and clear every
boss.** Robux shortens the grind; it does not remove it.

---

## 6. Compliance mapping

| Creator Hub rule | Where it is satisfied |
|---|---|
| Passes are one-time permanent privileges | `Config.PASSES` — all four are permanent |
| Products are repeatable | `Config.PRODUCTS` — all repeatable |
| Grants only inside `ProcessReceipt` | `AuraServer.server.luau` → `MarketplaceService.ProcessReceipt` |
| Receipt idempotency | `processedReceipts[PurchaseId]` guard |
| Unknown product → `NotProcessedYet` | `processReceipt` early return |
| Offline player → `NotProcessedYet` | `Players:GetPlayerByUserId` nil check |
| Paid random odds disclosed, sum to 100 | `Config.PRODUCTS.MysteryAura.Odds` + `validateProducts()` |
| Restricted users not charged | `applyPolicyGate` (fail-closed) + `BuyCapsuleRemote` guard |
| Earnable alternative for restricted users | `FreeEarnable = true`, `BossDropChance = 0.05` |
| No fake timers / fake scarcity | Only real daily streak, 36h window |
| Free players have a complete loop | Energy → upgrades → zones → Auras |
| Maturity answers mirrored in config | `Config.MATURITY` |
| Pass privileges assigned server-side | `applyPasses` on join + `PromptGamePassPurchaseFinished` |
| No client-authoritative money | Client sends intents only; server grants everything |
| Rate limiting on repeatable remotes | `isRateLimited` — 10 actions / second, per player per action |
| DataStore fails soft in Studio | `pcall` around `GetDataStore`, in-memory fallback |

---

## 7. Project structure

```
AuraLegends/
├── default.project.json                 Rojo project file
├── AuraLegends.rbxl                     Pre-built place (double-click to open)
├── README.md                            This file
└── src/
    ├── ReplicatedStorage/
    │   └── AuraConfig.luau              ModuleScript — ALL balance/odds/prices + validation
    ├── ServerScriptService/
    │   └── AuraServer.server.luau       Script — economy, receipts, passes, persistence
    └── StarterPlayer/
        └── StarterPlayerScripts/
            └── AuraClient.client.luau   LocalScript — HUD, sends intents
```

`.luau` extensions throughout; Rojo 7.7.1 maps them to ModuleScript / Script / LocalScript
automatically (`.server.luau` → Script, `.client.luau` → LocalScript).

---

## 8. Rojo setup

### Fix the `rojo` command first (one time)

Your `rojo` shim is currently broken — `~/.aftman/aftman.toml` has the rojo entry commented out,
so the shim refuses to run it. Fix with:

```bash
aftman add rojo-rbx/rojo@7.7.1
```

That writes the entry into `aftman.toml` and makes plain `rojo` work. Rojo 7.7.1 is already
downloaded, so this is instant and needs no network.

### Option A — live sync (what we'll use for development)

```bash
cd "C:/Users/WINDOWS 10/Desktop/AuraLegends"
rojo serve
```

Then in Roblox Studio: open a place → **Plugins** tab → **Rojo** → **Connect**.
Every save on disk pushes into Studio. The Rojo plugin ships with Studio (install it from the
Studio Plugin Manager if it isn't there yet).

### Option B — one-click open (fastest way to just see it)

Double-click **`AuraLegends.rbxl`** on the Desktop. That opens the game immediately, no Rojo
needed. Use this to eyeball it; use Option A for real development.

### Rebuilding the .rbxl after edits

```bash
cd "C:/Users/WINDOWS 10/Desktop/AuraLegends"
rojo build . -o AuraLegends.rbxl
```

---

## 9. What's verified so far

**Static checks**
- `rojo build` passes; instance classes are correct (ModuleScript / Script / LocalScript).
- All three scripts parse cleanly as Lua (`luaparser`).
- `Config.validate()` runs on load and fails loudly: loot odds sum to 100, every upgrade
  declares a source, and `validateBalance()` proves every boss is winnable for a
  mid-investment build.

**Runtime checks (driven through the Studio MCP)**
- Server boots clean: config validates, remotes created, arena built (Baseplate, Spawn,
  BossPlatform, 5 zone pads).
- Train: client → server → Energy granted → HUD updated.
- Upgrade: Energy deducted, level raised, linear cost enforced, insufficient funds rejected.
- Boss fight: enter zone → boss HP bar → attacks reduce HP → boss dies → Energy reward →
  zone unlocked → boss visual despawned.
- Player death: boss damage → HP 0 → death overlay → 3s respawn → HP restored.
- Aura drop: weighted roll (verified with a temporary 100% chance) → granted → collection UI.
- DataStore fails soft in Studio and falls back to in-memory persistence.

**Not yet verified:** real Robux receipts and pass grants (needs products created in the
Creator Dashboard), cross-session persistence (needs the place published), and UI feel.

### Bugs caught by testing (and fixed)
1. HUD elements had auto-generated names, so nothing was inspectable from the MCP.
2. **Boss 1 was mathematically unwinnable** — it dealt 8 dps while the kill took 25s against
   100 HP. Rebalanced the whole curve and added `validateBalance()` so it can't regress.
3. `task.cancel` on the currently-running thread threw "cannot cancel thread", which aborted
   death processing entirely — the boss never cleared and the player never respawned.
4. The client kept the boss HP bar visible after death because the server cleared its own
   boss without telling the client.

---

## 10. Roadmap

| # | Milestone | Status |
|---|---|---|
| 1 | Skeleton loads in Studio | ✅ Done |
| 2 | Boss fights (HP, damage, death/respawn, zone unlock) | ✅ Done |
| 3 | Aura drops + collection screen | ✅ Done |
| 4 | **Boss visibility** — see known issues below | 🔜 Next |
| 5 | Shop (upgrade store, capsule odds panel, pass store) | |
| 6 | Engagement layer (daily streak UI, near-miss, social proof) | |
| 7 | Store setup (create passes/products, paste IDs into `AuraConfig`) | |
| 8 | Persistence verified across sessions | |
| 9 | Maturity questionnaire in Creator Dashboard | |

### Known issues

**Boss is invisible to the player (confirmed by inspection, not yet fixed).**
The boss spawns correctly — verified `Boss_<userId>` Model with a 10×10×10 neon-red
Body at `(0, 6, -70)`, transparency 0, anchored. The problem is orientation and distance:

| Thing | Position |
|---|---|
| Player spawns at | `(-2.3, 4.0, 42.4)` |
| Player/camera facing | `(-0.30, 0, +0.95)` → **+z** |
| Boss at | `(0, 6, -70)` → **112 studs behind the player** |

The boss is behind the player's back when the fight starts. Layout is also inconsistent:
zone pads sit at `z = +90` (in front of spawn) while the boss platform is at `z = -70`
(behind spawn).

**Planned fix (not applied):**
1. Flip the spawn to face -z toward the boss platform, or move the boss platform to +z.
2. Pull the fight closer — 112 studs is too far for a 10-stud boss; 35–45 studs reads better.
3. Add a direction cue (beacon/arrow) or make the boss larger so the arena direction is obvious.

---

## 11. Honest money notes

- You receive **70% of Robux spent**; the 30% marketplace fee is not negotiable.
- Robux only becomes real money through **DevEx**: age 13+, verified email, **30,000 earned
  Robux**, tax form on file. Standard rate is ~0.0038 Robux, roughly **$114 per 30,000 Robux**.
- **Paid access** to a game requires age 13+ with verified ID and a 30-day-old account. Passes
  and developer products do not.
- Cross-game developer product sales are **disabled from May 30, 2026** — this game is
  single-game only, no cross-game flows.
- All monetization IDs are currently **0**. The store shows "Setup pending" until you create the
  real passes/products in the Creator Dashboard and paste the IDs into `AuraConfig.luau`. This
  keeps the whole game testable in Studio before anything costs real money.
- Retention beats pricing. A game that free players enjoy grows; a game that paywalls its loop
  gets delisted by moderation and forgotten by players.

---

*Imagination is our only limit.*
