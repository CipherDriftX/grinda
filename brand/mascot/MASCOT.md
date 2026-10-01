# Steppie and the crew

![Character sheet](renders/cast-character-sheet.png)

## Steppie, the lead

A young lion runner: cobalt sweatband with a volt stripe, cobalt singlet with a race bib printed with the Stride S, navy shorts with volt side stripes, white socks, and chunky trainers (white upper, volt midsole, black outsole, two cobalt stride slashes on the side). He shares his name with the app, so every time someone talks about him, they're talking about Steppie.

- **The mane is a progress meter.** Cub, Young lion, Lion, King of the track, based on goal days in the last 14. It never resets overnight.
- **The trainers are a collection.** Every finished race earns a Shoe Box with a new colourway (10 pairs, Common to Legendary). Steppie wears whichever pair you pick, on Today, the track, the finish and the share card.
- **He runs.** On Today he runs your laps around the track with dust behind him while Dash paces you.

## The cast: each one owns a mechanic

| | Who | Owns | Personality | Accent |
|---|---|---|---|---|
| 🐆 | **Dash** the cheetah | The pacer ghost on your track; the weekly league | The rival who winks. Fast, cocky, never mean. Black "tear marks", purple pacer singlet with the stride slashes. | `#7C5CFF` |
| 🐢 | **Shelly** the tortoise | Shields | Slow, steady, wise. Round glasses, and her shell carries the Shield crest. | `#2E9E6B` |
| 🐦 | **Pip** the sparrow | Notifications, invites, the shadow week | Chatty messenger with a volt cap and a satchel with a letter. | `#5B8CFF` |
| 🐻 | **Bo** the bear | The Vault (money) | Calm, big, trustworthy. Cobalt vault-keeper vest with a gold lock badge and a security cap. | `#A87452` |

A rule for the writers: each character only talks about their own thing. Pip never talks about money amounts on the track, Bo never nags, Dash never shames, Shelly never sells hard.

## Geometry

- Everything is built from ellipses, capsules, tapers and béziers (absolute M/L/C/Q/Z) on a 400 × 460 canvas. Sources: `tools/steppie.py` (Steppie), `tools/cast.py` (the crew), `tools/geom.py` (primitives).
- `tools/export_swift.py` writes all of it into `ios/Steppie/DesignSystem/MascotArt.swift` as rigs: parts grouped by bone (shadow, tail, legs, body, arms, head, mane), pivots (neck, shoulders, hips, tail base, eye line) and per-mood face parts.
- `tools/render_assets.py` renders the marketing art in `renders/`. Never draw a character by hand in another tool; change the geometry and re-export.

## Motion

`CharacterView` in `Mascot.swift` animates every member of the cast with one rig.

| Where | Motion |
|---|---|
| Idle (Today, cards, widget) | Breath (1.5%, 2.8 s), tail sway (2.2 s), blinks every 2.4–4.8 s, and every third beat a glance to the side. Near-invisible on purpose. |
| Running (track, featured race) | 2.3 strides a second: alternating knee lift with a small hip rotation, arm pump ±32°, body bob, 4° forward lean, head counter-tilt, tail swing, shadow that breathes with each stride, dust puffs behind. |
| Tap / goal / pin | Hop with anticipation (squash 0.82), stretch on take-off (1.12), 54 pt air time, landing squash, a little spin, bouncy spring settle. |
| Rare moments | Confetti that flutters like paper, coin rain into the amount on the finish, rotating light rays, sparkles, shimmer on the call to action, a pulsing halo on the Shoe Box. |
| Reduce Motion | No loops, no hops, no particles. Expressions cross-fade. |

Pose changes use the snap spring (damping 0.62), the same physics as the bib pins.

## Moods

- **Steppie:** happy, calm, cheer, roar, worried, sleep, wink, proud, focus. **Poses:** idle, cheer, wave, hold, flex, point, run.
- **Cast:** happy, cheer, worried, wink, with the same poses.

## Marketing assets (`renders/`)

| File | Use |
|---|---|
| `cast-character-sheet.png` | Press kit, Discord welcome, landing page |
| `x-header.png` (1500 × 500) | X header: "Back yourself. Keep your money." |
| `avatar-steppie.png` | X and Discord avatar |
| `post-*.png` (1080 × 1350) | Launch posts: Back yourself · Keep every cent · Shelly's got it · Dash is ahead of you · Pick your table · Come back |
| `emoji-steppie-*.png`, `emoji-<cast>.png` | Discord emoji pack |
