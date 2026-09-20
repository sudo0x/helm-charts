# Redis Helm Chart Production-Readiness Roadmap

This document is the next implementation plan for the `sudo0x-redis` Helm chart.

The current chart is intentionally:

```text
Single Redis instance
StatefulSet
PersistentVolumeClaim
Redis AOF
ClusterIP Service
Password authentication
```

This roadmap hardens that design. It does not turn the chart into Redis Sentinel, Redis Cluster, or an HA platform.

## Production target

The immediate target is:

> A reliable persistent single-instance Redis deployment for internal Kubernetes services.

This target is suitable when:

- One Redis instance is acceptable.
- A short Redis outage is acceptable.
- Applications can retry or degrade when Redis is unavailable.
- Redis data is important enough to persist.
- The team has a backup and restore process.

This target is not suitable when the requirement is:

- Automatic failover.
- Zero or near-zero downtime.
- Multiple Redis nodes.
- Cross-zone redundancy.
- Guaranteed disaster recovery without external backups.

Those requirements need a separate HA architecture.

## Current status

The chart already provides:

- Official Redis image with a fixed tag.
- StatefulSet.
- ConfigMap for `redis.conf`.
- Secret authentication.
- Existing Secret support.
- PVC or `emptyDir` storage selection.
- Authentication-aware probes.
- Resource requests and limits.
- Non-root security context.
- ClusterIP Service.
- PVC retention behavior after Helm uninstall.

The remaining work is operational hardening.

## Implementation order

Implement the work in this order:

```text
1. Secret safety
2. Production values and storage
3. Resource and memory sizing
4. Network access control
5. Monitoring and alerting
6. Backup and restore
7. Failure testing
8. Release and documentation update
```

Do not skip validation between steps.

## Step 1: Remove the default password risk

### Goal

Prevent production users from accidentally deploying Redis with:

```yaml
password: "change-me"
```

### Recommended production usage

Create the Secret outside Helm:

```bash
kubectl create secret generic redis-production-credentials \
  --from-literal=redis-password='REPLACE_WITH_A_REAL_SECRET' \
  --namespace infrastructure
```

Install using the existing Secret:

```bash
helm upgrade --install redis sudo0x/sudo0x-redis \
  --namespace infrastructure \
  --set auth.enabled=true \
  --set auth.existingSecret=redis-production-credentials \
  --set auth.existingSecretKey=redis-password
```

### Acceptance criteria

- The production deployment references the existing Secret.
- No chart-generated password Secret is created.
- No real password is committed to Git.
- The password is not present in the ConfigMap.
- The application uses the same Secret or a securely distributed copy.

### Optional chart hardening

Consider changing the chart defaults so production users must explicitly choose a password source. If this is done, document the behavior carefully because it changes the current simple development experience.

## Step 2: Choose production storage

### Goal

Use reliable persistent storage rather than an unspecified default.

Example production values:

```yaml
persistence:
  enabled: true
  storageClass: fast-ssd
  accessModes:
    - ReadWriteOnce
  size: 20Gi
```

Check available StorageClasses:

```bash
kubectl get storageclass
```

Check the created PVC:

```bash
kubectl get pvc --namespace infrastructure
kubectl describe pvc --namespace infrastructure
```

### Acceptance criteria

- The selected StorageClass exists.
- The PVC becomes `Bound`.
- The storage supports the required availability and performance.
- PVC expansion behavior is understood.
- The reclaim policy is documented.
- The team understands that deleting the PVC may delete the backing volume.

## Step 3: Size memory and resources

Redis serves active data primarily from RAM. The PVC stores persistence files; it does not replace RAM.

The normal flow is:

```text
Active Redis data: RAM
Persistence files: PVC
Normal reads and writes: primarily RAM
Restart recovery: AOF on disk is replayed into RAM
```

Example starting values:

```yaml
resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: "1"
    memory: 1Gi
```

Size memory based on:

- Expected key and value data.
- Redis internal overhead.
- Client connections.
- AOF buffers and rewrite needs.
- Operational headroom.

Do not set Redis memory equal to the Kubernetes memory limit without leaving headroom.

### Acceptance criteria

- The memory limit is based on observed or estimated workload.
- Redis does not repeatedly approach the Kubernetes memory limit.
- CPU throttling is acceptable.
- The team knows what happens when Redis reaches its configured memory limit.

The current policy is:

```yaml
redis:
  maxmemoryPolicy: "noeviction"
```

With `noeviction`, writes can fail when Redis reaches its configured memory limit. This may be correct for important data, but the application must handle write failures.

## Step 4: Restrict network access

The Service is internal:

```yaml
service:
  type: ClusterIP
```

That prevents direct external exposure by default, but any pod that can reach the namespace network may still be able to attempt a connection unless NetworkPolicy rules restrict it.

### Recommended next change

Add an optional NetworkPolicy that allows Redis traffic only from approved application labels and namespaces.

Example design:

```yaml
networkPolicy:
  enabled: true
  ingress:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: application
      podSelector:
        matchLabels:
          app.kubernetes.io/name: orders-service
      ports:
        - protocol: TCP
          port: 6379
```

The exact labels and namespaces must match the organization’s cluster conventions.

### Acceptance criteria

- Approved Spring Boot services can connect.
- Unapproved namespaces or pods cannot connect.
- NetworkPolicy support is tested in the target CNI.
- The Redis Service remains `ClusterIP`.

Do not add a NetworkPolicy with guessed labels. Confirm the labels used by the applications first.

## Step 5: Add monitoring and alerting

At minimum, monitor:

- Redis pod availability.
- StatefulSet readiness.
- Pod restarts.
- Liveness and readiness failures.
- Memory usage.
- CPU usage.
- Connected clients.
- Commands per second.
- Evictions.
- Rejected connections.
- AOF write or rewrite failures.
- PVC capacity.
- PVC errors.

### Recommended implementation options

Choose one approach already supported by the cluster:

- Prometheus Redis exporter.
- Existing platform monitoring integration.
- Kubernetes metrics plus application-level health checks.
- A separately managed monitoring stack.

Do not add a monitoring dependency to the chart without confirming the platform standard.

### Acceptance criteria

- Redis availability has an alert.
- PVC capacity has an alert.
- Memory pressure has an alert.
- AOF or persistence failures are visible.
- Pod restarts and probe failures are visible.
- Someone owns the alert response.

## Step 6: Define backup and restore

A PVC is not a backup.

Backups protect against:

- PVC deletion.
- Storage failure.
- Data corruption.
- Cluster loss.
- Human error.

Define:

- Backup method.
- Backup frequency.
- Backup retention.
- Backup storage location.
- Encryption requirements.
- Restore owner.
- Recovery Point Objective (RPO).
- Recovery Time Objective (RTO).

### Restore test outline

1. Create a test Redis deployment.
2. Restore a backup.
3. Verify expected keys or application state.
4. Verify password and configuration.
5. Measure restore duration.
6. Record the procedure.

### Acceptance criteria

- A backup exists outside the Redis pod and PVC.
- A restore has been tested successfully.
- The backup is protected from unauthorized access.
- The restore procedure is written down.
- Recovery expectations are agreed upon.

## Step 7: Test failure scenarios

Run tests in a non-production environment first.

### Pod deletion

```bash
kubectl delete pod \
  -n infrastructure \
  -l app.kubernetes.io/instance=redis
```

Verify:

```bash
kubectl get pods -n infrastructure
kubectl get pvc -n infrastructure
```

Expected result:

- A replacement pod starts.
- The PVC remains.
- Redis data is recovered.

### Helm uninstall

```bash
helm uninstall redis --namespace infrastructure
```

Check:

```bash
kubectl get pvc --namespace infrastructure
```

Expected result with persistence enabled:

```text
Helm resources removed
PVC remains
Redis data remains on the PVC
```

Do not delete the PVC during this test.

### Reinstall

```bash
helm upgrade --install redis ./charts/redis \
  --namespace infrastructure \
  --set auth.existingSecret=redis-production-credentials
```

Verify that the intended storage is used and data is available.

### Storage failure and application behavior

Do not simulate destructive storage failures on production data. Instead, test how the application behaves when Redis is unavailable:

- Does the application retry?
- Does it time out quickly?
- Does it fail safely?
- Does it return a useful health status?
- Can it continue with degraded functionality?

### Acceptance criteria

- Pod replacement recovery is understood.
- Uninstall and reinstall behavior is understood.
- Application timeout and retry behavior is tested.
- Backup restoration is tested separately.

## Step 8: Release and documentation

After implementation changes:

1. Update `charts/redis/Chart.yaml`.
2. Increment `version`.
3. Update `charts/redis/README.md`.
4. Update relevant files under `notes/`.
5. Run lint and rendering tests.
6. Package the chart.
7. Update `docs/index.yaml`.
8. Commit source and published files.
9. Push to GitHub.

Validation:

```bash
helm lint charts/redis
helm template redis charts/redis -n infrastructure
helm template redis charts/redis -n infrastructure \
  --set auth.existingSecret=my-redis-secret
helm template redis charts/redis -n infrastructure \
  --set auth.enabled=false \
  --set persistence.enabled=false
```

Package:

```bash
rm -f dist/*.tgz dist/index.yaml
helm package charts/redis --destination dist
helm repo index dist --url https://sudo0x.github.io/helm-charts
cp dist/*.tgz docs/
cp dist/index.yaml docs/
```

Review:

```bash
git status
git diff -- charts/redis
git diff -- docs
```

Commit and push:

```bash
git add charts/redis docs notes
git commit -m "Harden sudo0x Redis Helm chart for production"
git push
```

## Production deployment checklist

Before production:

- [ ] A real Secret is prepared.
- [ ] The default password is not used.
- [ ] The StorageClass is selected.
- [ ] The PVC size is sufficient.
- [ ] The PVC reclaim policy is understood.
- [ ] Redis memory sizing is documented.
- [ ] CPU and memory requests/limits are reviewed.
- [ ] Network access is restricted or explicitly accepted.
- [ ] Monitoring is configured.
- [ ] Alerts have owners.
- [ ] Backups are configured.
- [ ] Restore has been tested.
- [ ] Application retry and timeout behavior is tested.
- [ ] Pod replacement has been tested.
- [ ] Uninstall and reinstall behavior is understood.
- [ ] The chart README is updated.
- [ ] The chart version is incremented.
- [ ] `helm lint` passes.
- [ ] `helm template` passes for important value combinations.

## Final decision guide

Use the current chart with hardening when:

```text
One Redis instance is acceptable
PVC-backed persistence is sufficient
Short outages are acceptable
Backups and monitoring are available
```

Stop and design an HA solution when:

```text
Redis downtime is unacceptable
Automatic failover is required
Multiple nodes are required
Cross-zone availability is required
Redis is a critical system of record
```

Do not solve HA by changing only:

```yaml
replicaCount: 3
```

That creates multiple StatefulSet pods but does not configure Redis replication, Sentinel, or Cluster behavior.

