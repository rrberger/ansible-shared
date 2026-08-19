# Ansible & AWX Playground Environment

This playground environment is designed to have a home lab experience that is similar to utilizing **Red Hat Ansible Automation Platform (AAP)**. It provides a local, self-contained lab on my Mini-PC (Linux Mint) home lab machine. I am using Ansible to maintain my home lab, although those Playbooks are *not* public. Hopefully this helps you get started. Enjoy!

1. **Ansible AWX** (the upstream open-source project for AAP's Automation Controller) deployed via the official Kubernetes **AWX Operator** inside a lightweight Dockerized K3s instance.
2. **Event-Driven Ansible (EDA) Controller** (the upstream open-source project for AAP's Event-Driven Ansible) deployed via the official Kubernetes **EDA Server Operator** for real-time webhook automation.
3. **An Ansible Control Node** preloaded with Ansible CLI, `ansible-navigator` (the modern container-based play runner), `ansible-builder`, `ansible-lint`, and `kubectl`.
4. **Two Managed Target Containers (`target1`, `target2`)** configured with SSH, Python, and passwordless sudo privileges for running test playbooks.
5. **Dynamic Key Provisioning** where SSH keys are created automatically on startup—no hardcoded passwords or keys are used.
6. **AI Coding Assistance & Zen of Ansible Skills** pre-configured for Antigravity ([`.agents/skills/ansible-authoring/SKILL.md`](.agents/skills/ansible-authoring/SKILL.md)) and Claude ([`.claude/SKILLS.md`](.claude/SKILLS.md)) enforcing FQCN, strict idempotency, `async:` timeouts, and Red Hat repository directory standards.

---

## 🤖 AI Coding Assistance & Skills (`ansible-authoring`)

This repository includes pre-built AI pair programming skills configured for **Google Antigravity** and **Claude** following [The Zen of Ansible](https://www.redhat.com/en/blog/the-zen-of-ansible) and [Red Hat CoP Automation Good Practices](https://redhat-cop.github.io/automation-good-practices/):

* **Antigravity Skill Location**: [`.agents/skills/ansible-authoring/SKILL.md`](.agents/skills/ansible-authoring/SKILL.md)
* **Claude Skill / System Memory**: [`.claude/SKILLS.md`](.claude/SKILLS.md) & [`.claude/skills/ansible-authoring/SKILL.md`](.claude/skills/ansible-authoring/SKILL.md)

### Key Rules Enforced by the Skill:
1. **Mandatory FQCN**: All tasks require Fully Qualified Collection Names (e.g. `ansible.builtin.copy`, `community.hashi_vault.vault_kv2_get`).
2. **Strict Idempotency**: All `command` and `shell` tasks require `changed_when:` guards.
3. **Async Timeouts**: All `command` and `shell` tasks require `async:` timeouts so commands never hang indefinitely.
4. **Forbidden External Remote Scripts**: Scripts (`.sh`, `.ps1`) must exist inside the git project repository or be written inline—execution from external NFS/SMB file shares is forbidden.
5. **Red Hat Standard Directory Layout**: Enforces official AAP project directory structure (`group_vars/`, `host_vars/`, `roles/`, `playbooks/`, `rulebooks/`).
6. **Red Hat CoP Standards**: Enforces role variable namespacing (`role_name_var`), YAML quoting, and single responsibility roles.

---

## Deployed Container Stack Reference

This playground consists of host-level Docker Compose services and Kubernetes pod workloads running inside K3s. Below is the complete inventory of containers powering AWX and Event-Driven Ansible (EDA):

### 1. Host-Level Docker Compose Stack
| Container Service | Base Image / Dockerfile | Purpose |
| :--- | :--- | :--- |
| `bootstrap` | `alpine/k8s:1.27.4` | Automated orchestrator container that deploys AWX & EDA Operators into K3s. |
| `ansible-control` | `Dockerfile.control` (Debian 12) | Local development sandbox preloaded with Ansible CLI, `ansible-navigator`, `ansible-builder`, and `kubectl`. |
| `target-ubuntu-1` & `2` | `targets/Dockerfile.target-ubuntu24.04` | Ubuntu 24.04 SSH managed target containers. |
| `target-debian-1` | `targets/Dockerfile.target-debian12` | Debian 12 SSH managed target container. |
| `target-rocky-1` | `targets/Dockerfile.target-rockylinux9` | Rocky Linux 9 SSH managed target container. |

### 2. AWX Controller Workloads (Namespace: `awx`)
| Container / Pod | Container Image | Purpose |
| :--- | :--- | :--- |
| `awx-operator` | `quay.io/ansible/awx-operator:2.19.1` | Kubernetes operator managing AWX Custom Resource lifecycle. |
| `awx-demo-web` | `quay.io/ansible/awx-web:24.6.1` | AWX Web UI and REST API service (Port `8080`). |
| `awx-demo-task` | `quay.io/ansible/awx-task:24.6.1` | AWX task engine, job dispatcher, and receptor controller. |
| `awx-demo-postgres-15-0` | `postgres:15` | Dedicated PostgreSQL database for AWX configuration & job history. |
| `awx-ee` | `quay.io/ansible/awx-ee:24.6.1` | Default Execution Environment worker container launched per job. |

### 3. EDA Controller Workloads (Namespace: `eda-server-operator-system`)
| Container / Pod | Container Image | Purpose |
| :--- | :--- | :--- |
| `eda-server-operator` | `quay.io/ansible/eda-server-operator:1.0.2` | Kubernetes operator managing EDA Custom Resource lifecycle. |
| `eda-demo-api` | `quay.io/ansible/eda-server-api:1.0.2` | EDA Controller REST API service & database manager. |
| `eda-demo-ui` | `quay.io/ansible/eda-server-ui:1.0.2` | Event-Driven Ansible Web UI (Port `8083`). |
| `eda-demo-daphne` | `quay.io/ansible/eda-server-daphne:1.0.2` | Daphne ASGI WebSocket gateway for `ansible-rulebook` communication. |
| `eda-demo-postgres-15-0` | `postgres:15` | Dedicated PostgreSQL database for EDA event streams & activations. |
| `activation-job-1-XX` | `quay.io/ansible/ansible-rulebook:latest` | Active rule engine pod executing `ansible-rulebook` and matching events. |

---

## Prerequisites

> [!IMPORTANT]
> **System Resources:** Modern AWX and its underlying dependencies (PostgreSQL, Redis, Web UI, Task Engine, Receptor, and the AWX Operator) run inside a nested K3s cluster. 
> - Your Ubuntu host machine must have at least **4 CPU cores** and **8 GB of RAM** free.
> - Docker and Docker Compose (V2) must be installed.
> - Ensure host port **8080** is not currently in use.

---

## File Structure

- [docker-compose.yml](./docker-compose.yml) - Service definition stack.
- [Dockerfile.control](./Dockerfile.control) - Environment for the control node.
- `targets/` - Subdirectory containing the SSH target Node Dockerfiles:
  - [Dockerfile.target-ubuntu24.04](./targets/Dockerfile.target-ubuntu24.04) (Ubuntu 24.04 base)
  - [Dockerfile.target-debian12](./targets/Dockerfile.target-debian12) (Debian 12 base)
  - [Dockerfile.target-rockylinux9](./targets/Dockerfile.target-rockylinux9) (Rocky Linux 9 base)
- [awx-instance.yaml](./awx-instance.yaml) - The AWX Custom Resource manifest.
- [eda-instance.yaml](./eda-instance.yaml) - The EDA Custom Resource manifest.
- `docs/` - Architecture and workflow documentation:
  - [eda_awx_workflow.md](./docs/eda_awx_workflow.md) - **Complete Event-Driven Ansible (EDA) & AWX Integration Architecture & Workflow Guide**.
- `rulebooks/` - Event-Driven Ansible rulebook definitions:
  - [hello_world_rulebook.yml](./rulebooks/hello_world_rulebook.yml) - Production Event Stream rulebook triggering AWX Job Templates on webhook events.
- `entrypoints/` - Initialization scripts for SSH keys, target authorization, and Kubernetes bootstrapping.
- `playground/` - Playbook directory (shared folder mapped into the control container).
  - [ansible.cfg](./playground/ansible.cfg) - Playground Ansible config.
  - [inventory.ini](./playground/inventory.ini) - Playground target inventory.
  - [ansible-navigator.yml](./playground/ansible-navigator.yml) - Settings for the container runner.
  - [demo-playbook.yml](./playground/demo-playbook.yml) - Diagnostic test playbook.

---

## Quick Start Guide

### 1. Initialize External Docker Resources (One-time)
Run this command once on your Mint box / mini-lab host to create the shared network subnet and external volume:
```bash
docker network create --subnet=172.25.0.0/24 playnet
docker volume create k3s-shared
```

### 2. Launch the Standalone K3s Cluster
First, launch the independent K3s stack on your mini-lab:
```bash
cd ~/Documents/k3s-cluster
docker compose up -d
```

### 3. Launch the Ansible AWX Stack
Once K3s is running, run the following command in this `ansible` directory on your mini-lab host to launch AWX bootstrap and client nodes:
```bash
docker compose up -d --build
```

This starts:
- The target SSH containers (`target-ubuntu-1`, `target-ubuntu-2`, etc.).
- The `ansible-control` shell node.
- The `bootstrap` orchestrator container.

### 4. Monitor AWX Operator & Fetch the Admin Password
AWX will automatically install in the background inside the K3s container. You can monitor the progress by tailing the logs of the `bootstrap` service:
```bash
docker compose logs -f bootstrap
```

Depending on the speed of your home lab, the first setup can take **5 to 10 minutes** to pull the images and roll out the Postgres, Redis, and AWX pods. Once ready, the logs will print out the dynamic admin password:

```text
=========================================================================
                  AWX & EDA HOMELAB SETUP COMPLETE!                      
=========================================================================
 AWX Controller: http://localhost:8080
   Username:     admin
   Password:     <DYNAMICALLY_GENERATED_PASSWORD_HERE>

 EDA Controller: http://localhost:8083
   Username:     admin
   Password:     <DYNAMICALLY_GENERATED_PASSWORD_HERE>
=========================================================================
```

### 5. Log In to AWX & EDA
- **AWX Web UI:** `http://<your-host-ip>:8080`
- **EDA Web UI:** `http://<your-host-ip>:8083`
- **Username:** `admin`
- **Password:** (Copy the password printed in the bootstrap logs above)

---

## Using the Ansible Playground

> [!NOTE]
> **Note on `ansible-control` vs. AWX:**
> `ansible-control` (or `ansible-ansible-control-1`) is **not** part of AWX itself. AWX executes its jobs inside dedicated Execution Environment pods managed by K3s. The `ansible-control` container is a standalone sandbox provided in this environment to give you a local CLI command center to run `ansible-navigator`, build images with `ansible-builder`, or interact with `kubectl`.

### 1. Connect to the Control Node
Open a shell inside the Ansible Control container:
```bash
docker compose exec -it ansible-control bash
```

Inside this container, you will find yourself in `/playground` (which maps directly to your host's local `./playground` directory).

### 2. Verify Kubernetes / AWX Status via CLI
The control node is linked directly to the running K3s cluster. You can run `kubectl` commands to inspect the AWX pods and logs:
```bash
# View AWX pods
kubectl get pods -n awx

# Tail AWX logs
kubectl logs -n awx deployment/awx-demo-web -c awx-demo-web
```

### 3. Run a Playbook (Traditional Ansible CLI)
To test connectivity against your target containers using traditional Ansible:
```bash
ansible-playbook demo-playbook.yml
```

### 4. Run a Playbook (Modern Execution Environment CLI)
In Ansible Automation Platform 2, playbooks are run inside standardized containers called **Execution Environments (EE)** using `ansible-navigator`. This repository maps your host's Docker socket into the control container so it can spawn Execution Environments seamlessly.

To run the playbook inside the official developer Execution Environment:
```bash
ansible-navigator run demo-playbook.yml --mode stdout
```
*(On first execution, this will pull the `quay.io/ansible/creator-ee:v3.1.0` image, which may take a minute).*

---

## Scaling the Infrastructure via Git (IaC Workflow)

This playground mimics real-world enterprise architectures where inventories and topologies are managed via **Infrastructure as Code (IaC)**.

To add new target containers (e.g., `target3`) to your playground and run playbooks against them in AWX, follow this workflow:

### 1. Provision the New Host in Docker Compose
Add the new service under `services` in your `docker-compose.yml` file, assigning it the next static IP in the subnet (`172.25.0.23`):
```yaml
  target3:
    build:
      context: .
      dockerfile: targets/Dockerfile.target-ubuntu24.04
    volumes:
      - ssh-keys:/ssh-shared:ro
    networks:
      playnet:
        ipv4_address: 172.25.0.23
    restart: unless-stopped
```

### 2. Add the Host to your Git Inventory
Add the new host and its static IP to `playground/inventory.ini` in your repository:
```ini
[targets]
target1 ansible_host=172.25.0.21 ansible_user=ansible
target2 ansible_host=172.25.0.22 ansible_user=ansible
target3 ansible_host=172.25.0.23 ansible_user=ansible
```

### 3. Push and Deploy the Changes
1. Copy the updated project files from your MacBook to your Mint box:
   *To deploy K3s stack updates:*
   ```bash
   scp -r -i ~/.ssh/id_rsa ~/Documents/GitHub/k3s-cluster <USERNAME>@<SERVER_IP>:~/Documents/
   ```
   *To deploy Ansible playground updates:*
   ```bash
   scp -r -i ~/.ssh/id_rsa ~/Documents/GitHub/ansible <USERNAME>@<SERVER_IP>:~/Documents/
   ```
2. Commit and push the changes in your Git repository to GitHub:
   ```bash
   git add playground/inventory.ini
   git commit -m "Add target3 to inventory"
   git push origin main
   ```
3. SSH into the Mint box and re-run Compose to spin up the new container:
   ```bash
   cd ~/Documents/ansible
   docker compose up -d --build
   ```

### 4. Sync and Run in AWX
Because your AWX inventory is **Sourced from a Project**, you do not need to manually configure anything in AWX:
1. In the AWX Web UI, go to **Inventories** -> **Git Inventory** -> **Sources** -> Click **Sync** (or it will auto-sync on job launch if configured).
2. AWX will automatically pull the updated `inventory.ini` from GitHub and register `target3` into the hosts database.
3. Rerun your Job Template—it will now execute the playbooks on the new target automatically!

---

## AWX REST API Reference & Examples

AWX provides a complete, RESTful API (`/api/v2/`) allowing you to list resources, sync projects/inventories, launch job templates, and retrieve job stdout logs programmatically.

### Authentication & Common Headers
All API calls use standard OAuth2 Bearer Token authentication:
```bash
-H "Authorization: Bearer <YOUR_TOKEN>" \
-H "Content-Type: application/json"
```

To generate a token: **Users** $\rightarrow$ select user $\rightarrow$ **Tokens** tab $\rightarrow$ **Add** $\rightarrow$ Scope: `Write`.

---

### 1. Common GET API Examples (Inspecting Resources)

#### List All Job Templates
```bash
curl -s -k -H "Authorization: Bearer <YOUR_TOKEN>" \
  http://<AWX_HOST>:8080/api/v2/job_templates/ | jq '.results[] | {id: .id, name: .name}'
```

#### List All Inventories & Hosts
```bash
# List Inventories
curl -s -k -H "Authorization: Bearer <YOUR_TOKEN>" \
  http://<AWX_HOST>:8080/api/v2/inventories/ | jq '.results[] | {id: .id, name: .name}'

# List Hosts
curl -s -k -H "Authorization: Bearer <YOUR_TOKEN>" \
  http://<AWX_HOST>:8080/api/v2/hosts/ | jq '.results[] | {id: .id, name: .name, enabled: .enabled}'
```

#### List Recent Jobs & Statuses
```bash
curl -s -k -H "Authorization: Bearer <YOUR_TOKEN>" \
  http://<AWX_HOST>:8080/api/v2/jobs/ | jq '.results[] | {id: .id, name: .name, status: .status, elapsed: .elapsed}'
```

---

### 2. Common POST API Examples (Triggering Actions)

#### Trigger a Project Sync (Git Pull)
```bash
curl -s -k -X POST \
  http://<AWX_HOST>:8080/api/v2/projects/<PROJECT_ID>/update/ \
  -H "Authorization: Bearer <YOUR_TOKEN>" \
  -H "Content-Type: application/json"
```

#### Launch a Job Template (Standard)
```bash
curl -s -k -X POST \
  http://<AWX_HOST>:8080/api/v2/job_templates/<TEMPLATE_ID>/launch/ \
  -H "Authorization: Bearer <YOUR_TOKEN>" \
  -H "Content-Type: application/json"
```

#### Launch a Job Template with Survey / Extra Variables
```bash
curl -s -k -X POST \
  http://<AWX_HOST>:8080/api/v2/job_templates/<TEMPLATE_ID>/launch/ \
  -H "Authorization: Bearer <YOUR_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "extra_vars": {
      "patch_action": "update"
    }
  }'
```

---

### 3. Fetching Job Results & Logs

#### Check Job Status
```bash
curl -s -k -H "Authorization: Bearer <YOUR_TOKEN>" \
  http://<AWX_HOST>:8080/api/v2/jobs/<JOB_ID>/ | jq '{id: .id, status: .status, failed: .failed}'
```

#### Fetch Raw Stdout Log Output of a Job
```bash
curl -s -k -H "Authorization: Bearer <YOUR_TOKEN>" \
  "http://<AWX_HOST>:8080/api/v2/jobs/<JOB_ID>/stdout/?format=txt"
```

---

### 4. Interactive AWX API Toolkit Script (`awx_helper.sh`)

This repository includes a feature-rich CLI and interactive shell script [playground/scripts/awx_helper.sh](./playground/scripts/awx_helper.sh) designed to simplify AWX API interactions without needing raw `curl` commands.

#### Features:
* **Interactive Menu Loop**: Runs continuously in an interactive menu mode so you can inspect resources, launch jobs, view logs, and return to the main menu without exiting.
* **Pre-Launch Resource Listing**: When launching a template, optionally lists all registered job templates and IDs before asking for input.
* **Automatic Stdout Prompt**: Prompts to display raw job execution logs immediately after a job template finishes running.
* **CLI Command Support**: Supports non-interactive command-line shortcuts for scripting and CI/CD pipelines.

#### Configuration (Environment Variables):
You can override default settings via environment variables:
```bash
export AWX_HOST="http://<SERVER_IP>:8080"
export AWX_TOKEN="<YOUR_BEARER_TOKEN>"
```

#### Usage Modes:

##### 1. Interactive Menu Mode:
Run the script without arguments to enter the persistent menu:
```bash
./playground/scripts/awx_helper.sh
```

Menu options include:
1. **Launch a Job Template** (with optional pre-listing and post-run stdout viewing)
2. **Sync a Project** (triggers Git repo update and polls status)
3. **Sync an Inventory Source** (triggers inventory update and polls status)
4. **List AWX Resources** (Templates, Projects, Inventories, Hosts, Recent Jobs)
5. **View Job Stdout Logs** (fetches raw stdout output by Job ID)

##### 2. Direct CLI Subcommands:
Execute single tasks directly from your shell:

```bash
# Launch Job Template #15
./playground/scripts/awx_helper.sh launch 15

# Launch Job Template #15 with Survey Extra Variables (JSON)
./playground/scripts/awx_helper.sh launch 15 '{"patch_action": "update"}'

# Sync Git Project #6
./playground/scripts/awx_helper.sh sync-project 6

# Sync Inventory Source #1
./playground/scripts/awx_helper.sh sync-inventory 1

# List Resources (templates, projects, inventories, hosts, jobs)
./playground/scripts/awx_helper.sh list templates
./playground/scripts/awx_helper.sh list jobs

# Print Raw Stdout Logs for Job #42
./playground/scripts/awx_helper.sh logs 42
```

---

## Event-Driven Ansible (EDA) Integration & Workflow

This playground environment includes **Event-Driven Ansible (EDA) Controller** running on port `8083`. EDA introduces an event-driven automation paradigm: external webhooks (Alertmanager, GitHub, ServiceNow, or HTTP POST calls) are received by EDA, processed by `ansible-rulebook`, and automatically trigger AWX Job Templates.

```
[ External System / Webhook ] ──( HTTP POST )──> [ EDA Controller (Port 8083) ]
                                                      │
                                                      ▼
                                            [ ansible-rulebook ]
                                                      │
                                            ( Evaluates Rules )
                                                      │
                                                      ▼
[ Target Host ] <──( SSH / Playbook )── [ AWX Job Template (Port 8080) ]
```

### Overview of Interconnected Objects

* **Event Stream**: Listens on `http://<EDA-HOST>:8083/api/eda/v1/external_event_stream/<UUID>/post/` for incoming events.
* **Event Stream Credential (`Token Event Stream`)**: Secret token used to authenticate incoming webhooks (`Authorization: Bearer <TOKEN>`).
* **AWX Controller Credential (`Ansible Automation Platform`)**: API token allowing EDA to trigger Job Templates in AWX.
* **Rulebook Activation**: Spawns a dedicated Kubernetes pod running `ansible-rulebook` that links external Event Streams (`EDA_Trigger`) to rulebooks (`hello_world_rulebook.yml`).
* **AWX Job Template**: The playbook execution target in AWX (e.g. `Check Disk Space` in Organization `Home Lab`).

### Triggering an EDA Event via `curl`

To trigger the automated workflow:

```bash
curl -X POST http://<SERVER_IP>:8083/api/eda/v1/external_event_stream/<EVENT_STREAM_UUID>/post/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <EVENT_STREAM_TOKEN>" \
  -d '{"message": "ping"}'
```

> [!TIP]
> **Complete Deep Dive Guide:** For full step-by-step setup instructions, credential object mappings, sequence diagrams, and troubleshooting steps, see [docs/eda_awx_workflow.md](./docs/eda_awx_workflow.md).

---

## Custom Execution Environments (EE) & K3s Containerd Management

When running playbooks that depend on third-party Python packages (such as **`hvac`** for HashiCorp Vault lookups) or specific system C-libraries, you can build a custom Execution Environment container image using **`ansible-builder`** and import it into K3s.

---

### 1. `execution-environment.yml` Configuration

Create an `execution-environment.yml` definition file:

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

> [!TIP]
> **Build Tools (`append_base` / `prepend_galaxy`):** Including `gcc`, `python3-devel`, and `libxml2-devel` ensures C-extension Python packages compile without `gcc failed: No such file or directory` or missing `xmlreader.h` errors.

---

### 2. Building the EE Container Image

Build the container image using `ansible-builder` with Docker:

```bash
# Clean up previous build context
sudo rm -rf context/

# Build the custom EE image directly into Docker
sudo ansible-builder build --container-runtime docker --tag custom-awx-ee:1.0
```

*(Alternatively, if using Podman: `ansible-builder build --container-runtime podman --tag custom-awx-ee:1.0`)*

---

### 3. Importing Image into K3s Containerd (`k8s.io` Namespace)

AWX runs inside Kubernetes pods managed by K3s (`rancher/k3s:v1.27.4-k3s1`). Kubernetes checks K3s's internal `containerd` image store in the `k8s.io` namespace. To prevent `ErrImageNeverPull` errors when launching jobs, import the built image archive into K3s:

```bash
# 1. Export the image from Podman/Docker to a tar archive
podman save -o /tmp/custom-awx-ee.tar custom-awx-ee:1.0

# 2. Copy the tar archive into the K3s container
sudo docker cp /tmp/custom-awx-ee.tar k3s:/tmp/custom-awx-ee.tar

# 3. Import the tar archive into K3s's containerd k8s.io namespace
sudo docker exec k3s ctr -n k8s.io images import /tmp/custom-awx-ee.tar

# 4. (Optional) Tag image alias in k8s.io namespace
sudo docker exec k3s ctr -n k8s.io images tag localhost/custom-awx-ee:1.0 custom-awx-ee:1.0
```

---

### 4. Verifying K3s Containerd Images

To inspect images currently available inside K3s's `k8s.io` namespace:

```bash
# List all k8s images
sudo docker exec k3s ctr -n k8s.io images list

# Filter for custom EE image
sudo docker exec k3s ctr -n k8s.io images list | grep custom-awx-ee
```

*Expected Output:*
```text
custom-awx-ee:1.0            2.9 GiB   linux/amd64   io.cri-containerd.image=managed
localhost/custom-awx-ee:1.0  2.9 GiB   linux/amd64   io.cri-containerd.image=managed
```

---

### 5. Registering the Execution Environment in AWX UI

1. Open AWX Web UI (`http://<mini-lab-ip>:8080`).
2. Navigate to **Administration** $\rightarrow$ **Execution Environments** $\rightarrow$ Click **Add**.
   * **Name**: `Custom EE (hvac)`
   * **Image**: `custom-awx-ee:1.0`
   * **Pull**: Select **`Never`** *(or `IfNotPresent`)*
3. Click **Save**.
4. In your Job Template (e.g. `06-test-secret-vars-vault-module`), set **Execution Environment** to `Custom EE (hvac)` and launch!

---

## Clean Up / Reset

To spin down the playground:
```bash
docker compose down
```

To clean up all data (including the AWX PostgreSQL database volume and SSH key state) to start fresh:
```bash
docker compose down -v
```

