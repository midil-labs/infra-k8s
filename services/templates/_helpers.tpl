{{/*
Expand the name of the service.
*/}}
{{- define "onekg-service.name" -}}
{{- default .Values.serviceName .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "onekg-service.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Values.serviceName .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "onekg-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "onekg-service.labels" -}}
helm.sh/chart: {{ include "onekg-service.chart" . }}
{{ include "onekg-service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: onekg-platform
service.onekg.io/name: {{ .Values.serviceName }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "onekg-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "onekg-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "onekg-service.serviceAccountName" -}}
{{- if .Values.security.serviceAccount.create }}
{{- default (include "onekg-service.fullname" .) .Values.security.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.security.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Health check path with service prefix
*/}}
{{- define "onekg-service.healthPath" -}}
{{- if .Values.healthCheck.enabled }}
{{- .Values.healthCheck.path }}
{{- else }}
{{- printf "%s/health" .Values.ingress.path }}
{{- end }}
{{- end }}
