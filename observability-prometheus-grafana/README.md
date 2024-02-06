# Lab: Zapoznanie się z Prometheusem i Grafaną

## Wymagania

- docker

## Wstęp

Observability to szerokie pojęcie, które obejmuje między innymi monitoring.
Prometheus to popularne narzędzie do zbierania i obsługi metryk.
Grafana przoduje w prezentacji danych.

## Cel

Uruchomienie lokalne instancji Prometheusa i Grafany. Zapoznanie się z podstawowymi funkcjami Prometheusa i Grafany.

Czas trwania: 45 minut

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

### Dodatkowa konfiguracja

Niektóre kontenery mają wskazania do lokalnych plików, np:

```yaml
    volumes:
      - ./prometheus:/etc/prometheus
```

co pozwala trzymac szczegóły konfiguracji w repozytorium.

## Stack

```bash
docker-compose up
```

### Prometheus

Prometheus potrzebuje wskazania, skąd ściąga metryki. W przypadku docker-compose jest to plik `prometheus.yaml`, w który posiada definicje kontenerów, z których powinien ściągac metryki.

Otwórz Prometheusa po adresem: [http://localhost:9090](http://localhost:9090).
Zobacz metryki po adresem: [http://localhost:9090/metrics](http://localhost:9090/metrics).

### Alert Manager

Prometheus posiada funkcję tworzenia alertów, ale ich obsługa jest bardzo uboga. Alert Manager pozwala na zarządzanie alertami, np. wygaszenie na czas wdroenia lub integrację z innymi systemami.

Otwórz Alert Manager po adresem: [http://localhost:9093](http://localhost:9093).

### Grafana

Grafana słuzy do tworzenia wykresów w oparciu o dane.

Otwórz Alert Manager po adresem: [http://localhost:3000](http://localhost:3000).

### Nginx

Nginx udostępnia status, jednak nie jest on w formacie zjadliwym dla Prometheusa.
Z tego powodu jest doinstalowana usługa `nginx-exporter`, która "tłumaczy" metryki nginx na format akceptowalny przez Prometheusa.

W konfiguracji Prometheusa `prometheus.yml` wskazanie jest na `nginx-exporter` a nie `nginx` jako taki.

Otwórz stronę po adresem: [http://localhost:8081](http://localhost:8081).

Zobacz metryki po adresem: [http://localhost:8081/metrics](http://localhost:8081/metrics).

```bash
docker-compose down -v
```
