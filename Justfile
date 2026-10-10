_default:
    @just --list

# check that the local toolchain still matches the competition spec
check-env:
    #!/usr/bin/env bash
    set -uo pipefail
    fail=0
    chk() { # name actual want-prefix
      if printf '%s' "$2" | grep -q "^$3"; then
        printf '  %-10s %-16s ok\n' "$1" "$2"
      else
        printf '  %-10s %-16s WRONG (want %s*)\n' "$1" "$2" "$3"
        fail=1
      fi
    }

    echo "ioi-env — competition alignment"
    chk g++  "$(g++ -dumpversion 2>/dev/null || echo missing)" "13"
    chk vim  "$(vim --version 2>/dev/null | head -1 | awk '{print $5}' || echo missing)" "9"
    chk make "$(make --version 2>/dev/null | head -1 | awk '{print $3}' || echo missing)" "4"

    for c in gdb python3 diff timeout; do
      # `time` is deliberately excluded here: in the nix shell it resolves to
      # the coreutils one, but on some systems /usr/bin/time is a separate
      # package and `command -v time` finds the bash builtin instead.
      if command -v "$c" >/dev/null 2>&1; then
        printf '  %-10s ok\n' "$c"
      else
        printf '  %-10s MISSING\n' "$c"; fail=1
      fi
    done

    # The real guard: <print> is C++23. The judge's gcc 13.3 rejects it, so must
    # ours. If this ever compiles, the compiler pin silently drifted to a newer
    # gcc and the student's muscle memory is now wrong in the one way that
    # matters at the venue.
    t=$(mktemp -d)
    printf '#include <print>\nint main(){ std::println("x"); }\n' > "$t/cpp23.cpp"
    if g++ -O2 -std=c++17 "$t/cpp23.cpp" -o "$t/cpp23" 2>/dev/null; then
      printf '  %-10s FAIL — <print> compiled: the pin drifted to C++23\n' "std-guard"
      fail=1
    else
      printf '  %-10s ok (C++23 rejected, as the judge does)\n' "std-guard"
    fi
    rm -rf "$t"

    if [ "$fail" = 0 ]; then
      echo "  all good"
    else
      echo "  ENV DRIFTED — re-check devenv.nix"
      exit 1
    fi

# enter the student shell
shell:
    devenv shell

# update the pinned nixpkgs input (only when you mean to)
update:
    devenv update
