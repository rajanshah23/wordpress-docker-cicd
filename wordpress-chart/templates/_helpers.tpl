{{- define "wordpress-chart.selectorLabels" -}}
app: {{ .Chart.Name }}
{{- end }}
