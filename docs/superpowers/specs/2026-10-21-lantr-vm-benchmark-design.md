# lantr Plutus VM benchmark – design

Status: approved 2026-10-21.

## 0. Decisions

| # | Decision | Choice |
|---|---|---|
| D1 | Purpose | Public, neutral comparison for library authors who choose an evaluator |
| D2 | Home | Standalone repo `lantr-io/plutus-vm-benchmark` (not a GitHub fork) with the full SAIB history and MIT credit. Page at `plutus-vm-bench.lantr.io` (GitHub Pages, CNAME at Namecheap). scalus.org links to it |
| D3 | What is timed | Node-equivalent: flat decode + evaluate with the mainnet cost model and costing on |
| D4 | Correctness gate | Result and ExUnits of every script must equal Haskell. A VM that fails is not published; the page lists it as "failed check" |
| D5 | Compiled VMs (Scalus JIT) | Same ranking as interpreters, with a "compile excluded" badge and a compile-time column |
| D6 | PR automation | Bot opens version-bump PRs (`.env` only); they auto-merge on smoke + gate pass. Code PRs need human review; their CI has no secrets |
| D7 | Schedule | Monthly cron (skip if nothing merged since the last run) + manual button |
| D8 | Corpus | The existing 89 `plutus_use_cases` scripts. A mainnet PlutusV3 corpus is v2, as a separate ranking |
| D9 | Orchestration | GitHub Actions + `hcloud` CLI; NixOS installed on a fresh Ubuntu server by nixos-anywhere on each run |
| D10 | Older cost model | Where a VM API accepts a cost model, the harness passes the mainnet PlutusV3 model and D4 applies. Otherwise the row is published with an "outdated cost model" badge; the gate then requires ExUnits equal to Haskell under that VM's own semantics variant and model. Wrong results still hide the row |
| D11 | Gate parameters | PlutusV3, protocol version 11 (variant E), mainnet cost model, counting mode. CIP-117 unit-result rule not applied (78 PlutusV1-era scripts return a non-unit term) . The 89 scripts are PlutusV1-era; they are evaluated as PlutusV3 programs, like Plutus's own `validation` CEK benchmark (plutus-benchmark BenchCek.hs), and the page says so. Owner chose this over node-exact PlutusV1 rules (variant D), which would push the Scalus JIT to its CEK fallback |
| D12 | Pins | Release tags for every VM (Aiken v1.1.24, Scalus v1.4.0, plutus 1.63.0.0). |

### Line-up (rule: the VM has a downstream user today)

| VM | Language | Harness |
|---|---|---|
| Haskell plutus-core | Haskell | exists |
| Scalus CEK | Scala (JVM) | exists |
| Scalus JIT | Scala (JVM) | exists |
| Scalus.js | Scala.js (Node) | **new** |
| Aiken | Rust | **new** |
| uplc-turbo (Amaru) | Rust | exists |
| plutigo (Dingo) | Go | exists |
| blaze-plutus (V8, JSC) | TypeScript | exists |

Dropped: Chrysalis, Plutuz, llvm-uplc. Julc removed 2026-10-21: no stable release (only 0.1.0-preNN) and no visible downstream users; it rejoins at its first stable release. OpShin uplc removed 2026-10-21: it fails the correctness gate on the 11 UPLC 1.1.0 scripts (no `case` on builtin values, a protocol version 11 feature) at its latest release 1.3.3; it rejoins when it passes the gate. Aiken WASM removed 2026-10-21: the Aiken team ships no UPLC WASM; the only released one, `@lucid-evolution/uplc`, caches decoded programs with no off switch, so it cannot run the D3 loop as published. plu-ts and Helios join if their authors send a PR.

## 1. Components

Repo `lantr-io/plutus-vm-benchmark`:

| Unit | Does | Change from today |
|---|---|---|
| `harness/<vm>/` + `scripts/run-<vm>.sh` | One harness per VM | Add `aiken`, `scalus-js`. Remove chrysalis, plutuz, llvm-uplc |
| `.env` | Pins each VM to a SHA or tag | Haskell pinned to the plutus tag of the production node (today 1.63.0.0) |
| `images/` | One Docker image per VM, pushed to GHCR | Replaces the single image: a bump rebuilds one VM only |
| `check/` | Correctness gate: each VM writes result + ExUnits per script; the gate diffs them against Haskell | New |
| `parsers/`, `report/` | Outputs → `unified.csv` → HTML report | Add compile-time column, "compile excluded" badge, history chart |
| `results/<date>/` | Git-tracked history with `environment.txt` and pins | Kept |
| `.github/workflows/` | `smoke.yml` (PRs, no secrets), `bump.yml` (bot), `run.yml` (monthly + manual) | New |

NixOS config of the bench server, in this repo (not in `infra`: `infra` is local-only and holds secrets,
so a workflow cannot fetch it; a public config also lets anyone rebuild the exact machine):

- `flake.nix` output `bench-runner` = `nix/runner.nix` + `nix/disko.nix`.
- Rootful Docker (compose needs `SYS_NICE`), CPU governor `performance`.
- Root SSH keys come from the Hetzner metadata service at boot (per-run key, nothing baked in).
- `bench-selfdestruct.timer`: 10 h after boot, deletes its own server through the Hetzner API.
- `scripts/hetzner/up.sh` creates an Ubuntu server and installs the config with
  `nixos-anywhere --build-on remote` (no x86_64-linux builder needed). `down.sh` deletes it,
  `sweep.sh` deletes servers older than 12 h.
- Hetzner has no official NixOS image. Install on each run costs ~5–10 min of a multi-hour run. If it
  becomes flaky, snapshot an installed server with `hcloud server create-image` and boot from that.

Hetzner: a separate project for the benchmark. One fixed CCX (dedicated vCPU) server type. The API token is
stored only in the `run.yml` GitHub environment, which only `main` can use.

Token blast radius:

- Hetzner Cloud tokens are scoped to one project. A leaked bench token cannot read or change other lantr
  projects (for example `sugarrush-demo`).
- Inside the bench project a Read & Write token can create and delete servers. Hetzner has no finer scope.
  Limit the damage: keep the project server limit low (do not request an increase), set a billing alert,
  and let `sweep.yml` delete stray servers.
- The self-destruct timer needs the token on the server. Store it as a root-only `0400` file outside the
  Nix store. Benchmark containers do not mount it, because they run third-party VM code.

## 2. Data flow

### Version bump (`bump.yml`, weekly)

1. For each VM, read the latest upstream release tag. Scalus uses the latest tag, not master.
2. If a pin changed, open a PR that changes only `.env`.
3. `smoke.yml` builds the changed image, times 5 scripts, and runs the gate on all 89 scripts.
4. Pass: auto-merge. Fail: label `needs-human`; the old pin stays.

### Monthly run (`run.yml`)

1. Skip if no merge happened since the last `results/` directory.
2. Build and push changed images to GHCR on GitHub runners (not on the paid server).
3. `scripts/hetzner/up.sh`: create an Ubuntu server (run ID as a label) and install NixOS with nixos-anywhere.
4. Over SSH: pull images, write `environment.txt`, run the VMs one at a time, run the gate.
5. Copy `results/<date>/` back to the workflow.
6. `hcloud server delete` in an `always()` step. The self-destruct timer is the backstop.
7. Build the report. Rows that fail the gate are left out and listed as "failed check".
8. Commit the results to `main` and deploy GitHub Pages.

### History

- The chart plots each VM's geometric mean divided by Haskell's from the same run. The ratio survives
  hardware changes and reduces the ~10% drift between runs.
- The table shows absolute µs for the latest run only.

Expected run time: 3–5 h for the full line-up (the 4-VM run took 1.5 h on an M3 Max). Measure on the first run.

## 3. Failure handling and cost guards

- One VM fails to build or run: its row shows "failed", the run still publishes the others.
- Gate fails for a VM in the monthly run: row hidden, listed as "failed check", issue opened automatically.
- Server cleanup has three layers:
  1. `always()` delete step in `run.yml`.
  2. `bench-selfdestruct.timer` on the server (10 h).
  3. A daily `sweep.yml` deletes any server in the bench project with a run label older than 12 h.
- SSH or image pull fails: retry once, then delete the server and fail the workflow.
- Hetzner has no hard spending cap. Set a billing alert on the project.

## 4. Testing

- Gate test: feed a VM output with one wrong ExUnits value; the gate must fail. Run this in `smoke.yml`.
- Each new harness (Aiken, Scalus.js) must pass the gate on all 89 scripts before it joins.
- Dry run of `run.yml` with a cheap shared-vCPU server type and 3 VMs; verify the server is gone afterwards.
- First real run: compare Haskell ratios with the M3 Max runs of 2026-10-11; flag differences above 20%.

## 5. Open questions

1. Exact CCX type (for example CCX33 vs CCX43). `up.sh` defaults to `ccx33`.
2. Cost model and language version for the 89 scripts under D3: every VM in the line-up must support it.
