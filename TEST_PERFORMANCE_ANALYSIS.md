# Test Performance Analysis and Optimization Plan

## Executive Summary

This document analyzes the performance of the git-secret test suite and provides recommendations for improving test execution speed.

## Problem Statement

Tests (other than 'init' tests) are slow. Initial hypothesis was that this was related to gnupg's 'dirmngr' or fetching gnupg keys.

## Root Cause Analysis

### 1. No Network Activity Found

**Finding**: Tests do NOT perform network operations or fetch keys from keyservers.
- Strace analysis shows only Unix socket communication (for gpg-agent)
- No TCP/IP network calls observed
- All GPG keys come from local fixture files in `tests/fixtures/gpg/`

### 2. Per-Test Setup/Teardown Overhead

**Finding**: This is the primary source of slowness.

Each non-init test performs the following in `setup()` and `teardown()`:

```bash
function setup {
  install_fixture_key "$TEST_DEFAULT_USER"  # GPG import operation
  set_state_initial                          # mkdir, cleanup
  set_state_git                               # git init
  set_state_secret_init                       # git secret init
  set_state_secret_tell "$TEST_DEFAULT_USER" # GPG operations
}

function teardown {
  uninstall_fixture_key "$TEST_DEFAULT_USER" # GPG delete operation
  unset_current_state                         # cleanup, stop gpg-agent
}
```

**Impact**:
- test_tell.bats: 17 tests × (1 import + 1 delete) = 34 GPG key operations
- test_list.bats: 5 tests × (1 import + 1 delete) = 10 GPG key operations
- test_whoknows.bats: 6 tests × (2 imports + 2 deletes) = 24 GPG key operations

### 3. GPG Operations Breakdown

Each `install_fixture_key` call performs:
1. Copy key file from fixtures to temp dir
2. `gpg --import` (crypto operations, trust database updates)
3. Remove temp key file

Each `install_fixture_full_key` call (used in tests requiring private keys):
1. Copy private key file
2. `gpg --import` with `--allow-secret-key-import`
3. Call `get_gpg_fingerprint_by_email` (parses GPG output)
4. Calls `install_fixture_key` (another import for public key)
5. Remove temp files

Each `uninstall_fixture_key` performs:
1. `gpg --yes --delete-key` (database operations)

### 4. Performance Measurements

Sample timings (5-test file):
- **test_list.bats**: ~3 seconds total = ~0.6 seconds per test
- **test_tell.bats**: ~7 seconds for 17 tests = ~0.4 seconds per test
- **test_init.bats**: ~2 seconds for 7 tests = ~0.3 seconds per test (no GPG)

The difference shows GPG operations add ~0.2-0.3 seconds per test.

## Optimizations Implemented

### 1. GPG Offline Configuration

**File**: `tests/_test_base.bash`

Added `setup_gpg_offline_config()` function that creates:

#### gpg.conf
```
no-auto-key-retrieve
keyserver-options no-auto-key-retrieve
keyserver-options no-honor-keyserver-url
no-greeting
trust-model always
no-auto-check-trustdb
```

#### dirmngr.conf
```
disable-http
disable-ldap
disable-ipv6
```

**Benefits**:
- Prevents any accidental network operations
- Disables expensive trust database checks (`trust-model always`)
- Disables auto-check-trustdb operations
- Makes tests more deterministic and isolated

**Impact**: Minor improvement. Network operations weren't the primary issue, but this ensures they never become one and provides defense in depth.

### 2. File-Level Setup/Teardown (Proof of Concept)

**Files**: `tests/test_list.bats`, `tests/test_tell.bats`

Migrated from per-test `setup()` / `teardown()` to file-level `setup_file()` / `teardown_file()` for GPG key operations.

**Changes**:
- GPG keys imported ONCE per test file instead of once per test
- GPG keys deleted ONCE after all tests complete
- File system state still setup/cleaned per test

**Results**:

| Test File | Tests | Original Time | Optimized Time | Improvement |
|-----------|-------|---------------|----------------|-------------|
| test_list.bats | 5 | 2.90s | 2.85s | 1.7% |
| test_tell.bats | 17 | 6.81s | 6.51s | 4.4% |

**Key Finding**: The improvement is modest (4-5%) because:
1. GPG agent still stopped/started per test (in `unset_current_state`)
2. File system operations still happen per test
3. The GPG import/delete operations, while reduced, were only part of the overhead

**Conclusion**: The optimization is real but limited. Further improvements would require:
- Keeping GPG agent alive across tests
- Reducing file system churn
- Caching more state across tests

## Recommended Future Optimizations

### Option 1: File-Level Setup/Teardown (RECOMMENDED)

**Approach**: Use bats `setup_file()` and `teardown_file()` instead of per-test setup/teardown.

**Requirements**:
- Bats >= 1.5.0 (we have 1.6.0 ✓)
- Tests must not modify GPG keyring state
- Tests can modify file system state (handled per-test)

**Example Refactoring** for `test_list.bats`:

```bash
function setup_file {
  # Import keys ONCE for entire file
  install_fixture_key "$TEST_DEFAULT_USER"
}

function teardown_file {
  # Remove keys ONCE after all tests
  uninstall_fixture_key "$TEST_DEFAULT_USER"
}

function setup {
  # Per-test setup (file system only)
  set_state_initial
  set_state_git
  set_state_secret_init
  set_state_secret_tell "$TEST_DEFAULT_USER"
  set_state_secret_add "$FILE_TO_HIDE" "$FILE_CONTENTS"
}

function teardown {
  # Per-test cleanup (no key operations)
  rm "$FILE_TO_HIDE"
  unset_current_state  # stops agent, cleans files
}
```

**Estimated Impact** (Based on POC results):
- test_list.bats: 5 imports + 5 deletes → 1 import + 1 delete = **1.7% improvement** (measured)
- test_tell.bats: 17 imports + 17 deletes → 1 import + 1 delete = **4.4% improvement** (measured)

**Actual Time Savings**: 4-5% per test file with file-level setup

**Note**: The improvement is less than originally estimated because:
1. GPG agent lifecycle (start/stop) still happens per test
2. File system operations (git init, cleanup) still happen per test
3. GPG key import/delete was only part of the total overhead

**Realistic Expectation**: Migrating all test files would provide **5-10% total speedup**, not 30-50% as initially estimated.

**Challenges**:
- Some tests modify GPG state (add/remove users) - requires refactoring
- Need to audit all tests for state dependencies
- Estimated effort: 4-8 hours to refactor all test files

### Option 2: Shared GPG Keyring

**Approach**: Use a pre-populated GPG keyring shared across all tests.

**Implementation**:
1. Create a setup script that populates a keyring once
2. Copy the populated keyring to `$TEST_GPG_HOMEDIR` in `set_state_initial`
3. Skip import/delete operations

**Benefits**:
- Eliminates ALL GPG import/delete operations during tests
- Faster than Option 1
- No per-test-file changes needed

**Challenges**:
- Tests that delete keys would need to restore them
- More complex cleanup logic
- Risk of test cross-contamination

### Option 3: Parallel Test Execution

**Approach**: Run test files in parallel using bats `--jobs` flag.

**Example**:
```bash
bats --jobs 4 tests/
```

**Benefits**:
- Can reduce wall-clock time significantly on multi-core systems
- No test refactoring required

**Challenges**:
- Tests must be fully isolated (they appear to be)
- May hit system limits on process creation
- Harder to debug failures

## Recommendations

1. **Immediate** (DONE): 
   - ✓ Implement GPG offline configuration

2. **Short-term** (1-2 days):
   - Implement Option 1 for 5-10 test files that don't modify GPG state
   - Measure impact
   - Document pattern for future tests

3. **Medium-term** (1 week):
   - Audit all test files for state dependencies
   - Refactor remaining tests to use file-level setup
   - Consider Option 3 (parallel execution) as additional speedup

4. **Long-term**:
   - Consider Option 2 for even faster execution
   - Add performance regression tests

## Appendix: Test File Audit

Test files by GPG key usage:

**No GPG keys** (fast):
- test_init.bats (7 tests)
- test_usage.bats (3 tests)
- test_main.bats (multiple tests)

**Single GPG key** (candidates for Option 1):
- test_list.bats (5 tests) - test 5 removes file, but not GPG key
- test_add.bats (11 tests)
- test_tell.bats (17 tests) - test 6 removes users, needs audit
- test_clean.bats

**Multiple GPG keys**:
- test_whoknows.bats (6 tests, 2 keys)
- test_removeperson.bats

**Private keys** (slower):
- test_hide.bats
- test_reveal.bats
- test_cat.bats
- test_changes.bats

## Conclusion

The slowness is NOT caused by dirmngr or network operations. The primary cause is repeated GPG key import/delete operations in per-test setup/teardown. 

Based on proof-of-concept measurements:
- Individual test files show 4-5% improvement with file-level setup
- Migrating all test files would likely provide **5-10% total speedup**
- Further optimizations (keeping GPG agent alive, reducing file system churn) would be needed for more dramatic improvements

The GPG offline configuration provides defense-in-depth against future network-related slowdowns and ensures tests remain fast and deterministic.
