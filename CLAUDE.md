# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The parent `../CLAUDE.md` describes the fork collection, the shared toolchain
(Test Kitchen, pre-commit, CI) and the `template-formula` layout. This file only
covers what is specific to `grafana-formula`.

## Commands

```bash
bundle install
bin/kitchen list                               # 3 instances: default-<platform>
bin/kitchen test default-debian-13-3008-2      # one instance end to end
bin/kitchen converge default-debian-11-3006-27 # apply only, keep the container
bin/kitchen verify default-debian-11-3006-27   # rerun the InSpec controls
pre-commit run --all-files
```

There is a single suite, `default`, so one instance per platform. The
pre-commit config has **no rubocop hook**: yamllint runs on the whole tree,
salt-lint, shellcheck, rstcheck and rst-lint on the matching files.

## How the formula works

`init.sls` picks the install path from one switch, `grafana:pkg:use_upstream_archive`:

- `false` (production, and the Kitchen suite): `grafana.package` →
  `pkg.installed` of `grafana`, plus `package/repo` only when
  `pkg:use_upstream_repo` is true.
- `true`: `grafana.archive` downloads `grafana-<version>.<kernel>-<arch>` from
  `dl.grafana.com` (URL, hash and extract dir are computed in `map.jinja`,
  which also appends the archive `bin/` to `environ`).

Then `.config` and `.service`, whatever the path:

- `config/file.sls` renders `grafana.ini` from the **`grafana:config` dict**:
  the `default` key becomes top-level `key = value` lines, every other key a
  `[section]` (`files/default/grafana.ini.jinja`, through TOFS). The whole
  state is skipped when `config` is empty. The file holds the database
  password, hence `0640 root:grafana`; keep that when touching it. `group` is
  passed twice to that `file.managed`; both render `grafana` on the package
  path.
- `config/environ.sls` always manages `/etc/default/grafana.sh`, although
  `environ` is only filled on the archive path; on the package path it is a
  header-only file nothing sources. `environ_spec.rb` asserts on it, so
  removing the state means removing the control too.
- `config/alternatives/install.sls` renders nothing unless the archive path is
  used **and** `linux:altpriority > 0`. It relies on the `alternatives` state
  module, which is gone from Salt 3008 core.
- `service/running.sls` unmasks and starts `grafana-server` with an
  `onlyif: systemctl list-unit-files | grep …`: if the unit is missing, the
  state is skipped, not failed.

### Repository: `use_upstream_repo` is off in production

`osfamilymap.yaml` turns `use_upstream_repo` on for Debian (legacy
`apt.grafana.com` line with `key_url`). Production sets it back to `false`: the
repository is declared by apt-formula (deb822 file, key in its own keyring).
The Kitchen suite does the same — an inline pillar in
`kitchen.yml` forces `false`, and `test/salt/states/repo.sls` reproduces
apt-formula's repository and runs first in `state_top`. So `package/repo/*`
and the `pkg:repo` keys of `pillar.example` are never exercised.

### Map data relevant on Debian

`defaults.yaml` plus the Debian block of `osfamilymap.yaml`; `osarchmap.yaml`
only matters for the archive path (`arch`). `osmap.yaml` and
`osfingermap.yaml` are empty dicts. The FreeBSD, Windows and MacOS branches
(including the `cmd.run stat` call in `map.jinja`) are never rendered on the
fleet.

## Tests

- There is no `test/salt/pillar/`: the suite pillar is **`pillar.example`
  itself** (`pillars_from_files`). `config_spec.rb` asserts on its values
  (`instance_name`, `admin_user`, `client_secret`), so editing
  `pillar.example` can break the tests.
- `grafana._mapdata` runs in the suite, but there is no `_mapdata` control and
  no reference dump under `test/integration/default/files/`, so the merged map
  is never compared.
- `test/integration/default/todo/archives_spec.rb` sits outside `controls/`
  and is not run: the archive path has no test.
- `clean.sls` and its leaves are not in `state_top` and not tested.
  `config/clean.sls` does nothing unless `linux:altpriority > 0`.
