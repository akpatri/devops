<!--
This is the reading guide for the commented learning chart in this directory.
Commands below are written for PowerShell, but Helm commands are the same on
Linux and macOS. Rendering and linting do not require a Kubernetes cluster.
-->

# Helm Chart Learning Lab

This folder is a complete, intentionally small Helm chart. It deploys a public
unprivileged NGINX image, and includes a local child chart so you can see how a
parent chart, child values, dependency switches, and imported exports work.

## 1. Chart directory map

```text
helm-chart/                    # Root directory containing this learning chart.
|-- Chart.yaml                 # Chart identity, version, Kubernetes range, dependency
|-- values.yaml                # User-configurable defaults for the parent chart
|-- templates/                 # Go templates that produce Kubernetes YAML
|   |-- _helpers.tpl           # Named template helpers; underscore files are not resources
|   |-- deployment.yaml        # Workload and Pod specification
|   |-- service.yaml           # Stable network endpoint for the Pods
|   |-- configmap.yaml         # Non-secret configuration data
|   |-- secret.yaml            # Deliberately fake credentials for demonstration
|   |-- serviceaccount.yaml    # Identity assigned to the Pod
|   |-- ingress.yaml           # Optional HTTP routing (off by default)
|   |-- hpa.yaml               # Optional autoscaling (off by default)
|   |-- pvc.yaml               # Optional persistent storage (off by default)
|   |-- extra-objects.yaml     # Example of accepting extra Kubernetes objects
|   `-- NOTES.txt              # Printed after install; template output is plain text
|-- charts/demo-subchart/      # A local dependency chart, not another release
|-- crds/                      # Place raw CustomResourceDefinition YAML files here
`-- tutorial.md                # This guide
```

`Chart.yaml` (capital C) is the required filename. A chart version describes
changes to the chart package; `appVersion` describes the application image. The
two versions are independent. Helm uses `version` when packaging and resolving
dependencies. `apiVersion: v2` is the modern chart metadata format.

## 2. Render before installing

From this directory:

```powershell
helm lint . # Check chart metadata, values, dependencies, and common template mistakes.
helm template demo . --namespace learning # Render resources locally without contacting Kubernetes.
helm template demo . --namespace learning --debug # Include debug details when a render fails.
```

`helm lint` checks chart structure and common mistakes. `helm template` renders
templates locally; it does not contact a cluster or download the image. The
first command is the fastest feedback loop while editing templates.

The output is a stream of Kubernetes YAML documents separated by `---`. Check
that the Deployment selector matches the Pod labels, the Service selector uses
the same labels, and its named `targetPort` matches the container port name.
These are Kubernetes relationships that Helm cannot infer for you.

Use Helm's inspection commands to explore the defaults and template output:

```powershell
helm show chart . # Print chart metadata from Chart.yaml.
helm show values . # Print default values available for overrides.
helm template demo . --show-only templates/deployment.yaml # Render only the parent Deployment.
helm template demo . --show-only charts/demo-subchart/templates/configmap.yaml # Render only the child ConfigMap.
```

## 3. Values and overrides

`values.yaml` is the default input map. A template reads a key with
`.Values.someKey`; a user can override the same key without editing the chart.
Try a few overrides:

```powershell
helm template demo . --set replicaCount=1 # Override a number for this render only.
helm template demo . --set image.tag=1.27.5-alpine --set service.port=8081 # Override nested image and Service values.
helm template demo . --set ingress.enabled=true # Turn on the optional Ingress template.
helm template demo . --set demoSubchart.message="changed from the parent" # Override a value passed to the subchart.
```

For repeatable environment settings, put overrides in a separate YAML file and
pass `-f my-values.yaml`. Common precedence, from lower to higher, is chart
defaults, each `-f` file from left to right, then each `--set` argument from
left to right. `--set-string` forces a value to remain a string; `--set-file`
loads a file's contents into a value.

Do not put production passwords in values files. Values are stored in Helm
release history, and a rendered Kubernetes Secret is not automatically a
secure secret-management system. The credentials in this chart are fake and
exist only to show the `Secret` template shape.

The `global` values map is special: Helm makes it available to child charts as
`.Values.global`. Other parent values are not automatically visible to a child.
For example, the child receives its own `message` as
`.Values.demoSubchart.message` in the parent configuration and `.Values.message`
inside the child template.

## 4. Templates and template data

Helm templates use Go's `text/template` language plus the Sprig function set.
Important built-in objects include:

| Object | What it contains |
| --- | --- |
| `.Values` | Merged chart defaults and user overrides |
| `.Release` | Release name, namespace, revision, and install/upgrade state |
| `.Chart` | Metadata from the current chart's `Chart.yaml` |
| `.Capabilities` | Kubernetes and API versions available to the renderer |
| `$` | The root scope captured before entering `with` or `range` |

Useful template patterns in this chart:

```gotemplate
{{ .Values.replicaCount }}                 {{/* Read a configurable value from the merged values map. */}}
{{ include "learning-web.fullname" . }}   {{/* Call a named helper with the current template scope. */}}
{{- with .Values.ingress.annotations }}    {{/* Enter only when the optional map is non-empty. */}}
annotations: # Emit this mapping key only when ingress annotations exist.
	{{ toYaml . | nindent 2 }}{{/* Serialize the map at the correct YAML indentation. */}}
{{- end }}{{/* Close the with block and restore the prior scope. */}}
```

`if` conditionally emits YAML; `with` changes `.` to a non-empty value; `range`
iterates a map or list. Inside a `range`, `$` still refers to the original root
context. `include` returns helper output so it can be piped to `nindent`; the
built-in `template` action cannot be piped. `default`, `required`, `fail`,
`quote`, `toYaml`, `nindent`, `dict`, and `lookup` are other useful functions.

Whitespace trim markers matter. `{{-` removes whitespace to the left, and `-}}`
removes whitespace to the right. Over-trimming can join YAML keys together;
inspect rendered output whenever changing indentation or control flow. Use
`helm template --debug` to see render errors and source locations.

`_helpers.tpl` is not emitted as a Kubernetes object because its filename
starts with `_`. Its `define` blocks are named templates shared by this chart's
templates. The child chart has a separate template namespace; prefix helper
names with the chart name to avoid collisions.

## 5. Parent chart and subchart

The parent's `Chart.yaml` declares `demo-subchart` as a dependency. Its source
is already in `charts/demo-subchart`, so this example needs no repository URL
or network fetch. Helm renders the child as part of the parent's release; the
child is not installed as an independent release.

The dependency has an `alias` of `demoSubchart`, so its values are set under
that name. The `condition` checks `demoSubchart.enabled`; the child is included
by default and can be switched off:

```powershell
helm template demo . --set demoSubchart.enabled=false # Disable only the aliased child dependency.
helm template demo . --set tags.learning-examples=false # A true condition takes precedence over this tag value.
```

The child `values.yaml` has an `exports.data.greeting` value. `import-values`
copies that exported map to the parent's `importedDemo` path. The parent
ConfigMap reads `.Values.importedDemo.greeting`. This is a controlled way to
publish selected child values; it does not make all child values global.

`helm dependency list .` shows declared dependencies. `helm dependency update .`
resolves dependency versions and may create `Chart.lock`; commit a lock file
for reproducible remote dependency builds. This local child is checked into
`charts/` and can be rendered as-is.

## 6. Install, upgrade, inspect, remove

These commands require a reachable Kubernetes cluster and a configured
`kubectl` context. They create a namespace named `learning`:

```powershell
helm upgrade --install demo . --namespace learning --create-namespace # Install or upgrade release demo in a new namespace.
kubectl -n learning get deployment,service,pod # Check the workload, network endpoint, and Pods.
kubectl -n learning port-forward service/demo-learning-web 8080:80 # Forward local port 8080 to Service port 80.
```

Open `http://localhost:8080` while port-forward is running. This chart does not
create a public cloud load balancer; the default Service type is `ClusterIP`.

Change a release by changing a value and upgrading. Helm records a revision:

```powershell
helm upgrade demo . --namespace learning --set replicaCount=3 # Change the replica count and create a release revision.
helm history demo --namespace learning # List release revisions available for rollback.
helm rollback demo 1 --namespace learning # Restore the resources and values from revision 1.
helm get values demo --namespace learning --all # Show merged defaults and stored overrides.
helm get manifest demo --namespace learning # Inspect resources tracked by Helm.
```

Remove the release with `helm uninstall demo --namespace learning`. Persistent
volume claims may outlive releases depending on Kubernetes policy; inspect and
remove storage deliberately rather than assuming uninstall deletes the data.

## 7. Optional resources and chart lifecycle

Ingress, HPA, and PVC templates are guarded by values and disabled by default.
Enable ingress only if an Ingress controller exists. Enable autoscaling only
when metrics-server can report CPU usage. Enabling persistence requires a
StorageClass or a manually provisioned volume. Render each option before
installing it:

```powershell
helm template demo . --set ingress.enabled=true # Render the optional networking.k8s.io/v1 Ingress.
helm template demo . --set autoscaling.enabled=true # Render the optional autoscaling/v2 HPA.
helm template demo . --set persistence.enabled=true # Render the optional PVC and Pod mount.
```

CRDs are different: place CRD definitions as plain YAML under `crds/`, not in
`templates/`. Helm installs those definitions before templates but does not
template them or upgrade/delete them like ordinary release resources. This
folder leaves `crds/` empty because this demo does not need a custom API.

Package the chart with `helm package .`; the output filename includes the chart
name and chart `version`. `.helmignore` can exclude local files from that
package. To publish charts, teams commonly use an OCI registry or a chart
repository and pin dependency versions.

## Exercises

1. Change `replicaCount`, render, and find the resulting Deployment field.
2. Change `image.tag`; compare chart `version` with `appVersion`.
3. Set `demoSubchart.enabled=false`; find which child resource disappears.
4. Change `demoSubchart.message`; find the child ConfigMap value.
5. Change `fullnameOverride`; check that Deployment, Service, ConfigMap, and
	ServiceAccount references still agree.
6. Enable ingress, render, and trace the backend from Ingress to Service.
7. Add a harmless key to `config`, render, and find it in the parent ConfigMap.
8. Add a topology spread constraint using `app.kubernetes.io/name` and
	`app.kubernetes.io/instance` labels, then verify the generated selector.
