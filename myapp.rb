require 'sinatra/base'
require 'json'
require 'fileutils'

APP_DIR = File.dirname(__FILE__) + '/'
UPLOADS_DIR = APP_DIR + 'uploads/'

require  APP_DIR + 'scan2web.rb'


class MyApp < Sinatra::Base
  def jerr(msg)
    return {result: 'error', message: msg}.to_json
  end

  def sanitize_filename(filename)
    filename.strip.tap do |name|
      name.gsub! /[^\w\.\-\s]/, '_'
    end
  end

  post '/heatmap/create_heatmap.json' do
    content_type :json

    unless params[:file] &&
           (tmpfile = params[:file][:tempfile]) &&
           (name = params[:file][:filename])
      return jerr('invalid file upload parameters')
    end

    name = UPLOADS_DIR + sanitize_filename(name)
    FileUtils.cp(tmpfile, name)
    
    scan = Scan2Web.new()
    scan.handle_upload(name)
  end
end
