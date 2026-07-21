# V · Observation

🌐 [中文](../05-觀測.md)

## The statusline (two lines)

```
wander洞府 ~$123 · 靈力 76% · 1時20分後回復 · 鼎 Opus 4.8[1M] 34%
🌤 【築基期 二層 42%】 · 氣海 3.2M/59.8M · 靈石 2上40中
```

Line 1 is **now** — your cave and its Kindling, the 靈力 quota, and 鼎 (the model this conversation runs on and its context usage); line 2 is your **path** — 時辰, realm, 氣海, 靈石.

| Field | Meaning |
|-------|---------|
| 洞府 ~$X | Where you stand, and its lifetime Kindling (approximate) |
| 靈力 X% | 5-hour quota left; ⚠ / ✕ with recovery time when low |
| 鼎 M[size] % | The model this conversation runs on, its context window and the fraction used; the figure comes straight from Claude Code, hidden when unavailable |
| leading emoji | Leads line 2; rotates with the twelve 時辰 (子 🌙 → 亥 🌠) |
| 【realm · layer · %】 | Realm and in-layer progress, driven by Cultivation |
| 氣海 X/Y | Pool / cap — a **projection**; new Qi counted before it lands |
| ⚠ 寒月+X | What would scatter if settled now; refine or compress soon |
| 靈石 | Stones in the bag, compact notation (count + grade) |

First use shows 【未入門】 for a moment, then it lights up on its own — the record builds itself. The status bar redraws every five seconds, so it stays current even while idle.

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

**Q:** How far back do the annals reach? Do they last?
**A:** The source is Claude Code's transcripts (`.jsonl` under `~/.claude/projects/`). Claude Code deletes transcripts older than `cleanupPeriodDays` (default 30); but wander records each into its **permanent annals** *before* they are cleaned, so once ingested a session survives even after its transcript is gone — that is what the annals are for. The floor is the day you first ran wander; transcripts already deleted before then cannot be recovered. To keep more, set `cleanupPeriodDays` in `~/.claude/settings.json` (days, minimum 1; larger keeps transcripts longer), giving a deeper source if the annals are ever rebuilt — but transcripts accumulate on disk, so weigh it.

**Q:** Can I delete the cache?
**A:** Any time; it rebuilds. Only the permanent layer cannot be remade.

---

[← IV](04-realm.md) · [Contents](README.md) · [Appendix A · Commands →](06-commands.md)
