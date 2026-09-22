# Project working rules

Keep written tests to a minimum. The primary evidence of correctness is a working system exercised in playable scenes with real game state and the actual gameplay components.

- Validate the affected flow in the game or an existing development scene; record the setup, actions and observed result in the packet handoff. Reuse scenes rather than creating a separate test scene for every feature.
- Add only the smallest useful written check for an important invariant, a regression, or an edge case that is difficult to verify through play. Simple validations are sufficient; there is no test-count or coverage target and no requirement to add a test for every change or packet.
- Do not build test frameworks, mock systems, fixture factories, test-discovery infrastructure or extensive suites. Reuse native Godot checks and the small validation script when needed.
- Preserve validation of ownership, payments, completion and save integrity. Passing written checks does not replace demonstrating that the system works in the game.

Apply this rule throughout the implementation plan. Named acceptance cases describe behavior to verify, not a requirement for a separate automated test. See [verification guidance](docs/plan/05-verification.md).
