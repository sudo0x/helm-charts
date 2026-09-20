# PostgreSQL Production Guidance

## Short answer

Usually, a simple custom PostgreSQL Helm chart like this one should **not** be the default choice for serious production workloads.

This chart is appropriate for:

- Local development.
- Testing.
- Internal non-critical environments.
- Learning Kubernetes StatefulSets and PVCs.
- Small workloads where downtime and manual recovery are acceptable.

It is not a complete production PostgreSQL platform.

## What the current chart provides

The current chart provides:

```text
One PostgreSQL pod
One StatefulSet
One PVC by default
One ClusterIP Service
Password Secret support
Basic liveness and readiness probes
Resource requests and limits
```

This is persistent single-instance PostgreSQL. It is not an automatically highly available database.

## What the current chart does not provide

The chart does not provide:

- PostgreSQL replication.
- Automatic failover.
- Read replicas.
- Point-in-time recovery.
- Automated backups.
- Backup validation.
- WAL archiving.
- Automated upgrades.
- Connection pooling.
- Monitoring and alerting.
- Cross-zone availability.
- Disaster recovery.
- Leader election.
- Safe schema migration management.

A PVC protects against some pod replacement events, but it is not a backup.

## Production best-practice options

### Option 1: Managed PostgreSQL

Managed PostgreSQL is usually the best option when available.

Examples include:

- Amazon RDS or Aurora.
- Google Cloud SQL or AlloyDB.
- Azure Database for PostgreSQL.
- Other managed PostgreSQL providers.

The provider commonly handles much of:

- Backups.
- Replication.
- Patching.
- Failover.
- Monitoring.
- Storage management.
- Recovery workflows.

Your Spring Boot services connect to the managed database through its endpoint and credentials.

### Option 2: PostgreSQL operator

If PostgreSQL must run inside Kubernetes, use a PostgreSQL operator such as:

- CloudNativePG.
- Crunchy Postgres for Kubernetes.
- Zalando PostgreSQL Operator.

Operators can manage:

- Replication.
- Failover.
- Backups.
- Recovery.
- Upgrades.
- PostgreSQL clusters.
- Read replicas.

This is generally safer than writing a basic custom StatefulSet chart for production.

### Option 3: Established PostgreSQL chart

An established chart may be acceptable for simpler production workloads, but verify:

- Backup support.
- Upgrade strategy.
- Security defaults.
- Image provenance.
- Storage behavior.
- Monitoring.
- Recovery procedures.
- Maintenance ownership.

Installing a popular chart does not automatically make PostgreSQL production-ready.

## Why the Secret helper is acceptable

The chart uses this helper:

```gotemplate
{{ include "sudo0x-postgres.secretName" . }}
```

The helper allows the chart to use either:

- A chart-generated Secret for development.
- An existing Secret for production.

For production, use:

```yaml
auth:
  enabled: true
  existingSecret: postgres-production-credentials
  usernameKey: username
  passwordKey: password
```

Create the Secret separately:

```bash
kubectl create secret generic postgres-production-credentials \
  --from-literal=username=appuser \
  --from-literal=password='REPLACE_WITH_A_REAL_SECRET' \
  --namespace infrastructure
```

The helper name is not the production risk. The important requirements are:

- Do not commit passwords to Git.
- Do not expose passwords in ConfigMaps.
- Manage the Secret securely.
- Support credential rotation.
- Limit access to approved workloads.

## Minimum requirements if using this chart in production

At minimum, provide:

```text
Existing Secret
Persistent StorageClass
Automated backups
Restore testing
Monitoring and alerting
Resource sizing
Network restrictions
Upgrade procedure
Failure testing
Recovery documentation
```

Keep the chart configured as a single instance:

```yaml
replicaCount: 1

persistence:
  enabled: true
```

Do not change this to:

```yaml
replicaCount: 3
```

and assume PostgreSQL becomes highly available. Multiple StatefulSet pods do not automatically configure:

- PostgreSQL replication.
- Automatic failover.
- Leader election.
- Read replicas.
- Connection routing.

## Recommended role for this repository

Use the charts this way:

```text
Redis chart:
  Simple persistent internal Redis

PostgreSQL chart:
  Development and learning PostgreSQL

Spring Boot chart:
  Reusable application deployment

Production PostgreSQL:
  Managed PostgreSQL or PostgreSQL operator
```

The current PostgreSQL chart is a useful learning and development chart. For critical production data, use a managed PostgreSQL service or a PostgreSQL operator instead of relying on this simple custom StatefulSet alone.

## Decision checklist

Before using the custom chart for production, answer yes to all of these:

- [ ] Is one PostgreSQL instance acceptable?
- [ ] Is manual recovery acceptable?
- [ ] Are backups automated?
- [ ] Has restore been tested?
- [ ] Is the StorageClass reliable?
- [ ] Is the database monitored?
- [ ] Are alerts configured?
- [ ] Is the Secret managed securely?
- [ ] Is network access restricted?
- [ ] Is the upgrade process documented?
- [ ] Is downtime acceptable during maintenance?
- [ ] Is there a documented disaster recovery plan?

If any answer is no, use managed PostgreSQL or a PostgreSQL operator.

