#!/usr/bin/env bash

set -euo pipefail

DEFAULT_IMAGE="ubuntu:latest"
REPO_URL="https://github.com/aliceptve/dotfiles-gu.git"

IMAGE="$DEFAULT_IMAGE"
MODE="manual"
BRANCH=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Start an ephemeral container, install dotfiles, then open an interactive shell
or run automated checks.

OPTIONS:
  --image IMAGE    Base Docker image to use (default: ${DEFAULT_IMAGE})
  --branch BRANCH  Branch to check out (default: repo default branch)
  --auto           Run automated checks instead of an interactive shell
  -h, --help       Show this help message

EXAMPLES:
  $(basename "$0")
  $(basename "$0") --image mcr.microsoft.com/devcontainers/base:ubuntu
  $(basename "$0") --branch my-feature
  $(basename "$0") --auto
  $(basename "$0") --auto --image ubuntu:24.04
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --image)
      if [[ $# -lt 2 ]]; then
        printf "Error: --image requires an argument\n" >&2
        usage >&2
        exit 1
      fi
      IMAGE="$2"
      shift 2
      ;;
    --branch)
      if [[ $# -lt 2 ]]; then
        printf "Error: --branch requires an argument\n" >&2
        usage >&2
        exit 1
      fi
      BRANCH="$2"
      shift 2
      ;;
    --auto)
      MODE="auto"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf "Error: unknown option: %s\n" "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v docker &>/dev/null; then
  printf "Error: docker is not available on PATH. Install Docker and try again.\n" >&2
  exit 1
fi

printf "\033[36mImage:\033[0m  %s\n" "$IMAGE"
printf "\033[36mMode:\033[0m   %s\n" "$MODE"
printf "\033[36mBranch:\033[0m %s\n\n" "${BRANCH:-(default)}"

case "$MODE" in
  manual)
    printf "Starting interactive session (container will be removed on exit)...\n"
    # install.sh uses a relative path on its first line (>> .bash_aliases), so it must be
    # invoked from the home directory for that path to resolve to ~/.bash_aliases correctly.
    docker run --rm -it \
      -e "DEBIAN_FRONTEND=noninteractive" \
      "$IMAGE" \
      bash -c "apt-get update -q \
        && apt-get install -y -q sudo git \
        && useradd -m -s /bin/bash testuser \
        && echo 'testuser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
        && su - testuser -c 'cd ~ \
          && git clone ${BRANCH:+--branch ${BRANCH} }${REPO_URL} dotfiles \
          && pushd dotfiles \
          && bash install.sh \
          && popd \
          && exec bash'"
    ;;
  auto)
    printf "\033[1mInstalling dotfiles...\033[0m\n"
    # Pass the repo URL as an environment variable so the single-quoted heredoc
    # (which prevents outer-shell expansion) can still reference it inside the container.
    docker run --rm -i \
      -e "DEBIAN_FRONTEND=noninteractive" \
      -e "DOTFILES_REPO=${REPO_URL}" \
      -e "DOTFILES_BRANCH=${BRANCH}" \
      "$IMAGE" \
      bash -s <<'SCRIPT'
set -euo pipefail
# Set up a non-root user with sudo to match real target environments.
printf "  creating test user...\n" >&2
apt-get update -q >/dev/null
apt-get install -y -q sudo git >/dev/null
useradd -m -s /bin/bash testuser
echo 'testuser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Write the test script so it can be executed as the non-root user.
cat > /tmp/dotfiles-test.sh <<'TESTSCRIPT'
set -euo pipefail
cd ~
printf "  cloning dotfiles...\n" >&2
git clone -q ${DOTFILES_BRANCH:+--branch "$DOTFILES_BRANCH" }"$DOTFILES_REPO" dotfiles-gu
printf "  running install.sh...\n" >&2
pushd dotfiles-gu >/dev/null
bash install.sh >/dev/null
popd >/dev/null
printf "  setup complete.\n" >&2

# Non-interactive bash neither sources ~/.bash_aliases nor enables alias processing.
# Both are required: shopt enables the alias table, source loads the definitions.
shopt -s expand_aliases
source ~/.bash_aliases

PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"
  if [[ "$result" == "pass" ]]; then
    printf "  \033[32mPASS\033[0m: %s\n" "$desc"
    PASS=$((PASS + 1))
  else
    printf "  \033[31mFAIL\033[0m: %s\n" "$desc"
    FAIL=$((FAIL + 1))
  fi
}

printf "\n\033[1mRunning checks...\033[0m\n"

if [[ -f ~/.bash_aliases ]]; then
  check ".bash_aliases exists" "pass"
else
  check ".bash_aliases exists" "fail"
fi

if grep -q "aliceptve/dotfiles-gu" ~/.bash_aliases 2>/dev/null; then
  check ".bash_aliases contains dotfiles header" "pass"
else
  check ".bash_aliases contains dotfiles header" "fail"
fi

for name in la ll gatus hex2rgb cu gog; do
  if type "$name" &>/dev/null; then
    check "$name is available" "pass"
  else
    check "$name is available" "fail"
  fi
done

if type emacs &>/dev/null; then
  check "emacs is available" "pass"
else
  check "emacs is available" "fail"
fi

if [[ -f /usr/share/liquidprompt/liquidprompt ]]; then
  check "liquidprompt is installed" "pass"
else
  check "liquidprompt is installed" "fail"
fi

if [[ -f ~/.emacs.d/init.el ]]; then
  check "emacs config is installed" "pass"
else
  check "emacs config is installed" "fail"
fi

if [[ -f ~/.copilot/instructions/writing-style.instructions.md ]]; then
  check "copilot instructions are installed" "pass"
else
  check "copilot instructions are installed" "fail"
fi

if [[ $FAIL -gt 0 ]]; then
  printf "\n\033[1;31mResults: %d passed, %d failed\033[0m\n" "$PASS" "$FAIL"
else
  printf "\n\033[1;32mResults: %d passed, %d failed\033[0m\n" "$PASS" "$FAIL"
fi
[[ $FAIL -eq 0 ]]
TESTSCRIPT

# Run the test script as testuser, forwarding the environment variables.
# Use printf %q to safely escape values for the inner shell.
su - testuser -c "DOTFILES_REPO=$(printf %q "$DOTFILES_REPO") DOTFILES_BRANCH=$(printf %q "$DOTFILES_BRANCH") bash /tmp/dotfiles-test.sh"
SCRIPT
    ;;
esac