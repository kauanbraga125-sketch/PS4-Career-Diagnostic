# Noite da Horda v0.8.12 — corrections without new sprites

Based on the fully imported v0.8.11 Android source. No art or audio files changed.

- Extend plane/truck walking support to the rear and tolerate minor landing jitter.
- Keep the horizontal roof solid briefly after a vehicle flips, without changing the rotating visual effect.
- Only cull a zombie after its full sprite is behind the actual camera boundary.
- Slightly spread the horde; preserve individual positions while airborne and pause 0.5 s after landing before smooth regroup.
- Do not let automatic regrouping drag a grounded zombie through an active vehicle or a gap.
- Increase per-tunnel speed gains by 20% relative to the earlier increments; starting speed unchanged.
- Give the Masked form ×2 base pushing force per actual member, show effective force separately in the HUD, and shorten the masked jump.
- Add subtle camera tremors to the existing collapsing ground warning, without new art or tutorial text.
- Run the old truck/plane survival tests plus new gameplay regressions in CI.

Do not replace or remove the existing collapsing-ground obstacle. Rising-ground sprites are explicitly postponed.
