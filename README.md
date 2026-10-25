# Ansible Lab: Deploy a Docker App on AWS

Terraform builds four Ubuntu servers on AWS. Ansible then installs Docker on three of them and deploys the **Boundless Builders** Next.js app from Docker Hub.

## Architecture

| Server      | Role                                  |
|-------------|---------------------------------------|
| `server[0]` | Ansible control node                  |
| `server[1]` | node1 (managed by Ansible)            |
| `server[2]` | node2 (managed by Ansible)            |
| `server[3]` | node3 (managed by Ansible)            |

- Cloud: AWS, region `us-east-1`
- OS: Ubuntu 22.04 LTS
- Image deployed: `bedeneche/builders:v1.0.0`
- App port: `3000` inside the container, published on port `80` of each node

## Project structure

```
.
|-- main.tf            # Key pair, security group, 4 EC2 instances, outputs
|-- variable.tf        # Input variables (region, instance type, allowed IP)
|-- inventory.ini      # Ansible inventory template (node1-3 private IPs)
|-- ansible.cfg        # Ansible settings
|-- docker.yaml        # Playbook: install Docker and run the container
|-- .gitignore
|-- README.md
`-- command.md
```

## Prerequisites

- An AWS account with credentials configured locally
- [Terraform](https://developer.hashicorp.com/terraform/install)
- An SSH key pair. The public key is read from `~/.ssh/ansible-lab.pub`:

  ```bash
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/ansible-lab
  ```

## Usage

### 1. Build the servers

```bash
terraform init
terraform plan  -var="my_ip_cidr=$(curl -s ifconfig.me)/32"
terraform apply -var="my_ip_cidr=$(curl -s ifconfig.me)/32"
terraform output public_ips
terraform output private_ips
```

`my_ip_cidr` limits SSH (port 22) and HTTP (port 80) to your current public IP. Your IP can change, so pass the flag each time you apply from a new network. There is no default; Terraform requires you to provide it.

### 2. Set up the control node

Before copying, edit `inventory.ini` and replace its three placeholders with `private_ips[1]`, `private_ips[2]`, and `private_ips[3]` from the Terraform output. `private_ips[0]` is the control node.

Copy your private key and the Ansible files to `server[0]`, then connect:

```bash
scp -i ~/.ssh/ansible-lab ~/.ssh/ansible-lab ubuntu@<control-node-public-ip>:/home/ubuntu/ansible-lab
scp -i ~/.ssh/ansible-lab inventory.ini ansible.cfg docker.yaml ubuntu@<control-node-public-ip>:/home/ubuntu/
ssh -i ~/.ssh/ansible-lab ubuntu@<control-node-public-ip>
```

Install Ansible on the control node (Ubuntu 22.04):

```bash
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
ansible-galaxy collection install community.docker
chmod 600 /home/ubuntu/ansible-lab
```

### 3. Deploy the app

```bash
ansible all -m ping                # expect "pong" from node1-3
ansible-playbook docker.yaml --syntax-check
ansible-playbook docker.yaml
```

### 4. Verify

```bash
ansible servers -b -m command -a "docker ps"
```

Open `http://<node-public-ip>` in a browser (use `http://`, not `https://`).

Running the playbook a second time should report mostly `ok` rather than `changed`.

## What the playbook does

1. Updates the apt cache
2. Installs `docker.io` and `python3-docker`
3. Starts and enables the Docker service
4. Adds the `ubuntu` user to the `docker` group
5. Pulls `bedeneche/builders:v1.0.0`
6. Runs the container `buildersapp` with port mapping `80:3000` and `restart_policy: always`
7. Checks that the app answers HTTP 200, retrying while it starts

To deploy another version, change `image_tag` in the `vars` section of `docker.yaml` and rerun.

## Security notes

- The security group allows SSH only from `my_ip_cidr`. Do not open port 22 to `0.0.0.0/0`.
- HTTP (port 80) is limited to `my_ip_cidr`, the same address allowed to SSH. To share the app publicly, change the HTTP rule in `main.tf` to `0.0.0.0/0` and revert it afterwards.
- Never commit private keys (`*.pem`, `ansible-lab`), `terraform.tfstate`, or `.tfvars` files. They are covered by `.gitignore`.
- If the Docker Hub repository is private, log in with an access token (`community.docker.docker_login`) rather than a password, and keep the token out of the repository.

## Troubleshooting

| Problem | Likely cause and fix |
|---------|----------------------|
| SSH times out | Your IP changed. Reapply with `-var="my_ip_cidr=$(curl -s ifconfig.me)/32"` |
| `Permission denied (publickey)` | Wrong key, or wrong permissions. Run `chmod 600` on the key |
| `ansible: command not found` | Ansible is not installed on the control node (see step 2) |
| Image pull denied | The Docker Hub repo is private, so add a `docker_login` task |
| `exec format error` in container logs | The image was built for ARM. Rebuild with `--platform linux/amd64` |

## Cleanup

Destroy the lab when you are done so AWS stops charging for the servers:

```bash
terraform destroy -var="my_ip_cidr=$(curl -s ifconfig.me)/32"
```
