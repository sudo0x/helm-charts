# Redis Helm Chart: From-Scratch Guide

This is a repeatable beginner-friendly guide for building, validating, publishing, and installing the `sudo0x-redis` Helm chart.

Use it as a checklist when returning to the project after a break. Follow the steps in order instead of running random commands.

## 1. Understand the project

The project has four important directories:

```text
D:\dancypher\
├── charts\redis\   # Helm chart source code
├── docs\           # Published Helm repository files
├── dist\           # Temporary/local package output
└── notes\          # Learning and maintenance documentation
```

Use each directory for one purpose:

| Directory | Purpose |
|---|---|
| `charts/redis` | Edit the Helm chart here |
| `docs` | GitHub Pages publishes `index.yaml` and `.tgz` files from here |
| `dist` | Local output generated while packaging the chart |
| `notes` | Personal instructions and learning notes |

The source chart is not the same thing as the published Helm repository:

```text
Chart source: https://github.com/sudo0x/helm-charts/tree/master/charts/redis
Helm repository: https://sudo0x.github.io/helm-charts
```

## 2. Open Git Bash and go to the project

Use Git Bash, not a random directory:

```bash
cd /d/dancypher
pwd
```

The output should end with:

```text
/d/dancypher
```

Check the project:

```bash
ls
ls charts/redis
```

You should see files such as:

```text
Chart.yaml
README.md
values.yaml
templates/
```

## 3. Check the tools

Run:

```bash
git --version
helm version
kubectl version --client
```

You need:

- Git for source control and GitHub publishing.
- Helm for chart linting, rendering, packaging, and installation.
- kubectl for inspecting Kubernetes resources.

If you only want to build and publish the chart, a Kubernetes cluster is not required. A cluster is required for installation and runtime checks.

## 4. Understand the chart files

The chart source is under:

```text
charts/redis/
```

Important files:

| File | Responsibility |
|---|---|
| `Chart.yaml` | Chart name and versions |
| `values.yaml` | User-configurable defaults |
| `templates/_helpers.tpl` | Reusable names and labels |
| `templates/configmap.yaml` | Redis configuration |
| `templates/secret.yaml` | Optional password Secret |
| `templates/service.yaml` | Internal Kubernetes Service |
| `templates/statefulset.yaml` | Redis pod, storage, probes, and security |
| `README.md` | Chart-specific documentation |

The current chart identity is:

```yaml
name: sudo0x-redis
version: 0.2.0
appVersion: "8.2"
```

The chart deploys one Redis instance by default. It is not a Redis HA solution.

## 5. Make a chart change safely

First inspect the current Git state:

```bash
git status
```

Only edit files under:

```text
charts/redis/
```

Do not edit the `.tgz` package directly. The package is generated from the source chart.

If the change affects chart behavior, increase the chart version in `Chart.yaml`. For example:

```yaml
version: 0.2.1
```

Use a new chart version for every published chart change. Do not reuse an old version for different content.

`version` means the Helm chart version.

`appVersion` means the Redis application/image version.

## 6. Validate before packaging

Run these commands from the repository root:

```bash
helm lint charts/redis
```

Render the default chart:

```bash
helm template redis charts/redis -n infrastructure
```

The rendered output should include:

- Secret
- ConfigMap
- Service
- StatefulSet
- PersistentVolumeClaim template
- Redis port `6379`
- Password environment variable
- Authenticated probes
- `/data` volume mount
- Redis configuration mount

Render existing-Secret mode:

```bash
helm template redis charts/redis -n infrastructure \
  --set auth.existingSecret=my-redis-secret
```

In this output, the chart should reference `my-redis-secret` and should not generate another Secret.

Render disabled-auth and disabled-persistence mode:

```bash
helm template redis charts/redis -n infrastructure \
  --set auth.enabled=false \
  --set persistence.enabled=false
```

In this output:

- No password Secret should be created.
- No `REDIS_PASSWORD` environment variable should be used.
- Probes should run without authentication.
- `emptyDir` should be used instead of a PVC template.

If linting or rendering fails, fix the source chart before packaging.

## 7. Install into Kubernetes

Install or upgrade the local chart:

```bash
helm upgrade --install redis ./charts/redis \
  --namespace infrastructure \
  --create-namespace
```

Check the Helm release:

```bash
helm list --namespace infrastructure
helm status redis --namespace infrastructure
```

Check the Kubernetes resources:

```bash
kubectl get statefulset,service,secret,configmap,pvc \
  --namespace infrastructure
```

Check the pod:

```bash
kubectl get pods \
  --namespace infrastructure \
  -l app.kubernetes.io/instance=redis
```

View logs:

```bash
kubectl logs \
  --namespace infrastructure \
  -l app.kubernetes.io/instance=redis
```

If the pod is not ready:

```bash
kubectl describe pod \
  --namespace infrastructure \
  -l app.kubernetes.io/instance=redis
```

## 8. Create an existing password Secret

The safer reusable approach is to create the password Secret separately:

```bash
kubectl create secret generic my-redis-secret \
  --from-literal=redis-password='replace-this-password' \
  --namespace infrastructure
```

Install the chart using it:

```bash
helm upgrade --install redis ./charts/redis \
  --namespace infrastructure \
  --set auth.enabled=true \
  --set auth.existingSecret=my-redis-secret \
  --set auth.existingSecretKey=redis-password
```

The Secret must exist in the same namespace as the Helm release.

Do not commit real passwords into:

- `values.yaml`
- Markdown files
- Git history
- Public GitHub repositories

The default password `change-me` is only a placeholder and should not be used for a real deployment.

## 9. Package the chart

Go back to the repository root:

```bash
cd /d/dancypher
```

Create the local output directory if it does not exist:

```bash
mkdir -p dist
```

Package the chart:

```bash
helm package charts/redis --destination dist
```

You should get a file such as:

```text
dist/sudo0x-redis-0.2.1.tgz
```

The `.tgz` extension is correct. It is the compressed Helm chart package.

## 10. Generate the Helm repository index

Generate `index.yaml` next to the package:

```bash
helm repo index dist \
  --url https://sudo0x.github.io/helm-charts
```

Check the files:

```bash
ls dist
```

Expected:

```text
index.yaml
sudo0x-redis-0.2.1.tgz
```

Inspect the index:

```bash
cat dist/index.yaml
```

The index contains chart version metadata and the public URL where Helm downloads the package.

## 11. Publish through GitHub Pages

GitHub Pages currently publishes the `docs` directory from the `master` branch.

Copy the generated files into `docs`:

```bash
cp dist/*.tgz docs/
cp dist/index.yaml docs/
```

Check the publish directory:

```bash
ls docs
```

Expected:

```text
index.yaml
sudo0x-redis-0.2.1.tgz
```

The published Helm repository URL is:

```text
https://sudo0x.github.io/helm-charts
```

Helm reads:

```text
https://sudo0x.github.io/helm-charts/index.yaml
```

The `docs` directory must contain `index.yaml` and the package files because GitHub Pages serves that directory.

## 12. Commit and push to GitHub

Review changes before staging:

```bash
git status
git diff -- charts/redis
```

Stage the source chart and published repository:

```bash
git add charts/redis docs
```

Review what will be committed:

```bash
git diff --cached --stat
git diff --cached --name-only
```

Commit:

```bash
git commit -m "Publish sudo0x Redis Helm chart 0.2.1"
```

Push:

```bash
git push
```

Confirm the branch is synchronized:

```bash
git status
```

Expected:

```text
Your branch is up to date with 'origin/master'.
```

## 13. Test the published Helm repository

Wait for GitHub Pages to finish deploying, then test:

```bash
curl -I https://sudo0x.github.io/helm-charts/index.yaml
```

A successful result should contain:

```text
HTTP/1.1 200 OK
```

Add the repository:

```bash
helm repo add sudo0x https://sudo0x.github.io/helm-charts
```

If it already exists, update it:

```bash
helm repo update
```

Search:

```bash
helm search repo sudo0x
```

You should see a chart similar to:

```text
sudo0x/sudo0x-redis
```

Install from the published repository:

```bash
helm upgrade --install redis sudo0x/sudo0x-redis \
  --namespace infrastructure \
  --create-namespace
```

Install a specific version:

```bash
helm upgrade --install redis sudo0x/sudo0x-redis \
  --version 0.2.1 \
  --namespace infrastructure \
  --create-namespace
```

## 14. Uninstalling Redis safely

Remove the Helm release:

```bash
helm uninstall redis --namespace infrastructure
```

When persistence is enabled, Helm removes the release resources but the StatefulSet PVC normally remains:

```text
StatefulSet deleted
Service deleted
ConfigMap deleted
Secret deleted
PVC remains
Redis data remains
```

Check the PVC:

```bash
kubectl get pvc --namespace infrastructure
```

Do not delete the PVC if you may reinstall Redis and need the existing data.

To intentionally delete the Redis data:

```bash
kubectl delete pvc <redis-pvc-name> --namespace infrastructure
```

This may also delete the backing storage, depending on the StorageClass reclaim policy. Verify the PVC name before running the command.

When persistence is disabled, the chart uses `emptyDir`, and the data disappears when the pod is deleted.

## 15. GitHub SSH authentication

This repository uses the SSH host alias `github.com-sudo0x`.

Test it:

```bash
ssh -T git@github.com-sudo0x
```

This message means authentication worked:

```text
Hi sudo0x! You've successfully authenticated, but GitHub does not provide shell access.
```

The command can return exit code `1`; that is normal because GitHub does not provide an interactive shell.

Check the remote:

```bash
git remote -v
```

It should use:

```text
git@github.com-sudo0x:sudo0x/helm-charts.git
```

If it incorrectly uses plain `github.com`, fix it:

```bash
git remote set-url origin \
  git@github.com-sudo0x:sudo0x/helm-charts.git
```

Then push again:

```bash
git push
```

## 16. Troubleshooting

### `helm repo add` returns `404 Not Found`

Check:

```bash
curl -I https://sudo0x.github.io/helm-charts/index.yaml
```

If it returns `404`:

1. Confirm `docs/index.yaml` exists.
2. Confirm it was committed and pushed.
3. Open repository **Settings → Pages**.
4. Confirm the source is branch `master`, folder `/docs`.
5. Wait for the Pages deployment to finish.

### `helm repo add` says the repository is invalid

Run:

```bash
helm repo update
helm search repo sudo0x
```

Confirm the index is valid:

```bash
cat docs/index.yaml
```

### Package is not listed

Check that the package version in `Chart.yaml` is new:

```bash
grep '^version:' charts/redis/Chart.yaml
```

Then package again:

```bash
rm -f dist/*.tgz dist/index.yaml
helm package charts/redis --destination dist
helm repo index dist --url https://sudo0x.github.io/helm-charts
cp dist/*.tgz docs/
cp dist/index.yaml docs/
```

Commit and push:

```bash
git add charts/redis docs
git commit -m "Publish updated sudo0x Redis Helm chart"
git push
```

### Git push returns `Permission denied (publickey)`

Test:

```bash
ssh -T git@github.com-sudo0x
```

If authentication succeeds, check the remote:

```bash
git remote -v
```

Use the alias-based remote:

```bash
git remote set-url origin \
  git@github.com-sudo0x:sudo0x/helm-charts.git
```

### PVC is pending

Check:

```bash
kubectl get storageclass
kubectl get pvc --namespace infrastructure
kubectl describe pvc --namespace infrastructure
```

Set a valid StorageClass in the Helm values if the cluster has no suitable default:

```yaml
persistence:
  storageClass: your-storage-class
```

### Redis pod is not ready

Inspect:

```bash
kubectl get pods --namespace infrastructure
kubectl describe pod --namespace infrastructure -l app.kubernetes.io/instance=redis
kubectl logs --namespace infrastructure -l app.kubernetes.io/instance=redis
```

Common causes:

- Existing Secret does not exist.
- Existing Secret key is wrong.
- PVC cannot be provisioned.
- Image cannot be pulled.
- Cluster security policy rejects the configured UID/GID.

## 17. The short version

When you return tomorrow, use this sequence:

```bash
cd /d/dancypher

# 1. Edit the source chart.
#    Source: charts/redis/

# 2. Increase version in charts/redis/Chart.yaml.

# 3. Validate.
helm lint charts/redis
helm template redis charts/redis -n infrastructure

# 4. Package.
rm -f dist/*.tgz dist/index.yaml
helm package charts/redis --destination dist
helm repo index dist --url https://sudo0x.github.io/helm-charts

# 5. Publish files for GitHub Pages.
cp dist/*.tgz docs/
cp dist/index.yaml docs/

# 6. Review and push.
git status
git add charts/redis docs
git commit -m "Publish sudo0x Redis Helm chart"
git push

# 7. Verify the public repository.
curl -I https://sudo0x.github.io/helm-charts/index.yaml
helm repo update
helm search repo sudo0x
```

Remember:

```text
Edit:     charts/redis/
Publish:  docs/
Build:    dist/
Learn:    notes/
```
