# Company Redis Helm Chart

This Helm chart deploys a simple, reusable Redis OSS instance for internal Kubernetes infrastructure and Spring Boot microservices.

The chart intentionally uses a single Redis instance with persistent storage. It does not provide high availability, Redis Sentinel, Redis Cluster, automatic failover, or operator-based management.

## Architecture

The chart creates:

- One Kubernetes `StatefulSet`.
- One Redis container using the official `redis` image.
- One `ClusterIP` Service.
- One ConfigMap containing `redis.conf`.
- One Kubernetes Secret when chart-managed authentication is enabled.
- One PersistentVolumeClaim through the StatefulSet when persistence is enabled.
- Liveness and readiness probes using `redis-cli`.

The default Redis port is `6379`.

## Requirements

- Kubernetes cluster with `StatefulSet`, `Secret`, `ConfigMap`, `Service`, and PVC support.
- Helm 3.
- A default StorageClass, unless `persistence.storageClass` is configured explicitly.
- The official Redis image available to the cluster nodes.

## Default configuration

The default deployment uses:

| Setting | Default |
|---|---|
| Chart name | `sudo0x-redis` |
| Redis image | `redis:8.2` |
| Replicas | `1` |
| Service type | `ClusterIP` |
| Service port | `6379` |
| Authentication | Enabled |
| Persistence | Enabled |
| Persistent size | `10Gi` |
| Redis append-only mode | `yes` |
| Redis maxmemory policy | `noeviction` |
| Redis log level | `notice` |
| Container user/group | `999/999` |

The default password is `change-me`. This should be overridden for real deployments or replaced with an existing Secret.

## Installation

Change to the chart directory:

```powershell
Set-Location D:\dancypher\charts\redis
```

Install the chart using the default values:

```powershell
helm upgrade --install redis . -n infrastructure --create-namespace
```

Check the deployed resources:

```powershell
kubectl get statefulset,service,secret,configmap,pvc -n infrastructure
kubectl get pods -n infrastructure -l app.kubernetes.io/instance=redis
```

## Connecting from a Spring Boot service

The Service name is generated from the Helm release and chart name. With the installation command above, the Service is normally:

```text
redis-sudo0x-redis
```

Within the same Kubernetes namespace, use:

```text
redis-sudo0x-redis:6379
```

For a Spring Boot application deployed in another namespace, use the fully qualified Service DNS name:

```text
redis-sudo0x-redis.infrastructure.svc.cluster.local:6379
```

The application must use the same password configured in the Redis Secret.

Example Spring Boot properties:

```properties
spring.data.redis.host=redis-sudo0x-redis.infrastructure.svc.cluster.local
spring.data.redis.port=6379
spring.data.redis.password=${REDIS_PASSWORD}
```

The application Secret and environment variable are application-specific. This chart only manages the Redis authentication Secret.

## Configuration

The main configuration is in `values.yaml`.

### Image

```yaml
image:
  repository: redis
  tag: "8.2"
  pullPolicy: IfNotPresent
```

Use a fixed Redis version. Do not use `latest` in production.

### Replicas

```yaml
replicaCount: 1
```

The chart supports a configurable replica count because it is a StatefulSet, but this chart is designed and tested as a single-instance Redis deployment. Increasing the replica count does not configure Redis replication, Sentinel, or Cluster mode and must not be treated as an HA configuration.

### Authentication

Authentication is enabled by default:

```yaml
auth:
  enabled: true
  existingSecret: ""
  existingSecretKey: redis-password
  password: "change-me"
```

#### Chart-managed Secret

When authentication is enabled and `auth.existingSecret` is empty, the chart creates a Secret named after the release and chart:

```yaml
auth:
  enabled: true
  existingSecret: ""
  existingSecretKey: redis-password
  password: "replace-this-password"
```

The password is stored using:

```yaml
stringData:
  redis-password: ...
```

The password is not placed in the Redis ConfigMap.

#### Existing Secret

To use a Secret managed outside this chart:

```yaml
auth:
  enabled: true
  existingSecret: redis-credentials
  existingSecretKey: redis-password
```

Create the Secret before installing the chart:

```powershell
kubectl create secret generic redis-credentials `
  --from-literal=redis-password='replace-this-password' `
  -n infrastructure
```

When `auth.existingSecret` is set:

- The chart does not create another Secret.
- The StatefulSet references the specified Secret.
- The key is taken from `auth.existingSecretKey`.

The referenced Secret must exist in the same namespace as the Helm release.

#### Disable authentication

For a non-production development deployment:

```yaml
auth:
  enabled: false
```

In this mode:

- No chart-managed password Secret is created.
- Redis starts without `requirepass`.
- The `REDIS_PASSWORD` environment variable is not configured.
- Probes run without authentication.
- The lifecycle shutdown command does not pass a password.

Redis without authentication should not be exposed outside a trusted network.

### Persistence

Persistence is enabled by default:

```yaml
persistence:
  enabled: true
  storageClass: ""
  accessModes:
    - ReadWriteOnce
  size: 10Gi
```

With persistence enabled, the StatefulSet creates a `volumeClaimTemplate` named `redis-data` and mounts it at:

```text
/data
```

To select a specific StorageClass:

```yaml
persistence:
  enabled: true
  storageClass: fast-ssd
  size: 20Gi
```

To run without a PVC:

```yaml
persistence:
  enabled: false
```

The chart then uses an `emptyDir` volume. All Redis data is lost when the pod is removed or rescheduled.

Disabling persistence is suitable only for temporary development or testing workloads.

### Redis configuration

The chart generates `redis.conf` from:

```yaml
redis:
  appendonly: "yes"
  maxmemoryPolicy: "noeviction"
  loglevel: "notice"
```

The generated configuration is mounted at:

```text
/etc/redis/redis.conf
```

Authentication is deliberately not written to the ConfigMap. When enabled, the password is supplied through the `REDIS_PASSWORD` environment variable and passed to `redis-server` at startup.

### Service

```yaml
service:
  type: ClusterIP
  port: 6379
```

The Service selects pods using the chart's standard name and instance labels. The default `ClusterIP` service is intended for in-cluster clients.

For temporary local access:

```powershell
kubectl port-forward svc/redis-sudo0x-redis 6379:6379 -n infrastructure
```

Do not change the Service to `LoadBalancer` or `NodePort` without reviewing network access and authentication requirements.

### Resources

The default resource settings are:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

Adjust these values based on workload size, key count, command rate, and memory usage. Redis is memory-sensitive, so the memory limit should be selected carefully.

### Security context

The default security settings are:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 999
  runAsGroup: 999
  allowPrivilegeEscalation: false

podSecurityContext:
  fsGroup: 999
```

UID/GID `999` matches the Redis user used by the official Redis image and allows Redis to write its data under `/data`.

### Probes

Probe timing is configurable:

```yaml
livenessProbe:
  initialDelaySeconds: 20
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 6

readinessProbe:
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 6
```

When authentication is enabled, both probes run:

```text
redis-cli -a "$REDIS_PASSWORD" ping
```

When authentication is disabled, they run:

```text
redis-cli ping
```

### Termination behavior

The default termination grace period is:

```yaml
terminationGracePeriodSeconds: 30
```

When authentication is enabled, the container uses Redis shutdown during pod termination:

```text
redis-cli -a "$REDIS_PASSWORD" shutdown nosave
```

## Example production values file

Create a file such as `production-values.yaml`:

```yaml
replicaCount: 1

image:
  repository: redis
  tag: "8.2"
  pullPolicy: IfNotPresent

auth:
  enabled: true
  existingSecret: redis-production-credentials
  existingSecretKey: redis-password

persistence:
  enabled: true
  storageClass: fast-ssd
  accessModes:
    - ReadWriteOnce
  size: 20Gi

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: "1"
    memory: 1Gi

redis:
  appendonly: "yes"
  maxmemoryPolicy: "noeviction"
  loglevel: "notice"
```

Install it with:

```powershell
helm upgrade --install redis . `
  -n infrastructure `
  --create-namespace `
  -f production-values.yaml
```

## Upgrading

Review the rendered manifests before applying an upgrade:

```powershell
helm diff upgrade redis . -n infrastructure -f production-values.yaml
```

If the Helm Diff plugin is not installed, render locally instead:

```powershell
helm template redis . -n infrastructure -f production-values.yaml
```

Apply the upgrade:

```powershell
helm upgrade --install redis . -n infrastructure -f production-values.yaml
```

Changing the image version, Redis configuration, or storage settings can affect existing data and availability. Review StatefulSet and PVC changes carefully before upgrading.

## Validation

Run these commands from the chart directory:

```powershell
helm lint .
helm template redis . -n infrastructure
helm upgrade --install redis . -n infrastructure
```

Render the existing-Secret and non-persistent configuration:

```powershell
helm template redis . -n infrastructure `
  --set auth.existingSecret=redis-credentials `
  --set persistence.enabled=false
```

Render the disabled-auth configuration:

```powershell
helm template redis . -n infrastructure `
  --set auth.enabled=false `
  --set persistence.enabled=false
```

The rendered output should contain:

- A Secret only when authentication is enabled and no existing Secret is specified.
- A ConfigMap containing `redis.conf`.
- A ClusterIP Service selecting the StatefulSet pod.
- A StatefulSet listening on port `6379`.
- A PVC template only when persistence is enabled.
- An `emptyDir` volume only when persistence is disabled.
- An authentication environment variable and authenticated probes only when authentication is enabled.

## Troubleshooting

### Pod is not starting

Inspect the pod and events:

```powershell
kubectl describe pod -n infrastructure -l app.kubernetes.io/instance=redis
kubectl logs -n infrastructure -l app.kubernetes.io/instance=redis
```

Common causes include:

- The requested image tag is unavailable.
- The referenced existing Secret does not exist.
- The existing Secret does not contain `auth.existingSecretKey`.
- The PVC cannot be provisioned.
- The cluster rejects the configured security context.

### PVC remains pending

Check StorageClasses and PVC events:

```powershell
kubectl get storageclass
kubectl get pvc -n infrastructure
kubectl describe pvc -n infrastructure -l app.kubernetes.io/instance=redis
```

Set `persistence.storageClass` to a StorageClass that exists in the target cluster.

### Authentication fails

Confirm which Secret is configured:

```powershell
kubectl get statefulset redis-sudo0x-redis -n infrastructure -o yaml
```

For a chart-managed Secret, retrieve the password only when authorized:

```powershell
kubectl get secret redis-sudo0x-redis -n infrastructure `
  -o jsonpath="{.data.redis-password}" | `
  [System.Convert]::FromBase64String
```

For an existing Secret, verify that the Secret name and key match:

```powershell
kubectl get secret redis-credentials -n infrastructure
```

### Probe failures

Inspect the container logs and probe-related events:

```powershell
kubectl describe pod -n infrastructure -l app.kubernetes.io/instance=redis
kubectl logs -n infrastructure -l app.kubernetes.io/instance=redis
```

Probe authentication follows `auth.enabled`. Do not configure an authenticated application against a Redis release where authentication has been disabled.

## Limitations

This chart is intentionally not an HA Redis solution:

- It deploys one Redis instance by default.
- It does not configure replication.
- It does not provide Sentinel.
- It does not provide Redis Cluster.
- It does not provide automatic failover.
- It does not include backups or disaster recovery.
- It does not manage external Secrets.
- It does not provide automatic memory tuning.

For production workloads that require high availability, automatic failover, or managed backups, use an architecture and operational platform designed for those requirements.

## Chart files

| File | Purpose |
|---|---|
| `Chart.yaml` | Chart metadata and Redis application version |
| `values.yaml` | Documented default configuration |
| `templates/_helpers.tpl` | Reusable names, labels, and Secret helpers |
| `templates/configmap.yaml` | Generates `redis.conf` |
| `templates/secret.yaml` | Optionally creates the Redis password Secret |
| `templates/service.yaml` | Creates the internal Redis Service |
| `templates/statefulset.yaml` | Creates the Redis StatefulSet, probes, volumes, and PVC template |
