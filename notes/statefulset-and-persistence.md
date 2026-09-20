# StatefulSet and Persistence Explained

This note explains the difference between a Kubernetes `StatefulSet` and persistent storage, and why the Redis chart uses both.

## Short answer

The Redis chart currently uses:

```text
StatefulSet + PersistentVolumeClaim + Redis AOF
```

This means:

- Kubernetes manages Redis as a stateful workload.
- Redis data is stored on persistent storage.
- Redis can recover write operations after a restart.
- There is still only one Redis instance.
- This is not high availability.

## What is a StatefulSet?

A `StatefulSet` is a Kubernetes workload type for applications that need stable identity or storage.

Your Redis chart uses a StatefulSet because Redis commonly benefits from:

- A stable pod name.
- Stable network identity.
- A dedicated storage volume.
- Predictable pod startup and termination behavior.

With the Redis release installed as `redis`, the pod name is normally similar to:

```text
redis-sudo0x-redis-0
```

The final `-0` identifies the first StatefulSet pod.

## StatefulSet versus Deployment

A `Deployment` is normally used for stateless applications, such as Spring Boot REST APIs.

If a Deployment pod is deleted, Kubernetes creates a replacement pod. The replacement does not need to have the same identity or storage.

A StatefulSet gives pods stable identities. If the first pod is recreated, Kubernetes creates it again with the same ordinal identity:

```text
redis-sudo0x-redis-0
```

### Comparison

| Workload | Typical use | Stable identity | Storage relationship |
|---|---|---:|---:|
| Deployment | Stateless APIs and web services | No | Usually none |
| StatefulSet | Databases, queues, Redis, Kafka | Yes | Commonly persistent |

For Redis, a StatefulSet is a suitable Kubernetes workload type when Redis data or identity matters.

## What is persistence?

Persistence means storing Redis data on storage that survives the replacement of the Redis pod.

Your chart has:

```yaml
persistence:
  enabled: true
  size: 10Gi
```

When persistence is enabled, the StatefulSet creates a `volumeClaimTemplate`. Kubernetes uses it to create a PersistentVolumeClaim (PVC).

The PVC is mounted inside the Redis container at:

```text
/data
```

Redis writes its persistent files under this directory.

## What is a PVC?

PVC means **PersistentVolumeClaim**.

A PVC is a request for storage from Kubernetes. It does not directly contain the storage implementation. Kubernetes connects the claim to a suitable PersistentVolume (PV), usually through a StorageClass.

The flow looks like this:

```text
Redis
  ↓
/data inside the container
  ↓
PersistentVolumeClaim
  ↓
PersistentVolume
  ↓
Disk, cloud volume, or storage system
```

The exact storage depends on the Kubernetes cluster. Examples include:

- Local disk.
- Network-attached storage.
- AWS EBS.
- Azure Disk.
- Google Persistent Disk.
- Ceph or another CSI storage provider.

## What happens when persistence is enabled?

With:

```yaml
persistence:
  enabled: true
  size: 10Gi
```

the chart creates a PVC through the StatefulSet.

If the Redis pod restarts, Kubernetes can mount the same claim again:

```text
Redis pod is replaced
        ↓
Same PVC is mounted
        ↓
Redis data remains available
```

This protects data from normal pod replacement and rescheduling, assuming the storage system is healthy.

## What happens when persistence is disabled?

With:

```yaml
persistence:
  enabled: false
```

the chart uses:

```yaml
emptyDir: {}
```

`emptyDir` is temporary storage associated with the pod.

Redis can still start and operate, but the data is lost when the pod is removed:

```text
Redis pod is deleted
        ↓
emptyDir is deleted
        ↓
Redis data is lost
```

This mode is suitable for temporary development, testing, or disposable caches.

## Do you need persistence?

It depends on what Redis stores.

### Persistence is recommended when Redis stores:

- User sessions.
- Login or authentication state.
- Background jobs.
- Queues.
- Important rate-limit state.
- Data that would be difficult to rebuild.
- Data that must survive a normal pod restart.

Use:

```yaml
persistence:
  enabled: true
```

### Persistence may not be necessary when Redis is only:

- A disposable cache.
- A development-only service.
- Test infrastructure.
- Temporary computed data.
- Data that can always be rebuilt from a database.

Use:

```yaml
persistence:
  enabled: false
```

Only disable persistence when losing every Redis value is acceptable.

## What is Redis AOF?

AOF means **Append Only File**.

Your chart enables it by default:

```yaml
redis:
  appendonly: "yes"
```

With AOF enabled, Redis records write operations so it can reconstruct data after a restart.

The simplified recovery flow is:

```text
Application writes data
        ↓
Redis updates memory
        ↓
Redis records the write in the AOF
        ↓
Redis restarts
        ↓
Redis replays the AOF
        ↓
Data is restored
```

AOF is useful only when Redis has storage that survives the restart. AOF files stored on `emptyDir` are still lost when the pod is deleted.

## Does persistence make Redis use disk instead of RAM?

No. Redis remains primarily an in-memory data store.

With persistence enabled, the normal flow is:

```text
Application request
        ↓
Redis stores and serves active data from RAM
        ↓
Redis writes persistence information to the AOF on disk
```

The PVC stores Redis recovery files. It is not normally used as the main location for serving reads and writes.

For this chart:

```text
Active Redis data: RAM
Persistence files: /data on the PVC
Normal requests: primarily served from RAM
Restart recovery: AOF on disk is replayed into RAM
```

This is why Redis is fast while still being able to recover data after a restart.

### Performance tradeoff

Persistence generally does not make normal Redis reads disk-based. Reads continue to come from RAM.

Persistence can add some overhead to writes because Redis must also write AOF data to storage. The exact effect depends on the storage system, AOF configuration, workload, and disk performance.

Redis startup can also take longer after a restart because it must read and replay the AOF file from disk to rebuild the in-memory dataset.

The tradeoff is:

```text
Persistence enabled:
  RAM performance + better recovery + some write and startup overhead

Persistence disabled:
  RAM performance + no persistent recovery + all data lost with the pod
```

Persistence is therefore mainly a durability feature, not a way to make Redis faster.

## Persistence is not backup

A PVC improves resilience, but it is not a complete backup system.

A PVC can help with:

- Container crashes.
- Pod restarts.
- Pod rescheduling.
- Some node failures, depending on the storage system.

A PVC does not automatically protect against:

- Accidental PVC deletion.
- Storage failure.
- Data corruption.
- Cluster-wide failure.
- Human mistakes.
- Malicious deletion.
- Incorrect application writes.

Important production Redis data still needs backups and a recovery procedure.

## What happens when Helm uninstalls Redis?

With persistence enabled, the Redis StatefulSet creates a PVC through `volumeClaimTemplates`.

When you run:

```bash
helm uninstall redis --namespace infrastructure
```

Helm removes the Helm-managed resources, such as:

- StatefulSet.
- Service.
- ConfigMap.
- Chart-managed Secret.

The PVC normally remains:

```text
StatefulSet deleted
Service deleted
Secret deleted
ConfigMap deleted
PVC remains
Redis data remains on the PVC
```

This behavior helps prevent accidental data loss. If the chart is installed again with compatible names and settings, the existing PVC may be available for the recreated Redis pod.

Check PVCs after uninstalling:

```bash
kubectl get pvc --namespace infrastructure
```

A PVC name may look similar to:

```text
redis-data-redis-sudo0x-redis-0
```

Do not delete the PVC until you are certain that the Redis data is no longer needed.

### Permanently deleting Redis data

To remove the data, first list the PVCs:

```bash
kubectl get pvc --namespace infrastructure
```

Then delete only the specific Redis PVC:

```bash
kubectl delete pvc <redis-pvc-name> --namespace infrastructure
```

The underlying storage behavior also depends on the StorageClass reclaim policy. Deleting a PVC may delete the backing volume, or it may leave the backing volume available for manual recovery.

With persistence disabled, the chart uses `emptyDir`. That temporary storage disappears when the pod is deleted, so uninstalling the release removes the Redis data.

## Does StatefulSet provide high availability?

No.

The chart defaults to:

```yaml
replicaCount: 1
```

That means there is one Redis instance.

A StatefulSet provides stable identity and storage behavior, but it does not automatically provide:

- Redis replication.
- Sentinel.
- Redis Cluster.
- Automatic failover.
- Multiple active Redis nodes.
- High availability.

Increasing this value:

```yaml
replicaCount: 3
```

does not configure Redis replication or clustering. Do not increase the replica count unless the chart is redesigned for a specific Redis replication architecture.

## Why the Redis chart uses a StatefulSet

The chart uses a StatefulSet because the current design expects:

1. One Redis instance.
2. A stable Redis pod identity.
3. A persistent data directory at `/data`.
4. A PVC that can be reused when the pod is recreated.
5. Predictable Kubernetes behavior for a stateful service.

The StatefulSet is appropriate even though the chart does not provide HA.

## Why the Redis chart enables persistence by default

Persistence is enabled by default because it is safer for a reusable internal infrastructure chart.

The default is:

```yaml
persistence:
  enabled: true
  size: 10Gi
```

This avoids silently losing sessions, queues, or other Redis data after a pod replacement.

If a particular Spring Boot service uses Redis only as a disposable cache, that service can install the chart with:

```yaml
persistence:
  enabled: false
```

## Practical recommendations

### Development

For temporary development:

```yaml
replicaCount: 1

persistence:
  enabled: false
```

This is simple, but data disappears when the pod is removed.

### Testing

For tests where Redis data does not need to survive:

```yaml
persistence:
  enabled: false
```

This keeps test cleanup simple.

### Internal production service

For sessions, queues, or important state:

```yaml
replicaCount: 1

persistence:
  enabled: true
  size: 10Gi

redis:
  appendonly: "yes"
```

Also configure a real StorageClass and establish backups.

### Disposable cache

For a cache that can be fully rebuilt:

```yaml
replicaCount: 1

persistence:
  enabled: false
```

This is valid only if the application continues to work after all Redis values disappear.

## Useful inspection commands

Check the StatefulSet:

```bash
kubectl get statefulset -n infrastructure
```

Check the Redis pod:

```bash
kubectl get pods -n infrastructure
```

Check the PVC:

```bash
kubectl get pvc -n infrastructure
```

Describe the PVC:

```bash
kubectl describe pvc -n infrastructure
```

Check the pod's volume mounts:

```bash
kubectl describe pod -n infrastructure \
  -l app.kubernetes.io/instance=redis
```

Check Redis logs:

```bash
kubectl logs -n infrastructure \
  -l app.kubernetes.io/instance=redis
```

## Final summary

| Question | Answer |
|---|---|
| What is a StatefulSet? | A Kubernetes workload type with stable pod identity and storage relationships |
| What is persistence? | Keeping Redis data on storage that survives pod replacement |
| What is a PVC? | A Kubernetes request for persistent storage |
| What is `emptyDir`? | Temporary pod storage that disappears with the pod |
| What is AOF? | Redis write logging used to recover data after restart |
| Where does Redis serve normal requests? | Primarily from RAM |
| Does a PVC replace RAM? | No, it stores persistence files for recovery |
| Does persistence make Redis faster? | No, it improves durability and can add some write/startup overhead |
| Does a StatefulSet provide HA? | No |
| Does a PVC provide backups? | No |
| Should this chart default to persistence? | Yes, because it is safer for reusable infrastructure |
| Can persistence be disabled? | Yes, when Redis data is disposable |

For this chart, remember:

```text
StatefulSet = how Kubernetes runs Redis
PVC         = where Redis data survives
emptyDir    = temporary Redis data
AOF         = how Redis records writes for recovery
RAM         = where Redis actively serves normal requests
HA          = not provided by this chart
```
