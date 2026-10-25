variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "my_ip_cidr" {
  description = "Your public IPv4 address in CIDR form, for example 203.0.113.10/32"
  type        = string
}
