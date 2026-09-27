# Kubernetes API Resource Catalog

This catalog broadens the four-object lab in `webapp.yaml` into an API-wide map.
It is an index and learning guide, not a copy of every schema field. Kubernetes
is extensible and its API changes over time, so no static file can list every
kind available in every cluster. Use the live-discovery commands below and the
official API reference for exact schemas.

## Start with the API model

The Kubernetes API is a versioned REST API. A stored API object normally has:

- `apiVersion`: the API group and version that define this representation.
- `kind`: the object type, such as `Pod`, `Deployment`, or `NetworkPolicy`.
- `metadata`: identity and management data such as name, namespace, labels, and
  owner references.
- `spec`: desired settings for objects that accept configuration.
- `status`: observed state, normally written by Kubernetes controllers rather
  than by a user-authored manifest.

The API group plus version is not the same thing as the resource kind. For
example, `apps/v1` contains a `Deployment`; `networking.k8s.io/v1` contains an
`Ingress`; the original core group is written simply as `v1` for a `Pod`,
`ConfigMap`, or `Service`.

An API kind, a REST resource name, and a subresource are related but different
terms. `Deployment` is a kind; `deployments` is its usual plural REST name;
`deployments/web-demo/scale` is a subresource, not another kind. Other familiar
subresources include `pods/log`, `pods/exec`, `pods/status`, and `pods/eviction`.

## Discover what your cluster serves

The API server is the authority for your cluster. Its results include APIs
installed by add-ons and CRDs, and exclude APIs disabled or not served by that
cluster's version.

```powershell
kubectl api-versions # List the API group/version paths served by this cluster.
kubectl api-resources --sort-by=group # List served resource names, kinds, scope, and API groups.
kubectl api-resources --namespaced=true # List only resources that belong to a namespace.
kubectl api-resources --namespaced=false # List only cluster-scoped resources.
kubectl api-resources --api-group=apps # List only resources from the apps API group.
kubectl api-resources --api-group=networking.k8s.io # List resources from the networking API group.
kubectl explain deployment # Show the schema summary for a Deployment on this cluster.
kubectl explain deployment.spec.template.spec.containers --recursive # Explore nested container fields.
kubectl explain networkpolicy.spec --recursive # Explore the fields for a network policy.
```

`kubectl explain` uses the server's published schema. Prefer it when a field may
have changed between Kubernetes versions. For a specific resource instance, use
`kubectl get <kind> <name> -n <namespace> -o yaml` to inspect the live object;
the API server may add defaults and a controller-managed `status` section.

## Built-in API group inventory

This table follows the official Kubernetes API group/version index linked
below. Versions are group-level summaries: not every kind is served in every
listed version. Open the kind's page for its precise `apiVersion`, fields,
required values, defaults, and deprecation status.

| API group | Versions in the reference index | Resource kinds and what they are for |
| --- | --- | --- |
| `admissionregistration.k8s.io` | `v1`, `v1beta1`, `v1alpha1` | `MutatingAdmissionPolicy` and its binding; `ValidatingAdmissionPolicy` and its binding; `MutatingWebhookConfiguration`; `ValidatingWebhookConfiguration`. These configure checks or changes applied when objects enter the API server. |
| `apiextensions.k8s.io` | `v1` | `CustomResourceDefinition` (CRD), which teaches the API server a new custom kind. The CRD is built in; kinds supplied by CRDs are not a fixed part of Kubernetes. |
| `apiregistration.k8s.io` | `v1` | `APIService`, which registers an aggregated API server behind the main API endpoint. Usually managed by cluster add-ons. |
| `internal.apiserver.k8s.io` | `v1alpha1` | `StorageVersion`, control-plane storage-version coordination. Internal operational API; application users should not create it. |
| `apps` | `v1` | `Deployment`, `ReplicaSet`, `StatefulSet`, `DaemonSet`, and `ControllerRevision`. Deployments, StatefulSets, and DaemonSets are common workload controllers; ReplicaSets and ControllerRevisions are usually managed by controllers. |
| `authentication.k8s.io` | `v1` | `TokenReview` and `SelfSubjectReview`, API requests for authentication information rather than application workloads. |
| `authorization.k8s.io` | `v1` | `SubjectAccessReview`, `LocalSubjectAccessReview`, `SelfSubjectAccessReview`, and `SelfSubjectRulesReview`, which ask what an identity may do. These are commonly used by control-plane components and tools. |
| `autoscaling` | `v2`, `v1` | `HorizontalPodAutoscaler` (HPA), which changes a scalable workload's replica count using metrics. `Scale` is a subresource, not a standalone kind. |
| `batch` | `v1` | `Job` runs work to completion; `CronJob` creates Jobs on a schedule. |
| `certificates.k8s.io` | `v1`, `v1beta1` | `CertificateSigningRequest`, `ClusterTrustBundle`, and `PodCertificateRequest`. Certificate approval, trust distribution, and newer Pod certificate features require appropriate permissions and may depend on cluster configuration. |
| `coordination.k8s.io` | `v1`, `v1beta1`, `v1alpha2` | `Lease` is used for leader election and node heartbeats; `LeaseCandidate` supports coordinated leader election. |
| Core (`v1`) | `v1` | `Binding`, `ConfigMap`, `Endpoints`, `Event`, `LimitRange`, `Namespace`, `Node`, `PersistentVolume`, `PersistentVolumeClaim`, `Pod`, `PodTemplate`, `ReplicationController`, `ResourceQuota`, `Secret`, `Service`, and `ServiceAccount`. These include the basic runtime, configuration, naming, and storage objects. |
| `discovery.k8s.io` | `v1` | `EndpointSlice`, the scalable representation of the ready network endpoints behind Services. Normally created by a controller, not by an application author. |
| `events.k8s.io` | `v1` | `Event`, best-effort diagnostic information about changes and failures. Events expire and are not a durable audit log. |
| `flowcontrol.apiserver.k8s.io` | `v1` | `FlowSchema` and `PriorityLevelConfiguration`, which configure API Priority and Fairness for API requests. Cluster administration concern. |
| `lifecycle.k8s.io` | `v1alpha1` | `Eviction` and `EvictionRequest`, experimental eviction coordination APIs. Do not assume these alpha kinds exist on every cluster. |
| `networking.k8s.io` | `v1` | `Ingress`, `IngressClass`, `NetworkPolicy`, `IPAddress`, and `ServiceCIDR`. Ingress describes HTTP routing; NetworkPolicy describes Pod traffic rules; IPAddress and ServiceCIDR support Service IP allocation. |
| `node.k8s.io` | `v1` | `RuntimeClass`, which selects a configured container runtime class for a Pod. Runtime classes must be provided by the cluster. |
| `policy` | `v1` | `PodDisruptionBudget` (PDB), which limits voluntary disruptions to selected Pods. It does not prevent every failure or involuntary disruption. |
| `rbac.authorization.k8s.io` | `v1` | `Role`, `RoleBinding`, `ClusterRole`, and `ClusterRoleBinding`. Roles describe permissions; bindings grant those permissions to users, groups, or ServiceAccounts. Cluster-scoped grants deserve particular care. |
| `resource.k8s.io` | `v1`, `v1beta2`, `v1beta1`, `v1alpha3` | `DeviceClass`, `DeviceTaintRule`, `ResourceClaim`, `ResourceClaimTemplate`, `ResourcePoolStatusRequest`, and `ResourceSlice`. These support Dynamic Resource Allocation for devices such as accelerators; availability depends on Kubernetes version, feature gates, and drivers. |
| `scheduling.k8s.io` | `v1`, `v1beta1`, `v1alpha3` | `PriorityClass` is commonly used to influence scheduling priority. `Workload`, `PodGroup`, and `CompositePodGroup` are newer workload-group scheduling APIs and may be feature-gated. |
| `storage.k8s.io` | `v1` | `StorageClass`, `CSIDriver`, `CSINode`, `CSIStorageCapacity`, `VolumeAttachment`, and `VolumeAttributesClass`. StorageClass selects provisioning behavior; CSI kinds are generally registered or managed by storage drivers. PV and PVC are in the core `v1` group. |
| `storagemigration.k8s.io` | `v1`, `v1beta1` | `StorageVersionMigration`, an operational request to migrate stored objects between storage versions. Normally handled by cluster administrators and controllers. |

The resource kinds above are grouped for learning, not as a recommendation to
create every kind yourself. Many are observations or controller-owned records.
For example, the scheduler and kubelet report Node and Pod status; the Service
controller creates EndpointSlices; a Deployment creates ReplicaSets; and a
CSI driver populates storage-related objects.

## APIs added by cluster components

The 24 groups above are the built-in groups in the linked reference snapshot.
Real clusters may serve additional APIs through aggregated API servers or
CRDs. These are common examples, not a complete list of add-ons:

| API group | Example kinds | Usually provided by |
| --- | --- | --- |
| `metrics.k8s.io` | `NodeMetrics`, `PodMetrics` | Metrics Server; used by `kubectl top` and CPU-based HPAs. |
| `custom.metrics.k8s.io` | Adapter-specific metric resources | A custom metrics adapter. |
| `external.metrics.k8s.io` | Adapter-specific external metric resources | An external metrics adapter. |
| `gateway.networking.k8s.io` | `GatewayClass`, `Gateway`, `HTTPRoute`, `GRPCRoute` | The separately installed Gateway API CRDs and a compatible controller. |
| Operator-defined groups | Any CRD-defined kind | An operator or platform add-on installed in that cluster. |

The exact versions and kinds in these groups depend on the component release.
Check the API server instead of assuming an add-on is installed:

```powershell
kubectl api-resources --api-group=metrics.k8s.io # Check whether Metrics Server exposes its API.
kubectl api-resources --api-group=gateway.networking.k8s.io # Check whether Gateway API CRDs are installed.
kubectl get crds # List custom resource definitions installed in this cluster.
```

## Main resource families

### Workloads and Pods

A Pod is the smallest object Kubernetes schedules. It groups one or more
containers that share a network identity and can share volumes. A Pod created
by hand is not automatically replaced if it disappears.

For ordinary stateless services, create a Deployment. It manages ReplicaSets,
which maintain the Pod count and support rolling updates. Use a StatefulSet
when replicas need stable identities or stable per-replica storage. Use a
DaemonSet when a Pod should run on each eligible node. Use a Job for a finite
task and a CronJob for repeated scheduled Jobs. These controllers create Pods;
most applications should change the controller's Pod template instead of
editing a live Pod.

### Networking

A Service provides a stable virtual endpoint for a changing set of ready Pods.
Its selector commonly matches Pod labels. Service types include `ClusterIP`
(in-cluster), `NodePort` (a port on nodes), and `LoadBalancer` (requests an
external load balancer from a supporting environment). `ExternalName` maps a
Service name to a DNS name and does not proxy Pods.

EndpointSlices describe Service backends. Ingress defines HTTP/HTTPS host and
path routing but needs an installed Ingress controller. Ingress is not itself a
controller and does not guarantee a public IP. NetworkPolicy selects Pods and
specifies allowed ingress or egress traffic; it has an effect only when the
cluster network plugin enforces it. Gateway API kinds such as `Gateway` and
`HTTPRoute` are commonly supplied by separately installed CRDs, not by the
built-in Kubernetes API catalog above.

### Configuration and identity

ConfigMaps hold non-secret configuration. Secrets hold sensitive values, but
access must still be restricted and encryption-at-rest configured as needed.
Both can be projected as files or exposed as container environment variables.
ServiceAccounts provide workload identities; RBAC Roles and Bindings grant API
permissions. Do not give a workload cluster-wide permissions unless it truly
needs them.

### Storage

A PersistentVolume (PV) represents storage available to the cluster; a
PersistentVolumeClaim (PVC) requests storage for a workload. A StorageClass
selects how a provisioner creates volumes. A CSI driver connects Kubernetes to
a storage provider. A Pod's `emptyDir` is temporary Pod storage, not a PV/PVC and
not persistent across Pod replacement.

### Policies and cluster controls

ResourceQuota limits aggregate requests in a namespace; LimitRange supplies or
bounds per-object resources. PodDisruptionBudget limits some voluntary
 disruptions. PriorityClass assigns scheduling priority. Admission policies and
webhooks validate or mutate incoming objects. These resources affect other
workloads, so learn them on a disposable cluster and inspect their scope before
applying them.

## API version and lifecycle

A version such as `v1`, `v1beta1`, or `v1alpha1` is the schema contract for a
kind. Stable APIs (`v1`) are intended for long-term use. Beta and alpha APIs may
change or be disabled; feature-gated kinds may not be served at all. Use the
version printed by `kubectl api-resources` and the matching page in the
reference. Do not copy an old tutorial's `apiVersion` without checking it.

Some older kinds are deprecated while their replacements are active. Examples:
`Endpoints` is deprecated in newer Kubernetes releases in favor of
`discovery.k8s.io/v1 EndpointSlice`; `ComponentStatus` is deprecated; and
`ReplicationController` is a legacy workload controller generally replaced by
Deployment. Removed APIs are not restored by using an older YAML file.

Kubernetes also has API subresources such as `status`, `scale`, `log`, `exec`,
and `eviction`. They have their own permissions and HTTP behavior, but are not
independent persisted kinds. CRDs add still more kinds, whose schemas and
versions are defined by whichever operators are installed in a cluster.

## Authoritative references

The Kubernetes API reference is generated from Kubernetes API definitions and
is the source for field-level schemas. Its current documentation build may not
match your cluster version, so compare it with live discovery and `kubectl
explain` before applying a manifest.

- [Kubernetes API reference and all API groups](https://kubernetes.io/docs/reference/kubernetes-api/)
- [API groups and served versions](https://kubernetes.io/docs/reference/kubernetes-api/group-versions/)
- [API authentication and authorization concepts](https://kubernetes.io/docs/reference/access-authn-authz/)
- [Core API kinds](https://kubernetes.io/docs/reference/kubernetes-api/core/)
- [Apps API kinds](https://kubernetes.io/docs/reference/kubernetes-api/apps/)
- [Batch API kinds](https://kubernetes.io/docs/reference/kubernetes-api/batch/)
- [Networking API kinds](https://kubernetes.io/docs/reference/kubernetes-api/networking/)
- [Storage API kinds](https://kubernetes.io/docs/reference/kubernetes-api/storage/)
- [RBAC API kinds](https://kubernetes.io/docs/reference/kubernetes-api/rbac/)
- [Autoscaling API kinds](https://kubernetes.io/docs/reference/kubernetes-api/autoscaling/)
- [Policy API kinds](https://kubernetes.io/docs/reference/kubernetes-api/policy/)
- [Discovery API kinds](https://kubernetes.io/docs/reference/kubernetes-api/discovery/)
- [Certificates API kinds](https://kubernetes.io/docs/reference/kubernetes-api/certificates/)
- [Coordination API kinds](https://kubernetes.io/docs/reference/kubernetes-api/coordination/)
- [Admission registration API kinds](https://kubernetes.io/docs/reference/kubernetes-api/admissionregistration/)
- [API extensions and CRDs](https://kubernetes.io/docs/reference/kubernetes-api/apiextensions/)
- [API registration](https://kubernetes.io/docs/reference/kubernetes-api/apiregistration/)
- [Resource allocation APIs](https://kubernetes.io/docs/reference/kubernetes-api/resource/)
- [Scheduling API kinds](https://kubernetes.io/docs/reference/kubernetes-api/scheduling/)
- [Events API kinds](https://kubernetes.io/docs/reference/kubernetes-api/events/)
- [Flow control API kinds](https://kubernetes.io/docs/reference/kubernetes-api/flowcontrol/)
- [Lifecycle API kinds](https://kubernetes.io/docs/reference/kubernetes-api/lifecycle/)
- [Node API kinds](https://kubernetes.io/docs/reference/kubernetes-api/node/)
- [Storage migration API kinds](https://kubernetes.io/docs/reference/kubernetes-api/storagemigration/)
