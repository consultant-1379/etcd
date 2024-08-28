{{- define "eric-data-distributed-coordinator-ed.hkln.job-inventory-contents" -}}
- supportedSource: ">= 4.0.0"
  supportedTarget: "<= 3.5.0"
  jobList:
    - weight: 1
      triggerWhen: ["pre-rollback"]
      jobManifest: {{ include "eric-data-distributed-coordinator-ed.shh-prerollback" . | fromYaml | toJson | b64enc | trim | nindent 8 }}
    - weight: 2
      triggerWhen: ["post-rollback"]
      jobManifest: {{ include "eric-data-distributed-coordinator-ed.shh-postrollback" . | fromYaml | toJson | b64enc | trim | nindent 8 }}

{{- end -}}

{{- define "eric-data-distributed-coordinator-ed.shh-prerollback" -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: eric-data-distributed-coordinator-ed-shh-prerollback
spec:
  template:
    metadata:
      labels:
        {{- include "eric-data-distributed-coordinator-ed.labels" . | nindent 8 }}
    spec:
      restartPolicy: OnFailure
      serviceAccountName: {{ template "eric-data-distributed-coordinator-ed.hkln.name" . }}-sa
      containers:
      - name: shh-prerollback
        image: {{ template "eric-data-distributed-coordinator-ed.imagePath" (merge (dict "imageName" "dced") .) }}
        imagePullPolicy: {{ template "eric-data-distributed-coordinator-ed.dced.imagePullPolicy" . }}
        resources:
          requests:
            memory: {{ .Values.resources.hooklauncher.requests.memory | quote }}
            cpu: {{ .Values.resources.hooklauncher.requests.cpu | quote }}
            {{- if index .Values.resources.hooklauncher.requests "ephemeral-storage" }}
            ephemeral-storage: {{ index .Values.resources.hooklauncher.requests "ephemeral-storage" | quote }}
            {{- end }}
          limits:
            memory: {{ .Values.resources.hooklauncher.limits.memory | quote }}
            cpu: {{ .Values.resources.hooklauncher.limits.cpu | quote }}
            {{- if index .Values.resources.hooklauncher.limits "ephemeral-storage" }}
            ephemeral-storage: {{ index .Values.resources.hooklauncher.limits "ephemeral-storage" | quote }}
            {{- end }}
        command:
          - /bin/sh
          - /usr/local/bin/scripts/shh_pre_rollback.sh
  backoffLimit: 10
{{- end -}}

{{- define "eric-data-distributed-coordinator-ed.shh-postrollback" -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: eric-data-distributed-coordinator-ed-shh-postrollback
spec:
  template:
    metadata:
      labels:
        {{- include "eric-data-distributed-coordinator-ed.labels" . | nindent 8 }}
    spec:
      restartPolicy: OnFailure
      serviceAccountName: {{ template "eric-data-distributed-coordinator-ed.hkln.name" . }}-sa
      containers:
      - name: shh-postrollback
        image: {{ template "eric-data-distributed-coordinator-ed.imagePath" (merge (dict "imageName" "dced") .) }}
        imagePullPolicy: {{ template "eric-data-distributed-coordinator-ed.dced.imagePullPolicy" . }}
        resources:
          requests:
            memory: {{ .Values.resources.hooklauncher.requests.memory | quote }}
            cpu: {{ .Values.resources.hooklauncher.requests.cpu | quote }}
            {{- if index .Values.resources.hooklauncher.requests "ephemeral-storage" }}
            ephemeral-storage: {{ index .Values.resources.hooklauncher.requests "ephemeral-storage" | quote }}
            {{- end }}
          limits:
            memory: {{ .Values.resources.hooklauncher.limits.memory | quote }}
            cpu: {{ .Values.resources.hooklauncher.limits.cpu | quote }}
            {{- if index .Values.resources.hooklauncher.limits "ephemeral-storage" }}
            ephemeral-storage: {{ index .Values.resources.hooklauncher.limits "ephemeral-storage" | quote }}
            {{- end }}
        command:
          - /bin/sh
          - /usr/local/bin/scripts/shh_post_rollback.sh
  backoffLimit: 10
{{- end -}}
