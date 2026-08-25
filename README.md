# percona-valkey

Percona for Valkey packaged as a strict-confinement snap: Valkey — the
open-source, Linux Foundation-backed key/value datastore — plus Percona's
full module bundle (valkey-json, valkey-bloom, valkey-search,
valkey-audit, and valkey-ldap), all preloaded and staged unmodified from
Percona's official apt packages at `repo.percona.com/valkey-91/apt`. One
track/branch (`9.1/edge`) is published so far. Base: `core26`.

## Why this snap

Installing this snap gets Valkey and all five Percona modules in one
artifact, with every package pinned to an exact upstream version.
`valkey-server` starts automatically on `127.0.0.1:6379` with every module
already loaded — no separate `MODULE LOAD` step. Valkey Sentinel ships
installed but disabled, since it needs a `sentinel monitor` line before
it's useful. Future Valkey majors would land as additional
branches/tracks, following the same one-track-per-version pattern as the
rest of the Percona snap family.

## Tracks and branches

| Branch | apt source | Version |
|---|---|---|
| `9.1/edge` | `repo.percona.com/valkey-91/apt` (resolute, main + testing*) | 9.1.1-1 |

\* `main` carries most packages; `percona-valkey-ldap` is pinned from
`testing` because Percona's Ubuntu builds of it are, as of this writing,
only published there (its Debian builds are in `main`). Every other
package is exact-version-pinned, so nothing else can drift.

## Getting the snap

### From a CI build

Every push to a `*/edge` branch, every pull request, and every manual
`workflow_dispatch` run of the `Tests` workflow builds the snap (amd64 and
arm64) and runs the full spread suite against it.

1. Open the workflow run in GitHub Actions and download the
   `snap-packages` artifact.
2. Unzip it.
3. Install:
   ```
   sudo snap install ./percona-valkey_<version>_amd64.snap --dangerous --jailmode
   ```
   (substitute the `arm64` filename on that architecture).

### From source

```
git clone https://github.com/EvgeniyPatlan/percona-valkey-snap.git
cd percona-valkey-snap
snapcraft pack
sudo snap install ./percona-valkey_*.snap --dangerous --jailmode
```

Requires the `snapcraft` and `lxd` snaps.

A Store channel exists for this track (`9.1/edge`), but the release
workflow only publishes when the repository's `RELEASE_ENABLED` variable
is set, so Store availability isn't guaranteed.

## First steps

```
percona-valkey.valkey-cli ping
percona-valkey.valkey-cli JSON.SET doc $ '{"hello":"world"}'
percona-valkey.valkey-cli BF.ADD filter item
```

Security posture (as installed): there is **no password by default**. The
server binds to `127.0.0.1` only (protected-mode is a secondary guard),
but any local process has full access until you set `requirepass` or ACLs
in the config.

## Services and apps

| App | Kind | Purpose |
|---|---|---|
| `valkey-server` | daemon, auto-started | Valkey server, `127.0.0.1:6379`, all five modules preloaded |
| `valkey-sentinel` | daemon, disabled by default | Valkey Sentinel, port 26379 |
| `valkey-cli` | CLI | interactive/batch client |
| `valkey-benchmark` | CLI | load-testing tool |
| `valkey-check-aof` | CLI | AOF file integrity check |
| `valkey-check-rdb` | CLI | RDB file integrity check |
| `redis-cli` | CLI | Redis-compatible alias of `valkey-cli` |
| `redis-benchmark` | CLI | Redis-compatible alias of `valkey-benchmark` |
| `redis-check-aof` | CLI | Redis-compatible alias of `valkey-check-aof` |
| `redis-check-rdb` | CLI | Redis-compatible alias of `valkey-check-rdb` |

Starting Sentinel:

```
sudo snap start percona-valkey.valkey-sentinel
sudo snap stop percona-valkey.valkey-server
sudo snap restart percona-valkey.valkey-server
```

`snap set` configuration knobs:

| Key | Effect |
|---|---|
| `valkey-args` | extra CLI flags appended to `valkey-server` on start |
| `sentinel-args` | extra CLI flags appended to `valkey-sentinel` on start |

## Configuration and data paths

| Item | Path |
|---|---|
| Server config | `/var/snap/percona-valkey/current/etc/valkey/valkey.conf` (the server may rewrite this via `CONFIG REWRITE`) |
| Sentinel config | `/var/snap/percona-valkey/current/etc/valkey/sentinel.conf` (Sentinel rewrites this at runtime — state, `myid`) |
| Data directory | `/var/snap/percona-valkey/common/data` (survives snap refreshes) |
| Server log | `/var/snap/percona-valkey/common/log/valkey-server.log` |
| Audit log | `/var/snap/percona-valkey/common/log/audit.log` |
| Sentinel log | `/var/snap/percona-valkey/common/log/valkey-sentinel.log` |
| Unix socket | `/var/snap/percona-valkey/current/run/valkey.sock` |

Input/output files for the CLI tools must live under
`/var/snap/percona-valkey/common` — the snap cannot read your home
directory, and the data directory is not world-readable, so most
operations need `sudo`.

## Modules, AOF, and Sentinel

Preloaded modules (visible in `MODULE LIST` from startup): `json`
(valkey-json, `JSON.*`), `bf` (valkey-bloom, `BF.*`), `search`
(valkey-search, `FT.*` vector/full-text search), `audit` (valkey-audit,
connection/auth/command logging to
`/var/snap/percona-valkey/common/log/audit.log`), and `ldap`
(valkey-ldap, LDAP authentication — needs its own configuration, such as
an LDAP server and bind DN, before use; see the module README shipped at
`usr/share/doc/percona-valkey-ldap/` inside the snap).

Durability is RDB snapshots by default. To switch to AOF:

```
sudo percona-valkey.valkey-cli CONFIG SET appendonly yes
sudo percona-valkey.valkey-cli CONFIG REWRITE
```

Setting up Sentinel to monitor this snap's own server:

```
echo "sentinel monitor mymaster 127.0.0.1 6379 1" | sudo tee -a /var/snap/percona-valkey/current/etc/valkey/sentinel.conf
sudo snap start percona-valkey.valkey-sentinel
percona-valkey.valkey-cli -p 26379 SENTINEL master mymaster
```

## Testing

Every push and pull request runs the full spread suite against a real
snapd install inside an LXD `ubuntu-24.04` VM, on both `amd64` and
`arm64`. Suites: `cli_compat`, `persistence`, `sentinel_service`,
`smoke`, and `upgrade` (currently marked `manual` until the snap is
published to `9.1/edge`).

To reproduce locally:

```
snapcraft pack
CRAFT_ARTIFACT=$(pwd)/percona-valkey_<version>_amd64.snap spread -v
```

(`spread` from `go install github.com/canonical/spread/cmd/spread@latest`;
needs the `lxd` snap.)

## Updating to a new Percona release

`scripts/bump-version.sh` checks every exact-pinned package in
`snap/snapcraft.yaml` against the apt indexes declared under
`package-repositories`, and bumps any pin (and the top-level `version:`
field, derived from the `percona-valkey-server` pin) that is out of date.

For a package available from more than one component (this repo declares
both `main` and `testing` from the same apt source), the script only takes
candidate versions from the first component, in the order listed under
`components:`, that actually contains that package — so
`percona-valkey-ldap` resolves from `testing` (absent from `main` as of
this writing, see the tracks table above) while every other package
resolves from `main` and ignores any newer build that happens to also sit
in `testing`. If Percona later syncs `percona-valkey-ldap`'s Ubuntu builds
into `main`, the same rule switches it to tracking `main` automatically.

### Automated

The `Update check` workflow (`.github/workflows/update-check.yaml`) runs
weekly and, for each `*/edge` branch, runs the same script and opens a pull
request per branch that has an available update. The PR:

- touches only `snap/snapcraft.yaml`, with the pin diff as the commit;
- contains the script's summary table (old/new version per package) in its
  description;
- is verified the same way any other PR is: CI (`Tests`) builds the snap for
  `amd64` and `arm64` and runs the full spread suite against it. Merging the
  PR into its track branch produces the downloadable `snap-packages`
  artifact described above.

To trigger an immediate check instead of waiting for the weekly run, start
the `Update check` workflow manually from the Actions tab (`workflow_dispatch`,
optionally scoped to one branch via the `branch` input).

If a bump PR is closed without merging, its `bump/<track>-<version>` branch
is left behind and that exact version is skipped on every future run until
the branch is deleted (or a newer version ships) — delete the branch if you
want the check retried for that version.

### Manual

```
./scripts/bump-version.sh
git diff
```

Review the diff, then commit and push as usual.

### Scope

The script only updates pins within the current track (`9.1`). A new
Percona major version means a new track/branch and, per the Percona
publishing model for Valkey, a new apt repository path
(`repo.percona.com/valkey-<NN>/apt`) — that's a manual, one-time setup, not
something this script does.

## License

The snap packaging is Apache-2.0. Upstream component licenses (Valkey
server, tools, and Sentinel, the Redis-compatibility package, and all
five Percona modules) are shipped under `licenses/` inside the snap.
