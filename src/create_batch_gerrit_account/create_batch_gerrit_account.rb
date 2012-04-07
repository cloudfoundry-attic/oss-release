require 'bundler'
Bundler.setup

require 'logger'
require 'sequel'
require 'yaml'

# This script creates new batch accounts in Gerrit. It is used to bootstrap
# batch accounts before any users exist that belong to the Administrators group
# (needed in order to create accounts via `gerrit create-account`). Note that
# if the user being created already exists, its public key will be updated.

def assert_keys_exist(hash, keys)
  missing = []
  keys.each do |k|
    missing << k unless hash[k]
  end
  raise "Missing #{missing.join(', ')}" unless missing.empty?
end

def find_account_id(db, username)
  external_ids = db[:account_external_ids].filter('external_id = ?', "username:#{username}").all
  case external_ids.length
  when 1
    external_ids.first[:account_id]
  when 0
    nil
  else
    raise "Multiple accounts match: #{external_ids}"
  end
end

def create_account(db, account_config)
  account_id = db['insert into account_id () values(); select last_insert_id();']
  account_id = account_id.all[0]["last_insert_id()".to_sym]

  # Add the account
  row = {
    :account_id      => account_id,
    :full_name       => account_config['full_name'],
    :preferred_email => account_config['preferred_email'],
  }
  db[:accounts] << row

  # Link the username to it
  row = {
    :account_id  => account_id,
    :external_id => "username:#{account_config['user']}",
  }
  db[:account_external_ids] << row

  # Add the ssh key
  row = {
    :ssh_public_key => account_config['public_key'],
    :valid          => 'Y',
    :account_id     => account_id,
  }
  db[:account_ssh_keys] << row
end

def update_account(db, account_id, account_config)
  # Update account info
  account_info = {
    :full_name       => account_config['full_name'],
    :preferred_email => account_config['email'],
  }
  db[:accounts].filter('account_id = ?', account_id).update(account_info)

  # Update ssh key
  ssh_key = {:ssh_public_key => account_config['public_key']}
  db[:account_ssh_keys].filter('account_id = ?', account_id).update(ssh_key)
end

opts = {
  :verbose => false
}
parser = OptionParser.new do |op|
  op.banner = <<-EOT
Usage: create_batch_gerrit_account.rb [options] [db_config path] [account_info path]

This will create a batch account based on the supplied account information. If
an account already exists with the same username, it will be updated.

Options:
EOT

  op.on('-v', '--verbose', 'Display debugging information') do
    opts[:verbose] = true
  end
end

parser.parse!(ARGV)

unless ARGV.length == 2
  puts parser.help
  exit 1
end

db_config_path, account_config_path = ARGV

logger = Logger.new(STDOUT)
logger.level = opts[:verbose] ? Logger::DEBUG : Logger::INFO

begin
  db_config = YAML.load_file(db_config_path)
  assert_keys_exist(db_config, %w[host port user password dbname])

  account_config = YAML.load_file(account_config_path)
  assert_keys_exist(account_config, %w[user public_key full_name email])

  DB = Sequel.connect(:adapter  => 'mysql',
                      :host     => db_config['host'],
                      :port     => db_config['port'],
                      :user     => db_config['user'],
                      :password => db_config['password'],
                      :database => db_config['dbname'])
  DB.transaction do
    account_id = find_account_id(DB, account_config['user'])
    if account_id
      logger.info("Account exists, updating ssh key.")
      update_account(DB, account_id, account_config)
    else
      logger.info("Account doesn't exist, creating it.")
      account_id = create_account(DB, account_config)
    end
    logger.info("Done")
  end
rescue => e
  logger.error(e.to_s)
  logger.debug(e.backtrace.join("\n"))
end

