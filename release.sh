#!/usr/bin/env bash
#
# Github release script
# Prerequisites:
#   npm install -g trash conventional-recommended-bump conventional-changelog conventional-github-releaser conventional-commits-detector json
#
# Usage:
#   ./scripts/release.sh
#   ./scripts/release.sh patch
#   ./scripts/release.sh minor
#   ./scripts/release.sh major
#   ./scripts/release.sh <version>
#
# defaults to conventional-recommended-bump
# and optional argument preset `angular`/ `jquery` ...
# defaults to conventional-commits-detector
#-------------------------------------------------------------------------------
# Does the following:
#  1. pull from remote origin for master and develop branches
#  2. rebase master onto develop
#  3. rebase develop onto master
#  4. updates changelog
#  5. bumps version number
#  6. commits changes
#  7. creates a version tag
#  8. pushes master and tag to remote
#  9. rebase master onto develop
# 10. pushes develop to remote
# 11. creates a release on github
#-------------------------------------------------------------------------------

# define branches
develop="develop"
master="master"

gitCurrBranch() {
  ref=$(command git symbolic-ref HEAD 2> /dev/null) || \
  ref=$(command git rev-parse --short HEAD 2> /dev/null) || return
  echo "${ref#refs/heads/}"
}

updateBranches() {
  # pull latest changes from master and develop
  currBranch=`gitCurrBranch` &&
  [ "$currBranch" != $master ] && git checkout $master;
  git pull --rebase origin $master &&

  git checkout $develop
  git pull --rebase origin $develop
}

pushAll() {
  git push origin $master &&
  git push origin $develop &&
  git push --tags
}

publish() {
  # start with develop branch and make sure that master and develop
  # have both been rebased against each other
  currBranch=`gitCurrBranch` &&
  [ "$currBranch" != $master ] && git checkout $master;
  git rebase $develop &&

  # run tests
  # travis status --no-interactive &&
  trash node_modules &>/dev/null;
  npm install &&
  npm run test &&

  # bump version and build changelog
  cp package.json _package.json &&
  preset=`conventional-commits-detector` &&
  echo $preset &&
  bump=`conventional-recommended-bump -p angular` &&
  echo ${1:-$bump} &&
  npm --no-git-tag-version version ${1:-$bump} &>/dev/null &&
  conventional-changelog -i CHANGELOG.md -w -p ${2:-$preset} &&
  git add CHANGELOG.md &&
  version=`cat package.json | json version` &&

  # commit changes
  git commit -m"docs(CHANGELOG): $version" &&
  mv -f _package.json package.json &&
  npm version ${1:-$bump} -m "chore(release): %s" &&

  # push changes to remote
  git push origin $master &&
  git push origin $develop &&
  git push --tags

  # rebase master onto develop
  git checkout $develop &&
  git rebase $master &&
  git push origin $develop

  # Update github releases
  conventional-github-releaser -p ${2:-$preset}
}

pub() {
  currBranch=`gitCurrBranch` &&
  [ "$currBranch" != $master ] && git checkout $master;
  # travis status --no-interactive &&
  trash node_modules &>/dev/null;
  git pull --rebase origin develop &&
  npm install &&
  npm test &&
  cp package.json _package.json &&
  preset=`conventional-commits-detector` &&
  echo $preset &&
  bump=`conventional-recommended-bump -p angular` &&
  echo ${1:-$bump} &&
  npm --no-git-tag-version version ${1:-$bump} &>/dev/null &&
  conventional-changelog -i CHANGELOG.md -w -p ${2:-$preset} &&
  git add CHANGELOG.md &&
  version=`cat package.json | json version` &&
  git commit -m"docs(CHANGELOG): $version" &&
  mv -f _package.json package.json &&
  npm version ${1:-$bump} -m "chore(release): %s" &&
  git push --follow-tags &&
  conventional-github-releaser -p ${2:-$preset}
  # npm publish
}

if [[ "$1" == "update" ]]; then
  updateBranches

elif [[ "$1" == "push" ]]; then
  pushAll

elif [[ "$1" == "pub" ]]; then
  pub patch

elif [[ "$1" == "patch" ]]; then
  publish $1

elif [[ "$1" == "minor" ]]; then
  publish $1

elif [[ "$1" == "major" ]]; then
  publish $1

else
  publish $1
fi

