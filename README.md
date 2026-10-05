# StarCraft II PPO Agent

![Headless tests](https://github.com/T-Py-T/starcraft2-ppo-agent/actions/workflows/test.yml/badge.svg?branch=main)

**A reinforcement learning environment for playing Protoss in StarCraft II, where the
learner and the game run as separate processes and talk through a protocol you can test
without owning the game.**

The repository contains three pieces that fit together:

- a **Gymnasium environment** (`Sc2Env`) that presents a live StarCraft II match as a
  standard `reset()` / `step()` loop for Stable Baselines3 PPO;
- a **Protoss bot** built on [BurnySC2](https://github.com/BurnySc2/python-sc2) that
  carries out the policy's decisions inside the game and reports back what happened; and
- a **process-safe file protocol** between the two, so the training code never has to
  live inside the game's event loop.

Because that protocol is the seam, most of the project can be read, changed, and tested
on a machine with no StarCraft II installed.

## No training results are published here

This repository ships the training environment, not a trained agent. **No win rates,
episode rewards, training curves, or match outcomes are published, because no run has
been retained here.** There are no checkpoints, no TensorBoard logs, and no results file
in the tree; `.gitignore` deliberately excludes `src/.runtime/`, `logs/`, and `wandb/`,
and a previously tracked run log was removed as a runtime artifact (see
[`docs/gitroll-triage.md`](docs/gitroll-triage.md)). The green badge above means the
headless protocol tests pass — it says nothing about how well the agent plays. If you
train one, the numbers are yours; none are claimed on your behalf.

There is also no screenshot or demo recording in this repository.

## Contents

- [Why it works this way](#why-it-works-this-way)
- [How it fits together](#how-it-fits-together)
- [What the agent sees and does](#what-the-agent-sees-and-does)
- [Getting started without StarCraft II](#getting-started-without-starcraft-ii)
- [Example: one protocol round trip](#example-one-protocol-round-trip)
- [Running against the real game](#running-against-the-real-game)
- [Platform support](#platform-support)
- [Project layout](#project-layout)
- [Contributing](#contributing)
- [License](#license)

## Why it works this way

A reinforcement learning loop and a commercial game client make awkward roommates. The
learner wants a `step()` that returns promptly and deterministically. The game wants to
own its own process, its own event loop, and its own platform. Run them together and the
training code inherits every constraint the game has.

So they are kept apart. `Sc2Env.reset()` launches the bot as a child process and hands it
a fresh episode id; each `step()` is then a single correlated request/response exchange
through two files on disk. Three properties make that safe rather than merely convenient:

- **Atomic publication.** Every message is written to a uniquely named temporary file in
  the destination directory and then renamed into place, so a reader never observes a
  half-written frame. On Windows, where a rename can fail because the destination is
  briefly open, the write retries with a short backoff.
- **Correlation, not guesswork.** Every message carries an episode id and a request id.
  The learner ignores any reply that does not match the request it is waiting on, and the
  bot rejects an action that repeats a consumed request or skips ahead of one. Leftover
  state from a previous episode is discarded instead of being mistaken for a fresh
  observation.
- **No executable payloads.** State is stored as NumPy `.npz` archives loaded with
  `allow_pickle=False`, so a malformed or hostile state file cannot execute code in the
  learner. (An earlier version of this project exchanged pickles.)

Two things follow. You can develop and test the entire agent boundary with no game
installed, which is what the CI job does. And you can run concurrent training processes
on one machine by pointing `SC2_RUNTIME_DIR` at a different directory for each.

## How it fits together

```text
  Stable Baselines3 PPO
            │
            ▼
  Sc2Env (Gymnasium)  ──── spawns ────►  incredibot-sct.py
            │                                    │
            │  writes request.npz                │  plays the match
            │  (action, episode id, request id)  │
            ▼                                    ▼
      ┌──────────────── SC2_RUNTIME_DIR ────────────────┐
      │   request.npz  (learner → bot, single writer)   │
      │   response.npz (bot → learner, single writer)   │
      └─────────────────────────────────────────────────┘
            ▲                                    │
            │  reads response.npz                ▼
            └──── observation, reward, done ──── StarCraft II
```

Each channel has exactly one writer, which is what keeps the exchange free of lost
updates. `SC2_RUNTIME_DIR` defaults to `src/.runtime/`.

The protocol itself is [`src/ipc.py`](src/ipc.py), the environment and episode lifecycle
are in [`src/sc2env.py`](src/sc2env.py), and the in-game Protoss logic is in
[`src/incredibot-sct.py`](src/incredibot-sct.py).

## What the agent sees and does

**Observation** — a `224 × 224 × 3` `uint8` image. The bot draws a top-down bitmap of the
match at map resolution: one colour per category (your units and structures, enemy units
and structures, mineral fields, vespene geysers, enemy start locations), with units shaded
by remaining health and resource patches shaded by what is left in them. That bitmap is
then resized to a fixed `224 × 224`, so the observation shape never depends on map size.

**Actions** — a `Discrete(6)` space:

| Action | Effect in game |
| ---: | --- |
| 0 | Expand or mine: build a pylon if supply-blocked, train probes, build assimilators, otherwise expand to a new nexus |
| 1 | Build toward a Stargate: gateway, then cybernetics core, then stargate near each nexus |
| 2 | Train a Void Ray at every idle ready stargate |
| 3 | Scout: send a probe to the enemy start location, rate-limited to once per 200 iterations |
| 4 | Attack: send idle Void Rays at the nearest enemy units, then structures, then the enemy base |
| 5 | Flee: recall all Void Rays to your start location |

**Rewards** — shaped toward building an air force and using it, defined in
[`src/incredibot-sct.py`](src/incredibot-sct.py):

| Event | Reward |
| --- | ---: |
| Each new Stargate completed | +100 |
| Each new Void Ray trained | +80 |
| Attack command issued | +50 |
| Scout sent | +30 |
| Per Void Ray actively engaging a nearby enemy, per step | +0.015 |
| Only mining for more than 300 iterations | −40 |
| Game won / lost | +1000 / −1000 |

**Opponent and map** — the bot plays Protoss against the game's built-in Zerg computer on
`Difficulty.Easy`, on `AbyssalReefLE`. Both are set directly in the `__main__` block of
[`src/incredibot-sct.py`](src/incredibot-sct.py); change them there.

**Policy** — [`src/trainppo.py`](src/trainppo.py) uses Stable Baselines3 `PPO` with an
`MlpPolicy`, running 10 iterations of 10,000 timesteps and saving a checkpoint after each
one. Weights & Biases is wired up but runs in offline mode by default
(`WANDB_MODE = "offline"` in [`src/config.py`](src/config.py)); TensorBoard logs are
written alongside the checkpoints.

## Getting started without StarCraft II

This path needs no game, no Battle.net account, and no GPU. It takes a couple of minutes.

**You need:** Python 3.11 or 3.12, [uv](https://docs.astral.sh/uv/), and git. On a minimal
Linux install, OpenCV also needs the system library `libgl1`
(`sudo apt-get install -y libgl1`).

```bash
git clone https://github.com/T-Py-T/starcraft2-ppo-agent.git
cd starcraft2-ppo-agent
uv sync --locked --extra dev
make test
```

`make test` runs the headless suite and should finish in a couple of seconds:

```text
13 passed
```

Those 13 tests are the real gate, and they are what CI runs on Python 3.11 and 3.12. They
cover atomic publication and the Windows rename retry, rejection of object payloads,
episode and request correlation, stale and out-of-order message rejection, the fixed
observation shape, terminal-state precedence over a pending request, the initial ready
handshake, response timeouts, and child-process restart and cleanup across episodes — all
without launching the game.

Two more checks are available:

```bash
make type-check   # mypy over src/ipc.py and src/sc2env.py; currently clean
make lint         # ruff over src/, run/, tests/
```

`make lint` is not part of the CI gate and does not currently pass: it reports findings —
broad `except` clauses, unsorted imports, shebangs on non-executable files, unchecked
`subprocess.run` calls — concentrated in the older platform helper and diagnostic scripts
under `src/` and `run/`. The protocol and environment modules themselves are essentially
clean. Expect a non-zero exit until those legacy scripts are tidied up.

To confirm your interpreter and dependencies resolved correctly, and to see whether a
StarCraft II installation was detected:

```bash
make check-env
```

Without the game installed this prints a warning about the missing executable and then
confirms the dependencies are available. That is the expected result for development-only
setups.

## Example: one protocol round trip

The protocol is usable on its own, which is the easiest way to see what the learner and
the bot actually exchange. No game required:

```python
from src.ipc import REQUEST_PATH, empty_observation, load_state, save_state

save_state(
    {
        "state": empty_observation(),   # 224 x 224 x 3 uint8
        "reward": 0.0,
        "action": 4,                    # 4 = attack
        "done": False,
        "episode_id": "demo",
        "request_id": 1,
        "ready": True,
    },
    REQUEST_PATH,
)

state = load_state(REQUEST_PATH)
print(state["action"], state["episode_id"], state["request_id"], state["state"].shape)
```

```console
$ SC2_RUNTIME_DIR=/tmp/sc2demo uv run python example.py
4 demo 1 (224, 224, 3)
```

Setting `SC2_RUNTIME_DIR` keeps the exchange in a scratch directory; leave it unset and
the files land in `src/.runtime/`. The write is atomic, so no partially written archive is
left behind even if you interrupt it.

## Running against the real game

Everything above runs anywhere. Playing actual matches does not.

**What a live run requires:**

- a **licensed StarCraft II installation** and the Battle.net account that owns it — this
  project does not ship, download, or circumvent the game;
- **genuine `.SC2Map` archives** for the scenario you run (`AbyssalReefLE` for the
  training bot, `Simple64` for `src/test_bot.py`). Maps are runtime inputs, not something
  this repository generates. Use a map from your own installation or one you are licensed
  to use, and keep the original archive intact — renaming an unrelated ZIP does not make
  it a valid map; and
- **Windows**, realistically. See [Platform support](#platform-support) below.

A **GPU is not required**. On Linux the lock file deliberately resolves `torch` to the
CPU-only wheels.

### Windows setup

From PowerShell, after cloning:

```powershell
uv sync --locked --extra dev
Set-Location run/windows
.\download_maps_simple.ps1
uv run create_simple_map.py
Set-Location ../..
uv run python src/test_bot.py
```

`download_maps_simple.ps1` only creates the expected directories — it does not obtain a
map. Place a genuine `Simple64.SC2Map` in the project `Maps` directory first, or point
`SC2_MAP_SOURCE` at an existing archive, before running `create_simple_map.py`. The full
[Windows guide](run/windows/README.md) covers execution policy, Xbox Game Pass
installations, and troubleshooting.

If the game lives somewhere unusual, set `SC2PATH` yourself or adjust the detection in
[`src/config.py`](src/config.py).

### Train and evaluate

```bash
make train        # PPO training: src/trainppo.py
make test-bot     # launch the game with a trivial worker-rush bot, to prove the install
make test-model   # replay a saved checkpoint
```

Two things worth knowing before you run these:

- `make test-model` loads a hardcoded checkpoint path (`models/1647915989/2880000.zip`) in
  [`src/test_model.py`](src/test_model.py). That file is not in this repository; edit the
  path to point at a checkpoint you trained.
- Live runs write a PNG of the observation every step, because `SAVE_REPLAY` is `True` in
  [`src/config.py`](src/config.py). The frames go to a `replays/` directory relative to
  your working directory; OpenCV fails silently if it does not exist, so create it first
  or set `SAVE_REPLAY = False`.
- During training the bot's live OpenCV preview window stays closed: the environment
  starts the child process with `SC2_HEADLESS=1`. Run
  [`src/incredibot-sct.py`](src/incredibot-sct.py) directly without that variable if you
  want to watch what the agent sees.

## Platform support

| | Headless tests, lint, type-check | Live game and PPO training |
| --- | --- | --- |
| **Windows** | Supported | Primary, supported path |
| **macOS** | Supported | Only inside a Windows VM |
| **Linux / WSL** | Supported | Experimental; depends on your local SC2 runtime |

Setup notes live under [`run/`](run): [`run/windows/`](run/windows) for the supported
native path, [`run/macos/`](run/macos) for headless development and the Windows VM
workflow, and [`run/linux/`](run/linux) for experimental Linux and WSL use.

No claim is made that CrossOver, Wine, WSL process bridging, or a native Linux install
behaves like the Windows runtime. Those are experiments, not the baseline.

## Project layout

```text
src/
├── ipc.py                # the request/response protocol
├── sc2env.py             # Gymnasium environment and episode lifecycle
├── incredibot-sct.py     # in-game Protoss bot, observation rendering, rewards
├── trainppo.py           # PPO training entry point
├── test_model.py         # evaluate a saved checkpoint against the live game
├── config.py             # platform detection, SC2 paths, runtime flags
└── …                     # older CrossOver and diagnostic helper scripts
tests/                    # headless protocol and environment tests
run/                      # Windows, macOS, and Linux setup guides and scripts
scripts/                  # remote-development helpers
```

## Contributing

Issues and pull requests are welcome. Run `make test` and `make type-check` before
opening one — both should be clean — and check `make lint` against the files you touched.
Keep maps, checkpoints, and credentials out of commits.
[CONTRIBUTING.md](CONTRIBUTING.md) has the details.

Found a security issue? Do not open a public issue — follow [SECURITY.md](SECURITY.md).

## License

Released under the [MIT License](LICENSE).

StarCraft II is a product of Blizzard Entertainment and is covered by its own license and
terms; this project is not affiliated with or endorsed by Blizzard. BurnySC2, Stable
Baselines3, Gymnasium, and the other dependencies remain under their respective licenses.
