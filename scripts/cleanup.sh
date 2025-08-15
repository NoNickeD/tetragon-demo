#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Tetragon Demo Cleanup Script${NC}"
echo "============================="
echo ""

echo -e "${RED}WARNING: This will destroy all demo resources!${NC}"
read -p "Are you sure? (yes/no) " -r
if [[ ! $REPLY == "yes" ]]; then
    echo "Aborted."
    exit 1
fi

echo -e "${YELLOW}Removing Kubernetes resources...${NC}"

kubectl delete -f demo/legitimate-app/app.yaml --ignore-not-found
kubectl delete -f demo/attack-scenarios/vulnerable-app.yaml --ignore-not-found
kubectl delete -f tetragon/policies/ --ignore-not-found
kubectl delete -f tetragon/argocd/applications/ --ignore-not-found

echo -e "${YELLOW}Uninstalling ArgoCD...${NC}"
helm uninstall argocd -n argocd --wait || true
kubectl delete namespace argocd --ignore-not-found

echo -e "${YELLOW}Uninstalling monitoring stack...${NC}"
kubectl delete namespace monitoring --ignore-not-found

echo -e "${YELLOW}Uninstalling Tetragon...${NC}"
kubectl delete namespace tetragon --ignore-not-found

echo -e "${YELLOW}Destroying Azure infrastructure...${NC}"
cd infrastructure
tofu destroy -auto-approve
cd ..

echo -e "${GREEN}Cleanup complete!${NC}"