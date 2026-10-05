"""Test helper for test_watchdog.sh: build a wave, then ask the watchdog.

Kept out of the shell on purpose.  The first version of that test inlined its
Python, which broke three ways at once:

  * `latencies * 60.0` on the string "5,4,6" -- a sequence times a float;
  * the argv offset was wrong by one, so the verdict was read from the wrong
    position and every case reported `below-50-floor`;
  * it called a helper `python_now` that never existed.

One helper with argparse cannot do all three silently.

usage:
  build_wave.py build  <state.py> <out.json> <recycled-latencies-csv> <stuck-count> <now>
  build_wave.py ask    <watchdog.py> <state.json> <now>
  build_wave.py cappend <state.py> <out.json> <recycled> <stuck> <at-cap-lane>
"""
import argparse
import importlib.util
import pathlib
import sys


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def build(args):
    """Build a wave where the whole thing has been running for `now` - dispatch.

    `--now` is the evaluation instant.  The wave started `--ago` minutes before
    it, so lanes recycled `--ago` minutes ago with latency L actually recycled at
    `(now - ago) + L`.  An earlier version set dispatched_at = now and
    recycled_at = now - L, which makes every span negative whenever L > ago --
    the watchdog then saw an empty population and reported "no evidence".
    """
    st = load(args.state_py, "st")
    lat = [float(x) for x in args.recycled.split(",") if x.strip()]
    stuck = int(args.stuck)
    total = len(lat) + stuck
    now = float(args.now)
    dispatched = now - float(args.ago) * 60.0
    doc = st._blank(pathlib.Path("/tmp"), total)
    doc["wave_started_at"] = dispatched
    for i in range(total):
        row = doc["lanes"][i]
        row["dispatched_at"] = dispatched
        if i < len(lat):
            row["recycled_at"] = dispatched + lat[i] * 60.0
            row["status"] = "recycled"
            row["recycle_round"] = 1
        else:
            row["recycled_at"] = None
            row["status"] = "in-flight"
            row["recycle_round"] = 0
    doc["lanes_recycled"] = len(lat)
    doc["lanes_dispatched"] = total
    doc["phase"] = "scan"
    st.save(pathlib.Path(args.out), doc)
    print("built %d lanes (%d recycled, %d stuck), dispatched %s min ago"
          % (total, len(lat), stuck, args.ago))


def ask(args):
    w = load(args.watchdog_py, "w")
    doc = w.load_state(pathlib.Path(args.state))
    res = w.evaluate(doc, now=float(args.now))
    if res["threshold_minutes"] is None:
        print("silent|%s" % res["silent_reason"])
        return
    fired = ";".join("%d:%s" % (f["lane"], f["reason"]) for f in res["fire"]) or "none"
    print("fired-at-%d|%s" % (res["threshold_minutes"], fired))


def cappend(args):
    """A wave where the stuck lane has already exhausted its attempt budget.

    Same clock discipline as build(): the wave started --ago minutes before
    now, and recycled lanes came back with a 10 min latency.  The earlier
    version set dispatched_at = now and recycled_at = now - 600, i.e. negative
    spans, and the cap subcommand did not even accept --ago, so the fixture this
    case depends on was never created.
    """
    st = load(args.state_py, "st")
    doc = st._blank(pathlib.Path("/tmp"), args.recycled + args.stuck)
    now = float(args.now)
    dispatched = now - float(args.ago) * 60.0
    doc["wave_started_at"] = dispatched
    for i in range(len(doc["lanes"])):
        row = doc["lanes"][i]
        row["dispatched_at"] = dispatched
        if i < args.recycled:
            row["recycled_at"] = dispatched + 10.0 * 60.0
            row["status"] = "recycled"
            row["recycle_round"] = 1
            row["attempt"] = 1
        else:
            row["recycled_at"] = None
            row["status"] = "in-flight"
            row["recycle_round"] = 0
            row["attempt"] = st.MAX_ATTEMPT if row["id"] == args.at_cap else 1
    doc["lanes_recycled"] = args.recycled
    doc["lanes_dispatched"] = len(doc["lanes"])
    doc["phase"] = "scan"
    st.save(pathlib.Path(args.out), doc)
    print("built %d lanes, lane %s at the attempt cap (%d), dispatched %s min ago"
          % (len(doc["lanes"]), args.at_cap, st.MAX_ATTEMPT, args.ago))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("build")
    p.add_argument("--state-py", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--recycled", default="")
    p.add_argument("--stuck", type=int, default=0)
    p.add_argument("--now", required=True, help="evaluation instant, epoch seconds")
    p.add_argument("--ago", default="600",
                   help="minutes since the wave was dispatched (must exceed the "
                        "largest --recycled latency, or spans come out negative)")
    p.set_defaults(fn=build)

    p = sub.add_parser("ask")
    p.add_argument("--watchdog-py", required=True)
    p.add_argument("--state", required=True)
    p.add_argument("--now", required=True)
    p.set_defaults(fn=ask)

    p = sub.add_parser("cap")
    p.add_argument("--state-py", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--recycled", type=int, default=8)
    p.add_argument("--stuck", type=int, default=1)
    p.add_argument("--at-cap", type=int, required=True)
    p.add_argument("--now", required=True)
    p.add_argument("--ago", default="600")
    p.set_defaults(fn=cappend)

    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
