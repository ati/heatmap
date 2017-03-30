# convert rtl-sdr samples to google maps' heatmap
#
#
require 'json'

MIN_DISTANCE=10 #meters, don't store points, closer than this distance to each other

class Scan2Web
  # [
  #   {
  #     lat: lat,
  #     lon: lon,
  #     spectrum: [power_for_each_range in spectrum_ranges]
  #   },
  # ]
  def load_data(file_name)
    res = []
    json_file = File.read(file_name)
    data = JSON.parse(json_file)[1]
    spectrum = data['Spectrum']
    data['Location'].each do |ts, loc|
      data_point = {lat: loc[0], lon: loc[1], ts: ts.to_i}
      if farther_than(MIN_DISTANCE, res, data_point)
        # puts '+ ' + ts.to_s
        res.push(data_point.merge({spectrum: get_ranges(spectrum[ts])}))
      else
        # puts './tmp/' + ts.to_i.to_s + '.0.png'
      end
    end
    return res
  end


  # calculate combined power of signal
  #
  def get_ranges(spectrum)
    return spectrum.keys
      .reduce(0) {|memo, k| memo += spectrum[k]}
  end


  # convert absolute power values to relative 'weight' of each point
  #
  def normalize(data)
    return [] if data.empty?
    if data.length.eql?(1)
      data[0][:spectrum] = 100;
      return data
    else
      min_power = max_power = data[0][:spectrum]
      min_lat = max_lat = data[0][:lat]
      min_lon = max_lon = data[0][:lon]


      data.each do |dp|
        #STDERR.puts dp[:spectrum]
        min_power = [min_power, dp[:spectrum]].min
        max_power = [max_power, dp[:spectrum]].max
      end

      return data.map{|dp| dp[:spectrum] = (100*(dp[:spectrum] - min_power)/(min_power.abs - max_power.abs)).round(1); dp}
    end
  end


  def get_geo_center(data)
    return {} if data.empty?

    min_lat = max_lat = data[0][:lat]
    min_lon = max_lon = data[0][:lon]

    data.each do |dp|
      min_lat = [min_lat, dp[:lat]].min
      max_lat = [max_lat, dp[:lat]].max
      min_lon = [min_lon, dp[:lon]].min
      max_lon = [max_lon, dp[:lon]].max
    end

    return {
      lat: (min_lat + max_lat)/2.0, 
      lon: (min_lon + max_lon)/2.0
    }
  end


  # distance in meters between two points on Earth
  #
  def distance(p1, p2)
    a = [p1[:lat], p1[:lon]]
    b = [p2[:lat], p2[:lon]]

    rad_per_deg = Math::PI/180  # PI / 180
    rm = 6378137             # Radius in meters

    dlon_rad = (b[1]-a[1]) * rad_per_deg  # Delta, converted to rad
    dlat_rad = (b[0]-a[0]) * rad_per_deg

    lat1_rad, lon1_rad = a.map! {|i| i * rad_per_deg }
    lat2_rad, lon2_rad = b.map! {|i| i * rad_per_deg }

    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math::atan2(Math::sqrt(a), Math::sqrt(1-a))
    rm * c # Delta in meters
  end


  # true, если point находится дальше от всех точек accepted, чем meters
  def farther_than(meters, accepted, point)
    accepted.reverse.find{|p| distance(p, point) < meters}.nil?
  end


  def handle_upload(file_name)
    data = load_data(file_name)
    res = {
      title: File.basename(file_name),
      center: get_geo_center(data),
      points: normalize(data)
    }
    if data.length < 5
      res[:message] = 'Too few data points'
    end
    return res.to_json
  end
end
