#include <gtest/gtest.h>

#include "demo/calculator.hpp"

TEST(CalculatorTest, Adds) {
    const demo::Calculator calc;
    EXPECT_EQ(calc.add(2, 3), 5);
}

TEST(CalculatorTest, Divides) {
    const demo::Calculator calc;
    EXPECT_EQ(calc.divide(10, 2), 5);
}

TEST(CalculatorTest, Factorial) {
    const demo::Calculator calc;
    EXPECT_EQ(calc.factorial(5), 120U);
}

TEST(CalculatorTest, SumsHistory) {
    demo::Calculator calc;
    calc.push(1);
    calc.push(2);
    calc.push(3);
    EXPECT_EQ(calc.sum(), 6);
}

TEST(CalculatorTest, PrimesNaiveAndSieveAgree) {
    const demo::Calculator calc;
    EXPECT_EQ(calc.count_primes_naive(100), 25U);
    EXPECT_EQ(calc.count_primes_sieve(100), 25U);
    EXPECT_EQ(calc.count_primes_sieve(2), 0U);
}
