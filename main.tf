# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}
resource "azurerm_resource_group" "bd-rg" {
  name     = "bd-resources"
  location = "East Us"
  tags = {
    environment = "dev"
  }

}
#virtualnetwork
resource "azurerm_virtual_network" "bd-vn" {
  name                = "bd-network"
  resource_group_name = azurerm_resource_group.bd-rg.name
  location            = azurerm_resource_group.bd-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev"
  }

}
#subnet resource creation
resource "azurerm_subnet" "bd-subnet" {
  name                 = "bd-subnet"
  resource_group_name  = azurerm_resource_group.bd-rg.name
  virtual_network_name = azurerm_virtual_network.bd-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}
#resource network security group
resource "azurerm_network_security_group" "bd-sg" {
  name                = "bd-sg"
  location            = azurerm_resource_group.bd-rg.location
  resource_group_name = azurerm_resource_group.bd-rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "bd-dev-rule" {
  name                        = "bd-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*" #add public ip here whatever you have
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.bd-rg.name
  network_security_group_name = azurerm_network_security_group.bd-sg.name
}
resource "azurerm_subnet_network_security_group_association" "bd-sga" {
  subnet_id                 = azurerm_subnet.bd-subnet.id
  network_security_group_id = azurerm_network_security_group.bd-sg.id
}
#resource public ip 
resource "azurerm_public_ip" "bd-ip" {
  name                = "bd-ip"
  resource_group_name = azurerm_resource_group.bd-rg.name
  location            = azurerm_resource_group.bd-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

#create network interface and attch to vm  in order to provide netwrok connectivity and will receive public ip
resource "azurerm_network_interface" "bd-nic" {
  name                = "bd-nic"
  location            = azurerm_resource_group.bd-rg.location
  resource_group_name = azurerm_resource_group.bd-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.bd-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bd-ip.id
  }
  tags = {
    environment = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "bd-vm" {
  name                  = "bd-vm"
  resource_group_name   = azurerm_resource_group.bd-rg.name
  location              = azurerm_resource_group.bd-rg.location
  size                  = "Standard_F2"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.bd-nic.id]

  #######*******************################
  custom_data = filebase64("custumdata.tpl") #custumdata file is under the same directory so no change
  ########################################
  #private ip found but no public so ,
  #ssh creation so that we can  provisions a basic Linux Virtual Machine on an internal network
  #  #terarform file path is used here and also ssh-keygen -t rsa and also provide rename and provide the rename file 

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/mtcazurekey.pub")


  }

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

  tags = {
    environment = "dev"
  }
}
#use  ssh -i ~/.ssh/mtcazurekey adminuser@public-ip

##******************************
##utilize the custom data argument to bootstrap instances and install docker engine 
##this will help to have linux vm instance for our development need


