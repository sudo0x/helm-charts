# Kubernetes Connectivity Troubleshooting Cheat Sheet

This guide provides practical commands for diagnosing connection problems between clients, Ingress, Services, Pods, and infrastructure components.

The general troubleshooting path is:

```text
Client
  ↓
DNS or hosts file
  ↓
Ingress Controller or LoadBalancer
  ↓
Ingress rule
  ↓
Kubernetes Service
  ↓
Service endpoints
  ↓
Pod and container port
  ↓
Application process
```

Start at the layer where the failure occurs. Do not change several resources at once before identifying the failing layer.

## 1. Confirm the cluster and namespace

Check the active Kubernetes context:

```powershell
kubectl config current-context
```

Check the cluster:

```powershell
kubectl cluster-info
kubectl get nodes -o wide
```

Set a namespace explicitly on important commands:

```powershell
$namespace = "applications-dev"
kubectl get all --namespace $namespace
```

Check the namespace:

```powershell
kubectl get namespace applications-dev
```

## 2. Check Pod health

List Pods with node and IP information:

```powershell
kubectl get pods --namespace applications-dev -o wide
```

Inspect a Pod:

```powershell
kubectl describe pod <pod-name> --namespace applications-dev
```

Check recent events:

```powershell
kubectl get events `
  --namespace applications-dev `
  --sort-by=.lastTimestamp
```

View application logs:

```powershell
kubectl logs <pod-name> --namespace applications-dev --tail=100
kubectl logs <pod-name> --namespace applications-dev --follow
```

View logs from a previous crashed container:

```powershell
kubectl logs <pod-name> `
  --namespace applications-dev `
  --previous
```

Check readiness:

```powershell
kubectl get pod <pod-name> `
  --namespace applications-dev `
  -o jsonpath="{.status.conditions}"
```

A Pod may be `Running` but still unavailable if its readiness probe is failing.

## 3. Check the application process and port

Inspect the rendered container port:

```powershell
kubectl get pod <pod-name> `
  --namespace applications-dev `
  -o jsonpath="{.spec.containers[*].ports}"
```

Open a shell in the container:

```powershell
kubectl exec -it <pod-name> `
  --namespace applications-dev `
  -- sh
```

Inside the container, check listening ports when tools are available:

```text
ss -lnt
netstat -lnt
```

Test the application locally from inside its own container:

```text
curl http://127.0.0.1:8080/actuator/health
```

If localhost fails, the problem is inside the application or container. Ingress and Services cannot fix an application that is not listening.

## 4. Test with a temporary network Pod

Create a temporary curl client:

```powershell
kubectl run network-test `
  --rm -it `
  --restart=Never `
  --image=curlimages/curl `
  -- sh
```

Inside the temporary Pod:

```text
curl -v http://orders-service:8080/actuator/health
```

Resolve a Service name:

```text
nslookup orders-service
```

Test a fully qualified Service name:

```text
curl -v http://orders-service.applications-dev.svc.cluster.local:8080/actuator/health
```

Exit the temporary Pod:

```text
exit
```

If the temporary image cannot be pulled, inspect the Pod events:

```powershell
kubectl get events --sort-by=.lastTimestamp
```

## 5. Check the Service

List Services:

```powershell
kubectl get services --namespace applications-dev -o wide
```

Inspect a Service:

```powershell
kubectl describe service orders-service --namespace applications-dev
```

Important fields include:

```text
Type
ClusterIP
Port
TargetPort
Selector
Endpoints
```

Check the Service selector:

```powershell
kubectl get service orders-service `
  --namespace applications-dev `
  -o jsonpath="{.spec.selector}"
```

Check the endpoints:

```powershell
kubectl get endpoints orders-service `
  --namespace applications-dev `
  -o wide
```

Check EndpointSlices:

```powershell
kubectl get endpointslices `
  --namespace applications-dev `
  -l kubernetes.io/service-name=orders-service
```

If a Service has no endpoints, check:

- The Pod labels.
- The Service selector.
- Pod readiness.
- The namespace.
- Whether the application container is ready.

Show Pod labels:

```powershell
kubectl get pods `
  --namespace applications-dev `
  --show-labels
```

## 6. Test a Service with port-forwarding

Port-forward a Service:

```powershell
kubectl port-forward `
  --namespace applications-dev `
  service/orders-service `
  8080:80
```

Then test from another terminal:

```powershell
curl.exe http://127.0.0.1:8080/actuator/health
```

Port-forward a Pod:

```powershell
kubectl port-forward `
  --namespace applications-dev `
  pod/<pod-name> `
  8080:8080
```

Interpretation:

```text
Pod port-forward fails:
    Application or container port problem.

Pod works but Service port-forward fails:
    Service selector, port, or targetPort problem.

Service works but Ingress fails:
    Ingress, DNS, controller, or external access problem.
```

## 7. Check Service port mapping

Show the complete Service:

```powershell
kubectl get service orders-service `
  --namespace applications-dev `
  -o yaml
```

Verify the mapping:

```text
Service port: 80
targetPort: 8080
Container port: 8080
Application listening port: 8080
```

The Service `targetPort` must reach the port where the application actually listens. A named `targetPort` must match a named container port.

## 8. Test Kubernetes DNS

Start a DNS test Pod:

```powershell
kubectl run dns-test `
  --rm -it `
  --restart=Never `
  --image=busybox:1.36 `
  -- nslookup orders-service.applications-dev.svc.cluster.local
```

Check CoreDNS:

```powershell
kubectl get pods --namespace kube-system -l k8s-app=kube-dns
kubectl get service kube-dns --namespace kube-system
```

Inspect CoreDNS logs:

```powershell
kubectl logs `
  --namespace kube-system `
  -l k8s-app=kube-dns `
  --tail=100
```

Service DNS patterns:

```text
service-name
service-name.namespace
service-name.namespace.svc
service-name.namespace.svc.cluster.local
```

DNS names are namespace-sensitive. A Service in `infrastructure-dev` is not resolved by short name from `applications-dev` unless the namespace is included.

## 9. Check Ingress

List Ingress resources:

```powershell
kubectl get ingress --all-namespaces
```

Inspect an Ingress:

```powershell
kubectl describe ingress <ingress-name> `
  --namespace applications-dev
```

Show the generated object:

```powershell
kubectl get ingress <ingress-name> `
  --namespace applications-dev `
  -o yaml
```

Verify:

- `ingressClassName` is `nginx`.
- Hostname matches the request.
- Path and `pathType` are correct.
- Backend Service name is correct.
- Backend Service port is correct.
- The backend Service has endpoints.

Check the IngressClass:

```powershell
kubectl get ingressclass
```

## 10. Check the NGINX controller

List controller Pods:

```powershell
kubectl get pods --namespace ingress-nginx -o wide
```

Check the controller Service:

```powershell
kubectl get service ingress-nginx-controller `
  --namespace ingress-nginx `
  --wide
```

Inspect the controller:

```powershell
kubectl describe deployment ingress-nginx-controller `
  --namespace ingress-nginx
```

Read controller logs:

```powershell
kubectl logs deployment/ingress-nginx-controller `
  --namespace ingress-nginx `
  --tail=200
```

Check the Helm release:

```powershell
helm status ingress-nginx --namespace ingress-nginx
```

Check controller events:

```powershell
kubectl get events `
  --namespace ingress-nginx `
  --sort-by=.lastTimestamp
```

## 11. Test external Ingress traffic

Get the controller address:

```powershell
kubectl get service ingress-nginx-controller `
  --namespace ingress-nginx `
  -o wide
```

Test with a Host header:

```powershell
curl.exe -v `
  -H "Host: orders.local" `
  http://192.168.18.221/
```

Test a hostname:

```powershell
curl.exe -v http://orders.local/
```

If the Host-header request works but the hostname request fails, DNS or the local hosts file is incorrect.

On Windows, inspect the hosts file:

```text
C:\Windows\System32\drivers\etc\hosts
```

Example entry:

```text
192.168.18.221 orders.local
```

Check local DNS resolution:

```powershell
Resolve-DnsName orders.local
```

## 12. Test HTTP status and redirects

Show response headers:

```powershell
curl.exe -I -H "Host: orders.local" http://192.168.18.221/
```

Follow redirects:

```powershell
curl.exe -L -v -H "Host: orders.local" http://192.168.18.221/
```

Useful status meanings:

```text
200:
    Request succeeded.

301 or 308:
    Redirect, often HTTP to HTTPS.

404:
    No matching Ingress rule or application route.

502:
    NGINX cannot reach the backend Service or application.

503:
    Service has no ready backend endpoints.

504:
    Backend connection or response timed out.
```

## 13. Test TLS

Show TLS configuration:

```powershell
kubectl get ingress <ingress-name> `
  --namespace applications-dev `
  -o jsonpath="{.spec.tls}"
```

Check the TLS Secret:

```powershell
kubectl get secret orders-tls `
  --namespace applications-dev
```

Inspect Secret metadata:

```powershell
kubectl describe secret orders-tls `
  --namespace applications-dev
```

Test HTTPS:

```powershell
curl.exe -vk `
  -H "Host: orders.example.com" `
  https://192.168.18.221/
```

Common TLS problems:

- Secret does not exist.
- Secret is in the wrong namespace.
- Secret is not type `kubernetes.io/tls`.
- Certificate hostname does not match the request.
- DNS points to another load balancer.
- HTTP-to-HTTPS redirect is expected but HTTPS is not configured.

## 14. Test Redis connectivity

Find the Redis Service:

```powershell
kubectl get service --all-namespaces | Select-String redis
```

Start a Redis client Pod:

```powershell
kubectl run redis-test `
  --rm -it `
  --restart=Never `
  --image=redis:8.2 `
  -- redis-cli -h <redis-service> -p 6379 ping
```

With authentication:

```powershell
kubectl run redis-test `
  --rm -it `
  --restart=Never `
  --image=redis:8.2 `
  -- redis-cli -h <redis-service> -p 6379 -a '<password>' ping
```

Expected response:

```text
PONG
```

Check the Redis endpoints:

```powershell
kubectl get endpoints <redis-service> --namespace infrastructure-dev
```

## 15. Test PostgreSQL connectivity

Start a PostgreSQL client Pod:

```powershell
kubectl run postgres-test `
  --rm -it `
  --restart=Never `
  --image=postgres:16 `
  --env="PGPASSWORD=<password>" `
  -- psql -h <postgres-service> -U <username> -d <database> -c "select 1;"
```

Test readiness:

```powershell
kubectl run postgres-test `
  --rm -it `
  --restart=Never `
  --image=postgres:16 `
  -- pg_isready -h <postgres-service> -p 5432
```

Expected readiness output includes:

```text
accepting connections
```

Check the PostgreSQL Service:

```powershell
kubectl describe service <postgres-service> `
  --namespace infrastructure-dev
```

## 16. Test RabbitMQ connectivity

Check RabbitMQ ports:

```powershell
kubectl get service <rabbitmq-service> `
  --namespace infrastructure-dev
```

Test the AMQP TCP port:

```powershell
kubectl run tcp-test `
  --rm -it `
  --restart=Never `
  --image=busybox:1.36 `
  -- sh -c "nc -vz <rabbitmq-service> 5672"
```

Test the management HTTP endpoint:

```powershell
kubectl run rabbitmq-http-test `
  --rm -it `
  --restart=Never `
  --image=curlimages/curl `
  -- curl -v http://<rabbitmq-service>:15672/
```

TCP connectivity does not prove that credentials, vhosts, exchanges, or queues are correctly configured.

## 17. Test Kafka connectivity

Check Kafka Services:

```powershell
kubectl get service --namespace infrastructure-dev | Select-String kafka
```

Start a Kafka client using the Apache Kafka image:

```powershell
kubectl run kafka-test `
  --rm -it `
  --restart=Never `
  --image=apache/kafka:4.3.1 `
  -- bash
```

Inside the client Pod, list topics:

```text
/opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server <kafka-service>:9092 \
  --list
```

Describe a topic:

```text
/opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server <kafka-service>:9092 \
  --describe \
  --topic <topic-name>
```

Kafka connectivity can fail even when port `9092` is reachable if `advertised.listeners` returns a hostname that the client cannot resolve.

Check Kafka logs and advertised listener configuration:

```powershell
kubectl logs statefulset/<kafka-statefulset> `
  --namespace infrastructure-dev `
  --tail=200
```

## 18. Check NetworkPolicies

List policies:

```powershell
kubectl get networkpolicies --all-namespaces
```

Inspect a policy:

```powershell
kubectl describe networkpolicy <policy-name> `
  --namespace applications-dev
```

If a NetworkPolicy exists, verify that it allows:

- DNS access to CoreDNS.
- Traffic from the client namespace.
- Traffic to the target Service or Pod.
- The correct TCP port.

NetworkPolicies may block traffic even when Pods, Services, and endpoints appear healthy.

## 19. Check probes

Inspect probes:

```powershell
kubectl get deployment <deployment-name> `
  --namespace applications-dev `
  -o jsonpath="{.spec.template.spec.containers[*].readinessProbe}"
```

A readiness probe failure removes the Pod from Service endpoints. A liveness probe failure restarts the container.

Common probe errors:

```text
connection refused:
    Application is not listening on the probe port.

404:
    Probe path is wrong.

timeout:
    Application is too slow or blocked.

HTTP 401 or 403:
    Health endpoint requires authentication.
```

Test the probe manually:

```powershell
kubectl exec <pod-name> `
  --namespace applications-dev `
  -- curl -v http://127.0.0.1:8080/actuator/health
```

## 20. Fast diagnosis by symptom

### Cannot resolve the Service name

Check:

```powershell
kubectl get service <service-name> --namespace <namespace>
kubectl get pods --namespace kube-system -l k8s-app=kube-dns
```

Likely causes:

- Wrong Service name.
- Wrong namespace.
- CoreDNS problem.
- NetworkPolicy blocks DNS.

### Service has no endpoints

Check:

```powershell
kubectl get endpoints <service-name> --namespace <namespace>
kubectl get pods --namespace <namespace> --show-labels
kubectl describe pod <pod-name> --namespace <namespace>
```

Likely causes:

- Selector and labels do not match.
- Pod is not Ready.
- Wrong namespace.
- Deployment has no available replicas.

### Port-forward to Pod fails

Check:

```powershell
kubectl logs <pod-name> --namespace <namespace>
kubectl exec <pod-name> --namespace <namespace> -- sh
```

Likely causes:

- Application is not listening.
- Wrong container port.
- Application bound only to an unexpected address.
- Container has crashed.

### Service works but Ingress returns 404

Check:

```powershell
kubectl describe ingress <ingress-name> --namespace <namespace>
kubectl get ingressclass
```

Likely causes:

- Host header does not match.
- Path does not match.
- Wrong IngressClass.
- Request reached a different controller.

### Ingress returns 502 or 503

Check:

```powershell
kubectl get endpoints <service-name> --namespace <namespace>
kubectl logs deployment/ingress-nginx-controller --namespace ingress-nginx
```

Likely causes:

- No ready endpoints.
- Wrong Service port.
- Wrong target port.
- Application is refusing connections.

### Application cannot connect to PostgreSQL, Redis, RabbitMQ, or Kafka

Check in order:

```text
1. Service name and namespace.
2. Service endpoints.
3. NetworkPolicy.
4. Port.
5. Credentials.
6. TLS or protocol settings.
7. Application-specific advertised or external addresses.
```

## 21. Useful Helm inspection

List releases:

```powershell
helm list --all-namespaces
```

Inspect a release:

```powershell
helm status orders-service --namespace applications-dev
```

Show configured values:

```powershell
helm get values orders-service --namespace applications-dev
```

Show all rendered values:

```powershell
helm get values orders-service `
  --namespace applications-dev `
  --all
```

Show rendered manifests:

```powershell
helm get manifest orders-service --namespace applications-dev
```

Compare intended and live configuration:

```powershell
helm get manifest orders-service --namespace applications-dev
kubectl get deployment <deployment-name> --namespace applications-dev -o yaml
```

## 22. Recommended troubleshooting order

Use this order for most connection failures:

```text
1. Confirm the current Kubernetes context.
2. Confirm the namespace.
3. Check Pod status.
4. Read Pod logs and events.
5. Confirm the application listens on the expected port.
6. Check the Service selector.
7. Check Service endpoints.
8. Test the Service from inside the cluster.
9. Check DNS resolution.
10. Check NetworkPolicies.
11. Check Ingress rules and controller logs.
12. Check external DNS, hosts file, TLS, or load balancer settings.
```

Do not begin by changing the Ingress when the Service has no endpoints. Fix the lowest failing layer first.
