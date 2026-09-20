# Kafka Helm Chart (KRaft)

This chart deploys a simple single-node Apache Kafka broker in **KRaft combined mode**. KRaft means Kafka uses its built-in Raft-based controller quorum and does not use ZooKeeper.

The chart is intended for development, testing, and learning. It is not a production Kafka cluster.

## Resources

The chart creates:

- One StatefulSet.
- One headless ClusterIP Service.
- One PVC through `volumeClaimTemplates` when persistence is enabled.
- One `emptyDir` volume when persistence is disabled.
- Liveness and readiness probes.

The default image is:

```yaml
image:
  repository: apache/kafka
  tag: "4.3.1"
```

The chart uses:

```text
KRaft combined mode
broker role + controller role
one node
PLAINTEXT inside the cluster
```

There is no ZooKeeper dependency.

## Install for development

From the repository root:

```bash
helm lint charts/kafka
helm template kafka charts/kafka -n infrastructure
helm upgrade --install kafka charts/kafka \
  --namespace infrastructure \
  --create-namespace
```

Check the deployment:

```bash
kubectl get statefulset,service,pvc -n infrastructure
kubectl get pods -n infrastructure -l app.kubernetes.io/instance=kafka
```

The in-cluster bootstrap address is normally:

```text
kafka-sudo0x-kafka.infrastructure.svc.cluster.local:9092
```

The exact hostname depends on the Helm release name.

## Create and test a topic

Open a shell in the Kafka pod:

```bash
kubectl exec -it kafka-sudo0x-kafka-0 \
  -n infrastructure \
  -- bash
```

Create a topic:

```bash
/opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic test-events \
  --partitions 1 \
  --replication-factor 1
```

List topics:

```bash
/opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list
```

Produce messages:

```bash
/opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic test-events
```

Consume messages:

```bash
/opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic test-events \
  --from-beginning
```

## Persistence

Persistence is enabled by default:

```yaml
persistence:
  enabled: true
  size: 10Gi
```

Kafka data is mounted at:

```text
/var/lib/kafka/data
```

For temporary development:

```bash
helm upgrade --install kafka charts/kafka \
  --namespace infrastructure \
  --set persistence.enabled=false
```

This uses `emptyDir`, and all topics and records are lost when the pod is removed.

The PVC normally remains after:

```bash
helm uninstall kafka -n infrastructure
```

Check it:

```bash
kubectl get pvc -n infrastructure
```

Delete the PVC only when Kafka data is intentionally being destroyed.

## Important limitations

This chart is not a production Kafka solution. It does not provide:

- Multiple brokers.
- Controller quorum redundancy.
- Broker failover.
- Replicated topics.
- Rack or zone awareness.
- TLS or SASL authentication.
- NetworkPolicy.
- Automated backups.
- Disaster recovery.
- Monitoring and alerting.
- Kafka Connect or Schema Registry.

The defaults use replication factor `1` because there is only one broker. Do not increase replication factors until a multi-broker cluster exists.
