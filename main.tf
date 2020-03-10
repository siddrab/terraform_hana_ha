provider "azurerm" {
  version = "=2.0.0"
  features {}
}

data "azurerm_resource_group" "rg" {
  name = "${var.rg}"
}
data "azurerm_subnet" "subnet" {
  name                 = var.subnetname
  virtual_network_name = var.vnetname
  resource_group_name  = var.networkrg
}

resource "azurerm_availability_set" "avsethana" {
  name                          = var.avsethana
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = data.azurerm_resource_group.rg.name
  platform_update_domain_count  = 2
  platform_fault_domain_count   = 2
 
}

resource "azurerm_lb" "example" {
  name                = "HANA_LB"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "standard"

  frontend_ip_configuration {
    name                           = "FrontEndIPAddress"
    subnet_id                      = data.azurerm_subnet.subnet.id
    private_ip_address_allocation  = "dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "example" {
  resource_group_name = data.azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.example.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "example" {
  resource_group_name = data.azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.example.id
  name                = "ssh-running-probe"
  port                = 62000+var.hanainstanceno
}

resource "azurerm_lb_rule" "ascs" {
  resource_group_name            = data.azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.example.id
  name                           = "LBRule"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = "FrontEndIPAddress"
  enable_floating_ip             = true
  backend_address_pool_id        = azurerm_lb_backend_address_pool.example.id
  probe_id                       = azurerm_lb_probe.example.id
}

module "hanavm1" {
  source         = "./modules/compute"
  rg             = data.azurerm_resource_group.rg.name
  networkrg      = var.networkrg
  vnetname       = var.vnetname
  subnetname     = var.subnetname
  datadisksize   = var.datadisksize
  datadiskcount  = var.datadiskcount
  logdisksize    = var.logdisksize
  logdiskcount   = var.logdiskcount
  logdiskwa      = var.logdiskwa
  vmsize         = var.vmsize
  vmname         = var.hanavmname1
  ospublisher    = var.ospublisher
  osoffer        = var.osoffer
  ossku          = var.ossku
  osversion      = var.osversion
  admin          = var.admin
  password       = var.password
  avset_id       = azurerm_availability_set.avsethana.id
  backend_ip_id  = azurerm_lb_backend_address_pool.example.id
}

module "hanavm2" {
  source         = "./modules/compute"
  rg             = data.azurerm_resource_group.rg.name
  networkrg      = var.networkrg
  vnetname       = var.vnetname
  subnetname     = var.subnetname
  datadisksize   = var.datadisksize
  datadiskcount  = var.datadiskcount
  logdisksize    = var.logdisksize
  logdiskcount   = var.logdiskcount
  logdiskwa      = var.logdiskwa
  vmsize         = var.vmsize
  vmname         = var.hanavmname2
  ospublisher    = var.ospublisher
  osoffer        = var.osoffer
  ossku          = var.ossku
  osversion      = var.osversion
  admin          = var.admin
  password       = var.password
  avset_id       = azurerm_availability_set.avsethana.id
  backend_ip_id  = azurerm_lb_backend_address_pool.example.id
}