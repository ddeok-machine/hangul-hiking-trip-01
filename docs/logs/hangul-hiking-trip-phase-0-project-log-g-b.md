# Hangul Hiking Trip — Phase 0 Project Log G-B

Nov 23, 2026 · @Smeef

The Hallasan animal sightseeing scene is built end to end (steps 9a to 9f), with DualSense support, Settings, Controls and a Quit menu (C1 to C3). The suite stands at 5180 passed at `20657d8`. Three bugs block a clean playthrough and come first next session (§7).

*Covers the build sessions from 11 to 23 November 2026 · Dev team: 니가 한국어 못해 (NHMH) · Previous log: G-A (11 Nov, planning) · Repo: `ddeok-machine/hangul-hiking-trip-01`*

> **Read this first in every new session.** Read this log, then Log G-A and Logs F to A for everything it doesn't change, then the documents they point to. **Markers:** ✅ DECIDED · 🟡 SUGGESTED · ❓ OPEN · 🔍 VERIFY · ❌ REJECTED. Later logs win over earlier ones; any rule here may be overridden by the user.

## 1. Workflow rules

The Log E, F and G-A rules stand. These were added or confirmed during the build.

| # | Rule | Status |
| --- | --- | --- |
| 1 | **Project logs are artifacts**, not code blocks to copy | ✅ user rule |
| 2 | **Before a fresh context window, ask whether to write a project log** | ✅ user rule |
| 3 | **No screenshots** in prompts or from Claude Code. The user playtests and confirms by eye | ✅ user rule |
| 4 | Prompts never run `git`. The user's Claude Code memory notes forbid it; blocked calls are reported as slips | ✅ |
| 5 | Commit commands name every file from `git status --short -uall` explicitly, in one block, then `git push origin main` | ✅ |
| 6 | Each prompt ends with a playtest checklist and the PowerShell commands, with the real Godot path `C:\Users\smeefer\nhmh\tools\godot\` (console exe for headless and `--pad-debug`, windowed exe for playtests) | ✅ |
| 7 | The suite now runs **over 10 minutes**. Prompts ask for new sections alone first, then **one** full run in the background with a long timeout | ✅ |
| 8 | `MIN_CHECKS` = the observed total minus 6. A count Claude Code infers without a full run is flagged | ✅ |
| 9 | Godot `.uid` files are committed with their scripts (since `0012bdb`) | ✅ |
| 10 | Playtest items the user can't reach may be marked "assume pass, fix later if found" | ✅ user rule |

## 2. Decisions that overturn or change earlier docs

| Earlier item | Was | Now | Status |
| --- | --- | --- | --- |
| G-A §4.4 (a death kills both) | One traveler at 0 ends the scene | A traveler at 0 is **downed**. The other can revive them with 쌍화탕 or 공진당 (1.5 s channel). Both downed ends the scene. Applies to foraging and the animal scene | ✅ |
| (new) Leaving a scene | Not covered | **Nobody leaves while a traveler is downed.** A **90 s** downed countdown sends the white deer (foraging) or the bear (animals) for the one still standing | ✅ |
| (new) Bleed-out timer | — | Option B is **off but kept on the table** for after playtests | ❓ |
| G-A §4.5, D3 (English hint flickers out in \~1 s) | Brief hint | **English stays in the need entry**, as in foraging. A **picture thought bubble** shows for **5 s** when a need is discovered | ✅ |
| G-A §4.3 (timer) | Random 6–12 min | Kept, and **hidden**: warnings are shakes and a distant roar from 120 s, then a shadow at 30 s | ✅ ⏰ revisit after playtests |
| Map (9a) | 48 × 24 m, rectangular pond | **144 × 72 m**, lake a **half disc** of radius 12 m at the near edge, centre (72, 36). Habitat zones: forest, grass, shore, lake, air | ✅ |
| Animal count | Cap of 5 | Cap **ramps 4 → 10 over 240 s**, minus one per met need, never below 3. Animals spawn near the view, off screen | ✅ |
| Healing bottles (9b-ii) | 2–4 | **6–9** | ✅ |
| Hint Letters v0.1 §2 #1 (trigger) | 120 s without progress | **60 s** in the game. Progress = grabbing a letter a need still lacks, or finishing a syllable. No escalation after the one letter | ✅ |
| Exit Note v0.1 §3 (수민 → 민수 letters) | Default format | **Exit notes are found writing of any format.** Authors are usually an irrelevant mystery (Exit Note 2 v0.1 §3) | ✅ |
| Animals writing | — | **Animals can't write.** The 노루's 우리 letter is the one exception | ✅ |
| Difficulty | — | **"Too hard is good"**: keep it for now | ✅ |
| Trees | Props with no collision | Later: **trunks block travelers only**, not animals | 🟡 not built |
| Renderer | Forward+ asked about | **Stay on GL Compatibility** (web export, low-end devices) | ✅ |
| 멧돼지 gift | In the 9f gift list | Moved to **9g**: it knocks over the 막걸리 아저씨's cart and loot rains | ✅ |
| Controls | Keyboard and mouse | **DualSense** supported; **Options = pause**; Settings, Controls and Quit in the pause menu | ✅ |
| GitHub org | NHMH | **ddeok-machine** (remote updated 20 Nov) | ✅ |
| Online co-op | — | A **direction, not a commitment** | 🟡 |

## 3. Commits and test counts

HEAD is `20657d8`. Counts are full-suite passes with 0 failed; "inferred" means Claude Code did not observe it in a full run.

| Commit | Date | Step | What it added | Passed |
| --- | --- | --- | --- | --- |
| `20657d8` | 23 Nov | C3 | Walking hardening, `--pad-debug`, Quit menu, placeholder main menu | 5180 |
| `7fd5999` | 23 Nov | C1 + C2 | DualSense bindings, Options pause, input prompts; Settings, Controls remap, vibration | 4925 (C1); 5095 inferred (C2) |
| `9323b6b` | 22 Nov | 9f | Animal gifts, 도감 pages, trophies, 6–9 heal bottles, `--debug-kit` with F9 | 4695 |
| `0012bdb` | 22 Nov | 9e | Hidden timer, warnings, bear, Exit Note 2, cairn exit, "To be continued"; Godot `.uid` files added | 4552 |
| `fcbeaed` | 22 Nov | Docs | Hallasan Exit Note 2 v0.1 | — |
| `03654b7` | 22 Nov | 9d | Predator hunts with gore, telegraphed attacks, 등산스틱 and 우산 blocks, crows drawn by the 어묵꼬치 | 4404 |
| `8c850a9` | 21 Nov | 9c-ii + 9c-iii | No leaving while downed, 90 s downed countdown; 60 s hint letters | 4148; 4268 |
| `4af6f36` | 20 Nov | Docs | Hallasan Hint Letters v0.1 | — |
| `0c527c2` | 19 Nov | 9c | Breakable tools, pickups, starter skewer, tool rewards | 4068 |
| `1326474` | 19 Nov | 9b-iv | Downed and revive in both scenes | 3912 |
| `97eee1d` | 18 Nov | 9b-iii | English in entries, picture bubbles, guide prompts | 3770 |
| `3f5679a` | 18 Nov | 9b-ii | Bite chance, count ramp, spawns near the view, 0/6 counter, heal bottles, need rewards | 3724 |
| `682ff8c` | 17 Nov | 9b | Letters on animals, bare-hand grabs, need discovery, spelling and item needs | 3667 |
| `427d859` | 17 Nov | 9a-vi | E opens word selection; named Input Map actions | 3399 |
| `7bb0fd6` | 17 Nov | 9a-iii to 9a-v | Habitat ground and props, water shader, camera fit, off-screen entry and exit | 3283; 3299; 3332 |
| `454bb5e` | 15 Nov | 9a + 9a-ii | Skeleton scene, foraging hand-off, 3× map, half-disc lake, habitats | 3220; 3240 |
| `984d775` | 11 Nov | Docs | Log G-A | — |

The suite grew from 3121 checks (Log F) to 5180. `MIN_CHECKS` is 5174.

## 4. What the animal scene now does

The scene is playable from the foraging hand-off to a "To be continued… 백록담" placeholder. It is hard, and the user wants it kept hard. All numbers live in `data/mountains/hallasan.json` under `animals`.

1. **Arrive.** Foraging's exit loads `scenes/animals/animals.tscn` through `scene_paths` (temporary until the cutscene exists). Hearts, backpack and tools carry over.
2. **Watch.** Animals cross a 144 × 72 m map from off screen and keep to their habitats. Standing near one fills a ring and reveals a **need**: an entry with empty blocks, its English, and a picture bubble for 5 s. Six needs end the scene ("0/6" counter).
3. **Fetch letters.** Letters ride animals and respawn, so a missed grab is never a dead end. Bare-hand grabs can bite (0.3, or 0.5 for 사슴 and 큰부리까마귀); predators carry a 1/4 downing roll. **Tools** grab without cost: 9 tools, per-instance uses, R / R1 next, F / L1 previous, starter 어묵꼬치 once per hike.
4. **Meet needs.** E / △ opens word selection; a word opens spelling, an item need hands the item over (but see §7 bug 2). Wrong syllables cost hearts.
5. **Hints.** After **60 s** without progress, a found-writing **hint letter** for the oldest word need floats in, once per need (nine letters, Hint Letters v0.1).
6. **Survive.** Predators (들개, 멧돼지, 검독수리) hunt other animals with gore, and a kill loses that animal's letter. About every 3 minutes a predator near you telegraphs an attack (red ring and "!"): step out to dodge. 등산스틱 blocks a boar, 우산 a diving crow; 고무장갑 shred on a predator hit.
7. **Heal and revive.** 6–9 bottles lie on the map, and met needs can drop 쌍화탕 or 공진당. A downed traveler starts the 90 s countdown; the bear comes at zero.
8. **Rewards.** Each met need sends that kind's absurd **gift** (or the next one of its kind walks it over); endangered and extinct kinds give twice, add a **도감 page**, and extinct kinds a **trophy**. The 오리 holds its gift until Space.
9. **The timer.** A hidden 6–12 min timer warns with shakes, roars and a shadow, then the bear kills both if needs remain.
10. **Exit.** After the sixth need, **Exit Note 2** (the 산악회 schedule) floats in and points to the **stone cairn** 4 m inside the far edge. Walking onto the trail behind it, with nobody downed, fades to the placeholder.

**Dev aids:** `--seed=N`, `--debug-kit` (kit in the backpack, F9 finishes the oldest need), `--debug-notes`, `--pad-debug`.

## 5. Controller, Settings, Controls and Quit

Both scenes and every menu work on a DualSense. Pad 0 drives the `p1_*` actions and pad 1 the `p2_*` actions; both pads steer menus, and the keyboard still works for both players.

| Input | DualSense | Keyboard | Status |
| --- | --- | --- | --- |
| Walk, menu moves | Left stick, D-pad | WASD / arrows | ✅ |
| Grab, pick, revive, confirm | ✕ (shown as ×) | Space / Enter | ✅ |
| Cancel, back, close | ○ | Esc | ✅ |
| Word selection | △ | E | ✅ |
| Backpack | □ | Tab | ✅ |
| Next / previous tool | R1 / L1 | R / F | ✅ |
| 수첩 | Touchpad and Share/Create | Q | 🔍 which one works on Windows |
| Pause | **Options** (fixed) | Esc (fixed) | ✅ |
| Give an item to an animal | **A trigger** (user request) | ❓ | ❓ §7 bug 2 |

**Pause menu:** Resume · Restart scene · Settings · Controls · Quit. ○ / Esc backs out one level; Options closes the whole menu.

- **Settings:** Master, Music and Effects volume (0–10, 0 mutes), Fullscreen / Windowed (hidden on web), Vibration on/off. Rumble fires on a hit, a downing and a completed revive.
- **Controls:** one row per remappable action, a keyboard slot and a pad slot. A clash swaps the two bindings; Esc, Options, ○ and the D-pad on button slots are refused. Captures cancel with Esc (keys) or Options (buttons) or time out after 5 s. "Reset to defaults" needs two presses. Settings and remaps save to `user://settings.cfg`.
- **Quit:** "Exit to Main Menu" or "Quit to Desktop" (hidden on web), each confirmed with two presses. The main menu is a **placeholder** (title, Start, Quit) and is **not** the project's main scene yet.
- **Glyphs:** `InputPrompts.label_for(action)` switches prompts between key names and pad glyphs live, and follows remaps. The Korean font lacks ✕, so Cross shows ×.
- **Drift:** with the first pad and Steam running, Fernanda walked on her own. Closing Steam and using another DualSense fixed it; no code cause was found. Walking now reads only the left stick and D-pad, with a radial dead zone of 0.3, ignores unknown pads, and ignores a held stick after menus, launch and replugging. `--pad-debug` logs devices and movement sources to `pad_debug.log` if it returns.

## 6. Deviations worth remembering

Claude Code reported numbered deviations at every step. These are the ones that still shape the build; the full lists are in each step's report.

| Step | Deviation | Why it matters |
| --- | --- | --- |
| 9a | The launch argument is `--seed=N` (foraging uses `--placement-seed`) | Two seed flags across scenes |
| 9a-ii | Entries are per-habitat edges; slow animals (비바리뱀, 1 m/s) hold a cap slot for minutes | Speeds may need raising if the map feels empty |
| 9a-iii | Trees dither out over travelers instead of being lowered; props have **no collision** | Trees that block travelers are still to build |
| 9a-v | The camera fits its ground footprint to the map edges; walk limits are the map minus the traveler radius | The lake now meets the screen bottom |
| 9a-vi | Letter selection kept the `p1_*` / `p2_*` actions; Esc stayed hardcoded until C1 | Fixed in C1 |
| 9b-iii | Spelling-view title shows the English again (reverses 9b) | Matches foraging |
| 9b-iv | A grab bites whoever is controlled; a downed traveler stays downed across a scene boundary (later blocked by 9c-ii) |  |
| 9c | Tools live on a **belt** in GameState (`tool:<uid>` rows), not in Inventory | The backpack lists two kinds of rows (§7 bug 1) |
| 9c-iii | Hint progress is detected by a rise in solved counts each tick | Foraging untouched |
| 9d | A block spends its cost even if the tool then breaks; only the controlled traveler's tool protects |  |
| 9e | Handwriting has **no tilt** (containers reset rotation); the cairn sits **4 m inside** the far edge; the wall is a bounds clamp, not a body |  |
| 9e | Returning from the placeholder starts a new hike |  |
| 9f | 도감 pages and trophies are unique per hike by backpack check; the 들개 gift waits 40 s and is bait for an attack |  |
| C1 | `ui_accept` / `ui_cancel` had no pad buttons in 4.7.2 defaults, so they are overridden; a stick counts once per push, with no repeat | Notebook scrolling no longer repeats on a pad |
| C2 | Only three audio players are routed (countdown music → Music; decoy "tsss" and bear roar → SFX); `backpack_p2` and `notebook_p2` are not remappable | Any new sound must be routed |
| C3 | Exit to Main Menu calls `new_hike()`, not `restart_scene()`; menu buttons shrank to 40 px with an 8 px gap to fit five |  |

## 7. Bugs to fix first next session

The user found three bugs after C3. The likely causes below come from a read of the code at `20657d8`; none is confirmed until Claude Code reproduces it 🔍.

**Bug 1: the backpack can't be cycled to healing items when it holds many things.** Fernanda can't heal.

- The selection (`backpack.gd`, `key()`) steps only through selectable rows: elixirs, the 수첩 and tool rows. The rows sit in a `ScrollContainer` (`backpack_hud.gd`), but no code scrolls it to the selected row. The likely cause is a selection that moves **off screen** with nothing following it 🟡.
- The panel is 520 × 560 px and no capacity limit was found, so a **full backpack is probably not the cause** 🟡.
- The user suggested a **drop item** option ❓. It may still be wanted for clutter (9f added junk, souvenirs and trophies). Decide after the fix.

**Bug 2: E / △ only spells; it doesn't give animals the items they need.** This makes the scene impossible to finish.

- A give path exists: E opens word selection over **every** unfinished need, items included; confirming an item need calls `open_spelling()` → `give_item()` (`animals.gd`). The guide says "Press {spell\_open} to give it."
- `give_item()` returns false **silently** when picks aren't allowed, the spelling view is open, or the backpack lacks the item. Claude Code must find which case the user hits 🔍.
- Item needs are drawn only while the backpack holds the item; an item drunk or given away later leaves a need that can't be met 🟡.
- **User request ✅:** giving gets its own **DualSense trigger** and a keyboard key. Which trigger (R2 or L2), and whether the animal must be in reach, are ❓.

**Bug 3: the foraging map is full of mystery grey boxes.** They are to be removed ✅.

- They are the **graybox props**, built in `foraging.gd` from `foraging.props` (6.25 per 100 m², seed 7): grey box "rocks", grey cylinder stones and trees, in rotation. The backdrop also builds box and cone pieces 🟡.
- Removing them touches the exit note's `clear_prop` clearance, the prop fade and the tests that place things clear of props. ❓ Remove the boxes only, or all props?

**Also unverified from C1–C3 and 9f:**

- 🔍 Checklist item 3 of 9f: 도감 pages and trophies.
- 🔍 The Quit flows (two-press confirm, landing on the main menu, Start back to Hallasan, Quit to Desktop).
- 🔍 Touchpad or Share/Create for the 수첩; live fullscreen switching; rumble on a real pad.
- ❓ Should the placeholder main menu become the project's main scene?

## 8. Slips and errors

No slip reached the repo broken; every one was caught by a test, a permission check or the user.

| Who | Step | Slip | Fix |
| --- | --- | --- | --- |
| Claude (chat) | 9a | PowerShell commands used a placeholder path `C:\path\to\...` | Real path given (§1 #6) |
| Claude (chat) | 9a | The prompt omitted each animal's tier, so Claude Code guessed | Tier fix prompt |
| Claude (chat) | 9a-v | Claimed the test count varied between runs; it was a stale `MIN_CHECKS` (3299 vs 3298) | Corrected; the count is now exact |
| Claude Code | 9a | Started a subagent by mistake (it did nothing) | Prompts now say "do not start subagents" |
| Claude Code | 9a-v, 9c, C3 | A command included `git`; the permission check blocked it each time | Prompts repeat the no-git rule |
| Claude Code | 9a-ii | `MIN_CHECKS` off by one, set without a re-run | Re-run confirmed |
| Claude Code | 9a-vi | Scripted edits left a duplicate function and turned files CRLF | Fixed; LF/CRLF warnings remain (§9) |
| Claude Code | 9b | Letter weighting read from review words only, not all need words | Fixed in 9b-ii |
| Claude Code | 9c-iii | Two parse errors in new test code; the hung run was killed on low memory | Typed the variables; re-ran |
| Claude Code | 9f | A parse error hung the suite; two runs timed out at 580 s | Suite now runs over 10 min (§9) |
| Claude Code | C2 | Three failures fixed and only the affected sections re-run; 5095 inferred | C3's full run passed at 5180 |

## 9. Technical debt

The test suite is the main debt: it takes over 10 minutes, so it is starting to time out Claude Code. A cleanup prompt is owed **before 9g** 🟡.

- **Six static test switches** on `animals.gd`: `tools_enabled`, `hints_enabled`, `predators_enabled`, `timer_enabled`, `exit_enabled`, `gifts_enabled`. Older sections turn them off and newer ones on. Replace them with one test helper that enables what each section needs 🟡.
- **Runtime and memory:** long simulated scene runs and scenes left alive; Claude Code once had to kill a run on low memory. Free test scenes after each section and shorten simulations 🟡. Runs also end with an "N resources still in use at exit" line.
- **File size:** `tests/test_runner.gd` is 17,747 lines; `animals.gd` is 2,171 and `foraging.gd` 2,068. Splitting tests by scene would allow single-section runs 🟡.
- **Shared code in `scenes/foraging/`:** the animal scene and menus use foraging's HUD scripts (`pause_menu`, `backpack`, `hit_fx`, `revive`, `countdown_music`, the new Settings, Controls and Quit screens). A move to a shared folder is still to come 🟡.
- **LF/CRLF warnings** on `project.godot` and `tests/test_runner.gd`. A `.gitattributes` would settle line endings 🟡.
- **Data left unused:** `animals.ground_color`, `animals.lake.color`, and `lake.height` (kept only because a test needs it).
- **Temporary hand-off:** `scene_paths` maps `cutscene_foraging_to_animals` straight to the animal scene until the cutscene exists.

## 10. Production docs and open questions

| Doc | Path | Status |
| --- | --- | --- |
| Hallasan Hint Letters v0.1 | `docs/production/hallasan-hint-letters-v0.1.md` | ✅ new (`4af6f36`). Its 120 s trigger is overridden by 60 s (§2); fold that into v0.2 when it is next revised |
| Hallasan Exit Note 2 v0.1 | `docs/production/hallasan-exit-note-2-v0.1.md` | ✅ new (`fcbeaed`). Changes the exit-note series rule |
| Hallasan Animal Word Bank v0.1 | `docs/production/hallasan-animal-word-bank-v0.1.md` | ✅ current |
| Hallasan Item Names v0.1 | `docs/production/hallasan-item-names-v0.1.md` | To be superseded by v0.2 ("Korean yam"), still unwritten |
| 도감 pages and gift texts | `data/notes/dogam.json`, `animals.gifts` | Approved in chat and held in data only, no production doc |

Nothing was superseded this session.

**Open questions**

1. ❓ Which trigger gives items (R2 or L2), and must the animal be in reach? (§7 bug 2)
2. ❓ A **drop item** option in the backpack. (§7 bug 1)
3. ❓ Remove only the grey boxes from foraging, or all graybox props? (§7 bug 3)
4. ❓ Should the placeholder main menu become the main scene?
5. ❓ Bleed-out timer (option B): keep it off?
6. ❓ 우산 auto-block, so a crow dive needs no tool swap within the 1.2 s telegraph.
7. ❓ The three people waiting at the stone tower (Exit Note 2 §7): a cameo in the next scene, or a mystery?
8. ❓ Do hint letters get audio of the target word? (Hint Letters v0.1 §6)
9. ❓ How to hint unreadable words beyond the letters, for later mountains.
10. ❓ Carried from G-A: who writes the silent ㅇ note; tool scenarios before the scene; the 백록담 boss bonus; the timer range after playtests ⏰.
11. 🔍 The 사슴's diet and 미나리 for 오리; a cairn (돌탑) on a real Hallasan route; 노루생태관찰원's exact name.
12. 🔍 **Native-speaker review** of the nine hint letters, Exit Note 2 ("Mr. 동", 산악회), the 도감 pages and all game Korean.

## 11. Next steps

Next session opens in MODE: DEV with one fix prompt for the three bugs, then the test cleanup, then 9g.

| # | Work | Mode | Status |
| --- | --- | --- | --- |
| 1 | **Fix prompt (B1):** backpack selection scrolls into view and reaches healing items; giving works and has its own trigger and key; foraging's grey graybox props removed. Settle open questions 1–3 first | DEV | next |
| 2 | **Test cleanup:** one helper instead of six switches, free test scenes, shorter runs, single-section runs | DEV | before 9g |
| 3 | **9g:** the 막걸리 아저씨 — a 수레 cart, bright and friendly; sells 집게, 우산 and 고무장갑 at ridiculous prices, and 막걸리 (dizzy, heals ½ ♥); the 멧돼지 gift knocks his cart over and loot rains | DEV | after 2 |
| 4 | Owed playtest checks (§7, "Also unverified") | User | any time |
| 5 | Trees as trunk colliders that block travelers only | DEV | later |
| 6 | The 백록담 scene: the white deer boss word, the three at the tower | CHAT → WRITE → DEV | later |
| 7 | Content: Item Names v0.2, tool scenarios, the silent ㅇ note, overheard conversations, native-speaker review | WRITE | pending |
| 8 | Art direction for the animal scene (placeholder boxes and code-drawn pictures today) | FRONTEND | 🟡 |
| 9 | Save this log as `docs/logs/hangul-hiking-trip-phase-0-project-log-g-b.md` (export as Markdown) and commit it | User | now |
| 10 | Clean up duplicate Project docs, after confirmation | User | pending |
