# Install ubi GitHub Action

This GitHub Action installs [ubi (Universal Binary
Installer)](https://github.com/houseabsolute/ubi), a nifty tool for downloading
and installing pre-built binaries from GitHub releases.

## Usage

### Basic Usage

```yaml
- name: Install ubi, is and debounce
  uses: oalders/install-ubi-action@v0.0.6
  with:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    projects: |
      oalders/is
      oalders/debounce -v
```

### Complete Workflow Example

```yaml
name: CI
on: [pull_request, workflow_dispatch]

jobs:
  minimal:
    runs-on: ubuntu-latest
    steps:
      - name: Install ubi, is and debounce
        uses: oalders/install-ubi-action@v0.0.6
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          projects: |
            oalders/is
            oalders/debounce -v
  no_sudo:
    runs-on: ubuntu-latest
    steps:
      - name: Install ubi
        uses: oalders/install-ubi-action@v0.0.6
        id: ubi
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Use ubi to install "is" and "debounce"
        run: |
          ubi --project oalders/is --in "$HOME/.local/bin"
          ubi --project oalders/debounce --in "$HOME/.local/bin"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Verify installations
        run: |
          echo "ubi version: ${{ steps.ubi.outputs.version }}"
          echo "ubi path: ${{ steps.ubi.outputs.path }}"
          is there ubi --verbose
          is there is --verbose
          is there debounce --verbose
          is known summary var --md >> $GITHUB_STEP_SUMMARY

  with_sudo:
    runs-on: ubuntu-latest
    steps:
      - name: Install ubi
        uses: oalders/install-ubi-action@v0.0.6
        id: ubi
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          sudo: true

      - name: Use ubi to install other tools
        run: |
          sudo --preserve-env=GITHUB_TOKEN ubi --project oalders/is --in /usr/local/bin
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Verify installations
        run: |
          echo "ubi version: ${{ steps.ubi.outputs.version }}"
          echo "ubi path: ${{ steps.ubi.outputs.path }}"
          is there ubi --verbose
          is there is --verbose
          is known summary var --md >> $GITHUB_STEP_SUMMARY

  with_sudo_target:
    runs-on: ubuntu-latest
    steps:
      - name: Install ubi
        uses: oalders/install-ubi-action@v0.0.6
        id: ubi
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          sudo: true
        env:
          TARGET: /usr/local/sbin
      - name: Use ubi to install other tools
        run: |
          sudo --preserve-env=GITHUB_TOKEN ubi --project oalders/is --in /usr/local/sbin
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Verify installations
        run: |
          echo "ubi version: ${{ steps.ubi.outputs.version }}"
          echo "ubi path: ${{ steps.ubi.outputs.path }}"
          is there ubi --verbose
          is there is --verbose
          is known summary var --md >> $GITHUB_STEP_SUMMARY
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `projects` | Newline-delimited list of projects to install using ubi | No | `''` |
| `sudo` | Whether to use sudo for installation | No | `false` |
| `GITHUB_TOKEN` | GitHub token to use for API requests, helps avoid rate limiting | No | `''` |
| `version` | ubi release tag to install, with leading `v` | No | `v0.13.0` |

**Note:** the bootstrap script is pinned to commit
`d9348539c2521f05225618139ea23fd3f54bce46` for reproducibility and security.
The ubi release is pinned via `version`; the default is an immutable release.
Empty values and values containing `/` are rejected. Releases not marked
immutable can be re-pointed upstream, so prefer immutable ones.

**Note:** each `projects` line is split on whitespace so it can carry ubi
flags (e.g. `oalders/debounce -v`); glob characters are not expanded. Set
`projects` only from trusted sources, not issue titles, branch names or
`workflow_dispatch` inputs: a line can add any ubi argument, including `--url`
and `--in`, so it can put an arbitrary binary on `PATH` for later steps, and
with `sudo: true` it does so as root.

**Note:** set the `TARGET` environment variable to choose where ubi is
installed (by default `~/.local/bin`, or `/usr/local/bin` with `sudo: true`);
`projects` are installed there too. A `TARGET` directory goes
first on `PATH` for later steps, so it can shadow system binaries, and with
`sudo: true` it is written to as root. Like `projects`, set it only from
trusted sources, not issue titles, branch names or `workflow_dispatch` inputs.

## Outputs

| Output | Description |
|--------|-------------|
| `version` | The version of ubi that was installed |
| `path` | The path where ubi was installed |

## What is ubi?

[ubi](https://github.com/houseabsolute/ubi) is a universal binary installer
that makes it easy to download and install pre-built binaries from GitHub
releases. It's particularly useful for:

- Installing command-line tools in CI/CD pipelines
- Keeping tools up-to-date across different environments
- Avoiding the need to compile tools from source

## Licence

This action is provided under the MIT Licence.
