# Start-Machine-Learning

Machine Learning plug-and-play script collection.

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
aws_key_pair_name = ""
ssh_public_key = ""
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
ssh -i ~/.ssh/aws_key ubuntu@<your_server_public_ip>
```

2. Start jupyter notebook
```
jupyter notebook
```

3. Open the link including the secret_token from the log output on your local machine:
> http://127.0.0.1:8888/?secret_token=



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
