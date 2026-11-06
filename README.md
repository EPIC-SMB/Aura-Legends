# Aura Legends

An original anime-style **grind-and-fight simulator** for Roblox, built to sit alongside the
games on the Charts page (Blox Fruits, Attack on Titan Revolution, Ragdoll Physics, Tsunami).

Collect elemental **Auras**, train your power, fight bosses across five zones, and spend your
way up a free upgrade track.

**This is a fully free game.** No passes, no developer products, no paid random items — every
reward is earned by playing.

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

## 2. Design rules we're building to

### Free players get a complete loop
Every reward in the game is earned by playing. Energy is the single currency, and it is both
earnable and spendable — see section 3.

### No fake scarcity or fake timers
FOMO systems must be truthful. No countdown that auto-restarts, no "almost out of stock" claims.
Our only time-based system is the daily streak, which resets after a real 36-hour window.

### Combat is server-authoritative
Clients send intents ("I attacked", "I entered zone 1"). The server decides the outcome and
pushes the result back. Nothing about the player's state is trusted from the client.

### Rate limiting and validation on every remote
Every repeatable remote is rate-limited per player (10 actions/second), and every argument is
type-checked before use. See section 6.

---

## 3. The free loop has a real sink

The most common way to half-build a free-vs-paid game is to give free players a currency they
can earn but nothing to spend it on. Checked and enforced here:

| Check | Status |
|---|---|
| Is the free currency spendable? | Yes — **Energy** buys Power, Stamina and Aura Magnet upgrades |
| Does playing buy power? | Yes — Power adds real damage, Stamina adds real health, Magnet adds real pickup radius |
| Is there any premium currency? | No — Energy is the only currency, and it is earnable by playing |
| Is the split labelled in the UI? | N/A — there is nothing to split |

---

## 4. Psychology systems (all truthful)

| Mechanic | Psychology | Implementation |
|---|---|---|
| Variable ratio rewards | Skinner box — unpredictable rewards beat predictable ones | Random Aura drops from bosses, daily reward quality |
| Zeigarnik effect | Incomplete tasks create cognitive tension | Boss HP bars, "Power Lv 47/100", "Zone 3/5", collection counters |
| Loss aversion | Losses loom ~2x larger than gains | Near-miss messaging ("one tier below Legendary"), streak preservation |
| FOMO (truthful) | Anticipated regret drives urgency | Daily login calendar with real 36h window — no auto-restarting timers |
| Commitment / consistency | Habit formation through routine | 7-day escalating login rewards, streak milestones |
| Sunk cost bias | Continued investment after prior spending | Collection screen, lifetime stats, boss kill counters |
| Endowment effect | Ownership increases perceived value | "Your Auras" collection, equipped Aura |
| Social proof | Peer behaviour influences participation | "X players online", "Y players defeated this boss today" |
| Dopamine anticipation | Uncertainty sustains engagement | Aura drop beams, boss defeat rewards |

**Hard rules baked in:** drop odds are disclosed in-game and sum to 100; near-miss messages are
honest (actual roll, not fabricated); streak bonuses are capped at 3x; no fake countdowns.

---

## 5. The in-game economy

One currency, two directions. That's the whole economy.

| Direction | Source | Where it goes |
|---|---|---|
| **Earn Energy** | Training, boss kills, daily login rewards | — |
| **Spend Energy** | — | Power, Stamina, Aura Magnet upgrades |

| Upgrade | Effect | Max level | Cost formula |
|---|---|---|---|
| Power | +8 damage | 100 | `10 + 5 × level` |
| Stamina | +40 max health | 60 | `15 + 6 × level` |
| Aura Magnet | +6 pickup radius | 25 | `20 + 6 × level` |

Costs are **linear**, not exponential. Exponential (`10 × 1.16^level`) makes the late game
mathematically impossible to afford; linear keeps the grind predictable.

**A player can reach every zone, max every upgrade, collect every Aura and clear every boss
without spending anything.** There is no premium track.

---

## 6. Compliance and safety mapping

| Rule | Where it is satisfied |
|---|---|
| No fake timers / fake scarcity | Only the real daily streak, 36h window |
| Free players have a complete loop | Energy → upgrades → zones → Auras |
| Maturity answers mirrored in config | `Config.MATURITY` |
| No client-authoritative state | Client sends intents only; the server decides and pushes results |
| Rate limiting on repeatable remotes | `isRateLimited` — 10 actions/second, per player per action |
| Type validation on remote arguments | Every handler checks `type()` before use |
| Per-action cooldowns | Attack is capped at `Config.PLAYER.AttackInterval` |
| DataStore fails soft in Studio | `pcall` around `GetDataStore`, in-memory fallback |
| No paid random items | Nothing is purchased, so the odds-disclosure rules don't apply |

---

## 7. Project structure

```
AuraLegends/
├── default.project.json                 Rojo project file
├── AuraLegends.rbxl                     Pre-built place (double-click to open)
├── README.md                            This file
└── src/
    ├── ReplicatedStorage/
    │   └── AuraConfig.luau              ModuleScript — ALL balance/odds + validation
    ├── ServerScriptService/
    │   └── AuraServer.server.luau       Script — economy, combat, persistence
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

**Not yet verified:** cross-session persistence (needs the place published and Studio API
access enabled) and UI feel/animation.

### Bugs caught by testing (and fixed)
1. HUD elements had auto-generated names, so nothing was inspectable from the MCP.
2. **Boss 1 was mathematically unwinnable** — it dealt 8 dps while the kill took 25s against
   100 HP. Rebalanced the whole curve and added `validateBalance()` so it can't regress.
3. `task.cancel` on the currently-running thread threw "cannot cancel thread", which aborted
   death processing entirely — the boss never cleared and the player never respawned.
4. The client kept the boss HP bar visible after death because the server cleared its own
   boss without telling the client.

---

## 10. What's left to build

Priority tiers. Tier 1 is required before the game can honestly be called complete.

### 🔴 Tier 1 — Required for a complete game

| # | Item | Why it matters | State |
|---|---|---|---|
| 1 | **Aura abilities** | Auras are currently trophies, not powers. `Config.AURAS` defines `Ignite`, `Freeze`, `Surge`, `Phase`, `Nova` — nothing reads them. Needs ability buttons, cooldowns, real effects, and an equip system. | Not built |
| 2 | **Shop UI** | Only a `POWER +` button exists. Stamina and Magnet are buyable only through code — no player can purchase them. Needs a real upgrade panel with level, cost and effect preview. | Not built |
| 3 | **Boss models** | Five bosses, all identical glowing red cubes with different stats. Each needs its own silhouette (body, head, legs, eyes). | Not built |
| 4 | **Multiplayer correctness** | Boss models are created on the server into `workspace.AuraBosses`, which replicates to every client. In a 2-player server, player B sees player A's boss. Needs a decision: render bosses client-side (each player sees only their own) or make bosses shared co-op. | **Known bug** |

### 🟡 Tier 2 — Makes it feel like a real game

| # | Item | State |
|---|---|---|
| 5 | Daily reward calendar UI | Server logic works (+Energy), no UI — players can't see the 7-day escalation |
| 6 | Aura equip + player visual | No equip UI; no trail/effect when an Aura is equipped |
| 7 | Near-miss messaging | `Config.ENGAGEMENT.NearMissThreshold` exists, not implemented |
| 8 | Streak milestones | `Config.DAILY.StreakBonusCap` exists, not implemented |
| 9 | Social proof | `Config.ENGAGEMENT.SocialProofMinPlayers` exists, not implemented ("X players online") |
| 10 | Juice | No sound, no drop beams, no hit flashes, no screen shake |

### 🔵 Tier 3 — World & polish

| # | Item | State |
|---|---|---|
| 11 | Zone theming | All 5 zones share one arena; Ember Forest, Frost Peak and Storm Coast look identical |
| 12 | Boss telegraphs / dodge | Boss hits are automatic — no player agency, no timing skill |
| 13 | Boss phases / enrage | Every boss uses the same attack loop; only numbers differ |
| 14 | Arena decoration | Bare platform + pads |
| 15 | Beacon decision | Keep / recolour / remove — open question |
| 16 | Magnet effect | Buyable, but there is no pickup system, so it does nothing |

### ⚫ Tier 4 — Release

| # | Item | Owner |
|---|---|---|
| 17 | Persistence verification | Needs the place published + Studio API access enabled; saves currently reset in Studio |
| 18 | Remove debug attributes | `AuraDbgPlayerHP`, `AuraDbgBossHP`, `AuraDbgBossZone`, `AuraDbgAuras` must be stripped before shipping |
| 19 | Maturity questionnaire | Fill it in Creator Dashboard to match `Config.MATURITY` |
| 20 | Leaderboard (optional) | Stats exist (`LifetimeEnergy`, `BossKills`), no UI |

### Recommended order

1. **Aura abilities** — connects collection → combat, makes the whole loop feed itself
2. **Shop UI** — without it, two of three upgrades are unreachable by players
3. **Boss models** — the visual payoff
4. **Multiplayer fix** — small, but a correctness bug that gets worse with more players

Then Tier 2's engagement layer (items 5–9): it is mostly config + UI once the foundations exist.

---

## 11. Known issues

**Boss is currently a glowing red cube.** Verified working — a 20×20×20 neon body at
`(0, 11, -45)`, correctly in view on spawn (`in_view_dot = 0.954`). It has no silhouette yet:
no head, legs, or eyes, so "Cinder Wolf" doesn't read as a wolf. See Tier 1 item 3.

**The boss beacon is red and reads as a "zone marker".** It's a 70-stud translucent neon pillar
at `(0, 36, -70)` marking the arena. Open question: keep, recolour, or remove. See Tier 3 item 15.

---

## 12. Why there's no monetization

Deliberate choice for a first game:

- **Monetization doesn't make a game fun — it makes a fun game profitable.** With no players
  yet, revenue is zero while the compliance surface is real.
- **It removes a whole class of risk.** Roblox audits `ProcessReceipt`, requires exact odds
  disclosure for paid random items, and requires PolicyService gating. A first release is
  better off without that liability.
- **The effort goes into the game instead** — boss models, the shop UI, and the engagement
  systems that make people stay.
- **It's reversible.** The economy is data-driven; re-adding passes/products later is a
  config table plus a storefront, not a rewrite.

Roblox's monetization rules still apply the day you add it back: 70% revenue share, DevEx at
30,000 earned Robux with age 13+ and a tax form, and paid random items need disclosed odds
summing to exactly 100%.

---

*Imagination is our only limit.*
