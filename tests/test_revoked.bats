#!/usr/bin/env bats

load _test_base

function setup {
  install_fixture_key "$TEST_REVOKED_USER"

  set_state_initial
  set_state_git
  set_state_secret_init
  set_state_secret_tell "$TEST_REVOKED_USER"
  revoke_fixture_key "$TEST_REVOKED_USER"
}

function teardown {
  uninstall_fixture_key "$TEST_REVOKED_USER"
  unset_current_state
}

@test "test 'hide' using revoked key" {
  FILE_TO_HIDE="$TEST_DEFAULT_FILENAME"
  FILE_CONTENTS="hidden content юникод"
  set_state_secret_add "$FILE_TO_HIDE" "$FILE_CONTENTS"

  run git secret hide   
  # this should fail, because we're using a revoked key....
  # But it works because we didn't tell any keyservers like pgp.mit.edi

  echo "# output of hide: $output" >&3
    # output should look something like 
    # 'abort: problem encrypting file with gpg: exit code 2: space file'
  echo "# status of hide: $status" >&3

  [ $status -eq 0 ] # we expect failure here. Actual code is 2
	# FIXME - works fine, lets us hide with revoked key
}


@test "run 'whoknows -l' on only revoked user" {
  run git secret whoknows -l
  [ "$status" -eq 0 ]

  # diag output for bats-core
  echo "# output of 'whoknows -l: $output" >&3
  echo >&3
    # output should look like 'abort: problem encrypting file with gpg: exit code 2: space file'
  #echo "# status of hide: $status" >&3

  [[ "$output" == *"$TEST_REVOKED_USER (expires: never)"* ]]
}

@test "run 'reveal' with revoked user" {
  run git secret reveal
  [ "$status" -eq 0 ]
}



@test "run 'whoknows -l' on revoked and normal user" {
  install_fixture_key "$TEST_DEFAULT_USER"
  set_state_secret_tell "$TEST_DEFAULT_USER"

  run git secret whoknows -l
  [ "$status" -eq 0 ]

  echo $output | sed 's/^/# whoknows -l: /' >&3
  echo >&3

  # Now test the output, both users should be present:
  [[ "$output" == *"$TEST_DEFAULT_USER (expires: never)"* ]]
  [[ "$output" == *"$TEST_REVOKED_USER (expires: never)"* ]]

  uninstall_fixture_key "$TEST_DEFAULT_USER"
}

function teardown {
  uninstall_fixture_key "$TEST_REVOKED_USER"
  unset_current_state
}
