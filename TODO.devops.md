# DevOps Todo

This file tracks the remaining DevOps follow-up work for the local SaaS-style stack.

## In Progress

- [x] Remove the UTF-8 BOM from `smoke-elasticsearch-proxy.ps1` request bodies and confirm `verify.ps1` runs without AEM JSON parse noise
- [ ] Run full runtime validation for `author`, `publish`, `dispatcher`, `traefik`, `kibana`, `logstash`, `filebeat`, and `metricbeat`

## Pending Decisions

- [ ] Decide whether this repo stays on the current minimal Elasticsearch proxy integration or ports the full app-side indexing/search module from the source project
- [x] Add an ignored local override path for ports and secrets with `.env.local`
- [ ] Decide whether the team wants to actively move the committed default secrets out of `.env` now that `.env.local` is available

## Nice To Have

- [x] Add one more local operator helper after runtime validation, likely `open.ps1` or `restart.ps1`

## Runtime Findings

- [x] `verify.ps1` is now clean: no new AEM JSON parse errors after the smoke-test POST path
- [x] Alternate-port runtime validation works for `author`, `publish`, `traefik`, `dispatcher`, `dashboard`, `kibana`, `filebeat`, `metricbeat`, and the Elasticsearch proxy path
- [x] `publish` eventually recovers and answers `200` on `http://localhost:14513/system/console/bundles.json`, but it did emit an early `DocumentNodeStoreService` Mongo timeout during startup
- [ ] `publish` emitted a `DocumentNodeStoreService` attempt to reach Mongo at `0.0.0.0:27017`; this needs a clean-volume validation pass before calling it a repo defect
- [ ] `elasticsearch` still shows host clock / timer warnings during local startup on this machine
- [ ] `logstash` comes up but shows expected batch-job / restart behavior because the pipeline is configured with `exit_after_read => true`
