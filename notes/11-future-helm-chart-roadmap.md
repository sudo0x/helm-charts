# Future Helm Chart Roadmap

This document records the recommended next steps for extending this Helm repository after Redis, PostgreSQL, RabbitMQ, and Kafka have been created.

It is a planning document for future research and implementation. The features described here should be implemented incrementally and validated in a development cluster before being used in production.

## Recommended next chart

The next chart should be a reusable **Spring Boot service chart**.

The infrastructure charts provide databases, caches, messaging, and streaming services. A Spring Boot application chart will connect those services to deployable business applications such as:

```text
orders-service
users-service
payments-service
notifications-service
```

The chart should standardize Kubernetes deployment behavior while allowing each application to configure its own image, health endpoints, resources, environment variables, and external service connections.

The planned chart directory is:

```text
charts/spring-boot-service/
├── Chart.yaml
├── values.yaml
├── README.md
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── service.yaml
    ├── configmap.yaml
    ├── secret.yaml
    ├── serviceaccount.yaml
    ├── ingress.yaml
    ├── hpa.yaml
    ├── pdb.yaml
    ├── networkpolicy.yaml
    └── tests/
        └── connection-test.yaml
```

The existing planning document contains the initial design:

```text
charts/spring-boot-service/README.md
```

## Initial Spring Boot chart scope

The first implementation should support:

- Configurable container image repository, tag, and pull policy.
- Deployment replicas and rolling update behavior.
- ClusterIP Service and configurable container ports.
- CPU and memory requests and limits.
- Startup, readiness, and liveness probes.
- Spring Boot Actuator health endpoints.
- ConfigMap-based non-sensitive configuration.
- References to existing Kubernetes Secrets.
- ServiceAccount configuration.
- Pod and container security contexts.
- Node selectors, tolerations, affinity, and topology spread.
- Optional Ingress with TLS.
- Optional HorizontalPodAutoscaler.
- Optional PodDisruptionBudget.
- Optional NetworkPolicy after the basic chart is stable.

The chart should remain independent from Redis, PostgreSQL, RabbitMQ, and Kafka. Those components should be installed and upgraded separately. The application should connect to them through configurable hostnames, ports, credentials, and Secret references.

## Important Spring Boot integration

The application and chart must agree on the health endpoints and port. A typical Spring Boot application uses:

```text
/actuator/health
/actuator/health/liveness
/actuator/health/readiness
```

Typical application configuration is:

```properties
management.endpoint.health.probes.enabled=true
management.health.livenessstate.enabled=true
management.health.readinessstate.enabled=true
```

The chart must not assume that every application exposes the same paths. Probe paths and ports should remain configurable in `values.yaml`.

## Suggested implementation order

Implement and validate the chart in this order:

1. Create `Chart.yaml`.
2. Document the values structure.
3. Create namespaced helper templates.
4. Create the Deployment.
5. Create the ClusterIP Service.
6. Add resources and security contexts.
7. Add configurable health probes.
8. Add ConfigMap support.
9. Add existing Secret references.
10. Add ServiceAccount support.
11. Add optional Ingress and TLS.
12. Add optional HPA.
13. Add optional PDB.
14. Add optional NetworkPolicy.
15. Add README examples and troubleshooting guidance.
16. Run Helm lint and render important configuration variants.
17. Install and test a real sample Spring Boot application.
18. Package and publish the chart.

Start with a simple stateless service. Do not add every platform feature before a basic Deployment can be installed and upgraded successfully.

## Example future installation

After implementation, a service could be deployed with:

```bash
helm upgrade --install orders-service \
  sudo0x/spring-boot-service \
  --namespace applications-dev \
  --create-namespace \
  --set image.repository=ghcr.io/sudo0x/orders-service \
  --set image.tag=1.0.0
```

For repeatable environments, use a values file instead of many command-line flags:

```bash
helm upgrade --install orders-service \
  sudo0x/spring-boot-service \
  --namespace applications-production \
  --create-namespace \
  --values environments/production/orders-service.yaml
```

## Validation checklist

Before publishing the chart, verify:

- Deployment selectors and pod labels match.
- Service selectors point to the intended pods.
- Image repository and tag render correctly.
- Resource requests and limits are present.
- Probes use the configured paths and ports.
- Secret values are referenced rather than exposed in ConfigMaps.
- Ingress is absent when disabled.
- HPA is absent when disabled.
- PDB is absent when disabled.
- Security contexts render as intended.
- A Helm upgrade performs a safe rolling update.
- The application starts when Redis, PostgreSQL, RabbitMQ, or Kafka configuration is provided.
- Failure of a dependency produces useful application behavior and logs.

Recommended commands:

```bash
helm lint charts/spring-boot-service

helm template example-service charts/spring-boot-service \
  --namespace applications-dev

helm upgrade --install example-service \
  charts/spring-boot-service \
  --namespace applications-dev \
  --create-namespace \
  --wait
```

## Production considerations

Before using the chart in production, document:

- Whether the application is stateless.
- Required replica count and availability target.
- Resource sizing and scaling limits.
- Health endpoint behavior during startup and shutdown.
- Database migration ownership and rollback behavior.
- Redis, PostgreSQL, RabbitMQ, and Kafka connection requirements.
- Secret creation, rotation, and access control.
- Ingress hostname, TLS certificate, and authentication requirements.
- NetworkPolicy rules.
- Logging, metrics, tracing, and alerting.
- Image scanning and image promotion.
- Backup and disaster recovery responsibilities.

Do not add automatic database migrations to the generic chart unless the migration strategy is explicitly designed and tested. Database schema changes should be controlled separately from routine application rollouts.

## Future platform work after the application chart

After the Spring Boot chart is stable, the next useful areas are:

### Ingress and TLS

Use the official `ingress-nginx` or Gateway API ecosystem rather than creating a custom ingress controller chart. Define a consistent hostname and certificate strategy for each environment.

### Observability

Research official charts and operators for:

- Prometheus.
- Grafana.
- Alertmanager.
- Loki or another log aggregation system.
- OpenTelemetry Collector.

The application chart should expose standard metrics and logs but should not bundle the entire observability platform.

### Production infrastructure operators

For serious production workloads, prefer purpose-built operators or managed services:

- CloudNativePG or managed PostgreSQL.
- RabbitMQ Cluster Operator or managed RabbitMQ.
- Strimzi or managed Kafka.
- Managed Redis or a Redis operator where appropriate.

Do not attempt to create high availability by only increasing `replicaCount` on the current simple infrastructure charts.

### Environment management

Introduce clearly separated values files:

```text
environments/
├── development/
├── staging/
└── production/
```

Keep secrets outside Git or use an approved external-secrets solution. Review the values file and release history for accidental credential exposure.

## What should not be added initially

Avoid adding these features until the basic application chart is proven:

- Infrastructure charts as mandatory dependencies.
- Service mesh configuration.
- Custom operators.
- Automatic database migrations.
- External secret integrations without a platform decision.
- CI/CD workflows unrelated to Helm packaging.
- Application source code inside the chart repository.

## Long-term repository goal

The repository should eventually provide:

1. Reusable development infrastructure charts.
2. A reusable Spring Boot application chart.
3. Environment-specific deployment values.
4. Production guidance and migration notes.
5. Helm lint, template, package, and upgrade examples.
6. A clear separation between simple learning charts and production operators or managed services.

The Spring Boot service chart is the best next implementation because it connects the existing infrastructure to real applications while covering the most common Helm patterns used in Kubernetes development and production.
