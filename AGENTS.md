# Project working rules

Use ponytail only for work related to writing tests. Do not apply ponytail to gameplay code, architecture, or other implementation decisions.

Keep written tests to a minimum. The primary evidence of correctness is a working system exercised in playable scenes with real game state and the actual gameplay components.

- Validate the affected flow in the game or an existing development scene; record the setup, actions and observed result in the packet handoff. Reuse scenes rather than creating a separate test scene for every feature.
- Add only the smallest useful written check for an important invariant, a regression, or an edge case that is difficult to verify through play. Simple validations are sufficient; there is no test-count or coverage target and no requirement to add a test for every change or packet.
- Do not build test frameworks, mock systems, fixture factories, test-discovery infrastructure or extensive suites. Reuse native Godot checks and the small validation script when needed.
- Preserve validation of ownership, payments, completion and save integrity. Passing written checks does not replace demonstrating that the system works in the game.

## Graphics preset when testing

- Run every test on the Low graphics preset by default to keep runs fast. This covers written checks, validation scripts, development scenes and play sessions. Add `-- --graphics=low` to any launch that opens a window; headless runs draw nothing, so the preset does not matter there.
- If the change affects how the game looks or renders, test it on High, the default players get. That includes materials, shaders, lighting, shadows, effects, models, textures, draw distance and level of detail. If the change touches a setting the presets vary (shadows, SSAO, glow, MSAA, render scale, detail view distance), also check Ultra and Low.
- Take performance measurements, screenshots and visual evidence on High unless a specific preset is under test, and name the preset in the handoff.
- `--graphics=<preset>` applies to that launch only and never changes the player's saved settings.

Apply these rules throughout the implementation plan. Named acceptance cases describe behavior to verify, not a requirement for a separate automated test. See [verification guidance](docs/plan/05-verification.md).
