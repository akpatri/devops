{{/* Return a short DNS-safe name; Kubernetes name fields are usually limited to 63 characters. */}}
{{- define "learning-web.name" -}}{{/* Define a reusable short-name helper. */}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}{{/* Use the chart name unless nameOverride is set, then truncate safely. */}}
{{- end -}}{{/* End the short-name helper. */}}

{{/* Return the release-specific base name used by every parent-chart resource. */}}
{{- define "learning-web.fullname" -}}{{/* Define the shared fullname helper. */}}
{{- if .Values.fullnameOverride -}}{{/* Prefer an explicit complete name when provided. */}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{/* Keep overrides within Kubernetes naming limits. */}}
{{- else -}}{{/* Otherwise combine the release and short chart names. */}}
{{- printf "%s-%s" .Release.Name (include "learning-web.name" .) | trunc 63 | trimSuffix "-" -}}{{/* Generate a predictable release-scoped name. */}}
{{- end -}}{{/* End the override condition. */}}
{{- end -}}{{/* End the fullname helper. */}}

{{/* Choose the created ServiceAccount name or an existing/default account. */}}
{{- define "learning-web.serviceAccountName" -}}{{/* Define the account-name helper. */}}
{{- if .Values.serviceAccount.create -}}{{/* Enter this branch when this chart creates the account. */}}
{{- default (include "learning-web.fullname" .) .Values.serviceAccount.name -}}{{/* Use the explicit name or the generated fullname. */}}
{{- else -}}{{/* Do not create an account when serviceAccount.create is false. */}}
{{- default "default" .Values.serviceAccount.name -}}{{/* Use the given existing name or Kubernetes default. */}}
{{- end -}}{{/* End the create-account condition. */}}
{{- end -}}{{/* End the account-name helper. */}}

{{/* Add descriptive labels; selector labels below intentionally stay stable. */}}
{{- define "learning-web.labels" -}}{{/* Define labels shared by chart resources. */}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }} # Record the chart name and version.
app.kubernetes.io/name: {{ include "learning-web.name" . }} # Identify this application.
app.kubernetes.io/instance: {{ .Release.Name }} # Distinguish releases of the same chart.
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }} # Record the packaged application version.
app.kubernetes.io/managed-by: {{ .Release.Service }} # Identify Helm as the manager.
{{- end -}}{{/* End the common-label helper. */}}

{{/* Kubernetes selectors must stay stable across upgrades. */}}
{{- define "learning-web.selectorLabels" -}}{{/* Define labels used to connect Services and Pods. */}}
app.kubernetes.io/name: {{ include "learning-web.name" . }} # Select Pods belonging to this chart name.
app.kubernetes.io/instance: {{ .Release.Name }} # Restrict selection to this release.
{{- end -}}{{/* End the selector-label helper. */}}

{{/* Build either a tag-based image reference or an immutable digest reference. */}}
{{- define "learning-web.image" -}}{{/* Define the shared image-reference helper. */}}
{{- $registry := .Values.global.imageRegistry | default .Values.image.registry -}}{{/* Let the global registry override the image-specific one. */}}
{{- if .Values.image.digest -}}{{/* Prefer a digest when one is explicitly supplied. */}}
{{- printf "%s/%s@%s" $registry .Values.image.repository .Values.image.digest -}}{{/* Digests identify immutable image content. */}}
{{- else -}}{{/* Use the configured tag when no digest was supplied. */}}
{{- printf "%s/%s:%s" $registry .Values.image.repository .Values.image.tag -}}{{/* Tags are easier for a learning demo to read. */}}
{{- end -}}{{/* End the digest-versus-tag condition. */}}
{{- end -}}{{/* End the image helper. */}}
