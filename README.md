# install-ubi-action

This GitHub Action installs the [IBM UBI](https://github.com/IBM/ubi) binary on your runner.

## Features

- Installs the specified UBI version (default: `latest`)
- Supports custom install path
- Works with or without `sudo`
- Exposes installed path as output

---

## Inputs

| Name          | Description                                                 | Default            |
|---------------|-------------------------------------------------------------|--------------------|
| `version`     | UBI version to install (e.g. `v0.0.36`, or `latest`)        | `latest`           |
| `install-path`| Directory to install the binary                             | `/usr/local/bin`   |
| `sudo`        | Whether to use `sudo` for installation                      | `false`            |

---

## Outputs

| Name       | Description                             |
|------------|-----------------------------------------|
| `ubi-path` | Full path to the installed UBI binary   |

---

## Example Usage

```yaml
- name: Install UBI
  uses: chankeypathak/install-ubi-action@main
  with:
    version: 'v0.0.36'
    install-path: '/tmp'
    sudo: false
