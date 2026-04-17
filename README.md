# screenshot-optimizer

**Auto-downscales macOS screenshots before you paste them into Claude (or any LLM).**

Fixes two things Opus 4.7 made worse today:

1. **The 2000px crash.** Paste a Retina screenshot (usually ~3400×2000) and Claude Code errors out. Every message after that is broken until you `/compact` and lose your context. Happened to me twice today.
2. **The token tax.** 4.7 roughly doubled token usage on vision inputs. A full-window Retina screenshot costs ~9,500 image tokens. Capped at 1568px, the same screenshot is ~1,950 tokens. **~79% savings with no visible quality loss** — and you can push it further if you want (see [Config](#config--pick-your-own-qualitysavings-tradeoff) below).

> macOS only. Uses `sips`, `launchctl`, `defaults` — all built-in. No dependencies.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sunglasses-dev/screenshot-optimizer/main/install.sh | bash
```

Takes 10 seconds. Asks one question (whether to move your screenshot save path to `~/Pictures/Screenshots/` — needed because macOS TCC silently blocks LaunchAgents from reading `~/Desktop/`).

## After install

Nothing changes in your workflow:

- `Cmd+Shift+5` → full-screen capture
- `Cmd+Shift+4` → region capture

Screenshot saves → daemon fires within ~2 seconds → file is downscaled in place if over 1800px → a marker is set so it's never re-processed.

Then you either paste it into Claude as usual, or just say:

> *"check the screenshot I just saved"*

and Claude reads it already-optimized from disk.

## How it works

- **LaunchAgent** with `WatchPaths` on your screenshot folder. Fires on every new file.
- **`sips -Z 1800`** — built-in macOS image tool. Proportional resize, aspect preserved, no upscaling.
- **xattr marker** (`com.screenshot-optimizer.resized`) — makes it idempotent. Runs once per file, ever.
- **~60 lines of bash.** Read it: [screenshot-optimizer.sh](screenshot-optimizer.sh).

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/sunglasses-dev/screenshot-optimizer/main/uninstall.sh | bash
```

Removes the LaunchAgent and script. Does not touch your screenshots or revert the save path — instructions printed if you want to.

## Log

```bash
tail -f ~/.screenshot-optimizer/optimizer.log
```

## Config — pick your own quality/savings tradeoff

The only thing worth tuning is `MAX_DIM` (longest side in pixels). Default is **1568** because that's the magic number where Claude stops multi-tiling your image. Go lower to save more tokens if you don't mind slight readability loss in dense UIs.

Claude's tokens formula: `tokens ≈ (width × height) / 750`

From a standard Retina screenshot (3456×2058, ~9,500 tokens uncompressed):

| `MAX_DIM` | Tokens after | Savings | Best for |
| --- | --- | --- | --- |
| `1568` (default) | ~1,950 | **79%** | everything |
| `1280` | ~1,300 | **86%** | most screenshots |
| `1024` | ~800 | **92%** | simple UIs, chats, charts |
| `768` | ~450 | **95%** | extreme — text in IDEs may degrade |

### Two ways to change it

**1. Edit the script** (easiest — installed at `~/.screenshot-optimizer/screenshot-optimizer.sh`):

```bash
# change MAX_DIM="${SCREENSHOT_OPTIMIZER_MAX_DIM:-1568}"
# to     MAX_DIM="${SCREENSHOT_OPTIMIZER_MAX_DIM:-1024}"
```

Then reload the daemon: `launchctl unload ~/Library/LaunchAgents/com.screenshot-optimizer.plist && launchctl load ~/Library/LaunchAgents/com.screenshot-optimizer.plist`

**2. Set the env var in the plist** (at `~/Library/LaunchAgents/com.screenshot-optimizer.plist`):

```xml
<key>EnvironmentVariables</key>
<dict>
    <key>SCREENSHOT_OPTIMIZER_MAX_DIM</key>
    <string>1024</string>
    ...
</dict>
```

Already-resized screenshots keep their old dimensions (they have an xattr marker). Only NEW screenshots use the new value. To re-resize all: `find ~/Pictures/Screenshots -name '*.png' -exec xattr -d com.screenshot-optimizer.resized {} \;`

## Why the name / who built this

Built in ~1 hour tonight after Opus 4.7 launched and crashed my Claude session twice with oversized screenshots. Ships as a free tool from [sunglasses.dev](https://sunglasses.dev) — we make AI agent security software. Same "one step ahead" pattern: intercept + transform before the model sees the input.

Built with Claude Code. Open to PRs.

---

MIT License.
