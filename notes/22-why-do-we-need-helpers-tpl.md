# Why do we need `_helpers.tpl` in Helm?

`_helpers.tpl` is a Helm helper template file used to define reusable template snippets that can be shared across your chart.

It helps keep your chart cleaner, more maintainable, and consistent.

## Main purpose

Helm charts often repeat the same logic, such as:
- naming resources
- setting labels
- creating selectors
- generating common metadata

Instead of writing the same logic repeatedly in each YAML file, we put that logic in `_helpers.tpl` and call it whenever needed.

## Example

Here is a simple helper:

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "mychart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
```

Then in other files:

```yaml
metadata:
  name: {{ include "mychart.name" . }}
```

This avoids repeating the same naming logic in multiple templates.

## Benefits of `_helpers.tpl`

### 1. Reusability
You define logic once and use it in many templates.

### 2. Consistency
All resources use the same naming, labeling, and metadata rules.

### 3. Less duplication
Your YAML files stay shorter and easier to read.

### 4. Easier maintenance
If naming or label rules change, you update them in one place.

### 5. Better chart structure
It keeps Helm templates organized and modular.

## Typical use cases

Common things stored in `_helpers.tpl`:

- name generation
- labels and annotations
- selector labels
- service names
- app version metadata
- common environment variables or config blocks

## Example with labels

```yaml
{{- define "mychart.labels" -}}
app.kubernetes.io/name: {{ include "mychart.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
```

Then use it like this:

```yaml
metadata:
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
```

## When to use it

Use `_helpers.tpl` when:
- you need the same logic in multiple files
- you want to centralize naming and labels
- you want cleaner template files

## Summary

`_helpers.tpl` is important because it stores reusable Helm template logic. It helps reduce duplication, keeps naming and labels consistent, and makes your chart easier to maintain.
