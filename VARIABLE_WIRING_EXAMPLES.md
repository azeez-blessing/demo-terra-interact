# Example: Different environments with different values

# DEV Environment (03-env/dev1/main.tf)
module "base_infrastructure" {
  source = "../../02-mod-base"
  
  environment     = "dev"
  instance_count  = 1
  enable_backup   = false
  enable_auto_scaling = false
}

# PROD Environment (03-env/prod/main.tf)  
module "base_infrastructure" {
  source = "../../02-mod-base"
  
  environment     = "prod"
  instance_count  = 3
  enable_backup   = true
  enable_auto_scaling = true
  min_size       = 2
  max_size       = 10
}