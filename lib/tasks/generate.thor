require 'rubygems'
require 'pastebin'
require "cgi"

class Generate < Thor
  desc "uiurl [PATH]", "Creates the necessary URLs for testing a UI in Azure"
  method_option :expires, :type => :string, :default => "1D"
  method_option :mode, :type => :string, :default => "1"
  method_option :format, :type => :string, :default => "json"
  def uiurl(path)

    # Check that the file exist
    fail "The specified deifnition file cannot be found" unless File.exists?(path)

    # Read in the pastebinrc file if it exists and get the API_USER_KEY
    pboptions = {}
    pbrcfile = "%s/.pastebinrc" % [ENV['HOME']]
    if (File.exists?(pbrcfile))
      File.open(pbrcfile) do |fp|
        fp.each do |line|
          key, value = line.chomp.split("=")
          pboptions[key.downcase] = value
        end
      end
    end

    # Update the options with the items that need to be pasted
    pboptions["api_paste_code"] = path
    pboptions["api_paste_name"] = "CreateUIDefinition#{Time.now.to_i}"

    # override pboptions
    pboptions["api_paste_expire_date"] = options[:expires]
    pboptions["api_paste_private"] = options[:mode]
    pboptions["api_paste_format"] = options[:format]

    pb = TheFox::Pastebin::Pastebin.new(pboptions)
    parsed_uri = URI(pb.paste)
    parsed_uri.path = "/raw" + parsed_uri.path
    
    # Escape the URI so that it can be embedded into the correct format for Azure
    escaped_uri = CGI.escape(parsed_uri.to_s)

    # Configure the URL template
    url_template = %Q|https://portal.azure.com/#blade/Microsoft_Azure_Compute/CreateMultiVmWizardBlade/internal_bladeCallId/anything/internal_bladeCallerParams/{"initialData":{},"providerConfig":{"createUiDefinition":"{blob_url}"}}|

    # Replace the necessary parameters in the template
    url_template['{blob_url}'] = escaped_uri

    # Output the URL
    puts "PasteBin URL: %s" % [parsed_uri.to_s]
    puts "Azure Testing URL: %s" % [url_template]
    
  end
end