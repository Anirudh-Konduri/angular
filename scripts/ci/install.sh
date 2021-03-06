#!/usr/bin/env bash

set -u -e -o pipefail

TRAVIS=${TRAVIS:-}
CI_MODE=${CI_MODE:-}

# Setup environment
readonly thisDir=$(cd $(dirname $0); pwd)
source ${thisDir}/_travis-fold.sh


# If the previous commands in the `script` section of .travis.yaml failed, then abort.
# The variable is not set in early stages of the build, so we default to 0 there.
# https://docs.travis-ci.com/user/environment-variables/
if [[ ${TRAVIS_TEST_RESULT=0} == 1 ]]; then
  exit 1;
fi


mkdir -p ${LOGS_DIR}


# TODO: install nvm?? it's already on travis so we don't need it
#curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.0/install.sh | bash


# Install node
#nvm install ${NODE_VERSION}

if [[ ${CI_MODE} != "aio" && ${CI_MODE} != 'docs_test' ]]; then
  # Install version of npm that we are locked against
  travisFoldStart "install-npm"
    npm install -g npm@${NPM_VERSION}
  travisFoldEnd "install-npm"


  # Install all npm dependencies according to shrinkwrap.json
  travisFoldStart "npm-install"
    node tools/npm/check-node-modules --purge || npm install
  travisFoldEnd "npm-install"


  # Install Selenium WebDriver
  travisFoldStart "webdriver-manager-update"
    $(npm bin)/webdriver-manager update
  travisFoldEnd "webdriver-manager-update"


  # Install bower packages
  travisFoldStart "bower-install"
    $(npm bin)/bower install
  travisFoldEnd "bower-install"
fi


if [[ ${TRAVIS} && (${CI_MODE} == "e2e" || ${CI_MODE} == "e2e_2" || ${CI_MODE} == "aio" || ${CI_MODE} == "aio_e2e" || ${CI_MODE} == "aio_tools_test") ]]; then
  # Install version of yarn that we are locked against
  travisFoldStart "install-yarn"
    curl -o- -L https://yarnpkg.com/install.sh | bash -s -- --version "${YARN_VERSION}"
  travisFoldEnd "install-yarn"
fi


if [[ ${TRAVIS} && (${CI_MODE} == "aio" || ${CI_MODE} == "aio_e2e" || ${CI_MODE} == "aio_tools_test") ]]; then
  # angular.io: Install all yarn dependencies according to angular.io/yarn.lock
  travisFoldStart "yarn-install.aio"
    (
      cd ${PROJECT_ROOT}/aio
      yarn install
    )
  travisFoldEnd "yarn-install.aio"
fi

# Install bazel
if [[ ${TRAVIS} && (${CI_MODE} == "bazel" || ${CI_MODE} == "e2e_2") ]]; then
  travisFoldStart "bazel-install"
  (
    mkdir tmp
    cd tmp
    curl --location --compressed https://github.com/bazelbuild/bazel/releases/download/0.5.2/bazel-0.5.2-installer-linux-x86_64.sh > bazel-0.5.2-installer-linux-x86_64.sh
    chmod +x bazel-0.5.2-installer-linux-x86_64.sh
    ./bazel-0.5.2-installer-linux-x86_64.sh --user
    cd ..
    rm -rf tmp
  )
  travisFoldEnd "bazel-install"
fi

# Start xvfb for local Chrome testing
if [[ ${TRAVIS} && (${CI_MODE} == "js" || ${CI_MODE} == "e2e" || ${CI_MODE} == "e2e_2" || ${CI_MODE} == "aio" || ${CI_MODE} == "aio_e2e") ]]; then
  travisFoldStart "xvfb-start"
    sh -e /etc/init.d/xvfb start
  travisFoldEnd "xvfb-start"
fi


# Install Sauce Connect
if [[ ${TRAVIS}] && (${CI_MODE} == "saucelabs_required" || ${CI_MODE} == "saucelabs_optional") ]]; then
  travisFoldStart "install-sauceConnect"
    (
      ${thisDir}/../sauce/sauce_connect_setup.sh
    )
  travisFoldEnd "install-sauceConnect"
fi


# Install BrowserStack Tunnel
if [[ ${TRAVIS} && (${CI_MODE} == "browserstack_required" || ${CI_MODE} == "browserstack_optional") ]]; then
  travisFoldStart "install-browserstack"
    (
      ${thisDir}/../browserstack/start_tunnel.sh
    )
  travisFoldEnd "install-browserstack"
fi

# Print return arrows as a log separator
travisFoldReturnArrows
