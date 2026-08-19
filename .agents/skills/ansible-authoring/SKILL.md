---
name: ansible-authoring
description: >-
  Best practices and scaffolding for authoring clean, production-grade Ansible Playbooks, Roles, and Rulebooks using AI coding assistance.
  Enforces the Zen of Ansible, Fully Qualified Collection Names (FQCN), strict idempotency, declarative tasks, and proper secret hygiene.
---

# Ansible Authoring & Design Guidelines (The Zen of Ansible)

This skill provides a standardized framework and scaffolding for authoring clean, maintainable, production-ready **Ansible Playbooks**, **Roles**, and **Event-Driven Ansible (EDA) Rulebooks** using AI pair programming.

---

## 🧘 The Zen of Ansible Core Principles

1. **Simplicity Over Complexity**
   - Playbooks should read like self-documenting human English.
   - If a task requires complex inline bash scripts or nested conditionals, break it into dedicated tasks, roles, or custom modules.

2. **Strict Idempotency**
   - Every play and task must be safe to execute 1, 10, or 1,000 times without producing unexpected side-effects or duplicate configuration.
   - When using `ansible.builtin.command` or `ansible.builtin.shell`, ALWAYS specify `changed_when:` and `creates:` / `removes:` criteria.

3. **Declarative State Over Imperative Scripting**
   - Express *what target state you desire*, not *how to step-by-step run shell commands*.
   - Use built-in module abstractions (`ansible.builtin.package`, `ansible.builtin.user`, `ansible.builtin.service`) instead of raw shell commands (`apt-get`, `useradd`, `systemctl`).

4. **Mandatory FQCN (Fully Qualified Collection Names)**
   - Always use full collection module names: `ansible.builtin.copy` (not `copy`), `ansible.builtin.template` (not `template`), `community.general.ini_file`.

5. **Separation of Code & Data**
   - Never hardcode dynamic configuration parameters inside playbooks.
   - Store variables in `vars/`, `defaults/main.yml`, or pass them via AWX / EDA extra vars.

6. **Proper Secret Hygiene**
   - Never embed plain-text credentials, SSH private keys, API tokens, or passwords in playbooks or git repositories.
   - Use HashiCorp Vault lookup modules (`community.hashi_vault`) or Ansible Vault encryption.

---

## 📁 Red Hat Standard Directory & File Structure

Adhere to the official **Red Hat Ansible Automation Platform (AAP)** directory layout for repositories and roles:

```text
ansible-project/
├── ansible.cfg                     # Local Ansible configuration
├── collections/
│   └── requirements.yml            # Galaxy collections specification
├── docs/                           # Architecture & workflow documentation
├── execution_environments/
│   └── execution-environment.yml   # ansible-builder v3 specification
├── group_vars/                     # Group-level variable files (e.g. all.yml, webservers.yml)
├── host_vars/                      # Host-specific variable overrides (e.g. mini-lab.yml)
├── inventory/                      # Production & staging inventory files (or inventory.ini)
│   ├── production.ini
│   └── staging.ini
├── playbooks/                      # Orchestration & automation playbooks
│   ├── 01-site-setup.yml
│   └── 02-maintenance.yml
├── roles/                          # Reusable Ansible Roles (Galaxy / AAP standard)
│   └── webserver/
│       ├── defaults/
│       │   └── main.yml            # Default low-priority variables
│       ├── files/                  # Static files deployed via copy module
│       ├── handlers/
│       │   └── main.yml            # Role-specific service handlers
│       ├── meta/
│       │   └── main.yml            # Role metadata & collection dependencies
│       ├── tasks/
│       │   └── main.yml            # Role task execution entry point
│       ├── templates/              # Jinja2 configuration templates (.j2)
│       └── vars/
│           └── main.yml            # High-priority role variables
├── rulebooks/                      # Event-Driven Ansible (EDA) rulebook definitions
│   └── hello_world_rulebook.yml
└── vars/
    └── secrets.yml.example         # Secret variable templates
```

---

## 🏗️ Production Playbook Scaffolding Template

```yaml
---
- name: "Descriptive Play Title (e.g. Configure Web Application Server)"
  hosts: "all"
  gather_facts: true
  become: true

  vars:
    app_port: 8080
    app_service_state: "started"

  tasks:
    - name: "Validate input variables and prerequisites"
      ansible.builtin.assert:
        that:
          - app_port is defined
          - app_port | int > 0
        fail_msg: "Invalid app_port parameter provided."

    - name: "Install required system packages"
      ansible.builtin.package:
        name:
          - "curl"
          - "htop"
        state: "present"

    - name: "Ensure application service configuration directory exists"
      ansible.builtin.file:
        path: "/etc/myapp"
        state: "directory"
        owner: "root"
        group: "root"
        mode: "0755"

    - name: "Deploy application configuration from Jinja2 template"
      ansible.builtin.template:
        src: "myapp.conf.j2"
        dest: "/etc/myapp/myapp.conf"
        owner: "root"
        group: "root"
        mode: "0644"
      notify: "Restart application service"

    - name: "Ensure application service is enabled and running"
      ansible.builtin.service:
        name: "myapp"
        state: "{{ app_service_state }}"
        enabled: true

  handlers:
    - name: "Restart application service"
      ansible.builtin.service:
        name: "myapp"
        state: "restarted"
```

---

## ⚡ Event-Driven Ansible Rulebook Scaffolding Template

```yaml
---
- name: "Descriptive Rulebook Title (e.g. Webhook Remediation Rulebook)"
  hosts: "all"

  sources:
    - ansible.eda.event_stream:

  rules:
    - name: "Trigger AWX Remediation Job Template on Incident Event"
      condition: event.payload.status == "critical"
      action:
        run_job_template:
          name: "Remediate Disk Space"
          organization: "Home Lab"
          job_args:
            extra_vars:
              triggered_by: "Event-Driven Ansible"

    - name: "Log Non-Critical Webhook Payload"
      condition: event.payload.status is defined
      action:
        debug:
          msg: "Received event payload: {{ event.payload }}"
```

---

## 🛠️ AI Prompting Checklist for Playbook Creation

When prompting AI assistants to author playbooks:
- [ ] **Specify FQCN**: Require `ansible.builtin.<module>` for all tasks.
- [ ] **Require Handlers for Changes**: Ensure file/template edits trigger handlers (`notify:`) rather than restarting services inline.
- [ ] **Define Variable Contracts**: List inputs at top under `vars:` with default values and assertion checks.
- [ ] **Run Lint Verification**: Validate generated code using `ansible-lint <file.yml>`.
