require 'sinatra'
require 'digest'
require 'zip'

def json_response(status, message, urls = {})
  content_type :json
  status status
  response = { 
    success: (status < 400), 
    message: message
  }
  response[:url] = urls unless urls.empty?
  response.to_json
end

get '/' do
  json_response 200, "Please make a POST request to /pictures with 'file' in the request body."
end

post '/pictures' do
  if params[:file]
    if params[:file].empty?
      json_response 400, "Please attach an image file to the 'file' param."
    else
      urls = {}
      directory = "storage"
      unless Dir.exist?(directory)
        Dir.mkdir(directory)
      end

      # Check if the uploaded file is an image
      if params[:file][:type].start_with?('image/')
        # Apply hash to filename to have each as unique
        filehash =  Digest::MD5.hexdigest(params[:file][:filename] + Time.now.to_i.to_s)
        path = "#{directory}/"+ filehash + File.extname(params[:file][:filename])

        File.open(path, 'wb') do |f|
          f.write(params[:file][:tempfile].read)
        end

        # Construct the URL of the uploaded file
        urls[params[:file][:filename]] = "http://localhost:4567/pictures/#{filehash}"
        json_response 200, 'Picture uploaded successfully', urls
      elsif params[:file][:type] == 'application/zip'
        Zip::File.open(params[:file][:tempfile]) do |zipfile|
          zipfile.each do |file|
            accepted_ext = ['.jpg', '.jpeg', '.gif', '.png']
            
            if accepted_ext.include?(File.extname(file.name))
              # Apply hash to filename to have each as unique
              filehash =  Digest::MD5.hexdigest(file.name + Time.now.to_i.to_s)
              path = "#{directory}/"+ filehash + File.extname(file.name)
              zipfile.extract(file, path) unless File.exist?(path)

              # Construct the URL of the uploaded file
              urls[file.name] = "http://localhost:4567/pictures/#{filehash}" 
            end
          end
        end

        if urls.empty? 
          json_response 400, 'Please ensure that at least one of the file in zip is a valid image format'
        else
          json_response 200, 'Pictures were uploaded successfully.', urls
        end
      else
        json_response 400, 'Sorry the file you uploaded is not a valid picture format, please attach only pictures in your request.'
      end
    end
  else
    json_response 400, "Please include 'file' param in your request body."
  end
end

get '/pictures/:filehash' do
  filename = Dir.glob("storage/#{params[:filehash]}.*").first
  if filename && File.exist?(filename)
    send_file filename
  else
    json_response 400, "Oops! The picture you're trying to view does not exists."
  end
end