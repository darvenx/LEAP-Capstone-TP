package com.etleap.trading.domain;

import java.util.Objects;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * An {@link IdempotencyKeyRegistry} with no database behind it, for this sprint and for tests.
 * {@link ConcurrentHashMap#newKeySet()}'s {@code add} is itself a single atomic
 * compare-and-set, which is exactly the race-safety property {@link IdempotencyKeyRegistry}
 * requires: no read-then-write, no window in which two callers can both believe they were
 * first.
 */
public final class InMemoryIdempotencyKeyRegistry implements IdempotencyKeyRegistry {

    private final Set<String> registeredKeys = ConcurrentHashMap.newKeySet();

    @Override
    public boolean register(String idempotencyKey) {
        Objects.requireNonNull(idempotencyKey, "idempotencyKey must not be null");
        return registeredKeys.add(idempotencyKey);
    }
}
