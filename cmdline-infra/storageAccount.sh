# storageAccount.sh
# Version: 0.0.1
# Plik nie jest przeznaczony do uruchamiania jako pełnoprawny skrypt, to zapis instrukcji, które powinny być wykonywane krok po kroku

# Login - omiń w przypadku cloud shell
# az login

# Zmienne oraz genereowanie nazw obiektów
PROJECT="wsbwg"
OWNER="WG"
LOCATION="westeurope"
ENVIRONMENT="dev"
RGNAME=$PROJECT"-"$ENVIRONMENT
SANAME=$PROJECT$ENVIRONMENT$RANDOM

# Stwórz Resource group
# Zwróć uwagę na przekazane zmienne do parametrów oraz, że parametr Tag nie żywa wprost zmiennej typu string, ale przekazuje obiekt, co możesz poznać po 'zapisie @{}'
az group create --location $LOCATION --name $RGNAME --tags Environment=$ENVIRONMENT Owner=$OWNER

# Alternatywnie możesz filtrować wynik poleceniem 
az group list --query "[?location=='westeurope']" -o tsv
# az group list | grep $RGNAME

# Zapisz parametry Resource Group w zmiennej, aby móc jej używać przy tworzeniu pozostałych zasobów
# Jest to redundatne i tym miejscu służy do pokazania funkcjonalności
RGLOCATION=$(az group show --resource-group $RGNAME --query location -o tsv)

# Storage Account to jeden z kilku zasobów, który musi mieć unikalną nazwę globalnie, wobec czego jedną z praktyk jest dodawanie losowego ciągu znaków
# Wyświetl wygenerowaną nazwę Storage Account
echo $SANAME

# AZ CLI posiada polecenie do sprawdzenia, czy dana nazwa jest dostępna

# Sprawdź działanie polecenia
az storage account check-name --name test

# Sprawdź dostępność Twojej nazwy
SANAMEAVAILABILITY=$(az storage account check-name --name $SANAME --query nameAvailable)
echo $SANAMEAVAILABILITY

# Jeżeli nazwa jest dostępna, utwórz Storage Account
if [ $SANAMEAVAILABILITY ]; then
  az storage account create --name $SANAME --resource-group $RGNAME --location $RGLOCATION --sku Standard_LRS
fi
# A co jeżeli nie?

# Wyświetl dostępne Storage Accounts w Twojej Resource Group
az storage account list -o tsv

# Zadanie domowe:
# Wgraj ulubionego mema lub obrazek z kotkiem na swój Storage Account i udostępnij link w postaci SAS URL z parametrem tylko do odczytu
# Dodatkowe pojęcia: Container, Context, SAS