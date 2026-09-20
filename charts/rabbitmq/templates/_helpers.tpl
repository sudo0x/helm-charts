{{/*
Expand the name of the chart.
*/}}
{{- define "sudo0x-rabbitmq.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "sudo0x-rabbitmq.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "sudo0x-rabbitmq.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Chart name and version.
*/}}
{{- define "sudo0x-rabbitmq.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "sudo0x-rabbitmq.labels" -}}
helm.sh/chart: {{ include "sudo0x-rabbitmq.chart" . }}
app.kubernetes.io/name: {{ include "sudo0x-rabbitmq.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "sudo0x-rabbitmq.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sudo0x-rabbitmq.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Secret used for RabbitMQ bootstrap credentials.
*/}}
{{- define "sudo0x-rabbitmq.secretName" -}}
{{- default (include "sudo0x-rabbitmq.fullname" .) .Values.auth.existingSecret }}
{{- end }}
