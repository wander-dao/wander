# II · Qi Sea & Cold Moon

🌐 [中文](../02-氣海.md)

## The vessel's limit

The Sea starts at 10M Qi. Each layer adds about a fifth; nine layers, five-fold. Higher realm, larger vessel.

Below the cap, new Qi sits quietly in the pool. Nothing happens on its own.

## The Cold Moon

autoMode triggers only when the pool is full. With it off, the overflow scatters to the Cold Moon — gone; the running total shows in the bag. Only a [reset](04-realm.md) recomputes from lifetime tokens and redeems it.

## autoMode

```bash
wander config set autoMode cultivate   # full → auto-refine into Cultivation
wander config set autoMode compress    # full → auto-compress into Stones
wander config set autoMode off         # default: overflow scatters
```

| Mode | On full | Cold Moon |
|------|---------|-----------|
| off | absorbs once; the rest scatters | yes |
| cultivate | refine-and-absorb until drained | never |
| compress | compress-and-absorb until drained | only the sub-stone remainder |

## Choosing

- Realm-bound, hands-free — cultivate.
- Banking stones for what comes — compress.
- Keeping the manual tension — off, and watch the statusline's ⚠ (see [V](05-observe.md)).

---

[← I](01-way.md) · [Contents](README.md) · [III · Spirit Stones →](03-stones.md)
