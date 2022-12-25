variable "resource" {
  description = "The resource name for Network Security Rules"
  default = "azurerm_network_security_rule"
}

variable "module" {
  description = "The path to the Subscription A module"
  default = "../../Subscriptions/Subscription_A"
}

variable "state_file" {
  description = "Pass in a separate state file for the Subscription A module"
  default = ""
}

# dis was done assuming that your statefile is located on your local machine
# An external provider is used to fetch the state information from Subscription A
# This assumes that the state file exists for that module containing all the resources deployed by the module

# The defined program performs the following:
# 1. Use terraform -chdir=${var.module} show -json to fetch the state information for the module in json format
# 2. The external provider expects a map of string values from stdout, so the json returned from terraform show
#   is stringified using regex
# 3. The string is then passed as a value to the key "data"
# 4. The final map containing a single key and string value is then echoed to stdout
data "external" "example" {
  program = ["sh",
              "-c",
              "echo '{\"data\": \"'$(terraform -chdir=${var.module} show -json ${var.state_file} | sed -E 's/\"/\\\\\"/g')'\"}'"
            ]
}


# The result obtained fron the external provisioner is further processes to extract the needed information
locals {

  state_data = jsondecode(data.external.example.result.data)

  state_values = try(local.state_data.values, local.state_data.planned_values, {})

  # A list of all priorities declared in Subscription A is obtained by filtering for all network security rules
  # declared in the module and returning their various priority values.
  # The data is gotten by converting the json string gotten from the external provider to a json object using the
  # jsondecode() function

  # Example result: priorities = [100, 102, 104]
  priorities = [ for res in try(local.state_values.root_module.resources, [])
              : res.values.priority
              if res.type == var.resource
          ]


  # Generates a list of all free priority numbers within the interval of the smallest existing priority and the largest
  # existing priority

  # Example result: all_free_priorities = [100, 102, 104] => [100, 101, 102, 103, 104, 105] => [101, 103, 105]
  all_free_priorities = [
                          for i in range(
                            try(min(local.priorities...), 100),
                            try(max(local.priorities...), 100) + 2
                          )
                          : i
                          if !contains(local.priorities, i)
                      ]

  # Takes the first free priority in the free priorities list, exposing it as a local data for consumption within the module

  # Example result: free_priority = [101, 103, 105][0] => 101
  free_priority = local.all_free_priorities[0]
}

# Output the free priority number
output "free_priority" {
  value = local.free_priority
}

# Output the existing priorities
output "priorities" {
  value = local.priorities
}

