# **Ansible Managed Nodes Provisioner**

Terraform module-based provisioning of four AWS EC2 instances in a custom VPC to serve as Ansible managed nodes — web servers and database servers — ready to receive configuration from a control node.

---

## Project at a Glance

| | |
|---|---|
| **Tools Used** | Terraform, AWS EC2, AWS VPC, AWS SSM Parameter Store |
| **Platform** | Amazon Web Services (us-east-1) |
| **Languages** | HCL (Terraform) |
| **What It Does** | Provisions a VPC, subnet, internet gateway, security group, and four EC2 instances to serve as Ansible managed nodes |

---

## The Problem This Project Solves

In a real Ansible automation environment, the managed nodes — the servers that Ansible configures — must be provisioned before any playbooks can run. Doing this manually introduces inconsistency: different instance types, missing tags, mismatched security groups, or incorrect key pairs all prevent Ansible from reaching the nodes. When you need four identically configured servers across distinct roles, the manual approach simply does not scale.

This project solves that by using Terraform's module system to provision a complete, isolated network environment and a uniform fleet of EC2 instances in a single `terraform apply`. The VPC module creates the network layer: a /16 VPC, a public subnet, an internet gateway, a route table, and a security group with the ports Ansible and the target applications require (SSH on 22, HTTP on 80 and 8080, and a custom port on 1233). The compute module provisions four identical `t3.micro` Amazon Linux 2 instances with public IPs and the correct SSH key pair, tagged sequentially (`host_node_0` through `host_node_3`).

The public IPs of all four nodes are emitted as a Terraform output, making it straightforward to populate an Ansible inventory file. This separation of infrastructure provisioning from software configuration is a deliberate architectural choice — it keeps the Terraform code infrastructure-focused and leaves the Ansible playbooks free to handle application-layer concerns.

---

## Architecture

```
                    terraform apply
                          |
          +---------------+---------------+
          |                               |
          v                               v
  +----------------+           +--------------------+
  | module "vpc"   |           | module "compute"   |
  |                |           |                    |
  | - aws_vpc      |           | - aws_key_pair     |
  |   10.0.0.0/16  | --------> | - aws_instance x4  |
  | - aws_subnet   |  subnets  |   t3.micro          |
  |   10.0.1.0/24  | --------> |   Amazon Linux 2    |
  | - aws_igw      | sg id     |   public IPs        |
  | - aws_route_   |           |   host_node_0..3   |
  |   table        |           |                    |
  | - aws_sg       |           +--------------------+
  |   ports:       |
  |   22, 80,      |
  |   8080, 1233   |
  +----------------+

  Output: public IPs of all 4 managed nodes
```

---

## Repository Structure

```
ansible-managed-nodes-provisioner/
├── main.tf                     # Root module: wires vpc and compute modules together
├── variables.tf                # Region variable
├── outputs.tf                  # Exports managed node public IPs
├── modules/
│   ├── vpc/
│   │   ├── main.tf             # VPC, subnet, IGW, route table, security group
│   │   ├── variables.tf        # Region variable for VPC module
│   │   └── outputs.tf          # Exports subnet ID, security group ID, subnet CIDR
│   └── compute/
│       ├── main.tf             # EC2 instances (count=4), key pair, AMI lookup
│       ├── variables.tf        # SSH key path, security group, subnet inputs
│       └── outputs.tf          # Exports list of all managed node public IPs
└── .gitignore
```

---

## How It Works

**Module design.** The root `main.tf` calls two child modules. The `vpc` module is called first and exports three values: the public subnet ID, the security group ID, and the subnet CIDR block. These are passed as inputs into the `compute` module, ensuring the EC2 instances land in the correct network.

**AMI resolution.** The compute module uses an AWS SSM Parameter Store data source to resolve the latest Amazon Linux 2 HVM AMI at plan time, eliminating hardcoded AMI IDs and making the configuration region-portable.

**Key pair.** The compute module reads a local public key file (`~/.ssh/lab_ansible_key.pub` by default) and registers it as an AWS key pair named `ansible`. Every EC2 instance uses this key, so the Ansible control node can reach all managed nodes using the same private key.

**Four identical instances.** A `count = 4` argument on the `aws_instance` resource creates four machines from a single resource block. Each is tagged `host_node_0` through `host_node_3` using `count.index`. Two are intended for the `[webservers]` inventory group and two for `[databases]`, as configured in the control node's inventory.

**Security group.** The VPC module's security group opens ports 22 (SSH), 80 (HTTP), 8080 (alternative HTTP), and 1233 (custom application port), with unrestricted outbound access. This covers both the Ansible SSH communication and the application services that the control node's playbooks will install.

---

## Walkthrough

```bash
# 1. Initialize Terraform and download provider plugins
terraform init

# 2. Preview the execution plan — two modules, one VPC, four EC2 instances
terraform plan

# 3. Provision the entire environment
#    Override the SSH key path if yours differs from the default
terraform apply \
  -var="region=us-east-1" \
  -auto-approve

# 4. Retrieve all four managed node IPs
terraform output Managed-Nodes

# Example output:
# Managed-Nodes = [
#   "54.210.x.x",
#   "3.82.x.x",
#   "34.201.x.x",
#   "44.204.x.x",
# ]

# 5. Populate the Ansible inventory on the control node
# Add the IPs to host.ini under [webservers] and [databases]

# 6. Verify Ansible connectivity from the control node
ansible all -i host.ini -m ping

# 7. Tear down all resources
terraform destroy -auto-approve
```

---

## How to Reproduce

**Prerequisites**

- Terraform >= 1.5.0
- AWS credentials configured (`aws configure` or environment variables)
- SSH key pair — default expected at `~/.ssh/lab_ansible_key` (private) and `~/.ssh/lab_ansible_key.pub` (public)

```bash
# Clone the repository
git clone https://github.com/Seyifunmi0604/ansible-managed-nodes-provisioner.git
cd ansible-managed-nodes-provisioner

# Initialize modules and provider
terraform init

# Apply
terraform apply -auto-approve

# Collect IPs for your Ansible inventory
terraform output Managed-Nodes
```

After provisioning, the control node (from `ansible-control-node-provisioner`) can reach all four managed nodes via SSH using the `ansible` key pair. Run the playbooks from `ansible-control-node-setup` to complete the stack configuration.

---

## Related Projects

- `ansible-sandbox-ec2` — Minimal single-node Ansible sandbox
- `ansible-control-node-provisioner` — Provisions the Ansible control node
- `ansible-managed-nodes-provisioner` — **This project** — Provisions the managed node fleet
- `ansible-control-node-setup` — Playbooks that configure the nodes this project creates
- `mariadb-ansible-setup` — Self-contained single-node MariaDB provisioning

---

*Oluwaseyi Michael Falode · Cybersecurity & Cloud Security Engineer · Toronto, ON*
