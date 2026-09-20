# PostgreSQL Helm Chart Guidance

This directory contains a simple PostgreSQL Helm chart for development and learning.

It is intentionally separate from the Redis chart:

```text
charts/redis/
charts/postgres/
```

Do not add PostgreSQL templates or configuration inside `charts/redis/`.

## Short answer

PostgreSQL is an infrastructure service like Redis, but it is usually more critical because it is the primary source of truth for application data.

This chart is intentionally single-instance. It is not a production HA PostgreSQL platform.

For production, do not assume that a simple one-pod PostgreSQL StatefulSet provides a production database platform.

Prefer one of:

- Managed PostgreSQL from a cloud provider.
- A PostgreSQL operator such as CloudNativePG.
- A well-established PostgreSQL Helm chart.

## Redis versus PostgreSQL

| Redis | PostgreSQL |
|---|---|
| Often used as a cache, session store, queue, or fast data store | Usually the primary database and source of truth |
| Actively serves data primarily from RAM | Actively reads and writes durable data on disk |
| Uses AOF or RDB persistence options | Uses database files, WAL, checkpoints, and durable storage |
| A single-instance chart can be reasonable for simple internal use | A single-instance chart has serious availability and recovery limits |
| Usually simpler to operate | Requires more maintenance and operational planning |

Redis normally serves active data from RAM:

```text
Active Redis data: RAM
Persistence files: PVC
Restart recovery: disk to RAM
```

PostgreSQL uses both memory and disk:

```text
Active working data: memory buffers and operating system cache
Database data: persistent disk
Write-ahead log: persistent disk
Query execution: memory plus disk as needed
```

PostgreSQL is not primarily an in-memory database. Persistent storage is fundamental to its normal operation.

## Should you create a PostgreSQL chart?

### A custom chart is reasonable for learning when:

- You want to understand PostgreSQL StatefulSets.
- You want to learn PVC and Secret configuration.
- You are using it for development or testing.
- Data loss is acceptable.
- You explicitly understand that it is not HA.

### A custom simple chart is not enough for production when:

- PostgreSQL contains critical business data.
- Downtime is unacceptable.
- Automatic failover is required.
- Point-in-time recovery is required.
- Cross-zone resilience is required.
- Backups and restore must be automated.
- Upgrades must be managed with minimal risk.

For those requirements, use managed PostgreSQL or a PostgreSQL operator.

## Repository layout

The charts can remain in the same GitHub repository while staying independent:

```text
helm-charts/
├── charts/
│   ├── redis/
│   ├── postgres/
│   └── spring-boot-service/
├── docs/
├── dist/
└── notes/
```

The shared Helm repository remains:

```text
https://sudo0x.github.io/helm-charts
```

Each chart has its own files, values, templates, version, and README.

## Basic PostgreSQL chart design

A simple learning or development chart could provide:

- StatefulSet.
- PersistentVolumeClaim.
- ClusterIP Service.
- Existing Secret support.
- Database name configuration.
- Username and password configuration.
- Readiness and liveness probes.
- Resource requests and limits.
- Security context support.
- Graceful termination.
- Configurable PostgreSQL image version.

Example values:

```yaml
image:
  repository: postgres
  tag: "16"
  pullPolicy: IfNotPresent

auth:
  existingSecret: postgres-credentials
  usernameKey: username
  passwordKey: password
  database: appdb

persistence:
  enabled: true
  size: 20Gi
  storageClass: ""

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: "1"
    memory: 1Gi
```

The exact image tag and security settings must be checked against the selected PostgreSQL image. Do not blindly copy Redis UID/GID settings to PostgreSQL.

## PostgreSQL security

Do not commit real credentials into:

- `values.yaml`.
- ConfigMaps.
- Markdown notes.
- Git history.
- Public repositories.

Use an existing Kubernetes Secret:

```bash
kubectl create secret generic postgres-credentials \
  --from-literal=username=appuser \
  --from-literal=password='REPLACE_WITH_A_REAL_SECRET' \
  --namespace infrastructure
```

The chart should reference the Secret rather than printing the password in rendered ConfigMaps or normal values.

Keep PostgreSQL internal by default:

```yaml
service:
  type: ClusterIP
```

Do not expose PostgreSQL through a public LoadBalancer or NodePort without a specific network and security design.

## Persistence and backup

PostgreSQL requires persistent storage for meaningful use:

```yaml
persistence:
  enabled: true
```

A PVC protects against some pod replacement events, but it is not a backup.

Production PostgreSQL also needs:

- Logical or physical backups.
- Point-in-time recovery planning.
- Restore testing.
- Backup retention.
- Encrypted backup storage.
- Storage monitoring.
- A documented recovery owner.

Never test destructive PVC deletion against production PostgreSQL data.

## High availability warning

Do not use this as an HA configuration:

```yaml
replicaCount: 3
```

Multiple StatefulSet pods do not automatically configure:

- PostgreSQL replication.
- Synchronous replication.
- Automatic failover.
- Leader election.
- Read replicas.
- Promotion.
- Connection routing.

HA PostgreSQL requires a deliberate architecture, such as a managed service or an operator.

## Operational concerns

PostgreSQL production operations require more than deploying a pod:

- Version upgrades.
- Extension management.
- Schema migrations.
- Connection limits.
- Connection pooling.
- Vacuum behavior.
- Autovacuum tuning.
- WAL growth.
- Checkpoint behavior.
- Disk capacity.
- Slow queries.
- Locks and deadlocks.
- Replication lag, if replicas exist.
- Backup and restore.

This operational scope is why a managed service or operator is usually preferable for production.

## Recommended decision path

1. Finish and harden the Redis chart.
2. Create the generic Spring Boot service chart.
3. Use managed PostgreSQL or an operator for production.
4. Use this chart only for development or learning unless its operational gaps are deliberately addressed.
5. If creating a custom PostgreSQL chart, document clearly that it is single-instance and not HA.

## Chart structure

The implemented chart is:

```text
charts/postgres/
├── Chart.yaml
├── values.yaml
├── README.md
└── templates/
    ├── _helpers.tpl
    ├── statefulset.yaml
    ├── service.yaml
    └── secret.yaml
```

The chart currently provides:

- PostgreSQL `16` using the official image.
- One StatefulSet replica.
- ClusterIP Service on port `5432`.
- Chart-managed or existing Secret credentials.
- PVC-backed storage by default.
- `emptyDir` when persistence is disabled.
- `pg_isready` liveness and readiness probes.
- Resource requests and limits.
- Non-root security context.
- Graceful termination period.

Authentication is enabled by default. When `auth.existingSecret` is empty, the chart creates a development Secret from `auth.username` and `auth.password`. For real environments, use an existing Secret instead.

If `auth.enabled=false`, the chart uses PostgreSQL `trust` authentication. This is for local development only and must not be used for production.

Before using the chart, decide:

- PostgreSQL image version.
- Secret key names.
- Database and username behavior.
- StorageClass.
- PVC size.
- Resource sizing.
- Probe commands.
- Security context compatible with the image.
- Backup method.
- Upgrade process.
- Whether the chart is development-only.

## Validate the chart

Run from the repository root:

```bash
helm lint charts/postgres
helm template postgres charts/postgres -n infrastructure
```

Render existing-Secret mode:

```bash
helm template postgres charts/postgres -n infrastructure \
  --set auth.existingSecret=postgres-credentials \
  --set persistence.enabled=false
```

The existing Secret must contain the configured username and password keys.

## Install for development

Chart-managed credentials can be used for local development:

```bash
helm upgrade --install postgres ./charts/postgres \
  --namespace infrastructure \
  --create-namespace
```

For a real environment, create a Secret first:

```bash
kubectl create secret generic postgres-credentials \
  --from-literal=username=appuser \
  --from-literal=password='REPLACE_WITH_A_REAL_SECRET' \
  --namespace infrastructure
```

Install using it:

```bash
helm upgrade --install postgres ./charts/postgres \
  --namespace infrastructure \
  --set auth.existingSecret=postgres-credentials
```

Check the deployment:

```bash
kubectl get statefulset,service,secret,pvc \
  --namespace infrastructure
kubectl get pods --namespace infrastructure \
  -l app.kubernetes.io/instance=postgres
```

The default database connection address is similar to:

```text
postgres-sudo0x-postgres.infrastructure.svc.cluster.local:5432
```

The exact hostname depends on the Helm release name.

## Final reminder

```text
Redis:
  Usually RAM-first
  PVC supports persistence
  Single-instance chart can be a reasonable internal baseline

PostgreSQL:
  Disk-backed primary database
  PVC is required for meaningful persistence
  Backups and recovery are essential
  Simple StatefulSet is not production HA
```

For production PostgreSQL, the safest default is:

```text
Managed PostgreSQL or PostgreSQL operator
        +
Tested backups and restore
        +
Monitoring and alerting
```
