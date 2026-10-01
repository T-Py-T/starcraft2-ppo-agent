# Hireability and discoverability

Skim-friendly index for search, profiles, and contributors. Runtime behavior is unchanged.

## What / why / how

| | |
| --- | --- |
| **What** | Gymnasium environment and Stable Baselines3 PPO training loop for a Protoss StarCraft II bot, with file-based IPC between the learner and a BurnySC2 game process. |
| **Why** | Keeps reinforcement-learning logic separate from the live game client so the protocol and environment can be developed and tested headlessly; Windows remains the primary live-training path. |
| **How** | `uv sync --locked --extra dev`, then `make test` / `make lint` for the headless gate; `make train` and the platform guides under [`run/`](../run/) for live runs with a licensed StarCraft II install and genuine maps. |

## Suggested GitHub topics

Maintainers may add repository topics such as: `starcraft2`, `reinforcement-learning`, `ppo`, `gymnasium`, `stable-baselines3`, `burnysc2`, `python`, `machine-learning`, `game-ai`, `protoss`.

## Related documentation

- [README](../README.md) — architecture, quick start, and supported workflows
- [LICENSE](../LICENSE) — MIT; StarCraft II, BurnySC2, and other dependencies keep their own licenses and terms
- [SECURITY.md](../SECURITY.md) — vulnerability reporting and safe evidence handling
- [docs/gitroll-triage.md](gitroll-triage.md) — static finding disposition at a pinned revision
- Platform setup: [`run/windows/`](../run/windows/), [`run/linux/`](../run/linux/), [`run/macos/`](../run/macos/)

There is no separate `CONTRIBUTING.md`; use the README quick start, `make test` / `make lint`, and open a pull request for code changes. Report security issues only through [SECURITY.md](../SECURITY.md).

## Revision cite (`tip≠READY`)

Docs describe the tree at a cited commit prefix. **Tip citation is not READY**: it does not mean production readiness, benchmark scores, bake-off claims, or unparked authentication flows.

| Ref | Meaning |
| --- | --- |
| `86ce0fd` | `main` tip prefix when this page was added |
| This PR | Pending Steward resolve; refresh the tip row after merge when `main` advances |

Revert by deleting this file and removing the README pointer.
