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
counter=0

log() {
  ((counter+=1))
  echo ""
  echo ""
  echo "---- [$counter]: ${1} ----";
}

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
  log "update branches" &&                             # 1
  updateBranches &&
  # start with develop branch and make sure that master and develop
  # have both been rebased against each other
  currBranch=`gitCurrBranch` &&
  log "checkout $master" &&                            # 2
  [ "$currBranch" != $master ] && git checkout $master;
  log "rebase $develop" &&                             # 3
  git rebase $develop &&

  # run tests
  # travis status --no-interactive &&
  log "trash node_modules" &&                          # 4
  trash node_modules &>/dev/null;
  log "npm install" &&                                 # 5
  npm install &&
  log "npm run test" &&                                # 6
  npm run test &&

  # bump version and build changelog
  log "copy package.json" &&                           # 7
  cp package.json _package.json &&
  log "conventional-commits-detector" &&               # 8
  preset=`conventional-commits-detector` &&
  echo $preset &&
  log "conventional-recommended-bump" &&               # 9
  bump=`conventional-recommended-bump -p angular` &&
  echo ${1:-$bump} &&
  log "npm version no git tag" &&                      # 10
  npm --no-git-tag-version version ${1:-$bump} &>/dev/null &&
  log "conventional-changelog" &&                      # 11
  conventional-changelog -i CHANGELOG.md -w -p ${2:-$preset} &&
  log "git add changelog" &&                           # 12
  git add CHANGELOG.md &&
  version=`cat package.json | json version` &&

  # commit changes
  log "git commit changelog" &&                        # 13
  git commit -m"docs(CHANGELOG): $version" &&
  log "mv package.json" &&                             # 14
  mv -f _package.json package.json &&
  log "npm version" &&                                 # 15
  npm version ${1:-$bump} -m "chore(release): %s" &&

  # push changes to remote master
  log "git pull --rebase origin $master"               # 16
  git pull --rebase origin $master
  log "git push origin $master" &&                     # 17
  git push origin $master &&

  # push tags to remote
  log "git push tags" &&                               # 19
  git push --tags &&

  # rebase master onto develop
  log "git checkout $develop" &&                       # 20
  git checkout $develop &&
  log "git rebase master" &&                           # 21
  git rebase $master &&
  log "git pull --rebase origin $develop"              # 22
  git pull --rebase origin $develop
  log "git push origin $develop" &&                    # 23
  git push origin $develop &&

  # Update github releases
  log "conventional-github-releaser ${2:-$preset}" &&  # 24
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

