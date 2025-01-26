# Laboratorium: Infrastruktura Azure z Terraform

> ! NIE DZIAŁA !

## Wymagania wstępne

- Aktywna subskrypcja Azure
- Zainstalowany lokalnie Terraform
- Zainstalowane i skonfigurowane Azure CLI

## Cel

Stworzenie maszyny wirtualnej, która będzie służyć jako terminal do pracy z kontenerami, w tym kubernetes.

## Rozpoczęcie pracy

1. Sklonuj to repozytorium:

```bash
https://github.com/wguzik/devops-cloud-admin-zadania.git
cd windows-terminal
```

1. Zaktualizuj plik `terraform.tfvars` swoimi wartościami:

Przygotuj plik `terraform.tfvars` i wypełnij go swoimi wartościami:

```bash
cp terraform.tfvars.example terraform.tfvars

```
 
```bash
prefix         = "twoj-prefix"    # Prefix dla nazw zasobów
location       = "westeurope"     # Wybrany region Azure
admin_username = "azureuser"      # Nazwa użytkownika administratora VM
```

```bash
subscription_id=$(az account show --query="id")
sed -i "s/YourSubscriptionID/$subscription_id/g" terraform.tfvars
```

1. Zainicjuj Terraform, zweryfikuj konfigurację:
```bash
terraform init
terraform validate
terraform plan
```

1. Wdróż konfigurację:

```bash
terraform apply
```

1. Po zakończeniu wdrożenia możesz znaleźć publiczny adres IP maszyny wirtualnej w Azure Portal lub wykonując:

```bash
terraform output
```

1. Wyciągnij nazwę użytkownika i hasło do maszyny wirtualnej z Terraform:

```bash
az keyvault secret show --vault-name $(terraform output key_vault_name) --name $(terraform output vm_secret_username) --query value -o tsv
az keyvault secret show --vault-name $(terraform output key_vault_name) --name $(terraform output vm_secret_password) --query value -o tsv
```

## Dostęp do maszyny wirtualnej

1. Połącz się z maszyną wirtualną używając protokołu RDP.


2. Zainstaluj narzędzia:



## Sprzątanie

Gdy skończysz pracę z laboratorium, usuń wszystkie utworzone zasoby:
```bash
terraform destroy
```

## Rozwiązywanie problemów

1. Jeśli terraform apply nie powiedzie się:
   - Sprawdź swoje poświadczenia Azure
   - Zweryfikuj, czy Twoja subskrypcja ma wystarczający limit quota
   - Upewnij się, że wybrany region obsługuje wybrany rozmiar VM

2. Jeśli instalacja oprogramowania nie powiedzie się:
   - Sprawdź logi rozszerzeń VM w Azure Portal
   - Zweryfikuj połączenie internetowe z VM
   - Spróbuj ręcznej instalacji w razie potrzeby

## Dodatkowe zasoby

- [Dokumentacja dostawcy Terraform dla Azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Dokumentacja kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [Dokumentacja Helm](https://helm.sh/docs/)

## Wsparcie

W przypadku problemów:
1. Sprawdź sekcję rozwiązywania problemów powyżej
2. Przejrzyj logi w Azure Portal
3. Skonsultuj się z prowadzącym laboratorium
