# macOS development

Use macOS for editing, training-code development, and the headless test suite.
Run the live StarCraft II process inside Windows for the most predictable
result.

## Recommended workflow: Windows VM

1. Create a Windows 10 or 11 virtual machine in Parallels, VMware Fusion, or
   another hypervisor.
2. Install StarCraft II, Python, Git, and `uv` inside the VM.
3. Clone this repository in Windows or expose a shared working directory.
4. Follow the [Windows setup](../windows/README.md) and run the agent inside the
   VM.

The older SSH helper under [`remote_vm/`](remote_vm) can run commands on a
Windows VM after you configure your own host alias. It does not provision the
VM or credentials. See [PARALLELS_SETUP.md](PARALLELS_SETUP.md) for the
repository's detailed VM notes.

## Headless development on macOS

The game is not needed for protocol and environment tests:

```bash
uv sync --locked --extra dev
make test
make lint
make type-check
```

These checks cover Python behavior only. They do not validate game discovery,
map loading, or live control.

## Experimental compatibility layers

The files named `sc2_crossover_launcher*.py` and `setup_maps.py` are retained as
experiments for CrossOver-style installations. Compatibility depends on the
local bottle, StarCraft II build, filesystem layout, and networking behavior.
They are not the supported live path.

If you experiment with this route, set `SC2_MACOS_WINE_EXE` and `SC2PATH`
explicitly instead of editing a machine-specific path into source control:

```bash
export SC2_MACOS_WINE_EXE="/path/to/StarCraft II.exe"
export SC2PATH="/path/to/StarCraft II"
make check-env
```

Keep the Windows VM available as the comparison environment when diagnosing a
compatibility-layer failure.
