require 'singleton'
require 'httpi'
require 'nokogiri'
require 'json'
require 'savon'

require "baby-braspag/version"
require 'baby-braspag/connection'
require 'baby-braspag/payment_method'
require 'baby-braspag/crypto/jar_webservice'
require 'baby-braspag/crypto/webservice'
require 'baby-braspag/bill'
require 'baby-braspag/poster'
require 'baby-braspag/credit_card'
require 'baby-braspag/protected_credit_card'
require 'baby-braspag/eft'
require 'baby-braspag/errors'
require 'baby-braspag/utils'
require 'baby-braspag/order'

begin
  require 'pry-byebug'
  require "awesome_print"
rescue LoadError
end


module Braspag
  def self.logger=(value)
    @logger = value
  end

  def self.logger
    @logger
  end

  def self.config_file_path=(path)
    @config_path = path
  end

  def self.config_file_path
    @config_path || 'config/braspag.yml'
  end

  def self.proxy_address=(value)
    @proxy_address = value
  end

  def self.proxy_address
    @proxy_address
  end

  def self.http_global_options=(options_hash)
    @http_global_options = options_hash
  end

  def self.http_global_options
    @http_global_options || {}
  end

  def self.savon_global_options=(options_hash)
    @savon_global_options = options_hash
  end

  def self.savon_global_options
    @savon_global_options || {}
  end
end
