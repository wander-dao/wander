# Appendix A · Commands

🌐 [中文](../06-指令.md)

## Practice

| Command | Does |
|---------|------|
| `wander bag` | The bag: Cultivation / Qi Sea / Stones / Cold Moon / spiritual root |
| `wander cultivate [qi]` | Refine (defaults to the whole pool) → Cultivation |
| `wander compress [qi]` | Compress (defaults to the whole pool) → Stones |
| `wander decompress <count>` | Absorb stones back into the pool |
| `wander reset [--to cultivation\|stones]` | Recompute lifetime (see [IV](04-realm.md)) |

## Observation

`wander stats` shows the panorama; one flag, one view:

| Flag | View |
|------|------|
| `--today` / `--week` / `--month` / `--all` | Today / this week / this month / all time |
| `--sessions` | The expedition board |
| `--tools` | The artifact ledger — built-in and 靈像 on one board |
| `--skills` | The arts collection, with acquisition dates — model-initiated loads only |
| `--peaks` | Lifetime bests, and the intake rate |
| `--streak` | The practice calendar |
| `--realm` | Realm details |
| `--projects` | Across caves |
| `--oracle` | Today's oracle — authentic classics only |
| `--essence` | 真元 (new compute) vs 藏氣 (re-reading the existing), per period and per cave |
| `--models` | Per-model usage and 薪火 (fable / opus / custom each on its own row, by 薪火; all-time by default) |
| `--share` | Share mode: caves, external artifacts and custom arts all get fictional cultivation names (丹霞, 漱石…) — no real paths or names, screenshot-safe. Stacks with any view |
| `--json` | Machine-readable, read-only |

Modifiers: `--refresh` forces a rescan; `--cwd <path>` picks the cave; `-g`/`--global` for all caves, `-f`/`--focus` for the current cave (apply to `--models`/`--tools`/`--skills`; `--models` is all-time by default, `--tools`/`--skills` focus by default).

> 真元 roughly equals the token total Claude Code's `/stats` shows; 靈氣 also counts 藏氣 (re-read context), so it runs tens of times larger — the two measure different things, not an error.

## Settings

| Command | Does |
|---------|------|
| `wander config list` | Show current settings |
| `wander config set project.<absolute-path>.alias "name"` | Cave alias |
| `wander config set tool.<name>.alias "name"` | Rename an artifact |
| `wander config set skill.<name>.alias "name"` | Rename an art |
| `wander config set mcp.<server>.alias "name"` | Rename a whole 靈像 |
| `wander config set autoMode <off\|cultivate\|compress>` | Pool-full law (see [II](02-qi-sea.md)) |
| `wander config prices` | Show effective Kindling prices: built-in families + your overrides |
| `wander config set price.<model> <in>/<out>[/<write>/<read>]` | Custom model pricing (USD / 1M tokens) |
| `wander config set price.default <in>/<out>` | Fallback for unknown models |
| `wander config set price.<model> <in>/<out> --from YYYY-MM-DD` | Dated segments, effective that day |
| `wander config get <key>` | Read one key |
| `wander config unset <key>` | Remove one setting (every key `set` supports; `price.<model> --from <date>` removes a single segment) |
| `wander config reset` | Restore defaults; the annals untouched |

Prices apply at once: Kindling recomputes at read time; history itself is never rewritten. Omitted cache prices derive at list ratios — write 1.25× input, read 0.1×.

## Completions

Shell completions (zsh / bash / fish):

```bash
source <(wander completions zsh)    # or persist it in ~/.zshrc
```

## Update

```bash
wander version               # version and platform (--version prints the number)
wander upgrade               # to the latest
wander upgrade v0.1.0        # pin a version
wander upgrade --check       # ask only; download nothing
```

Manual, never automatic, zero telemetry: it touches GitHub only when you run it, and sends nothing out. The download replaces nothing until **SHA256 verifies**; a mismatch aborts and the old binary stands.

`upgrade` only goes forward. To return to an older version, pin it through the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/wander-dao/wander/main/install.sh | bash -s -- --version v0.1.0
```

If the data was written by a newer wander, the older one asks before its first read; back up the permanent layer before going back.

## Uninstall

```bash
wander uninstall                 # interactive; keeps the annals and settings
wander uninstall --purge-config  # also clear settings
wander uninstall --purge-archive # also burn the annals (irreplaceable; asks twice)
wander uninstall --purge         # both
wander uninstall --clean-statusline  # also unwire settings.json
wander uninstall --dry-run       # show the plan first
```

By default **the annals and settings stay**; reinstall and continue. To start over without losing history, [reset](04-realm.md).

---

[← V](05-observe.md) · [Contents](README.md)
