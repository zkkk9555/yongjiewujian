"""Throwaway probe: parallel decode+signal throughput to size a zero-view pipeline wall-clock.

Splits the source into N contiguous chunks by time and runs the same single-thread signal
pass in a process pool. Reports aggregate frames/s so it can be multiplied by total frames.
"""
import argparse, time, os, tempfile
from concurrent.futures import ProcessPoolExecutor
import numpy as np


def work(job):
    path, start, dur, width = job
    import av, cv2
    cv2.setNumThreads(1)
    container = av.open(path)
    stream = container.streams.video[0]
    stream.thread_type = "NONE"
    src_w, src_h = stream.codec_context.width, stream.codec_context.height
    fps = float(stream.average_rate)
    h = int(width * src_h / src_w)
    container.seek(int(start * fps), stream=stream)
    n_target = int(dur * fps)
    prev_gray = prev_bgr = None
    n = 0
    acc = {"content": [], "fdiff": [], "flow": [], "flow_p95": [], "edge": []}
    for frame in container.decode(stream):
        img = frame.to_ndarray(format="bgr24")
        if img.shape[1] != width:
            img = cv2.resize(img, (width, h), interpolation=cv2.INTER_AREA)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        if prev_gray is not None:
            diff = cv2.absdiff(img, prev_bgr)
            acc["content"].append(diff.mean() * 3.0)
            acc["fdiff"].append(diff.mean())
            flow = cv2.calcOpticalFlowFarneback(prev_gray, gray, None, 0.5, 2, 9, 2, 5, 1.1, 0)
            mag = np.linalg.norm(flow, axis=2)
            acc["flow"].append(mag.mean())
            acc["flow_p95"].append(np.percentile(mag, 95))
            del flow, mag, diff
        small = cv2.resize(gray, (width // 4, h // 4), interpolation=cv2.INTER_AREA)
        acc["edge"].append(float((cv2.Canny(small, 60, 160) > 0).mean()))
        prev_gray, prev_bgr = gray, img
        n += 1
        if n >= n_target:
            break
    container.close()
    # only summary stats come back, not raw frames
    return n, {k: (float(np.mean(v)) if v else 0.0) for k, v in acc.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--seconds", type=float, default=180.0)
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--chunk", type=float, default=10.0)
    ap.add_argument("--width", type=int, default=480)
    args = ap.parse_args()

    import av
    c = av.open(args.video)
    st = c.streams.video[0]
    fps = float(st.average_rate)
    total_dur = float(st.duration * st.time_base) if st.duration else 0.0
    c.close()

    chunk = args.chunk
    jobs = []
    t = 0.0
    while t < args.seconds:
        jobs.append((args.video, t, min(chunk, args.seconds - t), args.width))
        t += chunk

    t0 = time.time()
    with ProcessPoolExecutor(max_workers=args.workers) as ex:
        results = list(ex.map(work, jobs))
    wall = time.time() - t0
    frames = sum(r[0] for r in results)
    print(f"workers={args.workers} chunks={len(jobs)}")
    print(f"frames={frames} wall={wall:.1f}s aggregate={frames/wall:.1f} frames/s")
    if fps:
        total_frames = total_dur * fps
        print(f"src_fps={fps:.2f} src_duration_s={total_dur:.1f} total_frames={total_frames:.0f}")
        print(f"EXTRAPOLATED full-video wall = {total_frames/(frames/wall)/60:.1f} min at this aggregate rate")


if __name__ == "__main__":
    main()