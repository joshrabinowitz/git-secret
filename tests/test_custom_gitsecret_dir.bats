#!/usr/bin/env bats

# Tests for git-secret with SECRETS_DIR pointing to a subdirectory.
# Replicates the scenario from https://github.com/sobolevn/git-secret/issues/1209

load _test_base

FINGERPRINT=""


function setup {
  FINGERPRINT=$(install_fixture_full_key "$TEST_DEFAULT_USER")

  set_state_initial
  set_state_git
  set_state_secret_init
}


function teardown {
  rm -rf "secrets-dir"

  uninstall_fixture_full_key "$TEST_DEFAULT_USER" "$FINGERPRINT"
  unset_current_state
}


@test "hide and reveal both work when SECRETS_DIR is in a subdirectory" {
  local password
  password=$(test_user_password "$TEST_DEFAULT_USER")

  local secrets_subdir='secrets-dir'
  mkdir "$secrets_subdir"

  ( # start subshell for following commands
    cd "$secrets_subdir"

    SECRETS_DIR=secrets-dir/.git-secret run git secret init
    [ "$status" -eq 0 ]

    SECRETS_DIR=secrets-dir/.git-secret run git secret tell \
      -d "$TEST_GPG_HOMEDIR" "$TEST_DEFAULT_USER"
    [ "$status" -eq 0 ]

    echo "password123" > credentials.txt

    SECRETS_DIR=secrets-dir/.git-secret run git secret add credentials.txt
    [ "$status" -eq 0 ]

    SECRETS_DIR=secrets-dir/.git-secret run git secret hide
    [ "$status" -eq 0 ]

    SECRETS_DIR=secrets-dir/.git-secret run git secret reveal \
      -d "$TEST_GPG_HOMEDIR" -p "$password" -f
    [ "$status" -eq 0 ]
  ) # end subshell

  # Verify the revealed file exists and has the correct content:
  [ -f "$secrets_subdir/credentials.txt" ]
  [ "$(cat "$secrets_subdir/credentials.txt")" = "password123" ]

  # clean up
  rm -rf "$secrets_subdir"
}


@test "hide -d deletes plaintext file when SECRETS_DIR is in a subdirectory" {
  local secrets_subdir='secrets-dir'
  mkdir "$secrets_subdir"

  ( # start subshell for following commands
    cd "$secrets_subdir"

    SECRETS_DIR=secrets-dir/.git-secret run git secret init
    [ "$status" -eq 0 ]

    SECRETS_DIR=secrets-dir/.git-secret run git secret tell \
      -d "$TEST_GPG_HOMEDIR" "$TEST_DEFAULT_USER"
    [ "$status" -eq 0 ]

    echo "password123" > credentials.txt

    SECRETS_DIR=secrets-dir/.git-secret run git secret add credentials.txt
    [ "$status" -eq 0 ]

    SECRETS_DIR=secrets-dir/.git-secret run git secret hide -d
    [ "$status" -eq 0 ]
  ) # end subshell

  # The plaintext must have been deleted by the -d flag:
  [ ! -f "$secrets_subdir/credentials.txt" ]

  # clean up
  rm -rf "$secrets_subdir"
}
