# Kafka KRaft Production Guidance and Migration Plan

## Current chart status

The current chart is a simple development chart:

```text
One Kafka broker
One combined broker/controller KRaft node
One StatefulSet
One PVC
One headless Service
PLAINTEXT listeners
No ZooKeeper
```

It is useful for development and learning, but it is not a production Kafka cluster.

## What KRaft means

KRaft is Kafka's built-in Raft-based metadata quorum. It removes the ZooKeeper dependency.

The current chart runs:

```text
broker role + controller role
```

on the same node. This is called combined mode and is suitable for simple development environments.

Production Kafka should use multiple nodes and a deliberate controller/broker architecture.

## Do not scale this chart by changing only replicas

This is not enough:

```yaml
replicaCount: 3
```

The chart currently hardcodes a single-node controller voter:

```text
1@<kafka-service>-0.<kafka-service>:9093
```

Changing replicas without redesigning:

- Node IDs.
- Controller quorum voters.
- Advertised listeners.
- Storage identity.
- Replication factors.
- Rack or zone placement.

does not create a valid production cluster.

## Production Kafka architecture

A production KRaft deployment normally requires:

```text
Multiple Kafka brokers
Multiple KRaft controllers or dedicated controller nodes
Persistent storage per broker
Controller quorum
Replicated topics
Rack or zone awareness
TLS and SASL
Network restrictions
Monitoring and alerting
Backup and recovery procedures
Capacity planning
Upgrade planning
```

Use an approved Kafka operator or managed Kafka platform when possible.

Examples to evaluate:

- Strimzi Kafka Operator.
- Confluent for Kubernetes.
- Managed Kafka from a cloud or messaging provider.

The operator or platform should manage:

- KRaft node roles.
- Cluster membership.
- Rolling upgrades.
- Listener configuration.
- TLS and authentication.
- Storage.
- Topic and user resources.
- Monitoring integration.

## Production replication

The current chart defaults to:

```yaml
kafka:
  topicPartitions: 1
  offsetsTopicReplicationFactor: 1
  transactionStateLogReplicationFactor: 1
  transactionStateLogMinIsr: 1
```

These settings are required for a single broker.

For production, replication factors must match the actual broker count and failure-domain design. Example values for a three-broker cluster might use replication factor `3`, but only after the cluster is correctly configured.

Review:

- Topic replication factor.
- Minimum in-sync replicas.
- Producer acknowledgements.
- Unclean leader election.
- Consumer group behavior.
- Internal topic replication.
- Transaction state replication.

Do not copy production replication values into this single-node chart.

## Storage and data safety

Kafka stores event records on disk:

```text
Kafka log data: persistent disk
Active page cache: memory
Recovery: disk log segments are read after restart
```

For production:

- Use reliable CSI-backed storage.
- Size storage for retention and traffic.
- Monitor disk capacity.
- Test volume expansion.
- Use one persistent volume per broker.
- Understand the StorageClass reclaim policy.
- Do not use `emptyDir` for important event data.

Kafka replication is not a replacement for backups. Define how important topics and metadata are recovered after cluster loss.

## Security

The current chart uses PLAINTEXT for development:

```text
PLAINTEXT://:9092
```

Production should evaluate:

- TLS encryption.
- SASL authentication.
- Client authorization.
- Per-user ACLs.
- Secret rotation.
- NetworkPolicy.
- Restricted controller listener access.
- Restricted management and administrative access.

Do not expose a PLAINTEXT Kafka listener to an untrusted network.

## Listener design

Production Kafka listener design must distinguish:

- Client listeners.
- Inter-broker listener.
- Controller listener.
- Internal versus external clients.

Advertised listeners must be reachable from the clients that use them. A client may connect to the bootstrap Service but then receive broker addresses from metadata; every advertised broker address must resolve and be reachable.

Test from the actual application namespace and network path.

## Topic and message design

Production topics need documented:

- Topic names.
- Partition counts.
- Replication factor.
- Retention time.
- Retention size.
- Cleanup policy.
- Message key strategy.
- Ordering requirements.
- Consumer group names.
- Dead-letter strategy.
- Schema compatibility.

Increasing partitions can affect ordering and consumer distribution. Do not select partition counts randomly.

## Application requirements

Spring Boot Kafka clients should define:

- Bootstrap servers.
- Security protocol.
- SASL or TLS settings where required.
- Producer acknowledgements.
- Retries and delivery timeout.
- Idempotence.
- Consumer group.
- Offset commit behavior.
- Error handling.
- Dead-letter behavior.
- Rebalance handling.
- Graceful shutdown.

Applications must tolerate broker restarts and rebalances.

## Monitoring

Monitor and alert on:

- Broker availability.
- Controller quorum health.
- Under-replicated partitions.
- Offline partitions.
- ISR shrink events.
- Request latency.
- Produce and fetch rates.
- Consumer lag.
- Disk usage.
- Log segment growth.
- JVM or process memory.
- Network errors.
- Rebalances.
- Failed authentication.

Use the approved Kafka exporter, operator metrics, or managed-service monitoring.

## Backup and recovery

Define recovery for:

- Topic definitions.
- Topic configurations.
- ACLs and users.
- Consumer group expectations.
- Important event data.
- Schema definitions.
- Connect connector configuration, if used.

Kafka retention is not automatically a backup. If the cluster and storage are lost, retained records may also be lost.

Test:

1. Restore infrastructure.
2. Recreate security resources.
3. Recreate topics and configurations.
4. Restore or replay required data.
5. Start consumers.
6. Verify offsets and application behavior.
7. Measure RPO and RTO.

## Migration path

### Phase 1: Development

Install the current chart:

```bash
helm upgrade --install kafka charts/kafka \
  --namespace infrastructure-dev \
  --create-namespace
```

Use one broker, one partition, replication factor `1`, and persistence for repeatable local testing.

### Phase 2: Pre-production

Select:

- Strimzi, Confluent, or managed Kafka.
- Broker and controller count.
- StorageClass and disk size.
- Availability zones.
- Security protocol.
- Topic replication policy.
- Monitoring.
- Backup approach.

Test:

- Producer and consumer reconnect.
- Broker restart.
- Controller restart.
- Consumer rebalancing.
- Partition reassignment.
- Consumer lag recovery.
- Storage pressure.
- TLS and authentication.

### Phase 3: Production

1. Create the production KRaft cluster with the operator or managed platform.
2. Configure listeners, TLS, SASL, and ACLs.
3. Create production topics with the approved replication and retention settings.
4. Validate producer and consumer clients.
5. Migrate one application at a time.
6. Monitor lag, errors, and broker health.
7. Keep the rollback and data recovery plan available.

Do not migrate by changing only `replicaCount` in this chart.

## Production checklist

### Cluster

- [ ] KRaft operator or managed Kafka selected.
- [ ] Broker count selected.
- [ ] Controller quorum selected.
- [ ] Failure domains selected.
- [ ] Node roles and IDs documented.

### Storage

- [ ] StorageClass selected.
- [ ] Capacity sized for retention.
- [ ] Disk monitoring configured.
- [ ] Expansion procedure tested.
- [ ] Reclaim policy understood.

### Security

- [ ] TLS decision completed.
- [ ] SASL authentication configured where required.
- [ ] ACL model documented.
- [ ] NetworkPolicy configured.
- [ ] Secrets are not committed to Git.

### Topics

- [ ] Partition counts documented.
- [ ] Replication factors documented.
- [ ] Minimum ISR configured.
- [ ] Retention policy documented.
- [ ] Message ordering requirements documented.
- [ ] Dead-letter strategy documented.

### Operations

- [ ] Consumer lag alerts configured.
- [ ] Under-replicated partition alerts configured.
- [ ] Offline partition alerts configured.
- [ ] Storage alerts configured.
- [ ] Backup or event replay strategy tested.
- [ ] Upgrade and rollback procedures documented.

## Final recommendation

Use this chart for development and learning:

```text
Single broker
Combined KRaft mode
PLAINTEXT
Replication factor 1
```

For production Kubernetes:

```text
Kafka operator or managed Kafka
        +
Multiple brokers
        +
Controller quorum
        +
Persistent storage
        +
Replicated topics
        +
TLS and authentication
        +
Monitoring and alerting
        +
Recovery and migration testing
```
