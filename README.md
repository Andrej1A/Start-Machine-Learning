# Start-Machine-Learning

Machine Learning plug-and-play script collection for the setup and installation of:
- AWS EC2-Server instance(s) including GPU(s) with [Terraform](https://www.terraform.io)
- [Kubernetes](https://kubernetes.io) cluster with [Kubespray](https://kubespray.io/#/)
- [Kubeflow](https://www.kubeflow.org) on top of that cluster with [kubeflow/manifests](https://github.com/kubeflow/manifests)


## Pre-Requirements

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

6. Apply again to attach your volume to your new created instance and to connect the elastic ip to it.
```
terraform apply # yes, again.
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
> http://127.0.0.1:8888/?token=d4fe41442----long-id----27c13aa39


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

4. Install requirements on deployment host
```
pip3 install -r requirements.txt
```

5. Follow the installation steps on [Kubespray#quick-start](https://github.com/kubernetes-sigs/kubespray#quick-start):

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


6. Configurations for your Kubernetes Cluster
Kubeflow (which we will install later) supports Kubernetes version up to v1.21, please set this Kubernetes version into the following file: `inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml`. Additionaly, set the `nvidia_accelerator_enabled` to true and uncomment the `nvidia_gpu_device_plugin_container`.


File `inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml` contains:
```
kube_version: v1.21.6

nvidia_accelerator_enabled: true
nvidia_gpu_flavor: tesla
nvidia_gpu_device_plugin_container: "k8s.gcr.io/nvidia-gpu-device-plugin@sha256:0842734032018be107fa2490c98156992911e3e1f2a21e059ff0105b07dd8e9e"

persistent_volumes_enabled: true
```

File `inventory/mycluster/group_vars/all/all.yml` contains:
```
docker_storage_options: -s overlay2
```

File `inventory/mycluster/group_vars/k8s_cluster/addons.yml` contains:
```
# Helm deployment
helm_enabled: true

# Rancher Local Path Provisioner
local_path_provisioner_enabled: true
local_path_provisioner_namespace: "local-path-storage"
local_path_provisioner_storage_class: "local-path"
local_path_provisioner_reclaim_policy: Delete
local_path_provisioner_claim_root: /opt/local-path-provisioner/
local_path_provisioner_debug: false
local_path_provisioner_image_repo: "rancher/local-path-provisioner"
local_path_provisioner_image_tag: "v0.0.21"
local_path_provisioner_helper_image_repo: "busybox"
local_path_provisioner_helper_image_tag: "latest"

# Nginx ingress controller deployment
ingress_nginx_enabled: true
ingress_publish_status_address: ""
ingress_nginx_namespace: "ingress-nginx"
ingress_nginx_insecure_port: 80
ingress_nginx_secure_port: 443
```

7. Check your private ip which you will need in the next step:
```
terraform -chdir=../ output -json gpu_server_private_ips  | jq -r '.[0]'
```

8. Change the username to `ubuntu` inside the inventory file and add the private ip: `inventory/mycluster/hosts.yml`
```
all:
  hosts:
    node1:
      ansible_host: <PUBLIC_ip>
      ip: <PRIVATE_ip>
      access_ip: <PRIVATE_ip>  # IP for other hosts to use to connect to.
      ansible_user: ubuntu # <--- add this line
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


9. After the Ansible script run successfully through the installation. You have to copy the `/etc/kubernetes/admin.conf` file to your home directory `$HOME/.kube/config`. The admin.conf file has sometimes additional characters in it.
After that you can check the Kubernetes version:
```
mkdir $HOME/.kube/
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl version
```
 > Client Version: version.Info{Major:"1", Minor:"21", GitVersion:"v1.21.6", GitCommit:"d921bc6d1810da51177fbd0ed61dc811c5228097", GitTreeState:"clean", BuildDate:"2021-10-27T17:50:34Z", GoVersion:"go1.16.9", Compiler:"gc", Platform:"linux/amd64"}

 > Server Version: version.Info{Major:"1", Minor:"21", GitVersion:"v1.21.6", GitCommit:"d921bc6d1810da51177fbd0ed61dc811c5228097", GitTreeState:"clean", BuildDate:"2021-10-27T17:44:26Z", GoVersion:"go1.16.9", Compiler:"gc", Platform:"linux/amd64"}

10. After running the following command you can check the status of your Kubernetes cluster (with one node for now).

- Check your nodes:
```
kubectl get nodes
# Output:
# NAME    STATUS   ROLES                  AGE   VERSION
# node1   Ready    control-plane,master   22m   v1.21.6
```

- Check your storage class, persistent volume and persistent volume claims:
```
kubectl get sc
kubectl get pv --all-namespaces
kubectl get pvc --all-namespaces
```

- Check the nodes for details. Especially, that your node has no [Taints](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). When you create a server instance with a too small volume size, Kubernetes will mark your node with the Taint `node.kubernetes.io/disk-pressure:NoSchedule`, which will prevent the startup of some pods on that node.
Check the nodes for details:
```
kubectl describe nodes
kubectl describe nodes node1 | grep taint
```


## Install Kubeflow on top of your Kubernetes

After you have checked your Kubernetes cluster, you can start the installation of Kubeflow.

1. Login to your server, download and setup kustomize:
```
# got back to the root folder
cd ../

# Print the global ip of your server
terraform output -json gpu_server_global_ips  | jq -r '.[0]'

# SSH into your server
ssh -i ~/.ssh/aws_key ubuntu@<public_ip> -L 8888:localhost:8888    

# Download kustomize on your server
wget https://github.com/kubernetes-sigs/kustomize/releases/download/v3.2.0/kustomize_3.2.0_linux_amd64

# Copy kustomize to your user bin folder
sudo cp kustomize_3.2.0_linux_amd64 /usr/bin/kustomize

# Make kustomize executable
sudo chmod u+x /usr/bin/kustomize

# Change the ownership of kustomize to the current user and group
sudo chown $(id -u):$(id -g) /usr/bin/kustomize
```


2. Check your kustomize version:
```
kustomize version
```
> Version: {KustomizeVersion:3.2.0 GitCommit:a3103f1e62ddb5b696daa3fd359bb6f2e8333b49 BuildDate:2019-09-18T16:26:36Z GoOs:linux GoArch:amd64}


3. Download Kubeflow and checkout the release version `v1.5.0`:
```
git clone https://github.com/kubeflow/manifests

cd manifests/

git fetch --all --tags

git checkout tags/v1.5.0 -b v1.5.0-branch

# The default email (`user@example.com`) and password (`12341234`) is set in Kubeflow.
# Please change your user credentials **before** you start the Kubeflow installation:
python3 -c 'from passlib.hash import bcrypt; import getpass; print(bcrypt.using(rounds=12, ident="2y").hash(getpass.getpass()))'

# The previous command will return your password hash, which you will copy into the `config-map.yaml`-file:
# <password_hash>
```


Set your email and password_hash into the file `common/dex/base/config-map.yaml`:
```
staticPasswords:
- email: your@mail.com
  hash: <password_hash>
```


And into the file `common/user-namespace/base/params.env`:
```
user=your@mail.com
profile-name=kubeflow-start-machine-learning-env
```


4. Start your Kubeflow installation:
```
while ! kustomize build example | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 10; done
```


5. After the previous command run successfully through, you can watch the starting process of all the Kubeflow pods with the following command and wait until they all have been started.
```
kubectl get pods --all-namespaces # one time
watch kubectl get pods --all-namespaces # or watch
```


## Access your Kubeflow Dashboard
After all of your pods were started successfully, you can make a port-forward and login to your Kubeflow dashboard:
```
kubectl port-forward svc/istio-ingressgateway -n istio-system 8888:80
```

Visit the following url on your client host. The port was already routed through your ssh login (`-L ...` parameter) to your client.
```
http://localhost:8888/
```

If you like to login to your server directly, you can make a port-forward to listen to all ip addresses.
```
kubectl port-forward --address 0.0.0.0 svc/istio-ingressgateway -n istio-system 8888:80
```

After that you can open the following link on your client:
```
http://<public_ip>:8888/
```


## Configure Ingress for secure HTTPS connections to your Kubeflow

When you would like to make your Kubeflow available through a domain name, follow the next steps.

1. First of all you should create an DNS A-Record on your nameserver which points to your public ip of your server.


2. Create a file on your server `ingress_www.yourdomain.com.yaml`:
```
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: ingress-kubeflow-http
spec:
  rules:
  - host: www.yourdomain.com
    http:
      paths:
      - path: /
        backend:
          serviceName: istio-ingressgateway
          servicePort: 80
```

3. Apply this file:
```
kubectl apply -f ingress_www.yourdomain.com.yaml --namespace istio-system
```

4. Now you should be able to see your Kubeflow dashboard on your browser through your domain name.
  > https://your-public-ip
  > https://www.yourdomain.com/


# Make your GPUs available inside the Kubernetes cluster including Kubeflow

The NVIDIA GPU-Operator will make your NVIDIA GPU's available inside your Kubernetes cluster.

Install the GPU-Operator with the following command:
```
helm install --wait --generate-name \
     -n gpu-operator --create-namespace \
     nvidia/gpu-operator \
     --set driver.enabled=false \
     --set nfd.enabled=true \
     --set mig.strategy=mixed \
     --set toolkit.enabled=true \
     --set migManager.enabled=false
```

After the GPU-Operator was installed and all his deployed pods were started successfully.
You can describe your nodes with the following command. You will see information of how many and which GPUs are available inside your cluster.
```
kubectl describe nodes | grep -B 6 gpu

#OUTPUT:
# ...
#Capacity:
#  cpu:                16
#  ephemeral-storage:  254059440Ki
#  hugepages-1Gi:      0
#  hugepages-2Mi:      0
#  memory:             125702272Ki
#  nvidia.com/gpu:     1  <---------- GPUs are here
# ...
```


This can be a complicated part for beginners. If you would like to know more about how GPUs are made available inside your Kubernetes cluster and which components make it happen and how they work together, check the following resources:
Useful resources:
* [How to easily use GPUs on Kubernetes](https://info.nvidia.com/how-to-use-gpus-on-kubernetes-webinar.html)  
* [NVIDIA GPU-Operator - GitHub Repository](https://github.com/NVIDIA/gpu-operator)
* [NVIDIA GPU-Operator - Getting-Started](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/getting-started.html)


## If something goes wrong
In case something goes wrong during the Kubeflow installation, you can always **reset your Kubernetes cluster** with the following command, on your local machine. This will delete every resources and data inside the Kubernetes cluster:
```
ansible-playbook -i inventory/mycluster/hosts.yaml  --become --become-user=root reset.yml --key-file "~/.ssh/aws_key"  
```

In case you make any changes to your Kubesray configuration files. You can let Kubespray **update your Kubernetes cluster** with the configuration changes by running the following command again:
```
ansible-playbook -i inventory/mycluster/hosts.yaml  --become --become-user=root cluster.yml --key-file "~/.ssh/aws_key"  
```


## For later, when you don't need your infrastructure anymore
The following command will destroy all created infrastructure resources and data on AWS:
```
terraform destroy
```


## Tasks

- [x] As a Machine-Learning-beginner, I would like to have a script which launches a **GPU-Instance on AWS with a Jupyter Notebook**, to have a sandbox for my first Machine Learning experiments.

- [x] As a Machine-Learning-practitionar, I would like to have a (production-ready) **Kubernetes running on a single server**, on which I can deploy my first Machine Learning models to use them for inference in my web/ api projects to make experiences with Machine Learning deployment process, MLOps and Kubernetes. (KubeSpray)

- [x] As a Machine-Learning-practitionar, I would like to have a **KubeFlow environment** for my Machine-Learning projects, to have a simple, portable and scalable ecosystem for all Machine Learning steps (e.g. collecting data, building models, hyper parameter tuning, model serving, ...).

- [x] As a Machine-Learning-practitioner, I would like to open my Kubeflow Dashboard through a **secure HTTPS connection** directly on the ip-address of my server.

- [ ] As a Machine-Learning-practitionar, I would like to have a working **Kubernetes-cluster** and KubeFlow-environment **with multiple servers**, which can be added to the installation procedure (Terraform-script, KubeSpray-inventory), to scale my Machine Learning projects.


## More Information
- [Kubernetes](https://kubernetes.io) - [repo](https://github.com/kubernetes/kubernetes)
- [Kubernetes concepts](https://kubernetes.io/docs/concepts/)
- [Kubernetes Taint-and-toleration](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Kubeflow](https://www.kubeflow.org) - [repo](https://github.com/kubeflow/)
- [AWS](https://aws.amazon.com)
- [Terraform](https://www.terraform.io) - [repo](https://github.com/hashicorp/terraform)
- [Kubeflow/manifests](https://github.com/kubeflow/manifests)


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
