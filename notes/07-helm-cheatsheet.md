# Helm Command Cheat Sheet

This is a practical Helm command reference for daily chart development and Kubernetes operations.

The examples use this repository:

```text
D:\dancypher
```

The charts currently include:

```text
charts/redis/
charts/postgres/
charts/spring-boot-service/
```

The examples use Git Bash syntax.

## 1. Basic project navigation

Go to the repository root:

```bash
cd /d/dancypher
```

Check the current directory:

```bash
pwd
```

List files:

```bash
ls
```

List chart files:

```bash
find charts -maxdepth 2 -type f
```

Move into a chart:

```bash
cd charts/redis
```

Return to the repository root:

```bash
cd /d/dancypher
```

## 2. Check Helm installation

Show Helm version:

```bash
helm version
```

Show Helm help:

```bash
helm help
```

Show help for a specific command:

```bash
helm help install
helm help upgrade
helm help template
```

List all Helm commands:

```bash
helm --help
```

## 3. Understand chart structure

A normal application chart contains:

```text
my-chart/
├── Chart.yaml
├── values.yaml
├── README.md
└── templates/
    ├── _helpers.tpl
    └── resource.yaml
```

View chart metadata:

```bash
cat charts/redis/Chart.yaml
```

View default values:

```bash
cat charts/redis/values.yaml
```

List templates:

```bash
find charts/redis/templates -type f
```

## 4. Create a new chart

Create a starter chart:

```bash
helm create charts/example
```

This generates Helm starter files. Review and remove anything that is not needed.

Do not blindly keep every generated template. A clean chart should contain only resources the application actually needs.

## 5. Lint a chart

Lint the Redis chart:

```bash
helm lint charts/redis
```

Lint PostgreSQL:

```bash
helm lint charts/postgres
```

Lint with a custom values file:

```bash
helm lint charts/redis \
  --values environments/development/redis.yaml
```

Lint with an individual override:

```bash
helm lint charts/redis \
  --set image.tag=8.2.3
```

Linting catches many chart structure and template errors before deployment.

## 6. Render templates without installing

Render a chart:

```bash
helm template redis charts/redis \
  --namespace infrastructure
```

Render PostgreSQL:

```bash
helm template postgres charts/postgres \
  --namespace infrastructure
```

Render to a file:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  > /tmp/redis-rendered.yaml
```

Render only a specific template:

```bash
helm template redis charts/redis \
  --show-only templates/statefulset.yaml \
  --namespace infrastructure
```

Render using a values file:

```bash
helm template redis charts/redis \
  --values environments/production/redis.yaml \
  --namespace infrastructure
```

Render using multiple values files:

```bash
helm template redis charts/redis \
  --values values.yaml \
  --values environments/production/redis.yaml \
  --namespace infrastructure
```

The later values file overrides earlier values.

Render with a command-line override:

```bash
helm template redis charts/redis \
  --set image.tag=8.2.3 \
  --namespace infrastructure
```

Set a string explicitly:

```bash
helm template redis charts/redis \
  --set-string image.tag=8.2.3 \
  --namespace infrastructure
```

Set a boolean:

```bash
helm template redis charts/redis \
  --set auth.enabled=false \
  --namespace infrastructure
```

Set persistence off:

```bash
helm template redis charts/redis \
  --set persistence.enabled=false \
  --namespace infrastructure
```

## 7. Inspect rendered output

Search for Kubernetes resource kinds:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  | grep -E '^kind:'
```

Search for an image:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  | grep 'image:'
```

Search for names:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  | grep 'name:'
```

Search for Secret references:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  | grep -E 'kind: Secret|secretKeyRef|existingSecret'
```

Search for storage:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  | grep -E 'volumeClaimTemplates|emptyDir|storage:|mountPath:'
```

Save output for review:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  > /tmp/redis.yaml
```

## 8. Install a chart

Install a local chart:

```bash
helm install redis charts/redis \
  --namespace infrastructure \
  --create-namespace
```

Install PostgreSQL:

```bash
helm install postgres charts/postgres \
  --namespace infrastructure \
  --create-namespace
```

Install with values:

```bash
helm install redis charts/redis \
  --values environments/development/redis.yaml \
  --namespace infrastructure \
  --create-namespace
```

Install with a value override:

```bash
helm install redis charts/redis \
  --set persistence.enabled=false \
  --namespace infrastructure \
  --create-namespace
```

Install and wait for resources:

```bash
helm install redis charts/redis \
  --namespace infrastructure \
  --create-namespace \
  --wait
```

Install with a timeout:

```bash
helm install redis charts/redis \
  --namespace infrastructure \
  --create-namespace \
  --wait \
  --timeout 5m
```

Install and automatically roll back if it fails:

```bash
helm install redis charts/redis \
  --namespace infrastructure \
  --create-namespace \
  --wait \
  --atomic \
  --timeout 5m
```

## 9. Upgrade or install safely

The most common command is:

```bash
helm upgrade --install redis charts/redis \
  --namespace infrastructure \
  --create-namespace
```

Use a values file:

```bash
helm upgrade --install redis charts/redis \
  --values environments/production/redis.yaml \
  --namespace infrastructure \
  --create-namespace
```

Use a chart version from a Helm repository:

```bash
helm upgrade --install redis sudo0x/sudo0x-redis \
  --version 0.2.0 \
  --namespace infrastructure \
  --create-namespace
```

Wait for readiness:

```bash
helm upgrade --install redis charts/redis \
  --namespace infrastructure \
  --create-namespace \
  --wait \
  --timeout 5m
```

Use atomic upgrade behavior:

```bash
helm upgrade --install redis charts/redis \
  --namespace infrastructure \
  --create-namespace \
  --wait \
  --atomic \
  --timeout 5m
```

Reuse existing values during upgrade:

```bash
helm upgrade redis charts/redis \
  --reuse-values \
  --namespace infrastructure
```

Be careful with `--reuse-values` because old values can hide changes in the new chart defaults.

Force resource recreation only when necessary:

```bash
helm upgrade redis charts/redis \
  --force \
  --namespace infrastructure
```

Use `--force` cautiously because it can recreate resources and cause disruption.

## 10. List Helm releases

List releases in the current namespace:

```bash
helm list
```

List releases in a namespace:

```bash
helm list --namespace infrastructure
```

List releases in all namespaces:

```bash
helm list --all-namespaces
```

List releases including failed and uninstalled releases:

```bash
helm list \
  --namespace infrastructure \
  --all
```

## 11. Inspect a release

Show release status:

```bash
helm status redis \
  --namespace infrastructure
```

Show release history:

```bash
helm history redis \
  --namespace infrastructure
```

Show the values used by a release:

```bash
helm get values redis \
  --namespace infrastructure
```

Show all computed values:

```bash
helm get values redis \
  --all \
  --namespace infrastructure
```

Show the rendered manifest:

```bash
helm get manifest redis \
  --namespace infrastructure
```

Show release notes:

```bash
helm get notes redis \
  --namespace infrastructure
```

Show all release information:

```bash
helm get all redis \
  --namespace infrastructure
```

## 12. Uninstall a release

Uninstall Redis:

```bash
helm uninstall redis \
  --namespace infrastructure
```

Uninstall PostgreSQL:

```bash
helm uninstall postgres \
  --namespace infrastructure
```

Important: a StatefulSet PVC commonly remains after uninstall. Check it:

```bash
kubectl get pvc \
  --namespace infrastructure
```

Deleting a PVC may delete the underlying storage depending on the StorageClass reclaim policy:

```bash
kubectl delete pvc <pvc-name> \
  --namespace infrastructure
```

Treat PVC deletion as destructive.

## 13. Roll back a release

Show release history:

```bash
helm history redis \
  --namespace infrastructure
```

Roll back to a revision:

```bash
helm rollback redis 1 \
  --namespace infrastructure
```

Roll back and wait:

```bash
helm rollback redis 1 \
  --namespace infrastructure \
  --wait \
  --timeout 5m
```

Roll back atomically:

```bash
helm rollback redis 1 \
  --namespace infrastructure \
  --wait \
  --atomic \
  --timeout 5m
```

## 14. Add and manage chart repositories

Add your Helm repository:

```bash
helm repo add sudo0x \
  https://sudo0x.github.io/helm-charts
```

List repositories:

```bash
helm repo list
```

Update repository indexes:

```bash
helm repo update
```

Remove a repository:

```bash
helm repo remove sudo0x
```

Search all charts from a repository:

```bash
helm search repo sudo0x
```

Search all versions:

```bash
helm search repo sudo0x/sudo0x-redis \
  --versions
```

Show chart information:

```bash
helm show chart sudo0x/sudo0x-redis
```

Show default values:

```bash
helm show values sudo0x/sudo0x-redis
```

Show the chart README:

```bash
helm show readme sudo0x/sudo0x-redis
```

Show all chart metadata, values, and files:

```bash
helm show all sudo0x/sudo0x-redis
```

## 15. Package and publish a chart

Package Redis:

```bash
helm package charts/redis \
  --destination dist
```

Package PostgreSQL:

```bash
helm package charts/postgres \
  --destination dist
```

Generate a repository index:

```bash
helm repo index dist \
  --url https://sudo0x.github.io/helm-charts
```

Copy packages to GitHub Pages:

```bash
cp dist/*.tgz docs/
cp dist/index.yaml docs/index.yaml
```

Review:

```bash
git status
git diff -- docs/index.yaml
```

Stage only intended files:

```bash
git add docs/index.yaml docs/sudo0x-redis-0.3.0.tgz
```

Commit and push:

```bash
git commit -m "Publish Redis Helm chart"
git push
```

## 16. Dependency commands

Update chart dependencies:

```bash
helm dependency update charts/my-chart
```

Build dependencies from `Chart.lock`:

```bash
helm dependency build charts/my-chart
```

List dependencies:

```bash
helm dependency list charts/my-chart
```

Package charts with dependencies:

```bash
helm package charts/my-chart
```

Avoid adding dependencies unless they are required. Keep Redis, PostgreSQL, and application charts independently deployable.

## 17. Kubernetes inspection commands

List pods:

```bash
kubectl get pods --namespace infrastructure
```

List common resources:

```bash
kubectl get statefulset,deploy,service,secret,configmap,pvc \
  --namespace infrastructure
```

Describe a pod:

```bash
kubectl describe pod <pod-name> \
  --namespace infrastructure
```

Show pod logs:

```bash
kubectl logs <pod-name> \
  --namespace infrastructure
```

Follow logs:

```bash
kubectl logs -f <pod-name> \
  --namespace infrastructure
```

Show logs from a label selector:

```bash
kubectl logs \
  -l app.kubernetes.io/instance=redis \
  --namespace infrastructure
```

Show recent events:

```bash
kubectl get events \
  --namespace infrastructure \
  --sort-by=.lastTimestamp
```

Show a StatefulSet image:

```bash
kubectl get statefulset redis-sudo0x-redis \
  --namespace infrastructure \
  -o jsonpath="{.spec.template.spec.containers[0].image}"
```

Show a Deployment image:

```bash
kubectl get deployment <deployment-name> \
  --namespace applications \
  -o jsonpath="{.spec.template.spec.containers[0].image}"
```

Port-forward a Service:

```bash
kubectl port-forward service/redis-sudo0x-redis \
  6379:6379 \
  --namespace infrastructure
```

## 18. Common Helm workflows

### Validate before deploying

```bash
helm lint charts/redis
helm template redis charts/redis -n infrastructure
```

### Preview an upgrade

If Helm Diff is installed:

```bash
helm diff upgrade redis charts/redis \
  --namespace infrastructure
```

Without Helm Diff:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  > /tmp/redis-new.yaml
```

### Safe deployment

```bash
helm upgrade --install redis charts/redis \
  --namespace infrastructure \
  --create-namespace \
  --wait \
  --atomic \
  --timeout 5m
```

### Check after deployment

```bash
helm status redis -n infrastructure
kubectl get pods -n infrastructure
kubectl get events -n infrastructure --sort-by=.lastTimestamp
```

### Upgrade an image

```bash
helm upgrade --install redis charts/redis \
  --namespace infrastructure \
  --set image.tag=8.2.3 \
  --wait \
  --atomic \
  --timeout 5m
```

### Test a disabled feature

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  --set persistence.enabled=false
```

## 19. Secrets and sensitive values

Do not put production passwords directly in shell commands when shell history or process visibility is a concern.

Prefer an existing Secret:

```bash
kubectl create secret generic redis-production-credentials \
  --from-literal=redis-password='REPLACE_WITH_A_REAL_SECRET' \
  --namespace infrastructure
```

Use it:

```bash
helm upgrade --install redis charts/redis \
  --namespace infrastructure \
  --set auth.existingSecret=redis-production-credentials
```

Do not print Secrets casually:

```bash
kubectl get secret <secret-name> \
  --namespace infrastructure \
  -o yaml
```

Remember that Kubernetes Secret values are base64-encoded, not automatically encrypted in every access path. Use the cluster's approved Secret management and encryption controls.

## 20. Debugging template errors

Run Helm with debug output:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  --debug
```

Render one template:

```bash
helm template redis charts/redis \
  --show-only templates/statefulset.yaml \
  --namespace infrastructure \
  --debug
```

Validate Kubernetes API objects with server-side dry run:

```bash
helm upgrade --install redis charts/redis \
  --namespace infrastructure \
  --create-namespace \
  --dry-run=server \
  --debug
```

Render without contacting Kubernetes:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  --debug
```

`helm lint` and `helm template` are useful but do not replace testing against the target Kubernetes API.

## 21. Dry-run commands

Client-side install dry run:

```bash
helm install redis charts/redis \
  --namespace infrastructure \
  --dry-run \
  --debug
```

Server-side upgrade dry run:

```bash
helm upgrade --install redis charts/redis \
  --namespace infrastructure \
  --create-namespace \
  --dry-run=server \
  --debug
```

Server-side dry runs require access to the Kubernetes cluster.

## 22. Useful release naming rules

Use a stable release name:

```bash
helm upgrade --install redis charts/redis
```

The release name becomes part of generated resource names.

Avoid changing the release name unnecessarily:

```text
redis
redis-dev
redis-production
```

Changing the release name can create a new StatefulSet and a different PVC instead of upgrading the existing release.

## 23. Values precedence

Helm generally applies values in this order:

```text
Chart defaults
    ↓
First values file
    ↓
Later values file
    ↓
--set or --set-string
```

Example:

```bash
helm upgrade --install redis charts/redis \
  --values values.yaml \
  --values environments/production/redis.yaml \
  --set image.tag=8.2.3 \
  --namespace infrastructure
```

The final `--set` value has the highest precedence.

## 24. Most important daily commands

If you remember only a few commands, remember these:

```bash
# Validate.
helm lint charts/redis

# Render.
helm template redis charts/redis -n infrastructure

# Install or upgrade.
helm upgrade --install redis charts/redis \
  -n infrastructure \
  --create-namespace

# Check release.
helm status redis -n infrastructure

# Check pods.
kubectl get pods -n infrastructure

# Read logs.
kubectl logs -n infrastructure -l app.kubernetes.io/instance=redis

# View history.
helm history redis -n infrastructure

# Roll back.
helm rollback redis <revision> -n infrastructure

# Uninstall.
helm uninstall redis -n infrastructure
```

## 25. Recommended deployment pattern

For normal development and production deployments:

```bash
cd /d/dancypher

helm lint charts/redis
helm template redis charts/redis -n infrastructure

helm upgrade --install redis charts/redis \
  --namespace infrastructure \
  --create-namespace \
  --wait \
  --atomic \
  --timeout 5m

helm status redis --namespace infrastructure
kubectl get pods --namespace infrastructure
```

Use an existing Secret and a production values file for real environments.

## 26. Important cautions

- Do not use `latest` for production images.
- Do not use `git add .` when unrelated files are modified.
- Do not delete PVCs casually.
- Do not assume `replicaCount: 3` creates HA.
- Do not put real passwords in Git.
- Do not use `auth.enabled=false` in production without a deliberate security design.
- Do not change a StatefulSet release name casually.
- Do not reuse a chart version for different package content.
- Do not treat a PVC as a backup.
- Do not treat `helm lint` as a full production test.

