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

def filesize_from_description(description)
  size = 0
  size = description.match(/([0-9]*) B/i)[1].to_i if /[0-9]* B/i.match(description)
  size = description.match(/([0-9]*) KB/i)[1].to_i * 1024 if /[0-9]* KB/i.match(description)
  size = description.match(/([0-9]*) MB/i)[1].to_i * 1048576 if /[0-9]* MB/i.match(description)  
  size = description.match(/([0-9]*) GB/i)[1].to_i * 1073741824 if /[0-9]* GB/i.match(description)
  size = description.match(/([0-9]*) TB/i)[1].to_i * 1099511627776 if /[0-9]* TB/i.match(description)      
  return size
end

def check_condition(condition, value)
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
  
  expressions[".*"] = expressions["all"] if expressions["all"]
  expressions.delete("all")
  
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
          check = lambda { |condition, value|
            ret = false
            ret = true if (condition == "older_than") and older_than_age_description_does_match(value, ctime)
            ret = true if (condition == "not_accessed_in") and older_than_age_description_does_match(value, atime)
            ret = true if (condition == "not_modified_in") and older_than_age_description_does_match(value, mtime)
            
            ret = true if (condition == "newer_than") and newer_than_age_description_does_match(value, ctime)
            ret = true if (condition == "accessed_in") and newer_than_age_description_does_match(value, atime)
            ret = true if (condition == "modified_in") and newer_than_age_description_does_match(value, mtime)

            ret = true if (condition == "size_exceeds") and (File.size(cur_path) > filesize_from_description(value))
            ret = true if (condition == "size_is_below") and (File.size(cur_path) < filesize_from_description(value))            
            ret = true if (condition == "must_meet_all_conditions") and (value == true)
            
            ret
          }
          
          if conditions.has_key?("must_meet_all_conditions") and (conditions["must_meet_all_conditions"] == true) then
            remove_file = conditions.all?(&check) 
          else
            remove_file = conditions.any?(&check)
          end
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