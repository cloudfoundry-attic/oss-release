#!/usr/bin/env ruby

require "optparse"
require "yaml"
require "pp"

ENV['BUNDLE_GEMFILE'] = File.dirname(__FILE__) + '/Gemfile'

require "rubygems"
require "bundler/setup"
require "pony"
require "net/ssh"

def get_reviewer(notification, project)
  reviewers = Array.new
  notification.each_key do |team|
    if notification[team].include? project
      reviewers.push team
    end
  end
  return reviewers
end

config_path =  File.dirname(__FILE__)
config_file = File.join(config_path, "config", "gerrit_hooks.yml")
notification_file = File.join(config_path, "config", "notification_config.yml")
options = {}

opts = OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"
  opts.separator ""
  opts.separator "Specific options:"
  [:change, :project, :branch, :commit, :patchset, :"change-url"].each do |flag|
    opts.on("--#{flag} #{flag.to_s.upcase}", flag.to_s) do |value|
      options[flag] = value
    end
  end
end

begin
  opts.parse!(ARGV)
rescue OptionParser::InvalidOption
  retry
end

begin
  config = File.open(config_file) do |f|
    YAML.load(f)
  end
  notification = File.open(notification_file) do |f|
    YAML.load(f)
  end
rescue => e
  puts "Could not read configuration file: #{e}"
  exit 1
end

subject = `git show --format='%s' #{options[:commit]}`.split("\n").first
pretty_stat = `git show --color --stat #{options[:commit]} | #{File.join(File.dirname(__FILE__), "ansi2html.sh")}`
plain_stat = `git show --stat #{options[:commit]}`

html_body = <<EOF
If you're interested to review this code please visit<br/>
<br/>
&nbsp;&nbsp;&nbsp;&nbsp;<a href="#{options[:"change-url"]}">#{options[:"change-url"]}</a><br/>

#{pretty_stat}

Thanks,<br/>
Your Friendly Gerrit Bot
EOF

plain_body = <<EOF
If you're interested to review this code please visit

    #{options[:"change-url"]}

#{plain_stat}

Thanks
Your Friendly Gerrit Bot
EOF

# we don't need send mail now. gerrit will send mail to the new reviewer
=begin
Pony.mail(:to => config['notify']['maillist'],
  :from => config['notify']['from'],
  :subject =>"[Code Review] Review for #{options[:project]}[#{options[:branch]}]: #{subject}",
  :html_body => html_body,
  :via => :smtp,
  :via_options => {
  :address => config['notify']['smtpserver'],
  :port => config['notify']['port'],
  :authentication => :plain,
  :user_name => config['notify']['user'],
  :password => config['notify']['password'],
  :enable_starttls_auto => false,
  :body => plain_body
})
=end

reviewers = get_reviewer(notification, options[:project])
KEY = File.join(File.dirname(__FILE__), "/config/review")
SSH_OPTS = { :keys => KEY, :keys_only => true, :port => config['gerrit']['ssh_port'] }

HOST = "localhost"
USER = "reviewbot"

reviewers.each do |reviewer|
  `ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i #{KEY} -p #{config['gerrit']['ssh_port']} #{USER}@#{HOST} \"gerrit set-reviewers -a '#{reviewer}' #{options[:commit]}\"`
end
