variable "resource" {
  default = "azurerm_network_security_rule."
}

variable "module" {
  default = "../../Subscriptions/Subscription_A"
  # default = "main"
}

data "external" "example" {
  program = ["sh",
              "-c",
              "echo '{\"value\": \"'$(terraform -chdir=${var.module} show -json | sed -E 's/\"/\\\\\"/g')'\"}'"
            ]
}

locals {
  priorities = [ for res in jsondecode(data.external.example.result.value).values.root_module.resources
              : res.values.priority
              if try(regex(".{${length(var.resource)}}", res.address), "") == var.resource
          ]
  # priorities = [1,3,4,5]

  free_priority = [for i in range(100,
                        try(max(local.priorities...), 100) + 2)
                     : i if !contains(local.priorities, i)][0]
}

output "free_priority" {
  value = local.free_priority
}
