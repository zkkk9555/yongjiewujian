# Event, effect, text, and sound recipes

## Event taxonomy

Use semantic markers rather than generic “effect here” instructions:

```text
engage       进入交战
parry        振刀
counter      反打
combo        连招
clutch       残血极限
team_save    帮队友拆火/救援
ultimate     英雄大招
kill         单次击杀
multi_kill   连续击杀
escape       脱险/反杀后收束
```

Each marker has a source time, program time, confidence, and optional human confirmation state.

## Default recipes

The following are starting ranges, not immutable rules:

| Event | Picture | Audio | Text |
|---|---|---|---|
| parry | 0.45–0.75x lead-in, 2–4 frame hold, restrained flash | metal impact, short duck | optional “振刀” |
| counter | brief speed ramp into the hit, light punch-in | hit + whoosh | optional “反打” |
| kill | cut or impact aligned to a strong accent, tiny shake | low impact, preserve kill cue | optional kill text |
| clutch | retain setup, slow the decisive exchange, return to real time for result | heartbeat/riser used sparingly | “残血反杀” or none |
| ultimate | keep charge-up, place title on the release, protect the visual payoff | build → drop → impact | hero/ultimate name |
| team_save | show threat, intervention, and teammate outcome | duck BGM under callouts | “拆火成功” or none |

Effects must improve the read of the action. Avoid stacking flash, shake, zoom, blur, particles, and large text on the same frame unless the style profile explicitly calls for a climax.

## Text modes

- `dialogue`: speech subtitles for teaching or commentary.
- `impact`: short event labels for a montage.
- `title`: opening, chapter, or ending cards.

Keep these as separate tracks. Pure gameplay defaults to `dialogue: off` and `impact: selective`.

## Track contract

The internal timeline should separate:

```text
V1 main gameplay
V2 alternate/replay or punch-in
V3 overlays and effect plates
V4 text/title
A1 game audio
A2 player voice
A3 team comms
A4 BGM
A5 impact SFX
A6 transitions/riser
```

If the source does not contain separate audio tracks, document the limitation and use conservative ducking rather than pretending the speakers were isolated.
