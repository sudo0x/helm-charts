# PostgreSQL Production on Kubernetes

## Short answer

If you want production PostgreSQL running inside Kubernetes, do not rely on the current simple StatefulSet chart alone.

Use a PostgreSQL operator or a managed PostgreSQL service.

Recommended Kubernetes operators include:

- CloudNativePG.
- Crunchy Postgres for Kubernetes.
- Zalando PostgreSQL Operator.

The current custom chart is useful for development and learning, but it is not a complete production PostgreSQL platform.

## Recommended production architecture

```text
Kubernetes
└── PostgreSQL Operator
    └── PostgreSQL cluster
        ├── Primary instance
        ├── Replica instance or instances
        ├── Automatic failover
        ├── Backups
        ├── Recovery support
        └── Monitoring integration
```

The operator is installed once in the Kubernetes cluster. You then create a PostgreSQL custom resource that describes the desired database cluster.

The operator manages the PostgreSQL pods and supporting resources.

## Why not the current custom chart?

The current chart creates:

```text
One PostgreSQL pod
One StatefulSet
One PVC
One ClusterIP Service
```

Kubernetes does not automatically provide PostgreSQL:

- Replication.
- Failover.
- Primary election.
- Replica promotion.
- Backup scheduling.
- Point-in-time recovery.
- WAL archiving.
- Safe PostgreSQL upgrades.

Changing this value:

```yaml
replicaCount: 3
```

would only create three independent PostgreSQL pods. It would not configure:

- PostgreSQL replication.
- Primary and replica roles.
- Automatic failover.
- Leader election.
- Replica promotion.
- Connection routing.

Never treat a higher StatefulSet replica count as PostgreSQL HA.

## Production options

### Option 1: Managed PostgreSQL

Use a cloud-managed PostgreSQL service when available.

Examples include:

```text
Amazon RDS or Aurora
Google Cloud SQL or AlloyDB
Azure Database for PostgreSQL
```

Your Kubernetes applications connect to the managed database using:

- Hostname.
- Port.
- Database name.
- Username.
- Password stored in a Kubernetes Secret.

Managed PostgreSQL is usually the lowest operational-risk option because the provider handles much of the database infrastructure.

### Option 2: PostgreSQL operator in Kubernetes

Use an operator when PostgreSQL must run inside your Kubernetes cluster.

The operator can manage:

- PostgreSQL instances.
- Replication.
- Failover.
- Backups.
- Recovery.
- Upgrades.
- Storage.
- Monitoring integration.

The workflow becomes:

```text
Install operator once
        ↓
Create a PostgreSQL cluster resource
        ↓
Operator creates and manages PostgreSQL pods
```

You generally do not need to write your own PostgreSQL StatefulSet chart for this architecture.

### Option 3: Current custom chart

Use the current chart only when:

- One instance is acceptable.
- Downtime is acceptable.
- Manual recovery is acceptable.
- The data is not critical.
- Backups and restores have been tested.
- You understand that the chart is not HA.

## Production requirements inside Kubernetes

### Storage

Use:

- Reliable CSI-backed storage.
- An appropriate StorageClass.
- Enough capacity.
- Capacity alerts.
- A storage expansion plan.
- A documented reclaim policy.

The PVC is necessary, but it is not a backup.

### Backups

Production PostgreSQL needs:

- Scheduled backups.
- WAL archiving.
- Off-cluster backup storage.
- Encryption.
- Retention policy.
- Regular restore tests.
- Documented Recovery Point Objective (RPO).
- Documented Recovery Time Objective (RTO).

Do not assume a PVC protects against accidental deletion, storage corruption, or cluster loss.

### High availability

An HA design normally includes:

- At least one replica.
- PostgreSQL replication.
- Automatic failover.
- Primary election.
- Replica promotion.
- Application connection handling.

The operator or managed service should provide the database-specific behavior.

### Security

Use:

- Existing Secret or approved external Secret management.
- No passwords in Git.
- Internal `ClusterIP` access.
- NetworkPolicy.
- TLS where required.
- Restricted database permissions.
- Credential rotation.

Example application Secret reference:

```yaml
env:
  - name: SPRING_DATASOURCE_USERNAME
    valueFrom:
      secretKeyRef:
        name: postgres-production-credentials
        key: username
  - name: SPRING_DATASOURCE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-production-credentials
        key: password
```

### Operations

Monitor and alert on:

- Database availability.
- Disk usage.
- Replication lag.
- Connection count.
- Connection failures.
- Slow queries.
- WAL growth.
- Backup failures.
- Restore failures.
- Pod restarts.
- Operator health.
- Storage errors.

Document:

- Upgrade procedure.
- Rollback limitations.
- Backup restoration.
- Disaster recovery.
- Credential rotation.
- Application connection behavior during failover.

## What should happen to `charts/postgres`?

There are two reasonable choices.

### Keep it as a learning chart

Keep:

```text
charts/postgres/
```

and clearly label it:

```text
Development and learning only
```

Do not use it for important production data without adding and validating the missing operational capabilities.

### Use it for operator guidance

Keep documentation in the directory:

```text
charts/postgres/
├── README.md
├── PRODUCTION-GUIDANCE.md
└── KUBERNETES-PRODUCTION-GUIDANCE.md
```

The production PostgreSQL cluster would be created by the operator’s custom resource, not by the simple StatefulSet templates in this chart.

## Recommended project structure

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

Recommended roles:

```text
charts/redis:
  Single-instance internal Redis

charts/postgres:
  Development chart or PostgreSQL operator guidance

charts/spring-boot-service:
  Reusable Spring Boot application deployment

Production PostgreSQL:
  Managed PostgreSQL or Kubernetes operator
```

## Decision checklist

Use the current custom chart only if all of these are true:

- [ ] One PostgreSQL instance is acceptable.
- [ ] Planned downtime is acceptable.
- [ ] Manual recovery is acceptable.
- [ ] The data is non-critical or recoverable.
- [ ] Backups exist.
- [ ] Restore has been tested.
- [ ] Storage behavior is understood.
- [ ] Monitoring is available.

Use a managed service or operator when any of these are true:

- [ ] Automatic failover is required.
- [ ] PostgreSQL downtime is unacceptable.
- [ ] The database is a critical source of truth.
- [ ] Point-in-time recovery is required.
- [ ] Multiple replicas are required.
- [ ] Cross-zone resilience is required.
- [ ] Database upgrades must be managed automatically.

## Final recommendation

For production PostgreSQL on Kubernetes:

```text
Use a PostgreSQL operator
        +
Persistent storage
        +
Backups and WAL archiving
        +
Restore testing
        +
Monitoring and alerting
        +
Network restrictions
        +
Existing Secrets
```

Do not try to make the current simple chart highly available by only increasing `replicaCount`.

The correct production solution is a managed PostgreSQL service or a PostgreSQL operator.

