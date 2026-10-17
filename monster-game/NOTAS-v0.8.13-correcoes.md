# Noite da Horda v0.8.13 — sem sprites novos

Source: v0.8.12. No new sprites or textures included.

- Disable reinforced/BLINDADO impostor vehicles until a distinctive sprite is approved. Preserve standard car=4, tank=12, other catalog requirements.
- Spawn newly captured civilians directly in the formation at grounded height with arrival bounce disabled.
- Do not snap flying characters to tall vehicle roofs; use bounded velocity and ground-based envelope instead.
- Soldier fires low, high, or short tracking shots using the existing bullet artwork, with colored aiming guides.
- Quake warning now lasts visibly through the 0.65 s countdown and shakes the existing collapsing terrain tiles.
- Slightly raise population budget and occasionally offer larger groups to large hordes.
- Add planned offscreen tunnel coin groups, civilian groups, and a rare existing normal car; reuse current tunnel texture with programmatic lantern lighting.
- Optimize existing vehicle proximity checks during regrouping and avoid allocating the tunnel sign StyleBox every frame.
- Add settings screen clipboard backup/restore with confirmation to ease Android save migration across separate test package IDs.
- A *new* signing key cannot silently update previously installed test builds signed with a different ephemeral key. Keep v0.8.12 installed; copy its save only if it already has backup support (it does not), or use a user-authorized Android backup/ADB procedure. No progress transfer guarantee.
- Rising/descent ground sprite, new armored car sprite and bespoke decorations remain postponed. Existing terrain artwork and collapse mechanics remain enabled.
