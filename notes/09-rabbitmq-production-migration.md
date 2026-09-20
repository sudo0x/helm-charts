# RabbitMQ Production Migration Note

This note explains the recommended path from the simple RabbitMQ Helm chart to production RabbitMQ in Kubernetes.

## Current chart

The current chart is:

```text
charts/rabbitmq/
```

It provides:

- One RabbitMQ StatefulSet pod.
- One PVC by default.
- ClusterIP Service.
- AMQP port `5672`.
- Management port `15672`.
- Basic authentication.
- Basic health probes.

It is for development, testing, and learning.

It is not RabbitMQ HA.

## Do not scale it by changing only replicas

This is not enough:

```yaml
replicaCount: 3
```

That does not configure:

- RabbitMQ cluster membership.
- Shared Erlang cookie.
- Queue replication.
- Quorum queues.
- Failover.
- Client routing.

## Production target

Use one of:

```text
RabbitMQ Cluster Operator
Managed messaging service
Approved production RabbitMQ platform
```

## Migration phases

### Phase 1: Development

Install the simple chart:

```bash
helm upgrade --install rabbitmq charts/rabbitmq \
  --namespace infrastructure-dev \
  --create-namespace
```

Use a fixed image tag, persistent storage when messages matter, and an existing Secret for shared environments.

### Phase 2: Pre-production

Decide:

- Operator or managed service.
- Cluster size.
- Availability zones.
- StorageClass and capacity.
- Queue replication.
- TLS.
- NetworkPolicy.
- Monitoring.
- Backup and restore.
- Application reconnect behavior.

Test:

- Node failure.
- Rolling maintenance.
- Queue recovery.
- Producer confirms.
- Consumer acknowledgements.
- Dead-letter routing.
- Restore procedure.

### Phase 3: Production

1. Create the production RabbitMQ cluster.
2. Create users and vhosts.
3. Create exchanges, queues, bindings, and policies.
4. Configure TLS and application Secrets.
5. Test a producer and consumer.
6. Move applications gradually.
7. Monitor queue depth, errors, and consumer health.
8. Keep rollback available.

## Production checklist

- [ ] Approved operator or managed service selected.
- [ ] Multiple nodes and failure domains designed.
- [ ] Quorum queue strategy documented.
- [ ] Persistent storage selected and sized.
- [ ] Existing Secret configured.
- [ ] Erlang cookie management understood.
- [ ] Network access restricted.
- [ ] TLS decision completed.
- [ ] Monitoring and alerts configured.
- [ ] Backups configured.
- [ ] Restore tested.
- [ ] Application retry and reconnect tested.
- [ ] Upgrade and rollback procedures documented.

Read the detailed guide:

```text
charts/rabbitmq/PRODUCTION-GUIDANCE.md
```

