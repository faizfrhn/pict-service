ENV['APP_ENV'] = 'test'

require_relative '../service'
require 'test/unit'
require 'rack/test'
require 'digest'

class ServiceTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_root_shows_message_to_submit_post_request
    get '/'
    assert last_response.ok?
    assert_equal ( 
      {
        success: true,
        message: "Please make a POST request to /pictures with 'file' in the request body." 
      }.to_json ), last_response.body
  end

  def test_pictures_must_include_file_param
    post '/pictures'
    assert !last_response.ok?
    assert_equal ( 
      { 
        success: false,
        message: "Please include 'file' param in your request body." 
      }.to_json ), last_response.body
  end

  def test_pictures_file_param_must_not_be_empty
    post '/pictures', file: ''
    assert !last_response.ok?
    assert_equal ( 
      { 
        success: false,
        message: "Please attach an image file to the 'file' param."
      }.to_json ), last_response.body
  end

  def test_pictures_can_upload_to_service
    post '/pictures', file: Rack::Test::UploadedFile.new(__dir__ + "/sample/image.jpg", "image/jpeg")

    filehash = Digest::MD5.hexdigest(last_request[:file][:filename] + Time.now.to_i.to_s)
    urls = {
        last_request[:file][:filename] => 'http://localhost:4567/pictures/' + filehash
    }

    assert last_response.ok?
    assert_equal ( 
      { 
        success: true,
        message: 'Picture uploaded successfully',
        url: urls
      }.to_json ), last_response.body

    path = 'storage/' + filehash + File.extname(last_request[:file][:filename])
    assert File.exist?(path)
  end

  def test_pictures_reject_non_image
    post '/pictures', file: Rack::Test::UploadedFile.new(__dir__ + "/sample/not-image.txt", "text/plain")
    assert !last_response.ok?
    assert_equal ( 
      { 
        success: false,
        message: 'Sorry the file you uploaded is not a valid picture format, please attach only pictures in your request.'
      }.to_json ), last_response.body
  end

  def test_can_fetch_uploaded_pictures
    post '/pictures', file: Rack::Test::UploadedFile.new(__dir__ + "/sample/image.jpg", "image/jpeg")

    filehash = Digest::MD5.hexdigest(last_request[:file][:filename] + Time.now.to_i.to_s)
    get '/pictures/' + filehash
    assert last_response.ok?
    assert_equal 'image/jpeg', last_response.content_type
  end

  def test_error_fetch_uploaded_pictures_no_exist
    get '/pictures/' + Digest::MD5.hexdigest('test')
    assert !last_response.ok?
    assert_equal ( 
        { 
          success: false,
          message: "Oops! The picture you're trying to view does not exists."
        }.to_json ), last_response.body
  end

  def test_pictures_can_upload_zip 
    post '/pictures', file: Rack::Test::UploadedFile.new(__dir__ + "/sample/images.zip", "application/zip")
    assert last_response.ok?

    urls = {}
    Zip::File.open(last_request[:file][:tempfile]) do |zipfile|
        zipfile.each do |file|
          accepted_ext = ['.jpg', '.jpeg', '.gif', '.png']
          
          if accepted_ext.include?(File.extname(file.name))
            # Apply hash to filename to have each as unique
            filehash =  Digest::MD5.hexdigest(file.name + Time.now.to_i.to_s)
            path = "storage/"+ filehash + File.extname(file.name)
            
            assert File.exist?(path)
            urls[file.name] = "http://localhost:4567/pictures/#{filehash}" 
          end
        end
    end

    assert_equal ( 
        { 
          success: true,
          message: 'Pictures were uploaded successfully.',
          url: urls
        }.to_json ), last_response.body
  end

  def test_pictures_reject_zip_with_invalid_files
    post '/pictures', file: Rack::Test::UploadedFile.new(__dir__ + "/sample/not-images.zip", "application/zip")
    assert !last_response.ok?
    assert_equal ( 
      { 
        success: false,
        message: 'Please ensure that at least one of the file in zip is a valid image format',
      }.to_json ), last_response.body
  end
end