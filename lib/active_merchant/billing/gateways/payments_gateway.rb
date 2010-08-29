module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaymentsGatewayGateway < Gateway
      URL = 'www.paymentsgateway.net'
      
      TEST_PORT = 6050
      LIVE_PORT = 5050
      
      ACTIONS = { :CC_SALE => 10, :CC_AUTH_ONLY => 11, :CC_CAPTURE => 12, :CC_CREDIT => 13, :CC_VOID => 14,
                  :CC_PRE_AUTH =>15, :EFT_SALE => 20, :EFT_AUTH_ONLY => 21, :EFT_CAPTURE => 22, :EFT_CREDIT => 23,
                  :EFT_VOID => 24, :EFT_FORCE => 25, :EFT_VERIFY_ONLY => 26, :RECUR_SUSPEN => 40,
                  :RECUR_ACTIVATE => 41, :RECUR_DELETE => 42 }
                  
      RECURRING_FREQUENCIES = { :weekly => 10, :biweekly => 15, :monthly => 20, :bimonthly => 25,
                                :quarterly => 30, :semiannually => 35, :yearly => 40 }
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.paymentsgateway.net/'
      
      # The name of the gateway
      self.display_name = 'Payments Gateway'
      
      # Money format is dollars
      self.money_format = :dollars
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def authorize(money, payment_method, options = {})
        post = []
        add_invoice(post, options)       
        add_address(post, payment_method, options)        
        add_customer_data(post, options)
        
        if payment_method.type == 'check'
          add_check(post, payment_method)
          commit(:EFT_AUTH_ONLY, money, post)
        else
          add_creditcard(post, payment_method)    
          commit(:CC_AUTH_ONLY, money, post)
        end
      end
      
      def credit(money, payment_method, options = {})
        post = []
        add_invoice(post, options)      
        add_address(post, payment_method, options)   
        add_customer_data(post, options)
        
        if payment_method.type == 'check'
          add_check(post, payment_method)
          commit(:EFT_CREDIT, money, post)
        else
          add_creditcard(post, payment_method)    
          commit(:CC_CREDIT, money, post)
        end
      end
      
      def purchase(money, payment_method, options = {})
        post = []
        add_invoice(post, options)        
        add_address(post, payment_method, options)   
        add_customer_data(post, options)
             
        if payment_method.type == 'check'
          add_check(post, payment_method)
          commit(:EFT_SALE, money, post)
        else
          add_creditcard(post, payment_method)    
          commit(:CC_SALE, money, post)
        end
      end                       
    
      def capture(money, authorization, options = {})
        requires!(options, :trace_number, :payment_type)
        post = ["pg_original_authorization_code=#{authorization}", "pg_original_trace_number=#{options[:trace_number]}"]
        if options.payment_type == 'check'
          commit(:EFT_CREDIT, money, post)
        else  
          commit(:CC_CREDIT, money, post)
        end
      end
      
      def void(authorization, options ={})
        requires!(options, :trace_number, :payment_type)
        post = ["pg_original_authorization_code=#{authorization}", "pg_original_trace_number=#{options[:trace_number]}"]
        
        if options.payment_type == 'check'
          commit(:EFT_CREDIT, money, post)
        else  
          commit(:CC_CREDIT, money, post)
        end
      end
      
      def recurring(money, creditcard, options ={})
        requires!(options, :interval, :billing_address)
        requires!(options[:interval], :length, :frequency)
        
        post = []
        
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)   
        add_customer_data(post, options)
        
        post << "pg_schedule_quantity=#{options[:interval][:length]}"
        post << "pg_schedule_frequency=#{RECURRING_FREQUENCIES[options[:interval][:frequency]]}"
        post << "pg_schedule_recurring_amount=#{amount(options[:recurring_amount])}" if options.key? :recurring_amount
        post << "pg_schedule_start_date=#{options[:start_date]}" if options.key? :start_date
        
        commit(:CC_SALE, money, post)
      end
      
      def update_recurring(authorization, options)
        requires!(options, :trace_number, :action)
        
        post = []
        post = ["pg_original_authorization_code=#{authorization}", "pg_original_trace_number=#{options[:trace_number]}"]
        
        commit(options[:action], nil, post)
      end
    
      private                       
      
      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
              
      end

      def add_invoice(post, options)
        post << "ecom_consumerorderid=#{options[:order_id]}"
      end
      
      def add_creditcard(post, creditcard)
        post << "Ecom_payment_card_type=#{creditcard.type}"
        post << "ecom_payment_card_name=#{creditcard.name}"
        post << "ecom_billto_postal_name_first=#{creditcard.first_name}"
        post << "ecom_billto_postal_name_last=#{creditcard.last_name}"
        post << "ecom_payment_card_number=#{creditcard.number}"
        post << "ecom_payment_card_expdate_month=#{creditcard.month}"
        post << "ecom_payment_card_expdate_year=#{creditcard.year}"
        post << "ecom_payment_card_verification=#{creditcard.verification_value}" if creditcard.verification_value?
        post << "pg_cc_swipe_data=#{creditcard.track(1)}" if creditcard.track_data?      
      end
      
      def add_check(post, check)
        post << "ecom_payment_check_trn=#{check.routing_number}"
        post << "ecom_payment_check_account=#{check.account_number}"
        post << "ecom_payment_check_account_type=#{check.account_type}"
        post << "ecom_payment_check_checkno=#{check.number}"
      end
      
      def parse(body)
        fields = body[0..-1].split(/\=.*?\n/)
        data = body[0..-2].split(/\n?.*?\=/)
        
        data_hash = {}
        fields.each_with_index { |f, i| data_hash[f.to_sym] = data[i+1]}
        
        data_hash
      end     
      
      def commit(action, money, parameters)
        parameters << "pg_total_amount=#{amount(money)}" unless money.nil?
        parameters << "pg_transaction_type=#{ACTIONS[action]}"
        
        data = dsi_send(post_data(action, parameters))
        response = parse(data)
        
        message = message_from(response)
        
        Response.new(success?(response), message, response,
          :test => test?,
          :authorization => response[:pg_authorization_code],
          :trace_number => response[:pg_trace_number],
          :avs_result => { :code => response[:pg_avs_result]}
          )
      end

      def message_from(response)
        return response[:pg_response_description].nil? ? '' : response[:pg_response_description]
      end
      
      def post_data(action, parameters = {})
        parameters << "pg_merchant_id=#{@options[:login]}"
        parameters << "pg_password=#{@options[:password]}"
        parameters << "endofdata"
        
        parameters.join("\n")
      end
      
      # Payments Gateway uses a secure socket instead of an ssl post
      def dsi_send(request)
        socket = TCPSocket.new(URL, test? ? TEST_PORT : LIVE_PORT )

        ssl_context = OpenSSL::SSL::SSLContext.new
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER

        ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
        ssl_socket.sync_close = true
        ssl_socket.connect
        
        ssl_socket.puts(request)
        ssl_socket.flush
        
        response = ""
        
        while line = ssl_socket.gets
          response << line unless line.include? "endofdata"
        end
        
        ssl_socket.close
        return response
      end
      
      def success?(response)
        response[:pg_response_type] == 'A'
      end
      
      def parse(body)
        fields = body[0..-1].split(/\=.*?\n/)
        data = body[0..-2].split(/\n?.*?\=/)
        
        data_hash = {}
        fields.each_with_index { |f, i| data_hash[f.to_sym] = data[i+1]}
        
        data_hash
      end
    end
  end
end

