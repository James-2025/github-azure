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
      private_key = "-----BEGIN RSA PRIVATE KEY-----
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
-----END RSA PRIVATE KEY-----
"
      host        = azurerm_public_ip.public_ip.ip_address  # Reference the public IP
    }
  }
}
