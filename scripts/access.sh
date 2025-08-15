#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Tetragon Demo Access Script${NC}"
echo "=========================="
echo ""

echo -e "${YELLOW}Available services:${NC}"
echo "1. ArgoCD (GitOps Dashboard)"
echo "2. Grafana (Monitoring Dashboard)"
echo "3. Prometheus (Metrics)"
echo "4. Tetragon CLI (Real-time Events)"
echo ""

read -p "Select service (1-4): " choice

case $choice in
    1)
        echo -e "${GREEN}Starting ArgoCD port-forward...${NC}"
        echo "Access ArgoCD at: http://localhost:8080"
        echo "Username: admin"
        echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo 'Check manually')"
        echo ""
        kubectl port-forward -n argocd svc/argocd-server 8080:80
        ;;
    2)
        echo -e "${GREEN}Starting Grafana port-forward...${NC}"
        echo "Access Grafana at: http://localhost:3000"
        echo "Username: admin"
        echo "Password: tetragon-demo"
        echo ""
        kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
        ;;
    3)
        echo -e "${GREEN}Starting Prometheus port-forward...${NC}"
        echo "Access Prometheus at: http://localhost:9090"
        echo ""
        kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
        ;;
    4)
        echo -e "${GREEN}Starting Tetragon event monitoring...${NC}"
        echo "Press Ctrl+C to stop monitoring"
        echo ""
        kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra getevents -o compact
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac