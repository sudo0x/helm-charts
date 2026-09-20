# Kafka KRaft Development and Production Note

## Development chart

The new chart is:

```text
charts/kafka/
```

It uses:

```text
apache/kafka:4.3.1
KRaft combined broker/controller mode
one broker
no ZooKeeper
```

Validate:

```bash
helm lint charts/kafka
helm template kafka charts/kafka -n infrastructure
```

Install:

```bash
helm upgrade --install kafka charts/kafka \
  --namespace infrastructure-dev \
  --create-namespace
```

Test topics and records from the pod:

```bash
kubectl exec -it kafka-sudo0x-kafka-0 \
  -n infrastructure-dev \
  -- bash
```

Inside the pod:

```bash
/opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic test-events \
  --partitions 1 \
  --replication-factor 1
```

## Production warning

Do not make production Kafka by changing only:

```yaml
replicaCount: 3
```

That does not configure KRaft controller quorum, broker discovery, replication, security, or failover.

Use:

```text
Strimzi
Confluent for Kubernetes
Managed Kafka
```

## Production migration order

1. Select an operator or managed Kafka platform.
2. Design broker and controller roles.
3. Select storage and failure domains.
4. Configure TLS, SASL, ACLs, and NetworkPolicy.
5. Define topic partitions, replication, retention, and ISR settings.
6. Configure monitoring and consumer-lag alerts.
7. Test producer and consumer reconnect behavior.
8. Test broker and controller failures.
9. Create production topics.
10. Migrate applications gradually.
11. Keep rollback and recovery procedures available.

Read the detailed guide:

```text
charts/kafka/PRODUCTION-GUIDANCE.md
```
