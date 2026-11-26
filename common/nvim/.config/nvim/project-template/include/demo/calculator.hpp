#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <vector>

namespace demo {

class Calculator {
public:
    Calculator() = default;

    [[nodiscard]] std::int64_t add(std::int64_t a, std::int64_t b) const noexcept;
    [[nodiscard]] std::optional<std::int64_t> divide(std::int64_t a, std::int64_t b) const noexcept;
    [[nodiscard]] std::uint64_t factorial(unsigned n) const noexcept;  // recursive: watch the stack

    void push(std::int64_t value);
    [[nodiscard]] std::int64_t sum() const noexcept;

    // Profiling workload: the naive version is the deliberate hot spot.
    [[nodiscard]] std::size_t count_primes_naive(std::size_t limit) const noexcept;
    [[nodiscard]] std::size_t count_primes_sieve(std::size_t limit) const;

private:
    std::vector<std::int64_t> history_;
};

}  // namespace demo
