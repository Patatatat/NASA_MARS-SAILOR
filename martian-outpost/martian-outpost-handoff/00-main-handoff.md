# Martian Outpost — Implementation Handoff

This directory is the team's operational source of truth. Build in Godot 4.7 for Web and Windows/itch.io. The game ships with English and Spanish text through locale JSON files; this handoff is in English.

## 1. Hackathon deliverable

Create a low-poly, cel-shaded, 3D isometric colony simulator with a top-down *Clash of Clans*-like camera. The primary audience is children ages 7–12; older players, families, and judges are secondary. The player sustains a Martian colony for 42 sols: one sol lasts 60 seconds at x1 (x0.5–x4). They win by reaching the end of sol 42 with at least one astronaut alive. After the fourth and final rocket arrives at the start of sol 28, no more cargo arrives. They lose when the last astronaut dies.

The intended feeling is optimization under pressure: astronaut hours, power, consumables, space, and Earth cargo compete. The educational promise is equally important: every meaningful choice must visibly teach a genuine deep-space constraint—life support, power, food, radiation shielding, or limited delivery mass. No aliens, combat, or fully active 256×256 map at the start.

### Non-negotiable: decisions must change the colony

The player must feel the environment answer their decision, rather than merely see a resource number decrease. Every important action needs: **(1) an understandable cost before confirmation, (2) an immediate world/UI effect, (3) a delayed consequence or opportunity cost, and (4) a short causal explanation in the Sol Report.** There is no universally safe action. If an action lacks a cost, risk, delay, lost alternative, or capacity trade-off, remove it or redesign it.

The first implementation target is the following decision-to-consequence set; it is more important than additional buildings, art, or optional minigames.

| Player decision | Immediate consequence | Later/environmental consequence | Lesson |
| --- | --- | --- | --- |
| Give power to ISRU/Base over Greenhouse/Lab | O2/water reserve stabilizes | Crops stop growing and can die; food shortage arrives later | Power cannot serve every system at once. |
| Build an extra Greenhouse without enough power | Food capacity looks higher | Its crops visibly wilt and die after the grace period; wasted Seeds/time | Capacity is useless without operating power. |
| Spend battery reserve at night on research/production | Research or plates arrive sooner | Less emergency reserve for life support, a storm, or dawn delay | Stored energy is a future safety choice. |
| Send crew outside during a solar flare to repair/build | Repair/building progresses | Dose rises; that astronaut may later require replacement, reducing rocket salvage | Mission work competes with radiation safety. |
| Shelter the crew during a flare | Dose is avoided | A breach/damage may worsen, pressure falls, and a module can be lost | Safety also has an operational cost. |
| Weld a breached tunnel | Costs EVA time/dose; tunnel returns quickly | The welded section becomes fragile and is more likely to fail again until upgraded | Emergency repair can create technical debt. |
| Use Spare Parts to repair safely | Damage is solved with less EVA risk | Fewer parts remain for the next crisis; they consume cargo/printing capacity | Preparedness consumes limited mass and materials. |
| Put cargo/people in a rocket manifest | Chosen shortage is addressed | Other cargo cannot arrive, and replacing crew prevents rocket salvage | Mass and crew continuity are mutually constrained. |
| Dismantle an arrived rocket | Gains materials now | That rocket can no longer bring a manual astronaut replacement | One arrival cannot solve every problem. |
| Scan and expand toward a sector | Uses power/research time | Reveals opportunity, but delays another research/unlock; an unsuitable sector gives no shortcut | Information costs resources and reduces uncertainty, not risk. |
| Assign less sleep / prioritize output | More work completes now | Morale/effectiveness decline and a mini-break may remove that worker later | Human capacity is a finite mission resource. |

Use visual environmental response wherever possible: dim or stopped machinery when unpowered, battery/state meters dropping, greenhouse plants changing from healthy to wilted to dead, a pressure leak effect at a breach, dust on panels, sheltering/returning crew, and a clearly marked radiation risk zone. The UI must name the cause in simple language, never blame the player with unexplained failure.

### Direct actions and uninterrupted simulation

The user removed the dedicated decision system. Do not build Decision Maker, DecisionService, DecisionLog, decision templates, forced choices, automatic pauses, or forced slowdowns. The player acts directly through building inspectors and the Crew, Energy, and Rocket panels. Ordinary actions still have costs and observable consequences; services retain factual reason IDs for the Sol Report without a separate choice-tracking system.

Storm protection, shelter/EVA orders, and power toggles remain direct service commands. Alerts indicate the affected target and allow navigation to its inspector; they never change speed or require acknowledgement before play can continue. The player retains manual pause and x0.5/x1/x2/x4 controls. Unhandled hazards continue at the chosen simulation speed. A manually paused simulation freezes all hazards. Victory/defeat ends simulation normally.

### Scope order

1. Clock/sols, day-night power, O2/water, work/sleep, manifest, and rockets.
2. Iron/regolith, tunnels/pressure, storms, autonomy, and Earth support.
3. Radiation/rotation, repairs, Sol Report, and admin panel.
4. Cut in this order: welding minigame; advanced animation; non-essential morale detail; non-essential upgrades. Never cut victory/defeat or the power, consumables, and rocket loops.

### NASA data and learning priority

The game must make its science traceable without pretending that a scaled game number is a literal mission forecast. Use a bundled, curated NASA data pack by default so the Web build and judges' demo work offline. It must label the pack as **archived NASA data**, show its retrieval date and source URL, and never call it live. A live DONKI refresh is an optional post-MVP enhancement only when an API key, connectivity, error handling, and a visible `Live data / Archived data` label exist.

Use the included `data/nasa/sources.json` manifest as the provenance registry. It identifies:

- **DONKI** for archived solar-flare/solar energetic particle event context and radiation-warning examples.
- **OSDR RadLab** for the meaning and units of absorbed-dose-rate evidence, not a claim that ISS readings equal a Mars surface dose.
- **Mars Trek** for site/terrain inspiration and source attribution.

Curated data may determine event type, date, explanatory Codex content, or a relative risk tier. Game balance values remain deliberately scaled and editable; label them as gameplay values. Do not convert a real reading directly into astronaut injury/death, invent a NASA measurement, or make an unreferenced scientific claim. The Codex `Sources & Science` page must show each source's plain-language explanation, URL, retrieval/archive date, and the distinction between data and the game's simplified model.

For ages 7–12, introduce only one new major system at a time. The always-visible survival story is: **air/water/food → power → safety from radiation**. Explain terms in place: for example, “sol = a day on Mars” and “radiation dose = invisible energy that can harm the body.” Advanced values live behind inspectors/Codex, while immediate outcomes are concrete (“plants are losing power,” “the crew is safer indoors”). Never make a scientifically accurate but opaque dashboard more important than a readable consequence.

## 2. World, construction, and power

The map limit is 256×256 tiles; only a 32×32 buildable area is available at the start. Satellite scanning reveals adjacent 8×8 sectors and unlocks their construction. Each sector reveals iron/regolith, an aquifer, or sterile terrain. Mines can only be placed on iron/regolith; ISRUs only on aquifers.

| Building | Size | Connection / note |
| --- | ---: | --- |
| Main Base | 3×3 | Astronaut living hub. |
| ISRU | 2×2 | Requires aquifer; no tunnel, gets power by proximity. |
| Tunnel | 1×1 | Connects buildings; can breach. |
| Refinery | 3×3 | Converts Iron Ore into Iron Plates. |
| Mine | 6×6 | Iron and regolith; no tunnel. |
| Greenhouse | 3×3 | Grows Food from Seeds. |
| Solar Panel | 3×3 | No tunnel; low output at night and in storms. |
| Battery | 2×2 | No tunnel; stores power. |
| Nuclear Reactor | 4×4 | Eight-tile exclusion radius; consumes Nuclear Cores. |
| Laboratory | 2×2 | Research and unlocks. |
| 3D Printer | 2×2 | Iron Plates + Chips → Spare Parts/EVA suits. |
| Landing Pad | 6×6 | Raises rocket cargo capacity; requires Regolith. |

Everything except Solar Panels, Batteries, Mines, the Reactor, and ISRU must connect to the tunnel network. Buildings without tunnels receive power when within three tiles of an energized building; power propagates through these proximity links or tunnels. The initial reactor powers the whole colony (an explicit exception to the proximity network); another reactor cannot be built until its technology is researched. Do not build within its eight-tile radius. EVA suits block most ambient radiation; the 3D Printer can make additional suits after EVA research.

The starting kit is: four astronauts selected from eight profiles, a Base, ISRU, Greenhouse, and a pre-installed reactor at a safe distance. Base, ISRU, Tunnel, Greenhouse, and Laboratory start unlocked; every other building requires the Laboratory. Adjustable values live in `data/balance.json`.

## 3. Resources and loops

| Resource | Production / use |
| --- | --- |
| Oxygen, Water, Food | Every astronaut consumes all three; ISRU produces O2/water and Greenhouses produce Food. |
| Regolith | Mining; tunnel shielding, Landing Pad, repairs/upgrades. |
| Iron Ore | Mining; Refinery input. |
| Iron Plates | Refinery; construction and 3D printing. |
| Nuclear Core | Earth only; fuel manually replaced by an astronaut. |
| Chips | Earth only; advanced research and 3D printing. |
| Seeds | Earth; planting/replanting Greenhouses. |
| Spare Parts | Earth or 3D Printer; safe repairs. |
| Medicine | Earth; recovers health/fatigue, never removes radiation dose. |

The Autonomy Index counts only Oxygen, Water, and Food: useful local production divided by consumption of those resources over a configurable window. Chips and Nuclear Cores do not count. A higher index reduces Earth cargo mass; a lower index grants more mass but creates dangerous dependence. Formula and limits are JSON data.

Without power, ISRU/Refinery/Mine/Printer/Laboratory stop; crops lose health and die after their configured grace period; the Base consumes reserves and astronauts die when they are exhausted. A tunnel breach loses O2: seal it and isolate the module, weld it with EVA risk, or spend Spare Parts for the safe repair. Welding leaves the section more fragile until upgraded.

At the end of every sol, show a compact **“What changed and why?”** report: production versus consumption, the largest shortage/surplus, active damage, and up to three causal statements supported by actual recorded simulation causes (for example, “Food fell because Greenhouse 2 had no power for 0.5 sol”). It is an explanation, not a lecture; a player can expand it for details. The report must never claim causality without an event/resource reason recorded by the simulation.

## 4. Astronauts and priorities

There are eight profiles, two for each specialty: Engineer, Botanist, Medic, and Scientist. Select four before the game; the same profile can be selected repeatedly, with a unique astronaut ID for each selection. Every profile has exactly one benefit and one drawback defined in data. Required example: a Medic gives +18% global morale. Specialties use multipliers, not complex skill trees.

Simulation automatically handles basic needs. Players may enable manual control and set priorities 1–4 per astronaut and category, or forbid a category: survival, emergency/EVA, production, and science/construction. An urgent order interrupts current work. Less sleep creates more output but lowers morale. Morale is required: below a threshold it reduces effectiveness, and a crisis may trigger a recoverable mini-break during which the astronaut does not work. If they do not recover, the player may exchange them for a rocket replacement, giving up that rocket's salvage.

## 5. Research, exploration, and threats

Tutorial: build a Laboratory, research and build the Solar Panel before the first rocket, then teach batteries. The starting inventory now contains 32 Iron Plates: 16 for the Laboratory, 10 for the Solar Panel, and up to 6 for new Tunnel tiles. The initial layout must support that route with at most six additional tunnels and pre-installed connections for the starting buildings. Battery construction is a later step, not guaranteed by this initial plate budget. R2 must validate the layout; R1 validates research/work timing before sol 7. Target cadence is one unlock roughly every three sols: Laboratory → solar/battery → Refinery → 3D Printer → reactor/other upgrades. Relevant technologies: satellite scan; mine; Refinery; 3D Printer; EVA; regolith tunnel shielding; Landing Pad; reactor.

Satellite scanning consumes research data and power to scan a contiguous 8×8 sector, reveal its terrain, and make it buildable. There is no other fog of war.

| Timing | Event |
| --- | --- |
| Sols 1–3 | First night; guide robot. |
| Sol 6 | Micrometeorite hits a tunnel. |
| 7, 14, 21, 28 | Rocket arrives at the start of the sol. |
| Sol 12 | Dust storm, −70% solar output for four sols. |
| Sol 16 | Solar particles: shelter or EVA with dose. |
| From sol 22 | Random announced events: only one active; storm warns 1 sol, flare 2. |
| Sols 28–42 | No more rockets; autonomy test. |

A solar flare increases dose; construction and EVA outside the Base are more dangerous. The player chooses shelter or responding to an emergency. A dust storm reduces solar power, accumulates panel dust, and can damage structures/tunnels. All probabilities, durations, warnings, and effects are editable JSON.

## 6. Rockets, manifest, and Earth support

Before each arrival, the player composes a manifest within the next rocket's mass limit: resources, Seeds, Spare Parts, Medicine, Chips, Nuclear Cores, and optional replacements. They also reserve an empty 8×8 landing zone; it remains blocked until removed after landing. On landing, cargo transfers. An astronaut can dismantle the rocket for salvage or exchange a person, but never both. Landing Pad increases maximum mass and requires Regolith.

Earth never cancels the program. Its support is calculated after every sol from autonomy and completed goals, and changes only the next manifest's mass. The panel must show the estimate before the player confirms shipment.

## 7. Admin panel and demo

The presentation has a strict ten-minute budget. A full 42-sol run at x4 takes 10.5 minutes without manual pauses; do not silently change the 60-second sol or the 42-sol campaign. Keep the ten-minute presentation as a guided demonstration using the existing forward-only admin controls. This is the planning interpretation of the user confirmation to retain ten minutes; the campaign duration is unchanged. The admin panel, hideable in the itch.io build, can advance to a specific sol, enable/disable/remove events and buildings, and trigger rockets or phenomena on demand. There is no rewind: do not implement snapshots. State must still serialize for save/load and administration. See `01-interface-guide.md`.

## 8. Player experience: menus, HUD, tutorial, and dialogue

### Screens and navigation

The main menu has four actions: **New Game**, **Credits**, **Settings**, and **Quit**. `New Game` opens astronaut selection: show all eight profiles, allow exactly four selections (including repeated selections of the same profile, each with a unique astronaut ID), show each profile's one benefit and drawback, then start the colony. Settings owns language (English/Spanish), audio, and accessible UI options; the same settings remain available during play.

The in-game HUD has fixed zones. It must not hide the world or permit an informational message to conceal a survival alert.

```text
TOP LEFT                                      TOP RIGHT
Oxygen | Water | Food | pressure | avg morale       Pause / x0.5 / x1 / x2 / x4

WORLD: isometric map, placement previews, selected-building status

BOTTOM LEFT                          BOTTOM CENTER → RIGHT
event/news/thought/science log       Build | Crew | Energy | Rocket | Lab | Resources | Codex
```

- **Top left:** always-visible Oxygen, Water, Food, pressure, and average morale. Use color plus icon/text/state; do not communicate danger by color alone.
- **Top right:** pause and speed modifiers. Time speed must clearly show the active multiplier.
- **Bottom left log:** chronological feed of critical hazards, operational news, optional astronaut thoughts, and short scientific facts. It has filters and unread/critical state. Critical hazards persist until acknowledged/resolved; decorative thoughts/facts never use alarm styling or audio.
- **Bottom centre to right:** one mutually exclusive workspace panel, with tabs: Build, Crew, Energy, Rocket, Laboratory, Resources, and Codex. Selecting a building additionally opens its contextual inspector without changing simulation values directly.
- **Building inspector:** clicking a world building opens its live status: name/type, production and demand (for example `0.3 / 5 W`), health/condition, relevant attributes, active modifiers, and a building-local event log. It shows what will happen next in plain language, such as “plants may die if power remains unavailable.” It offers direct validated actions; it does not calculate rules itself.
- **Codex:** short, localized explanations of discovered resources, buildings, hazards, and mechanics. It is reference material, never a substitute for an active warning or tutorial step.
- **Codex / Sources & Science:** also contains the NASA provenance screen described above, including the explicit archived/live status of the data pack.

On Web, panels must adapt to the available width: the workspace is a horizontally scrollable/reflowed tab bar, while vital-resource and speed controls remain visible. The UI designer owns a wireframe before implementation.

### Guide AI, tutorial, and dialogue

The guide AI is an in-world/screen character and the only tutorial speaker. It introduces the first three sols and appears again exactly when a new concept is first relevant (for example Laboratory research, Solar Panels/Batteries, satellite scanning, rocket manifests, radiation, and random-event warnings). Tutorial progression is event/condition driven, not tied to a fragile fixed timer.

Use one `DialogueService` with three outputs:

1. **Guide tutorial dialogue:** a localized title/body plus an optional `focus_target` (UI tab, world building, or map cell) and action requirement. It records completion so it is not repeated after save/load.
2. **Operational notifications:** localized, data-backed messages from services. Critical warnings are always placed in the log and may request acknowledgement; they do not require the player to read flavour dialogue before acting.
3. **Ambient dialogue:** random astronaut thoughts and scientific facts, placed in the log at a controlled cadence. They must be gameplay-neutral, skippable, localized, and suppressed while a critical alert is active.

Only one guide card is visible at once. Critical operational warnings pre-empt ambient content; when the warning clears, the guide card can resume. Dialogue choices do not alter simulation balance in this hackathon scope. Store tutorial definitions/trigger IDs and cadence in JSON; store all displayed prose in locale JSON. The log history and completed tutorial IDs belong in the save state.

The player may skip the entire tutorial and reactivate it from Settings or Codex. Skipping never hides critical operational alerts and does not make a game state unavailable.

## 9. 24-hour plan — four people with four development agents

Each person and their agent own one section of the game. Exactly four roles are defined in `roles/`; every source, scene, resource, and data file has one writer. Shared APIs do not imply shared file ownership.

| Block | Verifiable goal |
| --- | --- |
| 0–2 h | Confirm pending gameplay rules, freeze contracts, bootstrap services/stubs, validate export tooling. |
| 2–6 h | Integrated placement, camera, clock, power, consumables, crew and HUD; first playable loop. |
| 6–11 h | Research/production/scan, rocket manifest/arrival, first fixed threat, save/load. |
| 11–16 h | Complete rocket/autonomy loop, pressure/repairs, radiation/morale, remaining events and admin. |
| 16–20 h | Full 42-sol runs, balancing, EN/ES, tutorial, NASA provenance, art/audio integration. |
| 20–24 h | Feature freeze, blocking fixes, Web/Windows exports and timed ten-minute rehearsal. |

Read `roles/00-plan-maestro.md` for owners, integration gates, cuts and demo timing; `roles/contratos-integracion.md` for cross-role contracts. The old five-role/36-hour allocation is superseded. Missing gameplay choices are explicitly tracked in `roles/dudas-y-supuestos.md`; proposed balance changes are not already approved requirements.

Do not change public contracts without updating `01-interface-guide.md` and notifying every consumer owner. GDScript and reuse of the workspace-root project are documented technical assumptions, while Godot 4.7 is user-confirmed.
