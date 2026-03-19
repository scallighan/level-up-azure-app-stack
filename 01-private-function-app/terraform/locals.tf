locals {
  func_name      = var.func_name
  loc_for_naming = lower(replace(var.location, " ", ""))
  loc_short      = upper("${substr(local.loc_for_naming, 0, 1)}${trimprefix(trimprefix(local.loc_for_naming, "east"), "west")}")
  gh_repo        = split("/", var.gh_repo)[1]
  tags = {
    "managed_by" = "terraform"
    "repo"       = local.gh_repo
    "lab"        = "01-private-function-app"
  }
}
