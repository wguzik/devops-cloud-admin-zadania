# Lab: Wykorzystanie narzędzi konsoli: PowerShell i az cli do tworzenia infrastruktury

## Wymagania

- docker

## Wstęp

Observability to szerokie pojęcie, które obejmuje między innymi monitoring.
Prometheus to popularne narzędzie do zbierania i obsługi metryk.
Grafana przoduje w prezentacji danych.

## Cel

Uruchomienie lokalne instancji Prometheusa i Grafany. Zapoznanie się z podstawowymi funkcjami Prometheusa i Grafany.

Czas trwania: 30 minut


### PromQL

PromQL to język zapytań, który pozwala na tworzenie zapytań w danych zebranych w Prometheusu.

```promql
sum(rate(http_requests_total{job="prometheus"}[2d]
^   ^    ^                   ^                 ^
4   3    1                   2                 5
```

1 - bazowa metryka
2 - etykietka (label), odfiltrowuje metryki z wybranego źródła
3 - funkcja zapytania
4 - funkcja agregacji
5 - zakres dat

Cheat sheet: [https://promlabs.com/promql-cheat-sheet/](https://promlabs.com/promql-cheat-sheet/)

Typy metryk:
- counter
- gauge
- histogram
- summary

## Stack

### Prometheus

`Section 1` odpowiada za ściągnięcie i uruchomienie aplikacji Prometheus.
Prometheus potrzebuje wskazania, skąd ściąga metryki. W przypadku docker-compose jest to plik `prometheus.yaml`, w który posiada definicje kontenerów, z których powinien ściągac metryki.

Odkomentuj sekcję i uruchom:

```bash
docker-compose up
```

Otwórz prometheusa po adresem: [http://localhost:9090](http://localhost:9090)


Wyłącz usługę.

```bash
docker-compose down -v
```

### Grafana

Grafana słuzy do tworzenia wykresów w oparciu o dane.


`Section 2` odpowiada za ściągnięcie i uruchomienie Grafany.