{{- define "desktop.user" -}}
{{- $u := required "username is required (--set username=jan)" .Values.username -}}
{{- if not (regexMatch "^[a-z][a-z0-9-]{0,30}$" $u) -}}
{{- fail (printf "invalid username %q: use lowercase letters, digits, hyphens" $u) -}}
{{- end -}}
{{- $u -}}
{{- end -}}

{{- define "desktop.name" -}}desktop-{{ include "desktop.user" . }}{{- end -}}
{{- define "desktop.home" -}}home-{{ include "desktop.user" . }}{{- end -}}
{{- define "desktop.hostname" -}}{{ include "desktop.user" . }}.{{ .Values.domain }}{{- end -}}
{{- define "desktop.cookieSecret" -}}
{{- default (printf "cookie-%s" (include "desktop.user" .)) .Values.auth.cookieSecretName -}}
{{- end -}}

{{- define "desktop.labels" -}}
app.kubernetes.io/name: desktop
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
innovatech/owner: {{ include "desktop.user" . }}
innovatech/role: {{ .Values.role }}
{{- end -}}

{{- define "desktop.selector" -}}
app: {{ include "desktop.name" . }}
{{- end -}}

{{- define "desktop.servicePort" -}}
{{- if .Values.auth.enabled }}4180{{ else }}3000{{ end -}}
{{- end -}}