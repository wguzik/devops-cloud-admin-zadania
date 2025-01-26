# devops-cloud-admin-zadania
Repozytorium z zadaniami z obszaru DevOps i Azure Cloud

# Laboratorium: Infrastruktura Azure z Terraform

## Wymagania wstępne

- Aktywna subskrypcja Azure
- Zainstalowany lokalnie Terraform
- Zainstalowane i skonfigurowane Azure CLI

## Przegląd laboratorium

To laboratorium przeprowadzi Cię przez proces tworzenia infrastruktury Azure przy użyciu Terraform, w tym:
- Sieć wirtualna (Virtual Network)
- Maszyna wirtualna Windows z 4 procesorami
- Publiczny adres IP
- Preinstalowane narzędzia (kubectl i Helm)

## Rozpoczęcie pracy

1. Sklonuj to repozytorium:
```bash
git clone <adres-repozytorium>
cd <nazwa-repozytorium>
```

2. Zaktualizuj plik `terraform.tfvars` swoimi wartościami:
```hcl
prefix         = "twoj-prefix"    # Prefix dla nazw zasobów
location       = "westeurope"     # Wybrany region Azure
admin_username = "azureuser"      # Nazwa użytkownika administratora VM
admin_password = "TwojeB@rdzoSilneHaslo123!"  # Hasło administratora VM (musi spełniać wymagania Azure)
```

3. Zainicjuj Terraform:
```bash
terraform init
```

4. Przejrzyj planowane zmiany:
```bash
terraform plan
```

5. Wdróż konfigurację:
```bash
terraform apply
```

6. Po zakończeniu wdrożenia możesz znaleźć publiczny adres IP maszyny wirtualnej w Azure Portal lub wykonując:
```bash
terraform output public_ip
```

## Dostęp do maszyny wirtualnej

1. Połącz się z maszyną wirtualną używając protokołu RDP (Pulpit Zdalny):
   - Użyj publicznego adresu IP
   - Nazwa użytkownika: wartość z admin_username w terraform.tfvars
   - Hasło: wartość z admin_password w terraform.tfvars

2. Preinstalowane narzędzia:
   - kubectl (interfejs wiersza poleceń Kubernetes)
   - Helm (menedżer pakietów Kubernetes)

3. Weryfikacja instalacji:
```powershell
kubectl version --client
helm version
```

## Sprzątanie

Gdy skończysz pracę z laboratorium, usuń wszystkie utworzone zasoby:
```bash
terraform destroy
```

## Uwagi dotyczące bezpieczeństwa

- Zmień domyślne hasło w terraform.tfvars
- Rozważ użycie Azure Key Vault dla wrażliwych danych
- Maszyna wirtualna jest dostępna z internetu przez publiczny IP - rozważ dodanie reguł NSG
- W środowisku produkcyjnym rozważ:
  - Włączenie szyfrowania dysków
  - Użycie hosta bastion
  - Wdrożenie bardziej restrykcyjnych reguł bezpieczeństwa sieci

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
