#!/bin/bash

# AWX API Multi-Tool Script
AWX_HOST="${AWX_HOST:-http://localhost:8080}"
TOKEN="${AWX_TOKEN:-<YOUR_AWX_BEARER_TOKEN>}"


# Helper function: HTTP GET
api_get() {
  local endpoint="$1"
  curl -s -k -H "Authorization: Bearer $TOKEN" "$AWX_HOST$endpoint"
}

# Helper function: HTTP POST
api_post() {
  local endpoint="$1"
  local data="$2"
  if [ -n "$data" ]; then
    curl -s -k -X POST "$AWX_HOST$endpoint" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "$data"
  else
    curl -s -k -X POST "$AWX_HOST$endpoint" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json"
  fi
}

# Generic poller for AWX background tasks
poll_task() {
  local endpoint="$1"
  local id_field="$2"
  local task_id="$3"

  echo "⏳ Monitoring task #$task_id..."
  while true; do
    local resp=$(api_get "$endpoint$task_id/")
    local status=$(echo "$resp" | jq -r '.status')
    
    if [[ "$status" == "successful" ]]; then
      echo "=========================================="
      echo "🎉 SUCCESS: Task #$task_id completed cleanly!"
      echo "=========================================="
      break
    elif [[ "$status" == "failed" || "$status" == "canceled" || "$status" == "error" ]]; then
      echo "=========================================="
      echo "❌ FAILED: Task #$task_id failed with status: $status"
      echo "=========================================="
      break
    else
      echo "   Current Status: [$status]... waiting 3s..."
      sleep 3
    fi
  done
}

# Action 1: Launch Job Template
action_launch_template() {
  local template_id="$1"
  local extra_vars="$2"

  if [ -z "$template_id" ]; then
    read -p "Would you like to list available Job Templates first? (Y/n): " list_first
    if [[ -z "$list_first" || "$list_first" =~ ^[Yy]$ ]]; then
      echo ""
      action_list_resources "templates"
      echo ""
    fi
    read -p "Enter Job Template ID: " template_id
  fi

  if [ -z "$template_id" ]; then
    echo "❌ Error: No Job Template ID provided."
    return 1
  fi

  echo "🚀 Triggering Job Template #$template_id..."
  
  local response
  if [ -n "$extra_vars" ]; then
    response=$(api_post "/api/v2/job_templates/$template_id/launch/" "{\"extra_vars\": $extra_vars}")
  else
    response=$(api_post "/api/v2/job_templates/$template_id/launch/")
  fi

  local job_id=$(echo "$response" | jq -r '.job // .id')

  if [ "$job_id" == "null" ] || [ -z "$job_id" ]; then
    echo "❌ Failed to trigger job template!"
    echo "$response" | jq .
    return 1
  fi

  echo "✅ Job #$job_id spawned successfully."
  poll_task "/api/v2/jobs/" "job" "$job_id"

  echo ""
  read -p "Would you like to view the stdout logs for Job #$job_id? (y/N): " view_logs
  if [[ "$view_logs" =~ ^[Yy]$ ]]; then
    echo ""
    action_get_logs "$job_id"
  fi
}

# Action 2: Sync Project (Git Repo Pull)
action_sync_project() {
  local project_id="$1"

  if [ -z "$project_id" ]; then
    echo "--- Available Projects ---"
    api_get "/api/v2/projects/" | jq -r '.results[] | "ID: \(.id) | Name: \(.name)"'
    read -p "Enter Project ID to sync: " project_id
  fi

  if [ -z "$project_id" ]; then
    echo "❌ Error: No Project ID provided."
    return 1
  fi

  echo "🔄 Triggering Project Sync for Project #$project_id..."
  local response=$(api_post "/api/v2/projects/$project_id/update/")
  local update_id=$(echo "$response" | jq -r '.project_update // .id')

  if [ "$update_id" == "null" ] || [ -z "$update_id" ]; then
    echo "❌ Failed to trigger project sync!"
    echo "$response" | jq .
    return 1
  fi

  echo "✅ Project update task #$update_id spawned."
  poll_task "/api/v2/project_updates/" "project_update" "$update_id"

  local update_info=$(api_get "/api/v2/project_updates/$update_id/")
  local scm_rev=$(echo "$update_info" | jq -r '.scm_revision // empty')

  if [ -n "$scm_rev" ] && [ "$scm_rev" != "null" ]; then
    echo "📌 Synced Git Commit Revision: $scm_rev"
  fi
}

# Action 3: Sync Inventory Source
action_sync_inventory() {
  local inv_src_id="$1"

  if [ -z "$inv_src_id" ]; then
    echo "--- Available Inventory Sources ---"
    api_get "/api/v2/inventory_sources/" | jq -r '.results[] | "ID: \(.id) | Name: \(.name)"'
    read -p "Enter Inventory Source ID to sync: " inv_src_id
  fi

  if [ -z "$inv_src_id" ]; then
    echo "❌ Error: No Inventory Source ID provided."
    return 1
  fi

  echo "📦 Triggering Inventory Source Sync for ID #$inv_src_id..."
  local response=$(api_post "/api/v2/inventory_sources/$inv_src_id/update/")
  local update_id=$(echo "$response" | jq -r '.inventory_update // .id')

  if [ "$update_id" == "null" ] || [ -z "$update_id" ]; then
    echo "❌ Failed to trigger inventory sync!"
    echo "$response" | jq .
    return 1
  fi

  echo "✅ Inventory update task #$update_id spawned."
  poll_task "/api/v2/inventory_updates/" "inventory_update" "$update_id"
}

# Action 4: List AWX Resources
action_list_resources() {
  local resource="$1"

  if [ -z "$resource" ]; then
    echo "Select resource to list:"
    echo "  1) Job Templates"
    echo "  2) Projects"
    echo "  3) Inventories"
    echo "  4) Hosts"
    echo "  5) Recent Jobs"
    read -p "Option [1-5]: " res_opt
    case "$res_opt" in
      1) resource="templates" ;;
      2) resource="projects" ;;
      3) resource="inventories" ;;
      4) resource="hosts" ;;
      5) resource="jobs" ;;
      *) echo "Invalid option"; return 1 ;;
    esac
  fi

  case "$resource" in
    templates|job_templates)
      echo "=== Job Templates ==="
      api_get "/api/v2/job_templates/" | jq -r '.results[] | "ID: \(.id) \t| Name: \(.name)"'
      ;;
    projects)
      echo "=== Projects ==="
      api_get "/api/v2/projects/" | jq -r '.results[] | "ID: \(.id) \t| Name: \(.name) \t| Status: \(.status)"'
      ;;
    inventories)
      echo "=== Inventories ==="
      api_get "/api/v2/inventories/" | jq -r '.results[] | "ID: \(.id) \t| Name: \(.name)"'
      ;;
    hosts)
      echo "=== Hosts ==="
      api_get "/api/v2/hosts/" | jq -r '.results[] | "ID: \(.id) \t| Name: \(.name) \t| Enabled: \(.enabled)"'
      ;;
    jobs)
      echo "=== Recent Jobs ==="
      api_get "/api/v2/jobs/" | jq -r '.results[] | "ID: \(.id) \t| Name: \(.name) \t| Status: \(.status) \t| Elapsed: \(.elapsed)s"'
      ;;
    *)
      echo "Unknown resource type: $resource"
      ;;
  esac
}

# Action 5: Fetch Job Stdout Logs
action_get_logs() {
  local job_id="$1"

  if [ -z "$job_id" ]; then
    read -p "Enter Job ID to view stdout logs: " job_id
  fi

  if [ -z "$job_id" ]; then
    echo "❌ Error: No Job ID provided."
    return 1
  fi

  echo "📜 Fetching stdout logs for Job #$job_id..."
  echo "--------------------------------------------------"
  curl -s -k -H "Authorization: Bearer $TOKEN" "$AWX_HOST/api/v2/jobs/$job_id/stdout/?format=txt"
  echo ""
  echo "--------------------------------------------------"
}

# Main Execution Switch
ACTION="$1"
SHIFT_ARG="$2"
EXTRA="$3"

case "$ACTION" in
  launch|job|template)
    action_launch_template "$SHIFT_ARG" "$EXTRA"
    ;;
  sync-project|project-sync)
    action_sync_project "$SHIFT_ARG"
    ;;
  sync-inventory|inventory-sync)
    action_sync_inventory "$SHIFT_ARG"
    ;;
  list)
    action_list_resources "$SHIFT_ARG"
    ;;
  logs|stdout)
    action_get_logs "$SHIFT_ARG"
    ;;
  "")
    # Interactive Menu Mode (Persistent Loop)
    while true; do
      echo ""
      echo "=========================================="
      echo "       AWX API Automation Toolkit         "
      echo "=========================================="
      echo "1) Launch a Job Template"
      echo "2) Sync a Project (Git Update)"
      echo "3) Sync an Inventory Source"
      echo "4) List AWX Resources"
      echo "5) View Job Stdout Logs"
      echo "6) Exit"
      echo "=========================================="
      read -p "Select an action [1-6]: " choice

      case "$choice" in
        1) action_launch_template ;;
        2) action_sync_project ;;
        3) action_sync_inventory ;;
        4) action_list_resources ;;
        5) action_get_logs ;;
        6) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid selection." ;;
      esac

      echo ""
      read -p "Press Enter to return to the main menu..."
    done
    ;;
  *)
    echo "Usage: $0 [action] [target_id] [extra_vars]"
    echo "Actions:"
    echo "  launch [template_id] [json_extra_vars]  - Launch job template"
    echo "  sync-project [project_id]               - Sync Git project"
    echo "  sync-inventory [inventory_source_id]     - Sync inventory source"
    echo "  list [templates|projects|inventories|hosts|jobs] - List resources"
    echo "  logs [job_id]                            - Print job stdout logs"
    exit 1
    ;;
esac
