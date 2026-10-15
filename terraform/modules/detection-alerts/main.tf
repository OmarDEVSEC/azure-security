locals {
  detections = {
    storage_container_made_public = {
      file        = "01-storage-container-made-public.kql"
      description = "T1530: Container ACL Changed (Possible public exposure)"
      severity    = 2
    }
    storage_anonymous_read = {
      file        = "02-storage-anonymous-read-success.kql"
      description = "T1530: anonymous blob read succeeded"
      severity    = 1
    }
    nsg_rule_changed = {
      file        = "04-nsg-rule-changed.kql"
      description = "T1562.007: NSG or security rule written"
      severity    = 1
    }
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "detection" {
  for_each = local.detections

  name                = "det-${replace(each.key, "_", "-")}"
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = each.value.description
  severity            = each.value.severity

  scopes                            = [var.log_analytics_workspace_id]
  evaluation_frequency              = "PT15M"
  window_duration                   = "PT30M"
  mute_actions_after_alert_duration = "PT1H"

  criteria {
    query                   = file("${path.module}/../../../detections/${each.value.file}")
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }
  action {
    action_groups = [var.action_group_id]
  }
}
