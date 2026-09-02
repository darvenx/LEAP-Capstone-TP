# Sprint 5 — the trading domain engine

Plain-Java domain module: accounts, instruments, orders and positions, and the eight business
rules that govern order placement. No Spring, no servlet API, no JDBC, no MyBatis, no
connection pool — enforced by the build itself (`maven-enforcer-plugin`'s `bannedDependencies`
rule), not just by convention.

## Building and testing

```bash
mvn clean test        # runs the suite; reports land in target/surefire-reports/
mvn clean install     # also installs the jar to the local repo, for Sprint 6 to resolve
mvn dependency:tree   # shows the full resolved tree - jakarta.validation-api (compile)
                       # and the JUnit 5 test tree, nothing else
```

Requires Java 21 and Maven 3.9+. No Docker, no network access and no environment variables are
needed to run the suite.

## Layout

| Path | What's there |
|---|---|
| `src/main/java/com/etleap/trading/domain/` | The three enumerations, the four entities, `OrderPlacementRules`, the idempotency seam |
| `src/main/java/com/etleap/trading/domain/dto/` | `PlaceOrderRequest`, `FieldViolation`, `PlaceOrderRequestValidator` |
| `src/main/java/com/etleap/trading/domain/exception/` | `TradingDomainException` and its seven subtypes |
| `src/main/java/com/etleap/trading/domain/support/` | `Money`, the exactly-two-decimal-places normalization helper every entity holding a `BigDecimal` calls |
| `src/test/java/...` | Mirrors the four packages above, one test class per production class, plus the three named classes the brief requires: `AccountTest`, `OrderLogicTest`, `PlaceOrderRequestValidationTest` |
| `design/class-diagram.md` | UML class diagram (Mermaid) |
| `design/sequence-diagram.md` | UML sequence diagram of order placement (Mermaid) |
| `design/decisions.md` | The two design decisions the brief asks for, and why the rule evaluation order is what it is |

## Base package

Declared once, in `manifest.env`: `com.etleap.trading.domain`. Sprint 6 absorbs this package,
under this exact name, as source into the Trade REST API's own build.

## Test-first

Every production class in this module was preceded by its test in the commit history — `git
log --oneline` shows a `test:` commit that fails to compile, immediately followed by the `feat:`
commit that makes it pass, class by class. `git log -p -- src/main/java/.../Account.java
src/test/java/.../AccountTest.java` walks that pair for `Account` specifically.
