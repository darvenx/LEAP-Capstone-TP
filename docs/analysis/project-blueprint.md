# Project Blueprint — Enterprise Trading Platform

> **Scope of this document.** This is a discovery and analysis artefact produced by reading two
> sources in full:
>
> 1. **`reference-repo/`** — the branch handed to teams: the root `README.md`, the five binding
>    contracts under `contracts/`, the infrastructure requirements under `infra/`, and every sprint
>    brief from Sprint 3 through the cloud-deployment week.
> 2. **`reference-repo/Project.pdf`** — the master *"Enterprise Trading Platform — Applied Capstone
>    Project (India Cohort), Specification & Build Guide"* (23 pages: Parts A–D covering overview &
>    approach, build components, technical specification, and delivery & assessment).
>
> It is documentation only. No source code, schema, contract or infrastructure definition has been
> modified. Its purpose is to give our team one place that explains what the platform is, how the
> pieces fit, what each sprint owns, and where the assumptions and ambiguities lie before we build.
>
> **Source precedence.** Where the two disagree, the **reference-repo materials bind**: they are the
> newer version and they explicitly correct the specification in several places (e.g. "The
> specification calls the first topic `trades`. This catalogue names it `orders`… one repository
> uses one name"; "There is no broker simulator in this platform and there will not be one"; "this
> cohort has no Sprint 11"). `Project.pdf` is the higher-level master spec and the source of truth
> for the programme narrative, the functional/non-functional requirement IDs, effort estimates and
> the assessment weighting. The concrete conflicts and how we resolve them are catalogued in
> **§12**.

---

## 1. Project vision

The Enterprise Trading Platform is a working retail-brokerage trading system, built by a team over
nine weeks, **one component per sprint**. Customers hold cash accounts, place buy and sell orders
against real instruments, and see their positions and cash move. Orders are:

- accepted by a REST API,
- executed asynchronously against live market prices,
- recorded in a transactional database,
- published as events on a message bus,
- loaded into an analytical store,
- and driven from a browser.

The stated design philosophy is that **the platform accumulates** — there is "no throwaway week".
What Sprint 3 models is what Sprint 6 queries; what Sprint 6 exposes is what Sprint 9 renders. Each
component depends on the ones before it. The problems are deliberately the real ones a trading
system faces:

- an order that must not be executed twice (idempotency, exactly-once effect),
- a price that arrives stale or delayed,
- a token that must be verified before any claim in it is trusted,
- a schema that answers both "what is this account's cash balance right now" and "what did we
  trade last quarter by asset class".

Market data comes from **Fauxnance**, a provided REST API (delayed quotes and end-of-day candles,
covering NSE/BSE symbols alongside US equities, FX and crypto). It has a hard quota of **2000
requests/day/key**, no push/stream, and its key must never reach the browser or a commit.

**Assessment framing.** The capstone is scored out of 100 marks across the sprints; the cloud week
adds 5. The programme repeatedly emphasises that **reviews are human-assessed** — structure and a
green test suite are the floor, not the deliverable.

---

## 2. Architecture overview

### 2.1 Runtime components (by Sprint 10, the finished platform)

The platform is **one repository and one stack**. Local orchestration describes **five containers**,
all team-created:

| Container | Component | Language / stack | Sprint |
|---|---|---|---|
| `postgres` | Trade (operational) database | PostgreSQL 16 | 3 |
| `kafka` | Event backbone (broker) | Kafka 3.8, KRaft mode | 7 |
| `trade-api` | Trade REST API (hosts domain package + all four extensions) | Java 21, Spring Boot 3.5.x, MyBatis | 6, 10 |
| `trade-executor` | Trade Executor + market-data poller | Java 21, Maven | 7 |
| `auth-service` | Auth service | Node 20+, NestJS, TypeScript | 8 |

Running **on the host, not containerised**:

- The **Angular dev server** (Sprint 9 UI).
- The **Python tooling** — analytics ETL / pipeline (Sprint 4, extended in Sprint 7), using DuckDB.

**Not containers**: the four Sprint 10 extensions and the Sprint 5 domain package. They are
**packages inside the Trade REST API**, sharing its port (8080), its token verification and its
database connection.

### 2.2 Logical data flow

```
                       Fauxnance API (quotes, candles)  [quota 2000/day/key, no push]
                                  |  (key server-side only)
                                  v
Browser (Angular) --HTTPS/JWT--> Trade REST API (8080) --produce--> orders topic
     ^                                 |  (verifies JWT)                 |
     |  tokens                         | writes/reads                    | consume (group: trade-executor)
     |                                 v                                 v
 Auth service (3000) <----------- PostgreSQL <---settle (1 txn)--- Trade Executor --produce--> trade-events
                                       ^                                 |  (poller inside it)
                                       | incremental extract             +--produce--> market-data
                                       v
                          Python ETL --> DuckDB star schema (analytics)
```

Downstream consumers of the topics (all packages inside the Trade REST API in Sprint 10, plus the
ETL):

- `trade-events` → Portfolio & P&L, Customer Notifications, Analytics loader (optional).
- `market-data` → Watchlists & Price Alerts, Portfolio & P&L.
- `orders` → **exactly one** consumer group (`trade-executor`); it is a work queue.

### 2.3 Two data stores, two shapes

- **Operational (Postgres, Sprint 3):** normalised (3NF), correct under concurrent writes, answers
  "what is true right now" in milliseconds. Owns accounts, instruments, orders, positions, cash.
- **Analytical (DuckDB, Sprint 4 + 7):** denormalised **star schema** (`contracts/analytics-schema.sql`),
  append-mostly, loaded by the Python ETL, never written or read by a service. Answers "what did we
  trade last quarter" without slowing order placement.

### 2.4 Cross-cutting conventions

- **One error envelope** everywhere: `{"errorCode": "...", "message": "..."}`. Clients branch on
  `errorCode`, never on `message` or HTTP status alone (404 and 409 each carry two codes).
- **JWT auth** (HS256, shared `JWT_SECRET` in dev). Signature/expiry/issuer/algorithm verified on
  every `/api/v1/**` route **before** any claim is trusted. Authentication (who) is answered once;
  authorisation (which account) is answered where the account key is known (`ACC-403` on mismatch).
- **Money is decimal** (two places), never `double`, held as `BigDecimal` in Java.
- **Secrets never in the repo**: `.env` is git-ignored; `.env.example` is the committed template.
  The Fauxnance key never reaches the browser.
- **At-least-once messaging**: consumers must be idempotent on `eventId`; producers use
  `acks=all`, `enable.idempotence=true`.

---

## 3. Sprint-by-sprint summary

| Week | Sprint | Component | Folder | Marks |
|---|---|---|---|---:|
| 1 | Induction | No capstone deliverable | none | — |
| 2 | 3 | Trade database (data modelling) | `sprint-03-trade-database` | 7 |
| 3 | 4 | Analytics & ETL pipeline | `sprint-04-analytics-etl` | 8 |
| 4 | 5 | Domain engine (Java/OOAD) | `sprint-05-domain-engine` | 18 |
| 5 | 6 | Trade REST API (Spring Boot) | `sprint-06-trade-api` | 18 |
| 6 | 7 | Event backbone (Kafka + executor + ETL load) | `sprint-07-event-backbone` | 10 |
| 7 | 8 | Auth service (NestJS) | `sprint-08-auth-service` | 13 |
| 8 | 9 | Trading UI (Angular) | `sprint-09-trading-ui` | 13 |
| 9 | 10 | Extensions (4 modules in the Trade API) | `sprint-10-extensions` | 8 |
| after | cloud | Cloud deploy (Angular → S3/CloudFront) | `sprint-11-cloud-deploy` | 5 |

> Sprint numbers are one ahead of week numbers by design. Sprint 7 and Sprint 9 weeks each lose a
> taught day to a public holiday (Ganesh Chaturthi, Gandhi Jayanti) and are scoped to four days.

**Marks column note.** The per-sprint marks above are the reference-repo's absolute breakdown of the
100-mark capstone (they sum to 100). `Project.pdf` §23.1 gives a slightly different *component-weight*
view of the same 100%: Data & Analytics 15% (= S3 + S4), Business Logic (Java) 20%, Trade REST API
20%, Eventing & Excellence 10%, Auth & Security 15%, User Interface 15%, Deployment & Showcase 5%.
Note the PDF's component view has **no separate line for the Sprint 10 extension** — the reference-repo
does (8 marks) — so treat the reference-repo per-sprint marks as authoritative and the PDF weights as
the higher-level grouping.

**Indicative effort (`Project.pdf` §20).** Programme time only, alongside instructor-led learning:
Sprints 3–9 are ~4 hrs each (project session), Sprint 10 (Extension + Integration, applied-project
week) ~30 hrs, and the cloud deployment + showcase ~12 hrs — **~78 hrs total, indicative**.

### Sprint 3 — Trade database
Design the normalised Postgres schema from the domain (accounts, instruments, orders, positions,
cash). Deliverables: numbered migrations (`001_`…), seed data covering all the states later sprints
need, an apply command (empty → migrated → seeded, `ON_ERROR_STOP`, reads `TARGET_DATABASE`), ER
diagram, index justifications (≥3 indexes each tied to a named query), a `DESIGN.md` covering
historical trade data. **Must demonstrate** a `23505` (unique violation on idempotency key) and a
`23503` (FK violation). The schema must serve `trade-api.yaml`, so read it before finishing.

### Sprint 4 — Analytics & ETL
An installable Python project with **separate extract / transform / load** functions in three
modules. Pull Fauxnance **candles** (`GET /candles/{symbol}`), cache raw pulls to `.cache/`,
transform (typing, cleaning, handling six malformed-fixture defects), load into DuckDB. Produce a
dashboard (offline HTML, inlined JS) and **three business claims** (`claims.md`), each backed by a
readable chart. pytest over at least the transform incl. a malformed-input case. ≥2 NSE/BSE symbols.
Error handling distinguishes quota (429), bad request (4xx), network, and bad-data-in-200.

### Sprint 5 — Domain engine
Framework-free Java 21 (Maven), the **only** non-test dependency being `jakarta.validation-api`. Four
entities (`Account`, `Instrument`, `Order`, `Position`), three enums (`AccountStatus`, `OrderSide`,
`OrderStatus`), the `PlaceOrderRequest` DTO with validation, an exception hierarchy of six cases,
and **business rules 1–8 in the domain** (not a controller). Money is `BigDecimal`. **Test-first**,
evidenced by commit history; three named test classes must be green (≥24 tests). UML class + order
sequence diagrams. Sprint 6 absorbs this package **as source**, so name the package for the domain.

### Sprint 6 — Trade REST API
Spring Boot service implementing all six `trade-api.yaml` endpoints exactly. Layered controller /
service / mapper; MyBatis with **parameterised statements only** (`#{}`, never `${}` except a
whitelisted column/sort name). `@ControllerAdvice` maps every domain exception → catalogue code.
Order placement is `@Transactional`. **Optimistic locking** on the account `version` column (lost
update → `ORD-409`). **JWT verified on every `/api/v1/**`** using a team-owned test fixture (no real
issuer yet). Multi-stage Dockerfile, non-root, health check; joined to local orchestration. Absorbs
the Sprint 5 domain as source.

### Sprint 7 — Event backbone
Create the three topics + three `.DLT` topics (auto-create off) with contracted names/keys/partitions/
retention; justify in `design/kafka.md`. **Characterisation tests** pinning Sprint 6 order placement,
committed **before** the change. Change the API: persist `NEW`, publish `ORDER_PLACED` to `orders`
**after commit**, return `NEW`. Build the **Trade Executor** (consume → load → check tradable →
quote → fill rule → settle in one txn → publish `ORDER_FILLED`/`ORDER_REJECTED` → ack). Guarded state
transition (`WHERE id=? AND status='NEW'`) + optimistic lock. **Market-data poller** inside the
executor (batched ≤25 symbols, one Kafka message per symbol, interval floor enforced, shares the
quota). One incremental, idempotent load into `FACT_TRADES` + dimensions with dead-lettering.
SonarQube gate passing. **Must demonstrate** a replayed message not double-debiting.

### Sprint 8 — Auth service
NestJS service implementing the four `auth-api.yaml` routes on port 3000. Access tokens HS256 with
**exactly** the claim set (`sub`, `accountId`, `roles`, `iat`, `exp`, `iss`). Passwords hashed with
argon2id or bcrypt (cost ≥12), never logged. Refresh tokens stored (as a hash), **rotated on every
refresh**; revocation optional but its absence documented. **Uniform failure** (same body, status
and comparable timing for unknown user vs wrong password — verify against a dummy hash). Jest tests
including expired-token and wrong-signature guard paths. Served OpenAPI doc (`/docs`, `/docs/json`).
Committed OWASP security review. **Adopting it in the Trade API must be config-only — no Java change.**

### Sprint 9 — Trading UI
Angular 21 workspace, standalone components + signals (no `NgModule`). **Typed clients generated**
from both contracts, committed, never hand-edited. One functional interceptor attaches the bearer
token to platform APIs **only** (by origin allow-list, never to Fauxnance/third parties — a security
control). Route guards + safe redirect. Screens: sign-in, dashboard, **order ticket** (validate
before submit; render **all eight** catalogue codes), **blotter** (status badges incl. handling an
order sitting at `NEW` via polling, never re-posting). Two Playwright journeys (sign-in, place order;
each self-contained; assertions accept `NEW`/`FILLED`/`REJECTED`). **No secret/key in the bundle.**

### Sprint 10 — Extensions
Four **mandatory** modules, all **packages inside the Trade REST API** (no new containers), built in
**dependency order**:
1. **Customer preferences** (owns default account + alert channel; publishes a Java interface),
2. **Customer notifications** (consumes `trade-events`, resolves channel via preferences, delivers;
   publishes a delivery interface),
3. **Watchlists & price alerts** (consumes `market-data`, evaluates thresholds, delivers via
   notifications — never to a log),
4. **Portfolio & P&L** (independent; implements `portfolio-api.yaml`, prices via Fauxnance).

Every route enforces its own authorisation (`accountId` claim vs path). Each consumer has its own
`group.id`. Deliverables also include a **decision log** (≥6 entries) and **one combined OWASP
review** whose findings are addressed. Two stretch modules (Trade advice/signals, Automated strategy
execution) unlock only after all four are done.

### Cloud week — Deploy the front end
Deploy **only the Angular build** to a **private S3 bucket** behind a **CloudFront distribution**
with **Origin Access Control** (public bucket policy fails the criteria). One **deploy script**
(build → upload → invalidate), a **scoped IAM deploy identity** (no wildcards, no committed key),
authenticated flows verified against the CloudFront URL. Back end stays local; the deployed build
points at `http://localhost` ports by default (documented decision). Followed via `RUNBOOK.md`.

---

## 4. Major entities

### 4.1 Operational domain (Postgres / Sprint 5 objects)

The Sprint 3 table shapes are the team's design (no contract), but the domain, the fields exposed by
`trade-api.yaml`, and the Sprint 5 objects fix the entity set:

| Entity | Key attributes | Notes / invariants |
|---|---|---|
| **Account** | numeric surrogate `id` (`ACCOUNTS.id`), business `account_id` (string ref, e.g. `ACC-000001`), `holderName`, `cashBalance` (decimal, one currency), `status` (`ACTIVE`/`SUSPENDED`/`CLOSED`), `version`, `lastUpdated` | Two identifiers, **not interchangeable**. `version` = optimistic lock. Closed ≠ deleted. Concurrency is highest here. |
| **Instrument** | `symbol` (Fauxnance scheme), `name`, `asset_class`, `currency`, tradable flag | Delisting is a **flag, never a delete** (order history references it). |
| **Order** | `id` (UUID; displayed `ORD-<uuid>`), `accountId`, `symbol`, `side` (`BUY`/`SELL`), `quantity` (int>0), `price` (limit, decimal), `executedPrice` (null until filled), `status` (`NEW`/`FILLED`/`REJECTED`/`CANCELLED`), `idempotencyKey` (unique), `createdOn` | Recorded on receipt (audit trail). Exactly one terminal state. No partial fill. Rejected orders **kept**. |
| **Position** | `accountId`, `symbol`, `quantity` (≥0), `averageCost` | Derived-but-stored. Buy recalculates avg cost; sell reduces qty, leaves avg cost unchanged. No shorting. |
| **Cash / ledger** | balance movements, `cashDelta` per event | Moves atomically with position in one transaction. |

Executor-added columns (Sprint 7 migration): executed price, executed-on timestamp, rejection reason.

### 4.2 Analytical model (DuckDB star, `contracts/analytics-schema.sql`)

| Table | Grain / type | Key columns |
|---|---|---|
| `dim_account` | one row per account **version** (SCD Type 2) | `account_key` (surrogate), `account_id` (natural), `status`, `effective_date`, `end_date`, `is_current` |
| `dim_instrument` | one row per instrument (SCD Type 1) | `instrument_key`, `symbol` (unique), `asset_class`, `currency`, `exchange` (derived from symbol) |
| `dim_date` | one row per calendar day | `date_key` (YYYYMMDD int), `year`, `quarter`, `is_weekday`, … |
| `fact_trades` | **one row per order** (any status) | `trade_key`, `account_key`, `instrument_key`, `date_key`, `side`, `quantity`, `price`, `executed_price`, `trade_value` (precomputed), `status`, `source_order_id` (unique → idempotent load) |

Must answer five analytics with one join per dimension: trade volume, most active accounts, fill
rate, exposure by instrument, average trade size.

### 4.3 Identity / auth

| Entity | Attributes |
|---|---|
| **User** (auth service) | `id` (UUID = `sub`), `username`, hashed password, `accountId` (links to `ACCOUNTS.id`), `roles` (`CUSTOMER`/`ADMIN`) |
| **Refresh token** | stored server-side as a **hash**, revocable, rotated per use |

### 4.4 Extension entities (Sprint 10, own tables per module)

- **Preferences**: preference record per customer (default account, alert channel + contact detail).
- **Notifications**: notification/delivery ledger (queued/sent/failed), keyed on `eventId` for idempotency.
- **Watchlists/alerts**: watchlists, watchlist items, price alerts (threshold + direction + state), per-account cap.
- **Portfolio/P&L**: only its own tables (reads trading tables read-only; realised P&L accumulated).

The seed data in the local `Our-project/database/` (users, trading_accounts, instruments, orders,
holdings, cash_ledger, watchlists, price_alerts, notifications, portfolio_snapshots, audit_logs)
reflects this superset of entities including the extensions.

---

## 5. Service boundaries

| Service / module | Owns | Talks to | Must NOT |
|---|---|---|---|
| **Trade REST API** | Transport + persistence for orders/accounts; hosts domain package + 4 extensions | Postgres (write), `orders` (produce), `trade-events` (consume optional), Auth (verify JWT via shared secret) | Decide trade rules in a controller; hold SQL in a controller; use Kafka from Sprint 6 alone |
| **Domain package** (in Trade API) | Business rules 1–8, entities, validation | Nothing (pure Java) | Reference servlet/Spring/MyBatis/JDBC types |
| **Trade Executor** | The **only** component that decides a fill; settles cash+position+status atomically; runs the poller | `orders` (consume, group `trade-executor`), Postgres (write), Fauxnance (quotes), `trade-events` + `market-data` (produce) | Double-apply a duplicated message; batch market-data into one Kafka message |
| **Market-data poller** (in Executor) | Manufacture the price stream | Fauxnance batch quotes, `market-data` (produce) | Run on the order path; hold a second copy of the key/quota |
| **Auth service** | The **only** holder of credentials; issues/validates JWTs; refresh lifecycle | Own credential store (Postgres) | Put anything beyond the fixed claim set in a token; return distinguishable failures |
| **Python ETL** | Move + reshape operational → analytical | Postgres/candles (read), DuckDB (write), `trade-events` (consume optional) | Write to Postgres; be read by a service |
| **Angular UI** | Presentation only | Trade API + Auth (via generated clients + interceptor) | Call Kafka or Fauxnance; hold any secret; be the authorisation authority |
| **Preferences / Notifications / Watchlists / Portfolio** (in Trade API) | Each owns its package + tables; cross-module links are **Java interfaces** | Their own topics/consumer groups; each other via published interfaces only | Reach into another module's tables; expose an internal resolution route as HTTP; write to trading tables (Portfolio) |

**Key boundary principle for Sprint 10:** with four modules in one process, the compiler no longer
enforces the boundary — it becomes a reviewed decision. Nothing outside a module imports anything
inside it except the interface that module publishes.

---

## 6. API boundaries (the five binding contracts)

All contracts are in `contracts/` and are **binding** — implement exactly; a renamed field breaks a
consumer or a generated client. All share the `{errorCode, message}` envelope.

### 6.1 `trade-api.yaml` (Sprint 6, client-generated in Sprint 9)
Six operations, all under `/api/v1`, all bearer-secured:

| Method | Path | Purpose |
|---|---|---|
| POST | `/orders` | Place order (returns `NEW` async from S7, or terminal in S6) |
| DELETE | `/orders/{id}` | Cancel a working order (guarded transition) |
| GET | `/accounts/{id}` | Account details (`AccountResponse`) |
| GET | `/accounts/{id}/balance` | Cash only |
| GET | `/accounts/{id}/positions` | Holdings (unpriced) |
| GET | `/accounts/{id}/orders` | Order history (all statuses, newest first) |

**Error catalogue:** `ACC-404` (404), `ACC-403` (403), `INS-404` (404), `ORD-400` (400),
`ORD-409` (409), `VAL-422` (422), `AUTH-401` (401). Business rules 1–8 evaluated in order, first
failure wins. `accountId` = numeric `ACCOUNTS.id` everywhere except `AccountResponse.accountId`
(the string business ref).

### 6.2 `auth-api.yaml` (Sprint 8; stub shape used in Sprint 6)
Four operations on port 3000: `POST /auth/register` (201, no tokens), `POST /auth/login` (200,
`TokenResponse`), `POST /auth/refresh` (200, rotates), `GET /auth/me` (bearer). Defines the
**normative JWT claims contract** every other service verifies. Extra code `AUTH-409` (username
taken), scoped to this service.

### 6.3 `kafka-topics.md` (Sprint 7)
Three topics + shared 5-field envelope (`eventId`, `eventType`, `eventTime`, `source`,
`schemaVersion`, + `payload`):

| Topic | Key | Partitions | Retention | Consumers |
|---|---|---|---|---|
| `orders` | `accountId` (string) | 3 | 7 days | **exactly one** group: `trade-executor` |
| `trade-events` | `accountId` (string) | 3 | 30 days | portfolio, notifications, analytics, advice, strategy |
| `market-data` | `symbol` | 6 | 1 day | watchlist, portfolio, advice, strategy |

At-least-once; publish after DB commit; consumers idempotent on `eventId`; `<topic>.DLT` for poison
messages. **Angular never touches Kafka.**

### 6.4 `analytics-schema.sql` (Sprint 4 dashboard, loaded fully in Sprint 7)
Portable ANSI SQL star schema (no IDENTITY/SERIAL, DECIMAL not NUMERIC). ETL assigns surrogate keys.
Incremental, watermark-driven, idempotent load; dimensions before facts; pre-load data-quality
checks with dead-lettering; post-load reconciliation against Postgres.

### 6.5 `portfolio-api.yaml` (Sprint 10)
Three routes + health, **served by the Trade REST API on 8080** (not a separate deployable):
`GET /api/v1/portfolio/{accountId}`, `/positions`, `/pnl`. Adds `MKT-503` (pricing unavailable for
all instruments). Defines cost basis, market value, unrealised vs **realised** P&L (booked at sale,
never recomputed from today's price), staleness (`priceAsOf`, `stale`, `partial`).

### 6.6 Functional & non-functional requirements (`Project.pdf` §15–16)

The PDF pins the requirement set with stable IDs (useful for traceability in stories and tests):

| ID | Feature | Component | Notes |
|---|---|---|---|
| FR-01 | Order placement & cancellation | Trade API | Buy/sell against an account; cancel working orders |
| FR-02 | Account validation | Trade API | Existence + status |
| FR-03 | Instrument validation | Trade API | Tradable check |
| FR-04 | Funds / holdings check | Trade API | Cash (buy) / held qty (sell) |
| FR-05 | Order logging | Trade API | Record all orders (audit trail) |
| FR-06 | Idempotency | Trade API | Prevent duplicate orders |
| FR-07 | Balance & positions | Trade API + Angular | Priced against live market data |
| FR-08 | Order history | Trade API + Angular | View past orders |
| FR-09 | Authentication | NestJS + Angular | Secure login with JWT |
| FR-10 | Eventing | Kafka | Publish/consume trade events |
| FR-11 | Analytics | Python/DuckDB | Business insights & reporting |
| FR-12 | Trade execution | Kafka / Trade Executor | Asynchronous execution *(see §12 on the "Broker Simulator API")* |

| ID | Requirement | Implementation |
|---|---|---|
| NFR-01 | Transactional integrity | `@Transactional` order processing |
| NFR-02 | Concurrency control | Optimistic locking (`version`) |
| NFR-03 | Security | JWT auth + Bean Validation |
| NFR-04 | Auditability | Order logging + trade events |
| NFR-05 | Resilience | Retries, idempotency, dead-letter queue |
| NFR-06 | Code quality | SonarQube quality gates, test coverage |
| NFR-07 | Version control | Branching + pull-request review |

Business rules 1–10 and the error catalogue in the PDF (§17–18) match the reference-repo/`trade-api.yaml`
exactly (rules 9–10 = atomic cash+position update and log-every-order, no code). Security implementation
(§19) additionally names, at the *aspirational* level, TLS 1.2+ in transit, "OAuth2-style / MFA-ready"
auth, Kafka TLS/SASL/ACLs with a full audit trail, and DevSecOps SAST/dependency/secret scanning — see
§12 for how the reference-repo scopes these down for the local training stack.

---

## 7. Infrastructure requirements

The reference branch supplies **requirements, not an executable stack** — the team builds it.

### 7.1 Required local services (`infra/README.md`)

| Service | Host address | Service-network address |
|---|---|---|
| PostgreSQL 16 | `localhost:5432` | `postgres:5432` |
| Kafka 3.8 (KRaft) | `localhost:9092` | `kafka:29092` |
| Auth service | `localhost:3000` | `auth-service:3000` (port 3000 reserved) |
| Trade REST API | `localhost:8080` | `trade-api:8080` |

- A stable-name network so services resolve each other; health checks; repeatable start/stop.
- **Postgres starts empty** — schema/migrations/seed are the Sprint 3 deliverable. Init convention:
  mount into `/docker-entrypoint-initdb.d`; `.sql`/`.sh` run once in filename order on an empty
  volume. Copy migrations + seed into `infra/postgres/` (numbered) so a fresh start builds unattended.
- **Kafka starts with no topics**; auto-creation **must stay off**; topics created explicitly with
  the contracted partitions/retention by a re-runnable command (Sprint 7).

### 7.2 Configuration (`.env` from `.env.example`)

| Variable | Purpose |
|---|---|
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | Single shared database (`trading`) |
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka:29092` for services, `localhost:9092` for host tools |
| `JWT_SECRET` | Shared HS256 secret (≥32 chars); auth signs, Trade API verifies |
| `FAUXNANCE_BASE_URL` | Fixed programme URL |
| `FAUXNANCE_API_KEY` | Personal key; header `X-Api-Key`; 2000/day; **never committed, never to browser** |

`.env` is git-ignored; commit `.env.example` with placeholders when adding a variable.

### 7.3 Tooling expectations
- Java 21 + Maven 3.9+ (domain, Trade API, Executor).
- Node 20+ (Auth, NestJS) and Node 20.19/22.12/24+ (Angular 21).
- Python 3.12+ with installable projects (`pip install -e`), DuckDB, pytest.
- Docker multi-stage builds (non-root, health-checked) for Trade API, Executor, Auth.
- SonarQube (local) gate for executor + pipeline (Sprint 7).
- OpenAPI client generator on the JVM (Sprint 9), pinned version.

---

## 8. Deployment requirements

### 8.1 Local (through Sprint 10)
`docker compose` (or equivalent) with the five containers above, `depends_on` health conditions,
env passed from `.env`, published ports, one command up/down. The Angular dev server and Python
tooling run on the host. The whole stack must start cleanly with schema + topics in place — this is
the **gate** for the cloud week.

### 8.2 Cloud week (Angular only → AWS)
- **S3 bucket**: private, all public access blocked, never addressed directly.
- **Origin Access Control**: the credential CloudFront presents to S3 (public bucket policy is
  explicitly disqualified).
- **CloudFront distribution**: public HTTPS face, `redirect-to-https`, `DefaultRootObject=index.html`,
  custom 403/404 → `/index.html` (deep-link fix), caching by file family.
- **One deploy script** (`deploy/deploy-ui.sh`): build (`npm ci` + prod build) → upload (hashed
  assets `immutable`, `index.html` `no-cache`, `--delete`) → invalidate `/index.html`. Idempotent
  (safe to run twice).
- **Two IAM identities**: broad **setup** identity (by hand, once); narrow **deploy** identity
  (write objects to one bucket + invalidate one distribution; **no wildcards**, no committed key,
  stored in `~/.aws/credentials`).
- **Cross-origin + base URL**: services get the CloudFront origin added to CORS (`Authorization`
  header, no wildcard for a service holding positions); deployed build points at `http://localhost`
  ports by a documented decision (works on any machine running the stack; a cold visitor sees the
  shell + failed sign-in).
- Verify authenticated flows from the CloudFront URL; scan the deployed bundle for secrets; share
  the link; tear down after assessment (distribution → bucket → OAC → deploy user, checked gone).
- Back end (Postgres, Kafka, Trade API, Auth, Executor, ETL) is **out of scope** for deployment.

---

## 9. Dependencies between sprints

```
S3 (schema) ──> S4 (ETL over market data; loads star schema)
   │              ▲
   │              │ (S7 repoints the same pipeline at real trades)
   ▼              │
S5 (domain) ──> S6 (Trade API absorbs domain as source) ──> S7 (executor + producer + ETL load)
                    │                                          │
                    │                                          ▼
                    │                                       S7 adds executed-price/reason migration to S3 schema
                    ▼
                 S8 (auth issues the tokens S6 already verifies) 
                    │
                    ▼
S6 + S7 + S8 ──> S9 (UI generated from S6 & S8 contracts) ──> S10 (4 extensions inside S6 service)
                                                                  │
                                                                  ▼
                                                        Cloud week (deploy S9 build; needs S10 green + stack clean)
```

Explicit chains:

- **S3 → everything**: the schema is the platform's memory; S6 writes it, S7 updates it, S4/S7 ETL
  extracts from it, S9 renders it.
- **S5 → S6**: the domain package is copied into the Trade API **as source** (not a dependency),
  keeping its package name; S6 wraps transport around unchanged rules.
- **S6 → S7**: the executor re-uses the same rules (rules 6 & 7 re-checked at fill time); S7 changes
  S6 to publish and return `NEW`; S7 adds a migration in the S3 style for executed price/reason.
- **Contracts → S6, S8, S9**: `trade-api.yaml` and `auth-api.yaml` are implemented by S6/S8 and
  **generated** into the S9 client.
- **S7 → S10**: the topics and their event payloads (esp. `cashDelta`, `positionQuantityAfter`,
  `averageCostAfter` on `trade-events`) exist so Portfolio/Notifications/Watchlists can project state
  without querying Postgres.
- **S8 → S6**: the auth service replaces the S6/S7 **test-token fixture**; adoption must be
  **config-only**.
- **S10 internal chain**: Preferences → Notifications → Watchlists (Portfolio independent).
- **Cloud week**: requires a green Sprint 10 and a locally clean stack.

---

## 10. Assumptions later sprints make about earlier sprints

These are the implicit contracts — where an unchecked assumption "costs the whole team a day in the
sprint after".

1. **S6/S7 assume the S3 schema enforces correctness in the database**: a unique constraint on
   `orders.idempotency_key` (so rule 8 and duplicate detection work by `23505`, not read-then-write),
   an `ACCOUNTS.version` column for optimistic locking, FKs and check constraints (incl. account
   state), and positions that never go negative.
2. **S6 assumes S3 exposes exactly what `trade-api.yaml` names** — both account identifiers, cash as
   decimal, positions with average cost, order history including rejected/cancelled.
3. **S6 assumes the S5 domain is transport-free** (no Spring/servlet/JDBC) so it can be hosted as
   source; the exception base carries a catalogue **code**, not an HTTP status.
4. **S7 assumes S6 order placement is characterisable and stable**, that publishing happens **after
   commit**, and that the account row still carries the version column for the executor's lock.
5. **S7's executor assumes** the fill rule can re-check rules 6 & 7 against a moved balance/price, and
   that a suspended-after-acceptance account must not trade.
6. **S7 ETL assumes** `source_order_id` is unique (idempotent merge) and that rejected/cancelled
   orders are present (fill rate needs them).
7. **S10 (Portfolio) assumes** positions carry weighted average cost and that `trade-events` carries
   enough (`cashDelta`, `*After`) to project P&L without a Postgres read dependency.
8. **S10 (Notifications/Watchlists) assume** `trade-events` and `market-data` exist with the
   contracted keys and idempotent-consumable envelope, and that Preferences exposes a resolution
   interface before Notifications is built.
9. **S8 assumes** S6 already verifies signature/expiry/issuer/algorithm and reads `JWT_SECRET` from
   config, so no Java changes on adoption; and that trading **accounts already exist** (registration
   links to `ACCOUNTS.id`, it does not create accounts).
10. **S9 assumes** the contracts are exact (client generation) and that order execution is
    **asynchronous** (an order may be `NEW` when the POST returns) — polling, not a stalled-request
    assumption.
11. **Cloud week assumes** a green Sprint 10 build and a locally clean stack, and that no secret ever
    reached the Angular bundle.
12. **Everyone assumes** the Fauxnance key stays server-side, the 2000/day quota is shared and
    respected (batch ≤25, cache, interval floor), and the `CANCELLED` literal is spelled with two Ls.

---

## 11. Unresolved ambiguities and open decisions

These are points the reference material deliberately leaves to the team, or where our design must
make and record a choice. They are the natural contents of our decision log.

1. **Operational schema shape (S3):** table count, which value is the primary/business key, how the
   customer-facing account reference maps to the internal key, how cash is stored (ledger vs balance
   column vs both), and historical-trade-data design (partitioning/archival/retention). No contract
   exists here on purpose.
2. **`VAL-422` in the exception hierarchy (S5):** the six specified exceptions have no member for
   quantity/price out of range. Add a type or argue validation alone covers it — must handle the
   Executor replaying an order that never ran a validator.
3. **Rule-8 seam without a database (S5):** how idempotency is expressible/testable in the pure
   domain while the real authority is the DB unique constraint in S6.
4. **Fill rule details (S7):** rounding/stored price precision, which rules are re-checked at fill,
   behaviour for an account suspended after acceptance, and what to do when no price is available
   (reject with a reason vs leave `NEW` — the brief says reject).
5. **Dead-letter topic shape (S7):** the `.DLT` schema is the team's decision.
6. **Poll interval + symbol universe (S7):** interval floor (quota arithmetic: 60s survives a full
   day; 30s does not overnight), which symbols to poll (held/watched only), quota-sharing between
   poller and fill path.
7. **Refresh-token revocation (S8):** rotation is required; revoking the presented token is optional
   — if not built, the residual risk must be written in the security review.
8. **Hash cost factor (S8):** argon2id/bcrypt parameters tuned to ~0.1s on target hardware.
9. **`JWT_SECRET` rotation (S8):** keep the published dev secret or rotate once a real issuer exists.
10. **Preferences: copy vs reference personal data (S10):** whether to store email/phone or reference
    the owning system; what a "no preference stored" default is (fail open vs closed).
11. **Alert "crossed" semantics (S10):** deactivate on fire vs wait-for-reset vs fire on every quote;
    per-account alert cap; behaviour when delivery fails.
12. **Portfolio cash source & currency (S10):** cash from balance endpoint vs `trade-events`
    projection; multi-currency conversion via Fauxnance `FX:` pairs vs restricting to one currency.
13. **Consumer-group scaling (S10):** one group per module, sized to partition count; how many
    Trade API instances to run.
14. **Cloud API base-URL strategy:** `localhost` (default), HTTPS tunnel, or (out of scope) deploying
    the back end; and the exact CORS posture for services holding positions.
15. **Topic naming legacy:** the spec calls the first topic `trades`; the catalogue binds it as
    `orders`. Our repo must use one name consistently (`orders`). *(See §12 D8; and §12 D1–D10 for
    the full set of spec-vs-repo conflicts, several of which are decision-log candidates in their
    own right — notably the broker-simulator, extension-architecture and portfolio-pricing choices.)*
16. **`Our-project` vs `our-project` path:** this document is created under the existing `Our-project/`
    directory (Windows is case-insensitive); confirm the intended casing if it matters for a
    case-sensitive CI/host later.

---

## 12. Reconciling `Project.pdf` (master spec) with the reference repository

The PDF is the programme's master specification; the reference-repo is the binding branch teams
actually build against, and it **explicitly supersedes the PDF** in several places. These are the
conflicts that matter for our design, with the resolution we will follow (and each is a decision-log
candidate).

| # | Topic | `Project.pdf` says | `reference-repo` says (binds) | Resolution |
|---|---|---|---|---|
| D1 | **Trade execution venue** | Executor "interacts asynchronously with the **provided Broker Simulator API**"; "Two external services are provided: a Live Pricing API and a Broker Simulator API" (FR-12, §5, §8, §10). | "There is **no broker simulator** in this platform and there will not be one. You build the execution venue." The executor prices fills against **Fauxnance live quotes** and applies the fill rule itself. | **Build the executor as the venue**; no broker-simulator dependency. Price via Fauxnance `GET /quotes/{symbol}`. |
| D2 | **Extensions: services vs packages** | "Component 8: Extension **Microservice** (Team's Choice)"; "Develop the chosen microservice"; "Connect to Spring Boot APIs and auth". | The four extensions are **packages inside the Trade REST API** — no Dockerfile, port, compose entry, or second JWT verifier. | **In-process packages** in the Trade API. Cross-module links are Java interfaces, not HTTP/microservices. |
| D3 | **Extension count** | "Select and build **one or more** extensions" (team's choice). | All **four** (Preferences, Notifications, Watchlists, Portfolio) are **mandatory**, built in dependency order; two others (advice, strategy) are stretch. | Plan for **all four mandatory**; treat advice/strategy as stretch only. |
| D4 | **Portfolio pricing timing** | Sprint 6 Trade API includes "a **provided basic Portfolio REST API** (positions, balances, priced against live market data)"; FR-07 "priced against live market data" in S6. | Sprint 6 `/balance` and `/positions` are **unpriced** (cash and qty/avg-cost only). Pricing is the **Sprint 10** Portfolio & P&L extension (`portfolio-api.yaml`), contracted separately, and no such stub is provided. | **Defer pricing to Sprint 10.** S6 positions/balance stay unpriced; Portfolio & P&L routes live on 8080 as an S10 module. |
| D5 | **Market-data stream** | Refers to a "**real-time price stream**" as if supplied; "Live Pricing API supplies market data". | Fauxnance has **no stream** (request/response only). The **Sprint 7 poller manufactures** the stream onto `market-data`. | The stream is **built** (poller), not provided. Everything price-driven downstream consumes `market-data`. |
| D6 | **Cloud = "Sprint 11"** | Cloud deployment is "**Sprint 11**: Cloud, Deployment & Final Showcase"; final showcase is the cloud week. | "This cohort has **no Sprint 11**"; cloud is a separate **Fidelity-run week after the capstone**, and the **platform showcase is at the end of Sprint 10 (week 9)**. | Treat cloud as a **post-capstone week**; the graded platform demo is end of Sprint 10. |
| D7 | **Security posture** | Aspirational/production: OAuth2-style, MFA-ready, RBAC, TLS 1.2+ in transit, **Kafka TLS/SASL/ACLs with full audit trail**, DevSecOps SAST/secret scanning. | Local dev is **plaintext Kafka, no TLS/SASL/ACL**; HS256 shared secret; production security is **documented as a plan, not implemented**. Roles are `CUSTOMER`/`ADMIN`; MFA is not in scope. | Implement the **local scope** (HS256, JWT, Bean Validation, OWASP review, SonarQube). Document TLS/SASL/ACL/MFA as a *future* plan only. |
| D8 | **Topic naming** | Specification calls the orders topic `trades`. | Catalogue binds it as **`orders`** ("one repository uses one name"). | Use **`orders`** consistently. |
| D9 | **DuckDB "Cloud"** | Tech matrix lists Data Warehouse "DuckDB — Cloud". | DuckDB is **one file on disk, no server, no account**. | Use **local file DuckDB**; portability to a hosted warehouse is a design property, not a deployment. |
| D10 | **Assessment breakdown** | §23.1 component weights (7 lines, no separate extension line). | Per-sprint absolute marks summing to 100, **including Sprint 10 = 8**. | Track against **reference-repo per-sprint marks**; use PDF weights only as a coarse grouping. |

**Additions the PDF contributes (no conflict)** and now folded into this blueprint: the programme
narrative and problem statement (§1–2 of the PDF), the "**no scaffolding supplied**" framing (no
scripts, Docker Compose, auth stub, assessment harness or boilerplate — teams build everything), team
size (4–5), the FR/NFR ID catalogue (now §6.6 here), indicative effort (~78 hrs, now in §3), the
technology-version matrix (already reflected in §2.1/§7.3), and the component-wise evaluation weights
(now in §3). Cross-cutting assessment across all components: **responsible GitHub Copilot use** (with
mandatory code walkthroughs and peer reviews confirming genuine understanding), engineering excellence,
secure-by-design, and clear communication to technical and non-technical audiences.

---

## 13. Quick reference — the error catalogue (union across contracts)

| Code | HTTP | Meaning | Contract(s) |
|---|---|---|---|
| `ACC-404` | 404 | Account not found | trade, portfolio |
| `ACC-403` | 403 | Account not active / not reachable with this token | trade, portfolio |
| `INS-404` | 404 | Instrument not found or not tradable | trade |
| `ORD-400` | 400 | Insufficient funds (buy) | trade |
| `ORD-409` | 409 | Insufficient holdings / duplicate order / not cancellable | trade |
| `VAL-422` | 422 | Invalid input | trade, auth, portfolio |
| `AUTH-401` | 401 | Unauthorised / invalid token | all |
| `AUTH-409` | 409 | Username already taken | auth |
| `MKT-503` | 503 | Pricing unavailable for every held instrument | portfolio |

---

*End of blueprint. Sources: `reference-repo/` (README, contracts, infra, sprints 03–11) and
`reference-repo/Project.pdf` (master Specification & Build Guide, 23 pp). Where the two conflict, the
reference-repo binds (see §12). This is analysis documentation only; no source code, schema, contract,
or infrastructure definition was modified in producing it.*
