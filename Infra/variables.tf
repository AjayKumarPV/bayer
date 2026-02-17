variable "aws_region" {
  default = "ap-south-2"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  default = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  default = "10.0.2.0/24"
}

variable "private_subnet_a_cidr" {
  default = "10.0.3.0/24"
}

variable "private_subnet_b_cidr" {
  default = "10.0.4.0/24"
}

variable "my_ip" {
  description = "Public IP for SSH access"
}

variable "key_name" {
  description = "Name of existing AWS EC2 Key Pair"
  type        = string
}

