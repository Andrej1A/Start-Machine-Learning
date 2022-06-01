# Start-Machine-Learning

Machine Learning plug-and-play script collection.

# Pre-Requirements

- Installed Python 3.8.13+
- Installed Ansible 2.11.6+
- Installed Terraform v1.2.0+


## Setup SSH keypair for your server instance and save it to the file `~/.ssh/aws_key`

```
ssh-keygen -t rsa -b 2048 -C "your.mail@address.com"
```

## Setup your cloud infrastructure on AWS

1. Install Terraform

2. (Optionally) Create a file `terraform.tfvars` for your variables or enter them in the prompt in step four and/or step five:
```
aws_access_key = ""
aws_secret_key = ""
aws_key_pair_name = "aws_key"
ssh_public_key = "<content-of-file:/Users/username/.ssh/aws_key.pub>"
ssh_private_key_file_path = "/Users/username/.ssh/aws_key"
```

3. Initialize this Terraform project
```
terraform init
```

4. Check what will happen to your infrastructure:
```
terraform plan
```

5. Apply your infrastructure setup:
```
terraform apply
```

## Start with Machine Learning on your new server instance

1. SSH into your new server instance with the following command. The additional parameter `-L 8888:localhost:8888` will forward the 8888 port to your local machine. We will use the port for Jupyter Notebook.

```
ssh -i ~/.ssh/aws_key ubuntu@<your_server_public_ip> -L 8888:localhost:8888
```

2. Start jupyter notebook
```
jupyter notebook
```

3. Open the link including the secret_token from the log output on your local machine:
> http://127.0.0.1:8888/?secret_token=


## Install Kubernetes on the new launched instance

We will use [Kubespray](https://github.com/kubernetes-sigs/kubespray) for the Kubernetes installation.

1. Init the submodules of Kubespray and checkout to a specific commit (2022-06-01 21:40) which we have used for our installation routine:
```
git submodule init
cd kubespray/
git checkout 1f65e6d3b5752f9a64d3038e45d705f272acae58
cd ../
```

2. Use the public-ip which was given to your GPU-Server through the elastic ip and use it in step 4 for your inventory file.

  The public-ip and private-ip which where given to your GPU-server, can be determined by the following command or can be found in your [AWS-console](https://eu-west-1.console.aws.amazon.com/ec2/v2/home?region=eu-west-1#Addresses:) and the created GPU-server instance.
```
terraform output gpu_server_global_ips
terraform output gpu_server_private_ips
```

3. Switch into the kubespray foler:
```
cd kubespray/
```

4. Follow the installation steps on [Kubespray#quick-start](https://github.com/kubernetes-sigs/kubespray#quick-start):

  The following commands should be executed inside the kubespray folder:

```ShellSession
# 1. Copy ``inventory/sample`` as ``inventory/mycluster``
cp -rfp inventory/sample inventory/mycluster

# Update Ansible inventory file with inventory builder
# Step 2.1) Replace the ips with your public ip / ips of your GPU-server here:
declare -a IPS=(10.10.1.3 10.10.1.4 10.10.1.5)

# Or Step 2.2) you can execute this automatic command
# declare -a IPS=($(terraform -chdir=../ output -json gpu_server_global_ips | jq -r '.[0]'))  
# Please check if your ip's where entered correctly with the command: `echo $IPS`

# Step 3.)
CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}

# Review and change parameters under ``inventory/mycluster/group_vars``
cat inventory/mycluster/group_vars/all/all.yml
cat inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
```

  Kubeflow (which we will install later) supports Kubernetes version up to v1.21, please set this Kubernetes version into the following file: `inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml`. Additionaly, set the `nvidia_accelerator_enabled` to true and uncomment the `nvidia_gpu_device_plugin_container`.

```
kube_version: v1.21.6

nvidia_accelerator_enabled: true

nvidia_gpu_device_plugin_container: "k8s.gcr.io/nvidia-gpu-device-plugin@sha256:0842734032018be107fa2490c98156992911e3e1f2a21e059ff0105b07dd8e9e"

```

5. Check your private ip which you will need in the next step:
```
terraform -chdir=../ output -json gpu_server_private_ips  | jq -r '.[0]'
```

6. Change the username to `ubuntu` inside the inventory file and add the private ip: `inventory/mycluster/hosts.yml`
```
all:
  hosts:
    node1:
      ansible_host: <PUBLIC_ip>
      ip: <PRIVATE_ip>
      access_ip: <PRIVATE_ip>  # IP for other hosts to use to connect to.
      ansible_user: ubuntu
...
```


7. Start the Ansible script to let Kubespray install Kubernetes on your GPU server.

Execute this command inside the kubespray folder.

```ShellSession
# Deploy Kubespray with Ansible Playbook - run the playbook as root
# The option `--become` is required, as for example writing SSL keys in /etc/,
# installing packages and interacting with various systemd daemons.
# Without --become the playbook will fail to run!
ansible-playbook -i inventory/mycluster/hosts.yaml  --become --become-user=root cluster.yml --key-file "~/.ssh/aws_key"
```

In case the script is not running, try it again.
When it continuous to fail, please create an issue and post us the error message with a description of your steps to reproduce the error.


8. After the Ansible script run successfully through the installation. You have to copy the `/etc/kubernetes/admin.conf` file to your home directory `$HOME/.kube/config`. The admin.conf file has sometimes additional characters in it.
After that you can check the Kubernetes version:
```
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl version
```
 > Client Version: version.Info{Major:"1", Minor:"21", GitVersion:"v1.21.6", GitCommit:"d921bc6d1810da51177fbd0ed61dc811c5228097", GitTreeState:"clean", BuildDate:"2021-10-27T17:50:34Z", GoVersion:"go1.16.9", Compiler:"gc", Platform:"linux/amd64"}

 > Server Version: version.Info{Major:"1", Minor:"21", GitVersion:"v1.21.6", GitCommit:"d921bc6d1810da51177fbd0ed61dc811c5228097", GitTreeState:"clean", BuildDate:"2021-10-27T17:44:26Z", GoVersion:"go1.16.9", Compiler:"gc", Platform:"linux/amd64"}

9. After running the following command you can check the status of your Kubernetes cluster (With one node for now).
```
kubectl get nodes
# Output:
# NAME    STATUS   ROLES                  AGE   VERSION
# node1   Ready    control-plane,master   22m   v1.21.6
```


## For later, when you don't need your infrastructure anymore
The following command will destroy all created resources:
```
terraform destroy
```

# Tasks

- [x] As a Machine-Learning-beginner, I would like to have a script which launches a **GPU-Instance on AWS with a Jupyter Notebook**, to have a sandbox for my first Machine Learning experiments.

- [x] As a Machine-Learning-practitionar, I would like to have a (production-ready) **Kubernetes running on a single server**, on which I can deploy my first Machine Learning models to use them for inference in my web/ api projects to make experiences with Machine Learning deployment process, MLOps and Kubernetes. (KubeSpray)

- [ ] As a Machine-Learning-practitionar, I would like to have a **KubeFlow environment** for my Machine-Learning projects, to have a simple, portable and scalable ecosystem for all Machine Learning steps (e.g. collecting data, building models, hyper parameter tuning, model serving, ...).

- [ ] As a Machine-Learning-practitionar, I would like to have a working **Kubernetes-cluster** and KubeFlow-environment **with multiple servers**, which can be added to the installation procedure (Terraform-script, KubeSpray-inventory), to scale my Machine Learning projects.


## Copyright

Copyright 2022 Andrej Albrecht

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
