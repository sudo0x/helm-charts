# Redis and PostgreSQL Daily Commands

This cheat sheet contains common daily commands for checking, connecting to, and troubleshooting the Redis and PostgreSQL charts in Kubernetes.

The examples assume:

```text
Namespace: infrastructure-dev
Redis Service: redis-sudo0x-redis
PostgreSQL Service: postgres-sudo0x-postgres
```

Names can differ depending on the Helm release name. Always check the actual names first:

```powershell
kubectl get services --namespace infrastructure-dev
kubectl get pods --namespace infrastructure-dev
helm list --namespace infrastructure-dev
```

## 1. Basic infrastructure checks

Check all resources:

```powershell
kubectl get all --namespace infrastructure-dev
```

Check Pods with IP addresses:

```powershell
kubectl get pods `
  --namespace infrastructure-dev `
  -o wide
```

Check recent events:

```powershell
kubectl get events `
  --namespace infrastructure-dev `
  --sort-by=.lastTimestamp
```

Check resource usage:

```powershell
kubectl top pods --namespace infrastructure-dev
```

Check Helm releases:

```powershell
helm list --namespace infrastructure-dev
```

## 2. Redis daily commands

### Check Redis resources

List Redis resources:

```powershell
kubectl get pods,service,statefulset,pvc `
  --namespace infrastructure-dev `
  | Select-String redis
```

Inspect the Redis Pod:

```powershell
kubectl describe pod <redis-pod-name> `
  --namespace infrastructure-dev
```

View Redis logs:

```powershell
kubectl logs <redis-pod-name> `
  --namespace infrastructure-dev `
  --tail=100
```

Follow Redis logs:

```powershell
kubectl logs <redis-pod-name> `
  --namespace infrastructure-dev `
  --follow
```

Check the Redis Service:

```powershell
kubectl get service <redis-service-name> `
  --namespace infrastructure-dev `
  -o wide
```

Check Redis endpoints:

```powershell
kubectl get endpoints <redis-service-name> `
  --namespace infrastructure-dev `
  -o wide
```

### Connect with `redis-cli`

Open a shell inside the Redis Pod:

```powershell
kubectl exec -it <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli
```

If authentication is enabled:

```powershell
kubectl exec -it <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>'
```

Avoid putting real passwords in shell history. Prefer an interactive method or a temporary diagnostic Pod when possible.

Run a health check:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' ping
```

Expected output:

```text
PONG
```

Check server information:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' INFO server
```

Check memory information:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' INFO memory
```

Check connected clients:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' CLIENT LIST
```

Check database sizes:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' INFO keyspace
```

Check the number of keys in database 0:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' DBSIZE
```

Check one key without displaying every key:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' TYPE <key>
```

Read a string value:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' GET <key>
```

Read a hash:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' HGETALL <key>
```

Check a key's TTL:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' TTL <key>
```

Use `SCAN` instead of `KEYS *` on a busy Redis instance:

```powershell
kubectl exec -it <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' SCAN 0
```

Avoid this on production-sized datasets:

```text
KEYS *
```

`KEYS *` can block Redis while scanning a large keyspace. Use `SCAN` with a controlled match pattern instead.

### Redis connectivity from a temporary Pod

Start a Redis client:

```powershell
kubectl run redis-client `
  --rm -it `
  --restart=Never `
  --namespace infrastructure-dev `
  --image=redis:8.2 `
  -- redis-cli -h <redis-service-name> -p 6379 ping
```

With authentication:

```powershell
kubectl run redis-client `
  --rm -it `
  --restart=Never `
  --namespace infrastructure-dev `
  --image=redis:8.2 `
  -- redis-cli -h <redis-service-name> -p 6379 -a '<redis-password>' ping
```

Check the TCP port:

```powershell
kubectl run redis-network-test `
  --rm -it `
  --restart=Never `
  --namespace infrastructure-dev `
  --image=busybox:1.36 `
  -- sh -c "nc -zv <redis-service-name> 6379"
```

### Redis configuration checks

Show the active configuration:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' CONFIG GET appendonly
```

Check the maximum memory policy:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' CONFIG GET maxmemory-policy
```

Check persistence information:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' INFO persistence
```

## 3. PostgreSQL daily commands

### Check PostgreSQL resources

List PostgreSQL resources:

```powershell
kubectl get pods,service,statefulset,pvc `
  --namespace infrastructure-dev `
  | Select-String postgres
```

Inspect the PostgreSQL Pod:

```powershell
kubectl describe pod <postgres-pod-name> `
  --namespace infrastructure-dev
```

View PostgreSQL logs:

```powershell
kubectl logs <postgres-pod-name> `
  --namespace infrastructure-dev `
  --tail=100
```

Follow PostgreSQL logs:

```powershell
kubectl logs <postgres-pod-name> `
  --namespace infrastructure-dev `
  --follow
```

Check the PostgreSQL Service:

```powershell
kubectl get service <postgres-service-name> `
  --namespace infrastructure-dev `
  -o wide
```

Check PostgreSQL endpoints:

```powershell
kubectl get endpoints <postgres-service-name> `
  --namespace infrastructure-dev `
  -o wide
```

Check the PostgreSQL PVC:

```powershell
kubectl get pvc `
  --namespace infrastructure-dev `
  | Select-String postgres
```

Inspect the PVC:

```powershell
kubectl describe pvc <postgres-pvc-name> `
  --namespace infrastructure-dev
```

### Check PostgreSQL readiness

Run `pg_isready` inside the PostgreSQL Pod:

```powershell
kubectl exec <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- pg_isready
```

Check a specific database:

```powershell
kubectl exec <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- pg_isready -U <username> -d <database>
```

Expected output includes:

```text
accepting connections
```

### Connect with `psql`

Open an interactive PostgreSQL session:

```powershell
kubectl exec -it <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- psql -U <username> -d <database>
```

If the image requires a password, provide it through the configured environment or use an approved Secret-based workflow. Avoid placing real passwords in command history.

Run a single query:

```powershell
kubectl exec <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- psql -U <username> -d <database> -c "SELECT 1;"
```

Show the PostgreSQL version:

```powershell
kubectl exec <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- psql -U <username> -d <database> -c "SELECT version();"
```

List databases:

```powershell
kubectl exec -it <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- psql -U <username> -d <database> -c "\l"
```

List schemas:

```powershell
kubectl exec -it <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- psql -U <username> -d <database> -c "\dn"
```

List tables:

```powershell
kubectl exec -it <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- psql -U <username> -d <database> -c "\dt"
```

Describe a table:

```powershell
kubectl exec -it <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- psql -U <username> -d <database> -c "\d <table-name>"
```

Check active connections:

```powershell
kubectl exec <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- psql -U <username> -d <database> `
  -c "SELECT pid, usename, datname, client_addr, state FROM pg_stat_activity;"
```

Check database sizes:

```powershell
kubectl exec <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- psql -U <username> -d <database> `
  -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database;"
```

Check table sizes:

```powershell
kubectl exec <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- psql -U <username> -d <database> `
  -c "SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC LIMIT 20;"
```

## 4. PostgreSQL connectivity from a temporary Pod

Run `pg_isready`:

```powershell
kubectl run postgres-client `
  --rm -it `
  --restart=Never `
  --namespace infrastructure-dev `
  --image=postgres:16 `
  -- pg_isready -h <postgres-service-name> -p 5432
```

Run a query:

```powershell
kubectl run postgres-client `
  --rm -it `
  --restart=Never `
  --namespace infrastructure-dev `
  --image=postgres:16 `
  --env="PGPASSWORD=<password>" `
  -- psql -h <postgres-service-name> -U <username> -d <database> -c "SELECT 1;"
```

Check the TCP port:

```powershell
kubectl run postgres-network-test `
  --rm -it `
  --restart=Never `
  --namespace infrastructure-dev `
  --image=busybox:1.36 `
  -- sh -c "nc -zv <postgres-service-name> 5432"
```

## 5. Port-forward for local access

Forward Redis:

```powershell
kubectl port-forward `
  --namespace infrastructure-dev `
  service/<redis-service-name> `
  6379:6379
```

In another terminal:

```powershell
redis-cli -h 127.0.0.1 -p 6379 ping
```

Forward PostgreSQL:

```powershell
kubectl port-forward `
  --namespace infrastructure-dev `
  service/<postgres-service-name> `
  5432:5432
```

In another terminal:

```powershell
psql -h 127.0.0.1 -p 5432 -U <username> -d <database>
```

Port-forwarding is useful for development and administration. It is not a production exposure method.

## 6. Helm inspection and upgrades

Check Redis release values:

```powershell
helm get values redis `
  --namespace infrastructure-dev
```

Check PostgreSQL release values:

```powershell
helm get values postgres `
  --namespace infrastructure-dev
```

Show rendered resources:

```powershell
helm get manifest redis `
  --namespace infrastructure-dev

helm get manifest postgres `
  --namespace infrastructure-dev
```

Upgrade Redis from a local chart:

```powershell
helm upgrade redis charts\redis `
  --namespace infrastructure-dev `
  --wait
```

Upgrade PostgreSQL from a local chart:

```powershell
helm upgrade postgres charts\postgres `
  --namespace infrastructure-dev `
  --wait
```

Check release history:

```powershell
helm history redis --namespace infrastructure-dev
helm history postgres --namespace infrastructure-dev
```

Rollback a release:

```powershell
helm rollback redis <revision> --namespace infrastructure-dev
helm rollback postgres <revision> --namespace infrastructure-dev
```

## 7. Backup reminders

### Redis

Check persistence status:

```powershell
kubectl exec <redis-pod-name> `
  --namespace infrastructure-dev `
  -- redis-cli -a '<redis-password>' INFO persistence
```

Redis persistence is not a substitute for a tested backup and restore process. Follow the chart's production guidance before treating AOF or a PVC as disaster recovery.

### PostgreSQL

Check PostgreSQL storage:

```powershell
kubectl get pvc `
  --namespace infrastructure-dev
```

A logical dump can be created with `pg_dump` from an approved backup location:

```powershell
kubectl exec <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- pg_dump -U <username> -d <database> > .\backup.sql
```

For large or production databases, use a planned backup system rather than relying on an interactive terminal redirect. Verify that the dump can be restored.

Restore only after confirming the target database and backup:

```powershell
Get-Content .\backup.sql | kubectl exec -i <postgres-pod-name> `
  --namespace infrastructure-dev `
  -- psql -U <username> -d <database>
```

Do not restore over a production database without an approved recovery procedure.

## 8. Common problems

### Redis Pod is running but clients cannot connect

Check:

```powershell
kubectl get endpoints <redis-service-name> --namespace infrastructure-dev
kubectl exec <redis-pod-name> --namespace infrastructure-dev -- redis-cli ping
kubectl get events --namespace infrastructure-dev --sort-by=.lastTimestamp
```

Likely causes:

- Wrong Service name or namespace.
- Redis authentication is enabled.
- Service has no endpoints.
- NetworkPolicy blocks port `6379`.
- Redis is not listening on the expected address.

### PostgreSQL rejects connections

Check:

```powershell
kubectl exec <postgres-pod-name> --namespace infrastructure-dev -- pg_isready
kubectl logs <postgres-pod-name> --namespace infrastructure-dev --tail=100
```

Likely causes:

- Incorrect username or password.
- Incorrect database name.
- PostgreSQL is still initializing.
- Service has no ready endpoints.
- PVC contains data initialized with different credentials.

### Credentials changed but access still fails

Redis and PostgreSQL credentials may be initialized into the data directory on first startup. Changing a Kubernetes Secret does not necessarily change credentials in already initialized data.

Check the chart documentation and data lifecycle before changing credentials or deleting storage.

### PVC is stuck or Pod is pending

Check:

```powershell
kubectl describe pvc <pvc-name> --namespace infrastructure-dev
kubectl get storageclass
kubectl describe pod <pod-name> --namespace infrastructure-dev
```

Do not delete a PVC casually. It may contain the only copy of the data.

## 9. Safe daily checklist

Run these checks before investigating an application connection problem:

```powershell
kubectl get pods --namespace infrastructure-dev
kubectl get services --namespace infrastructure-dev
kubectl get endpoints --namespace infrastructure-dev
kubectl get pvc --namespace infrastructure-dev
kubectl get events --namespace infrastructure-dev --sort-by=.lastTimestamp
```

Then test the native protocol:

```text
Redis:
    redis-cli ... ping

PostgreSQL:
    pg_isready ...
    psql ... -c "SELECT 1;"
```

## 10. Safety rules

- Never run `FLUSHALL` or `FLUSHDB` casually.
- Do not use `KEYS *` on a busy Redis instance.
- Do not run destructive SQL without a reviewed `WHERE` clause.
- Do not delete Redis or PostgreSQL PVCs without confirming backups.
- Do not expose Redis or PostgreSQL publicly for convenience.
- Keep passwords out of Git, screenshots, command history, and shared logs.
- Use `--namespace` explicitly when operating shared clusters.
- Test backup restoration, not only backup creation.
- Treat increasing `replicaCount` as insufficient for database HA.
