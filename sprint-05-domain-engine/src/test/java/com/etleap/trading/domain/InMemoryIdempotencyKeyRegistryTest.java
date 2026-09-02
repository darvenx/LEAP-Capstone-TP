package com.etleap.trading.domain;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;

import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Rule 8's design decision, made testable without a database: in Sprint 6 the authority on an
 * idempotency key is the unique constraint on {@code orders.idempotency_key}, not a read
 * followed by a write - two concurrent requests carrying the same key would both pass a
 * read-then-write check and duplicate a trade. {@link IdempotencyKeyRegistry#register} models
 * that unique-constraint semantics directly: it is a single atomic operation that both checks
 * and claims the key, so it is expressible and testable here, before there is a database.
 */
class InMemoryIdempotencyKeyRegistryTest {

    @Test
    void aKeySeenForTheFirstTimeIsAccepted() {
        IdempotencyKeyRegistry registry = new InMemoryIdempotencyKeyRegistry();

        assertTrue(registry.register("key-one"));
    }

    @Test
    void theSameKeySeenAgainIsRefused() {
        IdempotencyKeyRegistry registry = new InMemoryIdempotencyKeyRegistry();
        registry.register("key-one");

        assertFalse(registry.register("key-one"));
    }

    @Test
    void differentKeysAreEachAcceptedIndependently() {
        IdempotencyKeyRegistry registry = new InMemoryIdempotencyKeyRegistry();

        assertTrue(registry.register("key-one"));
        assertTrue(registry.register("key-two"));
    }

    @Test
    void rejectsANullKey() {
        IdempotencyKeyRegistry registry = new InMemoryIdempotencyKeyRegistry();

        assertThrows(NullPointerException.class, () -> registry.register(null));
    }

    @Test
    @Timeout(10)
    void exactlyOneOfManyConcurrentRegistrationsOfTheSameKeyWins() throws Exception {
        // This is the property a read-then-write check cannot guarantee: fire N threads at the
        // same key simultaneously (a CountDownLatch holds every thread at the gate so they are
        // all racing, not merely running one after another) and demand exactly one winner,
        // exactly as a unique constraint on orders.idempotency_key would in Sprint 6.
        final int concurrentCallers = 64;
        IdempotencyKeyRegistry registry = new InMemoryIdempotencyKeyRegistry();
        ExecutorService pool = Executors.newFixedThreadPool(concurrentCallers);
        CountDownLatch gate = new CountDownLatch(1);

        try {
            List<Callable<Boolean>> attempts = IntStream.range(0, concurrentCallers)
                    .<Callable<Boolean>>mapToObj(i -> () -> {
                        gate.await();
                        return registry.register("shared-key");
                    })
                    .collect(Collectors.toList());

            // submit(), not invokeAll(): invokeAll() blocks until every task finishes, but
            // every task is parked on the gate - submitting must return immediately so the
            // gate can be released afterwards, letting all callers race at once.
            List<Future<Boolean>> futures = attempts.stream()
                    .map(pool::submit)
                    .collect(Collectors.toList());
            gate.countDown();

            AtomicInteger winners = new AtomicInteger(0);
            for (Future<Boolean> future : futures) {
                if (future.get(5, TimeUnit.SECONDS)) {
                    winners.incrementAndGet();
                }
            }

            assertEquals(1, winners.get(), "exactly one concurrent caller must win the race for the same key");
        } finally {
            pool.shutdownNow();
        }
    }
}
