# storageAccount.sh1
# Version: 0.0.1
# Plik nie jest przeznaczony do uruchamiania jako pełnoprawny skrypt, to zapis instrukcji, które powinny być wykonywane krok po kroku

# Login - omiń w przypadku cloud shell
# Connect-AzAccount

# Zmienne oraz genereowanie nazw obiektów
$project = "mywg"
$owner = "WG"
$rand = Get-Random -Minimum 1024 -Maximum 10240
$location = "West Europe"
$environment = "dev"
$rgName = $project + "-" + $environment
$saName = $project + $environment + $rand

# Stwórz Resource group
# Zwróć uwagę na przekazane zmienne do parametrów oraz, że parametr Tag nie żywa wprost zmiennej typu string, ale przekazuje obiekt, co możesz poznać po 'zapisie @{}'
New-AzResourceGroup -Location $location -Name $rgName -Tag @{Environment = $environment; Owner=$owner}

# Alternatywnie możesz filtrować wynik poleceniem 
# Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -eq "$rgName"}

# Zapisz parametry Resource Group w zmiennej, aby móc jej używać przy tworzeniu pozostałych zasobów
$myRG = Get-AzResourceGroup -Location $location -Name $rgName

# Storage Account to jeden z kilku zasobów, który musi mieć unikalną nazwę globalnie, wobec czego jedną z praktyk jest dodawanie losowego ciągu znaków
# Wyświetl wygenerowaną nazwę Storage Account
$saName

# PowerShell posiada polecenie do sprawdzenia, czy dana nazwa jest dostępna

# Sprawdź działanie polecenia
Get-AzStorageAccountNameAvailability -name test

# Sprawdź dostępność Twojej nazwy
$saNameAvailability = Get-AzStorageAccountNameAvailability -name $saName
$saNameAvailability

# Jeżeli nazwa jest dostępna, utwórz Storage Account
if ($saNameAvailability.NameAvailable) {
    New-AzStorageAccount -Name $saName -ResourceGroupName $myRG.ResourceGroupName -Location $myRG.Location -SkuName Standard_LRS -Kind StorageV2
}
# A co jeżeli nie?

# Wyświetl dostępne Storage Accounts w Twojej Resource Group
Get-AzStorageAccount -ResourceGroupName $myRG.ResourceGroupName

# Zadanie domowe:
# Wgraj ulubionego mema lub obrazek z kotkiem na swój Storage Account i udostępnij link w postaci SAS URL z parametrem tylko do odczytu
# Dodatkowe pojęcia: Container, Context, SAS
