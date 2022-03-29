#!/bin/bash

USAGE="Please provide the challenge number you want to start with (1, 2 or 3).\nUsage: ./start.sh <number>, ex: ./start 1"
EXTRA_ARGS=""

KUBECTL="minikube kubectl --"

# if no args provided
if [ -z "$1" ]; then
    echo -e $USAGE
    exit 1
fi

# if args different than 1, 2 or 3
if [ $1 -lt 1 ] || [ $1 -gt 3 ]; then
    echo -e $USAGE
    exit 2
fi

minikube version >/dev/null 2>&1                                                 
if [ $? -ne 0 ]; then                                                            
    echo "Minikube seems not to be installed, please make sure that setup was successful"
    exit 3
fi

CHALL_POD_NAME=$($KUBECTL get pods -o name -l app=rce-step$1)
if [ -z $CHALL_POD_NAME ]; then
    echo "Pod not found, please make sure that setup was successful"
    exit 4
fi
if [ $1 -eq "3" ]; then
    EXTRA_ARGS="-c toolbox"
fi

echo "Waiting for the pod to be ready, please wait..."
echo "(It might take some time to download the container images)"
$KUBECTL wait --for=condition=ready $CHALL_POD_NAME >/dev/null
echo "Starting challenge $1, you should see a prompt! Good luck!"
echo
$KUBECTL exec -it $CHALL_POD_NAME $EXTRA_ARGS -- /bin/bash -l 
