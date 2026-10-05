#!/usr/bin/env bash
# Trusted pre-checks for the release workflow. They run from this public
# repository, before any file of the private checkout executes:
#
#   SOURCE_REF  the private commit to release (40 hex characters)
#   SOURCE_DIR  the private checkout, at SOURCE_REF, with origin/main fetched
#   PUBLIC_DIR  this repository's checkout (default: the working directory)
#
# Refuses a revision that is not on the private main (an unmerged commit could
# change any build script while keeping packaging/distribution/ intact), and a
# public tree that differs from packaging/distribution/ at that revision (the
# monorepo holds the only copy of these files).
set -euo pipefail

source_ref="${SOURCE_REF:?SOURCE_REF is required}"
source_dir="${SOURCE_DIR:?SOURCE_DIR is required}"
public_dir="${PUBLIC_DIR:-.}"

refuse() {
  echo "provenance: $*" >&2
  exit 1
}

[[ "${source_ref}" =~ ^[0-9a-f]{40}$ ]] || refuse "source_ref must be a full 40-character commit hash, got '${source_ref}'"
checked_out="$(git -C "${source_dir}" rev-parse HEAD)"
[[ "${checked_out}" == "${source_ref}" ]] || refuse "the private checkout is at ${checked_out}, not ${source_ref}; it must be checked out at source_ref"
git -C "${source_dir}" merge-base --is-ancestor "${source_ref}" refs/remotes/origin/main \
  || refuse "${source_ref} is not on the private main; release only reviewed, merged commits"

if ! drift="$(diff -r --brief --exclude=.git "${source_dir}/packaging/distribution" "${public_dir}" 2>&1)"; then
  printf '%s\n' "${drift}" | sed "s#${source_dir}/##; s#${public_dir}#public tree#" >&2
  refuse "this repository differs from packaging/distribution at ${source_ref}; run packaging/release/public-repo.sh sync from that revision first"
fi
echo "provenance: ${source_ref} is on the private main and this repository matches its packaging/distribution"
