# RabbitMQ Helm Chart

This chart deploys a simple single-instance RabbitMQ node using the official RabbitMQ Docker image.

It is intended for development, testing, and learning. It does not provide RabbitMQ clustering, quorum queues, mirrored queues, automatic failover, or high availability.

## Resources

The chart creates:

- One StatefulSet.
- One RabbitMQ container.
- One ClusterIP Service.
- One Secret when chart-managed authentication is enabled.
- One PVC through `volumeClaimTemplates` when persistence is enabled.
- Liveness and readiness probes.

Ports:

| Port | Purpose |
|---:|---|
| `5672` | AMQP client connections |
| `15672` | RabbitMQ management HTTP API and UI |

## Install locally

From the repository root:

```bash
helm lint charts/rabbitmq
helm template rabbitmq charts/rabbitmq -n infrastructure
helm upgrade --install rabbitmq charts/rabbitmq \
  --namespace infrastructure \
  --create-namespace
```

Inspect the deployment:

```bash
kubectl get statefulset,service,secret,pvc -n infrastructure
kubectl get pods -n infrastructure -l app.kubernetes.io/instance=rabbitmq
```

## Authentication

Default values:

```yaml
auth:
  enabled: true
  existingSecret: ""
  usernameKey: username
  passwordKey: password
  username: appuser
  password: "change-me"
```

For development, an empty `existingSecret` causes the chart to create a Secret.

For real environments, create the Secret separately:

```bash
kubectl create secret generic rabbitmq-production-credentials \
  --from-literal=username=appuser \
  --from-literal=password='REPLACE_WITH_A_REAL_SECRET' \
  --namespace infrastructure
```

Install with the existing Secret:

```bash
helm upgrade --install rabbitmq charts/rabbitmq \
  --namespace infrastructure \
  --set auth.existingSecret=rabbitmq-production-credentials
```

The Secret must contain the keys configured by `auth.usernameKey` and `auth.passwordKey`.

RabbitMQ bootstrap credentials are used during initial data directory initialization. Changing the Secret after the RabbitMQ data directory already exists does not automatically change the existing RabbitMQ user's password. Use RabbitMQ administrative commands or recreate the data only when that is intentional.

## Persistence

Persistence is enabled by default:

```yaml
persistence:
  enabled: true
  size: 10Gi
```

Data is mounted at:

```text
/var/lib/rabbitmq
```

For temporary development:

```bash
helm upgrade --install rabbitmq charts/rabbitmq \
  --namespace infrastructure \
  --set persistence.enabled=false
```

This uses `emptyDir`, and all queues and messages are lost when the pod is removed.

The PVC normally remains after:

```bash
helm uninstall rabbitmq -n infrastructure
```

Check it:

```bash
kubectl get pvc -n infrastructure
```

Delete the PVC only when the RabbitMQ data is intentionally being destroyed.

## Connecting applications

The AMQP Service address is normally:

```text
rabbitmq-sudo0x-rabbitmq.infrastructure.svc.cluster.local:5672
```

The exact hostname depends on the Helm release name.

The management UI can be accessed temporarily with:

```bash
kubectl port-forward svc/rabbitmq-sudo0x-rabbitmq \
  15672:15672 \
  -n infrastructure
```

Open:

```text
http://localhost:15672
```

Do not expose the management port publicly without authentication, TLS, and network restrictions.

## Important limitations

This chart is not a production HA RabbitMQ solution. It does not provide:

- Multiple RabbitMQ nodes.
- RabbitMQ clustering.
- Quorum queue design.
- Automatic failover.
- Cross-zone resilience.
- Automated backups.
- Disaster recovery.
- Monitoring and alerting.

For production RabbitMQ, use a managed messaging service, RabbitMQ Cluster Operator, or an established production chart with a documented backup and recovery design.
