# libghostty-android

[![Stable](https://github.com/ancientcatz/libghostty-android/actions/workflows/stable.yml/badge.svg)](https://github.com/ancientcatz/libghostty-android/actions/workflows/stable.yml) [![Nightly](https://github.com/ancientcatz/libghostty-android/actions/workflows/nightly.yml/badge.svg)](https://github.com/ancientcatz/libghostty-android/actions/workflows/nightly.yml) [![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Builds the Ghostty virtual terminal library (`libghostty-vt.so`) for Android.

Supported ABIs:

- `arm64-v8a`
- `armeabi-v7a`
- `x86_64`

## Usage

Download the library for your ABI from the [releases page](https://github.com/ancientcatz/libghostty-android/releases).

```c
void *handle = dlopen("libghostty-vt.so", RTLD_NOW);
void *terminal =
    ((void *(*)(void))dlsym(handle, "ghostty_terminal_new"))();
```

The Ghostty C API is defined in the `include/ghostty/*.h` headers.

## Manual builds

The stable and nightly workflows can be started manually from GitHub Actions.

Both workflows accept `ghostty_ref` and `force` inputs. The nightly workflow uses `main` by default.

## Local build

Requires Zig 0.16.0 and Android NDK r30.

```bash
zig build -Demit-lib-vt \
  -Dtarget=aarch64-linux-android.24 \
  -Doptimize=ReleaseFast \
  -Dcpu=baseline \
  -Dstrip=true \
  --prefix out/arm64-v8a
```

The repository also provides build, test, and packaging scripts:

```bash
./scripts/build.sh arm64-v8a
./scripts/smoke_test.sh arm64-v8a
./scripts/package.sh arm64-v8a "<ghostty-commit>"
```

## Build configuration

| Setting | Value |
|---------|-------|
| Android API level | 24 |
| Android NDK | r30 |
| Zig | 0.16.0 |
| Optimization | `ReleaseFast` |
| ABIs | `arm64-v8a`, `armeabi-v7a`, `x86_64` |

## References

- [ghostty-org/ghostty](https://github.com/ghostty-org/ghostty)
- [tapthaker/ghostty-android](https://github.com/tapthaker/ghostty-android)
- [termux/termux-packages](https://github.com/termux/termux-packages)
