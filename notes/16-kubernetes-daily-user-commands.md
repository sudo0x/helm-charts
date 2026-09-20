# Kubernetes Daily User Commands

This is a practical command reference for common Kubernetes development and operations tasks.

The examples use PowerShell-compatible commands and the namespaces used in this repository:

```text
infrastructure-dev
applications-dev
ingress-nginx
```

Replace namespaces, names, and labels with the values from your cluster.

## 1. Check cluster access

Show the active context:

```powershell
kubectl config current-context
```

List available contexts:

```powershell
kubectl config get-contexts
```

Switch context:

```powershell
kubectl config use-context <context-name>
```

Show client and server versions:

```powershell
kubectl version
```

Check the control plane:

```powershell
kubectl cluster-info
```

Check cluster API access:

```powershell
kubectl get --raw='/readyz?verbose'
```

## 2. Inspect nodes

List nodes:

```powershell
kubectl get nodes
```

Show node addresses and details:

```powershell
kubectl get nodes -o wide
```

Inspect one node:

```powershell
kubectl describe node <node-name>
```

Show node labels:

```powershell
kubectl get nodes --show-labels
```

Check node resource usage:

```powershell
kubectl top nodes
```

`kubectl top` requires Metrics Server.

## 3. Work with namespaces

List namespaces:

```powershell
kubectl get namespaces
```

Create a namespace:

```powershell
kubectl create namespace applications-dev
```

Set a default namespace for the current context:

```powershell
kubectl config set-context --current --namespace=applications-dev
```

Show the namespace currently configured in the context:

```powershell
kubectl config view --minify --output 'jsonpath={..namespace}'
```

List resources across every namespace:

```powershell
kubectl get pods --all-namespaces
```

## 4. List common resources

List all common resources in the current namespace:

```powershell
kubectl get all
```

List resources in a specific namespace:

```powershell
kubectl get all --namespace applications-dev
```

List Pods:

```powershell
kubectl get pods
kubectl get pods -o wide
```

List Deployments:

```powershell
kubectl get deployments
```

List StatefulSets:

```powershell
kubectl get statefulsets
```

List Services:

```powershell
kubectl get services
```

List ConfigMaps and Secrets:

```powershell
kubectl get configmaps
kubectl get secrets
```

List PersistentVolumeClaims:

```powershell
kubectl get pvc
```

List Ingress resources:

```powershell
kubectl get ingress
```

List resources in another namespace:

```powershell
kubectl get pods --namespace ingress-nginx
kubectl get ingress --namespace applications-dev
```

## 5. Inspect Pods

Show Pod status:

```powershell
kubectl get pods
```

Watch Pods while they start:

```powershell
kubectl get pods --watch
```

Show Pod labels and IP addresses:

```powershell
kubectl get pods --show-labels -o wide
```

Inspect a Pod:

```powershell
kubectl describe pod <pod-name>
```

List Pods selected by a label:

```powershell
kubectl get pods -l app.kubernetes.io/name=orders
```

Show Pod resource usage:

```powershell
kubectl top pods
```

Show usage in a namespace:

```powershell
kubectl top pods --namespace applications-dev
```

## 6. View logs

Show current logs:

```powershell
kubectl logs <pod-name>
```

Follow logs:

```powershell
kubectl logs --follow <pod-name>
```

Show the last 100 lines:

```powershell
kubectl logs <pod-name> --tail=100
```

Show logs from the previous crashed container:

```powershell
kubectl logs <pod-name> --previous
```

Show logs from a named container:

```powershell
kubectl logs <pod-name> --container <container-name>
```

Show logs from a Deployment:

```powershell
kubectl logs deployment/orders-service --follow
```

Show logs from all Pods matching a label:

```powershell
kubectl logs -l app.kubernetes.io/name=orders --all-containers=true --tail=100
```

## 7. Execute commands in containers

Open a shell:

```powershell
kubectl exec -it <pod-name> -- sh
```

Run one command:

```powershell
kubectl exec <pod-name> -- printenv
```

Select a namespace:

```powershell
kubectl exec -it <pod-name> --namespace applications-dev -- sh
```

Select a container:

```powershell
kubectl exec -it <pod-name> --container <container-name> -- sh
```

Not every image contains `bash` or `sh`. Use a debug container or a temporary diagnostic Pod when the application image is minimal.

## 8. Inspect Services and networking

Show Services:

```powershell
kubectl get services -o wide
```

Inspect a Service:

```powershell
kubectl describe service <service-name>
```

Show Service endpoints:

```powershell
kubectl get endpoints <service-name>
```

Show EndpointSlices:

```powershell
kubectl get endpointslices -l kubernetes.io/service-name=<service-name>
```

Port-forward a Service to the local machine:

```powershell
kubectl port-forward service/<service-name> 8080:80
```

Port-forward a Pod:

```powershell
kubectl port-forward pod/<pod-name> 8080:8080
```

Test a Service from inside the cluster:

```powershell
kubectl run network-test --rm -it --restart=Never --image=curlimages/curl -- curl http://<service-name>:8080/actuator/health
```

## 9. Inspect Ingress

List Ingress resources:

```powershell
kubectl get ingress --all-namespaces
```

Inspect an Ingress:

```powershell
kubectl describe ingress <ingress-name> --namespace applications-dev
```

List IngressClasses:

```powershell
kubectl get ingressclass
```

Inspect the NGINX controller:

```powershell
kubectl get pods --namespace ingress-nginx
kubectl get service --namespace ingress-nginx
kubectl logs deployment/ingress-nginx-controller --namespace ingress-nginx
```

## 10. Deploy and update applications

Apply a manifest:

```powershell
kubectl apply -f deployment.yaml
```

Apply a directory:

```powershell
kubectl apply -f .\manifests\
```

Create or update a Deployment image:

```powershell
kubectl set image deployment/orders-service orders-service=ghcr.io/sudo0x/orders-service:1.0.1
```

Watch a rollout:

```powershell
kubectl rollout status deployment/orders-service
```

Show rollout history:

```powershell
kubectl rollout history deployment/orders-service
```

Restart a Deployment:

```powershell
kubectl rollout restart deployment/orders-service
```

Roll back a Deployment:

```powershell
kubectl rollout undo deployment/orders-service
```

Pause and resume a rollout:

```powershell
kubectl rollout pause deployment/orders-service
kubectl rollout resume deployment/orders-service
```

## 11. Inspect configuration

Show a ConfigMap:

```powershell
kubectl get configmap <configmap-name> -o yaml
```

Show Secret metadata and keys without decoding values:

```powershell
kubectl describe secret <secret-name>
```

Decode one Secret value only when necessary:

```powershell
kubectl get secret <secret-name> -o jsonpath="{.data.<key>}" | `
  [System.Convert]::FromBase64String([Console]::In.ReadToEnd()) | `
  ForEach-Object { [System.Text.Encoding]::UTF8.GetString($_) }
```

Avoid printing credentials into shared terminals, logs, screenshots, or Git.

Show the complete live object:

```powershell
kubectl get deployment <deployment-name> -o yaml
```

## 12. Events and troubleshooting

List recent events:

```powershell
kubectl get events --sort-by=.lastTimestamp
```

List events in a namespace:

```powershell
kubectl get events --namespace applications-dev --sort-by=.lastTimestamp
```

Inspect a failing Pod:

```powershell
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl logs <pod-name> --previous
```

Common statuses:

```text
Pending:
    The Pod cannot be scheduled or its image/volume is not ready.

ContainerCreating:
    The image, volume, or networking setup is still in progress.

CrashLoopBackOff:
    The container starts, fails, and Kubernetes keeps retrying it.

ImagePullBackOff:
    Kubernetes cannot pull the configured image.

ErrImagePull:
    The image name, tag, registry, or credentials may be incorrect.

Running but not Ready:
    A readiness probe is failing or the application is not ready.
```

## 13. Storage

List PersistentVolumeClaims:

```powershell
kubectl get pvc
```

Inspect a PersistentVolumeClaim:

```powershell
kubectl describe pvc <pvc-name>
```

List PersistentVolumes:

```powershell
kubectl get pv
```

List StorageClasses:

```powershell
kubectl get storageclass
```

Inspect a StatefulSet:

```powershell
kubectl describe statefulset <statefulset-name>
```

Do not delete a PVC casually. It may contain the only copy of application data.

## 14. Labels and selectors

Show labels:

```powershell
kubectl get pods --show-labels
```

Filter by labels:

```powershell
kubectl get pods -l app.kubernetes.io/instance=orders-service
```

Add or change a label:

```powershell
kubectl label pod <pod-name> environment=development --overwrite
```

Labels must match the selectors used by Deployments and Services.

## 15. Resource definitions and API discovery

List supported resource types:

```powershell
kubectl api-resources
```

Explain a resource:

```powershell
kubectl explain deployment
kubectl explain deployment.spec.template.spec.containers
```

Show the API version of a resource:

```powershell
kubectl explain ingress --api-version=networking.k8s.io/v1
```

## 16. Delete resources safely

Delete one resource:

```powershell
kubectl delete pod <pod-name>
```

Delete a Deployment:

```powershell
kubectl delete deployment <deployment-name>
```

Delete a Service:

```powershell
kubectl delete service <service-name>
```

Delete resources from a manifest:

```powershell
kubectl delete -f deployment.yaml
```

Delete a namespace and everything managed inside it:

```powershell
kubectl delete namespace applications-dev
```

Always inspect the target namespace and resource names before deleting. Namespace deletion is broad and can remove applications, Services, Secrets, and storage claims.

## 17. Useful output formats

Show YAML:

```powershell
kubectl get pod <pod-name> -o yaml
```

Show JSON:

```powershell
kubectl get pod <pod-name> -o json
```

Show only a selected field:

```powershell
kubectl get pod <pod-name> -o jsonpath="{.status.podIP}"
```

Show resources sorted by name:

```powershell
kubectl get pods --sort-by=.metadata.name
```

Watch a command repeatedly:

```powershell
kubectl get pods --watch
```

## 18. A practical daily workflow

Start by checking the cluster:

```powershell
kubectl config current-context
kubectl cluster-info
kubectl get nodes
```

Inspect the target namespace:

```powershell
kubectl get all --namespace applications-dev
kubectl get events --namespace applications-dev --sort-by=.lastTimestamp
```

Check application health:

```powershell
kubectl get pods --namespace applications-dev -o wide
kubectl logs deployment/orders-service --namespace applications-dev --tail=100
kubectl get endpoints --namespace applications-dev
```

Check external routing:

```powershell
kubectl get ingress --namespace applications-dev
kubectl get pods --namespace ingress-nginx
```

After an update:

```powershell
kubectl rollout status deployment/orders-service --namespace applications-dev
kubectl get pods --namespace applications-dev
```

## 19. Kubernetes and Helm together

Use Helm to manage a release:

```powershell
helm list --all-namespaces
helm status orders-service --namespace applications-dev
helm upgrade --install orders-service charts/spring-boot-service `
  --namespace applications-dev `
  --create-namespace `
  --wait
```

Use `kubectl` to inspect the live resources created by Helm:

```powershell
kubectl get all --namespace applications-dev
kubectl describe deployment orders-service-sudo0x-spring-boot-service `
  --namespace applications-dev
```

Do not manually edit Helm-managed resources unless you understand that the next Helm upgrade may overwrite the change. Prefer changing chart values and running `helm upgrade`.

## 20. Safe daily habits

- Confirm the current context before changing resources.
- Specify `--namespace` for important commands.
- Inspect Pods, Services, endpoints, and events together when debugging.
- Check rollout status after application updates.
- Keep resource requests and limits configured.
- Treat Secrets and PVCs as sensitive.
- Do not expose databases or messaging systems publicly without a specific security design.
- Prefer Helm values and version-controlled manifests over manual live edits.
- Use `kubectl delete` carefully, especially for namespaces and PVCs.
- Record production changes and review them before execution.
