require "rubygems"
# require "zip"

class Package < Thor

  desc "soltemplate PATH VERSION", "Packages up the solution template for publishing to azure"
  method_option :output_dir, :type => :string, :default => ".."
  method_option :name, :type => :string, :default => ""
  def soltemplate(path, version)

    path = File.expand_path(path)

    # Ensure that the path exists
    fail "The specified path cannot be found" unless File.exists?(path)

    if options[:name].empty?
      name = File.basename(path)
    else 
      name = options[:name]
    end

    # Determine the filename for the archive file
    archive_path = "%s/%s-%s.zip" % [File.expand_path(options[:output_dir]), name, version]

    # Build up a list of the files that need to be included in the archive and the folder in the archive they 
    # need to be stored in
    files = {
      "createUiDefinition.json" => "",
      "mainTemplate.json" => "",
      "chefserver-password.json" => "nested",
      "chefserver-sshPublicKey.json" => "nested",
      "configurechefserver-no.json" => "nested",
      "configurechefserver-yes.json" => "nested",
      "../arm-virtual-network/vnet_exists.json" => "nested",
      "../arm-virtual-network/vnet_new.json" => "nested",
      "../arm-storage-account/storageaccount_exists.json" => "nested",
      "../arm-storage-account/storageaccount_new.json" => "nested",
      "../arm-public-ipaddress/publicipaddress_exists.json" => "nested",
      "../arm-public-ipaddress/publicipaddress_new.json" => "nested",
      "../scripts/install-compliance.sh" => "scripts"
    }

    Zip.continue_on_exists_proc = true

    puts "Adding files to: %s" % [archive_path]

    # Iterate around the files and build up the zip archive file
    Zip::File.open(archive_path, Zip::File::CREATE) do |zipfile|
      files.each do |source, target|

        zip_item = File.join(target, File.basename(source))
        target_file = File.join(path, source)

        if zip_item.start_with?('/')
          zip_item.sub!(/^\//, '')
        end

        puts "    %s => %s" % [target_file, zip_item]

        zipfile.add(zip_item, target_file)
      end
    end

  end

end