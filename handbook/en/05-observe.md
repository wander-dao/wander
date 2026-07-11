# V · Observation

🌐 [中文](../05-觀測.md)

## The statusline

```
🌤 【築基期 二層 42%】 · 氣海 3.2M/59.8M · 靈石 2上40中 · 靈力 76% · 1時20分後回復 · wander洞府 ~$123
```

| Field | Meaning |
|-------|---------|
| leading emoji | Rotates with the twelve 時辰 (子 🌙 → 亥 🌠) |
| 【realm · layer · %】 | Realm and in-layer progress, driven by Cultivation |
| 氣海 X/Y | Pool / cap — a **projection**; new Qi counted before it lands |
| ⚠ 寒月+X | What would scatter if settled now; refine or compress soon |
| 靈石 | Stones in the bag, compact notation (count + grade) |
| 靈力 X% | 5-hour quota left; ⚠ / ✕ with recovery time when low |
| 洞府 ~$X | Where you stand, and its lifetime Kindling (approximate) |

First use shows 【未入門】 for a moment, then it lights up on its own — the record builds itself. The lit line appears on your next interaction (Claude Code redraws the status bar on activity, not while idle).

The statusline is a **pure cache reader — it never scans, never writes**. Any command keeps it fresh. Projection is idempotent; leave it on without a thought.

## Write semantics

| Command | Absorbs new Qi | Writes game state |
|---------|----------------|-------------------|
| cultivate / compress / decompress / bag | ✓ | ✓ |
| reset | full rescan | ✓ |
| `stats` (display) | ✓ | ✓ (catches up to the projection) |
| `stats --json` | ✗ | ✗ |
| statusline | projection only | ✗ |

## Three layers of data

| Path | Nature | If lost |
|------|--------|---------|
| `~/.local/share/wander/` | **Permanent**: the annals and game state | practice zeroed; irreplaceable |
| `~/.cache/wander/stats/` | Derived cache | harmless; rebuilds |
| `~/.config/wander/stats/config.json` | Your settings | preferences gone |

Back up one directory: `~/.local/share/wander/`. On Windows, `~` is `%USERPROFILE%`; the layout is identical.

## Privacy

One promise: **your data never leaves your machine.** No API calls, no uploads, no telemetry; reading and computing happen locally, and results land only in the three paths above.

**Q:** Kindling doesn't match my bill?
**A:** Kindling derives from tokens at list prices — an approximation. On subscription it shows equivalent API cost, not a charge. Custom prices: [Appendix A](06-commands.md).

**Q:** Multiple machines?
**A:** Each cultivates alone; no merging today.

**Q:** Can I delete the cache?
**A:** Any time; it rebuilds. Only the permanent layer cannot be remade.

---

[← IV](04-realm.md) · [Contents](README.md) · [Appendix A · Commands →](06-commands.md)
