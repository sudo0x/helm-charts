# sudo0x Helm Charts

Reusable Helm charts and Kubernetes learning documentation for development, testing, and production migration planning.

This repository contains simple, understandable charts for common infrastructure and application workloads. The charts are intentionally separated so each component can be installed, upgraded, and operated independently.

## Charts

| Chart | Purpose | Current scope |
|---|---|---|
| `sudo0x-redis` | Redis OSS | Persistent single-instance Redis |
| `sudo0x-postgres` | PostgreSQL | Simple single-instance PostgreSQL |
| `sudo0x-rabbitmq` | RabbitMQ | Simple single-node RabbitMQ with management UI |
| `sudo0x-kafka` | Apache Kafka | Single-node KRaft mode without ZooKeeper |
| `sudo0x-spring-boot-service` | Spring Boot applications | Reusable Deployment, Service, ServiceAccount, and optional Ingress |

The infrastructure charts are useful for development and learning. They are not automatically highly available production systems merely because they use StatefulSets or allow replica-related values.

## Helm repository

Published packages are hosted with GitHub Pages:

```text
https://sudo0x.github.io/helm-charts
```

Add the repository:

```bash
helm repo add sudo0x https://sudo0x.github.io/helm-charts
helm repo update
helm search repo sudo0x
```

Install a published chart:

```bash
helm upgrade --install redis sudo0x/sudo0x-redis \
  --namespace infrastructure-dev \
  --create-namespace
```

The currently published infrastructure packages are:

```text
sudo0x/sudo0x-redis
sudo0x/sudo0x-postgres
sudo0x/sudo0x-kafka
```

The RabbitMQ chart and Spring Boot service chart are currently maintained in the repository source. Check each chart directory and the GitHub Pages index before installing from the package repository.

## Install charts from source

Clone the repository:

```bash
git clone https://github.com/sudo0x/helm-charts.git
cd helm-charts
```

Install Redis:

```bash
helm upgrade --install redis charts/redis \
  --namespace infrastructure-dev \
  --create-namespace \
  --wait
```

Install PostgreSQL:

```bash
helm upgrade --install postgres charts/postgres \
  --namespace infrastructure-dev \
  --create-namespace \
  --wait
```

Install RabbitMQ:

```bash
helm upgrade --install rabbitmq charts/rabbitmq \
  --namespace infrastructure-dev \
  --create-namespace \
  --wait
```

Install Kafka in KRaft mode:

```bash
helm upgrade --install kafka charts/kafka \
  --namespace infrastructure-dev \
  --create-namespace \
  --wait
```

Install the Spring Boot application chart:

```bash
helm upgrade --install orders-service charts/spring-boot-service \
  --namespace applications-dev \
  --create-namespace \
  --set image.repository=ghcr.io/sudo0x/orders-service \
  --set image.tag=1.0.0 \
  --wait
```

The Spring Boot chart uses a placeholder image by default for basic rendering and testing. Replace it with a real application image before deployment.

## NGINX Ingress Controller

The Spring Boot chart can create an optional Kubernetes Ingress resource. The shared NGINX Ingress Controller is installed separately from the official community Helm chart:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.ingressClassResource.name=nginx \
  --set controller.ingressClassResource.default=true \
  --wait
```

Enable application routing:

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: orders.example.com
      paths:
        - path: /
          pathType: Prefix
```

The relationship is:

```text
NGINX Ingress Controller
        ↓ reads
Kubernetes Ingress resource
        ↓ routes to
ClusterIP Service
        ↓ selects
Application Pods
```

Install one shared controller per cluster or environment, not one controller per application.

## Repository structure

```text
charts/
├── kafka/
├── postgres/
├── rabbitmq/
├── redis/
└── spring-boot-service/

notes/
├── 01-redis-helm-learning.md
├── 02-statefulset-and-persistence.md
├── 03-redis-helm-from-scratch.md
├── 04-production-readiness-roadmap.md
├── 05-spring-boot-service-chart-plan.md
├── 07-helm-cheatsheet.md
├── 08-helm-template-and-helper-syntax.md
├── 09-rabbitmq-production-migration.md
├── 10-kafka-kraft-development-and-production.md
├── 11-future-helm-chart-roadmap.md
├── 12-ingress-setup-and-changes.md
├── 13-nginx-ingress-controller-explained.md
├── 14-multiple-spring-boot-services-with-ingress.md
├── 15-service-vs-nginx-ingress.md
├── 16-kubernetes-daily-user-commands.md
├── 17-kubernetes-connectivity-troubleshooting-cheatsheet.md
└── 18-cross-network-diagnostics-cheatsheet.md

docs/
└── GitHub Pages Helm repository packages and index
```

## Validate a chart

Lint:

```bash
helm lint charts/redis
helm lint charts/postgres
helm lint charts/rabbitmq
helm lint charts/kafka
helm lint charts/spring-boot-service
```

Render manifests without installing:

```bash
helm template test charts/kafka \
  --namespace infrastructure-dev

helm template orders-service charts/spring-boot-service \
  --namespace applications-dev \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=orders.local
```

Inspect a release:

```bash
helm status <release-name> --namespace <namespace>
helm get values <release-name> --namespace <namespace>
helm get manifest <release-name> --namespace <namespace>
```

Inspect live Kubernetes resources:

```bash
kubectl get all --namespace applications-dev
kubectl get events --namespace applications-dev --sort-by=.lastTimestamp
kubectl get ingress --all-namespaces
```

## Documentation guide

Start with the general Helm references:

- [Helm command cheat sheet](notes/07-helm-cheatsheet.md)
- [Helm template and helper syntax](notes/08-helm-template-and-helper-syntax.md)
- [Kubernetes daily commands](notes/16-kubernetes-daily-user-commands.md)
- [Connectivity troubleshooting](notes/17-kubernetes-connectivity-troubleshooting-cheatsheet.md)
- [Cross-network diagnostics](notes/18-cross-network-diagnostics-cheatsheet.md)

Infrastructure and application guides:

- [Redis chart README](charts/redis/README.md)
- [Redis version upgrade guide](charts/redis/VERSION-UPGRADE-GUIDE.md)
- [PostgreSQL chart README](charts/postgres/README.md)
- [PostgreSQL production guidance](charts/postgres/PRODUCTION-GUIDANCE.md)
- [RabbitMQ chart README](charts/rabbitmq/README.md)
- [RabbitMQ production migration](notes/09-rabbitmq-production-migration.md)
- [Kafka chart README](charts/kafka/README.md)
- [Kafka KRaft production guidance](charts/kafka/PRODUCTION-GUIDANCE.md)
- [Spring Boot service chart plan](charts/spring-boot-service/README.md)
- [Multiple Spring Boot services with Ingress](notes/14-multiple-spring-boot-services-with-ingress.md)

## Production boundary

These charts are intentionally simple and are best suited to development, learning, and controlled migration exercises.

For serious production workloads, prefer managed services or purpose-built operators:

| Component | Production direction |
|---|---|
| PostgreSQL | CloudNativePG or a managed PostgreSQL service |
| RabbitMQ | RabbitMQ Cluster Operator or managed RabbitMQ |
| Kafka | Strimzi, Confluent for Kubernetes, or managed Kafka |
| Redis | Managed Redis or an appropriate Redis operator |
| Spring Boot | A reviewed application chart with image scanning, observability, secrets, and environment-specific values |

Production readiness also requires:

- Persistent storage design.
- Backup and restore testing.
- TLS and authentication.
- Resource requests and limits.
- NetworkPolicies.
- Monitoring and alerting.
- Failure and recovery testing.
- Secret rotation.
- Image version promotion.
- Disaster recovery planning.

Increasing `replicaCount` on a simple stateful chart does not automatically create a correctly configured HA database, broker, or cluster.

## Security notes

- Do not commit real passwords, private keys, or tokens.
- Prefer existing Kubernetes Secrets or an approved external secret system.
- Keep Redis, PostgreSQL, RabbitMQ, and Kafka internal unless external exposure is explicitly designed and secured.
- Use TLS for production HTTP traffic.
- Review rendered manifests before applying them.
- Use fixed image tags rather than mutable `latest` tags.

## Contributing workflow

For a chart change:

```bash
helm lint charts/<chart-name>
helm template <release-name> charts/<chart-name> --namespace <namespace>
git diff
```

For a new published chart package:

```bash
helm package charts/<chart-name> --destination dist
helm repo index dist --url https://sudo0x.github.io/helm-charts
Copy-Item dist\<package>.tgz docs\<package>.tgz
Copy-Item dist\index.yaml docs\index.yaml
```

Stage only the intended source files, documentation, package, and `docs/index.yaml`. Keep local build artifacts in `dist/` out of commits unless they are intentionally being tracked.

## Project status

This repository is both:

1. A working collection of simple Helm charts.
2. A structured learning guide for Kubernetes, Helm, Services, Ingress, and connectivity troubleshooting.

Read the chart-specific README before installing a component, and read the production guidance before treating a development chart as a production architecture.
