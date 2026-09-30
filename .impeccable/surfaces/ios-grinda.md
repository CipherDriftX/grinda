---
version: 1
slug: "ios-grinda"
primary_target: "ios/Grinda"
related_targets: []
---

# Surface brief: Grinda iOS app

Scope: whole iOS app (Today, Races, Progress, Wallet, onboarding, commit flow). Visitor mode: Operate.
Audience: adults trying to lose weight by walking; glance several times a day, one evening check, occasional longer sessions.
Task: see how far to go today, commit a stake to a challenge, trust where the money is.
Constraints: HIG navigation (tab bar, stacks, sheets), Dynamic Type, Dark Mode, Reduce Motion, SF Symbols.
Memorable moment: pinning your race bib (hold-to-commit) and breaking the finish tape when the stake comes back.
Unresolved: brand display face beyond SF Pro compressed; charity forfeit option.

## Direction contract

THESIS: A walking day is a race against yourself on a track. Refuses the category default of circular activity rings on a black screen with neon accents.

OWN-WORLD: Stadium track seen from above. Lane Cobalt field (Berlin 2009 blue track) owns the top of Today; lane-white lines; Tyvek cool-white bib cards with four safety-pin holes and a strict label grid (race name / goal / days / stake); ink near-black; Finish Volt reserved for completion and money returned; system red only for at-risk. Numerals are SF Pro heavy compressed, like bib numbers. Money bands on bibs carry banknote-grade fine line work (raise from Banknote/Guilloche: security-print precision where money is shown). No drop-shadow card stacks; depth comes from paper on field.

STORY: The user sees the track and knows at once how many laps remain, sees their bib pinned with the stake, trusts the Wallet ledger, and walks.

FIRST VIEWPORT: Today. Cobalt field top 55%: stadium-shaped progress lane with a runner dot; steps in huge compressed numerals in the infield, "4,120 to go · ~38 min walk" under it. Below on the ground: the active bib, pins visible, stake band, day punches. Primary action: none needed while active; "Enter a race" bib-shaped button when idle.

FORM: Track & Race Bib, candidate 4 of 7 on the ordered list, seed key a63e3c34. Raises: label grid ruling every card (from sneaker box stacks); numbers as hero material (from alphabet storm); completed days stay punched as history (from flash-scrawl sleeve); color reserved by meaning (from teletext).

Signature interaction: hold-to-pin. Four pins snap in at 25/50/75/100% with rigid haptics, bib settles on a spring, then Apple Pay sheet. Motion grammar: critically damped springs by default, bounce only on pin snap and tape break; numbers roll via numericText; Reduce Motion crossfades.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
