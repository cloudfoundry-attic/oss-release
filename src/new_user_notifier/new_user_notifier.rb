require "bundler"
Bundler.setup

require "erb"
require "logger"
require "pony"
require "sequel"
require "yaml"

# This emails out a list of full name and email address of
# any users that registered that registered since the last time it
# ran. It is intended to be run periodically via cron.

EMAIL_TEMPLATE =
  ERB.new(File.read(File.expand_path("../email_template.erb",
                                     __FILE__)))

CONFIG_TEMPLATE = {
  "smtp"        => %w[host port user pass],
  "mysql"       => %w[host port user pass dbname],
  "recipients"  => [],
  "last_registered_path" => [],
  "oldest_registered_ts" => [],
}

def validate_config(config)
  CONFIG_TEMPLATE.each do |section_name, section_keys|
    section = config[section_name]
    raise "Config missing section '#{section_name}'" unless section

    section_keys.each do |k|
      unless section[k]
        raise "Section '#{section_name}' missing key '#{k}'"
      end
    end
  end
end

def read_last_registered(path)
  if File.exist?(path)
    Time.at(Integer(File.read(path).chomp))
  else
    Time.at(0)
  end
end

def write_last_registered(path, last_run)
  File.open(path, 'w+') do |f|
    f.write(last_run.to_i.to_s)
  end
end

def render_email_template(last_registered_ts, new_users)
  params = {
    :last_registered_ts => last_registered_ts,
    :users => new_users
  }
  EMAIL_TEMPLATE.result(binding())
end

unless ARGV.length == 1
  puts "Usage: new_user_notifier.rb [/path/to/config.yml]"
  exit 1
end

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

config = YAML.load_file(ARGV[0])

validate_config(config)

last_registered_path = config["last_registered_path"]
last_registered_ts = read_last_registered(last_registered_path)

# Allow ourselves to exclude existing users on the first run
oldest_registered_ts = Time.at(config["oldest_registered_ts"])
if oldest_registered_ts > last_registered_ts
  last_registered_ts = oldest_registered_ts
end

# Find any new users
db_config = config["mysql"]
DB = Sequel.connect(:adapter  => 'mysql',
                    :host     => db_config['host'],
                    :port     => db_config['port'],
                    :user     => db_config['user'],
                    :password => db_config['pass'],
                    :database => db_config['dbname'])
new_users =
  DB[:accounts].filter('registered_on > ?', last_registered_ts) \
               .order(:registered_on) \
               .all

logger.info("Looking for registrations since #{last_registered_ts}")
logger.info("Found #{new_users.length} new users")

# Update recipients
unless new_users.empty?
  contents = render_email_template(last_registered_ts, new_users)
  Pony.mail({
    :from      => "noreply@vmware.com",
    :to        => config["recipients"].join(", "),
    :subject   => "[Gerrit] #{new_users.length} New Users",
    :html_body => contents,
    :via  => :smtp,
    :via_options => {
      :address   => config["smtp"]["host"],
      :port      => config["smtp"]["port"],
      :user_name => config["smtp"]["user"],
      :password  => config["smtp"]["pass"],
    },
  })
  logger.info("Notified #{config['recipients']}")
end

write_last_registered(last_registered_path, Time.now)
