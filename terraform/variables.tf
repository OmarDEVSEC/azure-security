# Variables declares inputs for the entire configuration - seperate
# from modules' own variables.tf.action 
  

variable "alert_email"{
    description = "Email for cost and service health alerts"
    type        = string
}