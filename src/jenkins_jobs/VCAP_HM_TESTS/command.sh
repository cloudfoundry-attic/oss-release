export PATH=$VCAP_RUBY19/bin:$PATH

HM_DIR=$PWD/health_manager
CC_DIR=$PWD/cloud_controller
SPEC_DIR=$HM_DIR/spec_reports

rm -rvf $SPEC_DIR
rm -rvf $PWD/tests/assets

# PATHS NEEDED IN THE CONTAINER
DEA_RUBY19_REALPATH=`readlink -nf $DEA_RUBY19`
SQLITE_REALPATH=`readlink -nf /var/vcap/packages/sqlite`
RUBY_BD=$DEA_RUBY19_REALPATH/bin
SQLITE_LIB=$SQLITE_REALPATH/lib
SQLITE_INC=$SQLITE_REALPATH/include

TEST_RUNNER=`mktemp`

cat <<-EOT > $TEST_RUNNER
#!/bin/bash
set -o errexit
set -o nounset
export PATH=$RUBY_BD:$PATH
export C_INCLUDE_PATH=$SQLITE_INC:$C_INCLUDE_PATH
export LIBRARY_PATH=$SQLITE_LIB:$LIBRARY_PATH
cd /tmp/cloud_controller
bundle install --deployment --without development production
cd /tmp/health_manager
bundle install --deployment --without development production
bundle exec rake prepare_test_db
bundle exec rake ci:spec
EOT

HANDLE=`$CREATE_CONTAINER $DEA_RUBY19_REALPATH $SQLITE_REALPATH`
$WARDEN_REPL -c "
copy $HANDLE in $CC_DIR /tmp
copy $HANDLE in $HM_DIR /tmp
copy $HANDLE in $TEST_RUNNER /tmp
run $HANDLE chmod +x $TEST_RUNNER
run $HANDLE $TEST_RUNNER
copy $HANDLE out /tmp/health_manager/spec_reports $HM_DIR vcap:vcap
destroy $HANDLE
"

rm -f $TEST_RUNNER
