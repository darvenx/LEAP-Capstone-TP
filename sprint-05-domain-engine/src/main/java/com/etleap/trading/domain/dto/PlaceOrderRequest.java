package com.etleap.trading.domain.dto;

import com.etleap.trading.domain.OrderSide;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/**
 * The inbound request to place an order. This is {@code PlaceOrderRequest} in
 * {@code contracts/trade-api.yaml} and that schema is binding.
 *
 * <p>These six constraints are business constraints rather than transport constraints, which
 * is why this type lives in the domain module and not in the Sprint 6 service: a second caller
 * gets them without reimplementing them. The {@code jakarta.validation} annotations below are
 * declarations, not behaviour - documentation for whatever Bean Validation provider Sprint 6
 * wires up - and are not themselves what enforces the rules in this module.
 * {@link PlaceOrderRequestValidator} enforces every one of them by hand, deliberately: the
 * Trade Executor replays an order in Sprint 7 without ever running a Bean Validation
 * {@code Validator} (there is no HTTP request, no DTO binding, no controller in that path), so
 * these six constraints - and rules 4 and 5, which mirror two of them - must hold even for a
 * caller that skips annotation processing entirely.
 */
public record PlaceOrderRequest(

        @NotNull
        @Min(1)
        Long accountId,

        @NotNull
        @NotBlank
        @Size(max = 20)
        String symbol,

        @NotNull
        OrderSide side,

        @NotNull
        @Positive
        Long quantity,

        @NotNull
        @DecimalMin(value = "0.0", inclusive = false)
        @Digits(integer = 15, fraction = 2)
        BigDecimal price,

        @NotNull
        @Size(min = 8, max = 100)
        String idempotencyKey
) {
}
