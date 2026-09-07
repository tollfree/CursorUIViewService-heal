# Security Policy

## Scope

This project is a small shell-based LaunchAgent that periodically checks
one system process (`CursorUIViewService`) and force-kills it if it looks
hung. It has a narrow, easy-to-audit scope:

- Runs entirely as the logged-in user (no root, no `sudo`, no privilege
  escalation).
- Makes no network connections.
- Reads process state via `ps`, `pgrep`, and `/usr/bin/sample`.
- Only ever signals one specific process, matched by its full binary
  path (`.../XPCServices/CursorUIViewService.xpc/Contents/MacOS/CursorUIViewService`),
  and only ever sends it `SIGKILL`.
- Writes only to `/tmp/cursoruiviewservice-watchdog.*` and to its own
  install directory.

Every file is plain, readable shell/plist — there is no compiled binary,
no downloaded dependency, and no obfuscation. You're encouraged to read
`cursoruiviewservice-watchdog.sh` in full before installing; it's under
100 lines.

## Supported Versions

This targets current macOS releases where `CursorUIViewService` exists
(Sonoma and later). It has been verified on macOS 26 (Tahoe). There are
no formal LTS/version guarantees — it's a small personal-use utility,
not a maintained product.

## Reporting a Vulnerability

If you find a security issue (for example, a way the install/uninstall
scripts could be tricked into touching files outside the intended
directories, or a flaw in how the LaunchAgent is registered):

1. Please open a GitHub issue marked `security`, or contact the
   maintainer directly if the repo has a listed contact — avoid posting
   exploit details in a public issue if the impact is more than
   theoretical.
2. Include the macOS version, the exact command you ran, and what you
   expected vs. what happened.
3. There's no bug bounty; this is a hobby-scale tool. Reports are still
   very welcome and will be fixed as soon as practical.

## Known Risk Considerations

- **`kill -9` on a system process**: this is the intended behavior
  (force-quitting an unresponsive Apple XPC service, which launchd
  automatically respawns). It only targets the exact binary path above
  — review the `SERVICE_MATCH` variable if you fork this for a
  different process.
- **`/usr/bin/sample`**: the deadlock check spawns Apple's own `sample`
  tool against the target process for 1 second per check. `sample` is
  a standard macOS diagnostic tool; no external or third-party binary
  is invoked.
- **LaunchAgent persistence**: `install.sh` registers a LaunchAgent
  under your own user domain (`gui/$(id -u)`), not system-wide. It
  runs on a 5-minute interval and at login. `uninstall.sh` fully
  removes it.
- **Do not install to iCloud Drive**: `install.sh` blocks this on
  purpose — launchd cannot execute files inside
  `~/Library/Mobile Documents/...`, and it's not a security boundary
  worth working around.
