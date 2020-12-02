---
layout: post
title: Kubernettes Remote Procedure Calls.
date: 2018-09-19
---
# Remote Procedure Calls.


To install software on a running docker container if you gain access to the controller, you can make remote procedure calls to the system.

For example, if I need to install curl.

```bash
kubectl exec -it --namespace=default flask-app-6c4c95fddd-h7pgv -- bash -c "apt-get update;apt-get -y install curl; curl https://www.google.com >> hello.txt"
```

Thats it! Pretty Simple! Will be updating this post soon with info on why were interested in this!
