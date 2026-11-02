# Amiga port intake: Freeciv

- Port Atlas: [g-freeciv](https://www.amicradle.com/ports/#g-freeciv)
- Priority: `P2`
- Atlas decision: `evaluate`
- Upstream source: `https://github.com/freeciv/freeciv`
- Atlas source pin: `Unverified`
- Imported commit: `900908ae2c3b7ce69352edb4188036f9d576960f` (tree verified against upstream on 2 November 2026: identical apart from `.github/` and this file)
- Rights state: `review`

## Target contract

Primary target: AmigaOS 3.x / AmiCradle AC090 / Motorola 68040 + FPU.

Use the OPEN platform libraries where applicable: OpenGPU, OpenAudio/OpenAHI, OpenInput, OpenSocket and measured OpenMulticore work. Preserve a correct 68040 fallback and do not assume Roadshow.

The port lives in [`platforms/amigaos3/`](platforms/amigaos3/README.md): its feasibility note and build plan ([FEASIBILITY.md](platforms/amigaos3/FEASIBILITY.md)), build scripts and the Amiga patches, applied at build time so the upstream files stay as imported. Freeciv's own data (rulesets, tilesets, themes) is part of the source and GPL; there is no external game data.

No build, runtime, playability or release claim is made here; the port README's "Observed" section records what each step has shown.

## Rights and data boundary

review; Confirm source/data licences before release.
