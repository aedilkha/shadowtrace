# 01 · Préparer le PC de bureau (hôte)

À faire **une seule fois**, chez toi. Durée : ~45 min (surtout des téléchargements).

## 1. Vérifier le matériel

| Élément | Minimum | Comment vérifier (Windows) |
|---|---|---|
| RAM | 16 Go | Gestionnaire des tâches > Performances > Mémoire |
| Virtualisation | Activée | Gestionnaire des tâches > Performances > Processeur > « Virtualisation : Activé ». Sinon : BIOS > Intel VT-x / AMD SVM |
| Disque libre | 130 Go (SSD fortement conseillé) | Explorateur |

> **Hyper-V / WSL2 déjà actifs ?** VirtualBox 7 fonctionne quand même (mode « NEM »), mais plus lentement. Si les VM rament fort, désactive « Plateforme de machine virtuelle » et « Hyper-V » dans *Fonctionnalités Windows*, puis redémarre.

## 2. Télécharger (pendant que tu lis la suite)

| Quoi | Où | Taille |
|---|---|---|
| VirtualBox 7.x + Extension Pack | https://www.virtualbox.org/wiki/Downloads | ~120 Mo |
| Ubuntu Server 24.04 LTS (ISO) | https://ubuntu.com/download/server | ~2,6 Go |
| Windows 11 Enterprise, évaluation 90 jours (ISO) | https://www.microsoft.com/evalcenter | ~5,5 Go |
| Git pour Windows | https://git-scm.com/download/win | ~60 Mo |

## 3. Cloner le repo sur l'hôte

```powershell
cd $HOME
git clone https://github.com/aedilkha/shadowtrace
cd shadowtrace
```

## 4. Créer le réseau du lab

PowerShell (pas besoin d'admin) :
```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\infra\virtualbox\create-lab-network.ps1
```
Résultat : un réseau NAT `shadowtrace-net` (10.10.10.0/24) et des redirections de ports : le dashboard Wazuh sera sur **https://localhost:8443**, le SSH vers la VM Ubuntu sur `localhost:2222`.

## 5. Créer les VM

```powershell
.\infra\virtualbox\create-vms.ps1 -UbuntuIso "C:\ISO\ubuntu-24.04-live-server-amd64.iso" -WindowsIso "C:\ISO\Win11_Eval.iso"
```
Si le script échoue (version de VirtualBox différente), crée-les à la main dans l'interface avec ces valeurs :

| | st-wazuh | st-ws-fin-042 |
|---|---|---|
| Type | Linux / Ubuntu 64-bit | Windows 11 64-bit |
| RAM / vCPU | 5120 Mo / 2 | 5120 Mo / 2 |
| Disque | 50 Go VDI dynamique | 64 Go VDI dynamique |
| Réseau | Carte 1 : *Réseau NAT* > `shadowtrace-net` | idem |
| Spécial | — | EFI + TPM 2.0 + Secure Boot (Système > Carte mère) |

Suite : [02-lab-build.md](02-lab-build.md).
