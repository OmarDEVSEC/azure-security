# Variables declares inputs for the entire configuration - seperate
# from modules' own variables.tf.action 

#Values for all variables declared are in terraform.tfvars
variable "alert_email" {
  description = "Email for cost and service health alerts"
  type        = string
}


