# -*- coding: utf-8 -*-
# vim: ft=sls
---
# Test-only: declare the grafana repository the way VEILLECO's apt-formula does in
# production (deb822 file, key in its own keyring), so the formula installs the
# package with `use_upstream_repo: false`.
test-repo-grafana-key:
  file.managed:
    - name: /etc/apt/keyrings/grafana.asc
    - source: https://apt.grafana.com/gpg.key
    - skip_verify: true
    - makedirs: true
    - mode: '0644'

test-repo-grafana-source:
  file.managed:
    - name: /etc/apt/sources.list.d/grafana.sources
    - mode: '0644'
    - contents: |
        Types: deb
        URIs: https://apt.grafana.com
        Suites: stable
        Components: main
        Signed-By: /etc/apt/keyrings/grafana.asc
    - require:
      - file: test-repo-grafana-key

test-repo-grafana-refresh:
  cmd.run:
    - name: apt-get update
    - onchanges:
      - file: test-repo-grafana-source
