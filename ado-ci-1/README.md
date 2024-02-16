# Lab: Konfiguracja Continuous Integration and Delivery w Azure DevOps

## Wymagania

- Aktywne konto w Azure DevOps z możliwością uruchamiania Pipelines.

> Nie masz konta w Azure? [Załóż darmowe konto](https://learn.microsoft.com/en-us/azure/devops/user-guide/sign-up-invite-teammates?view=azure-devops&tabs=microsoft-account) (po założeniu konta i próbie uruchomienia pipeline trzeba wypełnić formularz, aby mieć dostęp do darmowych minut, opcjonalnie można stworzyć własny runner).

- Konto GitHub

## Wstęp

Proces Continuous Integration składa się z kilku etapów, ale zazwyczaj kluczowe zadania to zbudowanie i przetestowanie aplikacji.

Proces Contiunous Delivery zazwyczaj kończy się na etapie opublikowania aplikacji (np. jako obraz kontenera), niekoniecznie jest wdrożeniem (deployment).

## Cel

Stwórz podstawowy proces Continuous Integration/Delivery korzystający z Artifactory oraz Azure Container Registry.

## Krok 1

Zrób fork repozytorium [swapi-caching](https://github.com/wguzik/swapi-caching/fork)

## Krok 2

Sklonuj repozytorium lokalnie:

```bash
git clone https://github.com/<your-gh-org>/swapi-caching.git
```

Odtwórz zmienne środowiskowe (`.env`) i uruchom docker-compose aby zweryfkować czy aplikacja działa:
```bash
mv .env.example .env
docker-compose up
```

## Krok 3

Zmień branch, będziesz na nim wprowadzać zmiany.

```bash
git checkout -b feature/ci-development
```

## Krok 4

Jeżeli nie posiadasz, załóż [organizację w Azure DevOps](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/create-organization?view=azure-devops).

Załóż [prywatny projekt](https://learn.microsoft.com/en-us/azure/devops/organizations/projects/create-project?view=azure-devops&tabs=browser#create-a-project) o nazwie `swapi-caching` (lub pokrewnej dla łatwej nawigacji).

## Krok 5

Wybierz z lewego menu "Pipelines" (niebieska rakieta), następnie z prawego górnego rogu "New pipeline".

Z zakładki "Connect" i dostępnych tam opcji wybierz "GitHub".

Z zakładki "Select" wybierz `swapi-caching`.

Z zakładki "Configure" wybierz "Existing Azure Pipelines YAML file" (na samym dole) - z kontekstowego menu wybierz branch "main" i plik `pipeline-ci.yaml`.

Potwierdź wybierając "Continue".

Z zakładki "Review" w prawym górnym rogu wybierz "Run" i obserwuj zachowanie pipeline.

## Krok 6

Stwórz feed dla NPM.

Aplikacje napisane w JavaScript zazwyczaj korzystają z package managera `npm`. Listę niezbędnych bibliotek znajdziesz w pliku `packages.json`. Listę wszystkich zależności znajdzies w `package-lock.json`.
Polecenie `npm install` ściąga i konfiguruje te biblioteki, znajdziesz je lokalnie w katalogu `node_modules` (nie musisz go wykonywać).
Ze względu na wygodę i możliwość kontroli chcesz skorzystać z lokalnego repozytorium, które de facto będzie ściągać paczki z `upstreamu`, ale `npm` będzie się do niego odwoływać.

Taka konfiguracja jest często stosowana, kiedy regularnie ściągasz te same paczki i chcesz je mieć "bliżej" lub istnieją ograniczenia w ruchu sieciowym i dzięki temu nie ściągasz paczek "z internetu", ale z lokalnej instancji.

## Krok 7

[Skonfiguruj feed](https://learn.microsoft.com/en-us/azure/devops/artifacts/get-started-npm?view=azure-devops&tabs=Windows#create-a-feed), ale tylko krok `Create feed`, koniecznie z zaznaczoną opcją "Upstream sources".

W tym momencie w ramach projektu posiadasz własne repozytorium paczek.

Otwórz "Artifacts" i wybierz "Connect to feed" a następnie "npm".

Stwórz plik `.npmrc` głównym katalogu w repozytorium:

```bash
# Mac/Linux
touch .npmrc
```

```PowerShell
# Windows
New-Item -type File -name .npmrc
```

przekopiuj sugerowaną zawartość do niego (coś jak poniżej):

```bash
registry=https://pkgs.dev.azure.com/<yourorg>/swapi-ci/_packaging/<yourfeed>/npm/registry/ 
                        
always-auth=true
```

Nie wykonuj kroków z "Setup credentials". One są przeznaczone dla użytkownika lokalnego. My skorzystamy z konfiguracji dla pipeline.

## Krok 8

Skonfiguruj pipeline tak, aby się odwoływał do repozytorium. Aby to zrobić, najlepiej skorzystać z dedykowanego taska. Upewnij się, że build pipeline ma właściwe uprawnienia. Skorzystaj z tego fragmentu dokumentacji: [pipeline authentication](https://learn.microsoft.com/en-us/azure/devops/artifacts/npm/npmrc?view=azure-devops&tabs=windows%2Cyaml#pipeline-authentication).

Niezbędny task znajduje się już definicji pipeline (linie 31-34):

```yaml
  #- task: npmAuthenticate@0
  #  inputs:
  #    workingFile: .npmrc           
  #    customEndpoint:  
```

odkomentuj ten fragment, zacommituj zmianę i wypchnij na branch.

```bash
git add .
git commit -am "Add npm configuration for local feed"
```

Wejdź na swojego GitHuba i załóż Pull Request.

Na poziomie pipeline powinien się uruchomić job, obserwuj jak jak realizują się kroki.

## Krok 8

Wejdź do "Artifacts" i otwórz swój feed npm. Zauważ, że są widoczne rozmaite paczki. Porównaj nazwy z zawartością `package-lock.json`.

## Krok 9

Obecny w pipeline krok uruchamia docker compose, jednak nigdzie nie zachowujesz tego obrazu:

```yaml
  - task: DockerCompose@0
    displayName: Run Docker-compose-up
    #
      dockerComposeCommand: 'up -d'
```

W Azure DevOps istnieje dedykowany task [Docker@2](https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/docker-v2?view=azure-pipelines&tabs=yaml).


W definicji pipeline znajduje się już zaadaptowany task:

```yaml
## Sekcja Docker push
#  - task: Docker@2
#    displayName: Build and push an image to container registry
#    inputs:
#      command: buildAndPush
#      repository: swapi-caching # efektywnie nazwa aplikacji
#      dockerfile: $(Build.SourcesDirectory)/Dockerfile # wskazanie Dockerfile
#      containerRegistry: <your-service-connection-name> #nazwa Service Connection
#      tags: |
#        $(Build.BuildNumber) # tag, może być kilka
#        latest

```

Obecnie nie posiadasz jeszcze Container Registry oraz Twoja organizacja nie posiada "Service Connection", niezbędnego do uwierzytelnienia się aby móc wysłać obrazy do Container Registry.

## Krok 10

Stwórz Container Registry za pomocą terraform:


```bash
cd infra
mv terraform.tfvars.example terraform.tfvars

terraform init
terraform validate
```

W pliku `terraform.tfvars` wprowadź swoje inicjały dla zmiennej `project`, dzięki temu stworzone obiekty będą mieć możliwie unikalną nazwę.

Nazwa `Container Registry` musi być unikalna globalnie, a nazwa zostanie wygenerowana przez terraform na podstawie podanych wartości parametrów.

Stwórz zasoby (`Resource Group` i `Container Registry`):

```bash
terraform apply
```

Oprócz stworzenia zasobów dostaniesz również nazwę swojego `Container Registry` i polecenie pozwalające uwierzytelnić się lokalnie:

```bash
Outputs:

acr_login = "az acr login -n acrwgdev"
acr_name = "acrwgdev"
```

Znajdź KeyVault oraz wartości kluczy `acr-username` i `acr-password`.

```bash
az keyvault secret show --vault-name <vault-name> --name acr-username --query "value" -o tsv 

az keyvault secret show --vault-name <vault-name> --name acr-password --query "value" -o tsv 
```

## Krok 11

Stwórz `Connection Service` między Azure DevOps a `Container Registry`.

Z głównego widoku projektu w Azure DevOps wybierz "Project settings" z menu po lewej na dole (z zębatką).

Z części "Pipelines" wybierz "Service connections" i w prawym górnym rogu wybierz "New service connection".

W wyszukiwarce wpisz "Docker Registry" i wybierz dostępną opcję.

W polu "Docker registry" podaj pełen adres, np. `acrwgdev.azurecr.io` (wartość `login server`), którą możesz znaleźć w detalach swojego `Container Registry`.

W polu "Docker ID" podaj wartość `acr-username`

W polu "Docker Password" podaj wartość `acr-password`.

W polu "Service connection name" nadaj znaczącą nazwę, będziesz jej potrzebować w pipeline.

Zaznacz checkbox: "Grant access permission to all pipelnes".

## Krok 12

Odkomentuj fragment `##Sekcja Docker push` i zamień `<your-service-connection-name>` na nazwę "Service connection" z poprzedniego kroku.

Zacommituj zmianę.

```bash
git commit -am "Enable docker push"
git push
```

Prześledź odpalenie pipeline a następnie nawiguj do Azure Portal, znajdź swój Container Registry, wybierz "Repositories" i znajdź zbudowany obraz.
