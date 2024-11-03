terraform {
  backend "azurerm" {
    resource_group_name   = "terraform-backend"
    storage_account_name  = "backend01"
    container_name        = "tfstate"
    key                   = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

variable "azure_ssh_private_key" {
  type      = string
  sensitive = true
}

variable "vm_name" {
  default = "my-azure-vm01"
}

variable "resource_group_name" {
  default = "my-terraform-rg"
}

variable "location" {
  default = "westus2"
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

  depends_on = [azurerm_virtual_network.vnet]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "${var.vm_name}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id  # Associate with public IP
  }
}

resource "azurerm_virtual_machine" "vm" {
  name                  = var.vm_name
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_D2s_v3"

  storage_os_disk {
    name              = "${var.vm_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = var.vm_name
    admin_username = var.admin_username
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = var.azure_ssh_private_key  # Use the variable for the SSH key
    }
  }

  # The provisioners will now reference the public IP address directly
  provisioner "file" {
    source      = "index.html"
    destination = "/tmp/index.html"
    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = var.azure_ssh_private_key
      host        = azurerm_public_ip.public_ip.ip_address  # Reference the public IP
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install -y apache2",
      "sudo mv /tmp/index.html /var/www/html/index.html",
      "sudo chown www-data:www-data /var/www/html/index.html",
      "sudo systemctl start apache2",
      "sudo systemctl enable apache2"
    ]
    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = var.azure_ssh_private_key
      host        = azurerm_public_ip.public_ip.ip_address  # Reference the public IP
    }
  }
}
