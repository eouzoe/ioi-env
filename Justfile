_default:
    @just --list

# check that the local toolchain still matches the competition spec
check-env:
    devenv tasks run ioi-env:verify

# enter the student shell
shell:
    devenv shell

# update the pinned nixpkgs input (only when you mean to)
update:
    devenv update
