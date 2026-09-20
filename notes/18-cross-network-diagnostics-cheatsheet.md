# Cross-Network Diagnostics Cheat Sheet

This cheat sheet covers practical commands for testing connectivity between:

- A Windows workstation and Kubernetes.
- One Kubernetes Pod and another Pod.
- A Pod and a Kubernetes Service.
- A Kubernetes cluster and an external server.
- Applications and TCP, HTTP, HTTPS, DNS, Redis, PostgreSQL, RabbitMQ, or Kafka endpoints.

The basic diagnostic questions are:

```text
1. Can the name resolve?
2. Can the network route reach the address?
3. Is the TCP port open?
4. Does the expected protocol respond?
5. Is authentication or TLS working?
6. Is the application returning a healthy response?
```

## 1. Tool meanings

```text
ping:
    Tests ICMP reachability. It does not test application ports.

curl:
    Tests HTTP, HTTPS, headers, redirects, authentication, and APIs.

nc / netcat:
    Tests TCP or UDP port connectivity.

nslookup:
    Tests DNS resolution.

Resolve-DnsName:
    PowerShell DNS lookup command.

Test-NetConnection:
    Windows TCP connectivity and route diagnostics.

tracert:
    Shows the route from Windows to a destination.

traceroute:
    Linux route diagnostic command.

tcpdump:
    Captures packets for detailed analysis.
```

## 2. Windows workstation commands

### Check DNS

```powershell
Resolve-DnsName example.com
```

Query a specific DNS server:

```powershell
Resolve-DnsName example.com -Server 8.8.8.8
```

Use `nslookup`:

```powershell
nslookup example.com
```

Query a specific DNS server:

```powershell
nslookup example.com 8.8.8.8
```

Check a local hostname:

```powershell
Resolve-DnsName orders.local
```

If the name is defined in the Windows hosts file, inspect:

```text
C:\Windows\System32\drivers\etc\hosts
```

Flush the Windows DNS cache:

```powershell
Clear-DnsClientCache
```

### Test a TCP port

```powershell
Test-NetConnection example.com -Port 443
```

Test a Kubernetes controller address:

```powershell
Test-NetConnection 192.168.18.221 -Port 80
Test-NetConnection 192.168.18.221 -Port 443
```

Show route and source information:

```powershell
Test-NetConnection example.com -Port 443 -InformationLevel Detailed
```

Important output:

```text
TcpTestSucceeded: True
```

`TcpTestSucceeded: True` proves that a TCP connection was established. It does not prove that the application protocol, authentication, or URL is correct.

### Test HTTP

```powershell
curl.exe -v http://example.com/
```

Test HTTPS:

```powershell
curl.exe -vk https://example.com/
```

Show response headers:

```powershell
curl.exe -I https://example.com/
```

Follow redirects:

```powershell
curl.exe -L -v http://example.com/
```

Send a custom Host header:

```powershell
curl.exe -v `
  -H "Host: orders.local" `
  http://192.168.18.221/
```

Send a custom header:

```powershell
curl.exe -v `
  -H "Authorization: Bearer <token>" `
  https://api.example.com/health
```

Send JSON:

```powershell
curl.exe -v `
  -X POST `
  -H "Content-Type: application/json" `
  -d '{"name":"example"}' `
  https://api.example.com/orders
```

Use basic authentication:

```powershell
curl.exe -v `
  -u username:password `
  https://api.example.com/
```

### Test an Ingress locally

Get the NGINX controller address:

```powershell
kubectl get service ingress-nginx-controller `
  --namespace ingress-nginx `
  --wide
```

Test using the hostname:

```powershell
curl.exe -v http://orders.local/
```

Test using the controller IP and Host header:

```powershell
curl.exe -v `
  -H "Host: orders.local" `
  http://192.168.18.221/
```

Test HTTPS with a Host header:

```powershell
curl.exe -vk `
  -H "Host: orders.example.com" `
  https://192.168.18.221/
```

## 3. Linux or macOS command equivalents

### DNS

```bash
dig example.com
nslookup example.com
getent hosts example.com
```

### TCP port

```bash
nc -zv example.com 443
```

With a timeout:

```bash
nc -zv -w 5 example.com 443
```

Test a Kubernetes Service:

```bash
nc -zv orders-service.applications-dev.svc.cluster.local 8080
```

### HTTP and HTTPS

```bash
curl -v http://example.com/
curl -vk https://example.com/
curl -I https://example.com/
curl -L -v http://example.com/
```

Send a Host header:

```bash
curl -v \
  -H 'Host: orders.local' \
  http://192.168.18.221/
```

### Route tracing

```bash
traceroute example.com
```

TCP route tracing:

```bash
traceroute -T -p 443 example.com
```

## 4. Temporary Kubernetes diagnostic Pods

The application image may not contain `curl`, `nc`, `dig`, or a shell. Use a temporary diagnostic Pod instead.

### Curl image

Start an interactive shell:

```powershell
kubectl run curl-test `
  --rm -it `
  --restart=Never `
  --image=curlimages/curl `
  -- sh
```

Inside the Pod:

```text
curl -v http://orders-service:8080/actuator/health
curl -v http://orders-service.applications-dev.svc.cluster.local:8080/
nslookup orders-service
```

Run one command without opening a shell:

```powershell
kubectl run curl-test `
  --rm -it `
  --restart=Never `
  --image=curlimages/curl `
  -- curl -v http://orders-service:8080/actuator/health
```

### BusyBox image

```powershell
kubectl run network-test `
  --rm -it `
  --restart=Never `
  --image=busybox:1.36 `
  -- sh
```

Inside the Pod:

```text
nslookup orders-service
nc -zv orders-service 8080
wget -S -O - http://orders-service:8080/actuator/health
```

BusyBox command availability varies by image version.

### Netshoot image

`nicolaka/netshoot` includes many network troubleshooting tools:

```powershell
kubectl run netshoot `
  --rm -it `
  --restart=Never `
  --image=nicolaka/netshoot `
  -- bash
```

Inside the Pod:

```text
ip addr
ip route
nslookup orders-service
dig orders-service
curl -v http://orders-service:8080/
nc -zv orders-service 8080
traceroute orders-service
tcpdump -i any port 8080
```

Use diagnostic images only in approved environments. Do not leave temporary Pods running.

## 5. `nc -zv` examples

The options commonly mean:

```text
-z:
    Scan without sending application data.

-v:
    Verbose output.

-w 5:
    Five-second timeout.
```

Test a TCP port:

```bash
nc -zv orders-service 8080
```

Test with a timeout:

```bash
nc -zv -w 5 orders-service 8080
```

Test PostgreSQL:

```bash
nc -zv postgres-service 5432
```

Test Redis:

```bash
nc -zv redis-service 6379
```

Test RabbitMQ AMQP:

```bash
nc -zv rabbitmq-service 5672
```

Test RabbitMQ management:

```bash
nc -zv rabbitmq-service 15672
```

Test Kafka:

```bash
nc -zv kafka-service 9092
```

Successful TCP output usually looks similar to:

```text
Connection to orders-service 8080 port [tcp/*] succeeded!
```

Failure usually indicates:

- DNS resolved but no process is listening.
- Service has no ready endpoints.
- NetworkPolicy blocks the connection.
- The port is wrong.
- The destination is unreachable.

`nc` confirms only TCP connection behavior. It does not verify protocol correctness or credentials.

## 6. `curl` examples by protocol

### HTTP status only

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://orders-service:8080/actuator/health
```

### Full verbose connection

```bash
curl -v http://orders-service:8080/actuator/health
```

### Connection timeout

```bash
curl --connect-timeout 5 --max-time 15 -v http://orders-service:8080/
```

### Headers only

```bash
curl -I http://orders-service:8080/
```

### Follow redirects

```bash
curl -L -v http://orders-service:8080/
```

### HTTP/2

```bash
curl --http2 -v https://api.example.com/
```

### Ignore certificate validation for temporary testing

```bash
curl -k -v https://api.example.com/
```

Do not use `-k` as a production security fix. It disables certificate verification.

### Test a specific resolved address

```bash
curl --resolve orders.example.com:443:192.168.18.221 `
  -vk https://orders.example.com/
```

This tests a hostname against a chosen IP while preserving the TLS Server Name Indication and Host header.

## 7. DNS troubleshooting

Resolve a Kubernetes Service:

```bash
nslookup orders-service
nslookup orders-service.applications-dev.svc.cluster.local
```

Use `dig`:

```bash
dig orders-service.applications-dev.svc.cluster.local
dig +short orders-service.applications-dev.svc.cluster.local
```

Check the resolver configuration:

```bash
cat /etc/resolv.conf
```

From Windows:

```powershell
Get-DnsClientServerAddress
Resolve-DnsName orders.local
```

Interpretation:

```text
NXDOMAIN:
    The name does not exist in the queried DNS system.

SERVFAIL:
    The DNS server failed to answer correctly.

Timeout:
    The DNS server or network path may be unavailable.

Name resolves to an unexpected address:
    DNS record, hosts file, or split-DNS configuration may be wrong.
```

## 8. TCP versus HTTP testing

Use `nc` or `Test-NetConnection` first to test the TCP layer:

```text
TCP connection succeeds
    The destination port accepts connections.

TCP connection fails
    Check address, port, routing, firewall, endpoints, and NetworkPolicy.
```

Then use `curl` to test HTTP:

```text
HTTP response succeeds
    The HTTP server and route responded.

TCP succeeds but HTTP fails
    Check URL path, Host header, TLS, authentication, and application protocol.
```

Example sequence:

```bash
nc -zv orders-service 8080
curl -v http://orders-service:8080/actuator/health
```

## 9. TLS and certificate diagnostics

Test HTTPS with curl:

```bash
curl -vk https://orders.example.com/
```

Inspect the certificate with OpenSSL:

```bash
openssl s_client -connect orders.example.com:443 \
  -servername orders.example.com
```

Check only certificate dates:

```bash
echo | openssl s_client \
  -connect orders.example.com:443 \
  -servername orders.example.com 2>$null |
  openssl x509 -noout -dates
```

Check Kubernetes TLS Secret metadata:

```powershell
kubectl get secret orders-tls `
  --namespace applications-dev `
  -o jsonpath="{.type}"
```

Common TLS failures:

- Certificate hostname does not match the requested hostname.
- Certificate is expired.
- Wrong TLS Secret namespace.
- Ingress host and certificate hosts differ.
- Client does not trust the issuing certificate authority.
- HTTP reaches the controller but HTTPS is not configured.

## 10. Kubernetes Service connectivity sequence

Run these checks in order:

```powershell
kubectl get service orders-service --namespace applications-dev
kubectl get endpoints orders-service --namespace applications-dev
kubectl get endpointslices `
  --namespace applications-dev `
  -l kubernetes.io/service-name=orders-service
kubectl get pods --namespace applications-dev -o wide
```

Then test from inside the cluster:

```powershell
kubectl run curl-test `
  --rm -it `
  --restart=Never `
  --image=curlimages/curl `
  -- curl -v http://orders-service:8080/actuator/health
```

If the Service has no endpoints, do not troubleshoot Ingress yet.

## 11. Cross-namespace connectivity

Short Service name, usually same namespace:

```text
http://orders-service:8080
```

Namespace-qualified name:

```text
http://orders-service.applications-dev:8080
```

Fully qualified name:

```text
http://orders-service.applications-dev.svc.cluster.local:8080
```

Test a Service in another namespace:

```powershell
kubectl run curl-test `
  --rm -it `
  --restart=Never `
  --image=curlimages/curl `
  -- curl -v http://redis-sudo0x-redis.infrastructure-dev.svc.cluster.local:6379
```

Cross-namespace failures often come from:

- Incorrect namespace in the hostname.
- NetworkPolicy restrictions.
- Wrong Service name.
- Missing endpoints.
- Authentication or protocol configuration.

## 12. Test database and messaging ports

Run TCP checks from a diagnostic Pod:

```bash
nc -zv postgres-service 5432
nc -zv redis-service 6379
nc -zv rabbitmq-service 5672
nc -zv rabbitmq-service 15672
nc -zv kafka-service 9092
```

Port availability does not prove the application protocol is usable:

```text
Port 5432 open:
    PostgreSQL may still reject credentials or database names.

Port 6379 open:
    Redis may still require authentication.

Port 5672 open:
    RabbitMQ may still reject credentials or vhosts.

Port 9092 open:
    Kafka advertised listeners may still return an unreachable address.
```

## 13. Kafka-specific connectivity

Kafka clients first connect to a bootstrap address, then receive broker addresses from `advertised.listeners`.

Test the bootstrap port:

```bash
nc -zv kafka-service 9092
```

Use a Kafka client:

```bash
/opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka-service:9092 \
  --list
```

If bootstrap succeeds but topic operations fail, inspect:

- `advertised.listeners`.
- Broker DNS names.
- Controller and broker listener ports.
- TLS or SASL settings.
- Client network location.

The address advertised by Kafka must be resolvable and reachable from the client.

## 14. RabbitMQ-specific connectivity

Test AMQP:

```bash
nc -zv rabbitmq-service 5672
```

Test management HTTP:

```bash
curl -v http://rabbitmq-service:15672/
```

Test with credentials:

```bash
curl -u username:password `
  http://rabbitmq-service:15672/api/overview
```

TCP success does not prove that the user has access to the required virtual host.

## 15. Redis-specific connectivity

Test the port:

```bash
nc -zv redis-service 6379
```

Test Redis protocol:

```bash
redis-cli -h redis-service -p 6379 ping
```

With authentication:

```bash
redis-cli -h redis-service -p 6379 -a '<password>' ping
```

Expected response:

```text
PONG
```

## 16. PostgreSQL-specific connectivity

Test the port:

```bash
nc -zv postgres-service 5432
```

Test PostgreSQL readiness:

```bash
pg_isready -h postgres-service -p 5432
```

Test a query:

```bash
PGPASSWORD='<password>' psql \
  -h postgres-service \
  -p 5432 \
  -U <username> \
  -d <database> \
  -c 'select 1;'
```

## 17. NetworkPolicy checks

List policies:

```powershell
kubectl get networkpolicies --all-namespaces
```

Inspect a policy:

```powershell
kubectl describe networkpolicy <policy-name> `
  --namespace applications-dev
```

If DNS fails after a NetworkPolicy is applied, verify that UDP and TCP port `53` to CoreDNS are allowed.

If a Service port fails, verify that the policy allows:

- The source namespace or Pod labels.
- The destination namespace or Pod labels.
- The destination TCP port.

## 18. Packet capture

Use a diagnostic image with `tcpdump`:

```powershell
kubectl run netshoot `
  --rm -it `
  --restart=Never `
  --image=nicolaka/netshoot `
  -- bash
```

Inside the Pod:

```text
tcpdump -i any host orders-service
tcpdump -i any port 8080
tcpdump -i any port 53
```

Packet capture can expose request metadata and sensitive information. Use it only with authorization and avoid sharing captures that contain credentials or personal data.

## 19. Interpret common errors

```text
Connection refused:
    Host reachable, but no process accepts the port or the port is wrong.

Connection timed out:
    Firewall, NetworkPolicy, routing, unavailable endpoint, or dropped packets.

No route to host:
    Routing or network path problem.

Name or service not known:
    DNS name is invalid or cannot be resolved.

HTTP 404:
    Server responded, but the path or Ingress host did not match.

HTTP 401 or 403:
    Authentication or authorization failed.

HTTP 502:
    Proxy could not connect correctly to the backend.

HTTP 503:
    Backend Service has no usable ready endpoints.

TLS certificate error:
    Certificate trust, hostname, expiry, or Secret configuration problem.
```

## 20. Recommended diagnostic sequence

For an external application:

```text
1. Resolve the hostname.
2. Test the controller IP and TCP port.
3. Test HTTP with the expected Host header.
4. Inspect the Ingress object.
5. Inspect the NGINX controller logs.
6. Check the backend Service.
7. Check Service endpoints.
8. Check Pod readiness and logs.
9. Test the Service from inside the cluster.
10. Test the application process locally inside the Pod.
```

For an internal Service:

```text
1. Confirm the Service name and namespace.
2. Resolve the Service DNS name.
3. Check Service endpoints.
4. Test the TCP port with nc.
5. Test the protocol with curl or the native client.
6. Check NetworkPolicies.
7. Check application logs and credentials.
```

For an infrastructure dependency:

```text
1. Confirm the Service DNS name.
2. Confirm the correct protocol port.
3. Test TCP with nc.
4. Test the native protocol.
5. Check authentication.
6. Check TLS or advertised addresses.
7. Check server logs.
```

## 21. Safety reminders

- Use timeouts so failed tests do not hang indefinitely.
- Do not place real passwords in shell history or shared documentation.
- Avoid `curl -k` except for temporary diagnostics.
- Treat packet captures and verbose logs as potentially sensitive.
- Remove temporary diagnostic Pods after testing.
- Test from the same network location as the failing client when possible.
- A successful ping does not prove that a TCP port is open.
- A successful TCP connection does not prove that the application protocol works.
