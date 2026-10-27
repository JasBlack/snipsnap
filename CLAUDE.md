# SnipSnap

Browser-only video tool: drop in any video and grab still frames at native resolution, snip marked sections, or auto-split the whole video at every scene cut / camera change. Everything runs client-side (WebCodecs + ffmpeg.wasm) — videos are never uploaded, so it can be hosted as a plain static site.

## Tech stack

- **No framework, no build step, no package.json.** One file, `index.html` (~1640 lines: inline CSS + vanilla JS).
- **WebCodecs** (browser `VideoDecoder` / `VideoEncoder`): fast, usually hardware-accelerated path for mp4/mov — frame-exact snips and scene detection.
- **mp4box.js 0.5.2** (`lib/mp4box.all.min.js`) — streaming mp4 demuxer.
- **mp4-muxer 5.1.5** (`lib/mp4-muxer.min.js`) — writes the output mp4s.
- **ffmpeg.wasm** — `@ffmpeg/ffmpeg 0.12.10`, `@ffmpeg/util 0.12.1`, `@ffmpeg/core` + `@ffmpeg/core-mt 0.12.6` (`ffmpeg/`). Fallback for webm/mkv, rotated phone video, lossless copy and GIF.
- All third-party code is **vendored** (no CDN at runtime) so it works offline and deploys as-is.

## Folder structure

```
index.html          the whole app (UI, styles, logic)
lib/                mp4box.js + mp4-muxer (vendored, minified)
ffmpeg/             ffmpeg.wasm: single-threaded core, multithreaded core (-mt), loader + util (~64 MB)
serve.json          COOP/COEP headers for local `npx serve` (enables multithreaded ffmpeg)
vercel.json         same headers for Vercel hosting
start.bat           Windows launcher (npx serve on :8123 + opens browser)
start.command       macOS launcher (run with `sh start.command`; LF line endings required, enforced in .gitattributes)
coi-serviceworker.js coi-serviceworker 0.1.7 (MIT, vendored): adds COOP/COEP via a service worker where the host can't (GitHub Pages)
CNAME               custom domain for GitHub Pages
.nojekyll           serve files as-is on Pages (no Jekyll build)
.claude/launch.json Claude Code preview config (same serve command)
design/             UI exploration mockups (*.dc.html artboards + canvas.json); reference only, not used by the app
README.md           user-facing how-to
```

### Map of index.html (search for these names)

| Area | Functions |
|---|---|
| Load / metadata | `loadVideo`, `probeFps` (exact fps from mp4 `stts`), `estimateFps` (timing fallback), `fitVideo` |
| Playback / timeline | `togglePlay`, `stepFrames`, `scrubSeek`/`applyScrub` (seek-chaining), `updateTimecode` |
| Markers / ranges | `addMark`, `renderMarks`, `linkedEdges`, `splitAt`, `clearMarks` — `state.ranges` = `[{a,b}]` seconds |
| Frame grabs | `captureFrame` (canvas → png/jpeg/webp at native res) |
| Shared mp4 plumbing | `demuxMp4` (streaming, edit-list aware), `openDecoder`, `videoDecoderConfig`, `editListOffsetUs` |
| Snip export | `exportSnip` → `snipWebCodecsMulti` (one pass, all ranges) → fallback `snipWasmRange` |
| Scene detection | `detectScenes` → `analyzeScenesWebCodecs` / `analyzeScenesWasm` → `pickCuts` → `applyScenes` |
| ffmpeg | `getFFmpeg` (MT if cross-origin isolated), `getFFmpegST` (single-threaded, for GIF), `ffmpegInput` (WORKERFS mount) |
| Jobs | `startJob` / `endJob` / `checkJob`, `Cancelled` (CANCEL button) |

## Commands

There is nothing to install or build. Node is only needed for the static file server.

```bash
# run locally (serve.json sends the COOP/COEP headers)
npx -y serve -l 8123 .
# then open http://localhost:8123
```

Windows: `start.bat`. macOS: `sh start.command`.

**Must be served over http(s).** Opening `index.html` via `file://` breaks snipping (browsers block the ffmpeg workers there).

Build: none. Deploy the folder as-is.

## Deployment

- Target: GitHub Pages at **snap.jas.black** (DNS: `CNAME snap -> jasblack.github.io` wherever jas.black's nameservers point).
- **Vercel**: `npx vercel --prod` — `vercel.json` already sends COOP/COEP.
- **GitHub Pages**: Settings → Pages → deploy from branch `main`, folder `/`. Pages can't send custom headers, so `coi-serviceworker.js` (first script in `index.html`) adds COOP/COEP; the first visit reloads once to activate it. It does nothing when the server already sends the headers (Vercel, `serve.json`). Keep "Enforce HTTPS" on — WebCodecs and service workers need a secure context.
- Largest file is 32 MB (under GitHub's 100 MB limit).

## Environment variables

None. The app has no backend, API keys or config. `.env.example` exists only to state that.

## Status

**Works (verified in Chrome on Windows with generated test videos):**
- Drag-and-drop anywhere replaces the current video; FIRST / FRAME / LAST grabs (`<name>_frame_001.png`, incrementing).
- Frame-exact snips via WebCodecs (~1 s for 10 s of 720p, ~5 s for 4K); lossless copy; GIF (two-pass palette).
- Multi-clip: many in/out pairs exported in one go.
- Scene detection: 5/5 known cuts found to the exact frame; 10 min 1080p analysed in ~25 s with flat memory (<90 MB); webm via ffmpeg fallback. Exported clips verified frame-by-frame at boundaries.
- Exact fps readout from the container; 4K scrubbing; Tactile Deck UI (purple/green).

**Untested / unverified:**
- Safari and Firefox; anything on macOS.
- Folder-picker export (`showDirectoryPicker`, used when exporting >5 clips in Chrome/Edge) — automated tests can't click the OS dialog.
- Real camera footage (VFR phone video, HEVC, 10-bit) — tests used ffmpeg `lavfi` sources.

**Known limitations:**
- Scene detection finds hard cuts; slow dissolves/fades usually don't register (user adds them with `C`).
- Lossless copy snaps the start to the previous keyframe (by design; frame-exact is the default).
- Hardware path passes audio through only if it's AAC; other audio codecs are silently dropped on that path.
- Rotated (phone) video skips the hardware path and uses slower ffmpeg.wasm.
- Black bars in a video are encoded in the file, not added by the app. A crop tool was discussed, not built.

**Verified for Pages (headless Chromium, server without COOP/COEP):** service worker makes the page cross-origin isolated; webm scene detection + frame-exact export on the multithreaded ffmpeg core cut 3 scenes at the exact frames.

**Unfinished / ideas:** crop region for frames/snips; ML shot detection (e.g. TransNetV2) for dissolves.

## Decisions & gotchas

- **Frame-exact is non-negotiable** for this user. Every export/detection change must be verified at frame level (compare output first/last frames against the source at the boundary), not just by duration.
- **ffmpeg.wasm loading**: do NOT pass `classWorkerURL` (forces a module worker without `importScripts` → "failed to import ffmpeg-core.js"). The vendored dir was renamed `vendor/` → `ffmpeg/` because Chrome kept serving cached worker scripts without COEP headers.
- **ffmpeg.wasm thread caps**: always prepend `WASM_THREADS` (`-threads 4 -filter_threads 1`). ffmpeg defaults to one thread per core, which exhausts the MT core's fixed pthread pool and hangs (seen on a 32-core machine). `-threads` binds to the next input/output, so extra `-i` and outputs need their own cap.
- **GIF** runs on the single-threaded core (`getFFmpegST`): png/gif encoders wedge the MT worker after exit. Palette is two-pass because one-pass `split/palettegen` buffers every frame and OOMs wasm.
- **Edit lists**: mp4s from ffmpeg and many cameras have an `elst` offset; `demuxMp4` subtracts it so timestamps match the `<video>` element. Without it snips start ~2 frames off.
- **moov at end of file**: mp4box jumps ahead to find it; `demuxMp4` then rewinds to read samples. Memory stays flat either way.
- **Scene scoring**: frames → 64×36 on the GPU, 64 per tile-sheet readback (4× faster than per-frame `getImageData`, bit-identical). Score = 0.5 × RGB-histogram distance + 0.5 × luma pixel distance. `pickCuts`: score ≥ floor AND ≥ median of previous 8 frames + margin, min 0.4 s between cuts. Scores are cached per file so the sensitivity slider is instant.
- **Hardware encode** is H.264 High (`avc1.640034`); bitrate scales by resolution (6/10/16/34 Mbps, ×fps/30).
- **UI rendering**: the background gradient lives on a composited `body::before` layer — painting it on `body` re-dithered on every playhead repaint and visibly shimmered. Playhead moves via `transform`, not `left`.
- Settings persist in `localStorage` key `snipsnap-settings-v2`.
- **Testing approach**: generate ground-truth clips with local ffmpeg, e.g. `ffmpeg -f lavfi -i "testsrc2=duration=20:size=1280x720:rate=24" ...`, concatenate different sources for known cut points, load via `fetch` + `loadVideo(new File(...))` in the browser console, and stub `downloadBlob` to capture outputs.
