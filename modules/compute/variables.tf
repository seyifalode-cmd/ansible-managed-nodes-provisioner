#-----compute/variables.tf-----
#===============================
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "ssh_key_public" {
  type    = string
  #Replace this with the location of you public key .pub
  default = "~/.ssh/lab_ansible_key.pub"
}

variable "subnet_ips" {}

variable "security_group" {}

variable "subnets" {}
