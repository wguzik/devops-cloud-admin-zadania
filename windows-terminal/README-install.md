# Instrukcja instalacji

## Azure CLI
```powershell
# Pobranie i uruchomienie instalatora Azure CLI
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://aka.ms/installazurecli -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
Remove-Item .\AzureCLI.msi

# Weryfikacja instalacji
az --version
```

## Terraform
```powershell
# Utworzenie katalogu na Terraform
New-Item -Path 'C:\terraform' -ItemType Directory -Force

# Pobranie i rozpakowanie Terraform
$terraformVersion = "1.7.4"
$terraformUrl = "https://releases.hashicorp.com/terraform/${terraformVersion}/terraform_${terraformVersion}_windows_amd64.zip"
Invoke-WebRequest -Uri $terraformUrl -OutFile "terraform.zip"
Expand-Archive -Path "terraform.zip" -DestinationPath "C:\terraform" -Force
Remove-Item -Path "terraform.zip"

# Dodanie Terraform do PATH
$currentPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
if ($currentPath -notlike '*C:\terraform*') {
    [Environment]::SetEnvironmentVariable('Path', $currentPath + ';C:\terraform', 'Machine')
}

# Weryfikacja instalacji
terraform --version
```

## Docker Desktop

```powershell
# Pobranie i instalacja Docker Desktop
Invoke-WebRequest -Uri "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe" -OutFile "DockerDesktopInstaller.exe"
Start-Process -Wait -FilePath ".\DockerDesktopInstaller.exe" -ArgumentList "install --quiet"
Remove-Item -Path "DockerDesktopInstaller.exe"

# Weryfikacja instalacji (wymaga restartu systemu)
docker --version
```

### Uwagi
   - Wymagany jest restart systemu
   - Przy pierwszym uruchomieniu należy zaakceptować warunki licencji
   - Może być wymagane włączenie funkcji WSL 2 i Hyper-V

## Kubectl
```powershell
# Utworzenie katalogu na kubectl
New-Item -Path 'C:\kubectl' -ItemType Directory -Force

# Pobranie i instalacja kubectl
Invoke-WebRequest -Uri "https://dl.k8s.io/release/v1.31.0/bin/windows/amd64/kubectl.exe" -OutFile "C:\kubectl\kubectl.exe"

# Dodanie kubectl do PATH
$currentPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
if ($currentPath -notlike '*C:\kubectl*') {
    [Environment]::SetEnvironmentVariable('Path', $currentPath + ';C:\kubectl', 'Machine')
}

# Weryfikacja instalacji
kubectl version --client
```

## Helm
```powershell
# Pobranie i rozpakowanie Helm
Invoke-WebRequest -Uri "https://get.helm.sh/helm-v3.13.3-windows-amd64.zip" -OutFile "helm.zip"
Expand-Archive -Path "helm.zip" -DestinationPath "C:\helm" -Force
Move-Item -Path "C:\helm\windows-amd64\helm.exe" -Destination "C:\helm" -Force
Remove-Item -Path "C:\helm\windows-amd64" -Recurse
Remove-Item -Path "helm.zip"

# Dodanie Helm do PATH
$currentPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
if ($currentPath -notlike '*C:\helm*') {
    [Environment]::SetEnvironmentVariable('Path', $currentPath + ';C:\helm', 'Machine')
}

# Weryfikacja instalacji
helm version
```

## Uwagi

1. Weryfikacja instalacji:

```powershell
# Sprawdzenie wszystkich zainstalowanych narzędzi
az --version
terraform --version
docker --version
kubectl version --client
helm version
```

2. Rozwiązywanie problemów:
   - Jeśli polecenia nie są rozpoznawane, uruchom ponownie PowerShell
   - Sprawdź, czy ścieżki zostały poprawnie dodane do PATH
   - W przypadku problemów z Docker Desktop, upewnij się, że:
     - System spełnia wymagania (Windows 10/11 Pro lub Enterprise)
     - WSL 2 jest zainstalowany i skonfigurowany
     - Funkcja Hyper-V jest włączona

3. Dodatkowe konfiguracje:
   - Azure CLI: `az login`
   - Docker Desktop: Może wymagać dodatkowej konfiguracji w zależności od potrzeb
   - Kubectl: Wymaga konfiguracji kontekstu klastra (zazwyczaj poprzez `az aks get-credentials`)