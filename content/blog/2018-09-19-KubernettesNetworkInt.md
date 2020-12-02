---
layout: post
title: Kubernettes pt. 2
date: 2018-09-19
---
# Kubernettes Simple Web app.

After brining the cluster up I wanted to experiment with capturing some traffic on the Container level.

Logging into my node, I deployed and configured my first simple container app (Flask Python Web App).

In order to determine the attached network interface I needed to find the POD docker ID.

From the controller ->

```bash
 kubectl get pod flask-app-6c4c95fddd-nl95g -o json
```
Then I parsed the Json and found the containerID.

```json
"containerStatuses": [
            {
                "containerID": "docker://d2a207c49e6dd118685fed88d20d0c3f34af50dfa70c60191486aeb504700d52",
                "image": "tdub17/flask-tutorial:latest",
                "imageID": "docker-pullable://tdub17/flask-tutorial@sha256:3fa8278c0255bc9c6acbffd268ed5c500293493a695f74480d32ed3ef800bf9f",
                "lastState": {},
                "name": "flask-app",
                "ready": true,
                "restartCount": 0,
                "state": {
                    "running": {
                        "startedAt": "2018-09-17T04:03:53Z"
                    }
                }
            }
        ],
```

From there I SSH'ed into my Node that has the running container and ran the following:

```bash
sudo docker exec d2a207c49e6dd118685fed88d20d0c3f34af50dfa70c60191486aeb504700d52 /bin/bash -c 'cat /sys/class/net/eth0/iflink'
```
Output ->
```
14
```
This returned the ID and then after running the following command I was able to easily determine the attached Network Interface.

```bash
ip link |grep ^14:
```
Output ->
```bash
14: calie1239ea5782@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default
```

Now Running the TCPdump command we can inspect the packets flowing into the docker.

```bash
tcpdump -i calie1239ea5782
```
