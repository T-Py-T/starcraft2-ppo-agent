# Linux and WSL development

Linux and WSL are useful for editing the agent and running the headless test
suite. Live StarCraft II integration is experimental because it depends on how
the game is installed and whether the Python process can reach that runtime.

## Headless development

```bash
uv sync --locked --extra dev
make test
make lint
make type-check
```

These commands do not launch StarCraft II.

## Experimental map setup

[`download_maps.py`](download_maps.py) searches paths already known to
`python-sc2` and copies genuine `.SC2Map` archives into the configured runtime
and project `Maps` directories. Despite its historical name, it does not
download files from the internet.

```bash
python3 run/linux/download_maps.py
```

If no map is found, provide one from your licensed StarCraft II installation.
See the main [Game maps](../../README.md#game-maps) section.

For a live run, set `SC2PATH` to the installation that the Linux or WSL Python
process can actually access, then use `make check-env` before starting the bot.
The native Windows workflow remains the baseline when this path fails.
