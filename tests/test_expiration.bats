#!/usr/bin/env bats

load _test_base

function setup {
  install_fixture_key "$TEST_EXPIRED_USER"

  set_state_initial
  set_state_git
  set_state_secret_init
  set_state_secret_tell "$TEST_EXPIRED_USER"
}

function teardown {
  uninstall_fixture_key "$TEST_EXPIRED_USER"
  unset_current_state
}

@test "test fetching user key expiration date" {
  local expiry
  expiry=$(_get_user_key_expiry "$TEST_EXPIRED_USER")
  if [[ $expiry = '' ]]; then
    expiry='never'
  fi

  echo "# expiry of user '$TEST_EXPIRED_USER': $expiry" >&3
  [ "$expiry" -eq  "1537745045" ]
  # that's 'Sun Sep 23 19:24:05 2018'
}


