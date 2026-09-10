# Psysonic Flatpak bundle

This repository builds the standalone `Psysonic.flatpak` file and the signed
OSTree repositories published for Psysonic releases. It is not a Flathub
submission repository.

The bundle points Flatpak at Flathub only for the GNOME runtime dependency.
Psysonic itself updates from `flatpak.psysonic.de` after the first install.

Two independent channels are published so release-candidate testing cannot
replace the stable repository:

| Channel | Flatpak branch | Repository |
| --- | --- | --- |
| Stable | `stable` | `https://flatpak.psysonic.de/stable/repo/` |
| Release candidate | `rc` | `https://flatpak.psysonic.de/rc/repo/` |

The stable channel receives stable releases only. The RC channel receives RC
builds and the matching final stable release, so testers continue onto the
released build without switching remotes. A published `version.txt` guard stops
an older stable patch from replacing an RC from a newer release line.

Each channel also publishes `release.json` with its current version, tag and
GitHub release notes. Flatpak builds read this file through the native host so
the updater follows the installed branch without browser CORS or API-rate-limit
dependencies.

## Install a release bundle

Download `Psysonic.flatpak` and its checksum from the latest Psysonic release,
then run:

```bash
sha256sum -c Psysonic.flatpak.sha256
flatpak install --user ./Psysonic.flatpak
flatpak run io.github.psysonic.psysonic
```

Once a repository-backed bundle has been installed, update it with:

```bash
flatpak update --user io.github.psysonic.psysonic
```

## Build locally

1. Install dependencies.

    ```bash
    make install-dependencies-locally
    ```

1. Initialise `shared-modules`.

    ```bash
    make submodule-update-init
    ```

1. Build the standalone bundle. Local builds are unsigned unless GPG variables
   are provided.

    ```bash
    make bundle \
      FLATPAK_BRANCH=stable \
      REPO_URL=https://flatpak.psysonic.de/stable/repo/
    ```

    The output is `Psysonic.flatpak` plus `Psysonic.flatpak.sha256`.

1. Install and smoke-test the bundle.

    ```bash
    make verify-bundle
    ```

To iterate without recreating the full source cache, use `make build-fast-install`.

For an RC build, use `FLATPAK_BRANCH=rc` and the RC repository URL. The app can
then be addressed explicitly as `io.github.psysonic.psysonic//rc`.

## Publishing

The application repository's `Flatpak Publish` workflow infers the channel from
the selected tag:

- `app-vX.Y.Z` publishes branch `stable` and also advances `rc` when it would
  not downgrade that channel.
- `app-vX.Y.Z-rc.N` publishes branch `rc`.

The workflow expects these GitHub Actions secrets in the application repository:

| Secret | Value |
| --- | --- |
| `OSTREE_FTP_SERVER` | FTP/FTPS/SFTP URL rooted at the HTTPS document root |
| `OSTREE_FTP_USER` | Deployment account |
| `OSTREE_FTP_PASSWORD` | Deployment password |
| `OSTREE_GPG_PRIVATE_KEY_B64` | Base64-encoded private GPG signing key |

Use a dedicated CI signing key that does not require an interactive passphrase.
Create the secret value with:

```bash
gpg --export-secret-key <key-id> | base64 --wrap=0
```

For `ftp://` URLs, the workflow requires TLS for credentials and data. The FTP
account root must map to `https://flatpak.psysonic.de/`; the workflow publishes
the `stable/` and `rc/` directories below it using a staging-directory rename.

## Generating sources

After changing `COMMIT_HASH` and the manifest source commit for a new release,
regenerate both offline dependency lists:

```bash
make generated-sources
make cargo-sources
```

Before publishing, the workflow verifies that the manifest and `COMMIT_HASH` are
pinned to the selected release tag. It then uploads the bundle to the existing
GitHub Release and deploys the matching signed update repository.
