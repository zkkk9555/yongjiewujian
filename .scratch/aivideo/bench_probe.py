"""Throwaway probe: measure zero-view machine signals available with the CURRENT toolchain.

Signals per decoded frame (all at reduced resolution, no model download):
  - content_val : HSL-based content change (same metric PySceneDetect uses)
  - fdiff       : mean abs pixel diff vs previous frame (motion proxy)
  - flow        : mean Farneback optical flow magnitude (motion intensity)
  - edge        : Canny edge density (scene texture complexity)

Usage: python bench_probe.py <mp4> <seconds>
Writes CSV to stdout path given by --out.
"""
import sys, time, csv, argparse
import numpy as np
import av


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--seconds", type=float, default=120.0)
    ap.add_argument("--out", required=True)
    ap.add_argument("--width", type=int, default=480)
    args = ap.parse_args()

    import cv2
    cv2.setNumThreads(0)  # avoid oversubscription; measure honestly single-stream

    rows = []
    t0 = time.time()
    container = av.open(args.video)
    stream = container.streams.video[0]
    stream.thread_type = "AUTO"
    src_w, src_h = stream.codec_context.width, stream.codec_context.height
    fps = float(stream.average_rate)
    n_target = int(args.seconds * fps)
    h = int(args.width * src_h / src_w)

    prev_gray = None
    prev_bgr = None
    i = 0
    decode_t = 0.0
    for frame in container.decode(stream):
        dt = time.time()
        img = frame.to_ndarray(format="bgr24")
        if img.shape[1] != args.width:
            img = cv2.resize(img, (args.width, h), interpolation=cv2.INTER_AREA)
        decode_t += time.time() - dt

        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        small = cv2.resize(gray, (args.width // 4, h // 4), interpolation=cv2.INTER_AREA)

        rec = {"frame": i, "t": round(i / fps, 3)}

        if prev_gray is not None:
            diff = cv2.absdiff(img, prev_bgr)
            rec["fdiff"] = round(float(diff.mean()), 4)
            # coarse content-change proxy on the same footing as PySceneDetect content_val
            rec["content_val"] = round(float(diff.mean() * 3.0), 3)
            flow = cv2.calcOpticalFlowFarneback(
                prev_gray, gray, None,
                pyr_scale=0.5, levels=2, winsize=9, iterations=2,
                poly_n=5, poly_sigma=1.1, flags=0,
            )
            mag = np.linalg.norm(flow, axis=2)
            rec["flow"] = round(float(mag.mean()), 4)
            rec["flow_p95"] = round(float(np.percentile(mag, 95)), 4)
            del flow, mag, diff

        edges = cv2.Canny(small, 60, 160)
        rec["edge"] = round(float((edges > 0).mean()), 5)

        rows.append(rec)
        prev_gray, prev_bgr = gray, img
        i += 1
        if i >= n_target:
            break
    container.close()

    wall = time.time() - t0
    fields = ["frame", "t", "content_val", "fdiff", "flow", "flow_p95", "edge"]
    with open(args.out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fields})

    print(f"video={args.video}")
    print(f"src={src_w}x{src_h} fps={fps:.3f}")
    print(f"frames={i} wall={wall:.1f}s speed={i/wall:.1f} fps_probe (decode+5 signals, no GPU)")
    print(f"decode+resize time={decode_t:.1f}s of wall")
    print(f"signal time={wall-decode_t:.1f}s")
    print(f"out={args.out}")


if __name__ == "__main__":
    main()