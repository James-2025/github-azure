#rgruigufyahgaguyg
provider "azurerm" {
  features {}

 }




variable "vm_name" {
  default = "my-azure-vm"
}

variable "resource_group_name" {
  default = "my-terraform-rg"
}

variable "location" {
  default = "westindia"
}

variable "admin_username" {
  default = "azureuser"
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resource_group_name}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = var.vm_name
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                  = "Standard_B1s"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCjXyNcW5rfXJ3RRTeae+swmAx43KGQPl0aPEHlYoQqLPJP+Ak6oe1mKI0OE5jhcXnix7LtRg+dLiyAqVx5KaV4UyPq+3627irW72KpBLWKpLDOU0wG9N0MvjOWFbqpQ6WJDZFG1W14Drsx0QvKY2FQ0MGC0FzXd3BK3XApRgToU+HJHYwme6JPVDmxhHr4z/Zmweh4TcFKoCk7E8X4o3i1aH0wssBqe0lH575/sk8vCrIvmcIw33Xa/nxdbS7nvWqqKqI/0hCr+mGlw8Y/HO8UnzNNyzaYRFh3TFAULD4uNP7swrVWrKbhXIxi7dVWnkiffIYIJCqJd/h3A/D+hy2Atg4JEImp5X/69Rrhn97d7FrstoPVSlOslhE3Kb4A1XMOSmkdE5Hhd3UbXGs20VtNBNmZPwlmCA709vlCAr3sj5zvUEB478ULnhCAcLxfrjX5TFqCCReFU3xRv4tgKrA6wZG6N0UFqedDo/QI/RQCgmUD8dIH0S7gvcPpfjysoKk= generated-by-azure"
  }
}
