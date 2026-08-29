# StarCraft II PPO Agent

A Gymnasium environment and PPO training loop for a Protoss StarCraft II bot.
The learner and the BurnySC2 game process communicate through a small,
process-safe request/response protocol so training logic stays separate from
the live game client.

## Architecture

```text
Stable Baselines3 PPO
        │
        ▼
Gymnasium environment
        │ action request
        ▼
atomic request file + episode/request ID
        │
        ▼
BurnySC2 Protoss bot ──► StarCraft II
        │
        └──────── observation, reward, and terminal response
                         │
                         ▼
                atomic response file
```

The IPC layer uses separate single-writer request and response files. Each
message includes episode and request identifiers, allowing the learner to
reject stale state. `SC2_RUNTIME_DIR` can be set to isolate concurrent runs.

## Environment contract

- **Observation:** `224 × 224 × 3` visual state.
- **Actions:** expand/mine, build Stargate, build Void Ray, scout, attack, and
  retreat.
- **Policy:** PPO through Stable Baselines3.
- **Bot:** Protoss economy and production logic built with BurnySC2.
- **Tracking:** optional Weights & Biases and TensorBoard logging.

The game-side implementation lives in
[`src/incredibot-sct.py`](src/incredibot-sct.py). The Gymnasium adapter and
reward lifecycle are in [`src/sc2env.py`](src/sc2env.py), and the shared IPC
contract is in [`src/ipc.py`](src/ipc.py).

## Quick start

Prerequisites:

- Python 3.9–3.12;
- [uv](https://docs.astral.sh/uv/);
- a licensed StarCraft II installation for live runs; and
- compatible `.SC2Map` files.

```bash
git clone https://github.com/T-Py-T/starcraft2-ppo-agent.git
cd starcraft2-ppo-agent
uv sync --locked --extra dev

make setup-maps
make check-env
```

Platform-specific setup is under [`run/`](run):

- [`run/windows/`](run/windows) for a native Windows installation;
- [`run/linux/`](run/linux) for Linux map setup;
- [`run/macos/`](run/macos) for CrossOver or a remote Windows VM.

If the game is installed in a non-default location, set `SC2PATH` or update the
path handling in [`src/config.py`](src/config.py).

## Train and evaluate

Start PPO training:

```bash
make train
```

Run the game bot directly or evaluate a saved model:

```bash
make test-bot
make test-model
```

These commands launch the commercial game runtime and depend on local maps,
display settings, and model files. Model output, TensorBoard logs, and optional
Weights & Biases runs are stored outside the source modules.

## Headless validation

The protocol and environment can be tested without launching StarCraft II:

```bash
make test
make lint
make type-check
```

The tests cover atomic publication, request and episode correlation, stale
message rejection, the fixed observation shape, terminal-state precedence,
and the initial ready handshake.

## Repository layout

```text
src/
├── sc2env.py             # Gymnasium environment and reward lifecycle
├── ipc.py                # process-safe state exchange
├── incredibot-sct.py     # Protoss game agent
├── trainppo.py           # PPO training entry point
├── test_model.py         # live saved-model evaluation
└── config.py             # platform and runtime paths
tests/                    # headless protocol and environment tests
run/                      # Windows, Linux, and macOS setup
scripts/                  # remote-development helpers
```

## License

This project is available under the [MIT License](LICENSE). StarCraft II,
BurnySC2, Stable Baselines3, Gymnasium, and other dependencies remain under
their respective licenses and terms.
