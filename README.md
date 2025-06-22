# Install ubi GitHub Action

This GitHub Action installs [ubi (Universal Binary
Installer)](https://github.com/houseabsolute/ubi), a nifty tool for downloading
and installing pre-built binaries from GitHub releases.

`ubi` will be installed into `/usr/local/bin`. After that you can specify the
path where you'd like to install additional binaries. e.g.

```
sudo ubi --project oalders/is --in /usr/local/bin
```

## Usage

### Basic Usage

```yaml
- uses: oalders/install-ubi-action@v0.0.2
```

### Complete Workflow Example

```yaml
name: CI
on: [pull_request, workflow_dispatch]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Install ubi
        uses: oalders/install-ubi-action@v0.0.2
        id: ubi

      - name: Use ubi to install "is" and "debounce"
        run: |
          # Install is using ubi
          sudo ubi --project oalders/is --in /usr/local/bin

          # Install debounce using ubi
          sudo ubi --project oalders/debounce --in /usr/local/bin

      - name: Verify installations
        run: |
          echo "ubi version: ${{ steps.ubi.outputs.version }}"
          echo "ubi path: ${{ steps.ubi.outputs.path }}"
          is --version
          debounce --version
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `sudo` | Whether to use sudo for installation (required for `/usr/local/bin` on most systems) | No | `true` |


**Note:** the bootstrap script is pinned to commit
`d9348539c2521f05225618139ea23fd3f54bce46` for reproducibility and security.

## Outputs

| Output | Description |
|--------|-------------|
| `version` | The version of ubi that was installed |
| `path` | The path where ubi was installed |


## What is ubi?

[ubi](https://github.com/houseabsolute/ubi)  is a universal binary installer
that makes it easy to download and install pre-built binaries from GitHub
releases. It's particularly useful for:

- Installing command-line tools in CI/CD pipelines
- Keeping tools up-to-date across different environments
- Avoiding the need to compile tools from source

## Licence

This action is provided under the MIT Licence.
