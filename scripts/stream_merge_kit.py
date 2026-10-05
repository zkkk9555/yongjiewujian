"""Build one real island-merge output, for test_partial_refusal.sh to point at.

The refusal test must run against a genuine `merge_decision_v*-partial-r*`
artefact, not a hand-written stub: a stub would only prove the gate rejects the
fixture someone imagined.  This produces it through the real merge path.
"""
import argparse
import importlib.util
import pathlib
import sys

SKILLS = pathlib.Path("skills/naraka-highlight-studio/scripts")


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tmp", required=True, help="scratch dir; gets state.json and out/")
    args = ap.parse_args()

    tmp = pathlib.Path(args.tmp)
    out_dir = tmp / "out"
    tmp.mkdir(parents=True, exist_ok=True)
    state_path = tmp / "state.json"

    st = load(SKILLS / "orchestrator_state.py", "st")
    mp = load(SKILLS / "merge_partial.py", "mp")

    doc = st._blank(tmp, 6)
    doc["source_path"] = "E:/OBS/demo.mp4"
    doc["source_duration"] = 1000.0
    for row in doc["lanes"]:
        if row["id"] in (1, 2, 3):
            row["status"] = "recycled"
            row["report_path"] = "reports/seg%d.md" % row["id"]
            row["episodes"] = [{"id": "e%02d" % row["id"], "source": "seg%d" % row["id"],
                                "source_start": row["id"] * 10.0,
                                "source_end": row["id"] * 10.0 + 8.0}]
        else:
            row["status"] = "in-flight"
            row["dispatched_at"] = 1.0
    doc["lanes_recycled"] = 3
    doc["phase"] = "scan"
    st.save(state_path, doc)

    res = mp.merge_available(state_path, out_dir, parent_version="v6")
    print("wrote %s" % ",".join(res["written"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
