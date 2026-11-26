#include "demo/calculator.hpp"

#include <numeric>

namespace demo {

std::int64_t Calculator::add(std::int64_t a, std::int64_t b) const noexcept { return a + b; }

std::optional<std::int64_t> Calculator::divide(std::int64_t a, std::int64_t b) const noexcept {
    if (b == 0) {
        return std::nullopt;  // not tested on purpose -> shows as uncovered
    }
    return a / b;
}

std::uint64_t Calculator::factorial(unsigned n) const noexcept {
    if (n <= 1) {
        return 1;
    }
    return n * factorial(n - 1);
}

void Calculator::push(std::int64_t value) { history_.push_back(value); }

std::int64_t Calculator::sum() const noexcept {
    return std::accumulate(history_.begin(), history_.end(), std::int64_t{0});
}

}  // namespace demo

namespace demo {

std::size_t Calculator::count_primes_naive(std::size_t limit) const noexcept {
    std::size_t count = 0;
    for (std::size_t n = 2; n < limit; ++n) {
        bool prime = true;
        for (std::size_t d = 2; d * d <= n; ++d) {
            if (n % d == 0) {
                prime = false;
                break;
            }
        }
        if (prime) {
            ++count;
        }
    }
    return count;
}

std::size_t Calculator::count_primes_sieve(std::size_t limit) const {
    if (limit < 3) {
        return 0;
    }
    std::vector<bool> composite(limit, false);
    std::size_t count = 0;
    for (std::size_t n = 2; n < limit; ++n) {
        if (composite[n]) {
            continue;
        }
        ++count;
        for (std::size_t m = n * n; m < limit; m += n) {
            composite[m] = true;
        }
    }
    return count;
}

}  // namespace demo
