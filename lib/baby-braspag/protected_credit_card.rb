module Braspag
  class ProtectedCreditCard < PaymentMethod

    PROTECTED_CARD_MAPPING = {
      :request_id => "RequestId",
      :merchant_id => "MerchantKey",
      :customer_name => "CustomerName",
      :holder => "CardHolder",
      :card_number => "CardNumber",
      :expiration => "CardExpiration"
    }

    JUST_CLICK_MAPPING = {
      :request_id => "RequestId",
      :merchant_id => "MerchantKey",
      :customer_name => "CustomerName",
      :order_id => "OrderId",
      :amount => "Amount",
      :payment_method => "PaymentMethod",
      :number_installments => "NumberInstallments",
      :payment_type => "PaymentType",
      :just_click_key => "JustClickKey",
      :security_code => "SecurityCode"
    }

    SAVE_PROTECTED_CARD_URI = "/CartaoProtegido.asmx?wsdl"
    GET_PROTECTED_CARD_URI = "/CartaoProtegido.asmx/GetCreditCard"
    JUST_CLICK_SHOP_URI = "/CartaoProtegido.asmx?wsdl"

    # saves credit card in Braspag PCI Compliant
    def self.save(params = {})
      connection = Braspag::Connection.instance
      params[:merchant_id] = connection.merchant_id

      self.check_protected_card_params(params)

      data = { 'saveCreditCardRequestWS' => {} }

      PROTECTED_CARD_MAPPING.each do |k, v|
        data['saveCreditCardRequestWS'][v] = params[k] || ""
      end

      data_for_logging = data['saveCreditCardRequestWS'].dup
      data_for_logging['CardNumber'] = "************%s" % data_for_logging['CardNumber'][-4..-1]

      Braspag.logger.info("[Braspag] #save_credit_card, data: #{data_for_logging}") if Braspag.logger

      client = savon_client(self.save_protected_card_url)
      response = client.call(:save_credit_card, :message => data)

      # We do not want to let any sensitive data exposed on log files.
      redacted_response = redact_just_click_key(response)

      Braspag.logger.info("[Braspag] #save_credit_card returns: #{redacted_response}") if Braspag.logger

      response.to_hash[:save_credit_card_response][:save_credit_card_result]
    end

    # request the credit card info in Braspag PCI Compliant
    def self.get(just_click_key)
      connection = Braspag::Connection.instance

      raise InvalidJustClickKey unless valid_just_click_key?(just_click_key)

      data = { 'getCreditCardRequestWS' => {:loja => connection.merchant_id, :justClickKey => just_click_key} }

      response = Braspag::Poster.new(self.get_protected_card_url).do_post(:get_protected_card, data)

      response = Utils::convert_to_map(response.body, {
          :holder => "CardHolder",
          :card_number => "CardNumber",
          :expiration => "CardExpiration",
          :masked_card_number => "MaskedCardNumber"
        })

      raise UnknownError if response[:card_number].nil?
      response
    end

    def self.just_click_shop(params = {})
      connection = Braspag::Connection.instance
      params[:merchant_id] = connection.merchant_id

      self.check_just_click_shop_params(params)

      order_id = params[:order_id]
      raise InvalidOrderId unless self.valid_order_id?(order_id)

      data = { 'justClickShopRequestWS' => {} }

      JUST_CLICK_MAPPING.each do |k, v|
        case k
        when :payment_method
          data['justClickShopRequestWS'][v] = Braspag::Connection.instance.homologation? ? PAYMENT_METHODS[:braspag] : PAYMENT_METHODS[params[:payment_method]]
        when :amount
          data['justClickShopRequestWS'][v] = ("%.2f" % params[k].to_f).gsub('.', '')
        else
          data['justClickShopRequestWS'][v] = params[k] || ""
        end
      end

      data_for_logging = data['justClickShopRequestWS'].dup
      data_for_logging['SecurityCode'] = data_for_logging['SecurityCode'].gsub(/./, '*')

      Braspag::logger.info("[Braspag] #just_click_shop, data: #{data_for_logging}") if Braspag::logger

      client = savon_client(self.just_click_shop_url)
      response = client.call(:just_click_shop, :message => data)

      Braspag::logger.info("[Braspag] #just_click_shop returns: #{response}") if Braspag::logger

      response.to_hash[:just_click_shop_response][:just_click_shop_result]
    end

    def self.check_protected_card_params(params)
      [:request_id, :customer_name, :holder, :card_number, :expiration].each do |param|
        raise IncompleteParams if params[param].nil?
      end

      raise InvalidHolder if params[:holder].to_s.size < 1 || params[:holder].to_s.size > 100

      matches = params[:expiration].to_s.match /^(\d{2})\/(\d{2,4})$/
      raise InvalidExpirationDate unless matches
      begin
        year = matches[2].to_i
        year = "20#{year}" if year.size == 2

        Date.new(year.to_i, matches[1].to_i)
      rescue ArgumentError
        raise InvalidExpirationDate
      end
    end

    def self.check_just_click_shop_params(params)
      just_click_shop_attributes = [:request_id, :customer_name, :order_id, :amount, :payment_method,
      :number_installments, :payment_type, :just_click_key, :security_code]

      just_click_shop_attributes.each do |param|
        raise IncompleteParams if params[param].nil?
      end

      raise InvalidSecurityCode if params[:security_code].to_s.size < 1 || params[:security_code].to_s.size > 4

      raise InvalidNumberInstallments if params[:number_installments].to_i < 1 || params[:number_installments].to_i > 99

    end

    def self.valid_just_click_key?(just_click_key)
      (just_click_key.is_a?(String) && just_click_key.size == 36)
    end

    def self.save_protected_card_url
      Braspag::Connection.instance.protected_card_url + SAVE_PROTECTED_CARD_URI
    end

    def self.get_protected_card_url
      Braspag::Connection.instance.protected_card_url + GET_PROTECTED_CARD_URI
    end

    def self.just_click_shop_url
      Braspag::Connection.instance.protected_card_url + JUST_CLICK_SHOP_URI
    end

    def self.savon_client(url)
      Braspag::Connection.instance.savon_client url
    end

    # Internal: Redact the JustClickKey value from a XML response.
    #
    # response - the XML response string to be parsed.
    #
    # Example
    #
    #   redact_just_click_key('<JustClickKey>{070071E9-1F73-4C85-B1E4-D8040A627DED}</JustClickKey>')
    #   # => '<JustClickKey>{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}</JustClickKey>'
    #
    # Returns a String.
    def self.redact_just_click_key(response)
      response.to_s.sub(/(<JustClickKey>)(.*)(<\/JustClickKey>)/) do
        open_tag = $1
        just_click_key = $2
        close_tag = $3

        just_click_key = just_click_key.to_s.gsub(/\h/, 'X')

        open_tag + just_click_key + close_tag
      end
    end
  end
end
