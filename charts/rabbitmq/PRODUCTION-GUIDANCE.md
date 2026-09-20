# RabbitMQ Production Guidance and Migration Plan

This document explains how to move from the current simple RabbitMQ chart to a production-ready RabbitMQ deployment in Kubernetes.

## Current chart status

The current chart is:

```text
One RabbitMQ instance
One StatefulSet
One PVC
One ClusterIP Service
AMQP and management ports
Secret-based bootstrap credentials
Basic liveness and readiness probes
```

It is suitable for:

- Local development.
- Testing.
- Non-critical internal environments.
- Learning RabbitMQ and Kubernetes.

It is not currently a production high-availability RabbitMQ platform.

## What production RabbitMQ requires

Production RabbitMQ should be designed around:

```text
Multiple RabbitMQ nodes
Cluster membership
Quorum queues where appropriate
Persistent storage for every node
Pod distribution across failure domains
TLS and restricted network access
Backups and recovery procedures
Monitoring and alerting
Upgrade planning
Application retry and reconnect behavior
```

Do not make the current chart production-ready by changing only:

```yaml
replicaCount: 3
```

Multiple StatefulSet pods do not automatically configure:

- RabbitMQ clustering.
- Erlang cookie sharing.
- Node discovery.
- Queue replication.
- Quorum queues.
- Automatic failover.
- Client connection routing.

## Recommended production options

### Option 1: RabbitMQ Cluster Operator

For RabbitMQ inside Kubernetes, use the RabbitMQ Cluster Operator when it is approved for your platform.

The operator can manage:

- RabbitMQ cluster resources.
- Node configuration.
- Cluster membership.
- Persistent volumes.
- Service discovery.
- Rolling upgrades.
- Kubernetes-native lifecycle management.

The application creates a RabbitMQ custom resource instead of manually managing a basic StatefulSet.

### Option 2: Managed messaging service

Use a managed RabbitMQ-compatible or messaging service when available and appropriate.

This can reduce responsibility for:

- Node failures.
- Patching.
- Backups.
- Capacity management.
- Monitoring.
- Disaster recovery.

### Option 3: Established production chart

Use an established production chart only after reviewing:

- Clustering behavior.
- Queue replication.
- Secret handling.
- Storage behavior.
- Upgrade process.
- Backup support.
- Monitoring support.
- Ownership and maintenance.

Do not assume that any chart with `replicaCount` is automatically HA.

## Production architecture

A typical in-cluster production design looks like:

```text
Kubernetes
└── RabbitMQ Cluster Operator
    └── RabbitMQ cluster
        ├── RabbitMQ node
        ├── RabbitMQ node
        ├── RabbitMQ node
        ├── Persistent storage per node
        ├── Client Service
        ├── Management Service
        └── Monitoring and alerting
```

Use at least three nodes when the platform and workload require quorum-based availability. The exact number depends on failure-domain design, workload, cost, and operational requirements.

## Queue design

High availability depends on queue type and application behavior, not only pod count.

For important queues, evaluate:

- Quorum queues.
- Publisher confirms.
- Consumer acknowledgements.
- Dead-letter exchanges.
- Retry behavior.
- Message TTL.
- Maximum queue length.
- Back-pressure behavior.
- Poison message handling.

Do not assume that a queue is replicated merely because RabbitMQ has multiple nodes.

## Storage requirements

Each production RabbitMQ node needs reliable persistent storage.

Review:

- StorageClass.
- Volume performance.
- Volume availability across zones.
- Capacity planning.
- Expansion support.
- Reclaim policy.
- IOPS and throughput.
- Disk-full behavior.

RabbitMQ data is mounted at:

```text
/var/lib/rabbitmq
```

Do not use `emptyDir` for production message data.

Example production storage requirements:

```yaml
persistence:
  enabled: true
  storageClass: fast-ssd
  size: 50Gi
```

The actual size must be based on message volume, retention, queue growth, and recovery requirements.

## Security requirements

### Credentials

Use an existing Secret:

```yaml
auth:
  enabled: true
  existingSecret: rabbitmq-production-credentials
  usernameKey: username
  passwordKey: password
```

Create it outside the chart:

```bash
kubectl create secret generic rabbitmq-production-credentials \
  --from-literal=username=appuser \
  --from-literal=password='REPLACE_WITH_A_REAL_SECRET' \
  --namespace infrastructure
```

Do not commit real passwords to:

- `values.yaml`.
- Git.
- ConfigMaps.
- Markdown documents.
- Shell scripts.

### Erlang cookie

RabbitMQ clustering requires a shared Erlang cookie. The production operator or chart must manage it securely and consistently across all nodes.

Do not invent separate cookies for nodes that must join the same cluster.

### Network access

Keep RabbitMQ internal:

```yaml
service:
  type: ClusterIP
```

Restrict access with NetworkPolicy so only approved applications can reach:

- AMQP port `5672`.
- TLS AMQP port when enabled.
- Management port `15672`, ideally from an operations namespace only.

Do not expose the management UI publicly without a deliberate TLS, authentication, and access-control design.

### TLS

For production, evaluate TLS for:

- AMQP client connections.
- Management UI/API.
- Inter-node communication where required.

Use an approved certificate and Secret management process.

## Scheduling and availability

Production RabbitMQ nodes should not all run on the same failure domain.

Use:

- Pod anti-affinity.
- Topology spread constraints.
- Node selectors where appropriate.
- PodDisruptionBudget.
- Multiple availability zones when supported.

Example design goals:

```text
Do not place every RabbitMQ node on one node.
Do not place every node in one zone when cross-zone availability is required.
Allow planned maintenance without losing quorum.
```

## Resources and memory

RabbitMQ needs memory for:

- Queues.
- Messages.
- Connections.
- Channels.
- Exchanges.
- Consumers.
- Plugins.
- Internal runtime overhead.

Set requests and limits based on measured workload:

```yaml
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: "2"
    memory: 4Gi
```

These are examples only. Do not copy them without load testing.

Monitor:

- Memory alarms.
- Disk alarms.
- Connection count.
- Channel count.
- Queue depth.
- Message rates.
- Consumer rates.
- Unacknowledged messages.
- Node health.
- File descriptor usage.

## Monitoring and alerting

Production monitoring should cover:

- Cluster health.
- Node availability.
- Queue depth.
- Publish and delivery rates.
- Consumer count.
- Unacknowledged messages.
- Connection and channel count.
- Memory alarms.
- Disk alarms.
- Network partition events.
- Restart count.
- PVC capacity.
- Backup success.

Use the platform's approved RabbitMQ exporter or operator monitoring integration.

Create alerts with owners and runbooks. An alert without an owner is not an operational control.

## Backup and recovery

RabbitMQ backups must match the message durability requirements.

Document:

- What is backed up.
- How definitions are exported.
- Where backups are stored.
- How long backups are retained.
- Whether messages themselves must be recoverable.
- How queues and exchanges are recreated.
- How credentials are restored.
- How consumers reconnect.
- Recovery Point Objective (RPO).
- Recovery Time Objective (RTO).

Definitions and messages are different:

```text
Definitions = users, vhosts, exchanges, queues, bindings, policies
Messages    = application data waiting in queues
```

Exporting definitions does not automatically back up every message.

Test recovery in a non-production environment:

1. Create a test RabbitMQ cluster.
2. Restore definitions.
3. Restore or replay required messages according to the recovery design.
4. Connect a test producer.
5. Connect a test consumer.
6. Verify acknowledgements and routing.
7. Measure restore duration.

## Application requirements

Spring Boot services using RabbitMQ should support:

- Automatic reconnect.
- Connection timeout.
- Channel recovery.
- Publisher confirms where required.
- Consumer acknowledgements.
- Retry limits.
- Dead-letter handling.
- Idempotent message processing.
- Graceful shutdown.
- Back-pressure.

Applications must not assume RabbitMQ is always available.

## Migration path from the simple chart

### Phase 1: Development

Use the current chart:

```bash
helm upgrade --install rabbitmq charts/rabbitmq \
  --namespace infrastructure-dev \
  --create-namespace
```

Use:

```yaml
replicaCount: 1
persistence:
  enabled: true
```

Use an existing Secret for any shared development environment.

### Phase 2: Pre-production

Before production:

- Choose the operator or managed service.
- Define the cluster size.
- Define storage and failure domains.
- Define queue replication strategy.
- Configure TLS.
- Configure monitoring.
- Configure backups.
- Test application reconnect behavior.
- Test rolling maintenance.
- Test node failure.
- Test restore.

### Phase 3: Production

Create the production RabbitMQ cluster with the approved operator or managed service.

Migrate in this order:

1. Create the production cluster.
2. Create users and vhosts.
3. Create exchanges, queues, bindings, and policies.
4. Configure TLS and application Secrets.
5. Deploy a test producer and consumer.
6. Validate routing and acknowledgements.
7. Move one application at a time.
8. Monitor queue depth and errors.
9. Confirm old clients are disconnected only after successful migration.
10. Keep the rollback plan available.

Do not migrate by changing only the StatefulSet replica count.

## Production checklist

### Architecture

- [ ] Managed service or approved RabbitMQ operator selected.
- [ ] HA requirement documented.
- [ ] Failure domains documented.
- [ ] Cluster size selected.
- [ ] Queue replication strategy selected.

### Storage

- [ ] Production StorageClass selected.
- [ ] Capacity sized from workload data.
- [ ] PVC expansion behavior understood.
- [ ] Reclaim policy understood.
- [ ] Disk-full behavior tested.

### Security

- [ ] Existing Secret is used.
- [ ] Real passwords are not in Git.
- [ ] Erlang cookie is managed securely.
- [ ] NetworkPolicy is configured.
- [ ] Management access is restricted.
- [ ] TLS requirement is decided.
- [ ] Credential rotation is documented.

### Operations

- [ ] Metrics are available.
- [ ] Alerts have owners.
- [ ] Backups are configured.
- [ ] Restore has been tested.
- [ ] Upgrade procedure exists.
- [ ] Rollback procedure exists.
- [ ] Disaster recovery procedure exists.

### Applications

- [ ] Producers use confirms where required.
- [ ] Consumers acknowledge messages correctly.
- [ ] Retry behavior is bounded.
- [ ] Dead-letter behavior is configured.
- [ ] Clients reconnect after node failure.
- [ ] Message handlers are idempotent.

## Final recommendation

Use the current chart for development and learning.

For production Kubernetes:

```text
RabbitMQ operator or managed messaging service
        +
Persistent storage
        +
Clustered nodes
        +
Quorum queue design
        +
TLS and restricted network access
        +
Monitoring and alerting
        +
Backups and restore testing
        +
Application reconnect and retry behavior
```

The current chart should be treated as a stepping stone, not the final production RabbitMQ architecture.

