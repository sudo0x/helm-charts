# Multiple Spring Boot Services with One NGINX Ingress Controller

This document explains how to deploy multiple Spring Boot applications while sharing one existing NGINX Ingress Controller.

## Main concept

You normally install one shared NGINX Ingress Controller per cluster or environment, not one controller per application.

Each application has its own:

- Helm release.
- Deployment.
- Kubernetes Service.
- Ingress resource.
- Hostname or URL path.

The controller reads all compatible Ingress resources and routes requests to the correct Service.

```text
One NGINX Ingress Controller
        ├── orders-service Ingress
        ├── users-service Ingress
        ├── payments-service Ingress
        └── notifications-service Ingress
```

## Existing cluster setup

The current controller is installed as:

```text
Helm chart:  ingress-nginx/ingress-nginx
Release:     ingress-nginx
Namespace:   ingress-nginx
Class:       nginx
```

Applications use this controller with:

```yaml
ingress:
  enabled: true
  className: nginx
```

Do not install another controller for every Spring Boot service.

## Host-based routing

The recommended approach for independent services is to use a different hostname for each application:

```text
orders.example.com  → orders-service
users.example.com   → users-service
payments.example.com → payments-service
```

The client sends the hostname in the HTTP `Host` header. NGINX uses that hostname to select the matching Ingress rule.

The traffic flow is:

```text
Client
  ↓
orders.example.com
  ↓
Shared NGINX Ingress Controller
  ↓
orders-service Ingress
  ↓
orders-service Kubernetes Service
  ↓
orders-service Pod
```

## Deploy the first service

Deploy an orders application:

```bash
helm upgrade --install orders-service \
  charts/spring-boot-service \
  --namespace applications-dev \
  --create-namespace \
  --set image.repository=ghcr.io/sudo0x/orders-service \
  --set image.tag=1.0.0 \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=orders.local \
  --wait
```

This creates an Ingress rule for:

```text
orders.local
```

## Deploy the second service

Deploy a users application using the same chart and the same NGINX controller:

```bash
helm upgrade --install users-service \
  charts/spring-boot-service \
  --namespace applications-dev \
  --set image.repository=ghcr.io/sudo0x/users-service \
  --set image.tag=1.0.0 \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=users.local \
  --wait
```

This creates a separate Ingress rule for:

```text
users.local
```

The two applications have separate Helm releases and Kubernetes resources, but share the same controller.

## Verify the applications

List deployments:

```bash
kubectl get deployments \
  --namespace applications-dev
```

List Services:

```bash
kubectl get services \
  --namespace applications-dev
```

List Ingress resources:

```bash
kubectl get ingress \
  --namespace applications-dev
```

Inspect one route:

```bash
kubectl describe ingress orders-service-sudo0x-spring-boot-service \
  --namespace applications-dev
```

The generated resource name depends on the Helm release name and chart name. Use `kubectl get ingress` to find the exact name.

## Local hostname testing

For local development, both hostnames can point to the same NGINX controller address.

On Windows, edit this file as Administrator:

```text
C:\Windows\System32\drivers\etc\hosts
```

Add entries using a current controller address:

```text
192.168.18.221 orders.local
192.168.18.221 users.local
```

Inspect the current address:

```bash
kubectl get service ingress-nginx-controller \
  --namespace ingress-nginx \
  --wide
```

Test the services:

```bash
curl.exe http://orders.local/
curl.exe http://users.local/
```

If DNS or the hosts file is not configured, test with the Host header:

```bash
curl.exe -H "Host: orders.local" http://192.168.18.221/
curl.exe -H "Host: users.local" http://192.168.18.221/
```

The request will work only when the application Pod is ready, the Service has endpoints, the hostname matches the Ingress rule, and the controller address is reachable.

## Production DNS

In production, create DNS records that point each hostname to the same load balancer or controller address:

```text
orders.example.com   A   203.0.113.20
users.example.com    A   203.0.113.20
payments.example.com A   203.0.113.20
```

The actual address depends on the cluster and load balancer. Do not copy the example address.

Then configure each application with its own hostname:

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

## Path-based routing alternative

Multiple applications can also share one hostname:

```text
api.example.com/orders → orders-service
api.example.com/users  → users-service
```

The orders release could use:

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: api.example.com
      paths:
        - path: /orders
          pathType: Prefix
```

The users release could use:

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: api.example.com
      paths:
        - path: /users
          pathType: Prefix
```

Host-based routing is usually simpler for independent Spring Boot services because each service receives requests at its own root path. Path-based routing may require the application to understand its URL prefix or an NGINX rewrite configuration.

## TLS for multiple services

Each hostname can use a separate TLS Secret:

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: orders.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: orders-tls
      hosts:
        - orders.example.com
```

The users service can use its own Secret:

```yaml
tls:
  - secretName: users-tls
    hosts:
      - users.example.com
```

Another option is one wildcard certificate:

```text
*.example.com
```

For production, use an approved certificate management process such as cert-manager or a managed cloud certificate integration.

## Namespace considerations

Ingress resources are namespace-scoped. An Ingress normally routes to Services in the same namespace.

You can place all application releases in one namespace:

```text
applications-dev
```

Or separate them:

```text
orders-dev
users-dev
```

When using separate namespaces, install each release in its intended namespace and ensure the relevant Secrets and Services exist there.

## Important rules

- Use one shared NGINX controller for many applications.
- Give each application a unique Helm release name.
- Give each application a unique hostname or non-conflicting path.
- Keep each application’s Deployment, Service, and Ingress together in its namespace.
- Ensure DNS points to the NGINX controller address.
- Configure TLS before exposing production applications.
- Ensure application container ports match the Service target port.
- Ensure readiness probes represent real application readiness.
- Do not expose Redis, PostgreSQL, RabbitMQ, or Kafka publicly through ordinary HTTP Ingress.

## Troubleshooting

Check the controller:

```bash
kubectl get pods \
  --namespace ingress-nginx
```

Check application Pods:

```bash
kubectl get pods \
  --namespace applications-dev
```

Check Service endpoints:

```bash
kubectl get endpoints \
  --namespace applications-dev
```

Check Ingress events:

```bash
kubectl describe ingress \
  --namespace applications-dev
```

Check controller logs:

```bash
kubectl logs deployment/ingress-nginx-controller \
  --namespace ingress-nginx
```

Common problems include:

- The hostname does not match the Ingress rule.
- DNS or the local hosts file points to the wrong address.
- The application Pod is not ready.
- The Service selector does not match Pod labels.
- The Service target port does not match the container port.
- The wrong `ingressClassName` is configured.
- TLS Secret is missing or in the wrong namespace.

## Final architecture

```text
Shared NGINX Ingress Controller
        ├── orders.example.com  → orders-service
        ├── users.example.com   → users-service
        ├── payments.example.com → payments-service
        └── notifications.example.com → notifications-service
```

Each application is independently deployed and upgraded, while the NGINX controller remains shared cluster infrastructure.
