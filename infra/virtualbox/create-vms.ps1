<#
.SYNOPSIS
  Crée les deux VM du lab (Ubuntu Wazuh + Windows 11 victime) dans VirtualBox.
.DESCRIPTION
  A lancer sur l'HÔTE après create-lab-network.ps1.
  Les ISO ne sont pas dans le repo (trop gros, licences) : télécharge-les puis passe leurs chemins.
    - Ubuntu Server 24.04 LTS : https://ubuntu.com/download/server
    - Windows 11 Enterprise (évaluation 90 jours) : https://www.microsoft.com/evalcenter
  Si une commande échoue (version de VirtualBox différente), crée la VM à la main avec
  les mêmes valeurs : voir docs/01-host-setup.md.
.EXAMPLE
  .\infra\virtualbox\create-vms.ps1 -UbuntuIso D:\ISO\ubuntu-24.04-live-server-amd64.iso -WindowsIso D:\ISO\Win11_Enterprise_Eval.iso
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string]$UbuntuIso,
  [Parameter(Mandatory)] [string]$WindowsIso,
  [string]$NetName   = "shadowtrace-net",
  [int]$UbuntuRamMB  = 5120,
  [int]$WindowsRamMB = 5120,
  [string]$VmFolder  = "$env:USERPROFILE\VirtualBox VMs\ShadowTrace"
)
$ErrorActionPreference = "Stop"
$vbm = Join-Path $env:ProgramFiles "Oracle\VirtualBox\VBoxManage.exe"

function New-LabVm {
  param($Name, $OsType, $RamMB, $Cpus, $DiskGB, $Iso, [switch]$Win11)
  if (& $vbm list vms | Select-String -SimpleMatch "`"$Name`"") { Write-Host "$Name existe déjà, ignorée."; return }

  & $vbm createvm --name $Name --ostype $OsType --basefolder $VmFolder --register
  & $vbm modifyvm $Name --memory $RamMB --cpus $Cpus --vram 32 `
      --nic1 natnetwork --nat-network1 $NetName `
      --audio-enabled off --usb-ohci off --clipboard-mode bidirectional --graphicscontroller vmsvga
  if ($Win11) {
    # Windows 11 exige UEFI + TPM 2.0 + Secure Boot
    & $vbm modifyvm $Name --firmware efi --tpm-type 2.0 --graphicscontroller vboxsvga
    & $vbm modifynvram $Name inituefivarstore
    & $vbm modifynvram $Name enrollmssignatures
    & $vbm modifynvram $Name enrollorclpk
  }
  $disk = Join-Path $VmFolder "$Name\$Name.vdi"
  & $vbm createmedium disk --filename $disk --size ($DiskGB * 1024) --format VDI
  & $vbm storagectl $Name --name "SATA" --add sata --controller IntelAhci --portcount 2
  & $vbm storageattach $Name --storagectl "SATA" --port 0 --device 0 --type hdd --medium $disk
  & $vbm storageattach $Name --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $Iso
  Write-Host "VM $Name créée ($RamMB Mo, $Cpus vCPU, $DiskGB Go)."
}

New-LabVm -Name "st-wazuh"      -OsType "Ubuntu_64"   -RamMB $UbuntuRamMB  -Cpus 2 -DiskGB 50 -Iso $UbuntuIso
New-LabVm -Name "st-ws-fin-042" -OsType "Windows11_64" -RamMB $WindowsRamMB -Cpus 2 -DiskGB 64 -Iso $WindowsIso -Win11

Write-Host "`nDémarre st-wazuh en premier et installe Ubuntu (voir docs/02-lab-build.md, étape 2)."
