# CursorUIViewService watchdog

Fixes the long-standing macOS bug where `CursorUIViewService` (the process
behind the text-insertion cursor, Caps Lock indicator, and input-language
popup) goes "Not Responding" in Activity Monitor and causes typing lag
across the whole system. First appeared in Sonoma, still present in
current macOS. No official fix from Apple yet — see:

- https://developer.apple.com/forums/thread/759802
- https://www.reddit.com/r/MacOS/comments/1clmu8y/one_of_the_hidden_reasons_causing_lag_on_macs/

## What this does

Runs a check every 5 minutes via a LaunchAgent. If the process is hung,
it force-kills it — launchd respawns it fresh immediately, memory and
all, with no reboot needed. Three detection layers, checked in order:

1. **Confirmed deadlock** (primary): takes a 1-second thread sample of
   the process. If the main thread is stuck in `-[HIRunLoopSemaphore
   wait]` (a real deadlock signature verified live — 100% of samples
   stuck in that exact frame while Activity Monitor showed "Not
   Responding"), it kills immediately regardless of CPU or age.
2. **Busy-spin fallback**: sustained high CPU for 3 consecutive checks.
3. **Stuck-idle fallback**: alive longer than 6 hours (tune or disable
   in the script if it's too aggressive).

## Install

```
./install.sh              # installs to ~/scripts
./install.sh ~/some/dir   # or a custom folder
```

Don't install into iCloud Drive (`~/Library/Mobile Documents/...`) —
launchd can't execute files there (macOS blocks background processes
from that container). The installer refuses that path automatically.

## Uninstall

```
./uninstall.sh              # if installed to the default ~/scripts
./uninstall.sh ~/some/dir   # match whatever you passed to install.sh
```

## Requirements

- macOS with `/usr/bin/sample` available (ships with Xcode Command Line
  Tools — install with `xcode-select --install` if missing). Without it,
  the deadlock check is skipped and only the CPU/age fallbacks run.

## Tuning

Edit the installed `cursoruiviewservice-watchdog.sh` directly:
- `DEADLOCK_RATIO` — % of samples that must show the stuck frame (default 50)
- `CPU_THRESHOLD` / `CPU_SUSTAIN_CHECKS` — busy-spin fallback
- `MAX_AGE_SECONDS` — idle fallback (default 6h, `0` disables it)

## Check it's working

```
launchctl print gui/$(id -u)/com.github.tollfree.cursoruiviewservice-watchdog
tail -f /tmp/cursoruiviewservice-watchdog.log
```
