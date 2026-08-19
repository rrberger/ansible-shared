---
name: ansible-authoring
description: >-
  Best practices and scaffolding for authoring clean, production-grade Ansible Playbooks, Roles, and Rulebooks using AI coding assistance.
  Enforces the Zen of Ansible, Fully Qualified Collection Names (FQCN), strict idempotency, declarative tasks, and proper secret hygiene.
---

# Ansible Authoring & Design Guidelines (The Zen of Ansible)

This document provides standardized guidelines and scaffolding for authoring clean, maintainable, production-ready **Ansible Playbooks**, **Roles**, and **Event-Driven Ansible (EDA) Rulebooks** using Claude and AI coding assistance.

---

## 🧘 [The Zen of Ansible Core Principles](https://www.redhat.com/en/blog/the-zen-of-ansible)

1. **Simplicity Over Complexity**
   - Playbooks should read like self-documenting human English.
   - If a task requires complex inline bash scripts or nested conditionals, break it into dedicated tasks, roles, or custom modules.

2. **Strict Idempotency & Safety Guards**
   - Every play and task must be safe to execute 1, 10, or 1,000 times without producing unexpected side-effects or duplicate configuration.
   - When using `ansible.builtin.command` or `ansible.builtin.shell`:
     - ALWAYS specify `changed_when:` and `creates:` / `removes:` criteria.
     - ALWAYS specify `async:` (e.g. `async: 30` or appropriate timeout) for `command` and `shell` tasks to ensure commands never hang or block play execution forever.

3. **Declarative State Over Imperative Scripting**
   - Express *what target state you desire*, not *how to step-by-step run shell commands*.
   - Use built-in module abstractions (`ansible.builtin.package`, `ansible.builtin.user`, `ansible.builtin.service`) instead of raw shell commands (`apt-get`, `useradd`, `systemctl`).

4. **Mandatory FQCN (Fully Qualified Collection Names)**
   - Always use full collection module names: `ansible.builtin.copy` (not `copy`), `ansible.builtin.template` (not `template`), `community.general.ini_file`.

5. **Separation of Code & Data**
   - Never hardcode dynamic configuration parameters inside playbooks.
   - Store variables in `vars/`, `defaults/main.yml`, or pass them via AWX / EDA extra vars.

6. **Proper Secret Hygiene & `no_log` Scoping**
   - Never embed plain-text credentials, SSH private keys, API tokens, or passwords in playbooks or git repositories.
   - Use HashiCorp Vault lookup modules (`community.hashi_vault`) or Ansible Vault encryption.
   - Apply `no_log: true` on tasks that register or output sensitive data to prevent secret leakage in job stdout logs.

7. **Script Execution Hygiene & Local Repository Scoping**
   - NEVER execute scripts (Bash `.sh` or PowerShell `.ps1`) directly from external remote file shares (e.g., SMB/CIFS, NFS, UNC paths `\\server\share`, or arbitrary HTTP downloads).
   - All scripts MUST either:
     - Exist directly within the version-controlled project repository (e.g. under `files/` or `scripts/`) and be executed via `ansible.builtin.script` or `ansible.builtin.copy`.
     - Be written inline directly inside the playbook task (e.g. using `ansible.builtin.shell` or `ansible.windows.win_powershell`).

8. **Service Restarts via Handlers Only (Avoid Inline Restarts)**
   - **Anti-Pattern**: Triggering service restarts directly in tasks (`ansible.builtin.service: state=restarted`) whenever a file edit occurs. If 10 tasks edit 10 config files, the service will restart 10 times during a single playbook execution!
   - **Red Hat Best Practice**: Always use `notify: "Restart service_name"` to defer service restarts to `handlers:`. Ansible will batch all notifications and restart the service **exactly once** at the end of the play run.

9. **Variable Naming Conventions & Snake Case**
   - **Anti-Pattern**: Using camelCase (`myAppPort`), hyphens (`my-app-port`), or UPPERCASE variables for non-constants.
   - **Red Hat Best Practice**: Use lowercase `snake_case` for all variable names (`app_port`, `target_package`, `vault_addr`). Reserve UPPERCASE for system environment variables (`VAULT_TOKEN`, `DEBIAN_FRONTEND`).

10. **Explicit Error Handling Over Blanket `ignore_errors`**
    - **Anti-Pattern**: Using `ignore_errors: true` as a shortcut when commands fail.
    - **Red Hat Best Practice**: Use `failed_when:` to explicitly define what output or return code constitutes a failure, or handle expected failures with `block`/`rescue`/`always` error handling.

11. **Task Naming Quality & Verb Mandate**
    - **Anti-Pattern**: Task names like `name: nginx`, `name: copy file`, or missing `name:` fields entirely.
    - **Red Hat Best Practice**: Every task must have a unique `name:` starting with an imperative verb describing the intent (`name: "Ensure Nginx package is installed"`, `name: "Deploy web server configuration template"`).

---

## 🤝 [Red Hat Community of Practice (CoP) Good Practices](https://redhat-cop.github.io/automation-good-practices/)

Adhere to the official Red Hat CoP Automation Good Practices framework:

12. **Role Variable Namespacing (Role Prefix Rule)**
    - All variables defined inside a role MUST be prefixed with the role name (e.g. inside `roles/nginx`, use `nginx_port`, `nginx_conf_dir`, `nginx_user` instead of generic `port` or `conf_dir`). This prevents variable scope collision across plays.

13. **YAML Formatting & Jinja2 Expression Quoting**
    - Always begin YAML files with `---`.
    - Use strict 2-space indentation (no tabs).
    - Always quote Jinja2 template expressions at the start of a value (`dest: "{{ config_path }}"`) to prevent YAML parser syntax errors.
    - Use explicit boolean values (`true` / `false` in lowercase) instead of `yes` / `no`.

14. **Minimal Privilege Escalation (`become` Scoping)**
    - Avoid setting `become: true` globally at the play level unless 100% of tasks require root. Apply `become: true` strictly to individual tasks that require elevated privileges to uphold the principle of least privilege.

15. **Strict Collection Version Pinning**
    - Always pin exact or semver compatible version specifications in `collections/requirements.yml` (`version: ">=1.5.0,<2.0.0"`) rather than using wildcard `version: "*"`, preventing unexpected breaking changes during EE image builds.

16. **Loop Result Registration Hygiene (`register` in loops)**
    - When registering the output of a loop task (`register: task_loop`), remember that `task_loop` becomes an object containing a `.results` list array. Access results via `task_loop.results` item loops rather than expecting a scalar `.stdout`.

17. **Single Responsibility Principle for Roles (SRP)**
    - A role must perform one focused architectural function. Avoid multi-purpose monolithic roles (e.g. separate `roles/nginx` from `roles/php_fpm`).

---

## 📁 Red Hat Standard Directory & File Structure

Adhere to the official **Red Hat Ansible Automation Platform (AAP)** directory layout for repositories and roles:

```text
ansible-project/
├── ansible.cfg                     # Local Ansible configuration (stdout_callback = yaml, retry_files_enabled = False)
├── collections/
│   └── requirements.yml            # Galaxy collections specification (version pinned)
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
│       │   └── main.yml            # Default low-priority variables (prefixed with role_name_)
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
  become: false # Use task-level privilege escalation where possible

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
      become: true

    - name: "Ensure application service configuration directory exists"
      ansible.builtin.file:
        path: "/etc/myapp"
        state: "directory"
        owner: "root"
        group: "root"
        mode: "0755"
      become: true

    - name: "Deploy application configuration from Jinja2 template"
      ansible.builtin.template:
        src: "myapp.conf.j2"
        dest: "/etc/myapp/myapp.conf"
        owner: "root"
        group: "root"
        mode: "0644"
      become: true
      notify: "Restart application service"

    - name: "Execute repository-scoped script using ansible.builtin.script"
      ansible.builtin.script: "files/check_myapp_health.sh"
      register: health_check
      changed_when: false
      async: 30
      poll: 5

    - name: "Ensure application service is enabled and running"
      ansible.builtin.service:
        name: "myapp"
        state: "{{ app_service_state }}"
        enabled: true
      become: true

  handlers:
    - name: "Restart application service"
      ansible.builtin.service:
        name: "myapp"
        state: "restarted"
      become: true
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
- [ ] **Require async timeouts**: Ensure `ansible.builtin.command` and `ansible.builtin.shell` tasks specify `async:` timeouts so they do not run forever.
- [ ] **Forbidden Remote Script Execution**: Ensure script files (.sh, .ps1) exist inside the git repo or are inline, never executed from remote file shares (NFS/SMB/UNC).
- [ ] **Require Handlers for Changes**: Ensure file/template edits trigger handlers (`notify:`) rather than restarting services inline.
- [ ] **Enforce Task-Level Become**: Scope `become: true` at task level rather than globally at play level.
- [ ] **Enforce Snake Case & Role Namespacing**: Use `snake_case` for variables and prefix role variables with `role_name_`.
- [ ] **Define Variable Contracts**: List inputs at top under `vars:` with default values and assertion checks.
- [ ] **Run Lint Verification**: Validate generated code using `ansible-lint <file.yml>`.
