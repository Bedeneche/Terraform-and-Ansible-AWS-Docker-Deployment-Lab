# Commands Used in the Lab

A cleaned, ordered list of the commands from the lab. Replace the `<...>` placeholders with your own values.

## On the laptop (Git Bash)

### 1. Build the servers with Terraform

```bash
cd ~/Desktop/ansible-class
terraform init
terraform plan  -var="my_ip_cidr=$(curl -s ifconfig.me)/32"
terraform apply -var="my_ip_cidr=$(curl -s ifconfig.me)/32"
terraform output public_ips
terraform output private_ips
```

Before continuing, edit `inventory.ini`: replace its placeholders with `private_ips[1]`, `private_ips[2]`, and `private_ips[3]`. `private_ips[0]` is the control node.

### 2. Copy the key and files to the control node

```bash
chmod 600 ~/.ssh/ansible-lab
scp -i ~/.ssh/ansible-lab ~/.ssh/ansible-lab ubuntu@<control-node-public-ip>:/home/ubuntu/ansible-lab
scp -i ~/.ssh/ansible-lab inventory.ini ansible.cfg docker.yaml ubuntu@<control-node-public-ip>:/home/ubuntu/
```

### 3. Connect to the control node

```bash
ssh -i ~/.ssh/ansible-lab ubuntu@<control-node-public-ip>
```

## On the control node (Ubuntu 22.04)

### 4. Prepare the key and check the system

```bash
whoami
pwd
ls
chmod 600 /home/ubuntu/ansible-lab
lsb_release -rs
```

### 5. Install Ansible and the Docker collection

```bash
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
ansible-galaxy collection install community.docker
ansible --version
```

### 6. Check the files and the connection to the nodes

```bash
cat inventory.ini
cat ansible.cfg
ansible all -m ping
```

### 7. Deploy the app

```bash
ansible-playbook docker.yaml --syntax-check
ansible-playbook docker.yaml
```

### 8. Verify the containers

```bash
ansible servers -b -m command -a "docker ps"
ansible servers -b -m command -a "docker logs buildersapp"
```

## Clean up

On the laptop:

```bash
terraform destroy -var="my_ip_cidr=$(curl -s ifconfig.me)/32"
```
