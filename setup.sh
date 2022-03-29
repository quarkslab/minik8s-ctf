#!/bin/bash

if [ $(uname -m) != "x86_64" ]; then
    echo "Sorry, only works on x86_64 for now..."
    exit 1
fi

case $(uname) in
    "Linux")
        echo "Starting setup for Linux x86."
        ./setup_linux_x86.sh
        ;;
    "Darwin")
        echo "Starting setup for macOS x86."
        ./setup_macos_x86.sh
        ;;
    *)
        echo "Sorry, only supports macOS and Linux x86..."
        ;;
esac


