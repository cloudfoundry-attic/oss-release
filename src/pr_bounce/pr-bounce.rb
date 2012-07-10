# Copyright (C) 2012 VMware, Inc. All rights reserved.
require 'bundler'
Bundler.setup

require "logger"
require "octokit"
require "optparse"
require "yaml"

def update_pull_request(log, config, client, org, repo, pr)
  closing_template = IO.read(config['templates']['closing'])

  log.info("Closing PR##{pr.number} #{org}/#{repo} at #{pr.url}")

  url = "repos/#{org}/#{repo}/pulls/#{pr.number}"

  begin
    client.post(pr._links.comments.href, :body => closing_template)
    client.patch(url, {:state => 'closed'})
  rescue => err
    log.fatal("Could not close PR#{pr.number}")
    log.fatal(err)
  end
end

def handle_pull_requests(log, config, client, org, repo)
  log.info("Getting pull requests for #{repo}")

  pulls = client.pulls(org + "/" + repo)
  min_pr_num = config['min_pr_num'][repo] || 0

  pulls.each do |pr|
    if pr.number > min_pr_num
      update_pull_request(log, config, client, org, repo, pr)
    end
  end
end

def handle_issues(log, config, client, org, repo)
  log.info("Getting issues for #{repo}")
  org_repo = org + "/" + repo

  issues = client.issues(org_repo)
  issues.each do |issue|
    begin
      closing_template = IO.read(config['templates']['closing_issue'])
      client.add_comment(org_repo, issue.number, closing_template)
      client.close_issue(org_repo, issue.number)
    rescue => err
      log.fatal("Could not close Issue #{issue.number}")
      log.fatal(err);
    end
  end
end

opts = {
  :verbose => false
}
parser = OptionParser.new do |op|
  op.banner = <<-EOT
Usage: pr-bounce.rb [options] [/path/to/config.yml]

Automatically close pull requests with a helpful message pointing to the
CF gerrit instance.

Options:
EOT

  op.on('-v', '--verbose', 'Display debugging information') do
    opts[:verbose] = true
  end
end

parser.parse!(ARGV)

unless ARGV.length == 1
  puts parser.help
  exit 1
end

begin
  config = YAML.load_file(ARGV[0])
  log = Logger.new(STDOUT)
  log.level = opts[:verbose] ? Logger::DEBUG : Logger::INFO

  # trying to use oauth is a tragedy
  client = Octokit::Client.new(
    :login    => config["username"],
    :password => ENV["PR_BOUNCE_PASSWORD"] || config["password"])
  log.info("Logged into Github with #{config['username']}")
  org = config['organization']

  log.info("Grabbing all public repos for #{org}")
  repos = client.organization_repositories(org)

  repos.each do |repo|
    handle_pull_requests(log, config, client, org, repo["name"])

    # Turn off auto-closer for issues. Issue functionality is disabled on github.
    # handle_issues(log, config, client, org, repo["name"])
  end

  log.info("Done")
rescue => e
  log.error(e.to_s)
  log.debug(e.backtrace.join("\n"))
end
