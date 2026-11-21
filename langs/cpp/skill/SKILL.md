---
name: cpp-best-practices
description: C and C++ playbook for building or learning: CMake layout and targets, sanitizers, clang-tidy, RAII, Core Guidelines, common pitfalls. Use when asked how to structure, build, test, debug or improve a C or C++ project, or to explain C/C++ practice.
---

Use only for C and C++. Answer from this, adapted to what the project already does.

## Layout and build (common convention, not from a mandated source)
- `CMakeLists.txt`, `include/`, `src/`, `tests/`, and an out-of-source `build/`. Configure with `cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`, build with `cmake --build build`, test with `ctest --test-dir build --output-on-failure`.
- Per-target CMake: `target_link_libraries`, `target_include_directories`, `target_compile_features` with PRIVATE, PUBLIC or INTERFACE as appropriate. Use `find_package` and imported `Foo::Foo` targets.

## Sanitizers (Clang docs; GCC accepts the same flags)
- `-fsanitize=address,undefined -g -fno-omit-frame-pointer -O1`. Add `-fno-sanitize-recover=undefined` in tests, or UBSan prints and continues. `UBSAN_OPTIONS=print_stacktrace=1`, `ASAN_OPTIONS=detect_leaks=1`.
- Limits: ASan does not support static linking, costs about 2x slowdown plus memory and is not for production; `-Wl,-z,defs` breaks its link; UBSan's `vptr` and `unsigned-integer-overflow` are not in the `undefined` group.

## Static analysis
- `clang-tidy -p build -checks=-*,bugprone-*,cert-*,cppcoreguidelines-* --warnings-as-errors=*` (the flag enables no checks by itself); `clang-tidy -list-checks` shows what is on. The `cert-*` checks cover only a subset of the SEI CERT rules (categories include MEM, STR, INT, ARR, FIO, ERR, CON).

## Core Guidelines worth knowing (C++)
- R.1 and R.11: RAII, no explicit `new` / `delete`. R.3: raw pointers are non-owning. ES.20: always initialize. ES.48: avoid casts. ES.78: no implicit fallthrough. C.21: define or delete all special members together. C.35: base destructors public and virtual, or protected and non-virtual. SL.con.1: prefer `std::array` or `vector`. Con.1: immutable by default. CP.20: RAII locks.

Sources: C++ Core Guidelines, CMake buildsystem and packages manuals, Clang AddressSanitizer and UndefinedBehaviorSanitizer docs, clang-tidy docs, SEI CERT C and C++ standards.
<!-- managed by claude-code-setup -->
