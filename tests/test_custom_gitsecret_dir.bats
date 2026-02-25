#!/usr/bin/env bats
# Tests for git-secret when SECRETS_DIR is in a subdirectory of the project.
# Replicates the scenario from https://github.com/sobolevn/git-secret/issues/1209

load _test_base

FINGERPRINT=""

function setup {
  FINGERPRINT=$(install_fixture_full_key "$TEST_DEFAULT_USER")

  set_state_initial
  set_state_git
  set_state_secret_init  # init standard .gitsecret so teardown works
}


function teardown {
  rm -rf "secrets-dir"   # clean up test artifact even if test failed

  uninstall_fixture_full_key "$TEST_DEFAULT_USER" "$FINGERPRINT"
  unset_current_state
}


@test "hide and reveal both work when SECRETS_DIR is in a subdirectory" {
  # Replicate the exact steps from the issue report:
  # https://github.com/sobolevn/git-secret/issues/1209
  #
  # The issue claims that hide uses _prepend_root_path and reveal uses
  # _prepend_relative_root_path, so no single path format in mapping.cfg
  # satisfies both commands when run from a subdirectory.

  local password
  password=$(test_user_password "$TEST_DEFAULT_USER")

  mkdir secrets-dir

  ( # start subshell: all operations run from inside secrets-dir/
    cd secrets-dir

    # SECRETS_DIR=secrets-dir/.git-secret git secret init
    SECRETS_VERBOSE=1 SECRETS_DIR=secrets-dir/.git-secret run git secret init
    [ "$status" -eq 0 ]

    # SECRETS_DIR=secrets-dir/.git-secret git secret tell user@example.com
    SECRETS_VERBOSE=1 SECRETS_DIR=secrets-dir/.git-secret run git secret tell \
      -d "$TEST_GPG_HOMEDIR" "$TEST_DEFAULT_USER"
    [ "$status" -eq 0 ]

    # echo "password123" > credentials.txt
    echo "password123" > credentials.txt

    # SECRETS_DIR=secrets-dir/.git-secret git secret add credentials.txt
    SECRETS_VERBOSE=1 SECRETS_DIR=secrets-dir/.git-secret run git secret add credentials.txt
    [ "$status" -eq 0 ]

    # Show what was stored in mapping.cfg so we can see the path format
    echo "# mapping.cfg contents:" >&3
    cat "../secrets-dir/.git-secret/paths/mapping.cfg" >&3

    # SECRETS_DIR=secrets-dir/.git-secret git secret hide
    SECRETS_VERBOSE=1 SECRETS_DIR=secrets-dir/.git-secret run git secret hide
    echo "# hide output: $output" >&3
    [ "$status" -eq 0 ]

    # SECRETS_DIR=secrets-dir/.git-secret git secret reveal -f
    # (we add -d and -p for the test GPG homedir/passphrase)
    SECRETS_VERBOSE=1 SECRETS_DIR=secrets-dir/.git-secret run git secret reveal \
      -d "$TEST_GPG_HOMEDIR" -p "$password" -f
    echo "# reveal output: $output" >&3
    [ "$status" -eq 0 ]

    # Verify the revealed content is correct
    [ -f credentials.txt ]
    [ "$(cat credentials.txt)" = "password123" ]

  ) # end subshell

  rm -rf secrets-dir
}


@test "hide -d deletes plaintext file when SECRETS_DIR is in a subdirectory" {
  # This tests the _optional_delete function in git_secret_hide.sh which uses
  # the filename directly without _prepend_root_path, causing it to silently
  # fail to delete the file when run from a subdirectory.
  #
  # mapping.cfg stores root-relative paths like "secrets-dir/credentials.txt".
  # _optional_delete checks: if [[ -e "$filename" ]] — but from inside
  # secrets-dir/, "secrets-dir/credentials.txt" resolves to
  # secrets-dir/secrets-dir/credentials.txt (doesn't exist), so the file is
  # never deleted.

  local password
  password=$(test_user_password "$TEST_DEFAULT_USER")

  mkdir secrets-dir

  ( # start subshell: all operations run from inside secrets-dir/
    cd secrets-dir

    SECRETS_VERBOSE=1 SECRETS_DIR=secrets-dir/.git-secret run git secret init
    [ "$status" -eq 0 ]

    SECRETS_VERBOSE=1 SECRETS_DIR=secrets-dir/.git-secret run git secret tell \
      -d "$TEST_GPG_HOMEDIR" "$TEST_DEFAULT_USER"
    [ "$status" -eq 0 ]

    echo "password123" > credentials.txt

    SECRETS_VERBOSE=1 SECRETS_DIR=secrets-dir/.git-secret run git secret add credentials.txt
    [ "$status" -eq 0 ]

    # hide -d should encrypt the file AND delete the plaintext
    SECRETS_VERBOSE=1 SECRETS_DIR=secrets-dir/.git-secret run git secret hide -d
    echo "# hide -d output: $output" >&3
    [ "$status" -eq 0 ]

  ) # end subshell

  # The plaintext file must have been deleted by the -d flag.
  # This assertion is outside the subshell so that bats can give a clear
  # error message showing WHICH assertion actually failed.
  [ ! -f secrets-dir/credentials.txt ]

  rm -rf secrets-dir
}
