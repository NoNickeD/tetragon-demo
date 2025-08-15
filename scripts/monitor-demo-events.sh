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

echo -e "${CYAN}==================================================${NC}"
echo -e "${CYAN}    Demo-Specific Tetragon Event Monitor          ${NC}"
echo -e "${CYAN}==================================================${NC}"
echo -e "${GREEN}Monitoring pod: $POD_NAME${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

echo -e "${BLUE}Watching for events from demo namespace...${NC}"
echo ""

kubectl exec -n tetragon ds/tetragon -c tetragon -- tetra getevents -o json 2>/dev/null | \
jq -r --unbuffered --arg pod "$POD_NAME" '
    select(.process_exec.process.pod.name == $pod or 
           .process_exit.process.pod.name == $pod or
           .process_kprobe.process.pod.name == $pod) |
    
    if .process_exec then
        "EXEC | " + (.time // "unknown") + " | " + 
        (.process_exec.process.binary // "unknown") + " | " + 
        (.process_exec.process.arguments // "no args")
    elif .process_exit then
        "EXIT | " + (.time // "unknown") + " | " + 
        (.process_exit.process.binary // "unknown") + " | " + 
        "code: " + (.process_exit.code | tostring)
    elif .process_kprobe then
        "KPROBE | " + (.time // "unknown") + " | " + 
        (.process_kprobe.function_name // "unknown") + " | " + 
        (.process_kprobe.process.binary // "unknown") + " | " +
        (if .process_kprobe.args[0].file_arg then 
            "file: " + .process_kprobe.args[0].file_arg.path
         elif .process_kprobe.args[0].string_arg then
            "arg: " + .process_kprobe.args[0].string_arg
         else
            "args: " + (.process_kprobe.args | tostring)
         end)
    else
        "OTHER | " + (.time // "unknown") + " | " + (. | tostring)
    end
'