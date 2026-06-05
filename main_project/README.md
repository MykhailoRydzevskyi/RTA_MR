# inventory-streaming

Infrastruktura projektu magazynowego RTA2026: Apache Kafka (KRaft), PostgreSQL, Redis i JupyterLab w Docker Compose.

Wzorzec techniczny: [sebkaz/jupyterlab-project](https://github.com/sebkaz/jupyterlab-project) oraz Lab 1 z [sebkaz-teaching/RTA2026](https://github.com/sebkaz-teaching/RTA2026).

## Wymagania

- Docker Desktop (z `docker compose`)
- Git

## Szybki start

```bash
git clone <url-repozytorium>
cd inventory-streaming
cp .env.example .env
docker compose up -d --build
```

Po starcie:

| Usługa | Adres |
|--------|-------|
| JupyterLab | http://localhost:8999 (token: `root` lub wartość z `.env`) |
| Kafka (z hosta Windows) | `localhost:29092` |
| Kafka (wewnątrz Docker / Jupyter) | `broker:9092` |
| PostgreSQL | `localhost:5432` / user `inventory` / db `inventory` |
| Redis | `localhost:6379` |

Sprawdzenie Kafki (terminal w JupyterLab):

```bash
kafka-topics.sh --list --bootstrap-server broker:9092
```

Health check (terminal w JupyterLab):

```bash
bash scripts/healthcheck.sh
```

Smoke test: otwórz `notebooks/smoke_test.ipynb` w JupyterLab i uruchom wszystkie komórki.

Zatrzymanie:

```bash
docker compose down
```

## Tematy Kafka

| Temat | Partycje | Klucz | Producent | Konsumenci |
|-------|----------|-------|-----------|------------|
| `products.catalog` | 3 | `product_id` | Dane i producenci | Przetwarzanie magazynu |
| `sales.events` | 3 | `product_id` | Dane i producenci | Przetwarzanie, prognozowanie |
| `deliveries.events` | 3 | `product_id` | Dane i producenci | Przetwarzanie magazynu |
| `inventory.states` | 3 | `product_id` | Przetwarzanie magazynu | Dashboard, zlecenia zakupu |
| `inventory.alerts` | 1 | `product_id` | Przetwarzanie magazynu | Dashboard, zlecenia zakupu |
| `forecasts.demand` | 3 | `product_id` | Prognozowanie | Zlecenia zakupu, dashboard |
| `orders.purchase` | 1 | `supplier_id` | Zlecenia zakupu | Dashboard |

Tematy tworzone automatycznie przez `kafka/init-topics.sh` przy `docker compose up`.

## Kontrakt zdarzeń JSON

Schematy w katalogu `schemas/`:

- [product_event.json](schemas/product_event.json) → `products.catalog`
- [sale_event.json](schemas/sale_event.json) → `sales.events`
- [delivery_event.json](schemas/delivery_event.json) → `deliveries.events`
- [inventory_state.json](schemas/inventory_state.json) → `inventory.states`
- [alert_event.json](schemas/alert_event.json) → `inventory.alerts`
- [forecast_event.json](schemas/forecast_event.json) → `forecasts.demand`
- [purchase_order_event.json](schemas/purchase_order_event.json) → `orders.purchase`

Przykład wiadomości na `sales.events`:

```json
{
  "event_id": "SALE-0001",
  "product_id": "P001",
  "quantity": 2,
  "unit_price": 49.99,
  "store_id": "WAW-01",
  "timestamp": "2026-06-05T10:15:00"
}
```

Producent (Python, w JupyterLab):

```python
from kafka import KafkaProducer
import json

producer = KafkaProducer(
    bootstrap_servers="broker:9092",
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
)
producer.send("sales.events", key=b"P001", value={...})
producer.flush()
```

Konsument (Python):

```python
from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    "sales.events",
    bootstrap_servers="broker:9092",
    group_id="my-consumer-group",
    auto_offset_reset="earliest",
    value_deserializer=lambda x: json.loads(x.decode("utf-8")),
)
for message in consumer:
    print(message.value)
```

## PostgreSQL

Schemat inicjalizowany z `db/init.sql` przy pierwszym starcie kontenera `postgres`.

Tabele: `suppliers`, `products`, `inventory_snapshots`, `sales`, `deliveries`, `alerts`, `forecasts`, `purchase_orders`, `purchase_order_items`.

Seed: 2 dostawców, 8 produktów, początkowe stany magazynu.

Połączenie z JupyterLab:

```python
import os
import psycopg2

conn = psycopg2.connect(
    host=os.environ.get("POSTGRES_HOST", "postgres"),
    port=os.environ.get("POSTGRES_PORT", "5432"),
    dbname=os.environ.get("POSTGRES_DB", "inventory"),
    user=os.environ.get("POSTGRES_USER", "inventory"),
    password=os.environ.get("POSTGRES_PASSWORD", "inventory"),
)
```

## Redis — konwencja kluczy

Implementacja zapisu należy do modułu „Przetwarzanie magazynu”. Ustalone klucze:

| Klucz | Typ | Zawartość |
|-------|-----|-----------|
| `stock:{product_id}` | string/int | bieżący stan magazynu |
| `velocity:{product_id}` | hash | sprzedaż w oknie czasowym |
| `alert:{product_id}` | string | ostatni alert LOW_STOCK |

```python
import os
import redis

r = redis.Redis(
    host=os.environ.get("REDIS_HOST", "redis"),
    port=int(os.environ.get("REDIS_PORT", "6379")),
    decode_responses=True,
)
```

## Zmienne środowiskowe

Skopiuj `.env.example` do `.env`. Kluczowe wartości:

```env
KAFKA_BOOTSTRAP_INTERNAL=broker:9092
KAFKA_BOOTSTRAP_HOST=localhost:29092
POSTGRES_HOST=postgres
POSTGRES_DB=inventory
POSTGRES_USER=inventory
POSTGRES_PASSWORD=inventory
REDIS_HOST=redis
JUPYTER_TOKEN=root
```

## Onboarding zespołu

| Moduł | Co dostajesz |
|-------|--------------|
| **Dane i producenci** | Tematy wejściowe, schematy JSON, `.env`, broker |
| **Przetwarzanie magazynu** | Tematy wej./wyj., Redis + PG, bootstrap servers |
| **Prognozowanie** | `sales.events`, tabela `sales` w PG |
| **Zlecenia zakupu** | `inventory.alerts`, `forecasts.demand`, `orders.purchase`, tabele zamówień |
| **Dashboard** | Connection strings PG/Redis, tematy read-only |

**Ważne (Windows):** producentów i konsumentów uruchamiaj w kontenerze JupyterLab (`broker:9092`), nie bezpośrednio na hoście.

## Struktura repozytorium

```
compose.yaml          # Docker Compose stack
Dockerfile            # JupyterLab + Kafka CLI + biblioteki Python
kafka/init-topics.sh  # tworzenie tematów
db/init.sql           # schemat PostgreSQL + seed
schemas/              # kontrakty JSON
scripts/healthcheck.sh
notebooks/smoke_test.ipynb
```
