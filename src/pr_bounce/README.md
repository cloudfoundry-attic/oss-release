# pr-bounce - A script to automatically close Github Pull Requests

This script should be run in cron. It will autoclose Github Pull Requests since
Github does not allow the Pull Request feature to be turned off. It will also
autoclose issues since Cloudfoundry use the below site to track issues.

https://cloudfoundry.atlassian.net/secure/Dashboard.jspa

# How does it work?

We query the Github API for a list of open pull requests and close them with a
message.

# Configuration

This script reads the file "config.yaml" in the current directory. Here is an
example:

    ---
    organization: 'setec_astronomy'
    username: 'bishop'
    password: 'toomanysecrets'
    templates:
      closing: 'templates/closing.html'
      closing_issue: 'templates/closing_issue.html'
    min_pr_num:
      foo: 42
      bar: 10

The above config would close any Pull Requests newer than #42 in the foo repo
and newer than #10 in the bar repo, which both are part of the
'setec\_astronomy' organization. It also close any open issues.

# Running

    cd pr-bounce        # rvm triggered
    ruby pr-bounce.rb

To specify a different config filename, use the PR\_BOUNCE\_PCONFIG env var:

    PR_BOUNCE_CONFIG=/foo/bar.yaml ruby pr-bounce.rb

# Authors

Jonathan "Duke" Leto, Monica Wilkinson

# Copyright

Copyright (C) 2012 VMware, Inc. All rights reserved.

# License

Apache 2.0
