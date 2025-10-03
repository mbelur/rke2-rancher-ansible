# RKE2 + Rancher HA Setup via Ansible

This project automates the setup of a high-availability RKE2 cluster along with Rancher on SLES, SLE-Micro,
leveraging containerized Ansible playbooks to streamline installation.
The initial implementation is designed to work with the default configuration options for both RKE2 and Rancher.


## Prerequisites

- Docker or Podman
- SSH key-based access to all target nodes
- Target hosts are SLES, SLE-Micro
- Proper DNS setup (e.g. `rancher.example.com`)
- Target hosts must fulfill prerequisites at https://docs.rke2.io/install/quickstart#prerequisites
- Target hosts with python 3.11+ version
- A valid registration key for the SUSE OS distribution, which can be obtained with your SUSE subscription.

## Components

- Ansible playbooks for:
  - RKE2 HA server installation
  - RKE2 agent node installation
  - Rancher HA Helm deployment
- Roles for idempotent configuration
- A Dockerfile to run the playbooks in a container

## Inventory Example

This is an example of inventory.ini file with 3 RKE2 Servers and 2 RKE2 Agents.
```bash
#inventory.ini.example
[rke2_servers]
rke2_server1 ansible_host=192.168.1.10
rke2_server2 ansible_host=192.168.1.11
rke2_server3 ansible_host=192.168.1.12

[rke2_agents]
rke2_agent1 ansible_host=192.168.1.20
rke2_agent2 ansible_host=192.168.1.21

[all:vars]
ansible_user=<SSH_USER>
```

This is an example of inventory.ini file with 1 RKE2 server.

```bash
#inventory.ini.onenode.example
[rke2_servers]
rke2_server1 ansible_host=192.168.1.10

[all:vars]
ansible_user=<SSH_USER>
```

This is an example of inventory.ini file with target host being the localhost.

```bash
##inventory.ini.local.example
[rke2_servers]
rke2_server1 ansible_host=localhost

[all:vars]
ansible_user=<SSH_USER>
```

## Notes

- Mount your SSH keys under `~/.ssh` to enable access to target nodes.
- The load balancer rke2.lb_address provided in the extra_vars.yml must route port 9345 and 443 to the RKE2 server nodes.

## Usage

### 1. Build the Docker Image from the source

```bash
docker build -t rke2-rancher-ansible-runner -f Dockerfile.local .
```

### 2. Create inventory.ini file 
```bash
cp inventory.ini.example inventory.ini
```
Update the ansible host and user entries in inventory.ini

### 3. Create extra_vars.yml 
```bash
cp extra_vars.yml.example extra_vars.yml
```
Configure entries in extra_vars.yml accordingly.

### 4. Run the stage1 playbook
This playbook at a high level checks that the target hosts are supported systems. Registers the
systems with the SCC if not already registered. Install packages and nvidia drivers.
The nvidia drivers are installed only when the servers have the NVIDIA GPU.
Finally the playbook *reboots* the target hosts.

Note: This playbook does not install the nvidia drivers when localhost is the target.

```bash
docker run --rm \
  -v ~/.ssh/id_rsa:/root/.ssh/id_rsa:ro \
  -v ./inventory.ini:/workspace/inventory.ini \
  -v ./extra_vars.yml:/workspace/extra_vars.yml \
  rke2-rancher-ansible-runner \
  ansible-playbook -i inventory.ini playbooks/stage1.yml -e "@extra_vars.yml"
```

If your target node is a *localhost*, using the host networking mode (--network host):

```bash
docker run --rm \
  --network host \
  -v ~/.ssh/id_rsa:/root/.ssh/id_rsa:ro \
  -v ./inventory.ini:/workspace/inventory.ini \
  -v ./extra_vars.yml:/workspace/extra_vars.yml \
  rke2-rancher-ansible-runner \
  ansible-playbook -i inventory.ini playbooks/stage1.yml -e "@extra_vars.yml"
```

### 5. Run the stage2 playbook

This playbook will run a post-stage1 check and installs rke2 servers, rke2 agents, rancher and gpu-operator.

```bash
docker run --rm \
  -v ~/.ssh/id_rsa:/root/.ssh/id_rsa:ro \
  -v ./inventory.ini:/workspace/inventory.ini \
  -v ./extra_vars.yml:/workspace/extra_vars.yml \
  rke2-rancher-ansible-runner \
  ansible-playbook -i inventory.ini playbooks/stage2.yml -e "@extra_vars.yml"
```

If your target node is a localhost, using the host networking mode (--network host):

```bash
docker run --rm \
    --network host \
  -v ~/.ssh/id_rsa:/root/.ssh/id_rsa:ro \
  -v ./inventory.ini:/workspace/inventory.ini \
  -v ./extra_vars.yml:/workspace/extra_vars.yml \
  rke2-rancher-ansible-runner \
  ansible-playbook -i inventory.ini playbooks/stage2.yml -e "@extra_vars.yml"
```

### 6. Troubleshooting

#### 6a. Failed to connect to the host via ssh

confirm key permissions (~/.ssh 700, private key 600).

verify public key is in ~/.ssh/authorized_keys of the remote user.

run ssh -v user@host to debug connection/auth issues.
