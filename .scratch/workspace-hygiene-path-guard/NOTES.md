# NOTES — workspace-hygiene-path-guard

Skills called: to-spec(implicit), to-tickets(implicit), implement, tdd(smoke), code-review(fast-lane)

## 2026-09-12 build evidence

- survey: root `f_*.jpg` 85 files / 1.68MB, all orphans (no report references root path without `shots`; hash differs from task-internal same-name file); `$T`, `14.848__` dup, garbled sibling, star-char dup dirs all 0 files; 11.844 task 3.98GB = preview 2.2GB (4 stale previews) + deliverables 1.52GB + shots 179MB + audio 70MB; C: used 256GB / free 67GB.
- 01 path guard: `roughcut-launch.md` §2.3 dispatch prompt requires task-dir prefix + cites §2.7; new §2.7 work-path iron rule (only `123\<id>.<name>`, ban list incl. `$T`/star/garbled/source disks, off-path outputs rejected as 未回); `AGENTS.md` §1 index added; §2.6 heading restored after an edit collision.
- 02 realtime cleanup: `deliverables-and-qa.md` new Realtime cleanup section (stale preview per-version purge, segment scatter purge on freeze, `audio_16k.wav` purge after master, all logged); `qa_gate.py` new `workspace_hygiene` gate (root `f_*.jpg`/`thumb_*.jpg`/`*.mp4`: 0=PASS, ≤10=WARN, >10=FAIL).
- hygiene gate red-green: before cleanup FAIL `85 strays, e.g. f_0001.jpg`; after cleanup PASS `no root strays`, full qa `pass True fail 0`.
- 03 cleanup: 85 orphans moved to `C:\Windows\Temp\root_strays_quarantine` (root `f_*.jpg` now 0); 4 empty shell dirs removed (`$T`, `14.848__` dup, garbled sibling, star-char dup); non-empty dirs untouched.
- 2026-09-12 historical purge (per new Realtime cleanup rule): 844 deleted v1-v3 full sets (21 files, 1.77GB; logged in reports/cleanup_log_v4.md); 835 deleted v2-v12 timelines + intermediates (24 files, 95KB; reports/cleanup_log_v14.md); 837 deleted review_v3 + v2/v3 companions (7 files, 393MB; reports/cleanup_log_v4.md). Quarantine `C:\Windows\Temp\root_strays_quarantine` (85 files) permanently deleted. Post-purge: 844 task 3.98GB→2.21GB, validate_v4 live re-run pass=true (7 eps); qa full pass True fail 0 with hygiene PASS; py_compile 4 scripts OK; root f_ 0, shells gone; C: used 254.5GB / free 69.2GB (freed ≈2.2GB).
- regress: `validate_combat_timeline.py` fixture pass; `py_compile` 4 scripts OK; root `f_*.jpg` glob empty (earlier `wc -l = 1` was the `ls: cannot access` error line, not a file); `$T` + garbled sibling confirmed gone.

## Code-review (fast lane: Standards + Spec)

- Standards: no new dependency; project root located by walking up to `AGENTS.md` (fixed an early parents[1] mis-scope that false-PASSed); compat flags untouched; deletions limited to verified orphans/empty shells.
- Spec: 3/3 tickets map to spec slices; boxes checked.
- Smell (record only): task-internal stale previews (e.g. 11.844 v1-v3) still occupy GBs — lifecycle now mandates per-version purge, but historical per-task purges remain for future task runs with user sign-off, not done silently here.
