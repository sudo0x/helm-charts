# NGINX Ingress Controller Explained

This document explains why the NGINX Ingress Controller was installed from the official Helm chart instead of being recreated as a custom chart in this repository.

## The short version

There are two different things:

```text
1. NGINX Ingress Controller
   Receives external traffic and routes it inside Kubernetes.

2. Kubernetes Ingress resource
   Describes which hostname and path should route to which Service.
```

The controller does the work. The Ingress resource provides the routing rules.

## What was installed

The official NGINX Ingress Controller chart was installed as a separate Helm release:

```text
Helm repository: ingress-nginx
Chart:           ingress-nginx/ingress-nginx
Release:         ingress-nginx
Namespace:       ingress-nginx
IngressClass:    nginx
```

The Helm repository is:

```text
https://kubernetes.github.io/ingress-nginx
```

Inspect the installation:

```bash
helm list --all-namespaces

helm status ingress-nginx \
  --namespace ingress-nginx

helm get values ingress-nginx \
  --namespace ingress-nginx

kubectl get pods \
  --namespace ingress-nginx

kubectl get ingressclass
```

## Why use the official chart?

The official chart already includes and maintains the components required for a reliable controller:

- NGINX controller Deployment.
- Controller Service.
- LoadBalancer or NodePort exposure.
- Admission webhook.
- RBAC permissions.
- ServiceAccount.
- ClusterRole and RoleBindings.
- `IngressClass` configuration.
- Kubernetes compatibility updates.
- Security and configuration options.
- Upgrade and rollback support.

Recreating all these resources manually would duplicate a large amount of community-maintained work. It would also make security updates and Kubernetes version compatibility the responsibility of this project.

Using the official chart does not mean that the controller is mixed into an application chart. It remains a separate Helm release with its own namespace, configuration, upgrade cycle, and rollback history.

## The application chart

The Spring Boot application chart is separate:

```text
charts/spring-boot-service/
```

It creates application resources such as:

- Deployment.
- ServiceAccount.
- ClusterIP Service.
- Optional Ingress resource.

It does not install the NGINX controller.

The application chart creates only a routing rule when this value is enabled:

```yaml
ingress:
  enabled: true
  className: nginx
```

The important field is:

```yaml
spec:
  ingressClassName: nginx
```

This tells Kubernetes that the installed controller named `nginx` should process the Ingress.

## How the pieces connect

The complete design is:

```text
Official ingress-nginx Helm chart
        ↓
NGINX Ingress Controller
        ↓ watches
Kubernetes Ingress resource
        ↓ routes to
Application Service
        ↓ selects
Application Pod
```

Example:

```text
http://orders.local/
        ↓
NGINX Ingress Controller
        ↓
Ingress rule for orders.local
        ↓
orders-service Service
        ↓
orders-service Pod
```

## Example Ingress configuration

The Spring Boot chart can be configured with:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations: {}
  hosts:
    - host: orders.local
      paths:
        - path: /
          pathType: Prefix
  tls: []
```

This produces an Ingress object similar to:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orders-service
spec:
  ingressClassName: nginx
  rules:
    - host: orders.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: orders-service
                port:
                  name: http
```

The exact generated name depends on the Helm release name and chart name.

## NGINX is not the Spring Boot application

The NGINX controller is an entry point and reverse proxy. It is not your business application.

The intended production flow is:

```text
Internet or internal client
        ↓
NGINX Ingress Controller
        ↓
Spring Boot application Service
        ↓
Spring Boot application Pods
```

The application image should be your real Spring Boot image, for example:

```yaml
image:
  repository: ghcr.io/sudo0x/orders-service
  tag: "1.0.0"
```

## About the temporary `nginx:1.27` image

The initial Spring Boot chart currently uses:

```yaml
image:
  repository: nginx
  tag: "1.27"
```

This is only a placeholder image so the generic chart can render and run during basic testing. It is not a Spring Boot application.

Before deploying a real service, replace it with the actual application image:

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

## Current cluster resources

The controller is installed in its own namespace:

```bash
kubectl get all \
  --namespace ingress-nginx
```

Important resources include:

```text
Deployment:  ingress-nginx-controller
Service:     ingress-nginx-controller
IngressClass: nginx
```

The controller Service currently provides HTTP and HTTPS entry points. Always inspect the current addresses because they depend on the cluster:

```bash
kubectl get service ingress-nginx-controller \
  --namespace ingress-nginx \
  --wide
```

## Installing an application Ingress

The controller can be installed without any application routes. It waits for Ingress resources to appear.

Install an application with Ingress enabled:

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

Inspect the route:

```bash
kubectl get ingress \
  --namespace applications-dev

kubectl describe ingress \
  --namespace applications-dev
```

## Local hostname testing

For a local hostname such as `orders.local`, the client computer must resolve that name to the controller address.

On Windows, edit this file as Administrator:

```text
C:\Windows\System32\drivers\etc\hosts
```

Add a line using a current controller address:

```text
192.168.18.221 orders.local
```

Then test:

```bash
curl.exe -H "Host: orders.local" http://192.168.18.221/
```

The request will work only when the application Pod is ready, the Service has endpoints, and the hostname matches the Ingress rule.

## TLS and HTTPS

The controller supports HTTPS, but installing the controller does not automatically create certificates.

An application must provide a TLS Secret:

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

Then configure the chart:

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

For production, use an approved certificate management process such as cert-manager or a managed cloud certificate integration.

## Why not create a custom controller chart?

A custom wrapper could be useful later for organization-wide defaults, but it should reference the official chart rather than copy it.

Possible future wrapper responsibilities:

- Pin an approved controller chart version.
- Set the standard IngressClass name.
- Configure the approved Service type.
- Apply organization-wide resource limits.
- Configure approved annotations.
- Define environment-specific controller values.

The wrapper should still use the official `ingress-nginx` chart as a dependency. Copying the controller templates into this repository would make updates and security maintenance harder.

## Removing the controller

Remove the separate Helm release with:

```bash
helm uninstall ingress-nginx \
  --namespace ingress-nginx
```

Before removing it, check whether applications depend on its Ingress routes:

```bash
kubectl get ingress \
  --all-namespaces
```

Do not remove the controller while required application routes are still in use.

## Final summary

The repository and cluster now have a clean separation:

```text
Official ingress-nginx chart
    installs the shared NGINX controller

Spring Boot application chart
    installs the application and optional Ingress rules

Application Ingress rules
    tell the controller where to route traffic
```

The controller is shared infrastructure. Each application chart should create only its own Deployment, Service, and optional Ingress resource.
