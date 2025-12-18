# picogem cli

A gem downloader for PicoRuby. Easily download gems from GitHub repositories for use in your PicoRuby projects.

## Installation

Simply run the following command to install `picogem`:

```sh
curl -fsSL https://raw.githubusercontent.com/hayaokimura/picoruby-gem-installer/main/install.sh | sh
```

The install script automatically detects your platform (Linux/macOS) and downloads the appropriate binary.

### Supported Platforms

- Linux (x86_64)
- macOS (Intel / Apple Silicon)

### Install Location

- `/usr/local/bin` (if writable)
- `~/.local/bin` (otherwise)

If installed to `~/.local/bin`, add it to your PATH:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

### Add a gem

```sh
picogem add <gem-name> [options]
picogem add --repo <github-url> [options]
```

Download and compile a mrbgem from GitHub.

#### Modes

**1. Gem name mode (default)**

Downloads from the [picoruby/picoruby](https://github.com/picoruby/picoruby) repository.

- Branch: `master`
- Path: `mrbgems/<gem-name>/mrblib`

```sh
picogem add picoruby-aht25
```

**2. Repository mode (`--repo`)**

Downloads from a specified GitHub repository.

- Branch: `main`
- Path: `mrblib`

```sh
picogem add --repo https://github.com/ksbmyk/picoruby-ws2812
picogem add --repo ksbmyk/picoruby-ws2812
```

#### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-r, --repo URL` | GitHub repository URL or owner/repo | - |
| `-b, --branch BRANCH` | Branch name | `master` (gem name mode) / `main` (repo mode) |
| `-o, --output DIR` | Output directory for compiled .mrb files | `lib` |
| `-h, --help` | Show help | - |

### List available gems

```sh
picogem list
```

By default, lists gems in the `runtime_gems` directory of [picoruby/picoruby](https://github.com/picoruby/picoruby).

#### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-r, --repo OWNER/REPO` | GitHub repository | `picoruby/picoruby` |
| `-b, --branch BRANCH` | Branch name | `master` |
| `-d, --dir DIR` | Directory to list | `runtime_gems` |
| `-h, --help` | Show help | - |

### Sync files to storage

```sh
picogem sync <storage_directory>
```

Syncs local Ruby files to a PicoRuby device storage:

- Copies `*.rb` files from the current directory to `<storage>/home`
- Copies `*.rb` and `*.mrb` files from `lib/` to `<storage>/lib` (recursively)

#### Examples

```sh
# Sync to a mounted PicoRuby device (Linux)
picogem sync /mnt/pico

# Sync to Raspberry Pi Pico (Linux typical mount point)
picogem sync /media/user/RPI-RP2

# Sync to Raspberry Pi Pico (macOS)
picogem sync /Volumes/RPI-RP2

# Watch mode: auto-sync on file changes
picogem sync --watch /mnt/pico
```

#### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-w, --watch` | Watch for file changes and auto-sync | - |
| `-h, --help` | Show help | - |


#### Watch Mode

With the `--watch` option, picogem continuously monitors your source files and automatically syncs changes to the storage device:

- Detects new, modified, and deleted files
- Syncs changes automatically when detected
- Press `Ctrl+C` to stop watching

## Global Options

| Option | Description |
|--------|-------------|
| `-v, --version` | Show version |
| `-h, --help` | Show help |
| `--debug` | Show debug output |

## License

MIT License
