# Contributing

Guidelines for code and documentation pull requests. **Do not** use this page to report security vulnerabilities — follow [SECURITY.md](SECURITY.md) instead.

## Local checks

Use the [README](README.md) quick start, then run the headless gate before opening a PR:

```bash
uv sync --locked --extra dev
make test
make lint
make type-check
```

Live `make train`, `make test-bot`, and `make test-model` workflows need a licensed StarCraft II install and genuine maps; they are optional for most protocol and environment changes.

## Pull requests

- Target the `main` branch with a focused change and a short description.
- Keep API keys, Weights & Biases tokens, credentials, maps, checkpoints, and unredacted run exports out of commits (see [SECURITY.md](SECURITY.md)).

## License

Contributions are accepted under the same [MIT License](LICENSE) as the project. StarCraft II, BurnySC2, and other dependencies remain under their own licenses and terms.
