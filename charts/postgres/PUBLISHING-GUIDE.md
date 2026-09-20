# Publishing the PostgreSQL Helm Chart

This document records the exact workflow used to publish the simple PostgreSQL chart to the shared Helm repository.

The chart source is:

```text
charts/postgres/
```

The public Helm repository is:

```text
https://sudo0x.github.io/helm-charts
```

The GitHub source repository is:

```text
https://github.com/sudo0x/helm-charts
```

## Important directories

```text
charts/postgres/  # PostgreSQL chart source
dist/             # Local package output
docs/             # GitHub Pages published Helm repository
```

The source chart must be packaged before Helm can install it from the published repository.

## What was already available

Before publishing, the PostgreSQL chart was already committed and contained:

```text
charts/postgres/
├── Chart.yaml
├── values.yaml
├── README.md
└── templates/
```

The chart metadata was:

```yaml
name: sudo0x-postgres
version: 0.1.0
appVersion: "16"
```

The existing `docs` directory contained the Redis package and `index.yaml`, but it did not yet contain the PostgreSQL package.

## Step 1: Check the repository state

From Git Bash:

```bash
cd /d/dancypher
```

Check the branch and pending changes:

```bash
git status --short --branch
git log -3 --oneline
```

This check is important because it shows:

- Which branch is active.
- Whether the source chart is already committed.
- Whether unrelated files have local changes.
- Which commit will be the parent of the publishing commit.

Do not blindly stage every file when unrelated work exists.

## Step 2: Inspect the package directories

Check the local build directory:

```bash
ls dist
```

Check the GitHub Pages directory:

```bash
ls docs
```

Before PostgreSQL was published, the expected existing files were similar to:

```text
dist/
├── index.yaml
└── sudo0x-redis-0.2.0.tgz

docs/
├── index.yaml
└── sudo0x-redis-0.2.0.tgz
```

The PostgreSQL package did not exist yet.

## Step 3: Package the PostgreSQL chart

Run:

```bash
helm package charts/postgres --destination dist
```

Helm creates:

```text
dist/sudo0x-postgres-0.1.0.tgz
```

The `.tgz` file is the packaged Helm chart. It contains the chart source in a compressed archive that Helm can install.

## Step 4: Regenerate the shared repository index

Run:

```bash
helm repo index dist \
  --url https://sudo0x.github.io/helm-charts
```

This updates:

```text
dist/index.yaml
```

The index contains entries for all packages currently in `dist`, including Redis and PostgreSQL.

It records:

- Chart name.
- Chart version.
- Redis or PostgreSQL application version.
- Package URL.
- Package digest.
- Package metadata.

The URL option is important:

```text
--url https://sudo0x.github.io/helm-charts
```

It tells Helm where users will download the package.

## Step 5: Copy files to the GitHub Pages directory

GitHub Pages serves the `docs` directory, so copy the package and regenerated index:

```bash
cp dist/*.tgz docs/
cp dist/index.yaml docs/index.yaml
```

After copying, `docs` contains:

```text
docs/
├── index.yaml
├── sudo0x-postgres-0.1.0.tgz
└── sudo0x-redis-0.2.0.tgz
```

The public Helm repository now has entries for both charts.

## Step 6: Review changes before staging

Check all pending files:

```bash
git status --short --untracked-files=all
```

Review the published index:

```bash
git diff -- docs/index.yaml
```

The index should contain:

```yaml
entries:
  sudo0x-postgres:
  sudo0x-redis:
```

Review the local build index if needed:

```bash
git diff -- dist/index.yaml
```

The `dist` directory is local build output in this workflow. It does not need to be committed unless you intentionally want to store build artifacts there.

## Step 7: Stage only the publication files

Stage only the files required by GitHub Pages:

```bash
git add docs/index.yaml docs/sudo0x-postgres-0.1.0.tgz
```

Do not use this when unrelated changes exist:

```bash
git add .
```

The selective command protects unrelated work such as:

```text
dist/index.yaml
charts/spring-boot-service/
notes/
```

Review the staged files:

```bash
git diff --cached --stat
git diff --cached --name-only
```

Expected staged files:

```text
docs/index.yaml
docs/sudo0x-postgres-0.1.0.tgz
```

## Step 8: Commit the published package

Create a focused commit:

```bash
git commit -m "Publish sudo0x PostgreSQL Helm chart 0.1.0"
```

The commit should contain:

- The PostgreSQL `.tgz` package.
- The shared `index.yaml` update.

It should not contain unrelated chart source or notes unless those files were intentionally part of the same change.

## Step 9: Push to GitHub

Push the branch:

```bash
git push
```

The repository uses the configured SSH alias:

```text
git@github.com-sudo0x:sudo0x/helm-charts.git
```

If SSH authentication fails, test it:

```bash
ssh -T git@github.com-sudo0x
```

Successful authentication looks similar to:

```text
Hi sudo0x! You've successfully authenticated, but GitHub does not provide shell access.
```

## Step 10: Verify the public index

After GitHub Pages deploys, check:

```bash
curl -I https://sudo0x.github.io/helm-charts/index.yaml
```

A successful response should be:

```text
HTTP/1.1 200 OK
```

To inspect the PostgreSQL entry:

```bash
curl -sS https://sudo0x.github.io/helm-charts/index.yaml \
  | grep -A 12 sudo0x-postgres
```

The index should reference:

```text
https://sudo0x.github.io/helm-charts/sudo0x-postgres-0.1.0.tgz
```

## Step 11: Use the published repository

Add the repository if it has not been added locally:

```bash
helm repo add sudo0x https://sudo0x.github.io/helm-charts
```

If it already exists, refresh the local index:

```bash
helm repo update
```

Search for both charts:

```bash
helm search repo sudo0x
```

Expected results:

```text
sudo0x/sudo0x-postgres
sudo0x/sudo0x-redis
```

Inspect the available PostgreSQL version:

```bash
helm search repo sudo0x/sudo0x-postgres --versions
```

## Step 12: Install the published PostgreSQL chart

Install into the `infrastructure` namespace:

```bash
helm upgrade --install postgres sudo0x/sudo0x-postgres \
  --namespace infrastructure \
  --create-namespace
```

This uses the chart's default development values.

For a real environment, use an existing Secret:

```bash
kubectl create secret generic postgres-production-credentials \
  --from-literal=username=appuser \
  --from-literal=password='REPLACE_WITH_A_REAL_SECRET' \
  --namespace infrastructure
```

Install with the existing Secret:

```bash
helm upgrade --install postgres sudo0x/sudo0x-postgres \
  --namespace infrastructure \
  --set auth.existingSecret=postgres-production-credentials
```

The current chart remains a simple single-instance chart. This publishing process does not make it HA or production-ready by itself.

## Why `docs/index.yaml` is important

Helm does not discover chart packages by browsing GitHub source files.

Helm reads:

```text
https://sudo0x.github.io/helm-charts/index.yaml
```

The index tells Helm:

- Which charts exist.
- Which versions exist.
- Where to download each `.tgz` package.
- Which digest belongs to each package.

Without `index.yaml`, this command fails:

```bash
helm repo add sudo0x https://sudo0x.github.io/helm-charts
```

with an error such as:

```text
404 Not Found
```

## Why the package is copied to `docs`

GitHub Pages is configured to publish the `docs` directory from the `master` branch.

Therefore:

```text
dist/  = local build output
docs/  = public Helm repository
```

The package must be copied to `docs` so GitHub Pages can serve it at:

```text
https://sudo0x.github.io/helm-charts/sudo0x-postgres-0.1.0.tgz
```

## Complete repeatable command sequence

From Git Bash:

```bash
cd /d/dancypher

# Check the repository.
git status --short --branch
git log -3 --oneline

# Package the source chart.
helm package charts/postgres --destination dist

# Rebuild the shared Helm repository index.
helm repo index dist \
  --url https://sudo0x.github.io/helm-charts

# Publish the package and index through GitHub Pages.
cp dist/*.tgz docs/
cp dist/index.yaml docs/index.yaml

# Review the exact files to publish.
git status --short --untracked-files=all
git diff -- docs/index.yaml

# Stage only the PostgreSQL publication files.
git add docs/index.yaml docs/sudo0x-postgres-0.1.0.tgz

# Review staged files.
git diff --cached --stat
git diff --cached --name-only

# Commit and push.
git commit -m "Publish sudo0x PostgreSQL Helm chart 0.1.0"
git push

# Verify GitHub Pages.
curl -I https://sudo0x.github.io/helm-charts/index.yaml

# Refresh and search locally.
helm repo update
helm search repo sudo0x
```

## Publishing a future version

When the PostgreSQL chart changes:

1. Edit `charts/postgres/`.
2. Increase `version` in `charts/postgres/Chart.yaml`.
3. Run `helm lint`.
4. Run `helm template`.
5. Package the new version.
6. Regenerate `dist/index.yaml`.
7. Copy the new package and index into `docs`.
8. Review the staged files.
9. Commit and push.

Example:

```yaml
version: 0.1.1
```

Then:

```bash
helm lint charts/postgres
helm template postgres charts/postgres -n infrastructure
helm package charts/postgres --destination dist
helm repo index dist --url https://sudo0x.github.io/helm-charts
cp dist/*.tgz docs/
cp dist/index.yaml docs/index.yaml
git add docs/index.yaml docs/sudo0x-postgres-0.1.1.tgz
git commit -m "Publish sudo0x PostgreSQL Helm chart 0.1.1"
git push
```

Do not reuse a chart version for different package content.

