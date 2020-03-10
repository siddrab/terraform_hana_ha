# refer to a resource group
data "azurerm_resource_group" "rg" {
  name = "${var.rg}"
}

#refer to a subnet
data "azurerm_subnet" "subnet" {
  name                 = "${var.subnetname}"
  virtual_network_name = "${var.vnetname}"
  resource_group_name  = "${var.networkrg}"
}

# Create public IPs
resource "azurerm_public_ip" "pip" {
    name                         = "${var.vmname}_pip"
    location                     = data.azurerm_resource_group.rg.location
    resource_group_name          = data.azurerm_resource_group.rg.name
    allocation_method            = "Dynamic"

}
# create a primary network interface
resource "azurerm_network_interface" "primary" {
  name                = "${var.vmname}_nic_1"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                                     = "${var.vmname}_ipconfig"
    subnet_id                                = data.azurerm_subnet.subnet.id
    private_ip_address_allocation            = "dynamic"
    primary                                  = true
  }
}
# create a secondary network interface
resource "azurerm_network_interface" "secondary" {
  name                = "${var.vmname}_nic_2"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                                     = "${var.vmname}_ipconfig"
    subnet_id                                = data.azurerm_subnet.subnet.id
    private_ip_address_allocation            = "dynamic"
    primary                                  = false
  }
}
#Create disk
resource "azurerm_managed_disk" "datadisk" {
  name                 = "${var.vmname}_datadisk_${count.index}"
  location             = data.azurerm_resource_group.rg.location
  resource_group_name  = data.azurerm_resource_group.rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.datadisksize
  count                = var.datadiskcount
}
resource "azurerm_managed_disk" "logdisk" {
  name                 = "${var.vmname}_logdisk"
  location             = data.azurerm_resource_group.rg.location
  resource_group_name  = data.azurerm_resource_group.rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.logdisksize
}
# Create virtual machine
resource "azurerm_virtual_machine" "vm" {
    name                  = var.vmname
    location              = azurerm_network_interface.primary.location
    resource_group_name   = data.azurerm_resource_group.rg.name
    primary_network_interface_id = azurerm_network_interface.primary.id
    network_interface_ids = ["${azurerm_network_interface.secondary.id}"]
    vm_size               = var.vmsize
    availability_set_id   = var.avset_id
    
# Uncomment this line to delete the OS disk automatically when deleting the VM
delete_os_disk_on_termination = true

# Uncomment this line to delete the data disks automatically when deleting the VM
delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "${var.ospublisher}"
    offer     = "${var.osoffer}"
    sku       = "${var.ossku}"
    version   = "${var.osversion}"
  }
   storage_os_disk {
    name              = "${var.vmname}_osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }
  
   os_profile {
    computer_name  = var.vmname
    admin_username = var.admin
    admin_password = var.password
  }
   os_profile_linux_config {
    disable_password_authentication = false
  }

}
resource "azurerm_virtual_machine_data_disk_attachment" "datadisk" {
  count              = var.datadiskcount
  managed_disk_id    = element(azurerm_managed_disk.datadisk.*.id, count.index)
  virtual_machine_id = azurerm_virtual_machine.vm.id
  lun                = count.index
  caching            = "ReadOnly"
}
resource "azurerm_network_interface_backend_address_pool_association" "example" {
  network_interface_id    = azurerm_network_interface.primary.id
  ip_configuration_name   = "${var.vmname}_ipconfig"
  backend_address_pool_id = var.backend_ip_id
}
resource "azurerm_virtual_machine_data_disk_attachment" "logdisk" {
  managed_disk_id    = "${azurerm_managed_disk.logdisk.id}"
  virtual_machine_id = azurerm_virtual_machine.vm.id
  lun                = var.datadiskcount+1
  caching            = "None"
  write_accelerator_enabled = var.logdiskwa
}
