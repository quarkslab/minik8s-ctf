# Minik8s CTF

This mini CTF is just a selection of what have I seen during some Kubernetes
CTFs I participated in. These flags are designed to highlight the use of the
[`kdigger`](https://github.com/quarkslab/kdigger) tool and are beginner-friendly. 
For now, it's only composed of 3 challenges.

This challenge could potentially run on any Kubernetes infrastructure but is
currently designed especially for the minikube virtual machine environment. You
might spoil yourself by running it on a different setup than recommended,
because you will need to look at the YAML and scripts files. You don't need any
extra cloud account to run the challenge, it runs on Linux x86 or macOS x86
hosts directly by creating a virtual machine for isolation. If you don't trust
the installation and you don't want to read all the challenges content, rent a
dedicated server to run the VM, a VM with nested virtualization enabled, or
wait for a cloud version.

**WARNING 1**: Do not start the challenge running Kubernetes in Docker (with
kind for example), it's running in privileged containers a.k.a. root processes
on the host and it does not provide a level of isolation between your machine
and the containers that will run as privileged on the Kubernetes cluster.
Nothing dramatic will happen but some CTF files will be written on your host
machine and it's not a safe way to experiment.

**WARNING 2**: Do not browse the YAML files since they contain the CTF
deployments, thus the structure behind each flag and even the flag themselves.

## Installation

Some basics requirements:
* Linux x86 or macOS x86
* 2 CPUs or more
* 2GB of free memory
* 10GB of free disk space
* Internet connection

And more importantly, a virtual machine driver installed like
[Virtualbox](https://minikube.sigs.k8s.io/docs/drivers/virtualbox/) or
[KVM](https://minikube.sigs.k8s.io/docs/drivers/kvm2/), the latter only for
Linux of course. Please follow the links for the installation instruction
for your distribution if you don't already installed one.

Then you can just use the setup script that will propose to install minikube if
not already present, setup the cluster and provision the challenges. You can
read the whole bash script without spoiling some challenge information.
```bash
$ ./setup.sh
```

To go further, you can also deploy a specific challenge that I used at [Quarks
In The Shell](https://content.quarkslab.com/event-quarks-in-the-shell),
Quarkslab's annual conference, by selecting via this environment variable.
```bash
$ CHALLENGE=qits ./setup.sh
```

## Usage

To start the challenges, just use the `start.sh` script with the step number
you want to try, you can also read the script without getting too much
information. You will then be given context information (or not?) for the
challenge.
```bash
$ ./start.sh <step number>
```

For example, if you finished step 1 and want to do step 2, just type `$
./start.sh 2`.

You have to find flags with the structure `quarksflag{...}`, with `...` being
some random text.

## Solutions

You can find the solutions [right here](./solutions.md).

## Uninstall

To remove everything, you can use, the `--purge` flag will delete the
`.minikube` folder from your user directory with caches and other
stuff:
```bash
minikube delete --purge=true
```
You can then remove minikube if you prefer!

## License

[Apache License 2.0](./LICENSE)
