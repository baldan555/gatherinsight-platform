# Application pipeline (mirror)

The application code lives in a private repository. These files are a read-only copy of its pipeline so the
release process can be reviewed here; they do not run from this repository.

| File | In the app repository | What it does |
|---|---|---|
| `ci-cd.yml` | `.github/workflows/ci-cd.yml` | Typecheck + unit tests on every push and pull request; release on every push to `main` |
| `unit-tests.sh` | `scripts/ci/unit-tests.sh` | 39 test files of pure logic (sampling and GPS engines, statistics, survey rules, i18n coverage, audit guards) |
| `preflight.sh` | `scripts/ci/preflight.sh` | Asks Google Cloud (`testIamPermissions`) whether the deployer may do every release step, without changing anything |
| `smoke-test.sh` | `scripts/ci/smoke-test.sh` | Health check plus four routes that must answer as themselves, run against the new revision before it gets traffic and against production after |

Release order: build both images (app and migrator) with a layer cache, run `prisma migrate deploy` as a Cloud Run
job, deploy the new revision with **no traffic** under a `candidate` tag, smoke-test it on its own URL, then move
100% of traffic to it. A revision that fails its checks never serves a user. While the database is switched off to
save money, the pipeline stops after the preflight with a warning instead of failing.
