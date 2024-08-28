{{/*
Create a map from global values with defaults if not in the values file.
*/}}
{{ define "eric-data-distributed-coordinator-ed.globalMap" }}
  {{- $globalDefaults := dict "security" (dict "securityPolicy" (dict "rolekind" "")) -}}
  {{- $globalDefaults := merge $globalDefaults (dict "security" (dict "tls" (dict "trustedInternalRootCa" (dict "secret" "eric-sec-sip-tls-trusted-root-cert")))) -}}
  {{ if .Values.global }}
    {{- mergeOverwrite $globalDefaults .Values.global | toJson -}}
  {{ else }}
    {{- $globalDefaults | toJson -}}
  {{ end }}
{{ end }}

{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "eric-data-distributed-coordinator-ed.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "eric-data-distributed-coordinator-ed.chart" -}}
  {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "eric-data-distributed-coordinator-ed.pullSecret.global" -}}
{{- $pullSecret := "" -}}
{{- if .Values.global -}}
    {{- if .Values.global.pullSecret -}}
      {{- $pullSecret = .Values.global.pullSecret -}}
    {{- end -}}
{{- end -}}
{{- print $pullSecret -}}
{{- end -}}

{{/*
Create image pull secret, service level parameter takes precedence
*/}}
{{- define "eric-data-distributed-coordinator-ed.pullSecret" -}}
{{- $pullSecret := ( include "eric-data-distributed-coordinator-ed.pullSecret.global" . ) -}}
  {{- if .Values.imageCredentials.pullSecret -}}
    {{- $pullSecret = .Values.imageCredentials.pullSecret -}}
  {{- end -}}
{{- print $pullSecret -}}
{{- end -}}

{{/*
create internalIPFamily
*/}}
{{- define "eric-data-distributed-coordinator-ed.internalIPFamily.global" -}}
{{- $ipFamilies := "" -}}
{{- if .Values.global -}}
  {{- if .Values.global.internalIPFamily -}}
      {{- $ipFamilies = .Values.global.internalIPFamily -}}
  {{- end }}
{{- end }}
{{- print $ipFamilies -}}
{{- end -}}


{{- define "eric-data-distributed-coordinator-ed.imagePullPolicy.global" -}}
{{- $imagePullPolicy := "IfNotPresent" -}}
{{- if .Values.global -}}
    {{- if .Values.global.registry -}}
        {{- if .Values.global.registry.imagePullPolicy -}}
            {{- $imagePullPolicy = .Values.global.registry.imagePullPolicy -}}
        {{- end -}}
    {{- end -}}
{{- end -}}
{{- print $imagePullPolicy -}}
{{- end -}}

{{/*
Pull policy for the dced container
*/}}
{{- define "eric-data-distributed-coordinator-ed.dced.imagePullPolicy" -}}
{{- $imagePullPolicy := ( include "eric-data-distributed-coordinator-ed.imagePullPolicy.global" . ) -}}
{{- if .Values.imageCredentials.dced.registry.imagePullPolicy -}}
    {{- $imagePullPolicy = .Values.imageCredentials.dced.registry.imagePullPolicy -}}
{{- end -}}
{{- print $imagePullPolicy -}}
{{- end -}}

{{/*
Pull policy for the brAgent container
*/}}
{{- define "eric-data-distributed-coordinator-ed.brAgent.imagePullPolicy" -}}
{{- $imagePullPolicy := ( include "eric-data-distributed-coordinator-ed.imagePullPolicy.global" . ) -}}
{{- if .Values.imageCredentials.brAgent.registry.imagePullPolicy -}}
    {{- $imagePullPolicy = .Values.imageCredentials.brAgent.registry.imagePullPolicy -}}
{{- end -}}
{{- print $imagePullPolicy -}}
{{- end -}}

{{/*
Argument: imageName
Returns image path of provided imageName.
*/}}
{{- define "eric-data-distributed-coordinator-ed.imagePath" }}
    {{- $productInfo := fromYaml (.Files.Get "eric-product-info.yaml") -}}
    {{- $image := (get $productInfo.images .imageName) -}}
    {{- $registryUrl := $image.registry -}}
    {{- $repoPath := $image.repoPath -}}
    {{- $name := $image.name -}}
    {{- $tag := $image.tag -}}

    {{- if .Values.global -}}
        {{- if .Values.global.registry -}}
            {{- if .Values.global.registry.url -}}
                {{- $registryUrl = .Values.global.registry.url -}}
            {{- end -}}
            {{- if not (kindIs "invalid" .Values.global.registry.repoPath) -}}
                {{- $repoPath = .Values.global.registry.repoPath -}}
            {{- end -}}
        {{- end -}}
    {{- end -}}
    {{- if .Values.imageCredentials -}}
        {{- if not (kindIs "invalid" .Values.imageCredentials.repoPath) -}}
            {{- $repoPath = .Values.imageCredentials.repoPath -}}
        {{- end -}}
        {{- if hasKey .Values.imageCredentials .imageName -}}
            {{- $credImage := get .Values.imageCredentials .imageName }}
            {{- if $credImage.registry -}}
                {{- if $credImage.registry.url -}}
                    {{- $registryUrl = $credImage.registry.url -}}
                {{- end -}}
            {{- end -}}
            {{- if not (kindIs "invalid" $credImage.repoPath) -}}
                {{- $repoPath = $credImage.repoPath -}}
            {{- end -}}
        {{- end -}}
    {{- end -}}
    {{- if $repoPath -}}
        {{- $repoPath = printf "%s/" $repoPath -}}
    {{- end -}}
    {{- if .Values.images -}}
      {{- if eq .imageName "dced" -}}
        {{- $name = ( include "eric-data-distributed-coordinator-ed.image.dced.name" . ) -}}
        {{- $tag = ( include "eric-data-distributed-coordinator-ed.image.dced.tag" . ) -}}
      {{- else if hasKey .Values.images .imageName -}}
          {{- $deprecatedImageParam := get .Values.images .imageName }}
          {{- if $deprecatedImageParam.name }}
              {{- $name = $deprecatedImageParam.name -}}
          {{- end -}}
          {{- if $deprecatedImageParam.tag }}
              {{- $tag = $deprecatedImageParam.tag -}}
          {{- end -}}
      {{- end -}}
    {{- end -}}
    {{- $imagePath := printf "%s/%s/%s:%s" $registryUrl $repoPath $name $tag -}}
    {{- print (regexReplaceAll "[/]+" $imagePath "/") -}}
{{- end -}}


{{/*
serviceAccount - will be deprecated from k8 1.22.0 onwards, supporting it for older versions
*/}}

{{- define "eric-data-distributed-coordinator-ed.serviceAccount" -}}
{{- $MinorVersion := int (.Capabilities.KubeVersion.Minor) -}}
{{- if lt $MinorVersion 22 -}}
  serviceAccount: ""
{{- end -}}
{{- end -}}


{{/*
DR-HC-113 ( BRAgent will not have an endpoint will have mtls by default)
Aligning with toggling with global.security.tls.enabled parameter - if set mtls is enforced between BRO and DCEDBrAgent.
*/}}

{{- define "eric-data-distributed-coordinator-ed.brAgent.tls" -}}
{{- $tls := true -}}
{{- if .Values.global -}}
    {{- if .Values.global.security -}}
          {{- if .Values.global.security.tls -}}
            {{- $tls = .Values.global.security.tls.enabled -}}
          {{- end -}}
    {{- end -}}
{{- end -}}
{{- $tls -}}
{{- end -}}

{{/*
 Ports - dced -peer
*/}}
{{- define "eric-data-distributed-coordinator-ed.ports.peer" -}}
{{- $peerPort := 2380 -}}
{{- print $peerPort -}}
{{- end -}}

{{/*
Create peer url
*/}}

{{- define "eric-data-distributed-coordinator-ed.peerUrl" -}}
   {{- printf "https://0.0.0.0:%d" (int64 (include "eric-data-distributed-coordinator-ed.ports.peer" . )) -}}
{{- end -}}

{{/*
If the timezone isn't set by a global parameter, set it to UTC
*/}}
{{- define "eric-data-distributed-coordinator-ed.timezone" -}}
{{- if .Values.global -}}
    {{- .Values.global.timezone | default "UTC" | quote -}}
{{- else -}}
    "UTC"
{{- end -}}
{{- end -}}

{{/*
Return the fsgroup set via global parameter if it's set, otherwise 10000
*/}}
{{- define "eric-data-distributed-coordinator-ed.fsGroup.coordinated" -}}
    {{- if .Values.global -}}
        {{- if .Values.global.fsGroup -}}
            {{- if .Values.global.fsGroup.manual -}}
                {{ .Values.global.fsGroup.manual }}
            {{- else -}}
                {{- if eq .Values.global.fsGroup.namespace true -}}
                     # The 'default' defined in the Security Policy will be used.
                {{- else -}}
                    10000
                {{- end -}}
            {{- end -}}
        {{- else -}}
            10000
        {{- end -}}
    {{- else -}}
        10000
    {{- end -}}
{{- end -}}

{{/*
 Security TLS - enabled check
*/}}

{{- define "eric-data-distributed-coordinator-ed.tls.enabled" -}}
{{- $tls := true -}}
{{- if .Values.global -}}
    {{- if .Values.global.security -}}
        {{- if .Values.global.security.tls -}}
            {{- if hasKey .Values.global.security.tls "enabled" -}}
                {{- $tls = .Values.global.security.tls.enabled -}}
            {{- end -}}
        {{- end -}}
    {{- end -}}
{{- end -}}
{{- if eq .Values.service.endpoints.dced.tls.enforced "optional" -}}
  {{- $tls = false -}}
{{- else -}}
  {{- $tls = true -}}
{{- end -}}
{{- $tls -}}
{{- end -}}


{{/*
 InternalIPFamily
*/}}

{{- define "eric-data-distributed-coordinator-ed.internalIPFamily" -}}
{{- $internalIPFamily := "" -}}
{{- if .Values.global -}}
    {{- if .Values.global.internalIPFamily -}}
        {{- $internalIPFamily = .Values.global.internalIPFamily -}}
    {{- end -}}
{{- end -}}
{{- $internalIPFamily -}}
{{- end -}}

{{/*
Client connection scheme
*/}}
{{- define "eric-data-distributed-coordinator-ed.clientConnectionScheme" -}}
{{- if eq ( include "eric-data-distributed-coordinator-ed.tls.enabled" . ) "true" }}
      {{- printf "https" -}}
    {{- else -}}
      {{- printf "http" -}}
  {{- end -}}
{{- end -}}

{{/*

{{/*
 Ports - dced -client
*/}}
{{- define "eric-data-distributed-coordinator-ed.ports.client" -}}
{{- $clientPort := 2379 -}}
{{- print $clientPort -}}
{{- end -}}

Create client url
*/}}
{{- define "eric-data-distributed-coordinator-ed.clientUrl" -}}
   {{ $scheme := include "eric-data-distributed-coordinator-ed.clientConnectionScheme" . }}
   {{- printf "%s://0.0.0.0:%d" $scheme (int64 (include "eric-data-distributed-coordinator-ed.ports.client" . )) -}}
{{- end -}}

{{/*
Advertised client url
*/}}
{{- define "eric-data-distributed-coordinator-ed.advertiseClientUrl" -}}
    {{- $scheme := include "eric-data-distributed-coordinator-ed.clientConnectionScheme" . -}}
    {{- $chartName := include "eric-data-distributed-coordinator-ed.name" . -}}
    {{- printf "%s://$(ETCD_NAME).%s.%s:%d" $scheme $chartName .Release.Namespace (int64 (include "eric-data-distributed-coordinator-ed.ports.client" . )) -}}
{{- end -}}


{{/*
Advertised peer url
*/}}
{{- define "eric-data-distributed-coordinator-ed.initialAdvertisePeerUrl" -}}
  {{ $chartName := include "eric-data-distributed-coordinator-ed.name" . }}
  {{- printf "https://$(ETCD_NAME).%s-peer.%s.svc.%s:%d" $chartName .Release.Namespace .Values.clusterDomain (int64 (include "eric-data-distributed-coordinator-ed.ports.peer" . )) -}}
{{- end -}}


{{/*
client service
*/}}
{{- define "eric-data-distributed-coordinator-ed.clientService" -}}
  {{ $chartName := include "eric-data-distributed-coordinator-ed.name" . }}
  {{- printf "%s.%s:%d" $chartName .Release.Namespace (int64 (include "eric-data-distributed-coordinator-ed.ports.client" . )) -}}
{{- end -}}

{{/*
ETCD endpoint for the agent.
*/}}
{{- define "eric-data-distributed-coordinator-ed.agent.endpoint" -}}
    {{ $chartName := include "eric-data-distributed-coordinator-ed.name" . }}
    {{- printf "%s:%d" $chartName (int64 (include "eric-data-distributed-coordinator-ed.ports.client" . )) -}}
{{- end -}}

{{/*
Parameters that cannot be specified in the settings
*/}}
{{- define "eric-data-distributed-coordinator-ed.forbiddenParameters" -}}
  {{ list "ETCD_INITIAL_CLUSTER_TOKEN" "ETCD_NAME"  }}
{{- end -}}

{{/*
Etcd mountpath
*/}}
{{- define "eric-data-distributed-coordinator-ed.mountPath" -}}
      {{- printf "/data" -}}
{{- end -}}

{{/*
Name of the sip-tls CA certificates
*/}}
{{- define "eric-data-distributed-coordinator-ed.ca.sipTls.name" -}}
  {{- $g := fromJson (include "eric-data-distributed-coordinator-ed.globalMap" .) -}}
  {{ $g.security.tls.trustedInternalRootCa.secret }}
{{- end -}}

{{/*
Path to the TLS trusted CA cert file.
*/}}
{{- define "eric-data-distributed-coordinator-ed.trustedCA" -}}
  {{ printf "/data/combinedca/ca.crt" }}
{{- end -}}

{{/*
Peer TLS Paths.
*/}}
{{- define "eric-data-distributed-coordinator-ed.peerPath" -}}
  {{ printf "/run/secrets/eric-data-distributed-coordinator-ed-peer-cert" }}
{{- end -}}

{{/*
Path to the peer TLS cert file.
*/}}
{{- define "eric-data-distributed-coordinator-ed.peerClientCert" -}}
  {{ printf "/data/certificates/tls-peer.crt" }}
{{- end -}}

{{/*
Path to the peer TLS key file.
*/}}
{{- define "eric-data-distributed-coordinator-ed.peerClientKeyFile" -}}
  {{ printf "/data/certificates/tls-peer.key" }}
{{- end -}}

{{/*
etcdctl parameters
*/}}
{{- define "eric-data-distributed-coordinator-ed.etcdctlParameters" -}}
- name: ETCDCTL_API
  value: "3"
- name: ETCDCTL_ENDPOINTS
  value: {{ template "eric-data-distributed-coordinator-ed.clientService" . }}
{{- if eq (include "eric-data-distributed-coordinator-ed.tls.enabled" .) "true" }}
- name: ETCDCTL_CACERT
  value: {{ template "eric-data-distributed-coordinator-ed.trustedCA" . }}
- name: ETCDCTL_CERT
  value: {{ template "eric-data-distributed-coordinator-ed.certs.clientcert" . }}
- name: ETCDCTL_KEY
  value: {{ template "eric-data-distributed-coordinator-ed.certs.clientkey" . }}
{{- end -}}
{{- end -}}
{{- define "eric-data-distributed-coordinator-ed.serverCert.path" -}}
{{ print "/run/secrets/eric-data-distributed-coordinator-ed-cert/" }}
{{- end}}

{{- define "eric-data-distributed-coordinator-ed.clientCa.path" -}}
{{ print "/run/secrets/eric-data-distributed-coordinator-ed-ca/" }}
{{- end}}

{{- define "eric-data-distributed-coordinator-ed.clientCert.path" -}}
{{ print "/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/" }}
{{- end}}

{{- define "eric-data-distributed-coordinator-ed.siptlsCa.path" -}}
{{- $globals   := fromJson (include "eric-data-distributed-coordinator-ed.globalMap" .) -}}
{{- $siptlsCaName := $globals.security.tls.trustedInternalRootCa.secret -}}
{{- printf "/run/secrets/%s/" $siptlsCaName -}}
{{- end}}

{{- define "eric-data-distributed-coordinator-ed.pmca.path" -}}
{{ print "/run/secrets/eric-pm-server-ca/" }}
{{- end}}

{{/*
secrets mount paths
*/}}
{{- define "eric-data-distributed-coordinator-ed.secretsMountPath" -}}
{{- if eq ( include "eric-data-distributed-coordinator-ed.tls.enabled" . ) "true" }}
- name: server-cert
  mountPath: {{ include "eric-data-distributed-coordinator-ed.serverCert.path" . }}
- name: peer-client-cert
  mountPath: {{ include "eric-data-distributed-coordinator-ed.peerPath" . }}
- name: client-ca
  mountPath: {{ include "eric-data-distributed-coordinator-ed.clientCa.path" . }}
- name: etcdctl-client-cert
  mountPath: {{ include "eric-data-distributed-coordinator-ed.clientCert.path" . }}
{{- if and ( eq (include "eric-data-distributed-coordinator-ed.brAgent.tls" . ) "true" ) (.Values.brAgent.enabled) }}
- name: etcd-bro-client-cert
  mountPath: {{ .Values.service.endpoints.dced.certificates.client.bro }}
{{- end }}
- name: siptls-ca
  mountPath: {{ include "eric-data-distributed-coordinator-ed.siptlsCa.path" . }}
- name: pmca
  mountPath: {{ include "eric-data-distributed-coordinator-ed.pmca.path" . }}
{{- end }}
{{- end -}}

{{/*
secrets volumes
*/}}

{{- define "eric-data-distributed-coordinator-ed.secretsVolumes" -}}
{{- if eq ( include "eric-data-distributed-coordinator-ed.tls.enabled" . ) "true" }}
- name: siptls-ca
  secret:
    optional: true
    secretName: {{ template "eric-data-distributed-coordinator-ed.ca.sipTls.name" . }}
- name: client-ca
  secret:
    optional: true
    secretName: {{ template "eric-data-distributed-coordinator-ed.name" . }}-ca
- name: server-cert
  secret:
    optional: true
    secretName: {{ template "eric-data-distributed-coordinator-ed.name" . }}-cert
- name: peer-client-cert
  secret:
    optional: true
    secretName: {{ template "eric-data-distributed-coordinator-ed.name" . }}-peer-cert
- name: etcdctl-client-cert
  secret:
    optional: true
    secretName: {{ template "eric-data-distributed-coordinator-ed.name" . }}-etcdctl-client-cert
- name: pmca
  secret:
    optional: true
    secretName: {{ template "eric-data-distributed-coordinator-ed.pmCaSecretName" . }}
{{- if and ( eq (include "eric-data-distributed-coordinator-ed.brAgent.tls" . ) "true" ) (.Values.brAgent.enabled) }}
- name: etcd-bro-client-cert
  secret:
    optional: true
    secretName: {{ template "eric-data-distributed-coordinator-ed.name" . }}-etcd-bro-client-cert
{{- end }}
{{- end }}
{{- end -}}


{{/*
Siptls ca cert bundle path.
*/}}
{{- define "eric-data-distributed-coordinator-ed.siptlsca.certbundle" -}}
{{- $globals   := fromJson (include "eric-data-distributed-coordinator-ed.globalMap" .) -}}
{{- $siptlsCaName := $globals.security.tls.trustedInternalRootCa.secret -}}
{{- printf "/run/secrets/%s/ca.crt"  $siptlsCaName -}}
{{- end -}}

{{/*
client cert path.
*/}}
{{- define "eric-data-distributed-coordinator-ed.certs.clientcert" -}}
{{ print "/data/certificates/tls-client.crt" }}
{{- end -}}

{{/*
client private key path
*/}}
{{- define "eric-data-distributed-coordinator-ed.certs.clientkey" -}}
{{ print "/data/certificates/tls-client.key" }}
{{- end -}}

{{/*
Server cert path.
*/}}
{{- define "eric-data-distributed-coordinator-ed.certs.servercert" -}}
{{ print "/data/certificates/tls-srv.crt" }}
{{- end -}}

{{/*
Server private key path
*/}}
{{- define "eric-data-distributed-coordinator-ed.certs.serverkey" -}}
{{ print "/data/certificates/tls-srv.key" }}
{{- end -}}

{{/*
Validate parameters helper
*/}}
{{- define "eric-data-distributed-coordinator-ed.validateParametersHelper" -}}
{{ $forbiddenParameters := list "ETCD_INITIAL_CLUSTER_TOKEN" "ETCD_NAME" "ETCDCTL_API" "ETCD_DATA_DIR" "ETCD_LISTEN_PEER_URLS" "ETCD_LISTEN_CLIENT_URLS" "ETCD_ADVERTISE_CLIENT_URLS" "ETCD_INITIAL_ADVERTISE_PEER_URLS" "ETCD_INITIAL_CLUSTER_STATE" "ETCD_INITIAL_CLUSTER" "ETCD_PEER_AUTO_TLS" "ETCD_CLIENT_CERT_AUTH" "ETCD_CERT_FILE" "ETCD_TRUSTED_CA_FILE" "ETCD_KEY_FILE" }}
{{- $dcedValue := (.Values.env.dced) }}
  {{- range $configName, $configValue := $dcedValue -}}
    {{- if has $configName $forbiddenParameters -}}
      {{- printf "%s " $configName -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Validate parameters
*/}}
{{- define "eric-data-distributed-coordinator-ed.validateParameters" -}}
  {{- $definedInvalidParameters := include "eric-data-distributed-coordinator-ed.validateParametersHelper" . -}}
  {{- $len := len $definedInvalidParameters -}}
  {{- if eq $len 0 -}}
    {{- print " valid" -}}
  {{- end -}}
{{- end -}}

{{/*
Create annotation for the product information (DR-D1121-064)
*/}}
{{- define "eric-data-distributed-coordinator-ed.productinfo" }}
ericsson.com/product-name: {{ (fromYaml (.Files.Get "eric-product-info.yaml")).productName | quote }}
ericsson.com/product-number: {{ (fromYaml (.Files.Get "eric-product-info.yaml")).productNumber | quote }}
ericsson.com/product-revision: {{regexReplaceAll "(.*)[+|-].*" .Chart.Version "${1}" | quote }}
{{- end }}

{{/*
User defined annotations (DR-D1121-065, DR-D1121-060)
*/}}
{{ define "eric-data-distributed-coordinator-ed.config-annotations" }}
  {{- $global := (.Values.global).annotations -}}
  {{- $service := .Values.annotations -}}
  {{- include "eric-data-distributed-coordinator-ed.mergeAnnotations" (dict "location" .Template.Name "sources" (list $global $service)) }}
{{- end }}

{{/*
Annotations
*/}}
{{- define "eric-data-distributed-coordinator-ed.annotations" -}}
  {{- $productInfo := include "eric-data-distributed-coordinator-ed.productinfo" . | fromYaml -}}
  {{- $config := include "eric-data-distributed-coordinator-ed.config-annotations" . | fromYaml -}}
  {{- include "eric-data-distributed-coordinator-ed.mergeAnnotations" (dict "location" .Template.Name "sources" (list $productInfo $config)) | trim }}
{{- end -}}

{{/*
User defined labels (DR-D1121-068, DR-D1121-060)
*/}}
{{ define "eric-data-distributed-coordinator-ed.config-labels" }}
  {{- $global := (.Values.global).labels -}}
  {{- $service := .Values.labels -}}
  {{- include "eric-data-distributed-coordinator-ed.mergeLabels" (dict "location" .Template.Name "sources" (list $global $service)) }}
{{- end }}

{{/*
Labels
*/}}
{{- define "eric-data-distributed-coordinator-ed.labels" -}}
  {{- $selector := include "eric-data-distributed-coordinator-ed.selectorLabels" . | fromYaml -}}
  {{- $servicemesh := dict -}}
  {{- $_ := set $servicemesh "sidecar.istio.io/inject" "false" -}}
  {{- $kubernetes := dict -}}
  {{- $_ := set $kubernetes "app.kubernetes.io/version" (include "eric-data-distributed-coordinator-ed.chart" . | toString) -}}
  {{- $_ := set $kubernetes "app.kubernetes.io/managed-by" (.Release.Service | toString) -}}
  {{- $_ := set $kubernetes "app" (include "eric-data-distributed-coordinator-ed.name" . | toString) -}}
  {{- $config := include "eric-data-distributed-coordinator-ed.config-labels" . | fromYaml -}}
  {{- include "eric-data-distributed-coordinator-ed.mergeLabels" (dict "location" .Template.Name "sources" (list $selector $servicemesh $kubernetes $config)) | trim }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "eric-data-distributed-coordinator-ed.selectorLabels" }}
  app.kubernetes.io/name: {{ include "eric-data-distributed-coordinator-ed.name" . | quote }}
  app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end }}

{{/*
Allow for override of agent name
*/}}
{{- define "eric-data-distributed-coordinator-ed.agentName" -}}
{{ template "eric-data-distributed-coordinator-ed.name" . }}-agent
{{- end -}}

{{/*
Agent Labels.
*/}}
{{- define "eric-data-distributed-coordinator-ed.agent.labels" }}
  {{- $selector := include "eric-data-distributed-coordinator-ed.agent.selectorLabels" . | fromYaml -}}
  {{- $servicemesh := dict -}}
  {{- $_ := set $servicemesh "sidecar.istio.io/inject" "false" -}}
  {{- $kubernetes := dict -}}
  {{- $_ := set $kubernetes "app.kubernetes.io/version" (include "eric-data-distributed-coordinator-ed.chart" . | toString) -}}
  {{- $_ := set $kubernetes "app.kubernetes.io/managed-by" (.Release.Service | toString) -}}
  {{- $config := include "eric-data-distributed-coordinator-ed.config-labels" . | fromYaml -}}
  {{- include "eric-data-distributed-coordinator-ed.mergeLabels" (dict "location" .Template.Name "sources" (list $selector $servicemesh $kubernetes $config)) | trim }}
{{- end }}

{{/*
Accommodate global params for broGrpcServicePort
*/}}

{{- define "eric-data-distributed-coordinator-ed.agent.broGrpcServicePort" -}}
{{- $broGrpcServicePort := "3000" -}}
{{- if .Values.global -}}
    {{- if .Values.global.adpBR -}}
        {{- if .Values.global.adpBR.broGrpcServicePort -}}
            {{- $broGrpcServicePort = .Values.global.adpBR.broGrpcServicePort -}}
        {{- end -}}
    {{- end -}}
{{- end -}}
{{- print $broGrpcServicePort -}}
{{- end -}}

{{/*
Accommodate global params for broServiceName
*/}}
{{- define "eric-data-distributed-coordinator-ed.agent.broServiceName" -}}
{{- $broServiceName := "eric-ctrl-bro" -}}
{{- if .Values.global -}}
    {{- if .Values.global.adpBR -}}
        {{- if .Values.global.adpBR.broServiceName -}}
            {{- $broServiceName = .Values.global.adpBR.broServiceName -}}
        {{- end -}}
    {{- end -}}
{{- end -}}
{{- print $broServiceName -}}
{{- end -}}


{{/*
Accommodate global params for brLabelKey
*/}}
{{/*
Get bro service brLabelKey
*/}}
{{- define "eric-data-distributed-coordinator-ed.agent.brLabelKey" -}}
{{- $brLabelKey := "adpbrlabelkey" -}}
{{- if .Values.global -}}
    {{- if .Values.global.adpBR -}}
        {{- if .Values.global.adpBR.brLabelKey -}}
            {{- $brLabelKey = .Values.global.adpBR.brLabelKey -}}
        {{- end -}}
    {{- end -}}
{{- end -}}
{{- print $brLabelKey -}}
{{- end -}}

{{/*
Selector labels for Agent.
*/}}
{{- define "eric-data-distributed-coordinator-ed.agent.selectorLabels" }}
app.kubernetes.io/name: {{ include "eric-data-distributed-coordinator-ed.agentName" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- if .Values.brAgent.brLabelValue }}
{{ include "eric-data-distributed-coordinator-ed.agent.brLabelKey" . }}: {{ .Values.brAgent.brLabelValue }}
{{ else }}
{{ include "eric-data-distributed-coordinator-ed.agent.brLabelKey" . }}: dc-etcd
{{- end }}
{{- end }}



{{/*
secrets mount paths
*/}}
{{- define "eric-data-distributed-coordinator-ed.agent.secretsMountPath" -}}
{{- if or ( eq ( include "eric-data-distributed-coordinator-ed.brAgent.tls" . ) "true" ) ( eq ( include "eric-data-distributed-coordinator-ed.tls.enabled" . ) "true" ) }}
- name: siptls-ca
  mountPath: {{ include "eric-data-distributed-coordinator-ed.siptlsCa.path" . }}
{{- end -}}
{{- if eq ( include "eric-data-distributed-coordinator-ed.brAgent.tls" . ) "true" }}
- name: etcd-bro-client-cert
  mountPath: {{ .Values.service.endpoints.dced.certificates.client.bro }}
{{- end -}}
{{- if eq ( include "eric-data-distributed-coordinator-ed.tls.enabled" . ) "true" }}
- name: etcdctl-client-cert
  mountPath: {{ include "eric-data-distributed-coordinator-ed.clientCert.path" . }}
- name: client-ca
  mountPath: {{ include "eric-data-distributed-coordinator-ed.clientCa.path" . }}
{{- end }}
{{- end -}}


{{/*
secrets volumes
*/}}
{{- define "eric-data-distributed-coordinator-ed.agent.secretsVolumes" -}}
{{- if or ( eq ( include "eric-data-distributed-coordinator-ed.brAgent.tls" . ) "true" ) ( eq ( include "eric-data-distributed-coordinator-ed.tls.enabled" . ) "true" ) }}
- name: siptls-ca
  secret:
    optional: true
    secretName: {{ (((((.Values).global).security).tls).trustedInternalRootCa).secret | default "eric-sec-sip-tls-trusted-root-cert" | quote }}
{{- end -}}
{{- if eq ( include "eric-data-distributed-coordinator-ed.brAgent.tls" . ) "true" }}
- name: etcd-bro-client-cert
  secret:
    optional: true
    secretName: {{ template "eric-data-distributed-coordinator-ed.name" . }}-etcd-bro-client-cert
{{- end -}}
{{- if eq ( include "eric-data-distributed-coordinator-ed.tls.enabled" . ) "true" }}
- name: etcdctl-client-cert
  secret:
    optional: true
    secretName: {{ template "eric-data-distributed-coordinator-ed.name" . }}-etcdctl-client-cert
- name: client-ca
  secret:
    optional: true
    secretName: {{ template "eric-data-distributed-coordinator-ed.name" . }}-ca
{{- end -}}
{{- end -}}

{{/*
Semi-colon separated list of backup types
*/}}
{{- define "eric-data-distributed-coordinator-ed.agent.backupTypes" }}
{{- .Values.brAgent.backupTypeList | join ";" -}}
{{- end -}}


{{/*
Additional SAN in cert to support hostname verification
*/}}
{{- define "eric-data-distributed-coordinator-ed.dns" -}}
{{- $dnslist := list (include "eric-data-distributed-coordinator-ed.dnsname-peer" .) (include "eric-data-distributed-coordinator-ed.dnsname" .) (include "eric-data-distributed-coordinator-ed.dnsname-localhost" .) (include "eric-data-distributed-coordinator-ed.pmdnsname" .)  -}}
{{- $dnslist | toJson -}}
{{- end}}


{{/*
Wildcard name to match all ETCD instances.
*/}}
{{- define "eric-data-distributed-coordinator-ed.dnsname-peer" -}}
*.{{- include "eric-data-distributed-coordinator-ed.name" . }}-peer.{{ .Release.Namespace }}.svc.{{ .Values.clusterDomain }}
{{- end}}


{{/*
DNS name localhost
*/}}
{{- define "eric-data-distributed-coordinator-ed.dnsname-localhost" -}}
{{ print "localhost" }}
{{- end}}

{{/*
Wildcard name to match non-peer instances
*/}}
{{- define "eric-data-distributed-coordinator-ed.dnsname" -}}
*.{{- include "eric-data-distributed-coordinator-ed.name" . }}.{{ .Release.Namespace }}.svc.{{ .Values.clusterDomain }}
{{- end}}

{{/*
Wildcard name to match non-peer instances
*/}}
{{- define "eric-data-distributed-coordinator-ed.pmdnsname" -}}
{{ print "certified-scrape-target" }}
{{- end}}

{{/*
AccessMode - For PVC set ReadWriteOnce
*/}}
{{- define "eric-data-distributed-coordinator-ed.persistentVolumeClaim.accessMode" -}}
{{ print "ReadWriteOnce" }}
{{- end}}

{{/*
Volume mount name used for Statefulset
*/}}
{{- define "eric-data-distributed-coordinator-ed.persistence.volumeMount.name" -}}
  {{- printf "%s" "data" -}}
{{- end -}}

{{/*
Create a merged set of nodeSelectors from global and service level -dced.
*/}}
{{- define "eric-data-distributed-coordinator-ed.dcedNodeSelector" -}}
{{- $globalValue := (dict) -}}
{{- if .Values.global -}}
    {{- if .Values.global.nodeSelector -}}
         {{- $globalValue = .Values.global.nodeSelector -}}
    {{- end -}}
{{- end -}}
{{- if .Values.nodeSelector.dced -}}
  {{- range $key, $localValue := .Values.nodeSelector.dced -}}
    {{- if hasKey $globalValue $key -}}
         {{- $Value := index $globalValue $key -}}
         {{- if ne $Value $localValue -}}
           {{- printf "nodeSelector \"%s\" is specified in both global (%s: %s) and service level (%s: %s) with differing values which is not allowed." $key $key $globalValue $key $localValue | fail -}}
         {{- end -}}
     {{- end -}}
    {{- end -}}
    nodeSelector: {{- toYaml (merge $globalValue .Values.nodeSelector.dced) | trim | nindent 2 -}}
{{- else -}}
  {{- if not ( empty $globalValue ) -}}
    nodeSelector: {{- toYaml $globalValue | trim | nindent 2 -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a merged set of nodeSelectors from global and service level - brAgent.
*/}}
{{- define "eric-data-distributed-coordinator-ed.brAgentNodeSelector" -}}
{{- $globalValue := (dict) -}}
{{- if .Values.global -}}
    {{- if .Values.global.nodeSelector -}}
         {{- $globalValue = .Values.global.nodeSelector -}}
    {{- end -}}
{{- end -}}
{{- if .Values.nodeSelector.brAgent -}}
  {{- range $key, $localValue := .Values.nodeSelector.brAgent -}}
    {{- if hasKey $globalValue $key -}}
         {{- $Value := index $globalValue $key -}}
         {{- if ne $Value $localValue -}}
           {{- printf "nodeSelector \"%s\" is specified in both global (%s: %s) and service level (%s: %s) with differing values which is not allowed." $key $key $globalValue $key $localValue | fail -}}
         {{- end -}}
     {{- end -}}
    {{- end -}}
    nodeSelector: {{- toYaml (merge $globalValue .Values.nodeSelector.brAgent) | trim | nindent 2 -}}
{{- else -}}
  {{- if not ( empty $globalValue ) -}}
    nodeSelector: {{- toYaml $globalValue | trim | nindent 2 -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Define supplementalGroups according to DR-D1123-135.
*/}}
{{- define "eric-data-distributed-coordinator-ed.supplementalGroups" -}}
    {{- $globalGroups := (list) -}}
    {{- if ( (((.Values).global).podSecurityContext).supplementalGroups) }}
      {{- $globalGroups = .Values.global.podSecurityContext.supplementalGroups -}}
    {{- end -}}
    {{- $localGroups := (list) -}}
    {{- if ( ((.Values).podSecurityContext).supplementalGroups) -}}
      {{- $localGroups = .Values.podSecurityContext.supplementalGroups -}}
    {{- end -}}
    {{- $mergedGroups := (list) -}}
    {{- if $globalGroups -}}
        {{- $mergedGroups = $globalGroups -}}
    {{- end -}}
    {{- if $localGroups -}}
        {{- $mergedGroups = concat $globalGroups $localGroups | uniq -}}
    {{- end -}}
    {{- if $mergedGroups -}}
        {{- toYaml $mergedGroups | nindent 8 -}}
    {{- end -}}
    {{- /* Do nothing if both global and local groups are not set */ -}}
{{- end -}}

{{/*
 CA Secret provided by PM Server
*/}}
{{- define "eric-data-distributed-coordinator-ed.pmCaSecretName" -}}
    {{- if .Values.service.endpoints.pm.tls.caSecretName -}}
        {{- .Values.service.endpoints.pm.tls.caSecretName -}}
    {{- else -}}
        {{- .Values.pmServer.pmServiceName -}}-ca
    {{- end -}}
{{- end -}}

{{/*
dced livenessProbeConfig
*/}}
{{- define "eric-data-distributed-coordinator-ed.livenessProbeConfig" }}
{{- $image := get .Values.probes .imageName -}}
{{- $initialDelay := $image.livenessProbe.initialDelaySeconds -}}
{{- $timeoutSec := $image.livenessProbe.timeoutSeconds -}}
{{- $periodSec := $image.livenessProbe.periodSeconds -}}
{{- $failThreshold := $image.livenessProbe.failureThreshold }}
{{ printf "initialDelaySeconds: %v"  $initialDelay }}
{{ printf "timeoutSeconds: %v"  $timeoutSec }}
{{ printf "periodSeconds: %v"  $periodSec }}
{{ printf "failureThreshold: %v"  $failThreshold }}
{{- end }}

{{/*
dced readinessProbeConfig
*/}}
{{- define "eric-data-distributed-coordinator-ed.readinessProbeConfig" }}
{{- $image := get .Values.probes .imageName -}}
{{- $initialDelay := $image.readinessProbe.initialDelaySeconds -}}
{{- $timeoutSec := $image.readinessProbe.timeoutSeconds -}}
{{- $periodSec := $image.readinessProbe.periodSeconds -}}
{{- $failThreshold := $image.readinessProbe.failureThreshold -}}
{{- $successfulThreshold := $image.readinessProbe.successThreshold }}
{{ printf "initialDelaySeconds: %v"  $initialDelay }}
{{ printf "timeoutSeconds: %v"  $timeoutSec }}
{{ printf "periodSeconds: %v"  $periodSec }}
{{ printf "failureThreshold: %v"  $failThreshold }}
{{ printf "successThreshold: %v"  $successfulThreshold }}
{{- end }}

{{/*
 Replicas
*/}}

{{- define "eric-data-distributed-coordinator-ed.pods.replicas" -}}
{{- $replicas := "" -}}
  {{ if .Values.pods.dced.replicas }}
    {{- $replicas = .Values.pods.dced.replicas -}}
  {{- else -}}
    {{- $replicas = .Values.pods.dced.replicaCount -}}
  {{- end -}}
{{- print $replicas -}}
{{- end -}}

{{/*
 Probes - Defination StatefulSet
*/}}
{{- define "eric-data-distributed-coordinator-ed.probes.statefulSet.dced" -}}
{{- $dcedValue := (.Values.probes.dced) }}
{{- $MinorVersion := int (.Capabilities.KubeVersion.Minor) -}}
{{/*
StartupProbe feature is stable from k8 v.1.20.x onwards, in case deployed in a cluster for that version and above,
readiness Probe's & liveness Probe's InitialDelaySeconds: 0
with a failureThreshold * periodSeconds long enough to cover the worse case startup time. ( Default 6x20 60 2 minutes )
*/}}

{{- $livenessInitialDelaySeconds := .Values.probes.dced.livenessProbe.initialDelaySeconds -}}
{{- $readinessInitialDelaySeconds := .Values.probes.dced.readinessProbe.initialDelaySeconds -}}

{{- if ge $MinorVersion 20 -}}
{{- $livenessInitialDelaySeconds := 0 -}}
{{- $readinessInitialDelaySeconds := 0 -}}
{{ end }}
          livenessProbe:
            httpGet:
              path: /health/liveness
              port: 9000
            initialDelaySeconds: {{ $livenessInitialDelaySeconds }}
            timeoutSeconds: {{ .Values.probes.dced.livenessProbe.timeoutSeconds }}
            failureThreshold: {{ .Values.probes.dced.livenessProbe.failureThreshold }}
            periodSeconds: {{ .Values.probes.dced.livenessProbe.periodSeconds }}
{{ if ge $MinorVersion 20 }}
          startupProbe:
            httpGet:
              path: /health/startup
              port: 9000
            initialDelaySeconds: {{ .Values.probes.dced.startupProbe.initialDelaySeconds }}
            timeoutSeconds: {{ .Values.probes.dced.startupProbe.timeoutSeconds }}
            periodSeconds: {{ .Values.probes.dced.startupProbe.periodSeconds }}
            failureThreshold: {{ .Values.probes.dced.startupProbe.failureThreshold }}
{{ end }}
          readinessProbe:
            httpGet:
              path: /health/readiness
              port: 9000
            initialDelaySeconds: {{ $readinessInitialDelaySeconds }}
            timeoutSeconds: {{ .Values.probes.dced.readinessProbe.timeoutSeconds }}
            failureThreshold: {{ .Values.probes.dced.readinessProbe.failureThreshold }}
            periodSeconds: {{ .Values.probes.dced.readinessProbe.periodSeconds }}
            successThreshold: {{ .Values.probes.dced.readinessProbe.successThreshold }}
{{- end -}}

{{/*
 livenessProbe EntrypointChecksNumber
*/}}
{{- define "eric-data-distributed-coordinator-ed.livenessProbe.entrypointChecksNumber" -}}
{{- print .Values.probes.dced.livenessProbe.EntrypointChecksNumber -}}
{{- end -}}

{{/*
 livenessProbe EntrypointRestartEtcd
*/}}
{{- define "eric-data-distributed-coordinator-ed.livenessProbe.entrypointRestartEtcd" -}}
{{- print .Values.probes.dced.livenessProbe.EntrypointRestartEtcd -}}
{{- end -}}

{{/*
 livenessProbe entrypointPipeTimeout
*/}}
{{- define "eric-data-distributed-coordinator-ed.livenessProbe.entrypointPipeTimeout" -}}
{{- print .Values.probes.dced.livenessProbe.EntrypointPipeTimeout -}}
{{- end -}}

{{/*
 livenessProbe EntrypointDcedProcessInterval
*/}}
{{- define "eric-data-distributed-coordinator-ed.livenessProbe.entrypointDcedProcessInterval" -}}
{{- print .Values.probes.dced.livenessProbe.EntrypointEctdProcessInterval -}}
{{- end -}}

{{/*
Env parameters
*/}}
{{- define "eric-data-distributed-coordinator-ed.env.dced" -}}
{{- $dcedValue := (.Values.env.dced) }}
{{ range $configName, $configValue := $dcedValue }}
            - name: {{ $configName }}
              value: {{ $configValue | quote }}
{{- end }}
{{- end -}}

{{/*
 Security TLS - client enabled check
*/}}

{{- define "eric-data-distributed-coordinator-ed.tls.clientEnabled" -}}
{{- print .Values.service.endpoints.dced.certificates.client.clientCertAuth -}}
{{- end -}}

{{/*
 Security TLS - Peer autoTls enabled check
*/}}
{{- define "eric-data-distributed-coordinator-ed.tls.peerAutoTls.enabled" -}}
{{- print .Values.service.endpoints.dced.certificates.peer.autoTls -}}
{{- end -}}

{{/*
 Security TLS - Peer autoTls enabled check
*/}}
{{- define "eric-data-distributed-coordinator-ed.tls.peerCertAuth.enabled" -}}
{{- print .Values.service.endpoints.dced.certificates.peer.peerCertAuth -}}
{{- end -}}

{{/*
 Security TLS -root acls
*/}}

{{- define "eric-data-distributed-coordinator-ed.tls.acls" -}}
{{- $dcedValue := (.Values.service.endpoints.dced) }}
    secretKeyRef:
      name: {{ $dcedValue.acls.adminSecret | quote }}
      key: {{ $dcedValue.acls.rootPassword | quote }}
{{- end -}}

{{/*
Define the apparmor annotation creation based on input profile and container name
*/}}
{{- define "eric-data-distributed-coordinator-ed.getApparmorAnnotation" -}}
{{- $profile := index . "profile" -}}
{{- $containerName := index . "ContainerName" -}}
{{- if $profile.type -}}
{{- if eq "runtime/default" (lower $profile.type) }}
container.apparmor.security.beta.kubernetes.io/{{ $containerName }}: "runtime/default"
{{- else if eq "unconfined" (lower $profile.type) }}
container.apparmor.security.beta.kubernetes.io/{{ $containerName }}: "unconfined"
{{- else if eq "localhost" (lower $profile.type) }}
{{- if $profile.localhostProfile }}
{{- $localhostProfileList := (splitList "/" $profile.localhostProfile) -}}
{{- if (last $localhostProfileList) }}
container.apparmor.security.beta.kubernetes.io/{{ $containerName }}: "localhost/{{ (last $localhostProfileList ) }}"
{{- end }}
{{- end }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Define Logshipper storage path
*/}}
{{- define "eric-data-distributed-coordinator-ed.logshipper.storage.path" -}}
  {{- if eq (default "" ((((.Values).global).logShipper).deployment).model) "static" -}}
  {{- include "eric-data-distributed-coordinator-ed.log-shipper-sidecar-storage-path" . -}}
  {{- else -}}
  {{- .Values.logShipper.storage.path -}}
  {{- end }}
{{- end -}}

{{/*
Define the apparmor annotation for dced container
*/}}
{{- define "eric-data-distributed-coordinator-ed.dced.appArmorAnnotations" -}}
{{- if .Values.appArmorProfile -}}
{{- $profile := .Values.appArmorProfile -}}
{{- if index .Values.appArmorProfile "dced" -}}
{{- if (index .Values.appArmorProfile "dced").type -}}
{{- $profile = index .Values.appArmorProfile "dced" }}
{{- end -}}
{{- end -}}
{{- include "eric-data-distributed-coordinator-ed.getApparmorAnnotation" (dict "profile" $profile "ContainerName" "dced") }}
{{- end -}}
{{- end -}}

{{/*
Define the apparmor annotation for init container
*/}}
{{- define "eric-data-distributed-coordinator-ed.init.appArmorAnnotations" -}}
{{- if .Values.appArmorProfile -}}
{{- $profile := .Values.appArmorProfile -}}
{{- if index .Values.appArmorProfile "init" -}}
{{- if (index .Values.appArmorProfile "init").type -}}
{{- $profile = index .Values.appArmorProfile "init" }}
{{- end -}}
{{- end -}}
{{- include "eric-data-distributed-coordinator-ed.getApparmorAnnotation" (dict "profile" $profile "ContainerName" "init") }}
{{- end -}}
{{- end -}}

{{/*
Define the apparmor annotation for metricsexporter container
*/}}
{{- define "eric-data-distributed-coordinator-ed.metricsexporter.appArmorAnnotations" -}}
{{- if .Values.appArmorProfile -}}
{{- $profile := .Values.appArmorProfile -}}
{{- if index .Values.appArmorProfile "metricsexporter" -}}
{{- if (index .Values.appArmorProfile "metricsexporter").type -}}
{{- $profile = index .Values.appArmorProfile "metricsexporter" }}
{{- end -}}
{{- end -}}
{{- include "eric-data-distributed-coordinator-ed.getApparmorAnnotation" (dict "profile" $profile "ContainerName" "metricsexporter") }}
{{- end -}}
{{- end -}}

{{/*
Define the apparmor annotation for logshipper container
*/}}
{{- define "eric-data-distributed-coordinator-ed.logshipper.appArmorAnnotations" -}}
{{- if .Values.appArmorProfile -}}
{{- $profile := .Values.appArmorProfile -}}
{{- if index .Values.appArmorProfile "logshipper" -}}
{{- if (index .Values.appArmorProfile "logshipper").type -}}
{{- $profile = index .Values.appArmorProfile "logshipper" }}
{{- end -}}
{{- end -}}
{{- include "eric-data-distributed-coordinator-ed.getApparmorAnnotation" (dict "profile" $profile "ContainerName" "logshipper") }}
{{- end -}}
{{- end -}}

{{/*
Define the apparmor annotation for brAgent container
*/}}
{{- define "eric-data-distributed-coordinator-ed.brAgent.appArmorAnnotations" -}}
{{- if .Values.appArmorProfile -}}
{{- $profile := .Values.appArmorProfile -}}
{{- if index .Values.appArmorProfile "brAgent" -}}
{{- if (index .Values.appArmorProfile "brAgent").type -}}
{{- $profile = index .Values.appArmorProfile "brAgent" }}
{{- end -}}
{{- end -}}
{{- $bragentcontainer := (printf "%s%s" .Chart.Name "-agent") }}
{{- include "eric-data-distributed-coordinator-ed.getApparmorAnnotation" (dict "profile" $profile "ContainerName" $bragentcontainer) }}
{{- end -}}
{{- end -}}


{{/*
Define the seccomp security context creation based on input profile (no container name needed since it is already in the containers security profile)
*/}}
{{- define "eric-data-distributed-coordinator-ed.getSeccompSecurityContext" -}}
{{- $profile := index . "profile" -}}
{{- if $profile.type -}}
{{- if eq "runtimedefault" (lower $profile.type) }}
seccompProfile:
  type: RuntimeDefault
{{- else if eq "unconfined" (lower $profile.type) }}
seccompProfile:
  type: Unconfined
{{- else if eq "localhost" (lower $profile.type) }}
seccompProfile:
  type: Localhost
  localhostProfile: {{ $profile.localhostProfile }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Define the seccomp security context for dced container
*/}}
{{- define "eric-data-distributed-coordinator-ed.dced.seccompProfile" -}}
{{- if .Values.seccompProfile }}
{{- $profile := .Values.seccompProfile }}
{{- if index .Values.seccompProfile "dced" }}
{{- if (index .Values.seccompProfile "dced").type -}}
{{- $profile = index .Values.seccompProfile "dced" }}
{{- end }}
{{- end }}
{{- include "eric-data-distributed-coordinator-ed.getSeccompSecurityContext" (dict "profile" $profile) }}
{{- end -}}
{{- end -}}

{{/*
Define the seccomp security context for metricsexporter container
*/}}
{{- define "eric-data-distributed-coordinator-ed.metricsexporter.seccompProfile" -}}
{{- if .Values.seccompProfile }}
{{- $profile := .Values.seccompProfile }}
{{- if index .Values.seccompProfile "metricsexporter" }}
{{- if (index .Values.seccompProfile "metricsexporter").type -}}
{{- $profile = index .Values.seccompProfile "metricsexporter" }}
{{- end -}}
{{- end }}
{{- include "eric-data-distributed-coordinator-ed.getSeccompSecurityContext" (dict "profile" $profile) }}
{{- end -}}
{{- end -}}

{{/*
Define the seccomp security context for logshipper container
*/}}
{{- define "eric-data-distributed-coordinator-ed.logshipper.seccompProfile" -}}
{{- if .Values.seccompProfile }}
{{- $profile := .Values.seccompProfile }}
{{- if index .Values.seccompProfile "logshipper" }}
{{- if (index .Values.seccompProfile "logshipper").type -}}
{{- $profile = index .Values.seccompProfile "logshipper" }}
{{- end }}
{{- end }}
{{- include "eric-data-distributed-coordinator-ed.getSeccompSecurityContext" (dict "profile" $profile) }}
{{- end -}}
{{- end -}}

{{/*
Define the seccomp security context for init container
*/}}
{{- define "eric-data-distributed-coordinator-ed.init.seccompProfile" -}}
{{- if .Values.seccompProfile }}
{{- $profile := .Values.seccompProfile }}
{{- if index .Values.seccompProfile "init" }}
{{- if (index .Values.seccompProfile "init").type -}}
{{- $profile = index .Values.seccompProfile "init" }}
{{- end }}
{{- end }}
{{- include "eric-data-distributed-coordinator-ed.getSeccompSecurityContext" (dict "profile" $profile) }}
{{- end -}}
{{- end -}}

{{/*
Define the seccomp security context for brAgent container
*/}}
{{- define "eric-data-distributed-coordinator-ed.brAgent.seccompProfile" -}}
{{- if .Values.seccompProfile }}
{{- $profile := .Values.seccompProfile }}
{{- if index .Values.seccompProfile "brAgent" }}
{{- if (index .Values.seccompProfile "brAgent").type -}}
{{- $profile = index .Values.seccompProfile "brAgent" }}
{{- end }}
{{- end }}
{{- include "eric-data-distributed-coordinator-ed.getSeccompSecurityContext" (dict "profile" $profile) }}
{{- end -}}
{{- end -}}

{{/*
Define Network Policy, note: returns boolean as string
*/}}
{{- define "eric-data-distributed-coordinator-ed.networkPolicy" -}}
{{- $networkPolicy := false -}}
{{- if .Values.global -}}
    {{- if and .Values.global.networkPolicy .Values.networkPolicy -}}
      {{- if and .Values.global.networkPolicy.enabled .Values.networkPolicy.enabled -}}
        {{- $networkPolicy = .Values.global.networkPolicy.enabled -}}
      {{- end -}}
    {{- end -}}
{{- end -}}
{{- $networkPolicy -}}
{{- end -}}

{{/*
Get PM service name
*/}}
{{- define "eric-data-distributed-coordinator-ed.pmServer.name" -}}
{{- $PmServiceName := "eric-pm-server" -}}
        {{- if .Values.pmServer.pmServiceName -}}
            {{- $PmServiceName = .Values.pmServer.pmServiceName -}}
        {{- end -}}
{{- print $PmServiceName -}}
{{- end -}}
{{/*
Traffic shaping bandwidth limit annotation (DR-D1125-040-AD)
*/}}
{{ define "eric-data-distributed-coordinator-ed.bandwidth-annotations" }}
{{- if .Values.bandwidth.maxEgressRate }}
kubernetes.io/egress-bandwidth: {{ .Values.bandwidth.maxEgressRate }}
{{- end }}
{{- end }}


{{/*
Define DCED podPriority
*/}}
{{- define "eric-data-distributed-coordinator-ed.podPriority" }}
{{- if .Values.podPriority }}
  {{- if index .Values.podPriority "eric-data-distributed-coordinator-ed" -}}
    {{- if (index .Values.podPriority "eric-data-distributed-coordinator-ed" "priorityClassName") }}
      priorityClassName: {{ index .Values.podPriority "eric-data-distributed-coordinator-ed" "priorityClassName" | quote }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Define DCED-Agent podPriority
*/}}
{{- define "eric-data-distributed-coordinator-ed-agent.podPriority" }}
{{- if .Values.podPriority }}
  {{- if index .Values.podPriority "eric-data-distributed-coordinator-ed-agent" -}}
    {{- if (index .Values.podPriority "eric-data-distributed-coordinator-ed-agent" "priorityClassName") }}
      priorityClassName: {{ index .Values.podPriority "eric-data-distributed-coordinator-ed-agent" "priorityClassName" | quote }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
{{/*
DR-D1126-010 JVM heap size for brAgent
*/}}
{{- define "eric-data-distributed-coordinator-ed.brAgent.JVMHeapSize" -}}
    {{- $maxRAM := "" -}}
    {{- $minRAM := "" -}}
    {{- $initRAM := "" -}}
    {{- if not .Values.resources.brAgent.limits.memory -}}
    {{- fail "memory limit for brAgent is not specified" -}}
    {{- end -}}
    {{- if .Values.resources.brAgent.jvm -}}
        {{- if .Values.resources.brAgent.jvm.initialMemoryAllocationPercentage -}}
            {{- $initRAM = .Values.resources.brAgent.jvm.initialMemoryAllocationPercentage | float64 -}}
            {{- $initRAM = printf "-XX:InitialRAMPercentage=%f" $initRAM -}}
        {{- end -}}
        {{- if .Values.resources.brAgent.jvm.smallMemoryAllocationMaxPercentage -}}
            {{- $minRAM = .Values.resources.brAgent.jvm.smallMemoryAllocationMaxPercentage | float64 -}}
            {{- $minRAM = printf "-XX:MinRAMPercentage=%f" $minRAM -}}
        {{- end -}}
        {{- if .Values.resources.brAgent.jvm.largeMemoryAllocationMaxPercentage -}}
            {{- $maxRAM = .Values.resources.brAgent.jvm.largeMemoryAllocationMaxPercentage | float64 -}}
            {{- $maxRAM = printf "-XX:MaxRAMPercentage=%f" $maxRAM -}}
        {{- end -}}
    {{- end -}}
{{- printf "%s %s %s" $initRAM $minRAM $maxRAM -}}
{{- end -}}

{{/*
Streaming method selection logic.
Precedence order:
  log.streamingMethod > global.log.streamingMethod > "indirect"
In other words, the log.streamingMethod parameter has higher importance.
Local overrides global, and if nothing set then indirect is chosen.
*/}}
{{ define "eric-data-distributed-coordinator-ed.log-streamingMethod" }}
  {{- $streamingMethod := "indirect" -}}
    {{- if (((.Values.global).log).streamingMethod) -}}
    {{- $streamingMethod = .Values.global.log.streamingMethod -}}
  {{- end -}}
  {{- if ((.Values.log).streamingMethod) -}}
    {{- $streamingMethod = .Values.log.streamingMethod -}}
  {{- end -}}
  {{- printf "%s" $streamingMethod -}}
{{ end }}

{{- define "eric-data-distributed-coordinator-ed.logshipper-enabled" -}}
  {{- $streamingMethod := (include "eric-data-distributed-coordinator-ed.log-streamingMethod" .) -}}
  {{- if or (eq $streamingMethod "dual") (eq $streamingMethod "direct") -}}
    {{- printf "%t" true -}}
  {{- else -}}
    {{- printf "%t" false -}}
  {{- end -}}
{{- end -}}

{{/*
Get DCED-brAgent Replicas Count
*/}}
{{- define "eric-data-distributed-coordinator-ed.brAgent.replicas" -}}
{{- $replicas := "" -}}
  {{- if .Values.brAgent.replicas -}}
    {{- $replicas = .Values.brAgent.replicas -}}
  {{- else -}}
    {{- $replicas = .Values.brAgent.replicaCount -}}
  {{- end -}}
{{- $replicas -}}
{{- end -}}
\
{{/*
Create the security policy rolebinding name according to DR-D1123-134.
*/}}
{{- define "eric-data-distributed-coordinator-ed.security-policy-rolebinding.name" -}}
    {{- printf "%s-%s-%s-sp" (include "eric-data-distributed-coordinator-ed.service-account.name" .) (ternary "c" "r" (eq (.Values.global.securityPolicy.rolekind) "ClusterRole") ) ( .Values.securityPolicy.dced.rolename ) -}}
{{- end -}}

{{- define "eric-data-distributed-coordinator-ed.service-account.name" -}}
    {{- printf "%s-service-account" (include "eric-data-distributed-coordinator-ed.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
To pass the Command line arguments in the startup of bragent java application
*/}}

{{- define "eric-data-distributed-coordinator-ed.brAgent.cmdLineArgs" -}}
{{- $cmdLineArgs := "-Dvertx.disableFileCaching=true -Dvertx.disableFileCPResolving=true" -}}
{{- print $cmdLineArgs -}}
{{- end -}}
