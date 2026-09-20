# Spring Boot Service Helm Chart Plan

This directory is reserved for a future reusable Helm chart for Spring Boot microservices.

The chart is intentionally not implemented yet. Read this document first before creating templates or deploying a service.

## Goal

Create one reusable application chart that can deploy multiple Spring Boot microservices consistently on Kubernetes.

Example services that could use this chart:

```text
orders-service
users-service
payments-service
notifications-service
```

Each service should provide its own values file while reusing the same chart templates.

## Relationship to the Redis chart

The Redis chart is a separate infrastructure chart:

```text
charts/redis/
```

The future Spring Boot chart will be an application chart:

```text
charts/spring-boot-service/
```

Do not combine the two charts. A Spring Boot service may connect to Redis, but Redis should remain independently deployable and upgradeable.

The intended relationship is:

```text
Spring Boot application
        ↓
Kubernetes Service
        ↓
Redis ClusterIP Service
```

The application chart should reference Redis through configuration. It should not install Redis as a chart dependency by default.

## Proposed chart structure

The planned directory will eventually contain:

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
    ├── serviceaccount.yaml
    ├── ingress.yaml
    ├── hpa.yaml
    └── pdb.yaml
```

The initial chart implementation now includes a Deployment, Service, ServiceAccount, and optional Ingress. Additional application configuration features can be added incrementally.

## Initial scope

The first implementation should support:

- Kubernetes Deployment.
- Configurable container image repository and tag.
- Configurable replica count.
- ClusterIP Service.
- Container port configuration.
- Resource requests and limits.
- Liveness probe.
- Readiness probe.
- Startup probe.
- Pod security context.
- Container security context.
- ConfigMap-based non-sensitive configuration.
- References to existing Secrets.
- ServiceAccount configuration.
- Rolling update strategy.
- Optional Ingress.
- Optional HorizontalPodAutoscaler.
- Optional PodDisruptionBudget.
- Node selector, tolerations, and affinity.

## Ingress

Ingress is disabled by default. Enable it only when an Ingress controller is installed in the cluster:

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: orders.local
      paths:
        - path: /
          pathType: Prefix
  tls: []
```

Install the official `ingress-nginx` controller separately. This application chart creates only the routing resource; it does not install or manage the controller.

For local development, add the hostname to the client machine's hosts file or use a DNS record that resolves to the controller's external address. For production, configure a real DNS name and TLS certificate.

Example:

```bash
helm upgrade --install orders-service \
  charts/spring-boot-service \
  --namespace applications-dev \
  --create-namespace \
  --set image.repository=ghcr.io/sudo0x/orders-service \
  --set image.tag=1.0.0 \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=orders.local
```

The first implementation should remain simple. Do not add every platform feature before a basic service can be deployed successfully.

## Configuration design

The chart should expose values similar to:

```yaml
replicaCount: 1

image:
  repository: ghcr.io/sudo0x/example-service
  tag: "1.0.0"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080
  targetPort: http

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

probes:
  liveness:
    enabled: true
    path: /actuator/health/liveness
    port: http
  readiness:
    enabled: true
    path: /actuator/health/readiness
    port: http
  startup:
    enabled: true
    path: /actuator/health
    port: http
```

The final values should be documented and should not copy complete Kubernetes manifests into `values.yaml`.

## Spring Boot health endpoints

The chart should support Spring Boot Actuator health endpoints.

Typical endpoints are:

```text
/actuator/health
/actuator/health/liveness
/actuator/health/readiness
```

The application must actually expose the configured endpoints. The Helm chart should not assume that every Spring Boot service uses the same path without documenting the requirement.

Example Spring Boot configuration:

```properties
management.endpoint.health.probes.enabled=true
management.health.livenessstate.enabled=true
management.health.readinessstate.enabled=true
```

The application and chart must agree on the port and paths before deployment.

## Environment variables and configuration

The chart should support:

### Non-sensitive values

Use a ConfigMap for values such as:

```text
SPRING_PROFILES_ACTIVE
SPRING_APPLICATION_NAME
REDIS_HOST
REDIS_PORT
```

### Sensitive values

Use references to an existing Kubernetes Secret for values such as:

```text
SPRING_DATA_REDIS_PASSWORD
DATABASE_PASSWORD
JWT_SECRET
```

Do not put real credentials directly in `values.yaml`, ConfigMaps, or Git.

The chart should support an explicit `env` and `envFrom` design, but it should avoid silently creating secrets from plain-text values unless there is a strong reason.

## Redis connection example

An application using the Redis chart could receive:

```yaml
env:
  - name: SPRING_DATA_REDIS_HOST
    value: redis-sudo0x-redis.infrastructure.svc.cluster.local
  - name: SPRING_DATA_REDIS_PORT
    value: "6379"
  - name: SPRING_DATA_REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: redis-production-credentials
        key: redis-password
```

The application chart should not hardcode the Redis release name. The host should be configurable through values or an environment variable.

## Security requirements

The future chart should use secure defaults:

```yaml
podSecurityContext:
  runAsNonRoot: true

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
```

The `readOnlyRootFilesystem` setting must be verified against the application. If the application writes temporary files, configure a specific `emptyDir` mount for the required path rather than disabling the control without investigation.

The chart should:

- Run containers as non-root where possible.
- Drop unnecessary Linux capabilities.
- Avoid privileged containers.
- Avoid host networking.
- Avoid hostPath volumes.
- Avoid exposing secrets in rendered ConfigMaps.

## Deployment behavior

The Deployment should use a rolling update strategy:

```yaml
strategy:
  type: RollingUpdate
```

The chart should allow configuration of:

- `maxUnavailable`.
- `maxSurge`.
- Pod termination grace period.
- Pod anti-affinity or topology spread.

The default replica count should remain small and predictable. A replica count greater than one requires the application to be stateless or to manage shared state correctly.

## Optional features

Add these only after the base Deployment works:

### Ingress

Ingress should be disabled by default:

```yaml
ingress:
  enabled: false
```

Do not expose services publicly without a clear hostname, TLS strategy, and authentication model.

### HorizontalPodAutoscaler

HPA should be disabled by default:

```yaml
autoscaling:
  enabled: false
```

HPA requires meaningful resource requests and a metrics server. It should not be enabled blindly.

### PodDisruptionBudget

PDB should be optional and should only be enabled when the replica count and availability requirements justify it.

## What not to include initially

Do not initially add:

- Redis as a chart dependency.
- PostgreSQL as a chart dependency.
- Kafka or RabbitMQ as a chart dependency.
- Service mesh configuration.
- Custom operators.
- External secret systems without an agreed platform standard.
- Automatic database migrations.
- Application source code.
- CI/CD workflows unrelated to the chart.

Keep infrastructure dependencies independent so they can be operated and upgraded separately.

## Implementation order

Implement the chart in this order:

1. Create `Chart.yaml`.
2. Create documented `values.yaml`.
3. Create reusable helpers.
4. Create the Deployment.
5. Create the ClusterIP Service.
6. Add resources and security contexts.
7. Add configurable probes.
8. Add ConfigMap support.
9. Add existing Secret references.
10. Add ServiceAccount support.
11. Add optional Ingress.
12. Add optional HPA.
13. Add optional PDB.
14. Add README usage examples.
15. Validate rendered output.
16. Package and publish the chart.

## Validation plan

Before installing:

```bash
helm lint charts/spring-boot-service
helm template example-service charts/spring-boot-service \
  --namespace applications
```

Render important variants:

```bash
helm template example-service charts/spring-boot-service \
  --namespace applications \
  --set image.repository=ghcr.io/sudo0x/example-service \
  --set image.tag=1.0.0
```

Verify:

- Deployment labels and selectors match.
- Service selectors match pod labels.
- Image repository and tag render correctly.
- Resources render correctly.
- Probes use the intended paths and ports.
- Secret values are referenced, not printed.
- Ingress is absent when disabled.
- HPA is absent when disabled.
- PDB is absent when disabled.

## Example future installation

After implementation and publication, an application might be installed like:

```bash
helm upgrade --install orders-service sudo0x/spring-boot-service \
  --namespace applications \
  --create-namespace \
  --set image.repository=ghcr.io/sudo0x/orders-service \
  --set image.tag=1.0.0
```

For real environments, prefer a values file:

```bash
helm upgrade --install orders-service sudo0x/spring-boot-service \
  --namespace applications \
  --create-namespace \
  --values environments/production/orders-service.yaml
```

## Production readiness questions

Before using the chart for a real service, answer:

- Is the service stateless?
- What health endpoints does it expose?
- What port does it listen on?
- Which configuration is non-sensitive?
- Which values must come from Secrets?
- Does it need Redis?
- Does it need a database?
- Does it need an Ingress?
- Does it need more than one replica?
- Can it handle rolling restarts?
- What are its resource requirements?
- What happens when Redis or the database is unavailable?
- How is the image built and scanned?
- How is the image version promoted?

## Final design principle

The reusable chart should standardize Kubernetes deployment behavior without hiding application-specific decisions.

The chart should provide safe defaults, but each microservice should explicitly configure:

- Image.
- Health endpoints.
- Resources.
- Environment.
- Secret references.
- Exposure requirements.
- Scaling requirements.
