{{/*
Expand the name of the chart.
*/}}
{{- define "sudo0x-redis.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "sudo0x-redis.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "sudo0x-redis.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "sudo0x-redis.labels" -}}
helm.sh/chart: {{ include "sudo0x-redis.chart" . }}
app.kubernetes.io/name: {{ include "sudo0x-redis.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Chart name and version.
*/}}
{{- define "sudo0x-redis.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Secret used for Redis authentication.
*/}}
{{- define "sudo0x-redis.secretName" -}}
{{- default (include "sudo0x-redis.fullname" .) .Values.auth.existingSecret }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "sudo0x-redis.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sudo0x-redis.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
