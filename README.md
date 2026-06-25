# fir-dist

Public binary distribution for [**fir**](https://github.com/kfet/fir) — a
terminal-native coding agent.

This repository hosts **binaries only**. The source lives at
[kfet/fir](https://github.com/kfet/fir).

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/kfet/fir-dist/main/install.sh | sh
```

This installs the latest release. To pin or roll back to a specific
version, see below.

## Installing a specific / previous version

### Via `install.sh` (`VERSION`)

Pass the desired version in the `VERSION` environment variable. It must
be set on the **`sh`** that runs the script, not on `curl` — so put it
after the pipe:

```sh
curl -fsSL https://raw.githubusercontent.com/kfet/fir-dist/main/install.sh | VERSION=0.73.1 sh
```

`VERSION` accepts a full release tag with or without the leading `v`
(`0.73.1`, `v0.73.1`). Use any tag from the
[releases list](https://github.com/kfet/fir-dist/releases). The script
also honours `INSTALL_DIR` to choose the destination (default
`/usr/local/bin`, falling back to `~/.local/bin`):

```sh
curl -fsSL https://raw.githubusercontent.com/kfet/fir-dist/main/install.sh \
  | VERSION=0.73.1 INSTALL_DIR="$HOME/.local/bin" sh
```

> Note: `VERSION=0.73.1 curl … | sh` does **not** work — the variable
> goes to `curl`'s environment, not the piped `sh`, and the script
> silently installs latest. Always put `VERSION=…` after the `|`.

### Via Homebrew (`fir@MAJOR.MINOR`)

The tap publishes a pinned formula per minor channel (the 10 most recent
minors are kept). Each tracks the latest patch within that minor:

```sh
brew unlink fir 2>/dev/null
brew install kfet/ai/fir@0.73   # or: brew link --overwrite fir@0.73
```

Return to the rolling latest with:

```sh
brew unlink fir@0.73 && brew install kfet/ai/fir
```

## Releases

Every release ships the following assets:

| Asset | Description |
|---|---|
| `fir-darwin-arm64` | macOS Apple Silicon |
| `fir-darwin-amd64` | macOS Intel |
| `fir-linux-amd64`  | Linux x86_64 |
| `fir-linux-arm64`  | Linux ARMv8 (Raspberry Pi 3/4/5, Zero 2 W) |
| `fir-linux-armv6`  | Linux ARMv6 (Raspberry Pi Zero/1) |
| `LICENSE`          | MIT license for fir itself |
| `THIRD_PARTY_NOTICES.md` | Attribution for all third-party Go modules |
| `checksums.txt`    | SHA-256 checksums covering every asset above |

See the [latest release](https://github.com/kfet/fir-dist/releases/latest)
for the current version.

## Verifying a download

```sh
sha256sum -c checksums.txt --ignore-missing
```

## License

`fir` itself is distributed under the [MIT License](https://github.com/kfet/fir/blob/main/LICENSE).
Third-party attribution is in `THIRD_PARTY_NOTICES.md` inside each release.
