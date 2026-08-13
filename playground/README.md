# Ansible Playground Playbooks Guide

Welcome to the Ansible and AWX playground! This guide documents the set of sample playbooks created to help you learn Ansible playbook syntax, understand core configurations, and explore running tasks across multiple OS platforms (Ubuntu, Debian, Rocky Linux) and within AWX.

---

## Playbook Overview

### 1. [01-variables-and-loops.yml](01-variables-and-loops.yml)
* **Focus**: Variables, Loops, and Conditionals.
* **Concepts Demonstrated**:
  * Defining variables at the play level (`vars`).
  * Accessing dynamically gathered host system properties (`ansible_facts`, like `ansible_os_family`).
  * Iterating over simple lists and lists of dictionaries using the `loop` keyword.
  * Conditional task execution with `when`.
  * Registering outputs from shell commands (`register`) and displaying them (`debug`).

### 2. [02-templates-and-handlers.yml](02-templates-and-handlers.yml)
* **Focus**: Jinja2 Template rendering and Event Handlers.
* **Concepts Demonstrated**:
  * Deploying files dynamically using Jinja2 templates via the `ansible.builtin.template` module (using [templates/welcome.txt.j2](templates/welcome.txt.j2)).
  * Using filters (like `| upper`) and loops (`{% for %}`) within template files.
  * Modifying file lines directly using `ansible.builtin.lineinfile`.
  * Declaring `handlers` that trigger (`notify`) only when a task reports an actual state change (`changed: true`).

### 3. [03-error-handling-and-blocks.yml](03-error-handling-and-blocks.yml)
* **Focus**: Structure grouping and Exception Catching.
* **Concepts Demonstrated**:
  * Grouping tasks using `block`.
  * Gracefully catching and recovering from errors inside a block using `rescue` (like try-catch).
  * Ensuring specific tasks run regardless of success or failure using `always` (like try-finally).
  * Explicitly controlling success/failure criteria using `failed_when` and `changed_when` rules.

### 4. [04-package-and-user-management.yml](04-package-and-user-management.yml)
* **Focus**: Core system administration tasks across different Linux distributions.
* **Concepts Demonstrated**:
  * Using `become: true` to escalate privileges (sudo root).
  * Using the generic `ansible.builtin.package` module to install packages (`curl`, `htop`) automatically using `apt` on Debian/Ubuntu or `dnf` on Rocky Linux.
  * Managing Unix groups and users (`ansible.builtin.group`, `ansible.builtin.user`).
  * Configuring secure directories and files with permissions (`ansible.builtin.file`, `ansible.builtin.copy`).

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
```

---

## Running Playbooks in the Playground

### Method 1: Using `ansible-playbook` (Traditional CLI)

```bash
# Run against all target containers
ansible-playbook 01-variables-and-loops.yml

# Run against a specific host or group
ansible-playbook 01-variables-and-loops.yml --limit target-ubuntu-1

# Check syntax without executing
ansible-playbook 01-variables-and-loops.yml --syntax-check
```

### Method 2: Using `ansible-navigator` (Modern TUI Container Runner)

```bash
# Interactive TUI mode (from control container)
ansible-navigator run demo-playbook.yml --ee false

# Plain text output mode
ansible-navigator run demo-playbook.yml --ee false --mode stdout
```
