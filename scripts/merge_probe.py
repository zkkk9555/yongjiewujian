"""Evaluate an expression against merge_partial.py -- the test's read-only probe.

This exists because inlining that evaluator into a bash heredoc failed three
separate ways in one session:

  * PowerShell parses `<<EOF` as a syntax error, not a heredoc, so the whole
    command never ran;
  * a *parameterised* heredoc (`<<PYEOF` with no quotes) expands `$2` at launch
    time, before the argument is bound;
  * with `2>/dev/null` on top, a broken probe prints nothing and every case
    compares empty strings -- which reads as "the module returned empty", not as
  "the probe never ran".

Each of those made a working module look broken.  A named file has none of them.

usage:  merge_probe.py <module.py> <expression>
        merge_probe.py <module.py> islands <csv>
"""
import importlib.util
import json
import sys

SAFE = {
    "m": None, "json": json, "str": str, "sorted": sorted, "len": len,
    "any": any, "all": all, "set": set, "list": list, "int": int, "float": float,
    "round": round, "sum": sum, "min": min, "max": max, "bool": bool,
}


def main() -> int:
    if len(sys.argv) < 3:
        sys.stderr.write("usage: merge_probe.py <module.py> <expr|islands <csv>>\n")
        return 2
    spec = importlib.util.spec_from_file_location("m", sys.argv[1])
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    SAFE["m"] = m

    if sys.argv[2] == "islands":
        lanes = [int(x) for x in sys.argv[3].split(",") if x.strip()]
        print(m.islands(lanes))
        return 0
    try:
        print(eval(sys.argv[2], dict(SAFE)))  # noqa: S307 - test probe, fixed input
    except Exception as exc:  # a broken probe must say so, never print nothing
        print("PROBE_ERROR:%s:%s" % (type(exc).__name__, exc))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
