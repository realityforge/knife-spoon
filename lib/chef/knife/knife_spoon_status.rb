require 'json'
require 'chef/knife'
require 'chef/cookbook_loader'

module KnifeSpoon
  class SpoonStatus < Chef::Knife

    deps do
      require 'chef/json_compat'
      require 'uri'
      require 'chef/checksum_cache'
      require 'chef/cookbook_version'
      require 'pathname'
    end
    banner "knife spoon status"

    option :show,
           :short => "-s",
           :long => "--show",
           :description => "Show the files that differ in cookbook"

    def run
      self.config = ::Chef::Config.merge!(config)

      cookbook_path = config[:cookbook_path]
      unless cookbook_path
        ui.fatal "No default cookbook_path; Specify with -o or fix your knife.rb."
        show_usage
        exit 1
      end

      cookbooks = ::Chef::CookbookLoader.new(cookbook_path)
      cookbooks = cookbooks.select { |c| name_args.include?(c[0].inspect) } unless name_args.empty?

      cookbooks.each do |cookbook|
        local_version = ::Chef::CookbookLoader.new(cookbook_path)[cookbook].version
        remote_version = get_remote_cookbook_version(cookbook)
        check_versions(cookbook, local_version, remote_version)
      end
    end

    def get_latest_remote_cookbook_ref(cookbook_name)
      get_remote_cookbook_refs(cookbook_name)[0]
    end

    def get_remote_cookbook_refs(cookbook_name)
      api_endpoint = "cookbooks/#{cookbook_name}"
      cookbooks = rest.get_rest(api_endpoint)
      cookbooks[cookbook_name]["versions"]
    end

    def get_remote_cookbook_version(cookbook_name)
      get_latest_remote_cookbook_ref(cookbook_name)["version"] rescue nil
    end

    def get_remote_cookbook_data(cookbook_name)
      url = get_latest_remote_cookbook_ref(cookbook_name)["url"]
      rest.get_rest(url)
    end

    def check_versions(cookbook_name, local_version, remote_version)
      if remote_version.nil?
        ui.msg "Cookbook '#{cookbook_name}' not present on server." if config[:show]
        ui.err("#{ui.color('OK     :', :green, :bold)} Safe to upload '#{cookbook_name}' as it is a new cookbook.")
        return
      end
      frozen = get_remote_cookbook_refs(cookbook_name).select{|c| c["version"] == remote_version}[0]["frozen?"]
      if remote_version != local_version
        ui.msg "Cookbook '#{cookbook_name}' version mismatch: Local: #{local_version}, Remote: #{remote_version}#{frozen ? ' (Frozen)' : ''}" if config[:show]
        ui.err("#{ui.color('OK     :', :green, :bold)} Safe to upload '#{cookbook_name}' as cookbook has new version.")
      else
        cookbook = get_local_cookbook(cookbook_name)
        root_dir = Pathname.new(cookbook.root_dir)
        remote_files = get_remote_cookbook_data(cookbook_name).manifest_records_by_path
        changed_files = []
        missing_files = []
        added_files = remote_files.keys.dup
        (::Chef::Cookbook::CookbookVersionLoader::FILETYPES_SUBJECT_TO_IGNORE + [:root_filenames]).each do |key|
          files = cookbook.send(key.to_sym)
          files.each do |file|
            short_filename = Pathname.new(file).relative_path_from(root_dir).to_s
            added_files.delete(short_filename)
            if remote_files[short_filename]
              remote_file_checksum = remote_files[short_filename]['checksum']
              local_checksum = Chef::CookbookVersion.checksum_cookbook_file(file)
              changed_files << short_filename unless local_checksum == remote_file_checksum
            else
              missing_files << short_filename
            end
          end
        end
        unless added_files.empty? && missing_files.empty? && changed_files.empty?
          if config[:show]
            ui.msg "Cookbook '#{cookbook_name}' version same#{frozen ? ', remote version frozen' : ''}. Content modified."
            ui.msg "\tAdded Files: #{added_files.inspect}" unless added_files.empty?
            ui.msg "\tMissing Files: #{missing_files.inspect}" unless missing_files.empty?
            ui.msg "\tModified Files: #{changed_files.inspect}" unless changed_files.empty?
          end
          if frozen
            ui.err("#{ui.color('WARNING:', :yellow, :bold)} Unsafe to upload '#{cookbook_name}' as it modifies an existing cookbook.")
          else
            ui.err("#{ui.color('ERROR  :', :red, :bold)} Dangerous to upload '#{cookbook_name}' as it modifies a frozen cookbook.")
          end

        end
      end
    end

    def get_local_cookbook(cookbook_name)
      cookbook = ::Chef::Cookbook::CookbookVersionLoader.new("cookbooks/#{cookbook_name}", ::Chef::Cookbook::Chefignore.new("chefignore"))
      cookbook.load_cookbooks
      cookbook.cookbook_version
    end

    def get_version(cookbook_path, cookbook_name)
      ::Chef::CookbookLoader.new(cookbook_path)[cookbook_name].version
    end

    def remote_cookbook_data(cookbook, version)
      rest.get_rest("cookbooks/#{cookbook}/#{version}").to_hash
    end
  end
end