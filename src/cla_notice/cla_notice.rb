require 'optparse'
require 'pony'
require 'yaml'

opts = {
}

parser = OptionParser.new do |op|
  op.banner = <<-EOT
Usage: cla-signed --submitter <submitter> --user-id <user_id> --cla-id <cla_id> --config <config_file_path>

This hook will be called automatically once there is a CLA signed. Once it gets
called, it will send notification mail to cf_contributors@vmware.com.
EOT

  op.on('--submitter SUBMITTER', 'CLA submitter') do |submitter|
    opts[:submitter] =  submitter.gsub(ESCAPE_SYMBOL, ' ')
  end
  op.on('--user-id USER_ID', 'user ID of the CLA submitter') do |user_id|
    opts[:user_id] = user_id
  end
  op.on('--cla-id CLA_ID', 'CLA ID') do |cla_id|
    opts[:cla_id] = cla_id
  end
  op.on('--config CONFIG_FILE', 'config file for cla_notice') do |config_file|
    config = YAML.load_file config_file
    opts[:smtp_port] = config['port']
    opts[:smtp_host] = config['host']
    opts[:smtp_user] = config['user']
    opts[:smtp_password] = config['password']
    opts[:mail_subject] =config['subject']
    opts[:mail_to] = config['to']
    opts[:mail_body] = config['body']
    opts[:mail_from] = config['from']
  end
end

# convert "--submitter Leo Li (lileo@rbcon.com) --user-id 3 --cla-id 1" to "--submitter Leo#--#Li#--#(lileo@rbcon.com) --user-id 3 --cla-id 1"
ESCAPE_SYMBOL = '#--#'
new_argv = []
para_bff = ''
ARGV.each do |item|
  if item.match /^--.*/
    if para_bff != ''
      new_argv.push para_bff
      para_bff = ''
    end
    new_argv.push item
  else
    if para_bff == ''
      para_bff = item
    else
      para_bff = para_bff + ESCAPE_SYMBOL + item
    end
  end
end
if para_bff != ''
  new_argv.push para_bff
end

parser.parse!(new_argv)

Pony.mail({
  :from => opts[:mail_from],
  :to => opts[:mail_to],
  :subject => opts[:mail_subject].gsub('{submitter}', opts[:submitter]),
  :body => opts[:mail_body].gsub('{submitter}', opts[:submitter]),
  :via => :smtp,
  :via_options => {
    :address  => opts[:smtp_host],
    :port => opts[:smtp_port],
    :user_name => opts[:smtp_user],
    :password => opts[:smtp_password],
  }
})

