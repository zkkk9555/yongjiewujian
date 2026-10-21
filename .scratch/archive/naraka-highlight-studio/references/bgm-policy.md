# Dynamic BGM and beat policy

## Project status

Dynamic Douyin BGM discovery and acquisition are currently deferred. The default delivery does not contain a platform-native music cue and does not require a second manual music step.

## Principle

Never bake a one-year-old “hot BGM” list into the skill. For the current project, only a local or user-supplied track is eligible for automatic analysis and final rendering.

## Discovery versus audio acquisition

The workflow has two distinct capabilities:

- It can refresh current-trend metadata at task time and record the title, source, date, BPM, sections, mood, and availability.
- It can analyze any local or user-supplied MP3/WAV/M4A/other FFmpeg-readable audio file and use its beat map to place event packs, cuts, speed changes, impact text, and sound design.

A public trend page does not guarantee a downloadable production audio file. If a usable file is not available from the platform/source, keep the track as a platform-native cue and render against an approved local/reference track; save the cue-to-beat mapping so the platform sound can be added later. Do not silently substitute an unrelated song or place an untracked download in the asset library.

Record each candidate with:

```json
{
  "title": "track name",
  "source_url": "https://…",
  "observed_at": "2026-08-26T00:00:00+08:00",
  "bpm": 148,
  "sections": ["intro", "build", "drop", "outro"],
  "mood": "high_energy",
  "availability": "platform_native|local|user_supplied",
  "usage_note": "platform cue or approved local file"
}
```

Do not embed an audio file merely because a chart mentions it. The master must use a user-supplied or project-approved local track, or clearly separate a platform-native music cue from the rendered video.

## Music modes

### Local or supplied track

Use the actual audio for beat analysis, mix, preview, and master. Keep the BGM as a separate audio stem internally, even when the final MP4 contains the mix.

### Platform-native track

Use a reference copy or cue data to map the edit, but retain a clean or separately mixed master when the platform track is not available as a local approved file. Save the cue name, observed date, BPM, section markers, and the exact event-to-beat mapping.

## Beat map

The beat map should include:

- BPM and confidence;
- beat timestamps;
- bar and phrase boundaries;
- strong accents and drops;
- energy by section;
- optional manual correction points.

Use phrase boundaries for major scene changes and strong accents for impacts. Do not cut every shot on every beat; let some shots breathe so the combat remains readable.

## Audio mix defaults

- Keep game impact sounds intelligible.
- Duck BGM under player or team speech.
- Duck BGM briefly around a parry, kill, or ultimate impact when the original sound carries information.
- Avoid clipping and verify the final integrated loudness and true peak.
- Keep a separate BGM stem for later replacement.
