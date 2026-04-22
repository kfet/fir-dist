# fir-dist

Public binary distribution for [**fir**](https://github.com/kfet/fir) — a
terminal-native coding agent.

This repository hosts **binaries only**. The source lives at
[kfet/fir](https://github.com/kfet/fir).

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/kfet/fir-dist/main/install.sh | sh
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
