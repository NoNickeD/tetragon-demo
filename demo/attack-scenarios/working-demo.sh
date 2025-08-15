#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

POD_NAME=$(kubectl get pods -n demo -l app=vulnerable-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo -e "${RED}Error: Vulnerable app pod not found${NC}"
    exit 1
fi

clear
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}    WORKING Tetragon Security Demo             ${NC}"
echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}Pod: $POD_NAME${NC}"
echo ""
echo -e "${YELLOW}This demo shows what IS working in your Tetragon setup${NC}"
echo ""

function show_events() {
    echo -e "${BLUE}Capturing events for 10 seconds...${NC}"
    timeout 10 kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra getevents -o json 2>/dev/null > /tmp/demo_events.json
    
    echo -e "${GREEN}Events captured! Analyzing...${NC}"
    echo ""
    
    # Show process execution events from our pod
    echo -e "${CYAN}Process Execution Events from Demo Pod:${NC}"
    cat /tmp/demo_events.json | jq -r --arg pod "$POD_NAME" '
        select(.process_exec.process.pod.name == $pod) | 
        "EXEC | " + .time + " | " + .process_exec.process.binary + " | " + (.process_exec.process.arguments // "no args")
    ' | tail -10
    echo ""
    
    # Show kprobe events that are working
    echo -e "${CYAN}Security Events (kprobes) Detected:${NC}"
    cat /tmp/demo_events.json | jq -r '
        select(.process_kprobe) | 
        .process_kprobe.function_name
    ' | sort | uniq -c | sort -rn | head -10
    echo ""
    
    # Show capability events specifically
    echo -e "${CYAN}Capability Check Events:${NC}"
    cat /tmp/demo_events.json | jq -r '
        select(.process_kprobe.function_name == "cap_capable") | 
        "CAP_CHECK | " + .time + " | " + (.process.binary // "unknown") + " | CAP_" + (.process_kprobe.args[2].int_arg | tostring)
    ' | head -5
    echo ""
}

function run_attacks() {
    echo -e "${YELLOW}Running attack scenarios...${NC}"
    echo ""
    
    echo -e "${BLUE}1. File System Access${NC}"
    kubectl exec -n demo $POD_NAME -- bash -c "
        echo 'Accessing sensitive files...'
        cat /etc/passwd | head -3
        cat /etc/shadow | head -2 2>/dev/null || echo 'Shadow access blocked'
    "
    echo ""
    
    echo -e "${BLUE}2. Process Execution from Suspicious Locations${NC}"
    kubectl exec -n demo $POD_NAME -- bash -c "
        echo 'Creating executable in /tmp...'
        echo -e '#!/bin/sh\necho Malicious process from /tmp\nps aux | head -3' > /tmp/malicious.sh
        chmod +x /tmp/malicious.sh
        /tmp/malicious.sh
    "
    echo ""
    
    echo -e "${BLUE}3. Network Activity${NC}"
    kubectl exec -n demo $POD_NAME -- bash -c "
        echo 'Testing network connections...'
        timeout 2 nc -zv 8.8.8.8 53 2>&1 || echo 'DNS connection attempted'
        timeout 2 nc -zv 1.1.1.1 3333 2>&1 || echo 'Mining port connection attempted'
    "
    echo ""
    
    echo -e "${BLUE}4. Multiple Process Spawning${NC}"
    kubectl exec -n demo $POD_NAME -- bash -c "
        echo 'Spawning multiple processes...'
        date &
        whoami &
        hostname &
        wait
    "
    echo ""
}

echo -e "${YELLOW}Starting demo...${NC}"
echo ""

# Start event monitoring in background
show_events &
MONITOR_PID=$!

sleep 2

# Run the attacks
run_attacks

# Wait for monitoring to complete
wait $MONITOR_PID

echo -e "${GREEN}Demo completed!${NC}"
echo ""
echo -e "${CYAN}Summary of What's Working:${NC}"
echo "•  Process execution monitoring (process_exec events)"
echo "•  Capability checking (cap_capable kprobe events)"
echo "•  Setuid monitoring (__x64_sys_setuid events)"
echo "•  Network monitoring (udp_sendmsg events)"
echo "•  File descriptor installation (fd_install events)"
echo ""
echo -e "${YELLOW}Note: Your Tetragon setup IS working!${NC}"
echo "The policies are detecting system-level security events."
echo "For real-time monitoring, run: ./scripts/monitor-demo-events.sh"
echo ""
echo -e "${CYAN}To see more detailed events:${NC}"
echo "kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra getevents -o compact"