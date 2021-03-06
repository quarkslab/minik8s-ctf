#!/bin/bash

KUBECTL="minikube kubectl --"
PARENT_PATH=$(dirname ${BASH_SOURCE[0]})

# make sure that the default service account was already created
echo "Will perform some periodic checks to make sure the cluster is ready before deploying challenges..."
n=0; until ((n >= 60)); do
    $KUBECTL -n default get serviceaccount default -o name >/dev/null 2>&1 && break;
    echo -n "."
    n=$((n + 1));
    sleep 1;
done; ((n < 60))
echo
echo Applying challenges YAMLs to the CTF cluster.

if [ "$(echo $CHALLENGE | awk '{print tolower($0)}')" == "qits" ]; then
    echo "You selected the QITS challenge."
    $KUBECTL apply -f $PARENT_PATH/../scripts.yaml -f $PARENT_PATH/../challenge-qits.yaml
else
    $KUBECTL apply -f $PARENT_PATH/../scripts.yaml -f $PARENT_PATH/../challenge1.yaml -f $PARENT_PATH/../challenge2.yaml -f $PARENT_PATH/../challenge3.yaml
fi

