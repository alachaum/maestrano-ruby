module Maestrano
  module SSO
    # Return the saml_settings based on
    # Maestrano configuration
    def self.saml_settings
      settings = Maestrano::Saml::Settings.new
      settings.assertion_consumer_service_url = self.consume_url
      settings.issuer                         = Maestrano.param('app_host')
      settings.idp_sso_target_url             = self.idp_url
      settings.idp_cert_fingerprint           = Maestrano.param('sso_x509_fingerprint')
      settings.name_identifier_format         = Maestrano.param('sso_name_id_format')
      settings
    end
    
    # Build a new SAML Request
    def self.build_request(get_params = {})
      Maestrano::Saml::Request.new(get_params)
    end
    
    # Build a new SAML response
    def self.build_response(saml_post_param)
      Maestrano::Saml::Response.new(saml_post_param)
    end
    
    def self.enabled?
      !!Maestrano.param('sso_enabled')
    end
    
    def self.init_url
      host = Maestrano.param('app_host')
      path = Maestrano.param('sso_app_init_path')
      return "#{host}#{path}"
    end
    
    def self.consume_url
      host = Maestrano.param('app_host')
      path = Maestrano.param('sso_app_consume_path')
      return "#{host}#{path}"
    end
    
    def self.logout_url
      host = Maestrano.param('api_host')
      path = '/app_logout'
      return "#{host}#{path}"
    end
    
    def self.unauthorized_url
      host = Maestrano.param('api_host')
      path = '/app_access_unauthorized'
      return "#{host}#{path}";
    end
    
    def self.idp_url
      host = Maestrano.param('api_host')
      api_base = Maestrano.param('api_base')
      endpoint = 'auth/saml'
      return "#{host}#{api_base}#{endpoint}"
    end
    
    def self.session_check_url(user_uid,sso_session) 
      host = Maestrano.param('api_host')
      api_base = Maestrano.param('api_base')
      endpoint = 'auth/saml'
      return URI.escape("#{host}#{api_base}#{endpoint}/#{user_uid}?session=#{sso_session}")
    end
  end
end