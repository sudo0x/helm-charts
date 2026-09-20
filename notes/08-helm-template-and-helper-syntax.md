# Helm Template and Helper Syntax Guide

This document explains the Helm template syntax used in the Redis and PostgreSQL charts.

It focuses on the files that initially look confusing:

```text
templates/_helpers.tpl
templates/statefulset.yaml
templates/service.yaml
templates/secret.yaml
values.yaml
```

The goal is to understand how Helm turns templates and values into normal Kubernetes YAML.

## 1. What Helm does

Helm combines:

```text
Chart templates
        +
values.yaml
        +
user-provided values
        ↓
Rendered Kubernetes YAML
```

For example, this template:

```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
```

with these values:

```yaml
image:
  repository: redis
  tag: "8.2"
```

renders as:

```yaml
image: "redis:8.2"
```

Helm does not run the Kubernetes resources directly. It first renders templates, then sends the resulting YAML to Kubernetes.

## 2. Helm chart files

```text
charts/redis/
├── Chart.yaml
├── values.yaml
├── README.md
└── templates/
    ├── _helpers.tpl
    ├── configmap.yaml
    ├── secret.yaml
    ├── service.yaml
    └── statefulset.yaml
```

### `Chart.yaml`

Contains chart metadata:

```yaml
apiVersion: v2
name: sudo0x-redis
version: 0.2.0
appVersion: "8.2"
```

### `values.yaml`

Contains configurable defaults:

```yaml
replicaCount: 1

image:
  repository: redis
  tag: "8.2"
```

### `templates/`

Contains Kubernetes manifests with Helm expressions.

### `_helpers.tpl`

Contains reusable named template helpers. It does not normally render a Kubernetes resource by itself.

## 3. Helm expression delimiters

Helm expressions use:

```gotemplate
{{ ... }}
```

Example:

```yaml
name: {{ .Values.service.name }}
```

If the value is:

```yaml
service:
  name: redis
```

the output is:

```yaml
name: redis
```

## 4. Whitespace control

These forms control whitespace around a Helm expression:

```gotemplate
{{ ... }}
{{- ... }}
{{ ... -}}
{{- ... -}}
```

The hyphen removes whitespace:

- `{{-` trims whitespace before the expression.
- `-}}` trims whitespace after the expression.

Example:

```gotemplate
{{- if .Values.enabled }}
enabled: true
{{- end }}
```

Whitespace control is useful for avoiding unwanted blank lines, but it does not replace correct YAML indentation.

## 5. Built-in context objects

Helm provides special objects through the dot:

```gotemplate
.
```

Common objects:

| Object | Meaning |
|---|---|
| `.Values` | Values from `values.yaml` and user overrides |
| `.Chart` | Chart metadata from `Chart.yaml` |
| `.Release` | Release name, namespace, service, and revision |
| `.Template` | Current template information |
| `.Capabilities` | Kubernetes cluster capabilities |
| `.` | Current template context |

## 6. `.Values`

Read a value:

```gotemplate
{{ .Values.replicaCount }}
```

Read a nested value:

```gotemplate
{{ .Values.image.repository }}
{{ .Values.image.tag }}
```

Template:

```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
```

Values:

```yaml
image:
  repository: postgres
  tag: "16"
```

Rendered output:

```yaml
image: "postgres:16"
```

## 7. `.Chart`

Read chart metadata:

```gotemplate
{{ .Chart.Name }}
{{ .Chart.Version }}
{{ .Chart.AppVersion }}
```

Example:

```yaml
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
```

If `appVersion` is `"16"`, the result is:

```yaml
app.kubernetes.io/version: "16"
```

## 8. `.Release`

Read release information:

```gotemplate
{{ .Release.Name }}
{{ .Release.Namespace }}
{{ .Release.Service }}
{{ .Release.IsInstall }}
{{ .Release.IsUpgrade }}
```

If installed with:

```bash
helm upgrade --install redis charts/redis \
  --namespace infrastructure
```

then:

```gotemplate
{{ .Release.Name }}
```

renders as:

```text
redis
```

Avoid hardcoding release names in templates.

Good:

```gotemplate
name: {{ include "sudo0x-redis.fullname" . }}
```

Avoid:

```yaml
name: redis-production
```

## 9. What is `_helpers.tpl`?

`_helpers.tpl` is a collection of reusable named templates.

It helps prevent repeated naming and label logic across:

- StatefulSet.
- Service.
- ConfigMap.
- Secret.
- Deployment.

Example helper:

```gotemplate
{{- define "sudo0x-redis.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
```

This defines a helper called:

```text
sudo0x-redis.name
```

It does not render output until another template calls it.

## 10. `define`

`define` creates a named reusable template:

```gotemplate
{{- define "sudo0x-postgres.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
```

The name should be unique to the chart:

```text
sudo0x-postgres.name
sudo0x-postgres.fullname
sudo0x-postgres.labels
```

Do not reuse another chart's helper names. Redis and PostgreSQL should have separate helper namespaces.

## 11. `include`

`include` calls a named helper:

```gotemplate
{{ include "sudo0x-postgres.fullname" . }}
```

The final `.` passes the current context to the helper.

Example:

```yaml
metadata:
  name: {{ include "sudo0x-postgres.fullname" . }}
```

If the helper renders:

```text
postgres-sudo0x-postgres
```

the final YAML is:

```yaml
metadata:
  name: postgres-sudo0x-postgres
```

## 12. `template` versus `include`

Helm supports both:

```gotemplate
{{ template "helper.name" . }}
{{ include "helper.name" . }}
```

Prefer `include` because its output can be passed through formatting functions:

```gotemplate
{{ include "sudo0x-postgres.labels" . | nindent 4 }}
```

This is one of the most common helper patterns.

## 13. `default`

`default` returns a fallback when a value is empty:

```gotemplate
{{ default "ClusterIP" .Values.service.type }}
```

If `service.type` is empty, the result is:

```text
ClusterIP
```

The helper uses:

```gotemplate
{{ default .Chart.Name .Values.nameOverride }}
```

This means:

```text
Use nameOverride when it is set.
Otherwise use Chart.Name.
```

## 14. `required`

`required` fails rendering when a value is empty:

```gotemplate
{{ required "auth.password is required" .Values.auth.password }}
```

Use it only when a value is genuinely required for the selected mode.

Good conditional use:

```gotemplate
{{- if and .Values.auth.enabled (not .Values.auth.existingSecret) }}
password: {{ required "auth.password is required" .Values.auth.password | quote }}
{{- end }}
```

This requires a password only when:

```text
Authentication is enabled
AND
An existing Secret is not being used
```

Bad use:

```gotemplate
{{ required "auth.existingSecret is required" .Values.auth.existingSecret }}
```

This is wrong when `existingSecret` is intentionally optional.

## 15. `quote`

`quote` wraps a value in quotes:

```gotemplate
{{ .Values.image.tag | quote }}
```

Output:

```yaml
tag: "16"
```

Use quotes for:

- Passwords.
- Image tags.
- Application versions.
- Values that could be interpreted as numbers or booleans.

Example:

```gotemplate
stringData:
  password: {{ .Values.auth.password | quote }}
```

## 16. Pipelines

Helm functions can be chained with the pipe operator:

```gotemplate
{{ .Values.name | quote }}
```

Read this as:

```text
Pass .Values.name into quote.
```

Multiple functions:

```gotemplate
{{ .Chart.Name | trunc 63 | trimSuffix "-" }}
```

The value flows from left to right:

```text
Chart.Name
  ↓
truncate to 63 characters
  ↓
remove a trailing hyphen
```

## 17. `trunc`

Kubernetes names commonly have a maximum length of 63 characters.

Use:

```gotemplate
{{ .Values.fullnameOverride | trunc 63 }}
```

The helper pattern:

```gotemplate
{{ printf "%s-%s" .Release.Name (include "sudo0x-redis.name" .) | trunc 63 | trimSuffix "-" }}
```

creates a name and then ensures it is short enough.

## 18. `trimSuffix`

Remove a suffix:

```gotemplate
{{ "redis-" | trimSuffix "-" }}
```

Result:

```text
redis
```

This is useful after truncation because truncation could leave a name ending in `-`.

## 19. `printf`

Format strings:

```gotemplate
{{ printf "%s-%s" .Release.Name (include "sudo0x-redis.name" .) }}
```

If:

```text
Release.Name = redis
name = sudo0x-redis
```

the result is:

```text
redis-sudo0x-redis
```

Common format verbs:

| Verb | Meaning |
|---|---|
| `%s` | String |
| `%d` | Integer |
| `%t` | Boolean |
| `%v` | General value |

## 20. `toYaml`

Convert a values object to YAML:

```gotemplate
{{ toYaml .Values.resources }}
```

Common usage:

```gotemplate
resources:
  {{- toYaml .Values.resources | nindent 12 }}
```

Values:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
```

Rendered output:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
```

`toYaml` is useful for maps and lists such as:

- Resources.
- Security contexts.
- Labels.
- Annotations.
- Tolerations.
- Affinity.
- Access modes.

## 21. `indent` and `nindent`

`indent` adds spaces:

```gotemplate
{{ toYaml .Values.resources | indent 12 }}
```

`nindent` adds a newline and spaces:

```gotemplate
{{ toYaml .Values.resources | nindent 12 }}
```

In Kubernetes templates, `nindent` is commonly safer:

```yaml
resources:
  {{- toYaml .Values.resources | nindent 12 }}
```

The number must match the YAML nesting level.

Example:

```gotemplate
metadata:
  labels:
    {{- include "sudo0x-redis.labels" . | nindent 4 }}
```

The labels helper output is indented four spaces under `labels`.

## 22. `if`

Render content conditionally:

```gotemplate
{{- if .Values.persistence.enabled }}
volumeClaimTemplates:
  ...
{{- end }}
```

If the value is true, the block renders.

If the value is false, it does not render.

## 23. `else`

Choose between two blocks:

```gotemplate
{{- if .Values.persistence.enabled }}
volumeClaimTemplates:
  ...
{{- else }}
volumes:
  - name: data
    emptyDir: {}
{{- end }}
```

This is how the Redis and PostgreSQL charts select PVC or `emptyDir`.

## 24. `else if`

Chain conditions:

```gotemplate
{{- if .Values.auth.existingSecret }}
secretKeyRef:
  name: {{ .Values.auth.existingSecret }}
{{- else if .Values.auth.enabled }}
valueFrom:
  secretKeyRef:
    name: generated-secret
{{- else }}
value: development
{{- end }}
```

Use this when modes are mutually exclusive.

## 25. Boolean functions

### `and`

All conditions must be true:

```gotemplate
{{- if and .Values.auth.enabled (not .Values.auth.existingSecret) }}
```

Meaning:

```text
auth.enabled is true
AND
existingSecret is empty
```

### `or`

At least one condition must be true:

```gotemplate
{{- if or .Values.ingress.enabled .Values.gateway.enabled }}
```

### `not`

Invert a condition:

```gotemplate
{{- if not .Values.persistence.enabled }}
```

Meaning:

```text
persistence.enabled is false
```

## 26. `with`

Change the current context to a nested object:

```gotemplate
{{- with .Values.ingress.annotations }}
annotations:
  {{- toYaml . | nindent 4 }}
{{- end }}
```

Inside the block, `.` means the annotations object.

Without `with`:

```gotemplate
{{- if .Values.ingress.annotations }}
annotations:
  {{- toYaml .Values.ingress.annotations | nindent 4 }}
{{- end }}
```

Use whichever is clearer.

## 27. `range`

Loop over a list or map:

```gotemplate
{{- range .Values.persistence.accessModes }}
- {{ . }}
{{- end }}
```

Values:

```yaml
accessModes:
  - ReadWriteOnce
```

Rendered:

```yaml
accessModes:
  - ReadWriteOnce
```

Loop over environment variables:

```gotemplate
{{- range .Values.env }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
```

## 28. `lookup`

`lookup` queries an existing Kubernetes resource:

```gotemplate
{{ lookup "v1" "Secret" .Release.Namespace "my-secret" }}
```

Use it carefully. It requires access to the Kubernetes API and can make rendering behave differently between:

```bash
helm template
```

and:

```bash
helm install
```

Avoid `lookup` unless the chart genuinely needs to inspect existing cluster resources.

## 29. Name helper pattern

The PostgreSQL name helper:

```gotemplate
{{- define "sudo0x-postgres.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
```

Meaning:

```text
Use nameOverride if provided.
Otherwise use Chart.Name.
Limit the result to 63 characters.
Remove a trailing hyphen.
```

## 30. Fullname helper pattern

```gotemplate
{{- define "sudo0x-postgres.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "sudo0x-postgres.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
```

Meaning:

1. Use `fullnameOverride` if supplied.
2. Otherwise combine the Helm release name and chart name.
3. Limit the result to 63 characters.
4. Remove a trailing hyphen.

Example:

```text
Release name: postgres
Chart name: sudo0x-postgres
Full name: postgres-sudo0x-postgres
```

## 31. Labels helper pattern

```gotemplate
{{- define "sudo0x-postgres.labels" -}}
helm.sh/chart: {{ include "sudo0x-postgres.chart" . }}
app.kubernetes.io/name: {{ include "sudo0x-postgres.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

Use it:

```yaml
metadata:
  labels:
    {{- include "sudo0x-postgres.labels" . | nindent 4 }}
```

Labels provide consistent identity and support selectors, monitoring, and operations.

## 32. Selector labels helper pattern

```gotemplate
{{- define "sudo0x-postgres.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sudo0x-postgres.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

Use the same selector labels on the Service and pod:

```yaml
spec:
  selector:
    {{- include "sudo0x-postgres.selectorLabels" . | nindent 4 }}
```

StatefulSet:

```yaml
spec:
  selector:
    matchLabels:
      {{- include "sudo0x-postgres.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "sudo0x-postgres.selectorLabels" . | nindent 8 }}
```

Selectors must match pod labels. If they do not, Services will not route traffic correctly and the workload may be rejected by Kubernetes.

## 33. Secret helper pattern

```gotemplate
{{- define "sudo0x-postgres.secretName" -}}
{{- default (include "sudo0x-postgres.fullname" .) .Values.auth.existingSecret }}
{{- end }}
```

Meaning:

```text
If auth.existingSecret is set, use it.
Otherwise use the chart-generated Secret name.
```

Use it consistently:

```gotemplate
name: {{ include "sudo0x-postgres.secretName" . }}
```

This avoids hardcoding a Secret name.

## 34. Secret conditional pattern

```gotemplate
{{- if and .Values.auth.enabled (not .Values.auth.existingSecret) }}
apiVersion: v1
kind: Secret
...
{{- end }}
```

Meaning:

```text
Create a Secret only when:
authentication is enabled
AND
existingSecret is empty
```

When an existing Secret is supplied, the chart must not create a duplicate Secret.

## 35. Secret value pattern

```gotemplate
stringData:
  password: {{ .Values.auth.password | quote }}
```

`stringData` lets Kubernetes encode the value into the Secret.

Do not place password values in ConfigMaps:

Bad:

```yaml
kind: ConfigMap
data:
  password: change-me
```

Good:

```yaml
kind: Secret
stringData:
  password: change-me
```

For production, prefer an existing Secret rather than committing a password in values.

## 36. Conditional environment variable pattern

```gotemplate
{{- if .Values.auth.existingSecret }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "sudo0x-postgres.secretName" . }}
      key: {{ .Values.auth.passwordKey }}
{{- else }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "sudo0x-postgres.secretName" . }}
      key: {{ .Values.auth.passwordKey }}
{{- end }}
```

Both branches may use the same Secret helper, while the chart controls whether the Secret is generated or external.

## 37. ConfigMap pattern

Template:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "sudo0x-redis.fullname" . }}-config
data:
  redis.conf: |
    appendonly {{ .Values.redis.appendonly }}
    maxmemory-policy {{ .Values.redis.maxmemoryPolicy }}
```

Important:

- Use ConfigMaps for non-sensitive configuration.
- Do not place passwords in ConfigMaps.
- Use a block scalar `|` for multi-line configuration.

## 38. StatefulSet conditional storage

PVC mode:

```gotemplate
{{- if .Values.persistence.enabled }}
volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      resources:
        requests:
          storage: {{ .Values.persistence.size }}
{{- end }}
```

Temporary mode:

```gotemplate
{{- if not .Values.persistence.enabled }}
volumes:
  - name: postgres-data
    emptyDir: {}
{{- end }}
```

The container mount must use the same volume name:

```yaml
volumeMounts:
  - name: postgres-data
    mountPath: /var/lib/postgresql/data
```

## 39. Template comments

Helm template comments:

```gotemplate
{{/* This comment is not rendered into Kubernetes YAML. */}}
```

YAML comments:

```yaml
# This comment remains in rendered YAML.
```

Use template comments in `_helpers.tpl` to explain helper purpose.

## 40. Common syntax mistakes

### Missing closing braces

Wrong:

```gotemplate
{{ .Values.image.tag }
```

Correct:

```gotemplate
{{ .Values.image.tag }}
```

### Incorrect helper name

Wrong:

```gotemplate
{{ include "company-redis.fullname" . }}
```

when the helper is defined as:

```gotemplate
{{ define "sudo0x-redis.fullname" }}
```

Correct:

```gotemplate
{{ include "sudo0x-redis.fullname" . }}
```

### Missing context

Wrong:

```gotemplate
{{ include "sudo0x-redis.labels" }}
```

Correct:

```gotemplate
{{ include "sudo0x-redis.labels" . }}
```

### Incorrect indentation

Wrong:

```yaml
metadata:
  labels:
  {{ include "sudo0x-redis.labels" . }}
```

Correct:

```yaml
metadata:
  labels:
    {{- include "sudo0x-redis.labels" . | nindent 4 }}
```

### Required optional value

Wrong:

```gotemplate
{{ required "existingSecret is required" .Values.auth.existingSecret }}
```

Correct:

```gotemplate
{{- if and .Values.auth.enabled (not .Values.auth.existingSecret) }}
{{ required "password is required" .Values.auth.password }}
{{- end }}
```

### Password in ConfigMap

Do not put credentials in normal configuration:

```yaml
kind: ConfigMap
```

Use:

```yaml
kind: Secret
```

## 41. Debugging template errors

Lint:

```bash
helm lint charts/redis
```

Render with debug output:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  --debug
```

Render one template:

```bash
helm template redis charts/redis \
  --show-only templates/statefulset.yaml \
  --namespace infrastructure \
  --debug
```

Validate against the Kubernetes API without applying:

```bash
helm upgrade --install redis charts/redis \
  --namespace infrastructure \
  --create-namespace \
  --dry-run=server \
  --debug
```

Save the result:

```bash
helm template redis charts/redis \
  --namespace infrastructure \
  > /tmp/redis-rendered.yaml
```

Then inspect:

```bash
cat /tmp/redis-rendered.yaml
```

## 42. The template development loop

Use this loop whenever editing a chart:

```text
1. Edit values.yaml or a template.
2. Run helm lint.
3. Run helm template.
4. Inspect the rendered YAML.
5. Test important value combinations.
6. Run a dry-run against Kubernetes when available.
7. Install or upgrade in a test namespace.
8. Inspect pods and events.
```

Commands:

```bash
helm lint charts/redis
helm template redis charts/redis -n infrastructure
helm template redis charts/redis -n infrastructure \
  --set auth.existingSecret=my-secret
helm template redis charts/redis -n infrastructure \
  --set persistence.enabled=false
helm upgrade --install redis charts/redis \
  -n infrastructure-test \
  --create-namespace \
  --wait \
  --atomic
kubectl get pods -n infrastructure-test
```

## 43. Practical helper checklist

When writing `_helpers.tpl`, check:

- [ ] Helper names are unique to the chart.
- [ ] `nameOverride` is supported.
- [ ] `fullnameOverride` is supported.
- [ ] Names are truncated to 63 characters.
- [ ] Trailing hyphens are removed.
- [ ] Common labels are reusable.
- [ ] Selector labels are reusable.
- [ ] Selector labels match pod labels.
- [ ] Existing Secret names are supported.
- [ ] `include` passes the current context with `.`.
- [ ] Helper output is indented with `nindent`.

## 44. Practical template checklist

Before considering a template complete:

- [ ] YAML indentation is valid.
- [ ] Values have sensible defaults.
- [ ] Optional resources are controlled by values.
- [ ] Secrets are not exposed in ConfigMaps.
- [ ] Names are not hardcoded to one release.
- [ ] Namespace is not hardcoded.
- [ ] Selectors match labels.
- [ ] Resource requests and limits are supported.
- [ ] Security contexts are supported.
- [ ] Probes use the correct command or endpoint.
- [ ] PVC and `emptyDir` modes are mutually correct.
- [ ] `helm lint` passes.
- [ ] `helm template` output is inspected.

## 45. Quick memory guide

```text
.Values       = chart configuration
.Chart        = Chart.yaml metadata
.Release      = Helm release information
define        = create a reusable helper
include       = call a helper
default       = fallback value
required      = fail when a needed value is empty
if            = conditional rendering
with          = change context
range         = loop
toYaml        = convert values to YAML
nindent       = newline plus indentation
quote         = wrap a value in quotes
printf        = format a string
trunc         = limit name length
trimSuffix    = remove trailing text
```

The most common helper call is:

```gotemplate
{{- include "sudo0x-redis.labels" . | nindent 4 }}
```

Read it as:

```text
Call the redis labels helper with the current context,
then indent its output by four spaces.
```
