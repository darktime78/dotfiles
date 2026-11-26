#include <algorithm>
#include <iostream>
#include <random>
#include <span>
#include <string_view>
#include <vector>

#include "demo/calculator.hpp"

namespace {

// `demo_app --bench`: something worth profiling (<leader>pr, args: --bench)
int bench() {
    const demo::Calculator calc;
    std::cout << "naive primes: " << calc.count_primes_naive(1'200'000) << '\n';   // hot spot
    std::cout << "sieve primes: " << calc.count_primes_sieve(20'000'000) << '\n';

    std::vector<std::uint32_t> values(3'000'000);
    std::mt19937 rng{42};
    std::ranges::generate(values, rng);
    std::ranges::sort(values);  // std:: frames, try the "only my code" filter
    std::cout << "median: " << values[values.size() / 2] << '\n';
    return 0;
}

}  // namespace

int main(int argc, char* argv[]) {
    const std::span<char*> args(argv, static_cast<std::size_t>(argc));
    if (args.size() > 1 && std::string_view{args[1]} == "--bench") {
        return bench();
    }

    demo::Calculator calc;
    for (int i = 1; i <= 5; ++i) {
        calc.push(static_cast<std::int64_t>(i) * 10);  // F9 here, then F5
    }

    const auto f = calc.factorial(6);  // F11 to step into the recursion (stack view)
    std::cout << "sum = " << calc.sum() << ", 6! = " << f << '\n';

    if (const auto q = calc.divide(10, 0); !q) {
        std::cout << "division by zero\n";
    }
    return 0;
}
