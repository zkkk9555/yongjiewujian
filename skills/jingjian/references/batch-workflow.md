# Batch workflow for many matches

## Input model

Accept either a list of files or a folder. Scan only supported video extensions, preserve the supplied path, and create a manifest containing:

- absolute source path;
- filename, size, modification time;
- duration, frame size, frame rate, video/audio codecs;
- stable identity or fingerprint;
- task status and generated artifacts.

Do not copy the source videos into the project directory. Store links and metadata; use proxies or cached shots for editing.

## Batch selection

Treat each match as a source unit, then score all event packs together. Prefer a balanced episode:

```text
hook
→ first clear skill moment
→ escalation
→ strongest reversal or team save
→ climax / multi-kill
→ short payoff or clean ending
```

Avoid taking every high-volume segment from one match while ignoring stronger material in the other matches. Keep alternate candidates so a later style revision can replace a shot without re-running transcription or scene analysis.

## Caching

Cache work by source fingerprint and analysis version:

```text
cache/<source-id>/probe.json
cache/<source-id>/audio/
cache/<source-id>/transcript/
cache/<source-id>/scenes/
cache/<source-id>/events.json
cache/<source-id>/shots/
```

Changing BGM, style, text, or effect intensity must reuse source analysis. Changing only one event should rebuild that shot and the final assembly, not repeat the whole batch.

## Event packs

Every selected pack should contain:

```json
{
  "source": "match_03.mp4",
  "start": 412.4,
  "end": 427.8,
  "lead_in": 2.4,
  "impact": 418.9,
  "outcome": 424.6,
  "event_types": ["parry", "counter", "kill"],
  "confidence": 0.86,
  "reason": "完整保留进入交战、振刀、反打和击杀收束"
}
```

The `impact` marker is the anchor for beat matching and effects. `start` and `end` must retain enough context to understand the action.

## Batch failure handling

If one source is corrupt or unreadable, record it in the manifest and continue with the other matches. Do not silently drop a file. Deliver a concise report listing skipped inputs and the reason.
