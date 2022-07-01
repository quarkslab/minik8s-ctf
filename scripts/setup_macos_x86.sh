#!/bin/bash

if [[ -z "${KUBERNETES_VERSION}" ]] || [[ -z "${MINIKUBE_URL}" ]]; then
    echo "Please define KUBERNETES_VERSION and MINIKUBE_URL env vars"
    exit 1
fi

VBOX_OK=0

PARENT_PATH=$(dirname ${BASH_SOURCE[0]})

# check if virtualbox is installed
if [ -c "/dev/vboxdrv" ]; then
    VBOX_OK=1
fi

if [ $VBOX_OK -eq 0 ]; then
    echo Please install Virtualbox 
else
    # check if minikube is installed and propose installation
    minikube version >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        read -p "Minikube seems not to be installed, would you like to install it? (yY): " -n 1 -r
        # just to print a newline
	    echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # check if curl is already installed
            curl --version >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo Need to install curl to fetch the minikube binary, answer yes if you want to continue.
                sudo apt-get update && sudo apt-get install curl
            fi
            # fetch and install minikube
            curl -L $MINIKUBE_URL -o /tmp/minikube
            sudo install /tmp/minikube /usr/local/bin/minikube
            rm /tmp/minikube
	    else
		    exit 1
        fi
    fi

    # start the minikube Kubernetes cluster with virtualbox
    MINIKUBE_CMD="minikube start --disk-size=4096m --memory=2048m --kubernetes-version=$KUBERNETES_VERSION"
    echo $MINIKUBE_CMD
    if [ $VBOX_OK -eq 1 ]; then
        $MINIKUBE_CMD --driver=virtualbox
        if [ $? -ne 0 ]; then
            exit $?
        fi
        $PARENT_PATH/deploy_challenges.sh
	    exit 0
    fi
fi
