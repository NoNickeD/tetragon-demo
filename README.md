# Cilium Tetragon Demo on Azure Kubernetes Service

A comprehensive demonstration of Cilium Tetragon's runtime security capabilities on AKS, built entirely with CNCF tools.

## Overview

This demo showcases:

- **eBPF-based runtime security** with Tetragon
- **Infrastructure as Code** using OpenTofu
- **GitOps deployment** with ArgoCD
- **Observability** with Prometheus & Grafana
- **Real-world attack scenarios** and detection
- **Production-ready security policies**
- **Optimized networking** with proper subnet sizing
- **High availability** with multi-node configuration

## Infrastructure Highlights

### Optimized Networking

- **VNet**: `10.0.0.0/14` (1M+ IP addresses)
- **Node Subnet**: `10.0.0.0/20` (4094 nodes)
- **Pod Subnet**: `10.1.0.0/16` (65K pods)
- **CNI**: Azure CNI with Cilium dataplane

### High Availability

- **System Nodes**: 2-5 nodes (autoscaling)
- **Workload Nodes**: 3-6 nodes (autoscaling)
- **Service Type**: ClusterIP (secure internal access)

### Resource Allocation

- **Node Size**: Standard_D4s_v5 (4 vCPUs, 16GB RAM)
- **Storage**: 100GB Premium SSD per node
- **Container Registry**: Azure Container Registry

## Prerequisites

### Required Tools

- **Azure CLI** (`az`) - [Install](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- **OpenTofu** (`tofu`) - [Install](https://opentofu.org/docs/intro/install/)
- **kubectl** - [Install](https://kubernetes.io/docs/tasks/tools/)
- **Helm** v3+ - [Install](https://helm.sh/docs/intro/install/)

### Azure Requirements

- Active Azure subscription
- Sufficient quota for:
  - 8 Standard_D4s_v5 VMs (2 system + 6 workload max)
  - 1 Container Registry
  - Large IP address space (10.0.0.0/14)

## Clone the Repository

```bash
git clone https://github.com/NoNickeD/tetragon-demo.git
cd tetragon-demo
```

## Setup

### Step 1: Infrastructure

```bash
cd infrastructure

# Setup backend storage
./scripts/setup-backend.sh

# Initialize OpenTofu
tofu init

# Plan infrastructure
tofu plan

# Apply infrastructure
tofu apply

# Get kubeconfig
az aks get-credentials \
  --resource-group $(tofu output -raw resource_group_name) \
  --name $(tofu output -raw cluster_name)
```

### Step 2: ArgoCD Installation

```bash
cd ..

# Create namespaces
kubectl apply -f tetragon/argocd/namespace.yaml

# Install ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --values tetragon/argocd/argocd-values.yaml

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### Step 3: Deploy Applications

```bash
# Deploy Tetragon and monitoring
kubectl apply -f tetragon/argocd/applications/

# Apply policies for demo
kubectl apply -f tetragon/policies/

# Verify policies are loaded
kubectl get tracingpolicies -n tetragon

# Deploy demo applications
kubectl apply -f demo/attack-scenarios/vulnerable-app.yaml
```

### Security Policies

The demo includes 4 optimized security policies:

1. **Sensitive File Monitoring** - Detects access to `/etc/shadow`, `/etc/passwd`, SSH keys
2. **Process Execution Monitoring** - Monitors execution from suspicious locations (`/tmp/`, `/dev/shm/`)
3. **Network Monitoring** - Tracks connections to mining ports and suspicious DNS activity
4. **Privilege Escalation Detection** - Monitors `setuid` calls and dangerous capabilities

All policies are located in `/tetragon/policies/` and optimized for Azure AKS environments.

## Running the Security Demo

### Quick Start

```bash
# Run the comprehensive security demonstration
./demo/attack-scenarios/working-demo.sh
```

This script will:

- Execute realistic attack scenarios against the vulnerable app
- Capture and analyze Tetragon security events in real-time
- Show exactly what threats are being detected
- Demonstrate the effectiveness of your security policies

### Real-time Monitoring

For live monitoring of security events:

```bash
# Monitor events from demo pod specifically
./scripts/monitor-demo-events.sh
```

In another terminal, run attacks:

```bash
./demo/attack-scenarios/working-demo.sh
```

### Manual Event Viewing

```bash
# View all Tetragon events (live stream)
kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra getevents -o compact

# Check policy status
kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra tracingpolicy list

# Verify Tetragon health
kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra status
```

### Grafana Dashboards

Access Grafana to view security metrics:

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Access at: http://localhost:3000
# Credentials: admin/tetragon-demo
```

### Service Access

Use the access script for easy port-forwarding:

```bash
# Access ArgoCD, Grafana, and Prometheus
./scripts/access.sh
```

## Testing and Verification

### Prerequisites Check

Before running the demo, verify all components are properly deployed:

```bash
# Check Tetragon pods are running
kubectl get pods -n tetragon

# Check demo application is running
kubectl get pods -n demo

# Verify security policies are loaded
kubectl get tracingpolicies -n tetragon
```

Expected results:

- Tetragon pods should be in `Running` status
- Demo pod `vulnerable-app-*` should be in `Running` status
- 4 policies should be listed: `sensitive-files`, `process-execution`, `network-monitoring`, `privilege-escalation`

### Quick Health Check

Verify Tetragon is capturing events:

```bash
# Test basic event capture
timeout 5 kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra getevents -o compact | head -5
```

You should see output similar to:

```bash
setuid  node-name /usr/bin/runc 0
syscall node-name /usr/bin/cilium-agent cap_capable
process kube-system/pod-name /some/binary
```

### Running the Full Demo

Execute the complete demonstration:

```bash
./demo/attack-scenarios/working-demo.sh
```

### What You Should See

The demo will show three types of output:

1. **Process Execution Events** - Lines showing `EXEC |` with pod names and executed commands
2. **Security Events Summary** - Event counts for detected kprobes:
   ```
   45 cap_capable
   12 __x64_sys_execve
    8 fd_install
    3 udp_sendmsg
   ```
3. **Capability Check Events** - Lines showing `CAP_CHECK |` entries with capability numbers

### Manual Testing (Alternative Method)

If you prefer to test manually or troubleshoot issues:

#### Terminal 1 - Start Monitoring

```bash
./scripts/monitor-demo-events.sh
```

#### Terminal 2 - Execute Tests

```bash
# Get the demo pod name
POD_NAME=$(kubectl get pods -n demo -l app=vulnerable-app -o jsonpath='{.items[0].metadata.name}')

# Test 1: File access monitoring
kubectl exec -n demo $POD_NAME -- cat /etc/passwd | head -3
kubectl exec -n demo $POD_NAME -- cat /etc/shadow | head -3

# Test 2: Process execution monitoring
kubectl exec -n demo $POD_NAME -- bash -c "echo '#!/bin/sh\necho Suspicious process from /tmp' > /tmp/test.sh && chmod +x /tmp/test.sh && /tmp/test.sh"

# Test 3: Network monitoring
kubectl exec -n demo $POD_NAME -- timeout 2 nc -zv 8.8.8.8 53 2>&1 || echo 'DNS connection attempted'

# Test 4: Privilege escalation monitoring
kubectl exec -n demo $POD_NAME -- python3 -c "import os; os.setuid(0)" 2>/dev/null || echo 'Setuid attempt made'
```

In Terminal 1, you should observe:

- `EXEC` events showing command executions
- `KPROBE` events showing security function calls
- File paths and process information

### Success Indicators

Your demo is working correctly when you see:

- **Process events** containing your demo pod name
- **Kprobe function names** like `fd_install`, `__x64_sys_execve`, `cap_capable`
- **Non-zero event counts** in the security events summary
- **File paths** appearing in events (e.g., `/etc/passwd`, `/etc/shadow`)
- **Capability numbers** like `CAP_21` (CAP_SYS_ADMIN)

### Verification Command

Run this single command to verify all components:

```bash
echo "=== Tetragon Demo Verification ===" && \
kubectl get pods -n tetragon --no-headers | wc -l | xargs echo "Tetragon pods:" && \
kubectl get pods -n demo --no-headers | wc -l | xargs echo "Demo pods:" && \
kubectl get tracingpolicies -n tetragon --no-headers | wc -l | xargs echo "Policies loaded:" && \
echo "Running quick test..." && \
POD_NAME=$(kubectl get pods -n demo -l app=vulnerable-app -o jsonpath='{.items[0].metadata.name}') && \
kubectl exec -n demo $POD_NAME -- echo "Test successful" && \
echo "All components ready - run ./demo/attack-scenarios/working-demo.sh"
```

## Project Structure

```
tetragon-demo/
├── infrastructure/         # OpenTofu configuration for AKS
│   ├── main.tf             # AKS cluster with Cilium CNI
│   ├── variables.tf        # Configuration variables
│   ├── outputs.tf          # Output values
│   └── scripts/            # Backend setup scripts
├── tetragon/               # Tetragon deployment
│   ├── argocd/             # ArgoCD GitOps setup
│   │   ├── applications/   # Tetragon & monitoring apps
│   │   └── argocd-values.yaml
│   ├── policies/           # Working security policies (4 policies)
│   └── policies-original/  # Original policies backup
├── demo/                   # Demo applications
│   ├── attack-scenarios/   # Vulnerable app + working demo
│   └── legitimate-app/     # Production app example
├── scripts/                # Automation scripts
│   ├── cleanup.sh          # Teardown script
│   ├── access.sh           # Service port-forwarding
│   ├── monitor-demo-events.sh  # Real-time event monitoring
│   └── reset-policies.sh # Policy management
└── README.md             # This documentation
```

## Troubleshooting

### No Events Appearing

If you're not seeing any events in the demo:

1. **Check if any events are being generated:**

   ```bash
   timeout 10 kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra getevents -o json | jq -r '.process_kprobe.function_name // "no-kprobe"' | sort | uniq -c | head -10
   ```

2. **Verify demo pod is generating events:**

   ```bash
   timeout 10 kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra getevents -o json | jq -r 'select(.process.pod.name) | .process.pod.name' | sort | uniq -c
   ```

3. **Check Tetragon health:**
   ```bash
   kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra status
   ```

### Component Status Issues

```bash
# Check Tetragon pods
kubectl get pods -n tetragon
kubectl logs -n tetragon ds/tetragon -c tetragon --tail=50

# Check demo pod
kubectl get pods -n demo
kubectl describe pod -n demo -l app=vulnerable-app

# Verify policies are loaded
kubectl get tracingpolicies -n tetragon
kubectl describe tracingpolicy sensitive-files -n tetragon
```

### Policy Loading Issues

```bash
# Check policy status
kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra tracingpolicy list

# Reload policies if needed
kubectl delete tracingpolicies --all -n tetragon
kubectl apply -f tetragon/policies/
```

### ArgoCD Deployment Issues

```bash
kubectl get applications -n argocd
argocd app sync tetragon
argocd app sync monitoring
```

### Network Connectivity Issues

```bash
# Test if demo pod has network access
POD_NAME=$(kubectl get pods -n demo -l app=vulnerable-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n demo $POD_NAME -- ping -c 2 8.8.8.8
kubectl exec -n demo $POD_NAME -- nslookup google.com
```

### Verbose Event Debugging

```bash
# Raw event output with full details
kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra getevents -o json | jq . | head -100

# Filter for specific event types
kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra getevents -o json | jq 'select(.process_kprobe.function_name == "cap_capable")'
```

## Cleanup

Remove all resources:

```bash
./scripts/cleanup.sh
```

Or manually:

```bash
# Delete Kubernetes resources
kubectl delete -f demo/
kubectl delete -f tetragon/policies/
kubectl delete namespace tetragon argocd monitoring demo production

# Destroy infrastructure
cd infrastructure
tofu destroy -auto-approve
```

## Security Considerations

- **Production Use**: Review and adjust policies for your specific requirements
- **Policy Testing**: Always test policies in non-production environments first
- **Performance**: Monitor CPU/memory usage when enabling multiple policies
- **False Positives**: Fine-tune policies to reduce false positives
- **Enforcement Mode**: Start with detection-only mode before enabling enforcement

## References

- [Cilium Tetragon Documentation](https://tetragon.io/docs/)
- [eBPF Documentation](https://ebpf.io/)
- [CNCF Projects](https://www.cncf.io/projects/)
- [Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Created by NN - [Blog Post](https://srekubecraft.io/posts/tetragon/)

---

**Note**: This is a demonstration environment. For production use, ensure proper security hardening, network isolation, and compliance with your organization's security policies.
