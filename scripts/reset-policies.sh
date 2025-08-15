#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Tetragon Policy Reset - Safe Recovery${NC}"
echo "====================================="
echo ""

echo -e "${YELLOW}Step 1: Remove all existing policies${NC}"
echo "This will restore cluster stability..."

# Delete all TracingPolicies
kubectl delete tracingpolicies --all -n tetragon --ignore-not-found=true

echo "Waiting 30 seconds for policies to be fully removed..."
sleep 30

echo -e "${GREEN}All policies removed!${NC}"
echo ""

echo -e "${YELLOW}Step 2: Check cluster health${NC}"
unhealthy_pods=$(kubectl get pods -A --field-selector=status.phase!=Running --field-selector=status.phase!=Succeeded 2>/dev/null | wc -l)

if [ "$unhealthy_pods" -gt 1 ]; then
    echo -e "${YELLOW}Warning: $((unhealthy_pods-1)) pods are still unhealthy${NC}"
    echo "This may take a few more minutes to recover..."
    kubectl get pods -A --field-selector=status.phase!=Running --field-selector=status.phase!=Succeeded
else
    echo -e "${GREEN}Cluster appears healthy!${NC}"
fi
echo ""

read -p "Apply minimal demo policies? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Step 3: Apply minimal, safe policies${NC}"
    
    kubectl apply -f tetragon/policies-minimal/
    
    echo ""
    echo -e "${GREEN}Minimal policies applied!${NC}"
    echo ""
    echo "These policies are:"
    echo "  - Detection only (no blocking)"
    echo "  - Extremely targeted"
    echo "  - Safe for cluster operations"
    echo ""
    echo "Test with: ./demo/attack-scenarios/test-minimal.sh"
else
    echo "Skipping minimal policies."
fi

echo ""
echo -e "${GREEN}Recovery complete!${NC}"
echo ""
echo "Current policies:"
kubectl get tracingpolicies -n tetragon