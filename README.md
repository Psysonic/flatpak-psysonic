# Psysonic Flatpak Creator

1. Install dependencies

    ```bash
    make install-dependencies-locally
    ```

1. Update shared-modules

    ```bash
    make update-shared-modules
    ```

1. Generate the package

    ```bash
    make build-install
    ```

    To skip offline package download after a failed build:

    ```bash
    make build-fast-install
    ```

## Generating sources

To generate the required sources:

```bash
make generated-sources
make cargo-sources
```
