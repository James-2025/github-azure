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


variable "vm_name" {
  default = "my-azure-vm01"
}

variable "ssh_public_key" {
  description = "The SSH public key used for authentication."
  type        = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDFSz/3f6ccuQsSaMjasW9P+NzYjVaokcqDdZ7nh6n3VlQFCLRBMTIjj82ohQm1bbdlTd38mmhOm8CThar4rfXnnF0UxNhTK41LDp678wepxTK0MkbeaQpgOMdSAOolGvPtKxppbrk7KK65+zeH2J/1pH+4bkwn3kaagnGtZir0uOJRBFAJAUNACplWEbTtYdNQ+TNn7DNeXu9ew+949953bWCVubRUVia+sdF0HPFqMzeGPNZL3PxZMs+uCzNl952pj+wSqOyMMK15+UoPMuLX+KT3iRjigeugaAxSdnhkBVH734DEjk3qb6wpGtFv58zfwbwrVSowMbxTMJyzpc4I9Loq4yuapd6utLGshUSALdUUbCdCFcp+IoDNqFvuSSKRpmPrYJnicrPzKVpLqtwfuRk12p07c5jSIgX7Y0DC5GQi4MNqyfBJVCki8u++vlmLrxAxVcxmNJGQLL2bOuvfYbI0Xd+FzjRadilBoWUUHzloQC/4DnGVGBc6WXokezE= generated-by-azure"
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

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.vm_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "ssh" {
  name                        = "allow-ssh"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg.name
  resource_group_name         = "my-terraform-rg"  # Add this line

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
  network_security_group_id = azurerm_network_security_group.nsg.id


  depends_on = [azurerm_virtual_network.vnet]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "${var.vm_name}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard" 
  allocation_method   = "Static"
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
    network_security_group_id = azurerm_network_security_group.nsg.id

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
      key_data = var.ssh_public_key
    }
  }

  # The provisioners will now reference the public IP address directly
  provisioner "file" {
    source      = "index.html"
    destination = "/tmp/index.html"
    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file(var.private_key_path)
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
      private_key = file(var.private_key_path)
      host        = azurerm_public_ip.public_ip.ip_address  # Reference the public IP
    }
  }
}
