# Ingress Setup and Changes

Date: 2026-09-20

This document records what was added to the repository and what was installed in the Kubernetes cluster when Ingress support was requested.

## What was done

Two separate changes were made:

1. Added optional Ingress support to a new reusable Spring Boot application Helm chart.
2. Installed the official `ingress-nginx` controller into the Kubernetes cluster.

These are different responsibilities:

```text
Spring Boot chart
        creates an Ingress routing object

ingress-nginx controller
        watches Ingress objects and receives HTTP/HTTPS traffic
```

Creating an Ingress object alone does not route traffic. An Ingress controller is required.

## Repository changes

The following local chart was created:

```text
charts/spring-boot-service/
├── Chart.yaml
├── README.md
├── values.yaml
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── ingress.yaml
    ├── service.yaml
    └── serviceaccount.yaml
```

This is an initial application chart, not a finished production application platform.

### Chart resources

When installed, the chart can create:

- A `Deployment`.
- A `ServiceAccount`.
- A `ClusterIP` `Service`.
- An optional `Ingress`.

The Ingress is disabled by default:

```yaml
ingress:
  enabled: false
```

The chart uses the example `nginx:1.27` image by default so that the chart can render and run for basic testing. Replace it with the real Spring Boot image before using it for an application.

## Ingress chart configuration

Ingress can be enabled with values such as:

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

The chart generates a Kubernetes `networking.k8s.io/v1` Ingress that routes:

```text
orders.local/
        ↓
Spring Boot chart Service
```

The host, paths, Ingress class, annotations, and TLS entries are configurable. No DNS record or TLS certificate was created automatically.

## Cluster changes

The official `ingress-nginx` Helm repository was added locally:

```text
https://kubernetes.github.io/ingress-nginx
```

Then the official `ingress-nginx/ingress-nginx` chart was installed as:

```text
Helm release: ingress-nginx
Namespace:    ingress-nginx
```

The release can be inspected with:

```bash
helm status ingress-nginx --namespace ingress-nginx
```

The controller created cluster resources including:

- A controller Deployment.
- A controller Pod.
- A `LoadBalancer` Service.
- An admission Webhook Service.
- A default `IngressClass` named `nginx`.
- ServiceAccounts, Roles, ClusterRoles, and bindings.
- A validating webhook configuration.
- A controller ConfigMap.

The controller Pod was running successfully:

```text
ingress-nginx-controller   1/1   Running
```

The `nginx` IngressClass was configured as the default class:

```text
nginx (default)
```

## Controller network addresses

The controller Service currently reports:

```text
Type:        LoadBalancer
Cluster IP:  10.43.55.186
Addresses:   192.168.18.221, 192.168.18.222
HTTP:        80:30131
HTTPS:       443:31675
```

The addresses are provided by the local K3s environment. They are cluster-specific and should not be copied as production infrastructure values without checking the current Service status.

Inspect the current values:

```bash
kubectl get svc ingress-nginx-controller \
  --namespace ingress-nginx \
  --wide
```

Inspect all controller resources:

```bash
kubectl get all \
  --namespace ingress-nginx

kubectl get ingressclass
```

## How traffic will work

After deploying an application chart with Ingress enabled:

```text
Client
  ↓
orders.local
  ↓
192.168.18.221 or 192.168.18.222
  ↓
ingress-nginx-controller
  ↓
Ingress rule
  ↓
Spring Boot Service
  ↓
Spring Boot Pod
```

The application Service remains internal to Kubernetes. The Ingress controller is the component that accepts external HTTP or HTTPS traffic.

## Example application installation

First choose a real application image:

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

Check the generated resources:

```bash
kubectl get all \
  --namespace applications-dev

kubectl get ingress \
  --namespace applications-dev

kubectl describe ingress \
  --namespace applications-dev
```

The application image must listen on the configured container port, which defaults to `8080`. The application should also expose the configured health endpoint if probes are enabled.

## Local hostname testing

For local testing, the client machine must resolve the hostname to a controller address. On Windows, edit the hosts file as Administrator:

```text
C:\Windows\System32\drivers\etc\hosts
```

Add a line such as:

```text
192.168.18.221 orders.local
```

Then test:

```bash
curl.exe -H "Host: orders.local" http://192.168.18.221/
```

The request will only return the expected application response when:

- The application chart is installed.
- The application Pod is ready.
- The Service has ready endpoints.
- The Ingress host matches the request.
- The controller address is reachable from the client machine.

## TLS

TLS was not configured automatically. A TLS Ingress requires a Kubernetes Secret containing a certificate and private key:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: orders-tls
  namespace: applications-dev
type: kubernetes.io/tls
data:
  tls.crt: <base64-certificate>
  tls.key: <base64-private-key>
```

Then configure:

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

For production, use a managed certificate process such as cert-manager or an approved cloud load balancer certificate integration.

## What was not done

The following were not created or changed automatically:

- No Spring Boot application source code.
- No real application image.
- No DNS records.
- No TLS certificates.
- No public cloud load balancer.
- No production domain.
- No Ingress resource for an application.
- No changes to Redis, PostgreSQL, RabbitMQ, or Kafka releases.
- No GitHub push for the new Spring Boot chart yet.

The controller is installed, but it will not route application traffic until an application Service and matching Ingress object exist.

## Removing the controller

If the controller is no longer wanted, remove the Helm release:

```bash
helm uninstall ingress-nginx --namespace ingress-nginx
```

The namespace can then be removed only after checking that it contains no resources you want to keep:

```bash
kubectl get all --namespace ingress-nginx
kubectl delete namespace ingress-nginx
```

Do not remove the controller while applications still depend on its Ingress routes.

## Current status summary

```text
Spring Boot chart: created locally
Ingress template: available and disabled by default
Ingress controller: installed in ingress-nginx
IngressClass: nginx and default
Controller Pod: running
Application Ingress: not deployed
DNS: not configured
TLS: not configured
GitHub: Spring Boot chart changes not pushed yet
```

The current setup is suitable for learning and development. Production use requires a real application image, DNS, TLS, resource sizing, access control, monitoring, and a reviewed network exposure policy.
