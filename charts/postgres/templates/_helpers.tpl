{{/*
Expand the name of the chart.
*/}}
{{- define "sudo0x-postgres.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "sudo0x-postgres.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "sudo0x-postgres.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Chart name and version.
*/}}
{{- define "sudo0x-postgres.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "sudo0x-postgres.labels" -}}
helm.sh/chart: {{ include "sudo0x-postgres.chart" . }}
app.kubernetes.io/name: {{ include "sudo0x-postgres.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "sudo0x-postgres.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sudo0x-postgres.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Secret used for PostgreSQL credentials.
*/}}
{{- define "sudo0x-postgres.secretName" -}}
{{- default (include "sudo0x-postgres.fullname" .) .Values.auth.existingSecret }}
{{- end }}
