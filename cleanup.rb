require 'yaml'
require 'find'
require 'time'


def timestamp_from_age_description(description)
  span = 0
  span = description.match(/(.*) years/i)[1].to_i * 31536000 if /.* years/i.match(description)  
  span = description.match(/(.*) months/i)[1].to_i * 2592000 if /.* months/i.match(description)    
  span = description.match(/(.*) days/i)[1].to_i * 86400 if /.* days/i.match(description)
  span = description.match(/(.*) hours/i)[1].to_i * 3600 if /.* hours/i.match(description)
  span = description.match(/(.*) minutes/i)[1].to_i * 60 if /.* minutes/i.match(description)  
  return Time.now - span
end

def older_than_age_description_does_match(description, time)
  return time < timestamp_from_age_description(description)
end

def newer_than_age_description_does_match(description, time)
  return time > timestamp_from_age_description(description)
end


test_run = ((ARGV.length > 0) and (ARGV[0]=="--test"))

cfg_file = File.exists?("cleanup.yml") ? "cleanup.yml" : "#{ENV['HOME']}/.cleanup"

if !File.exists?(cfg_file) then
  puts "! Error neither ~/.cleanup nor a cleanup.yml in this directory were found !"
  exit
end

config = readme = YAML::load(File.open(cfg_file))

config.each do |path, expressions|
  
  puts "Checking #{path}..."
  
  recursive = expressions['recursive']
  expressions.delete("recursive")
  
  Find.find("#{path}/") do |cur_path|
    next if (cur_path == "#{path}/")
    Find.prune if (FileTest.directory?(cur_path) and !recursive)

    remove_file = false
    begin
      f = File.new(cur_path)
      ctime = Time.parse(`mdls -name kMDItemFSCreationDate -raw #{cur_path}`) or f.ctime         # osx fallback
      atime = f.atime
      mtime = f.mtime
    rescue 
      puts "  ! Error while accessing #{cur_path} !"
      next
    end
    
    
    expressions.each do |expression, conditions|
      if (Regexp.new(expression).match(cur_path)) then
        # now check conditions
        if (conditions == true) then
          remove_file = true
        else 
          remove_file = true if conditions.has_key?("older_than") and older_than_age_description_does_match(conditions["older_than"], ctime)
          remove_file = true if conditions.has_key?("not_accessed_in") and older_than_age_description_does_match(conditions["not_accessed_in"], atime)
          remove_file = true if conditions.has_key?("not_modified_in") and older_than_age_description_does_match(conditions["not_modified_in"], mtime)

          remove_file = true if conditions.has_key?("newer_than") and newer_than_age_description_does_match(conditions["newer_than"], ctime)
          remove_file = true if conditions.has_key?("accessed_in") and newer_than_age_description_does_match(conditions["accessed_in"], atime)
          remove_file = true if conditions.has_key?("modified_in") and newer_than_age_description_does_match(conditions["modified_in"], mtime)          
        end
      end
    end
    
    if remove_file then
      if test_run then
        puts "  Would delete #{cur_path}"
      else
        begin
          puts "  Deleting #{cur_path}"
          File.delete(cur_path)
        rescue
          puts "  ! That's what i would say if I was allowed to delete this file  - But there was an error !"
        end
      end
      
    end
  end
end