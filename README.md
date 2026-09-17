# EFK Kubernetes Logging Stack

A Git-repository-style deployment of Elasticsearch, Fluent Bit, and Kibana on Kubernetes.

> **Lab scope:** This repository is designed for learning and testing. It uses a single-node Elasticsearch cluster and disables Elasticsearch security for simplicity. Do not use these settings for production.

## 1. What is EFK?

EFK means:

- **Elasticsearch:** Stores, indexes, and searches log documents.
- **Fluent Bit:** Collects logs from Kubernetes nodes, parses and enriches them, and forwards them.
- **Kibana:** Provides the web interface for searching and visualizing Elasticsearch data.

## 2. Log flow

```text
Application Pod
      |
      v
Container runtime log
      |
      v
/var/log/containers/*.log
      |
      v
Fluent Bit DaemonSet
      |
      | Kubernetes metadata + parsing
      v
Elasticsearch StatefulSet
      |
      v
Kibana
      |
      v
User / SRE / Developer
```

## 3. Repository layout

```text
efk-kubernetes/
├── README.md
├── namespace.yaml
├── elasticsearch/
│   ├── service.yaml
│   ├── statefulset.yaml
│   └── storage.yaml
├── kibana/
│   ├── configmap.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── fluent-bit/
│   ├── serviceaccount.yaml
│   ├── rbac.yaml
│   ├── configmap.yaml
│   └── daemonset.yaml
├── test-app/
│   └── log-generator.yaml
└── scripts/
    ├── deploy.sh
    ├── verify.sh
    └── cleanup.sh
```

## 4. Prerequisites

Required:

- A running Kubernetes cluster.
- `kubectl` configured.
- A working StorageClass, or a manually provisioned PersistentVolume.
- Permission to create a namespace, RBAC objects, DaemonSets, StatefulSets, and PVCs.
- Internet access to pull container images.

Check the cluster:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get storageclass
kubectl get pods -A
```

Recommended lab resources:

- At least 2 vCPU available.
- At least 4 GiB RAM available for the logging stack.
- At least 20 GiB persistent storage for Elasticsearch.

## 5. Important compatibility notes

This repository uses example image versions:

- Elasticsearch: `8.15.0`
- Kibana: `8.15.0`
- Fluent Bit: `3.1`

For a real environment, pin versions that are currently supported and tested together. Elasticsearch and Kibana should use compatible versions.

The example uses:

```yaml
xpack.security.enabled: "false"
```

This is only for a simple lab. Production deployments must use authentication, authorization, TLS, and a supported security configuration.

## 6. Deploy from scratch

### Step 1: Clone the repository

```bash
git clone <YOUR-GIT-REPOSITORY-URL>
cd efk-kubernetes
```

Or create the directory manually:

```bash
mkdir efk-kubernetes
cd efk-kubernetes
```

### Step 2: Create the namespace

```bash
kubectl apply -f namespace.yaml
kubectl get namespace logging
```

### Step 3: Deploy Elasticsearch

```bash
kubectl apply -f elasticsearch/storage.yaml
kubectl apply -f elasticsearch/service.yaml
kubectl apply -f elasticsearch/statefulset.yaml
```

Check:

```bash
kubectl get statefulset -n logging
kubectl get pods -n logging -l app=elasticsearch -w
kubectl get pvc -n logging
```

Wait until Elasticsearch is ready:

```bash
kubectl wait \
  --for=condition=ready \
  pod/elasticsearch-0 \
  -n logging \
  --timeout=300s
```

### Step 4: Test Elasticsearch

Port-forward:

```bash
kubectl port-forward -n logging svc/elasticsearch 9200:9200
```

In another terminal:

```bash
curl http://127.0.0.1:9200
curl http://127.0.0.1:9200/_cluster/health?pretty
curl http://127.0.0.1:9200/_cat/indices?v
```

Create a test document:

```bash
curl -X POST \
  http://127.0.0.1:9200/test-logs/_doc/1 \
  -H 'Content-Type: application/json' \
  -d '{
    "level": "INFO",
    "message": "Elasticsearch is working",
    "service": "efk-lab"
  }'
```

Search it:

```bash
curl http://127.0.0.1:9200/test-logs/_search?pretty
```

Stop port-forward with `Ctrl+C` after testing.

### Step 5: Deploy Kibana

```bash
kubectl apply -f kibana/configmap.yaml
kubectl apply -f kibana/deployment.yaml
kubectl apply -f kibana/service.yaml
```

Check:

```bash
kubectl get deployment -n logging
kubectl get pods -n logging -l app=kibana
kubectl logs -n logging deployment/kibana
```

Access Kibana:

```bash
kubectl port-forward -n logging svc/kibana 5601:5601
```

Open:

```text
http://localhost:5601
```

### Step 6: Deploy Fluent Bit

```bash
kubectl apply -f fluent-bit/serviceaccount.yaml
kubectl apply -f fluent-bit/rbac.yaml
kubectl apply -f fluent-bit/configmap.yaml
kubectl apply -f fluent-bit/daemonset.yaml
```

Check:

```bash
kubectl get daemonset -n logging
kubectl get pods -n logging -l app=fluent-bit -o wide
kubectl logs -n logging daemonset/fluent-bit
```

### Step 7: Deploy the test application

```bash
kubectl apply -f test-app/log-generator.yaml
```

Check:

```bash
kubectl get pods
kubectl logs deployment/log-generator
```

Wait approximately 30 seconds, then check Elasticsearch:

```bash
kubectl port-forward -n logging svc/elasticsearch 9200:9200
```

In another terminal:

```bash
curl http://127.0.0.1:9200/_cat/indices?v
curl 'http://127.0.0.1:9200/kubernetes-*/_search?pretty'
```

### Step 8: Configure Kibana

Open `http://localhost:5601`.

1. Open **Stack Management**.
2. Open **Data Views**.
3. Select **Create data view**.
4. Enter:

```text
kubernetes-*
```

5. Select `@timestamp` if it is available.
6. Save the data view.
7. Open **Discover**.
8. Select the data view.
9. Search logs.

Example KQL queries:

```text
kubernetes.namespace_name: default
```

```text
message: "EFK test log"
```

```text
log: "EFK test log"
```

Field names depend on the parser and Elasticsearch document structure.

## 7. One-command deployment

Make scripts executable:

```bash
chmod +x scripts/*.sh
```

Deploy:

```bash
./scripts/deploy.sh
```

Verify:

```bash
./scripts/verify.sh
```

Cleanup:

```bash
./scripts/cleanup.sh
```

> Cleanup deletes the logging namespace and its PVCs. This can permanently delete lab logs.

## 8. Troubleshooting

### Elasticsearch is Pending

```bash
kubectl describe pod -n logging elasticsearch-0
kubectl get pvc -n logging
kubectl get events -n logging --sort-by=.lastTimestamp
```

Common causes:

- No StorageClass.
- PVC cannot bind.
- Insufficient node resources.
- Storage provisioner failure.

### Elasticsearch crashes

```bash
kubectl logs -n logging elasticsearch-0
kubectl describe pod -n logging elasticsearch-0
```

On many Linux systems, Elasticsearch requires:

```bash
sysctl vm.max_map_count
```

The value commonly needs to be at least:

```text
262144
```

Configure this through your node-management process. Do not depend on a temporary manual change in production.

### Kibana cannot connect

```bash
kubectl logs -n logging deployment/kibana
kubectl get svc -n logging elasticsearch
kubectl run curl-test --rm -it \
  --image=curlimages/curl \
  --restart=Never -- \
  curl http://elasticsearch.logging.svc.cluster.local:9200
```

Check:

- Elasticsearch is Ready.
- Elasticsearch and Kibana versions are compatible.
- Service DNS is correct.
- NetworkPolicy is not blocking traffic.

### Fluent Bit is running but no logs arrive

```bash
kubectl logs -n logging daemonset/fluent-bit
kubectl get configmap -n logging fluent-bit-config -o yaml
```

On a Kubernetes node, check:

```bash
sudo ls -l /var/log/containers
sudo ls -l /var/log/pods
```

Possible causes:

- Incorrect host log path.
- Incorrect parser.
- Permission or security policy issue.
- Wrong Elasticsearch service name.
- Elasticsearch is unavailable.
- Authentication or TLS mismatch.

### No logs in Kibana

Check:

1. The correct data view.
2. The selected time range.
3. The index pattern.
4. The `@timestamp` field.
5. Elasticsearch documents directly.
6. Fluent Bit output errors.

## 9. Production checklist

Before production:

- Use a supported operator or platform logging solution.
- Use multiple Elasticsearch nodes where required.
- Use persistent storage.
- Enable TLS and authentication.
- Configure RBAC and SSO for Kibana.
- Configure index lifecycle and retention.
- Configure snapshots and restore testing.
- Monitor CPU, memory, disk, JVM heap, and ingestion rate.
- Configure multiline parsing for stack traces.
- Use NetworkPolicies.
- Avoid logging passwords, tokens, and sensitive information.
- Use resource requests and limits.
- Test node failure and volume recovery.
- Pin and regularly review image versions.

## 10. Cleanup

Delete the test app:

```bash
kubectl delete -f test-app/log-generator.yaml
```

Delete the logging stack:

```bash
kubectl delete -f fluent-bit/daemonset.yaml
kubectl delete -f fluent-bit/configmap.yaml
kubectl delete -f fluent-bit/rbac.yaml
kubectl delete -f fluent-bit/serviceaccount.yaml

kubectl delete -f kibana/service.yaml
kubectl delete -f kibana/deployment.yaml
kubectl delete -f kibana/configmap.yaml

kubectl delete -f elasticsearch/statefulset.yaml
kubectl delete -f elasticsearch/service.yaml
kubectl delete -f elasticsearch/storage.yaml

kubectl delete -f namespace.yaml
```

Or:

```bash
./scripts/cleanup.sh
```

## 11. Summary

```text
Elasticsearch = Store and Search
Fluent Bit    = Collect, Parse, Enrich, Forward
Kibana        = Explore and Visualize
```

The complete flow is:

```text
Pod -> Container Log -> Fluent Bit -> Elasticsearch -> Kibana
```
