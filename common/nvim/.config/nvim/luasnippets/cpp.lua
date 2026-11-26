-- C++ snippets for LuaSnip.  Expand with <Tab>, jump with <Tab>/<S-Tab>,
-- cycle choices (capture list, typename/class, specifiers…) with <C-l>.
local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local c = ls.choice_node
local d = ls.dynamic_node
local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep

-- my_widget.hpp -> MyWidget ; calculator_test.cpp -> CalculatorTest
local function pascal_from_file()
  local name = vim.fn.expand("%:t:r")
  if name == "" then
    return "MyClass"
  end
  name = name:gsub("[_%-](%w)", function(ch)
    return ch:upper()
  end)
  name = name:gsub("^%l", string.upper)
  return name
end

local function name_node(pos)
  return d(pos, function()
    return sn(nil, { i(1, pascal_from_file()) })
  end)
end

local function capture(pos)
  return c(pos, { t(""), t("&"), t("="), t("this"), i(nil, "x") })
end

local function lambda_spec(pos)
  return c(pos, {
    t(""),
    sn(nil, { t(" -> "), i(1, "auto") }),
    t(" mutable"),
    t(" noexcept"),
    t(" constexpr"),
  })
end

local function tkind(pos)
  return c(pos, { t("typename"), t("class") })
end

return {
  ---------------------------------------------------------------------------
  -- Classes
  ---------------------------------------------------------------------------
  s({ trig = "class", dscr = "class with ctor/dtor" }, fmt([[
class {} {{
public:
    {}();
    ~{}();

    {}

private:
    {}
}};
]], { name_node(1), rep(1), rep(1), i(2, "// public API"), i(3, "// data members") })),

  s({ trig = "classr5", dscr = "class with the rule of five" }, fmt([[
class {} {{
public:
    {}();
    ~{}();

    {}(const {}& other);
    {}& operator=(const {}& other);
    {}({}&& other) noexcept;
    {}& operator=({}&& other) noexcept;

    {}

private:
    {}
}};
]], {
    name_node(1), rep(1), rep(1),
    rep(1), rep(1), rep(1), rep(1),
    rep(1), rep(1), rep(1), rep(1),
    i(2, "// public API"), i(3, "// data members"),
  })),

  s({ trig = "classmo", dscr = "move-only class (copy deleted)" }, fmt([[
class {} {{
public:
    {}() = default;
    ~{}() = default;

    {}(const {}&) = delete;
    {}& operator=(const {}&) = delete;
    {}({}&&) noexcept = default;
    {}& operator=({}&&) noexcept = default;

    {}

private:
    {}
}};
]], {
    name_node(1), rep(1), rep(1),
    rep(1), rep(1), rep(1), rep(1),
    rep(1), rep(1), rep(1), rep(1),
    i(2, "// public API"), i(3, "// data members"),
  })),

  s({ trig = "iface", dscr = "abstract interface" }, fmt([[
class {} {{
public:
    virtual ~{}() = default;

    virtual {} {}({}) = 0;
}};
]], { name_node(1), rep(1), i(2, "void"), i(3, "run"), i(4) })),

  s({ trig = "struct", dscr = "struct" }, fmt([[
struct {} {{
    {}
}};
]], { name_node(1), i(2) })),

  ---------------------------------------------------------------------------
  -- Templates
  ---------------------------------------------------------------------------
  s({ trig = "tclass", dscr = "class template" }, fmt([=[
template <{} {}>
class {} {{
public:
    {}() = default;
    explicit {}({} value) : value_{{std::move(value)}} {{}}

    [[nodiscard]] const {}& value() const noexcept {{ return value_; }}

    {}

private:
    {} value_{{}};
}};
]=], { tkind(1), i(2, "T"), name_node(3), rep(3), rep(3), rep(2), rep(2), i(4), rep(2) })),

  s({ trig = "tfn", dscr = "function template" }, fmt([[
template <{} {}>
{} {}({} {}) {{
    {}
}}
]], { tkind(1), i(2, "T"), i(3, "auto"), i(4, "func"), i(5, "const T&"), i(6, "value"), i(7) })),

  s({ trig = "tvar", dscr = "variadic template + perfect forwarding" }, fmt([[
template <typename... {}>
{} {}({}&&... {}) {{
    {}
}}
]], { i(1, "Args"), i(2, "void"), i(3, "func"), rep(1), i(4, "args"), i(5, "(std::forward<Args>(args), ...);") })),

  s({ trig = "tspec", dscr = "full template specialization" }, fmt([[
template <>
{} {}<{}> {{
    {}
}};
]], { c(1, { t("struct"), t("class") }), i(2, "Name"), i(3, "int"), i(4) })),

  s({ trig = "concept", dscr = "C++20 concept" }, fmt([[
template <typename {}>
concept {} = requires({} {}) {{
    {{ {} }} -> std::{}<{}>;
}};
]], { i(1, "T"), i(2, "Addable"), rep(1), i(3, "a"), i(4, "a + a"), i(5, "convertible_to"), rep(1) })),

  s({ trig = "treq", dscr = "constrained template (requires)" }, fmt([[
template <typename {}>
    requires {}
{} {}({} {}) {{
    {}
}}
]], { i(1, "T"), i(2, "std::integral<T>"), i(3, "auto"), i(4, "func"), i(5, "T"), i(6, "value"), i(7) })),

  ---------------------------------------------------------------------------
  -- Lambdas
  ---------------------------------------------------------------------------
  s({ trig = "lam", dscr = "lambda [capture](params) spec { }" }, fmt([[
[{}]({}){} {{
    {}
}}
]], { capture(1), i(2), lambda_spec(3), i(4) })),

  s({ trig = "laml", dscr = "named lambda: auto fn = [..](..) { };" }, fmt([[
auto {} = [{}]({}){} {{
    {}
}};
]], { i(1, "fn"), capture(2), i(3), lambda_spec(4), i(5) })),

  s({ trig = "glam", dscr = "generic lambda (auto&&)" }, fmt([[
[{}](auto&& {}) {{
    {}
}}
]], { capture(1), i(2, "x"), i(3) })),

  s({ trig = "tlam", dscr = "C++20 template lambda" }, fmt([[
[{}]<typename {}>({} {}) {{
    {}
}}
]], { capture(1), i(2, "T"), i(3, "const T&"), i(4, "x"), i(5) })),

  s({ trig = "iife", dscr = "immediately-invoked lambda for const init" }, fmt([[
const auto {} = [&]() {{
    {}
}}();
]], { i(1, "value"), i(2, "return 0;") })),

  s({ trig = "sortl", dscr = "std::ranges::sort with comparator lambda" }, fmt([[
std::ranges::sort({}, [](const auto& a, const auto& b) {{ return {}; }});
]], { i(1, "v"), i(2, "a < b") })),

  ---------------------------------------------------------------------------
  -- Misc
  ---------------------------------------------------------------------------
  s({ trig = "main", dscr = "main()" }, fmt([[
#include <{}>

int main({}) {{
    {}
    return 0;
}}
]], { i(1, "iostream"), c(2, { t(""), t("int argc, char* argv[]") }), i(3) })),

  s({ trig = "ns", dscr = "namespace" }, fmt([[
namespace {} {{

{}

}}  // namespace {}
]], { i(1, "detail"), i(2), rep(1) })),

  s({ trig = "once", dscr = "#pragma once" }, t("#pragma once")),

  s({ trig = "forr", dscr = "range-based for" }, fmt([[
for ({} {} : {}) {{
    {}
}}
]], { c(1, { t("const auto&"), t("auto&"), t("auto&&"), t("auto") }), i(2, "item"), i(3, "container"), i(4) })),

  s({ trig = "fori", dscr = "index for" }, fmt([[
for (std::size_t {} = 0; {} < {}; ++{}) {{
    {}
}}
]], { i(1, "i"), rep(1), i(2, "n"), rep(1), i(3) })),

  ---------------------------------------------------------------------------
  -- GoogleTest
  ---------------------------------------------------------------------------
  s({ trig = "test", dscr = "GoogleTest TEST()" }, fmt([[
TEST({}, {}) {{
    {}
}}
]], { name_node(1), i(2, "Works"), i(3, "EXPECT_EQ(1, 1);") })),

  s({ trig = "testf", dscr = "GoogleTest TEST_F()" }, fmt([[
TEST_F({}, {}) {{
    {}
}}
]], { name_node(1), i(2, "Works"), i(3) })),

  s({ trig = "fixture", dscr = "GoogleTest fixture" }, fmt([[
class {} : public ::testing::Test {{
protected:
    void SetUp() override {{
        {}
    }}

    void TearDown() override {{
        {}
    }}

    {}
}};
]], { name_node(1), i(2), i(3), i(4) })),

  s({ trig = "gtmain", dscr = "GoogleTest main()" }, fmt([[
#include <gtest/gtest.h>

int main(int argc, char** argv) {{
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}}
]], {})),
}
