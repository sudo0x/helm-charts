{{- define "sudo0x-spring-boot-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "sudo0x-spring-boot-service.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "sudo0x-spring-boot-service.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "sudo0x-spring-boot-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "sudo0x-spring-boot-service.labels" -}}
helm.sh/chart: {{ include "sudo0x-spring-boot-service.chart" . }}
app.kubernetes.io/name: {{ include "sudo0x-spring-boot-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "sudo0x-spring-boot-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sudo0x-spring-boot-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "sudo0x-spring-boot-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "sudo0x-spring-boot-service.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
