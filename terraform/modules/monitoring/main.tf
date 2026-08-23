# Setting up resource moniotoring via terraform and deploying it the Azure subscription

resource "azurerm_monitor_action_group" "main" {
  name                = "ag-security-lab-alerts"
  resource_group_name = var.resource_group_name
  short_name          = "seclab"

  email_receiver {
    name          = "omar-email"
    email_address = var.alert_email
  }
}

resource "azurerm_consumption_budget_subscription" "main" {
  name            = "monthly-lab-budget"
  subscription_id = "/subscriptions/${var.subscription_id}"

  amount     = var.monthly_budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = "2026-08-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 80.0
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100.0
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }
}

resource "azurerm_monitor_activity_log_alert" "service_health" {
  name                = "service-health-alerts"
  resource_group_name = var.resource_group_name
  scopes              = ["/subscriptions/${var.subscription_id}"]
  description         = "Alerts on Azure service health issues affecting the subscription"

  criteria {
    category = "ServiceHealth"

    service_health {
      events    = ["Incident", "Maintenance"]
      locations = ["Global", var.location]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}