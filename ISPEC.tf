provider "azurerm" {
    subscription_id = "${var.Subscription_ID}"
    client_id       = "${var.Client_ID}"
    client_secret   = "${var.Client_Secret}"
    tenant_id       = "${var.Tenant_ID}"
}

#######################################################################
#######################   RESOURCE GROUP   ############################
#######################################################################
resource "azurerm_resource_group" "PRD" {
    name = "${var.Resource_Group}"
    location = "${var.Location}"
}
data "azurerm_resource_group" "dpwhorgnw" {
  name = "dpwhorgnw"
}
#######################################################################
##############################   NETWORK   ############################
#######################################################################
data "azurerm_subnet" "subnet" {
  name = "${var.Subnet_name}"
  virtual_network_name = "dpwhonetwork"
  resource_group_name = "dpwhorgnw"
}
resource "azurerm_network_interface" "ispecnic" {
  name = "${var.nic_name}"
  location = "${azurerm_resource_group.PRD.location}"
  resource_group_name = "${data.azurerm_resource_group.dpwhorgnw.name}"

  ip_configuration {
    name                          = "${var.ip_conf}"
    subnet_id                     = "${data.azurerm_subnet.subnet.id}"
    private_ip_address_allocation = "dynamic"
  }
}
#######################################################################
#############################  STORAGE OS  ############################
#######################################################################
resource "azurerm_storage_account" "storage" {
  name = "${var.Storage_AccountName}"
  resource_group_name = "${azurerm_resource_group.PRD.name}"
  location = "${azurerm_resource_group.PRD.location}"
  account_tier = "Premium"
  account_replication_type = "LRS"
}
resource "azurerm_storage_container" "disks" {
  name                  = "vhds"
  resource_group_name   = "${azurerm_resource_group.PRD.name}"
  storage_account_name  = "${azurerm_storage_account.storage.name}"
  container_access_type = "private"
}
#######################################################################
#############################  STORAGE DATA  ############################
#######################################################################
resource "azurerm_storage_account" "storageData" {
  name = "${var.Storagedata_AccountName}"
  resource_group_name = "${azurerm_resource_group.PRD.name}"
  location = "${azurerm_resource_group.PRD.location}"
  account_tier = "Standard"
  account_replication_type = "LRS"
}
resource "azurerm_storage_container" "datadisks" {
  name                  = "vhds"
  resource_group_name   = "${azurerm_resource_group.PRD.name}"
  storage_account_name  = "${azurerm_storage_account.storageData.name}"
  container_access_type = "private"
}
locals {
  storage_account_base_uri = "${azurerm_storage_account.storage.primary_blob_endpoint}${azurerm_storage_container.disks.name}"
  storage_accountdata_base_uri = "${azurerm_storage_account.storageData.primary_blob_endpoint}${azurerm_storage_container.datadisks.name}"
}

#######################################################################
#####################    VIRTUAL MACHINE   ############################
#######################################################################
resource "azurerm_virtual_machine" "VM" {
  name = "${var.vm_name}"
  location = "${azurerm_resource_group.PRD.location}"
  resource_group_name = "${azurerm_resource_group.PRD.name}"
  network_interface_ids = ["${azurerm_network_interface.ispecnic.id}"]
  vm_size = "${var.vm_size}"

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${var.disk_name}_os"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    disk_size_gb = "200"
    vhd_uri       = "${local.storage_account_base_uri}/${var.disk_name}_os.vhd" 
    #managed_disk_type = "StandardSSD_LRS"
  }
  storage_data_disk {
    name          = "${var.disk_name}-1"
    vhd_uri       = "${local.storage_accountdata_base_uri}/${var.disk_name}-1.vhd"
    disk_size_gb  = "500"
    create_option = "Empty"
    lun           = "0"
  }
  storage_data_disk {
    name          = "${var.disk_name}-2"
    vhd_uri       = "${local.storage_accountdata_base_uri}/${var.disk_name}-2.vhd"
    disk_size_gb  = "500"
    create_option = "Empty"
    lun           = "1"
  }
  storage_data_disk {
    name          = "${var.disk_name}-3"
    vhd_uri       = "${local.storage_accountdata_base_uri}/${var.disk_name}-3.vhd"
    disk_size_gb  = "500"
    create_option = "Empty"
    lun           = "2"
  }
  storage_data_disk {
    name          = "${var.disk_name}-4"
    vhd_uri       = "${local.storage_accountdata_base_uri}/${var.disk_name}-4.vhd"
    disk_size_gb  = "500"
    create_option = "Empty"
    lun           = "3"
  }
  os_profile {
    computer_name  = "${var.vm_name}"
    admin_username = "gobinath"
    admin_password = "Mageswaran225"
  }
 os_profile_windows_config {
    provision_vm_agent = true
  }
  license_type = "Windows_Server"
}

resource "azurerm_virtual_machine_extension" "DP" {
  name                 = "custom"
  location             = "${azurerm_resource_group.PRD.location}"
  resource_group_name  = "${azurerm_resource_group.PRD.name}"
  virtual_machine_name = "${azurerm_virtual_machine.VM.name}"
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"
  protected_settings = <<PROTECTED_SETTINGS
  {
  "storageAccountName": "dpwhostrgbak",
  "storageAccountKey": "4EPVsMhekjxcoaWs9nNrgBWBf7sdO3CKloodwry+uC4mhlZ8PfEEZsBpjY3Sq00abN0X8JVOVlrIHKwpWm8awA=="
  }
  PROTECTED_SETTINGS
    settings = <<SETTINGS
    {
        "fileUris": [
                "https://dpwhostrgbak.blob.core.windows.net/vhds/joindomain.ps1"
            ],
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File joindomain.ps1"
    }
SETTINGS
}
################END###############3