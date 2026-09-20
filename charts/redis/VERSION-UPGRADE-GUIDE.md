# Redis Helm Chart Version Upgrade Guide

This document explains how to update the Redis image or chart behavior, publish a new Helm chart version, and upgrade safely.

The current chart source is:

```text
charts/redis/
```

The public Helm repository is:

```text
https://sudo0x.github.io/helm-charts
```

## Core rule

When the Redis image or Helm chart changes, publish a new chart package.

Do not overwrite an old `.tgz` package with different content.

The current Redis chart metadata is similar to:

```yaml
name: sudo0x-redis
version: 0.2.0
appVersion: "8.2"
```

The image configuration is:

```yaml
image:
  repository: redis
  tag: "8.2"
```

## Do not use `latest`

Always use a fixed Redis image tag.

Good:

```yaml
image:
  repository: redis
  tag: "8.2.3"
```

Avoid:

```yaml
tag: latest
```

A floating tag can change without a chart source change. Fixed tags make deployments reproducible and rollbacks understandable.

Before using a new tag, confirm that the exact tag exists in the official Redis image registry and test it in a non-production namespace.

## Version fields

The chart has two important version fields:

```yaml
version: 0.3.0
appVersion: "8.2.3"
```

`version` is the Helm chart package version.

`appVersion` identifies the Redis application version.

The image tag in `values.yaml` should match the intended `appVersion`:

```yaml
image:
  tag: "8.2.3"
```

## Example upgrade

Suppose Redis is upgraded from `8.2` to fixed tag `8.2.3`.

### Update `Chart.yaml`

Edit:

```text
charts/redis/Chart.yaml
```

Change:

```yaml
version: 0.2.0
appVersion: "8.2"
```

to:

```yaml
version: 0.3.0
appVersion: "8.2.3"
```

### Update `values.yaml`

Edit:

```text
charts/redis/values.yaml
```

Change:

```yaml
image:
  tag: "8.2"
```

to:

```yaml
image:
  tag: "8.2.3"
```

## Validate the updated chart

From Git Bash:

```bash
cd /d/dancypher
```

Run linting:

```bash
helm lint charts/redis
```

Render the chart:

```bash
helm template redis charts/redis \
  --namespace infrastructure
```

Check the rendered image:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  | grep 'image:'
```

Expected:

```text
image: "redis:8.2.3"
```

Check important resources and settings:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  | grep -E 'kind: (Secret|ConfigMap|Service|StatefulSet)|volumeClaimTemplates|REDIS_PASSWORD'
```

Confirm that the rendered output still contains:

- Secret behavior.
- ConfigMap.
- Service.
- StatefulSet.
- Persistent storage.
- Redis password environment variable.
- Authentication-aware probes.
- `/data` volume mount.
- Redis configuration mount.

## Test in Kubernetes before production

Use a test namespace where possible:

```bash
helm upgrade --install redis charts/redis \
  --namespace infrastructure-test \
  --create-namespace
```

Check the pod:

```bash
kubectl get pods \
  --namespace infrastructure-test \
  -l app.kubernetes.io/instance=redis
```

Check the deployed image:

```bash
kubectl get statefulset \
  --namespace infrastructure-test \
  -l app.kubernetes.io/instance=redis \
  -o jsonpath="{.items[0].spec.template.spec.containers[0].image}"
```

Expected:

```text
redis:8.2.3
```

Check logs:

```bash
kubectl logs \
  --namespace infrastructure-test \
  -l app.kubernetes.io/instance=redis
```

Check readiness:

```bash
kubectl get pods --namespace infrastructure-test
```

Verify that:

- The pod starts successfully.
- The readiness probe passes.
- The liveness probe passes.
- The PVC remains bound.
- Existing Redis data is available if the test uses an existing PVC.

## Package the new chart

Remove old local Redis packages if you want a clean local Redis package output:

```bash
rm -f dist/sudo0x-redis-*.tgz
```

Do not remove PostgreSQL packages if they are needed in the shared repository.

Package Redis:

```bash
helm package charts/redis \
  --destination dist
```

This creates:

```text
dist/sudo0x-redis-0.3.0.tgz
```

## Regenerate the shared Helm index

The Helm repository contains both Redis and PostgreSQL packages. Make sure the packages that should remain published are present in `dist` before generating the index:

```bash
ls dist
```

Example:

```text
index.yaml
sudo0x-postgres-0.1.0.tgz
sudo0x-redis-0.2.0.tgz
sudo0x-redis-0.3.0.tgz
```

Generate the index:

```bash
helm repo index dist \
  --url https://sudo0x.github.io/helm-charts
```

This index includes all packages currently present in `dist`.

## Publish through GitHub Pages

Copy the new Redis package and the regenerated index:

```bash
cp dist/sudo0x-redis-0.3.0.tgz docs/
cp dist/index.yaml docs/index.yaml
```

Keeping the older package allows users to install or roll back to the older version:

```text
docs/sudo0x-redis-0.2.0.tgz
docs/sudo0x-redis-0.3.0.tgz
```

## Review before staging

Check the working tree:

```bash
git status --short
```

Review source changes:

```bash
git diff -- charts/redis/Chart.yaml charts/redis/values.yaml
```

Review the shared index:

```bash
git diff -- docs/index.yaml
```

The index should contain both Redis versions and any other chart packages:

```yaml
entries:
  sudo0x-postgres:
  sudo0x-redis:
```

## Stage only the intended files

Example for Redis version `0.3.0`:

```bash
git add charts/redis/Chart.yaml \
  charts/redis/values.yaml \
  docs/index.yaml \
  docs/sudo0x-redis-0.3.0.tgz
```

Review staged files:

```bash
git diff --cached --stat
git diff --cached --name-only
```

Do not use this when unrelated changes exist:

```bash
git add .
```

Selective staging prevents unrelated files from being included accidentally.

## Commit and push

Create a focused commit:

```bash
git commit -m "Publish Redis chart 0.3.0 for Redis 8.2.3"
```

Push:

```bash
git push
```

Wait for GitHub Pages to deploy before testing the public Helm repository.

## Verify the published version

Check the public index:

```bash
curl -I https://sudo0x.github.io/helm-charts/index.yaml
```

Refresh the local Helm repository:

```bash
helm repo update
```

List all Redis versions:

```bash
helm search repo sudo0x/sudo0x-redis --versions
```

Expected:

```text
sudo0x/sudo0x-redis   0.3.0   8.2.3
sudo0x/sudo0x-redis   0.2.0   8.2
```

Install or upgrade to the new chart version:

```bash
helm upgrade --install redis sudo0x/sudo0x-redis \
  --version 0.3.0 \
  --namespace infrastructure
```

Check the deployed image:

```bash
kubectl get statefulset \
  --namespace infrastructure \
  -o jsonpath="{.items[0].spec.template.spec.containers[0].image}"
```

## Roll back if necessary

Inspect Helm release history:

```bash
helm history redis --namespace infrastructure
```

Roll back to a Helm revision:

```bash
helm rollback redis 1 \
  --namespace infrastructure
```

Or install the previous published chart version:

```bash
helm upgrade --install redis sudo0x/sudo0x-redis \
  --version 0.2.0 \
  --namespace infrastructure
```

An image-only upgrade should not require deleting the PVC. Do not delete the PVC during a rollback unless you intentionally want to delete Redis data.

## Versioning rules

Increment the chart `version` when:

- The Redis image version changes.
- Templates change.
- Default values change.
- Security settings change.
- Probe behavior changes.
- Storage behavior changes.
- Chart behavior documentation changes.

Examples:

| Change | Chart `version` | `appVersion` |
|---|---:|---:|
| Redis image update | `0.3.0` | `8.2.3` |
| Template-only fix | `0.3.1` | `8.2.3` |
| Redis image update again | `0.4.0` | `8.3.0` |

Practical rule:

```text
Chart behavior change: increment chart version
Redis application change: update appVersion and image.tag
```

## Complete repeatable sequence

```bash
cd /d/dancypher

# Edit:
# charts/redis/Chart.yaml
#   version: 0.3.0
#   appVersion: "8.2.3"
#
# charts/redis/values.yaml
#   image.tag: "8.2.3"

helm lint charts/redis

helm template redis charts/redis \
  --namespace infrastructure

rm -f dist/sudo0x-redis-*.tgz

helm package charts/redis \
  --destination dist

helm repo index dist \
  --url https://sudo0x.github.io/helm-charts

cp dist/sudo0x-redis-0.3.0.tgz docs/
cp dist/index.yaml docs/index.yaml

git status --short
git diff -- charts/redis docs/index.yaml

git add charts/redis/Chart.yaml \
  charts/redis/values.yaml \
  docs/index.yaml \
  docs/sudo0x-redis-0.3.0.tgz

git diff --cached --stat

git commit -m "Publish Redis chart 0.3.0 for Redis 8.2.3"
git push

helm repo update
helm search repo sudo0x/sudo0x-redis --versions
```

The version `8.2.3` is an illustrative example. Confirm that the exact Redis image tag exists before using it.

