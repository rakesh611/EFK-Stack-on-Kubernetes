# EFK Stack on Kubernetes — Complete README

## 1. What is EFK?

**EFK** stands for:

- **Elasticsearch** — stores and searches logs.
- **Fluent Bit** — collects, parses, enriches, and forwards logs.
- **Kibana** — provides a web UI for searching, filtering, and visualizing logs.

The EFK stack is commonly used for **centralized logging** in Kubernetes and Linux environments.

Instead of checking logs separately on every node or pod, EFK collects logs into one central place.

---

## 2. Why do we need centralized logging?

In Kubernetes, applications run in multiple pods and nodes.

Without centralized logging:

```text
Node 1
 ├── Pod A logs
 └── Pod B logs

Node 2
 ├── Pod C logs
 └── Pod D logs
```

An administrator must log in to different nodes or execute:

```bash
kubectl logs <pod-name>
```

This becomes difficult when:

- There are hundreds of pods.
- Pods are recreated frequently.
- Applications run across multiple nodes.
- Logs must be retained for several days.
- Troubleshooting requires searching logs from many services.
- Security or audit teams need centralized access.

With EFK:

```text
Kubernetes Pods
      |
      v
Container Log Files
      |
      v
Fluent Bit
      |
      v
Elasticsearch
      |
      v
Kibana
      |
      v
Administrator / Developer / SRE
```

---

## 3. EFK Architecture

```text
+----------------------------------------------------------+
|                    Kubernetes Cluster                   |
|                                                          |
|  +-------------+     +-------------+     +-------------+ |
|  | Application |     | Application |     | Application | |
|  | Pod         |     | Pod         |     | Pod         | |
|  +------+------+     +------+------+     +------+------+ |
|         |                   |                   |        |
|         +-------------------+-------------------+        |
|                             |                            |
|                   Container Runtime Logs                 |
|                  /var/log/containers/*.log               |
|                             |                            |
|                             v                            |
|                  +---------------------+                 |
|                  | Fluent Bit DaemonSet|                 |
|                  | - Tail logs         |                 |
|                  | - Parse logs        |                 |
|                  | - Add metadata      |                 |
|                  | - Buffer logs       |                 |
|                  | - Forward logs      |                 |
|                  +----------+----------+                 |
+-----------------------------|----------------------------+
                              |
                              v
                   +----------------------+
                   | Elasticsearch Cluster|
                   | - Index logs         |
                   | - Search logs        |
                   | - Store logs         |
                   | - Retention          |
                   +----------+-----------+
                              |
                              v
                   +----------------------+
                   | Kibana               |
                   | - Discover           |
                   | - Dashboards         |
                   | - Visualizations     |
                   | - Alerts             |
                   +----------------------+
```

---

# 4. Elasticsearch

## 4.1 What is Elasticsearch?

**Elasticsearch** is a distributed search and analytics engine built around Apache Lucene.

In EFK, Elasticsearch is the central backend where logs are indexed and stored.

It supports:

- Full-text search.
- Structured field search.
- Aggregations.
- Filtering.
- Log analytics.
- Distributed storage.
- Replication.
- Time-based indices.
- REST APIs.

Example log document:

```json
{
  "@timestamp": "2026-09-17T10:30:00Z",
  "level": "ERROR",
  "message": "Database connection failed",
  "service": "payment-api",
  "namespace": "production",
  "pod": "payment-api-7d8c9f",
  "node": "worker-01"
}
```

Elasticsearch indexes fields such as:

- `message`
- `level`
- `service`
- `namespace`
- `pod`
- `node`
- `@timestamp`

This makes it possible to search:

```text
level: ERROR
```

or:

```text
service: payment-api AND namespace: production
```

---

## 4.2 Elasticsearch core concepts

### Cluster

A cluster is a group of Elasticsearch nodes working together.

```text
Elasticsearch Cluster
 ├── Master-eligible node
 ├── Data node
 └── Coordinating node
```

For a lab, one node may be enough.

For production, use multiple nodes and proper sizing.

### Node

A node is one Elasticsearch process.

Common node roles include:

- Master-eligible.
- Data.
- Ingest.
- Coordinating.
- Transform.
- Machine learning, where applicable.

### Index

An index is a logical collection of documents.

Example:

```text
logs-kubernetes-2026.09.17
```

An index is similar to a database table conceptually, but Elasticsearch is document-oriented.

### Document

A document is a JSON object.

Example:

```json
{
  "message": "Application started",
  "level": "INFO"
}
```

### Shard

An index is divided into shards.

Shards allow Elasticsearch to distribute data across nodes.

```text
Index: logs-2026.09.17
 ├── Primary shard 0
 ├── Primary shard 1
 └── Primary shard 2
```

### Replica

A replica is a copy of a primary shard.

Replicas provide:

- High availability.
- Failover.
- Additional read capacity.

For a single-node lab, replicas should normally be set to `0`.

### Mapping

A mapping defines how fields are stored and indexed.

Example:

```json
{
  "properties": {
    "message": {
      "type": "text"
    },
    "status_code": {
      "type": "integer"
    },
    "@timestamp": {
      "type": "date"
    }
  }
}
```

### Inverted index

Elasticsearch uses an inverted index to make text searching fast.

Conceptually:

```text
Word       Documents
error      1, 5, 9
timeout    2, 5
database   1, 4
```

---

## 4.3 Elasticsearch data lifecycle

A typical log lifecycle is:

```text
Log received
    |
    v
Document parsed
    |
    v
Document indexed
    |
    v
Stored in primary shard
    |
    v
Replicated if replicas exist
    |
    v
Searched through Kibana
    |
    v
Deleted according to retention policy
```

---

## 4.4 Elasticsearch storage requirements

Elasticsearch is storage-intensive.

Plan for:

- Persistent volumes.
- Fast disks.
- Adequate IOPS.
- Heap memory.
- CPU.
- Disk watermarks.
- Retention.
- Backup and restore.

Important production considerations:

- Do not run production Elasticsearch with `emptyDir`.
- Use persistent storage.
- Monitor disk usage.
- Configure retention.
- Avoid unlimited log growth.
- Test snapshot restoration.
- Secure Elasticsearch with authentication and TLS.

---

# 5. Fluent Bit

## 5.1 What is Fluent Bit?

**Fluent Bit** is a lightweight and high-performance log processor and forwarder.

In Kubernetes, Fluent Bit is commonly deployed as a **DaemonSet**, so one Fluent Bit pod runs on each node.

It collects logs from node-level log files and forwards them to Elasticsearch.

---

## 5.2 Fluent Bit responsibilities

Fluent Bit can:

1. Read log files.
2. Tail new log lines.
3. Parse JSON or other formats.
4. Add Kubernetes metadata.
5. Filter unwanted records.
6. Modify fields.
7. Buffer logs.
8. Retry failed delivery.
9. Forward logs to Elasticsearch.
10. Expose metrics.

---

## 5.3 Fluent Bit architecture

```text
+------------------------------+
| Fluent Bit                   |
|                              |
| Input                        |
|  Tail / Systemd / TCP        |
|          |                   |
|          v                   |
| Parser                       |
|  JSON / Regex / Multiline    |
|          |                   |
|          v                   |
| Filter                       |
|  Kubernetes metadata         |
|  Modify / Grep / Nest        |
|          |                   |
|          v                   |
| Buffer / Storage              |
|          |                   |
|          v                   |
| Output                       |
|  Elasticsearch / HTTP / etc. |
+------------------------------+
```

---

## 5.4 Fluent Bit input

The input defines where logs come from.

For Kubernetes container logs:

```ini
[INPUT]
    Name              tail
    Path              /var/log/containers/*.log
    Parser            cri
    Tag               kube.*
    Mem_Buf_Limit     50MB
    Skip_Long_Lines   On
```

Common inputs:

- `tail`
- `systemd`
- `forward`
- `tcp`
- `http`
- `stdin`

---

## 5.5 Fluent Bit parser

A parser converts raw text into structured fields.

Example raw log:

```text
{"level":"ERROR","message":"Connection failed"}
```

After JSON parsing:

```json
{
  "level": "ERROR",
  "message": "Connection failed"
}
```

For Kubernetes container logs, the `cri` parser is commonly used for CRI-formatted logs.

---

## 5.6 Fluent Bit filter

Filters modify or enrich records.

Common filters:

- `kubernetes`
- `grep`
- `modify`
- `nest`
- `record_modifier`
- `lua`
- `multiline`

Kubernetes metadata may include:

```json
{
  "kubernetes": {
    "namespace_name": "production",
    "pod_name": "payment-api-123",
    "container_name": "payment-api",
    "host": "worker-01"
  }
}
```

---

## 5.7 Fluent Bit output

The output defines where logs are sent.

Example:

```ini
[OUTPUT]
    Name            es
    Match           kube.*
    Host            elasticsearch.logging.svc
    Port            9200
    Logstash_Format On
    Retry_Limit     False
```

Common outputs include:

- Elasticsearch.
- OpenSearch.
- Kafka.
- HTTP.
- Loki.
- Fluentd.
- Cloud services.

---

## 5.8 Fluent Bit buffering

If Elasticsearch is temporarily unavailable, Fluent Bit may buffer records.

Memory buffering is fast but can lose data if the pod or node crashes.

Filesystem buffering is more durable.

Example:

```ini
[SERVICE]
    storage.path              /var/log/flb-storage
    storage.sync              normal
    storage.checksum          off
    storage.backlog.mem_limit 50M
```

For production, design buffering according to:

- Expected log volume.
- Outage duration.
- Available disk.
- Data-loss tolerance.

---

# 6. Kibana

## 6.1 What is Kibana?

**Kibana** is the web interface for Elasticsearch.

It allows users to:

- Search logs.
- Filter logs.
- Build dashboards.
- Create visualizations.
- Investigate incidents.
- Explore fields.
- View time-based log activity.
- Manage data views.
- Configure alerting features where supported.

Kibana does not normally collect logs directly. It queries Elasticsearch.

---

## 6.2 Kibana components

### Discover

Used for searching and exploring individual log events.

Example query:

```text
kubernetes.namespace_name: production
```

### Data View

A data view tells Kibana which indices to search.

Example:

```text
logs-*
```

or:

```text
filebeat-*
```

### Dashboard

A dashboard combines multiple visualizations.

Example dashboard panels:

- Total log count.
- Error count.
- Logs by namespace.
- Logs by pod.
- Logs by severity.
- Top error messages.
- Logs over time.

### Visualization

Examples:

- Line chart.
- Bar chart.
- Pie chart.
- Data table.
- Metric.
- Heat map.

### KQL

Kibana Query Language is used for filtering.

Examples:

```text
log.level: ERROR
```

```text
kubernetes.namespace_name: "production"
```

```text
message: "timeout"
```

```text
log.level: ERROR and kubernetes.container_name: "payment-api"
```

---

# 7. EFK vs ELK

## ELK

```text
Elasticsearch + Logstash + Kibana
```

## EFK

```text
Elasticsearch + Fluent Bit/Fluentd + Kibana
```

| Feature | Logstash | Fluent Bit |
|---|---|---|
| Runtime | JVM | Lightweight native binary |
| Resource usage | Usually higher | Usually lower |
| Processing | Very powerful | Fast and efficient |
| Kubernetes DaemonSet | Possible | Common |
| Plugin ecosystem | Large | Large and focused |
| Best use | Complex processing pipelines | Node-level collection and forwarding |

Fluent Bit is often selected for Kubernetes because it is lightweight and suitable for running on every node.

---

# 8. Deployment options

There are several ways to deploy EFK:

1. Kubernetes manifests.
2. Helm charts.
3. Elasticsearch and Kibana operators.
4. OpenShift logging operators.
5. Managed Elasticsearch services.

This README demonstrates a **basic Kubernetes lab deployment using manifests**.

For production, use an operator or a supported vendor distribution where appropriate.

---

# 9. Lab prerequisites

## Required tools

Install and configure:

```bash
kubectl
```

Optional:

```bash
helm
curl
jq
```

## Kubernetes requirements

Recommended for this lab:

- Kubernetes cluster with at least one worker node.
- Dynamic storage provisioner, or manually created PersistentVolume.
- `kubectl` configured.
- Internet access to pull images.
- Sufficient CPU and memory.

Check cluster:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

Check storage:

```bash
kubectl get storageclass
```

Create namespace:

```bash
kubectl create namespace logging
```

---

# 10. Recommended lab architecture

```text
Namespace: logging

Elasticsearch
 └── StatefulSet
     └── PersistentVolumeClaim

Kibana
 └── Deployment
     └── Service

Fluent Bit
 └── DaemonSet
     ├── ConfigMap
     ├── ServiceAccount
     ├── ClusterRole
     └── ClusterRoleBinding
```

---

# 11. Deploy Elasticsearch from scratch

## 11.1 Create Elasticsearch manifest

Create a file:

```bash
vi elasticsearch.yaml
```

Add:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: logging
spec:
  clusterIP: None
  selector:
    app: elasticsearch
  ports:
    - name: http
      port: 9200
      targetPort: 9200
    - name: transport
      port: 9300
      targetPort: 9300
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: logging
spec:
  serviceName: elasticsearch
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
        - name: elasticsearch
          image: docker.elastic.co/elasticsearch/elasticsearch:8.15.0
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 9200
            - name: transport
              containerPort: 9300
          env:
            - name: discovery.type
              value: single-node
            - name: xpack.security.enabled
              value: "false"
            - name: ES_JAVA_OPTS
              value: "-Xms512m -Xmx512m"
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "1"
              memory: "2Gi"
          volumeMounts:
            - name: elasticsearch-data
              mountPath: /usr/share/elasticsearch/data
  volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 20Gi
```

> Note: The image version is an example. In a real environment, pin a version that is supported and tested for your platform. Do not blindly use an old version for production.

Apply:

```bash
kubectl apply -f elasticsearch.yaml
```

Check:

```bash
kubectl get statefulset -n logging
kubectl get pods -n logging -w
kubectl get pvc -n logging
kubectl get svc -n logging
```

---

## 11.2 Test Elasticsearch

Port-forward:

```bash
kubectl port-forward -n logging svc/elasticsearch 9200:9200
```

In another terminal:

```bash
curl http://127.0.0.1:9200
```

Check cluster health:

```bash
curl http://127.0.0.1:9200/_cluster/health?pretty
```

Check indices:

```bash
curl http://127.0.0.1:9200/_cat/indices?v
```

Create a test document:

```bash
curl -X POST \
  http://127.0.0.1:9200/test-logs/_doc/1 \
  -H 'Content-Type: application/json' \
  -d '{
    "level": "INFO",
    "message": "EFK test log",
    "service": "demo"
  }'
```

Search:

```bash
curl http://127.0.0.1:9200/test-logs/_search?pretty
```

---

# 12. Deploy Kibana from scratch

## 12.1 Create Kibana manifest

Create:

```bash
vi kibana.yaml
```

Add:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: logging
spec:
  selector:
    app: kibana
  ports:
    - name: http
      port: 5601
      targetPort: 5601
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: logging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
        - name: kibana
          image: docker.elastic.co/kibana/kibana:8.15.0
          ports:
            - containerPort: 5601
          env:
            - name: ELASTICSEARCH_HOSTS
              value: '["http://elasticsearch.logging.svc.cluster.local:9200"]'
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "1"
              memory: "1Gi"
```

Apply:

```bash
kubectl apply -f kibana.yaml
```

Check:

```bash
kubectl get deployment -n logging
kubectl get pods -n logging
kubectl logs -n logging deployment/kibana
```

---

## 12.2 Access Kibana

Port-forward:

```bash
kubectl port-forward -n logging svc/kibana 5601:5601
```

Open in a browser:

```text
http://localhost:5601
```

---

# 13. Deploy Fluent Bit from scratch

Fluent Bit requires:

- ServiceAccount.
- ClusterRole.
- ClusterRoleBinding.
- ConfigMap.
- DaemonSet.

The DaemonSet runs Fluent Bit on each node.

---

## 13.1 Create Fluent Bit manifest

Create:

```bash
vi fluent-bit.yaml
```

Add:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluent-bit
  namespace: logging
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluent-bit-read
rules:
  - apiGroups:
      - ""
    resources:
      - pods
      - namespaces
      - nodes
    verbs:
      - get
      - list
      - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fluent-bit-read
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fluent-bit-read
subjects:
  - kind: ServiceAccount
    name: fluent-bit
    namespace: logging
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: logging
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush                     1
        Log_Level                 info
        Parsers_File              parsers.conf

    [INPUT]
        Name                      tail
        Path                      /var/log/containers/*.log
        Parser                    cri
        Tag                       kube.*
        Mem_Buf_Limit             50MB
        Skip_Long_Lines           On
        Refresh_Interval           10

    [FILTER]
        Name                      kubernetes
        Match                     kube.*
        Kube_URL                  https://kubernetes.default.svc:443
        Kube_CA_File              /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File           /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix            kube.var.log.containers.
        Merge_Log                 On
        Keep_Log                  Off

    [OUTPUT]
        Name                      es
        Match                     kube.*
        Host                      elasticsearch.logging.svc.cluster.local
        Port                      9200
        Logstash_Format            On
        Logstash_Prefix            kubernetes
        Suppress_Type_Name         On
        Retry_Limit                False

  parsers.conf: |
    [PARSER]
        Name        cri
        Format      regex
        Regex       ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<log>.*)$
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: logging
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
    spec:
      serviceAccountName: fluent-bit
      tolerations:
        - operator: Exists
      containers:
        - name: fluent-bit
          image: cr.fluentbit.io/fluent/fluent-bit:3.1
          imagePullPolicy: IfNotPresent
          securityContext:
            runAsUser: 0
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          volumeMounts:
            - name: varlog
              mountPath: /var/log
            - name: containers
              mountPath: /var/lib/docker/containers
              readOnly: true
            - name: fluent-bit-config
              mountPath: /fluent-bit/etc/fluent-bit.conf
              subPath: fluent-bit.conf
            - name: fluent-bit-config
              mountPath: /fluent-bit/etc/parsers.conf
              subPath: parsers.conf
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
        - name: containers
          hostPath:
            path: /var/lib/docker/containers
        - name: fluent-bit-config
          configMap:
            name: fluent-bit-config
```

Apply:

```bash
kubectl apply -f fluent-bit.yaml
```

Check:

```bash
kubectl get daemonset -n logging
kubectl get pods -n logging -o wide
kubectl logs -n logging daemonset/fluent-bit
```

> Important: Kubernetes runtimes commonly write logs under `/var/log/containers` and `/var/log/pods`. The exact paths and permissions can differ by runtime and distribution. Validate the paths on your cluster. Some environments do not need the Docker container directory mount.

---

# 14. Generate application logs

Create a test application:

```bash
kubectl create deployment log-generator \
  --image=busybox:1.36 \
  -n default \
  -- /bin/sh -c 'i=0; while true; do echo "{\"level\":\"INFO\",\"message\":\"EFK test log\",\"counter\":$i}"; i=$((i+1)); sleep 5; done'
```

Check pod:

```bash
kubectl get pods
```

View logs:

```bash
kubectl logs deployment/log-generator
```

Wait for Fluent Bit to forward logs:

```bash
sleep 30
```

Check Elasticsearch indices:

```bash
kubectl port-forward -n logging svc/elasticsearch 9200:9200
```

Then:

```bash
curl http://127.0.0.1:9200/_cat/indices?v
```

Search logs:

```bash
curl 'http://127.0.0.1:9200/kubernetes-*/_search?pretty'
```

---

# 15. Configure Kibana Data View

Open:

```text
http://localhost:5601
```

In Kibana:

1. Open **Stack Management**.
2. Open **Data Views**.
3. Select **Create data view**.
4. Enter:

```text
kubernetes-*
```

5. Select the time field if available:

```text
@timestamp
```

6. Save the data view.
7. Open **Discover**.
8. Select the new data view.
9. Search and filter logs.

Example KQL filters:

```text
kubernetes.namespace_name: default
```

```text
message: "EFK test log"
```

```text
log.level: ERROR
```

Field names depend on the parser and Fluent Bit configuration.

---

# 16. Verify the complete EFK flow

## Verify Elasticsearch

```bash
kubectl get pods -n logging -l app=elasticsearch
kubectl logs -n logging statefulset/elasticsearch
```

Test:

```bash
curl http://127.0.0.1:9200/_cluster/health?pretty
```

## Verify Kibana

```bash
kubectl get pods -n logging -l app=kibana
kubectl logs -n logging deployment/kibana
```

## Verify Fluent Bit

```bash
kubectl get pods -n logging -l app=fluent-bit -o wide
kubectl logs -n logging daemonset/fluent-bit
```

## Verify log indices

```bash
curl http://127.0.0.1:9200/_cat/indices?v
```

## Verify log documents

```bash
curl 'http://127.0.0.1:9200/kubernetes-*/_search?pretty'
```

---

# 17. Troubleshooting

## 17.1 Elasticsearch pod is Pending

Check:

```bash
kubectl describe pod -n logging -l app=elasticsearch
kubectl get pvc -n logging
kubectl get events -n logging --sort-by=.lastTimestamp
```

Possible causes:

- No StorageClass.
- Insufficient storage.
- PVC cannot bind.
- Node resource shortage.

---

## 17.2 Elasticsearch pod crashes

Check:

```bash
kubectl logs -n logging statefulset/elasticsearch
kubectl describe pod -n logging -l app=elasticsearch
```

Common causes:

- Insufficient memory.
- Incorrect heap settings.
- File permission issues.
- Disk pressure.
- Unsupported kernel settings.
- Incorrect image configuration.

For many Linux environments, Elasticsearch may require:

```bash
vm.max_map_count=262144
```

Check:

```bash
sysctl vm.max_map_count
```

Set temporarily on a Linux node:

```bash
sudo sysctl -w vm.max_map_count=262144
```

For Kubernetes, apply the setting through your node configuration or supported infrastructure process. Do not rely on a temporary manual change for production.

---

## 17.3 Kibana cannot connect to Elasticsearch

Check DNS:

```bash
kubectl exec -n logging deploy/kibana -- \
  getent hosts elasticsearch.logging.svc.cluster.local
```

Check Elasticsearch service:

```bash
kubectl get svc -n logging elasticsearch
```

Check Elasticsearch endpoint:

```bash
kubectl run curl-test --rm -it \
  --image=curlimages/curl \
  --restart=Never -- \
  curl http://elasticsearch.logging.svc.cluster.local:9200
```

Check the Elasticsearch and Kibana versions. They should be compatible.

---

## 17.4 Fluent Bit is running but no logs arrive

Check Fluent Bit logs:

```bash
kubectl logs -n logging daemonset/fluent-bit
```

Check files on a node:

```bash
sudo ls -l /var/log/containers
sudo ls -l /var/log/pods
```

Check the Fluent Bit configuration:

```bash
kubectl get configmap -n logging fluent-bit-config -o yaml
```

Check Elasticsearch:

```bash
curl http://127.0.0.1:9200/_cat/indices?v
```

Possible causes:

- Wrong host log path.
- Wrong parser.
- Wrong Elasticsearch DNS name.
- NetworkPolicy blocking traffic.
- Authentication or TLS mismatch.
- Fluent Bit lacks permission to read logs.
- Index naming mismatch.
- Elasticsearch is unhealthy.

---

## 17.5 Fluent Bit permission denied

Check:

```bash
kubectl describe pod -n logging -l app=fluent-bit
```

The DaemonSet may need permission to read host log files.

Use the least privilege possible, and review your platform's security policy. On OpenShift, do not blindly use privileged settings; use the appropriate SecurityContextConstraints and supported logging solution.

---

## 17.6 No data in Kibana Discover

Check:

1. The correct data view is selected.
2. The time range includes the log timestamps.
3. The index pattern is correct.
4. The time field is configured correctly.
5. Fluent Bit is forwarding records.
6. Elasticsearch contains documents.

Search directly:

```bash
curl 'http://127.0.0.1:9200/_search?pretty'
```

---

# 18. Production design considerations

The basic manifests in this README are for learning and lab use.

Production requires additional design.

## 18.1 Elasticsearch high availability

Use multiple nodes where appropriate:

```text
Elasticsearch Cluster
 ├── Node 1
 ├── Node 2
 └── Node 3
```

Consider:

- Multiple replicas.
- Pod anti-affinity.
- Dedicated storage.
- Separate node pools.
- Resource requests and limits.
- PodDisruptionBudgets.
- Snapshot repository.
- TLS.
- Authentication.
- Monitoring.

## 18.2 Security

Do not run production logging with security disabled.

Use:

- TLS.
- Authentication.
- Authorization.
- Secret management.
- NetworkPolicies.
- Restricted service accounts.
- Role-based access control.
- Audit logging.
- Encryption at rest where required.

The example uses:

```yaml
xpack.security.enabled: "false"
```

This is only for a simple lab.

## 18.3 Retention

Logs must have a retention policy.

Examples:

- Keep application logs for 7 days.
- Keep security logs for 30 or 90 days.
- Archive selected logs to object storage.

Retention can be implemented through:

- Index lifecycle management.
- Data streams.
- Curator-like automation where supported.
- Scheduled deletion.
- Storage-tier policies.

## 18.4 Resource sizing

Monitor:

- CPU.
- Memory.
- JVM heap.
- Disk usage.
- Disk watermarks.
- Indexing rate.
- Search latency.
- Fluent Bit buffer usage.
- Dropped records.
- Network traffic.

## 18.5 Backpressure

Backpressure occurs when the destination cannot accept logs as quickly as Fluent Bit produces them.

```text
Application log rate > Elasticsearch ingest rate
                         |
                         v
                    Buffer grows
                         |
                         v
                Disk or memory pressure
```

Mitigations:

- Increase Elasticsearch capacity.
- Reduce unnecessary logs.
- Use buffering.
- Tune batch sizes.
- Use retry policies.
- Scale collectors.
- Apply retention.
- Monitor dropped records.

---

# 19. Useful Elasticsearch commands

Check cluster health:

```bash
curl -s http://127.0.0.1:9200/_cluster/health?pretty
```

List nodes:

```bash
curl -s http://127.0.0.1:9200/_cat/nodes?v
```

List indices:

```bash
curl -s http://127.0.0.1:9200/_cat/indices?v
```

Count documents:

```bash
curl -s http://127.0.0.1:9200/kubernetes-*/_count?pretty
```

Search errors:

```bash
curl -s \
  -H 'Content-Type: application/json' \
  -X GET \
  http://127.0.0.1:9200/kubernetes-*/_search \
  -d '{
    "query": {
      "match": {
        "level": "ERROR"
      }
    }
  }'
```

Delete a lab index:

```bash
curl -X DELETE http://127.0.0.1:9200/test-logs
```

Do not delete production indices without approval.

---

# 20. Useful Kubernetes commands

List logging resources:

```bash
kubectl get all -n logging
```

Check events:

```bash
kubectl get events -n logging --sort-by=.lastTimestamp
```

Check Fluent Bit on all nodes:

```bash
kubectl get pods -n logging -l app=fluent-bit -o wide
```

Follow Fluent Bit logs:

```bash
kubectl logs -n logging -l app=fluent-bit -f --prefix
```

Restart Fluent Bit:

```bash
kubectl rollout restart daemonset/fluent-bit -n logging
```

Restart Kibana:

```bash
kubectl rollout restart deployment/kibana -n logging
```

Restart Elasticsearch:

```bash
kubectl rollout restart statefulset/elasticsearch -n logging
```

Use caution when restarting Elasticsearch in production.

---

# 21. Cleanup lab

Delete the test application:

```bash
kubectl delete deployment log-generator
```

Delete Fluent Bit:

```bash
kubectl delete -f fluent-bit.yaml
```

Delete Kibana:

```bash
kubectl delete -f kibana.yaml
```

Delete Elasticsearch:

```bash
kubectl delete -f elasticsearch.yaml
```

Delete PVCs:

```bash
kubectl delete pvc -n logging --all
```

Delete namespace:

```bash
kubectl delete namespace logging
```

> Deleting PVCs can permanently delete stored logs. Confirm before running cleanup commands.

---

# 22. Important improvements for real environments

Before using this design in production:

- Use supported and compatible Elasticsearch and Kibana versions.
- Use TLS and authentication.
- Use persistent storage.
- Use multiple Elasticsearch nodes when required.
- Use a supported operator or platform logging solution.
- Configure retention and index lifecycle management.
- Configure backups and snapshots.
- Monitor ingestion and dropped records.
- Validate container log paths.
- Configure multiline parsing for stack traces.
- Use resource requests and limits.
- Apply NetworkPolicies.
- Protect Kibana with SSO/RBAC.
- Avoid collecting secrets or sensitive data.
- Mask passwords, tokens, and personal information from logs.
- Test failure recovery.
- Test node replacement and volume recovery.
- Document an incident-response process.

---

# 23. Multiline log example

Java stack traces and Python tracebacks span multiple lines.

Without multiline processing:

```text
ERROR Exception occurred
java.lang.RuntimeException: Failed
    at com.example.App.main(App.java:10)
    at ...
```

These lines may be stored as separate events.

With multiline processing, they can be combined into one event.

Conceptual Fluent Bit configuration:

```ini
[MULTILINE_PARSER]
    name          java
    type          regex
    flush_timeout 1000
    rule          "start_state" "/^\d{4}-\d{2}-\d{2}/" "cont"
    rule          "cont"        "/^\s+at\s+/" "cont"
```

The exact multiline rules depend on the application log format. Test carefully before deploying.

---

# 24. EFK interview questions

## What is EFK?

EFK is Elasticsearch, Fluent Bit, and Kibana. Fluent Bit collects and forwards logs, Elasticsearch stores and searches them, and Kibana visualizes them.

## Why is Fluent Bit deployed as a DaemonSet?

A DaemonSet ensures that a collector pod runs on each eligible node, allowing it to read node-level container logs.

## Why is Elasticsearch deployed as a StatefulSet?

A StatefulSet provides stable identity and is commonly used with persistent storage for stateful applications such as Elasticsearch.

## What is the role of Kibana?

Kibana is the user interface used to search, analyze, and visualize data stored in Elasticsearch.

## What happens if Elasticsearch is down?

Fluent Bit may retry and buffer records according to its configuration. If buffers fill, records may be delayed or dropped depending on the configuration and failure duration.

## What is the difference between an index and a shard?

An index is a logical collection of documents. A shard is a partition of an index used for distribution and scaling.

## Why should replicas be zero in a single-node lab?

A replica cannot be allocated to a different node when only one node exists. Setting replicas to zero avoids unnecessary unassigned replica shards.

## Why is persistent storage important?

Without persistent storage, Elasticsearch data can be lost when the pod is recreated or rescheduled.

## What is centralized logging?

Centralized logging collects logs from multiple applications, pods, and nodes into one searchable backend.

---

# 25. Final summary

```text
Elasticsearch
    |
    | Stores and searches log documents
    v
Kibana
    |
    | Displays and analyzes Elasticsearch data
    v
Fluent Bit
    |
    | Collects and forwards logs
    v
Kubernetes Nodes / Container Logs
```

The normal data flow is:

```text
Application
   -> Container Runtime
   -> Node Log Files
   -> Fluent Bit
   -> Elasticsearch
   -> Kibana
   -> User
```

Remember:

- **Elasticsearch = Store and Search**
- **Fluent Bit = Collect, Process, Forward**
- **Kibana = Explore and Visualize**

This is the core concept of the EFK stack.
