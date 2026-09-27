# Kubernetes Resources: Learning Guide

This folder contains plain Kubernetes YAML, not Helm templates. Its safe
hands-on lab demonstrates Namespace, ConfigMap, Deployment, and Service. The
[API resource catalog](API-RESOURCE-CATALOG.md) broadens this into a guide to
built-in API groups and resource kinds, including networking, workloads,
storage, policy, security, and cluster operations. Use live API discovery because
the exact resources available depend on the Kubernetes version, feature gates,
and installed custom resources.

## Files and apply order

- `namespace.yaml` creates the `learning-resources` namespace.
- `webapp.yaml` contains three YAML documents: a ConfigMap, a Deployment, and a
	Service. All three belong to the namespace created above.
- `README.md` explains the resources and gives commands to practice with them.
- `API-RESOURCE-CATALOG.md` maps the wider Kubernetes built-in API and links to
	the official, versioned field reference.

Create the namespace first. The API server needs to know about it before it can
accept the namespaced resources in `webapp.yaml`.

```powershell
kubectl apply -f k8s/Resources/namespace.yaml # Create the namespace for this example.
kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/learning-resources --timeout=60s # Wait until Kubernetes can accept objects in it.
kubectl apply -f k8s/Resources/webapp.yaml # Create the ConfigMap, Deployment, and Service.
```

## How to read a resource

Each YAML document describes one Kubernetes object. The `---` line starts a new
document, so `webapp.yaml` creates three objects in order.

- `apiVersion` selects the Kubernetes API that understands the object. A
	ConfigMap and Service use `v1`; a Deployment uses `apps/v1`.
- `kind` names the resource type Kubernetes should create.
- `metadata` gives the object its name, namespace, labels, and annotations.
- `spec` describes the desired state for resources that have one.
- `status`, which Kubernetes adds to live objects, reports what has happened.
	You normally write `spec` in these files and inspect `status` with `kubectl`.

The namespace itself is cluster-scoped, so its metadata has no `namespace`
field. The ConfigMap, Deployment, and Service are namespaced objects; their
`metadata.namespace` values must identify an existing Namespace.

## 1. Namespace

The Namespace in `namespace.yaml` is named `learning-resources`. A namespace is
a logical boundary for namespaced objects: it lets teams organize and address
objects with the same short names in different namespaces. It is not a virtual
cluster or a strong security boundary by itself; access control comes from
features such as RBAC and network policies.

Namespaced resources in this example explicitly set
`metadata.namespace: learning-resources`. If you omit that field, `kubectl`
usually uses the `default` namespace, which would separate the object from the
Namespace, ConfigMap, Deployment, and Service relationships used here.

Deleting a Namespace deletes the namespaced objects inside it. Always inspect
the namespace before deleting it, especially outside a learning cluster.

```powershell
kubectl get namespaces # List namespaces in the current cluster.
kubectl get namespace learning-resources -o yaml # Inspect this Namespace and its status.
kubectl get all -n learning-resources # List common workload and network resources in this namespace.
```

`kubectl get all` does not literally mean every Kubernetes kind. Use a resource
name such as `configmaps`, `secrets`, or `persistentvolumeclaims` when you need
to inspect a kind that the shorthand omits.

## 2. ConfigMap

The `web-demo-config` ConfigMap stores the non-secret key `APP_MESSAGE`. The
Deployment refers to the ConfigMap by its exact name using `envFrom.configMapRef`.
Kubernetes adds each ConfigMap key to the container environment, so the example
variable can be read with `printenv APP_MESSAGE`.

The stock NGINX image does not use `APP_MESSAGE` to change its page. The value is
there to make the ConfigMap-to-Pod connection easy to inspect. The page at `/`
is NGINX's normal default page.

ConfigMaps are for configuration, not passwords, tokens, or private keys. Use a
Secret or an external secret manager for sensitive data, and remember that a
Kubernetes Secret still needs appropriate access control and encryption at rest.

Environment variables are read when a container starts. If you edit and reapply
the ConfigMap, existing containers do not automatically receive new environment
values. Restart the Deployment after a change:

```powershell
kubectl get configmap web-demo-config -n learning-resources -o yaml # Inspect the stored configuration.
kubectl exec -n learning-resources deployment/web-demo -- printenv APP_MESSAGE # Read the value inside one running Pod.
kubectl rollout restart -n learning-resources deployment/web-demo # Restart Pods after changing environment-based configuration.
```

## 3. Deployment

A Deployment is a controller. You declare the desired Pod state, and the
Deployment manages a ReplicaSet that creates or removes Pods to approach that
state. If a Pod disappears, Kubernetes normally creates a replacement.

Important fields in this example:

- `spec.replicas: 2` asks for two Pods. Change this number in the file and apply
	it to practice declarative scaling.
- `spec.selector.matchLabels` tells the Deployment which Pods it owns. It must
	match `spec.template.metadata.labels`. Treat this selector as stable; changing
	it later can make an update invalid or detach existing Pods.
- `spec.template` is the blueprint for each Pod. Changes here cause the
	Deployment to create a new ReplicaSet and roll out replacement Pods.
- `spec.template.spec.containers` lists the containers inside each Pod. This
	example has one container named `web`.
- `image` identifies the container image. Pin a deliberate version for repeatable
	learning; avoid relying on a moving `latest` tag.
- `imagePullPolicy: IfNotPresent` reuses an image already cached on a node.
- `ports` documents the container's listening port. It does not publish that
	port outside the Pod; the Service below provides cluster networking.
- `envFrom.configMapRef` loads every key in the named ConfigMap into the
	container environment. The ConfigMap and Pod must be in the same namespace.
- Pod-level `securityContext` sets the process to non-root user ID `101`.
	Container-level `securityContext` disables privilege escalation, makes the
	root filesystem read-only, and drops Linux capabilities.
- The `tmp` `emptyDir` is writable temporary space. It exists for the lifetime
	of the Pod and is removed when the Pod is replaced. It is not permanent storage.
- `livenessProbe` asks Kubernetes to restart the container after repeated
	failures. `readinessProbe` controls whether the Pod should receive Service
	traffic. A failing readiness probe alone does not restart the container.
- `resources.requests` are used when the scheduler places a Pod and when CPU
	utilization is calculated. `resources.limits` cap container resource use.
- `cpu: 100m` means one tenth of a CPU core. `memory: 64Mi` means 64 mebibytes.
	Requests and limits are examples, not universal production recommendations.

The probe port is the named container port `http`, not a separate number. Named
ports reduce accidental mismatches when another resource refers to the port.

## 4. Service

A Service gives a changing set of Pods a stable in-cluster address. Pod IPs can
change when a Deployment replaces Pods; clients should connect to the Service
instead of remembering individual Pod IP addresses.

The Service selector is `app: web-demo`. It matches the Deployment's Pod label,
so the Service routes traffic to ready Pods created by that Deployment. The
Deployment selector uses the same label to manage those Pods. If either selector
does not match, the Service may have no endpoints or the Deployment may not own
the Pods you expect.

In `ports`, `port: 80` is the Service's client-facing port. `targetPort: http`
means forward traffic to the Pod port named `http`, which the container declares
as port `8080`. `type: ClusterIP` makes the address reachable inside the
cluster; it does not create a public internet endpoint.

```powershell
kubectl get service web-demo -n learning-resources -o yaml # Inspect the Service port and selector.
kubectl get endpointslices -n learning-resources -l kubernetes.io/service-name=web-demo # Check which ready Pod IPs receive traffic.
kubectl port-forward -n learning-resources service/web-demo 8080:80 # Temporarily forward local port 8080 to Service port 80.
```

While port-forward is running, open `http://localhost:8080` in a browser. This
local tunnel is for learning and debugging; the Service remains internal to the
cluster.

## Follow the resource links

These references describe the object relationships to check when reading the
manifests:

1. `namespace.yaml` creates `learning-resources`.
2. `web-demo-config` is in that namespace and is named by the Deployment's
	 `envFrom` reference.
3. `web-demo` Deployment creates Pods with label `app: web-demo`.
4. `web-demo` Service selects Pods with that same label and forwards port `80`
	 to the named container port `http` (`8080`).

Names and selectors are literal links between objects. Kubernetes does not
automatically infer that two objects are related just because their names look
similar.

## Inspect and troubleshoot

Start by checking whether the Deployment has available replicas, whether the
Pods are ready, and whether the Service has endpoints:

```powershell
kubectl get deployment,pods,service -n learning-resources -o wide # Compare desired, ready, and available Pods.
kubectl describe deployment web-demo -n learning-resources # Read rollout conditions and recent events.
kubectl describe pods -n learning-resources -l app=web-demo # Inspect Pod scheduling, probes, and container state.
kubectl logs -n learning-resources -l app=web-demo --all-containers=true --prefix=true # Read logs from matching Pods.
kubectl get events -n learning-resources --sort-by=.metadata.creationTimestamp # Show recent cluster explanations in time order.
```

Common symptoms:

- `ImagePullBackOff`: check the image name and tag, node network access, and any
	private-registry credentials.
- `CrashLoopBackOff`: inspect container logs and events. A bad startup command,
	missing configuration, or repeatedly failing liveness probe can cause restarts.
- Pods remain `Pending`: inspect events and resource requests. The cluster may
	have no node with enough available CPU or memory.
- Pods run but the Service has no endpoints: compare the Service selector with
	Pod labels and check whether the Pods are Ready.
- Port-forward connects but the page fails: compare Service `port`, Service
	`targetPort`, the named container port, and the HTTP probe path.
- `APP_MESSAGE` is missing: verify that the ConfigMap and Deployment share a
	namespace, the ConfigMap name matches, and the Pods were restarted after a
	ConfigMap environment value changed.

## Change and reapply

Edit `webapp.yaml` to change the desired replica count or configuration, then
apply the file again. Kubernetes compares the declared state with the live
objects and updates what it manages.

```powershell
kubectl diff -f k8s/Resources/webapp.yaml # Preview changes before applying them.
kubectl apply -f k8s/Resources/webapp.yaml # Reconcile the live resources with the file.
kubectl rollout status -n learning-resources deployment/web-demo # Wait for the updated Pods to be ready.
kubectl rollout history -n learning-resources deployment/web-demo # Review Deployment rollout revisions.
```

For a quick experiment, `kubectl scale` can change replicas immediately, but
that change is not written back to the manifest. Applying the file later restores
the replica count declared in `webapp.yaml`.

```powershell
kubectl scale -n learning-resources deployment/web-demo --replicas=3 # Temporarily scale to three Pods.
kubectl apply -f k8s/Resources/webapp.yaml # Restore the replica count declared in the manifest.
```

## Remove the example

Delete the application objects first, then delete the Namespace. Deleting the
Namespace also removes any other namespaced objects left inside it.

```powershell
kubectl delete -f k8s/Resources/webapp.yaml # Remove the ConfigMap, Deployment, and Service.
kubectl delete -f k8s/Resources/namespace.yaml # Remove the namespace and remaining namespaced objects.
```

The manifests are learning examples, not a production deployment. Production
workloads usually need reviewed image versions, real secret management, an
appropriate availability strategy, policy controls, monitoring, and
environment-specific resource sizing.
