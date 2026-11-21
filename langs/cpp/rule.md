---
paths:
  - "**/*.c"
  - "**/*.h"
  - "**/*.cc"
  - "**/*.cpp"
  - "**/*.cxx"
  - "**/*.hh"
  - "**/*.hpp"
  - "**/CMakeLists.txt"
---

# C and C++ guardrails
The project's own build and style config (CMakeLists, .clang-format, .clang-tidy, CI) wins over these. For a fuller guide, use the cpp-best-practices skill.
- Debug builds use sanitizers: `-fsanitize=address,undefined -g -fno-omit-frame-pointer -O1`, plus `-fno-sanitize-recover=undefined` in tests so UBSan fails instead of printing and continuing. A sanitizer report is a bug, not noise.
- Run clang-tidy against a compile database: `cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`, then `clang-tidy -p build <file>` (bugprone, cert and cppcoreguidelines checks).
- C++: no explicit `new` / `delete` (Core Guidelines R.11); own resources with RAII handles; a raw `T*` is non-owning. Initialize every object. Avoid casts. No implicit switch fallthrough. Define or delete copy, move and destructor together; prefer `std::array` / `std::vector` to C arrays; immutable by default; RAII locks, not manual lock and unlock.
- C: check every return value, pass sizes with buffers, never `gets`, `strcpy` or `sprintf`; free what you allocate exactly once on every path.
- CMake: express dependencies per target (`target_link_libraries`, `target_include_directories`, `target_compile_features`, each with PRIVATE, PUBLIC or INTERFACE); use imported `Foo::Foo` targets from `find_package`.
- Do not rely on undefined behaviour; say so when code near it looks risky.
<!-- managed by claude-code-setup -->
