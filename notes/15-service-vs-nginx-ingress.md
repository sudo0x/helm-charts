# Kubernetes Service vs NGINX Ingress Controller

This document explains why Kubernetes Services and the NGINX Ingress Controller are both used, and when an application needs one or both.

## Short answer

A Kubernetes Service and an NGINX Ingress Controller solve different problems:

```text
Service:
    Gives Pods a stable network endpoint.

NGINX Ingress Controller:
    Receives external HTTP/HTTPS traffic and routes it to Services.
```

The normal external application architecture is:

```text
Client
  ↓
NGINX Ingress Controller
  ↓
ClusterIP Service
  ↓
Application Pods
```

This is not usually a choice between Service and Ingress. The Service remains required, and the Ingress Controller is added when external HTTP/HTTPS routing is needed.

## What is a Kubernetes Service?

A Service provides a stable virtual IP and DNS name for a group of Pods.

Pods are temporary. They can be restarted, rescheduled, or replaced, and their IP addresses can change. A Service provides a stable endpoint while selecting the current healthy Pods.

Example:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: orders-service
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: orders
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

The Service sends traffic to Pods whose labels match:

```yaml
app.kubernetes.io/name: orders
```

Inside the cluster, another application can call:

```text
http://orders-service
```

Or, using the full DNS name:

```text
http://orders-service.applications-dev.svc.cluster.local
```

## Service types

### ClusterIP

`ClusterIP` is the default Service type. It is reachable only from inside the cluster.

Use it for:

- Internal Spring Boot services.
- Redis.
- PostgreSQL.
- RabbitMQ.
- Kafka.
- Services accessed through an Ingress Controller.

Example:

```yaml
service:
  type: ClusterIP
```

### NodePort

`NodePort` opens a port on every Kubernetes node.

Traffic is accessed using:

```text
node-address:node-port
```

NodePort can be useful for simple development testing, but it is usually not the preferred production entry point.

### LoadBalancer

`LoadBalancer` asks the cluster or cloud provider for an external load balancer.

Example:

```yaml
service:
  type: LoadBalancer
```

This can be appropriate when one application needs a dedicated external endpoint, but using a separate load balancer for every application can increase cost and operational complexity.

## What is an NGINX Ingress Controller?

The NGINX Ingress Controller is software running inside Kubernetes. It watches Kubernetes Ingress resources and configures NGINX to route HTTP and HTTPS requests.

In this repository, it was installed with the official Helm chart:

```text
Chart:     ingress-nginx/ingress-nginx
Release:   ingress-nginx
Namespace: ingress-nginx
Class:     nginx
```

The controller is shared infrastructure. It can route traffic for many applications.

## What is an Ingress resource?

An Ingress resource is a Kubernetes object containing HTTP/HTTPS routing rules.

Example:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orders
spec:
  ingressClassName: nginx
  rules:
    - host: orders.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: orders-service
                port:
                  number: 80
```

This rule says:

```text
Requests for orders.example.com
    should be sent to orders-service on port 80.
```

The Ingress resource does not route traffic by itself. The NGINX Ingress Controller reads the resource and applies the rule.

## How Service and Ingress work together

The complete request flow is:

```text
Client
  ↓ HTTP/HTTPS
NGINX Ingress Controller
  ↓ matches hostname or path
Ingress rule
  ↓ selects backend
Kubernetes Service
  ↓ selects matching Pods
Spring Boot application Pods
```

The Service remains responsible for stable discovery and Pod load balancing. The Ingress Controller is responsible for external HTTP/HTTPS routing.

## Using only a Service

Use only a Service when the application is internal:

```text
Another Kubernetes Pod
        ↓
ClusterIP Service
        ↓
Application Pods
```

Example internal request:

```text
http://orders-service:8080
```

This is the preferred pattern for:

- Service-to-service communication.
- Internal administration endpoints.
- Redis connections.
- PostgreSQL connections.
- RabbitMQ connections.
- Kafka connections.

These infrastructure services generally should not be exposed through public HTTP Ingress.

## Using a LoadBalancer Service directly

An application can be exposed without Ingress:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: orders-service
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: orders
  ports:
    - port: 80
      targetPort: 8080
```

The architecture is:

```text
Client
  ↓
External LoadBalancer
  ↓
orders-service
  ↓
Application Pods
```

This can be simple for one application. However, multiple applications may require multiple external load balancers:

```text
orders-service   → LoadBalancer 1
users-service    → LoadBalancer 2
payments-service → LoadBalancer 3
```

Depending on the environment, this may cost more and require more external configuration.

## Using one shared NGINX Ingress Controller

With one shared controller:

```text
One external entry point
        ↓
NGINX Ingress Controller
        ├── orders.example.com   → orders-service
        ├── users.example.com    → users-service
        └── payments.example.com → payments-service
```

Each application can continue to use:

```yaml
service:
  type: ClusterIP
```

This gives the cluster one HTTP/HTTPS entry point while keeping application Services internal.

## Advantages of Ingress

An Ingress Controller can centralize:

- Host-based routing.
- Path-based routing.
- HTTP and HTTPS entry points.
- TLS termination.
- Shared external IP or load balancer.
- Request size limits.
- Proxy timeouts.
- Redirects.
- Authentication integrations.
- Rate limiting.
- Access logging.

The exact features depend on the selected controller and configuration.

## Multiple Spring Boot services

The recommended design for several applications is:

```text
Shared NGINX Ingress Controller
        ├── orders-service Ingress → orders-service Service
        ├── users-service Ingress → users-service Service
        ├── payments-service Ingress → payments-service Service
        └── notifications-service Ingress → notifications-service Service
```

Each application should have:

- A unique Helm release.
- A separate Deployment.
- A separate Service.
- A separate Ingress resource.
- A unique hostname or non-conflicting path.

Do not install another NGINX controller for every application.

## Example Spring Boot chart values

Enable Ingress in the reusable application chart:

```yaml
service:
  type: ClusterIP
  port: 8080
  targetPort: http

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: orders.example.com
      paths:
        - path: /
          pathType: Prefix
```

The chart creates the application Service and Ingress resource. The already-installed NGINX controller processes the Ingress resource.

## When to use only a Service

Use only a Service when:

- The application is internal-only.
- Another Pod calls it.
- No public HTTP/HTTPS access is required.
- You are running a simple development test.
- You want the fewest moving parts.

Use a `ClusterIP` Service by default.

## When to use Ingress

Use an Ingress Controller when:

- Users access the application from outside the cluster.
- Multiple applications share one external address.
- You need domain-based routing.
- You need path-based routing.
- You need HTTPS and TLS termination.
- You want centralized HTTP configuration.

The application still needs a Service behind the Ingress.

## What should not use ordinary HTTP Ingress?

Do not expose these infrastructure components through ordinary public HTTP Ingress:

- Redis.
- PostgreSQL.
- RabbitMQ AMQP.
- Kafka.

Keep them internal and connect using their Kubernetes Service DNS names. If external access is genuinely required, use a protocol-appropriate, authenticated, encrypted, and restricted exposure design.

## Troubleshooting

Check Services:

```bash
kubectl get services \
  --namespace applications-dev
```

Check Service endpoints:

```bash
kubectl get endpoints \
  --namespace applications-dev
```

Check Ingress resources:

```bash
kubectl get ingress \
  --namespace applications-dev
```

Inspect an Ingress:

```bash
kubectl describe ingress \
  --namespace applications-dev
```

Check the controller:

```bash
kubectl get pods \
  --namespace ingress-nginx
```

Check controller logs:

```bash
kubectl logs deployment/ingress-nginx-controller \
  --namespace ingress-nginx
```

Common issues include:

- The Service selector does not match Pod labels.
- The Service has no ready endpoints.
- The Ingress hostname does not match the request.
- The wrong `ingressClassName` is used.
- DNS points to the wrong address.
- The application container port and Service target port do not match.
- The application Pod is not ready.

## Final comparison

Internal application:

```text
ClusterIP Service
        ↓
Application Pods
```

External application:

```text
Client
        ↓
NGINX Ingress Controller
        ↓
ClusterIP Service
        ↓
Application Pods
```

The Service provides stable access to Pods. The NGINX Ingress Controller provides shared external HTTP/HTTPS routing. In a normal Kubernetes application architecture, both are used together.
