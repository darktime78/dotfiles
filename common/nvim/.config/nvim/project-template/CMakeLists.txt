cmake_minimum_required(VERSION 3.21)
project(
  demo
  VERSION 0.1.0
  LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(BUILD_TESTS "Build GoogleTest unit tests" ON)
option(ENABLE_COVERAGE "Instrument code for gcov coverage" OFF)
option(ENABLE_PROFILING "Keep frame pointers for perf call graphs" OFF)

if(ENABLE_PROFILING)
  add_compile_options(-fno-omit-frame-pointer)
endif()

# --- library under test + application ----------------------------------------
add_library(demo_core src/calculator.cpp)
target_include_directories(demo_core PUBLIC include)
target_compile_options(demo_core PRIVATE -Wall -Wextra -Wpedantic)

if(ENABLE_COVERAGE)
  target_compile_options(demo_core PRIVATE --coverage -O0 -g)
  target_link_options(demo_core PUBLIC --coverage)
endif()

add_executable(demo_app src/main.cpp)
target_link_libraries(demo_app PRIVATE demo_core)

# --- GoogleTest ----------------------------------------------------------------
if(BUILD_TESTS)
  include(FetchContent)
  FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/refs/tags/v1.17.0.tar.gz
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
  set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(googletest)

  enable_testing()
  add_executable(unit_tests tests/calculator_test.cpp)
  target_link_libraries(unit_tests PRIVATE demo_core GTest::gtest_main)

  include(GoogleTest)
  gtest_discover_tests(unit_tests)
endif()

# --- coverage: ctest -> gcovr -> build/<preset>/coverage.info (+ HTML) ----------
if(ENABLE_COVERAGE AND BUILD_TESTS)
  find_program(GCOVR_EXE gcovr REQUIRED)
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    set(GCOV_TOOL "llvm-cov gcov")
  else()
    set(GCOV_TOOL "gcov")
  endif()

  add_custom_target(
    coverage
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/coverage-html
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure
    COMMAND
      ${GCOVR_EXE} --root ${CMAKE_SOURCE_DIR} --filter ${CMAKE_SOURCE_DIR}/src/ --filter
      ${CMAKE_SOURCE_DIR}/include/ --gcov-executable ${GCOV_TOOL} --delete --print-summary --lcov
      ${CMAKE_BINARY_DIR}/coverage.info --html-details ${CMAKE_BINARY_DIR}/coverage-html/index.html
      ${CMAKE_BINARY_DIR}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    DEPENDS unit_tests
    COMMENT "Running tests and collecting coverage"
    VERBATIM)
endif()

# --- formatting targets (cmake --build --preset debug --target format) ---------
file(GLOB_RECURSE PROJECT_CXX_SOURCES CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/src/*.[ch]pp
     ${CMAKE_SOURCE_DIR}/include/*.[ch]pp ${CMAKE_SOURCE_DIR}/tests/*.[ch]pp)
find_program(CLANG_FORMAT_EXE clang-format)
find_program(CMAKE_FORMAT_EXE cmake-format)

if(CLANG_FORMAT_EXE)
  add_custom_target(
    format
    COMMAND ${CLANG_FORMAT_EXE} -i ${PROJECT_CXX_SOURCES}
    COMMENT "clang-format"
    VERBATIM)
  add_custom_target(
    format-check
    COMMAND ${CLANG_FORMAT_EXE} --dry-run --Werror ${PROJECT_CXX_SOURCES}
    COMMENT "clang-format --dry-run"
    VERBATIM)
  if(CMAKE_FORMAT_EXE)
    add_custom_command(
      TARGET format
      POST_BUILD
      COMMAND ${CMAKE_FORMAT_EXE} -i ${CMAKE_SOURCE_DIR}/CMakeLists.txt
      VERBATIM)
  endif()
endif()
