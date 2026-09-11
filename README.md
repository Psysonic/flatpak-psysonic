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

Official publication retains five stable commits and three RC commits in their
respective OSTree histories. The test channel is intentionally rebuilt with only
its current commit. Users can inspect retained stable versions and roll back with:

```bash
flatpak remote-info --log psysonic io.github.psysonic.psysonic
flatpak update --user --commit=<commit> io.github.psysonic.psysonic
```

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

The supported installation scope is per-user. The in-app updater deliberately
uses `flatpak update --user`; system-wide installations are not currently part
of the supported update contract.

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

Publishing a Psysonic GitHub Release triggers the application repository's
`Flatpak Publish` workflow automatically. A manual dispatch with the release tag
remains available to retry a failed run. The workflow infers the channel from
the tag:

- `app-vX.Y.Z` publishes branch `stable` and also advances `rc` when it would
  not downgrade that channel.
- `app-vX.Y.Z-rc.N` publishes branch `rc`.

The workflow checks out the exact release tag, rewrites a temporary packaging
checkout to that source commit, copies the canonical desktop metadata, and
regenerates both offline dependency lists before building. The committed source
pin remains useful for local packaging work, but it is not a release prerequisite
and requires no manual update. Draft or otherwise unpublished RC and stable
Releases are rejected before any Flatpak channel is read or changed.
Before exporting a release channel, the workflow verifies and mirrors its signed
current history. The new commit is added on top and bounded pruning keeps five
stable commits or three RC commits; test publications start from an empty repo.

The workflow expects these GitHub Actions secrets in the application repository:

| Secret | Value |
| --- | --- |
| `OSTREE_SSH_HOST` | Deployment hostname or IPv4 address |
| `OSTREE_SSH_PORT` | SSH port |
| `OSTREE_SSH_USER` | Restricted deployment account |
| `OSTREE_SSH_PATH` | Absolute HTTPS document root, currently `/var/www/flatpak` |
| `OSTREE_SSH_PRIVATE_KEY` | Unencrypted private key dedicated to GitHub Actions deployment |
| `OSTREE_SSH_KNOWN_HOSTS` | Pinned OpenSSH known-host entry for the configured host and port |
| `OSTREE_GPG_PRIVATE_KEY_B64` | Base64-encoded private GPG signing key |

It also requires this repository variable in the application repository:

| Variable | Value |
| --- | --- |
| `OSTREE_GPG_FINGERPRINT` | Full uppercase 40- or 64-character fingerprint of the repository signing key |

Use a dedicated CI signing key that does not require an interactive passphrase.
The workflow fails if its full fingerprint differs from
`OSTREE_GPG_FINGERPRINT`, preventing accidental signing-key replacement.
Create the secret value with:

```bash
gpg --export-secret-key <key-id> | base64 --wrap=0
```

Run the application's **Flatpak SSH Diagnostics** workflow after changing any
SSH secret. It verifies strict host-key checking, the dedicated account,
directory write access, SCP upload, public HTTPS retrieval, and cleanup without
publishing a release. The release workflow uploads hidden staging directories
with SCP, atomically switches `stable/` and `rc/`, verifies each signed remote,
and retains backups until the complete deployment succeeds.

## Generating sources

When changing the committed source pin for local packaging work, regenerate both
offline dependency lists:

```bash
make generated-sources
make cargo-sources
```

Official publication does this preparation automatically from the selected
application checkout. It then uploads the bundle to the existing GitHub Release
and deploys the matching signed update repository.
