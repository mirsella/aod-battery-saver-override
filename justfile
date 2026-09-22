default: build

build:
    sh scripts/build.sh

check:
    shellcheck -x -s sh module/*.sh scripts/*.sh tests/*.sh
    sh tests/policy.sh

clean:
    rm -rf dist
