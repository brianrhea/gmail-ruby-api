require 'mail'
require 'hashie'
require 'hooks'
#require 'google/api_client'
require 'gmail/gmail_object'
require 'gmail/api_resource'
#base
require 'gmail/base/create'
require 'gmail/base/delete'
require 'gmail/base/get'
require 'gmail/base/list'
require 'gmail/base/update'
require 'gmail/base/modify'
require 'gmail/base/trash'

#object
require 'gmail/util'
require 'gmail/message'
require 'gmail/draft'
require 'gmail/thread'
require 'gmail/label'

require 'googleauth'
require 'google/apis/gmail_v1'
module Gmail

  class << self
    attr_accessor :auth_method, :client_id, :client_secret, 
      :refresh_token, :auth_scopes, :email_account
      #:application_name, :application_version not required
    attr_reader :service, :client, :mailbox_email
    def new hash
      #[:auth_method, :client_id, :client_secret, :refresh_token, :auth_scopes, :email_account, :application_name, :application_version].each do |accessor|
      [:auth_method, :client_id, :client_secret, :refresh_token, :auth_scopes, :email_account].each do |accessor|
        Gmail.send("#{accessor}=", hash[accessor.to_s])
      end
    end
  end

  # Google::APIClient.logger.level = 3
  # @service = Google::APIClient.new.discovered_api('gmail', 'v1')
  # Google::APIClient.logger.level = 2

  # begin
  #   Gmail.new  YAML.load_file("account.yml")  # for development purpose
  # rescue

  # end

  def self.request(method, params={}, body={}, auth_method=@auth_method)
  
    params[:user_id] ||= "me"
    case auth_method
      when "web_application" 
        if @client.nil?
          self.connect
        end
      when "service_account"
        if @client.nil?
          self.service_account_connect
        elsif self.client.authorization.principal != @email_account
          self.service_account_connect
        end
    end
  
    if body.empty?
      response = @client.execute(
          :api_method => method,
          :parameters => params,

          :headers => {'Content-Type' => 'application/json'})
    else

     # response =  @client.execute(
     #      :api_method => method,
     #      :parameters => params,
     #      :body_object => body,
     #      :headers => {'Content-Type' => 'application/json'})
    end
    parse(response)

  end

  def self.new_request(method, params={},body={}, auth_method = @auth_method)
    params[:userId] ||= "me"
    variables = [params[:userId], *params[:variables]]
    unless auth_method.nil?
      case auth_method
        when "web_application" 
          if @client.nil?
            self.connect
          end
        when "service_account"
          if @client.nil?
            self.service_account_connect
          elsif self.client.authorization.principal != @email_account
            self.service_account_connect
          end
      end
    
      if body.empty?
        response = @client.send(method,*variables).to_json
      else
        response = @client.send(method,*variables, body).to_json
      end
      parse(response)
    else
      raise "No Auth Method defined"
    end
  end

  def self.mailbox_email
    #@mailbox_email ||= self.request(@service.users.to_h['gmail.users.getProfile'])[:emailAddress]
    @mailbox_email ||= self.new_request("get_user_profile", {variables:["me"]}).email_address
  end



  def self.connect(client_id=@client_id, client_secret=@client_secret, refresh_token=@refresh_token)
    unless client_id
      raise 'No client_id specified'
    end

    unless client_secret
      raise 'No client_secret specified'
    end

    unless refresh_token
      raise 'No refresh_token specified'
    end
    
    authorization = Google::Auth::UserRefreshCredentials.new(
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: refresh_token
      )

    @client = Google::Apis::GmailV1::GmailService.new
      
    @client.authorization = authorization
    # We don't currently specify what the account is... this could beb problematic as it's a useful piece of information.
    # @client.authorization.principal
    @client.authorization.fetch_access_token!
    @client.authorization.principal = @client.get_user_profile("me").email_address
    
    @service = @client
    @auth_method = "web application"
  end

  def self.service_account_connect(
    client_id=@client_id, client_secret=@client_secret,
    email_account=@email_account, auth_scopes=@auth_scopes 
    )
    #This relies on passing the client_secret as a parameter. 
    authorization = Signet::OAuth2::Client.new(
      :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
      :audience => 'https://accounts.google.com/o/oauth2/token',
      :scope => auth_scopes,
      :issuer => client_id,
      :signing_key => OpenSSL::PKey::RSA.new(client_secret, nil),
    )
    @client.authorization.principal = email_account
    authorization.fetch_access_token!
    #authorization

    
    @service = @client
    @auth_method = "service account"
  end

  def self.parse(response)
    begin

      if response.empty?
        return response
      else
        response = JSON.parse(response)
      end

    rescue JSON::ParserError
      raise "error code: #{response.error},body: #{response})"
    end

    r = Gmail::Util.symbolize_names(response)
    if r[:error]
      raise "#{r[:error]}"
    end
    r
  end

end # Gmail
