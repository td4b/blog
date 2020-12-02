---
layout: post
title: Intro to Kubernettes.
date: 2018-09-15
---
# Kubernettes Pt 1.

**Pre-reqs.**

1) Make sure to set up a static IP.
2) Disable VM Swap space.

```bash
swapoff -a
```
!! Comment out swap space !!
```bash
nano /etc/fstab
```

**Installation on Master & Slave.**

*Use Ansible to Automate the Dependency & Configuration process.*
https://github.com/kubernetes-incubator/kubespray

Single node to test.

```bash
declare -a IPS=(192.168.1.216)
CONFIG_FILE=inventory/mycluster/hosts.ini python3 contrib/inventory_builder/inventory.py ${IPS[@]}
```
Playbook execution (This will just install the master node, use extra verbosity to troubleshoot errors!).
```bash
ansible-playbook -i inventory/mycluster/hosts.ini cluster.yml -b -vvv --private-key=~/.ssh/id_rsa --ask-sudo-pass
```

After the playbook execution is succesful we can try to access the dashboard by default @

https://192.168.1.217:6443/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/login

We need to login with the authenticated service account. Notice that we do not access the dashboard via ```kubectl proxy```

This is important, as enabling access via kubectl proxy to 0.0.0.0 would allow un-authenticated users to login to the dashboard and have elevated rights to the controller...

The Default service account with the appropriate RBAC needs to be enabled!

```bash
kubectl create serviceaccount my-dashboard-sa
```

```bash
kubectl create clusterrolebinding my-dashboard-sa \
   --clusterrole=cluster-admin \
   --serviceaccount=default:my-dashboard-sa
```

We need to retreive our Key to Login to the Dashboard.
```bash
tdub@node1:~$ kubectl get secret
NAME                          TYPE                                  DATA      AGE
default-token-5bjhz           kubernetes.io/service-account-token   3         4h
my-dashboard-sa-token-jjsrh   kubernetes.io/service-account-token   3         4h
tdub@node1:~$ kubectl describe secret my-dashboard-sa-token-jjsrh
Name:         my-dashboard-sa-token-jjsrh
Namespace:    default
Labels:       <none>
Annotations:  kubernetes.io/service-account.name=my-dashboard-sa
              kubernetes.io/service-account.uid=540f3bcc-b9ef-11e8-ba32-000c29fdbf52

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1090 bytes
namespace:  7 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6Im15LWRhc2hib2FyZC1zYS10b2tlbi1qanNyaCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJteS1kYXNoYm9hcmQtc2EiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiI1NDBmM2JjYy1iOWVmLTExZTgtYmEzMi0wMDBjMjlmZGJmNTIiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6ZGVmYXVsdDpteS1kYXNoYm9hcmQtc2EifQ.cQjLXLEN-paqzP6mMmA-UroZ3sKsGw-xYxn6yEJOuC9kLQ2XdHzlD8MOvEcCLDjgDxVbG-Ddj1J-argIjAaUXZYY6TVB88TfzMwFiE-Puj3MihiTbO1vGlSwXqr958bnTuC_omU6urSKWcTDa-72IFQxEETdrHMyajrzuUrIWNQtdoMczegIbmeHOuiKpxhmlFc61OxKl7tpdYrRlJDHOVeRkKD0do00M2hs06uduIoz_7qAInc_WaQMd7Sj-28n58Yjjw8fDyPF4sp5pEj9tcqrZxY32CxPfNR-fP2BA4iJ-KYKpJvZYCL6mmTKBVpktK4r6nFJVyS6FIfm3FEh3g
```

And were in!

![](/img/kuber1/Dashboard1.png)

Running Pods on Master node.

```bash
kubectl get pods -o wide --all-namespaces
```

We need to save our Master config data so we can reload after rebooting the system. (For simplicity since I am on ESXi I also just took a snapshot of the Master).
