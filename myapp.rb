require 'sinatra/base'
require 'json'
require 'fileutils'
require 'sinatra/reloader'


require  APP_DIR + 'scan2web.rb'


class MyApp < Sinatra::Base
  configure do
    APP_DIR = File.dirname(__FILE__)
    UPLOADS_DIR = File.join(APP_DIR, 'uploads')
  end

  configure :development do
    register Sinatra::Reloader
  end

  def jerr(msg)
    return {result: 'error', message: msg}.to_json
  end

  def sanitize_filename(filename)
    filename.strip.tap do |name|
      name.gsub!(/[^\w\.\-\s]/, '_')
    end
  end


  get "/heatmap/single_band_index.html" do
    @rfs_list = Dir.entries(UPLOADS_DIR).grep(/\.rfs$/).sort
    erb :single_band_index
  end


  get "/heatmap/show/:f" do
    if !defined?(params[:f])
      status 400
      body "Required parameters missing"
    elsif !File.file?(File.join(UPLOADS_DIR, sanitize_filename(params[:f])))
      status 404
      body "File '#{params[:f]}' not found"
    else
      content_type :json
      scan = Scan2Web.new()
      scan.handle_upload(File.join(UPLOADS_DIR, sanitize_filename(params[:f])))
    end
  end


  post '/heatmap/create_heatmap.json' do
    content_type :json

    unless params[:file] &&
           (tmpfile = params[:file][:tempfile]) &&
           (name = params[:file][:filename])
      return jerr('invalid file upload parameters')
    end

    begin
      rfs = JSON.parse(File.read(tmpfile)) # throw exception here if it's not a valid json
      if !defined?(rfs[1]) || !defined(rfs[1]["Location"])
        return jerr("Missing 'Location' section in JSON file")
      end

      name = File.join(UPLOADS_DIR, sanitize_filename(name))
      FileUtils.cp(tmpfile, name)
    
      scan = Scan2Web.new()
      scan.handle_upload(name)

    rescue Exception => e
      return jerr("Invalid data file.")
    end
  end
end
