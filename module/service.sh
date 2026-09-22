#!/system/bin/sh
set -eu
# Shared late-start entry point for KernelSU, KernelSU Next, and Magisk.
MODDIR=${0%/*}
# shellcheck source=module/policy.sh
. "$MODDIR/policy.sh"
wait_for_boot
apply_policy
