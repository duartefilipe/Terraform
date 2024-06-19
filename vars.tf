variable "os_type" {
  description = "The operating system type: windows or linux"
  type        = string
  default     = "linux"
}

variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type = string
}

# resource vars
variable "proxmox_host" {
  type    = string
  default = "anakin"
}

variable "template_name" {
  type    = string
  default = "Template"
}

variable "ansible_user" {
  default = "anakin"
  type    = string
}

# Caminho para os arquivos de chave SSH
variable "private_key_path" {
  description = "Path to the private key for SSH access"
  type        = string
  default     = "terraform"
}

variable "public_key_path" {
  description = "Path to the public key for SSH access"
  type        = string
  default     = "terraform.pub"
}
