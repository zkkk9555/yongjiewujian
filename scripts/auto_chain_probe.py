"""Read-only probe for test_auto_chain.sh.

Same reason as merge_probe.py: an inline heredoc evaluator failed three ways in
one session (PowerShell parsed `<<EOF` as a syntax error; an unquoted heredoc
expanded `$2` before the argument bound; and under `2>/dev/null` a dead probe
printed nothing, so every case compared empty strings and a working module looked
broken).

A probe that fails must say so.

usage: auto_chain_probe.py <auto_chain.py> <command> [--state p] [--phrase s] [--at n]
"""
import importlib.util
import json
import sys


def load(path):
    spec = importlib.util.spec_from_file_location("a", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main() -> int:
    if len(sys.argv) < 3:
        sys.stderr.write("usage: auto_chain_probe.py <module> <command> [k v ...]\n")
        return 2
    a = load(sys.argv[1])
    cmd = sys.argv[2]
    opts = dict(zip(sys.argv[3::2], sys.argv[4::2]))

    state = None
    if "--state" in opts:
        from pathlib import Path
        state = a.load_state(Path(opts["--state"]))

    phrase = opts.get("--phrase")
    at = float(opts["--at"]) if "--at" in opts else None

    try:
        if cmd == "chain_state":
            print(state["authorization"]["chain_state"])
        elif cmd == "granted_at":
            v = state["authorization"]["granted_at"]
            print("None" if v is None else "%.1f" % v)
        elif cmd == "steps_run":
            print(len(state["authorization"].get("steps") or []))
        elif cmd == "step_names":
            print(",".join(a.STEPS))
        elif cmd == "master_dir":
            print(a.MASTER_DIR)
        elif cmd == "last_error":
            print(state["authorization"].get("chain_error"))
        elif cmd == "plan_output":
            print(a.plan_output(master_exists=opts.get("--master-exists") == "yes"))
        elif cmd == "verdict":
            print(a.verdict(state, phrase))
        elif cmd == "run_step":
            print(a.can_run(state, opts["--step"]))
        elif cmd == "grant":
            a.grant(state, phrase, at)
            # grant() mutates in place, so the print must read the mutated dict.
            # An earlier version returned the dict from grant() but then printed
            # `state`'s pre-call snapshot, which made a working grant look
            # un-granted in every case.
            print("granted" if state["authorization"]["granted"] else "refused")
        elif cmd == "run_result":
            a.run_step(state, opts["--step"], opts.get("--result", "ok"),
                       opts.get("--detail"))
            save = a.save_state
            save(state["__path__"], state) if "__path__" in state else None
            print("ran")
        elif cmd == "init":
            from pathlib import Path
            import time
            doc = a._blank(Path(opts["--state"]).parent, 0)
            a.save_state(Path(opts["--state"]), doc)
            print("init")
        else:
            print("PROBE_ERROR:unknown command %r" % cmd)
            return 1
    except Exception as exc:
        print("PROBE_ERROR:%s:%s" % (type(exc).__name__, exc))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
