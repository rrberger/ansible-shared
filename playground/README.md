# Ansible Playground Playbooks Guide

Welcome to the Ansible and AWX playground! This guide documents the set of sample playbooks created to help you learn Ansible playbook syntax, understand core configurations, and explore running tasks across multiple OS platforms (Ubuntu, Debian, Rocky Linux) and within AWX.

---

## Playbook Overview

### 1. [01-variables-and-loops.yml](./playground/01-variables-and-loops.yml)
*   **Focus**: Variables, Loops, and Conditionals.
*   **Concepts Demonstrated**:
    *   Defining variables at the play level (`vars`).
    *   Accessing dynamically gathered host system properties (`ansible_facts`, like `ansible_os_family`).
    *   Iterating over simple lists and lists of dictionaries using the `loop` keyword.
    *   Conditional task execution with `when`.
    *   Registering outputs from shell commands (`register`) and displaying them (`debug`).

### 2. [02-templates-and-handlers.yml](./playground/02-templates-and-handlers.yml)
*   **Focus**: Jinja2 Template rendering and Event Handlers.
*   **Concepts Demonstrated**:
    *   Deploying files dynamically using Jinja2 templates via the `ansible.builtin.template` module (using [templates/welcome.txt.j2](./playground/templates/welcome.txt.j2)).
    *   Using filters (like `| upper`) and loops (`{% for %}`) within template files.
    *   Modifying file lines directly using `ansible.builtin.lineinfile`.
    *   Declaring `handlers` that trigger (`notify`) only when a task reports an actual state change (`changed: true`).

### 3. [03-error-handling-and-blocks.yml](./playground/03-error-handling-and-blocks.yml)
*   **Focus**: Structure grouping and Exception Catching.
*   **Concepts Demonstrated**:
    *   Grouping tasks using `block`.
    *   Gracefully catching and recovering from errors inside a block using `rescue` (like try-catch).
    *   Ensuring specific tasks run regardless of success or failure using `always` (like try-finally).
    *   Explicitly controlling success/failure criteria using `failed_when` and `changed_when` rules.

### 4. [04-package-and-user-management.yml](./playground/04-package-and-user-management.yml)
*   **Focus**: Core system administration tasks across different Linux distributions.
*   **Concepts Demonstrated**:
    *   Using `become: true` to escalate privileges (sudo root).
    *   Using the generic `ansible.builtin.package` module to install packages (`curl`, `htop`) automatically using `apt` on Debian/Ubuntu or `dnf` on Rocky Linux.
    *   Managing Unix groups and users (`ansible.builtin.group`, `ansible.builtin.user`).
    *   Configuring secure directories and files with permissions (`ansible.builtin.file`, `ansible.builtin.copy`).

---

## Anatomy of a Playbook

An Ansible playbook is written in YAML. Here is a breakdown of its basic structure:

```yaml
--- # Starts the YAML document
- name: Human readable description of the play
  hosts: targets                 # Group of hosts to target (defined in inventory)
  gather_facts: true             # Inspect the target hosts before running tasks
  become: true                   # Run all tasks in this play as root (sudo)
  vars:                          # Define key-value configuration variables
    my_var: "hello"

  tasks:                         # Sequential list of actions to execute
    - name: Describe the task
      ansible.builtin.command: whoami
      register: user_check       # Capture the command results
      
    - name: Print the result
      ansible.builtin.debug:
        msg: "The user is {{ user_check.stdout }}"
```

---

## How to Run These Playbooks

First, log in to your Ansible control node shell:
```bash
docker compose exec -it ansible-control bash
```

Inside the control container, you can run playbooks in two ways:

### Method A: Traditional CLI (`ansible-playbook`)
Run any playbook using the local config and inventory:
```bash
ansible-playbook 01-variables-and-loops.yml
ansible-playbook 02-templates-and-handlers.yml
ansible-playbook 03-error-handling-and-blocks.yml
ansible-playbook 04-package-and-user-management.yml
```

### Method B: Modern Containerized Runner (`ansible-navigator`)
In AAP 2 / modern environments, playbooks run inside isolated containers called **Execution Environments**:
```bash
ansible-navigator run 01-variables-and-loops.yml --mode stdout
```

---

## Running Playbooks inside Ansible AWX

AWX sits on top of Ansible to provide a web interface, RBAC, credentials management, and API controls. To run these playbooks in AWX:

1.  **Add Credentials**: Go to **Credentials** -> **Add**. Choose **Machine** credential type.
    *   **Username**: `ansible`
    *   **SSH Private Key**: Copy the contents of your generated private key (found inside `/ssh-shared/id_rsa` or on your host system at `docker volume inspect ansible_ssh-keys` path).
2.  **Add Inventory**: Go to **Inventories** -> **Add**.
    *   Name it `Playground Inventory`.
    *   Under **Hosts**, add your target nodes:
        *   `target-ubuntu-1` (Variables: `ansible_host: 172.25.0.21`)
        *   `target-ubuntu-2` (Variables: `ansible_host: 172.25.0.22`)
        *   `target-debian-1` (Variables: `ansible_host: 172.25.0.23`)
        *   `target-rocky-1`  (Variables: `ansible_host: 172.25.0.24`)
    *   Make sure to define `ansible_user: ansible` and set Privilege Escalation to `sudo`.
3.  **Add Project**: Go to **Projects** -> **Add**.
    *   If you pushed your repository to Git, choose **Git** as the source control type and supply your repo URL.
    *   Alternatively, you can configure AWX to read local files by mapping the `/playground` folder as a project base directory.
4.  **Create Template**: Go to **Templates** -> **Add Job Template**.
    *   Select your `Playground Inventory`.
    *   Select the `Project` you created.
    *   Select the **Playbook** from the dropdown (e.g., `01-variables-and-loops.yml`).
    *   Assign the **Machine Credential** you configured in step 1.
    *   Click **Save** and click **Launch**!
