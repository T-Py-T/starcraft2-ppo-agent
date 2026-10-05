# StarCraft II PPO Agent

![Headless tests](https://github.com/T-Py-T/starcraft2-ppo-agent/actions/workflows/test.yml/badge.svg?branch=main)

**Train a Protoss policy against StarCraft II without putting the learner inside the game.**

[`Sc2Env`](src/sc2env.py) is a Gymnasium environment. Stable Baselines3 PPO talks to it with the usual `reset()` / `step()` calls. A separate Protoss bot, [`src/incredibot-sct.py`](src/incredibot-sct.py), plays the match through [BurnySC2](https://github.com/BurnySc2/python-sc2). The two processes exchange one request and one response through NumPy archives on disk.

That split is the product. You can read, change, and test the seam on a machine that does not have StarCraft II installed. A live match is a different, licensed install.

## No training result is published here

No win rate, episode return, training curve, or match outcome is claimed. This repository does not contain checkpoints, TensorBoard logs, replays, or a results file. `.gitignore` excludes `src/.runtime/`, `logs/`, and `wandb/`. The badge above means the headless protocol tests passed. It says nothing about playing strength.

There is no screenshot and no demo replay in the repository.

## Why try it

A commercial game client and an RL loop want different things. The game owns its process and its event loop. The learner wants a `step()` that returns a fixed-shape observation. Keeping them in one process makes every training bug a game bug.

Here the boundary is a file protocol with three properties you can test without launching the client:

- **Atomic writes.** Each message is saved to a temporary file in the destination directory, then renamed into place. A reader never sees a half-written archive. On Windows, where a rename can fail because the destination is briefly open, the replace retries with a short backoff.
- **Ids, not timing guesses.** Every message carries an episode id and a request id. The learner ignores a reply that does not match the request it is waiting on. The bot rejects a repeated or skipped request. Leftovers from the previous episode are not treated as a new observation.
- **No pickles.** State is a NumPy `.npz` loaded with `allow_pickle=False`. A bad state file cannot execute code in the learner.

Point `SC2_RUNTIME_DIR` at a different directory per process and several learners can share one machine without sharing a mailbox. The default directory is `src/.runtime/`.

## Contents

- [How a step moves](#how-a-step-moves)
- [What the agent sees and does](#what-the-agent-sees-and-does)
- [Worked example](#worked-example)
- [Demo without the game](#demo-without-the-game)
- [Getting started](#getting-started)
- [Playing a real match](#playing-a-real-match)
- [Contributing](#contributing)
- [License](#license)

## How a step moves

```text
Stable Baselines3 PPO
        │
        ▼
Sc2Env.step(action)
        │  writes request.npz
        ▼
SC2_RUNTIME_DIR
        │  request.npz   learner → bot
        │  response.npz  bot → learner
        ▼
incredibot-sct.py  →  StarCraft II
        │
        ▼
observation, reward, done
```

Each file has one writer. The protocol is [`src/ipc.py`](src/ipc.py). Episode lifecycle is [`src/sc2env.py`](src/sc2env.py).

## What the agent sees and does

**Observation.** The bot paints a top-down bitmap at map resolution: your units and structures, enemy units and structures, minerals, vespene, and enemy start locations. Health and remaining resources change the pixel color. That bitmap is resized to `224×224` before it is written, which is also `Sc2Env.observation_space`: `Box(0, 255, (224, 224, 3), uint8)`.

**Actions.** `Discrete(6)`, carried out in [`src/incredibot-sct.py`](src/incredibot-sct.py):

| Action | What the bot does |
| ---: | --- |
| 0 | If supply is tight, build a pylon. Otherwise train probes up to 22 near a nexus, build assimilators, or expand. |
| 1 | Build toward a Stargate: gateway, cybernetics core, then a stargate near each nexus. |
| 2 | Train a Void Ray at every idle ready stargate that you can afford. |
| 3 | Send a probe to the enemy start. Refused if the last scout was within 200 iterations. |
| 4 | Order idle Void Rays to a nearby enemy unit within 10, else a nearby structure, else any enemy unit, else any enemy structure, else the enemy start. |
| 5 | Send every Void Ray back to your start location. |

The bot also runs opportunistic builds on the same step (workers, the odd gateway or stargate). The action is not the only order issued.

**Reward shaping**, from the same file. These are the numbers in the code, not measured returns from a training run:

| Event | Reward |
| --- | ---: |
| Each new Stargate completed | +100 |
| Each new Void Ray | +80 |
| Attack command issued | +50 |
| Scout sent | +30 |
| Per Void Ray that is attacking and in range of an enemy within 8, per step | +0.015 |
| Still on the mining action after more than 300 iterations | −40 |
| Win / loss | +1000 / −1000 |

**Match setup.** Protoss versus the built-in Zerg computer on `Difficulty.Easy`, map `AbyssalReefLE`, both set in the `__main__` block of the bot. [`src/test_bot.py`](src/test_bot.py) expects `Simple64` instead. Change them in those files.

**Learner.** [`src/trainppo.py`](src/trainppo.py) builds `PPO("MlpPolicy", env)`, then runs 10 iterations of 10,000 timesteps and saves a checkpoint after each. Weights & Biases is initialized, but [`src/config.py`](src/config.py) forces `WANDB_MODE = "offline"`. TensorBoard logs go next to the checkpoints. None of those files are in the repository.

## Worked example

The protocol does not need the game. From the repository root, after the install in [Getting started](#getting-started):

```python
from src.ipc import REQUEST_PATH, empty_observation, load_state, save_state

save_state(
    {
        "state": empty_observation(),  # 224 x 224 x 3 uint8
        "reward": 0.0,
        "action": 4,                   # attack
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

```text
4 demo 1 (224, 224, 3)
```

Set `SC2_RUNTIME_DIR` to a scratch directory if you do not want the files under `src/.runtime/`. The write is a temp file plus a rename, so interrupting it does not leave a partial `request.npz` at the published path.

## Demo without the game

This is the demo. It does not start StarCraft II.

```bash
git clone https://github.com/T-Py-T/starcraft2-ppo-agent.git
cd starcraft2-ppo-agent
uv sync --locked --extra dev
make test
```

You need Python 3.11 or 3.12, [uv](https://docs.astral.sh/uv/), and git. On a minimal Linux image, OpenCV also needs `libgl1` (`sudo apt-get install -y libgl1`), which is what CI installs. On this macOS checkout, `uv sync --locked --extra dev --python 3.12` then `make test` reported:

```text
13 passed in 21.42s
```

Those 13 tests are what CI runs on Python 3.11 and 3.12: atomic publish and the Windows rename retry, rejection of object payloads, episode and request correlation, stale and out-of-order messages, the fixed observation shape, terminal-state handling, the ready handshake, timeouts, and child-process restart. They do not play a game.

Two more local checks:

```bash
make type-check   # mypy on src/ipc.py and src/sc2env.py
make lint         # ruff on src/, run/, and tests/
```

`make type-check` is clean on those two modules (`Success: no issues found in 2 source files` on this checkout).

`make lint` is **not** in CI, and it does **not** pass. On this checkout it exited 2 with 66 findings: 20 blind `except`s, 19 unsorted imports, 15 shebangs on non-executable files, 9 `subprocess.run` calls without `check`, plus a couple of smaller ruff rules. They sit mostly in older diagnostic and platform scripts. Do not treat a red `make lint` as a regression you introduced unless you touched those lines.

```bash
make check-env
```

Without a game installed, this warns that the StarCraft II executable was not found and then reports that the Python dependencies imported. That warning is the expected result on a development machine. It was the result on this macOS checkout.

## Getting started

The block above is the start. After `make test` is green, the protocol example is the next thing to touch. You do not need a GPU. On Linux the lockfile resolves `torch` to CPU wheels.

## Playing a real match

**Not run from this checkout.** A live game needs all of the following, and none of it is vendored:

- a licensed StarCraft II install and the Battle.net account that owns it;
- a real `.SC2Map` archive (`AbyssalReefLE` for the training bot, `Simple64` for `src/test_bot.py`). This repository does not generate maps. Renaming an unrelated zip does not make one;
- realistically, Windows. macOS is a Windows VM. Linux and WSL are experimental and were not exercised here.

### Windows, after you have a map

```powershell
uv sync --locked --extra dev
Set-Location run/windows
.\download_maps_simple.ps1
uv run create_simple_map.py
Set-Location ../..
uv run python src/test_bot.py
```

`download_maps_simple.ps1` creates directories. It does not download a map. Put a genuine `Simple64.SC2Map` in `Maps/`, or point `SC2_MAP_SOURCE` at one, before `create_simple_map.py`. The longer notes are in [`run/windows/README.md`](run/windows/README.md). If the install is not in a default location, set `SC2PATH` or edit the detection in [`src/config.py`](src/config.py).

### Train

```bash
make train        # src/trainppo.py
make test-bot     # a trivial bot, to see whether the client launches
make test-model   # load a checkpoint and step the live env
```

`make test-model` loads `models/1647915989/2880000.zip` from [`src/test_model.py`](src/test_model.py). That file is not in the repository. Point the constant at a checkpoint you trained.

`SAVE_REPLAY` is `True` in [`src/config.py`](src/config.py), so a live bot writes a PNG per step into `replays/` relative to the working directory. Create that directory first, or OpenCV fails the write quietly. Set `SAVE_REPLAY = False` if you do not want the frames. Training starts the child with `SC2_HEADLESS=1`, so the OpenCV preview stays closed. Run the bot script directly, without that variable, if you want the window.

| | Headless tests | Live game |
| --- | --- | --- |
| Windows | Supported | The path the scripts target |
| macOS | Supported | Only inside a Windows VM |
| Linux / WSL | Supported | Experimental |

Platform notes: [`run/windows/`](run/windows), [`run/macos/`](run/macos), [`run/linux/`](run/linux). CrossOver, Wine, and WSL bridges in this tree are experiments. They are not a claim that those runtimes match Windows.

## Project layout

```text
src/ipc.py              request/response protocol
src/sc2env.py           Gymnasium env and episode lifecycle
src/incredibot-sct.py   Protoss bot, observation, rewards
src/trainppo.py         PPO entry point
src/test_model.py       live eval of a checkpoint you supply
src/config.py           paths, SAVE_REPLAY, offline W&B
tests/                  headless protocol tests
run/                    Windows, macOS, and Linux setup
```

## Contributing

Issues and pull requests are welcome. Run `make test` and `make type-check` first. Both should be clean. Run `make lint` on the files you touch and expect the existing 66 findings until those scripts are cleaned up. Do not commit maps, checkpoints, or credentials.

See [CONTRIBUTING.md](CONTRIBUTING.md). Security reports go through [SECURITY.md](SECURITY.md), not a public issue.

## License

[MIT](LICENSE).

StarCraft II is a product of Blizzard Entertainment and is covered by its own terms. This project is not affiliated with or endorsed by Blizzard. BurnySC2, Stable Baselines3, Gymnasium, and the other dependencies stay under their own licenses.
