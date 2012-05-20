require 'bundler'
Bundler.setup

require 'logger'
require 'sequel'
require 'set'
require 'yaml'

# This script keeps the CLA information stored in Gerrit's database in sync
# with that in the user-supplied config file. It removes existing entries (and
# assocated approvals) for agreements that exist in the database but do not
# exist in the config file. It adds entries for agreements that do no exist in
# the database, but exist in the config. Finally, it updates agreements that
# exist in both the config and the database (keyed by shortname).

def assert_keys_exist(hash, keys)
  missing = []
  keys.each do |k|
    missing << k unless hash[k]
  end
  raise "Missing #{missing.join(', ')}" unless missing.empty?
end

def delete_clas(db, logger, shortnames)
  cla_ids = db[:contributor_agreements].filter(:short_name => shortnames) \
                                       .all                               \
                                       .map {|r| r[:id] }
  logger.info("Deleting CLAs #{shortnames.join(', ')}")
  DB[:contributor_agreements].filter(:short_name => shortnames).delete
  logger.info("Deleting Agreements for said CLAs")
  DB[:account_agreements].filter(:cla_id => cla_ids).delete
end

def add_clas(db, logger, clas)
  clas.each do |cla|
    # Gross, but I don't know of a better way
    cla_id = db['insert into contributor_agreement_id () values(); select last_insert_id();']
    cla_id = cla_id.all[0]["last_insert_id()".to_sym]
    row = {
      :id            => cla_id,
      :active        => 'Y',
      :auto_verify   => 'Y',
      :short_name    => cla['shortname'],
      :agreement_url => "static/#{cla['basename']}",
      :short_description => cla['description'],
      :require_contact_information => 'Y',
    }
    logger.info("Adding #{row}")
    db[:contributor_agreements] << row
  end
end

def update_clas(db, logger, clas)
  clas.each do |cla|
    cols = {
      :short_name    => cla['shortname'],
      :agreement_url => "static/#{cla['basename']}",
      :short_description => cla['description'],
    }
    logger.info("Updating #{cla['shortname']} with cols #{cols}")
    DB[:contributor_agreements].filter('short_name = ?', cla['shortname']) \
                               .update(cols)
  end
end

unless ARGV.length == 1
  puts <<-EOT
Usage: gerrit_cla_updater.rb [/path/to/config.yml]

Keep Gerrit in-sync with the cla information in the supplied config.
EOT
  exit 1
end

config = YAML.load_file(ARGV[0])

# Validate config
assert_keys_exist(config, %w[host port user password dbname clas])
config['clas'].each do |cla|
  assert_keys_exist(cla, %w[shortname description basename])
end

logger = Logger.new(STDOUT)

DB = Sequel.connect(:adapter  => 'mysql',
                    :host     => config['host'],
                    :port     => config['port'],
                    :user     => config['user'],
                    :password => config['password'],
                    :database => config['dbname'])

DB.transaction do
  existing_clas = DB[:contributor_agreements].all

  existing_shortnames = Set.new(existing_clas.map {|cla| cla[:short_name] })
  config_shortnames = Set.new(config['clas'].map {|cla| cla['shortname'] })

  # Remove CLAs and associated agreements that are no longer referenced
  to_delete = existing_shortnames - config_shortnames
  if to_delete.empty?
    logger.info("No CLAs to remove")
  else
    delete_clas(DB, logger, to_delete.to_a)
  end

  # Add new CLAs
  to_add = config_shortnames - existing_shortnames
  if to_add.empty?
    logger.info("No CLAs to add")
  else
    clas = config['clas'].select {|cla| to_add.include?(cla['shortname']) }
    add_clas(DB, logger, clas)
  end

  # Update existing CLAs
  to_update = config_shortnames & existing_shortnames
  if to_update.empty?
    logger.info("No CLAs to update")
  else
    clas = config['clas'].select {|cla| to_update.include?(cla['shortname']) }
    update_clas(DB, logger, clas)
  end
end
