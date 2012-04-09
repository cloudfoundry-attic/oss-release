export PATH=$VCAP_RUBY19/bin:$PATH

rm -rvf $PWD/tests/assets

RUBY19_REALPATH=`readlink -nf $VCAP_RUBY19`
COMMON=$PWD/common
CF_EM_GEM=$PWD/stager/vendor/cache/eventmachine-0.12.11.cloudfoundry.3.gem
TEST_RUNNER=`mktemp`
cat <<-EOT > $TEST_RUNNER
#!/bin/bash
set -o errexit
export VCAP_TEST_LOG=true
export PATH=$RUBY19_REALPATH/bin:$PATH
cd /tmp/common
mkdir -p vendor/cache
cp -lunv ../eventmachine-0.12.11.cloudfoundry.3.gem vendor/cache/
bin/fetch_gems ./Gemfile ./Gemfile.lock ./vendor/cache
bundle install --no-color --deployment --without development production
bundle exec rake spec
EOT

HANDLE=`$CREATE_CONTAINER $RUBY19_REALPATH`
$WARDEN_REPL -e -c "
copy $HANDLE in $COMMON /tmp
copy $HANDLE in $CF_EM_GEM /tmp
copy $HANDLE in $TEST_RUNNER /tmp
run $HANDLE chmod +x $TEST_RUNNER
run $HANDLE $TEST_RUNNER
destroy $HANDLE
"

rm -f $TEST_RUNNER
