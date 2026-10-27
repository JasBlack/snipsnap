# SnipSnap

Browser tool: grab still frames and snip sections from any video, at native resolution / fps / quality. Everything runs locally — no uploads.

**Use it online: https://snap.jas.black** — or run it on your own machine:

## Run

Needs Node installed (nodejs.org) — nothing else.

- **Windows**: double-click `start.bat`
- **Mac**: open Terminal in this folder and run `sh start.command`
  (or `chmod +x start.command` once, then double-click it)
- **Anywhere**:

```
npx serve -l 8123 .
```

then open http://localhost:8123.

**Don't open index.html directly as a file** — frame grabs work, but snipping needs ffmpeg.wasm workers, which browsers block on `file://`.

## Use

- Drop any video anywhere on the page — always replaces the current one.
- FIRST / FRAME / LAST — instant still download at native resolution. Names: `videoname_frame_001.png`, incrementing.
- Right-click the timeline to drop in/out markers (or `I` / `O` keys), drag to adjust, then SNIP. Right-click a marker to delete its pair.
- **Multi-clip** (toggle in settings): mark as many in/out pairs as you like — SNIP exports every section as its own numbered file in one go.
- **SCENES**: finds every hard cut / camera change and turns each scene into a clip on the timeline (alternating purple/green). Then:
  - **Sensitivity** slider re-cuts instantly (no re-analysis).
  - Right-click the timeline or press `C` to add a cut (snaps to the nearest frame); right-click a cut to merge its two scenes; drag a cut to nudge both sides.
  - SNIP exports every scene as `videoname_scene_001.mp4`, `_002`, … in one pass. More than 5 clips (Chrome/Edge): you pick a folder once and they're written straight into it.
  - Speed: ~24× real time on 1080p mp4/mov (10 min analysed in ~25 s, memory stays flat). webm/mkv use ffmpeg's scene filter instead (slower).
  - Detects hard cuts; slow dissolves/fades between shots usually won't register — add those with `C`.
- Long jobs (scene analysis, multi-clip export) have a CANCEL button.
- Snip modes (settings at bottom):
  - **Frame-exact** (default) — starts and ends on the exact frames you marked; outputs mp4. Uses WebCodecs (hardware encode, `lib/` demuxer+muxer) for mp4/mov sources — ~1s for a 10s 720p snip, ~5s for 4K. Other containers, rotated phone footage, or older browsers fall back to the ffmpeg.wasm encoder automatically (multithreaded when served with the COOP/COEP headers in `serve.json`).
  - **Lossless copy** — same format, fps, quality; instant; cuts snap to keyframes so the start may shift slightly earlier.
  - **GIF** — native resolution, two-pass palette (memory stays flat for long clips).
- Keyboard: Space play, ←/→ frame step, Shift+←/→ 1s, I/O mark, C cut, S save frame, Home/End, Esc clear marks.

ffmpeg.wasm is vendored in `ffmpeg/` (~64 MB, single- and multi-threaded cores) so snipping works offline.

## Hosting

Live at **https://snap.jas.black** (GitHub Pages). It's a static site with no backend, so it works on any static host. Videos never leave the visitor's browser.

## License

MIT — see [LICENSE](LICENSE). Bundled third-party code (`lib/`, `ffmpeg/`, `coi-serviceworker.js`) keeps its own license.
