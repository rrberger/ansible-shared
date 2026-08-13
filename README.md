# 🚀 Ansible AWX & Automation Controller Homelab Environment

This repository provides a self-contained, enterprise-grade Ansible playground designed to mirror the capabilities of **Red Hat Ansible Automation Platform (AAP)** and **AWX (Automation Controller)** in a local homelab.

---

## 🛠️ HOW TO SET UP & INTEGRATE THIS ENVIRONMENT IN K3S

Follow these step-by-step instructions to spin up the environment and deploy AWX into your K3s cluster.

### 1. Prerequisite Initialization (One-Time Setup)
Before launching the containers, create the external Docker network subnet and shared K3s volume:

```bash
# 1. Create the dedicated container network bridge
docker network create --subnet=172.25.0.0/24 playnet

# 2. Create the external volume to share K3s kubeconfig between containers
docker volume create k3s-shared
```

---

### 2. Launch the Environment Stack
Spin up the target SSH nodes, control node, and K3s AWX bootstrap orchestrator:

```bash
docker compose up -d --build
```

#### What happens during launch:
* **K3s Integration**: The `bootstrap` container waits for K3s to generate `kubeconfig.yaml` in the shared volume.
* **AWX Operator Installation**: Applies Kustomize manifests to deploy AWX Operator `v2.19.1` into namespace `awx`.
* **AWX Custom Resource**: Applies `awx-instance.yaml` to deploy Postgres, Redis, AWX Web, and AWX Task pods inside K3s.
* **SSH Target Nodes**: Starts 4 isolated SSH target containers (`target-ubuntu-1`, `target-ubuntu-2`, `target-debian-1`, `target-rocky-1`) with auto-generated SSH key pairs.

---

### 3. Monitor K3s Deployment & Fetch Admin Password
The AWX Operator rolls out the Kubernetes deployment automatically. Monitor progress by tailing the bootstrap container logs:

```bash
docker compose logs -f bootstrap
```

Depending on host performance, the initial deployment takes **3 to 7 minutes**. Once ready, the logs will print out the completion banner with your dynamic admin password:

```text
=========================================================================
                         AWX SETUP COMPLETE!                             
=========================================================================
 Access URL: http://localhost:8080
 Username:   admin
 Password:   <DYNAMICALLY_GENERATED_PASSWORD_HERE>
=========================================================================
```

---

### 4. Access the AWX Web UI
Navigate to `http://<YOUR_HOST_IP>:8080` in your web browser:
* **Username**: `admin`
* **Password**: *(Copied from the bootstrap log banner above)*

---

### 5. Verify K3s Cluster & AWX Pods (Optional CLI Check)
You can inspect the AWX pods running inside K3s directly from your host or control node:

```bash
# Exec into control container
docker exec -it ansible-ansible-control-1 bash

# Check AWX pods in K3s
kubectl get pods -n awx
```

*Expected Pod Output:*
```text
NAME                                               READY   STATUS    RESTARTS   AGE
awx-demo-postgres-15-0                             1/1     Running   0          5m
awx-operator-controller-manager-698d48b554-kszhz   2/2     Running   0          5m
awx-demo-web-cdf478b67-rnplc                       3/3     Running   0          4m
awx-demo-task-5cf94b5cd8-49ctd                     4/4     Running   0          4m
```

---

### 6. Set Up Git-Sourced Projects & Inventories (Enterprise AAP Best Practice)

In enterprise **Red Hat Ansible Automation Platform (AAP)** and AWX, production playbooks and inventory files are **never** manually uploaded or edited on the server. Instead, everything is managed in **Git repositories** and automatically synced by AWX.

Follow these 4 sub-steps to replicate an enterprise Git-driven AAP workflow:

#### Sub-step 6.1: Push Your Code to Git
Push this repository (or your own playbook repository) to GitHub, GitLab, Gitea, or your enterprise Git server:

```bash
git add .
git commit -m "Initial Ansible playbook repository"
git push origin main
```

#### Sub-step 6.2: Create Source Control Credentials & Git Project in AWX

##### 1. Create a Source Control Credential (for Private Repos or HTTPS/SSH Auth):
1. In AWX UI, go to **Resources** $\rightarrow$ **Credentials** $\rightarrow$ Click **Add**.
2. **Name**: `GitHub Source Control Credential`
3. **Credential Type**: Select **`Source Control`**.
4. **Authentication Method**:
   * **HTTPS Token**: Enter your **Username** and **Password / Token** (e.g. GitHub Personal Access Token `ghp_...`).
   * **SSH Key**: Paste your SSH Private Key into the **SSH Private Key** field.
5. Click **Save**.

##### 2. Create and Attach Credential to the AWX Project:
1. In AWX UI, go to **Resources** $\rightarrow$ **Projects** $\rightarrow$ Click **Add**.
2. **Name**: `Ansible Homelab Playbooks`
3. **Execution Environment**: Select `AWX EE (latest)` (or your custom EE).
4. **Source Control Type**: Select **`Git`**.
5. **Source Control URL**: Enter your Git repository URL (e.g. `https://github.com/<YOUR_USERNAME>/ansible-shared.git`).
6. **Source Control Credential**: Select `GitHub Source Control Credential` *(required for private repos)*.
7. **Options**: Check **`Update Revision on Launch`** *(ensures AWX pulls the latest Git commit before every job)*.
8. Click **Save**. AWX will authenticate via your credential and trigger an automatic Git sync.


#### Sub-step 6.3: Create a Git-Sourced Inventory
1. In AWX UI, go to **Resources** $\rightarrow$ **Inventories** $\rightarrow$ Click **Add** $\rightarrow$ **Add inventory**.
   * **Name**: `Git Managed Inventory`
   * Click **Save**.
2. Click the **Sources** tab $\rightarrow$ Click **Add**.
   * **Name**: `Git Repository Inventory Source`
   * **Source**: Select **`Sourced from a Project`**.
   * **Project**: Select `Ansible Homelab Playbooks`.
   * **Inventory File**: Select `playground/inventory.ini` (or type your inventory relative path).
   * **Verbosity**: `1 (Normal)`
   * **Options**: Check **`Overwrite`** and **`Update on Launch`**.
3. Click **Save** $\rightarrow$ Click **Sync**.
4. Click the **Hosts** tab—AWX has automatically populated `target-ubuntu-1`, `target-ubuntu-2`, `target-debian-1`, and `target-rocky-1` from Git!

#### Sub-step 6.4: Create & Launch a Job Template
1. In AWX UI, go to **Resources** $\rightarrow$ **Templates** $\rightarrow$ Click **Add** $\rightarrow$ **Add job template**.
   * **Name**: `01 - Check Disk Health`
   * **Job Type**: `Run`
   * **Inventory**: Select `Git Managed Inventory`.
   * **Project**: Select `Ansible Homelab Playbooks`.
   * **Execution Environment**: `AWX EE (latest)`
   * **Playbook**: Select `playbooks/01-check-disk.yml`.
   * **Credentials**: Select your Machine SSH Credential.
2. Click **Save** $\rightarrow$ Click **Launch**!

AWX will pull the latest commit from Git, load the inventory, and execute `01-check-disk.yml` against all target containers!


---

## 🌟 Environment Architecture

```text
+-----------------------------------------------------------------------------------+
|                                 YOUR HOST NODE                                    |
|                                                                                   |
|  +-----------------------+     +-------------------+     +---------------------+  |
|  |       K3s CLUSTER     |     |  ANSIBLE CONTROL  |     |   TARGET CONTAINERS |  |
|  |                       |     |     CONTAINER     |     |                     |  |
|  |  [AWX Operator]       |     |  - Ansible CLI    |     |  - Ubuntu 24.04 (#1)|  |
|  |  [AWX Web UI: 8080]   | <-> |  - navigator      | <-> |  - Ubuntu 24.04 (#2)|  |
|  |  [AWX Task Engine]    |     |  - builder        |     |  - Debian 12    (#1)|  |
|  |  [PostgreSQL DB]      |     |  - kubectl        |     |  - Rocky Linux 9(#1)|  |
|  +-----------------------+     +-------------------+     +---------------------+  |
+-----------------------------------------------------------------------------------+
```

### Key Features:
1. **Ansible AWX Web UI**: Deployed via official Kubernetes **AWX Operator** inside K3s (`http://<YOUR_HOST_IP>:8080`).
2. **Dedicated Control Container (`ansible-control`)**: Pre-loaded with Ansible CLI, `ansible-navigator` (TUI runner), `ansible-builder`, `ansible-lint`, and `kubectl`.
3. **Multi-OS Target Containers**: 4 isolated SSH target nodes (Ubuntu 24.04, Debian 12, Rocky Linux 9) pre-configured for passwordless `sudo` execution.
4. **Dynamic Key Provisioning**: SSH key pairs are generated dynamically at startup inside a shared Docker volume—no hardcoded passwords or private keys.
5. **Custom Execution Environment (EE) Pipeline**: Complete configuration to compile Python dependencies (`hvac`, `requests`) and Galaxy collections (`community.hashi_vault`) into custom container images.
6. **HashiCorp Vault Integration**: Pre-built playbooks demonstrating Vault authentication via both **Direct REST API** and native **`community.hashi_vault` Collection Task Modules** with AppRole auth.

---

## 📋 System Prerequisites

> [!IMPORTANT]
> **System Requirements:**
> - **OS**: Linux (Ubuntu, Debian, Fedora, Linux Mint) or macOS.
> - **CPU / RAM**: Minimum **4 CPU Cores** and **8 GB RAM** free.
> - **Software**: Docker & Docker Compose (V2) installed.
> - **Ports**: Host port **8080** must be available.

---

## 📁 Repository Structure

```text
ansible-shared/
├── docker-compose.yml              # Service definition stack (targets, control, bootstrap)
├── Dockerfile.control              # Control node container definition
├── awx-instance.yaml               # AWX Custom Resource manifest for AWX Operator
├── requirements.txt                # Python package dependencies (hvac, requests)
├── collections/
│   └── requirements.yml            # Ansible Galaxy collections (community.hashi_vault, etc.)
├── execution_environments/
│   └── execution-environment.yml # ansible-builder v3 specification for custom EEs
├── targets/                        # Target Node Dockerfiles (Ubuntu, Debian, Rocky)
├── entrypoints/                    # Automated bootstrapping and SSH key setup scripts
├── vars/
│   ├── secrets.yml.example         # Template secret lookup manifest
│   └── secrets.yml                 # Dynamic secret lookup dictionary
├── playbooks/                      # Practice Playbooks & Vault Integrations
│   ├── 01-check-disk.yml           # Disk usage reporting
│   ├── 02-patch-mint.yml           # System package updating (UPDATE/UPGRADE modes)
│   ├── 03-verify-borgmatic.yml     # Backup service diagnostic checks
│   ├── 04-test-secret-vars.yml     # Vault REST API token lookup
│   ├── 05-test-secret-vars-uri.yml # Vault REST API AppRole login exchange
│   ├── 06-test-secret-vars-vault-module.yml # community.hashi_vault Task Module
│   └── 07-test-secret-loop.yml     # Dynamic YAML manifest secret loop
└── playground/                     # Interactive CLI Sandbox
    ├── ansible.cfg                 # Playground Ansible configuration
    ├── inventory.ini               # Target container inventory
    ├── ansible-navigator.yml       # TUI runner configuration
    ├── demo-playbook.yml           # Diagnostic test playbook
    └── scripts/
        └── awx_helper.sh           # Interactive CLI & API management script
```

---

## 💻 Using the Ansible Control Node CLI

You can execute playbooks directly from the command line inside the Ansible Control container.

### 1. Connect to the Control Node
```bash
docker exec -it ansible-ansible-control-1 bash
```

Inside this container, you will land in `/playground` (which maps directly to `./playground` on your host).

### 2. Run Playbooks via `ansible-navigator` (TUI Mode)
Because you are already inside the Ansible control container, disable nested EE execution with `--ee false`:

```bash
# Run interactive TUI mode
ansible-navigator run /playground/demo-playbook.yml --ee false

# Run in stdout mode
ansible-navigator run /playground/demo-playbook.yml --ee false --mode stdout
```

---

## 🦭 Building & Importing Custom Execution Environments (EE)

When running playbooks that require third-party Python libraries (like **`hvac`** for HashiCorp Vault) or C-extensions, you can build a custom Execution Environment container image and load it into AWX/K3s.

### 1. The EE Definition (`execution_environments/execution-environment.yml`)
```yaml
version: 3
images:
  base_image:
    name: quay.io/ansible/awx-ee:latest
dependencies:
  ansible_core:
    package_pip: ansible-core>=2.15.0
  ansible_runner:
    package_pip: ansible-runner>=2.3.0
  python:
    - hvac>=1.0.0
    - requests
  galaxy:
    collections:
      - name: community.hashi_vault
additional_build_steps:
  append_base:
    - RUN dnf install -y gcc gcc-c++ python3-devel libffi-devel libxml2-devel openssl-devel
  prepend_galaxy:
    - RUN dnf install -y gcc gcc-c++ python3-devel libffi-devel libxml2-devel openssl-devel
```

### 2. Build the Image directly into Docker
```bash
sudo ansible-builder build --container-runtime docker --tag custom-awx-ee:1.0
```

### 3. Import the Image into K3s Containerd (`k8s.io` Namespace)
AWX runs inside Kubernetes pods managed by K3s. Import the built image into K3s's `k8s.io` containerd store to prevent `ErrImageNeverPull` errors:

```bash
# Export and import into K3s containerd
docker save custom-awx-ee:1.0 | docker exec -i k3s ctr -n k8s.io images import -

# Ensure tag alias exists
docker exec k3s ctr -n k8s.io images tag docker.io/library/custom-awx-ee:1.0 custom-awx-ee:1.0
```

### 4. Register in AWX UI
1. Go to **AWX UI** $\rightarrow$ **Administration** $\rightarrow$ **Execution Environments** $\rightarrow$ Click **Add**.
2. **Name**: `Custom EE (hvac)`
3. **Image**: `custom-awx-ee:1.0`
4. **Pull**: Select **`Never`** (or `IfNotPresent`).
5. Save and attach to your Job Templates!

---

## 🔐 HashiCorp Vault Integration & Playbooks

This repository includes 4 playbooks demonstrating enterprise HashiCorp Vault patterns:

| Playbook | Method | Dependencies | Description |
| :--- | :--- | :--- | :--- |
| [04-test-secret-vars.yml](playbooks/04-test-secret-vars.yml) | Native REST API | None | Uses `ansible.builtin.uri` with static Vault token. |
| [05-test-secret-vars-uri.yml](playbooks/05-test-secret-vars-uri.yml) | Native REST API | None | Performs dynamic AppRole login (`role_id` + `secret_id`) to exchange for client token. |
| [06-test-secret-vars-vault-module.yml](playbooks/06-test-secret-vars-vault-module.yml) | Task Module | `custom-awx-ee:1.0` | Uses `community.hashi_vault.vault_kv2_get` with AppRole auth and `delegate_to: localhost`. |
| [07-test-secret-loop.yml](playbooks/07-test-secret-loop.yml) | Dynamic Manifest Loop | `custom-awx-ee:1.0` | Iterates over `vars/secrets.yml` to batch-fetch multiple keys dynamically from Vault. |


### Vault Policy Setup (`ansible-policy`):
Ensure your HashiCorp Vault instance has the following policy configured for your AppRole:

```hcl
path "kv/data/*" {
  capabilities = ["read", "list"]
}
path "kv/metadata/*" {
  capabilities = ["read", "list"]
}
path "kv/*" {
  capabilities = ["read", "list"]
}
```

---

## 🛠️ Interactive AWX Helper Script (`awx_helper.sh`)

A CLI helper script is included in `playground/scripts/awx_helper.sh` to interact with AWX via API:

```bash
# Set your environment variables
export AWX_HOST="http://localhost:8080"
export AWX_TOKEN="<YOUR_AWX_BEARER_TOKEN>"

# Run interactive menu
./playground/scripts/awx_helper.sh

# Or direct CLI shortcuts
./playground/scripts/awx_helper.sh launch <TEMPLATE_ID>
./playground/scripts/awx_helper.sh logs <JOB_ID>
./playground/scripts/awx_helper.sh list templates
```

---

## 🧹 Clean Up / Reset

To spin down the containers:
```bash
docker compose down
```

To clean up all data (including the AWX PostgreSQL database volume and SSH key volume) to start fresh:
```bash
docker compose down -v
```
