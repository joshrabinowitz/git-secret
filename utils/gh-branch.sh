#!/usr/bin/env bash

set -e


function update_gh_branch {
  local branch_name

  branch_name=$(git branch | grep '\*' | sed 's/* //')

  git checkout 'origin/gh-pages'
  make

  git add '_posts'
  git commit -m 'documentation update'
  git checkout "$branch_name"
}

update_gh_branch
