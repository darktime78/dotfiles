# Thin wrapper over CMake presets:  make build | test | run | coverage | profile | format
PRESET ?= debug

CXX_SOURCES   := $(shell find src include tests -type f \( -name '*.cpp' -o -name '*.hpp' \))
CMAKE_SOURCES := CMakeLists.txt $(wildcard cmake/*.cmake)

.PHONY: configure build test run coverage profile format format-check clean

configure:
	cmake --preset $(PRESET)

build: configure
	cmake --build --preset $(PRESET)

test: build
	ctest --preset $(PRESET)

run: build
	./build/$(PRESET)/demo_app

coverage:
	cmake --preset coverage
	cmake --build --preset coverage --target coverage

profile:
	cmake --preset profile
	cmake --build --preset profile
	perf record -F 499 --call-graph dwarf -- ./build/profile/demo_app --bench

format:
	clang-format -i $(CXX_SOURCES)
	cmake-format -i $(CMAKE_SOURCES)

format-check:
	clang-format --dry-run --Werror $(CXX_SOURCES)
	cmake-format --check $(CMAKE_SOURCES)

clean:
	rm -rf build
