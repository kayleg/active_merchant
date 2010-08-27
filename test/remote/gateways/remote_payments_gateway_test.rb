require 'test_helper'

class RemotePaymentsGatewayTest < Test::Unit::TestCase
  

  def setup
    @gateway = PaymentsGatewayGateway.new(fixtures(:payments_gateway))
    
    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')
    
    @options = { 
      :order_id => generate_unique_id[0..14],
      :billing_address => address
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'TEST APPROVAL', response.message
    assert response.authorization
  end
  
  def test_successful_credit
    assert response = @gateway.credit(15000, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'TEST APPROVAL', response.message
    assert response.authorization
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'TEST APPROVAL', response.message
    assert response.authorization
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization, @options.merge(:trace_number => authorization.params[:pg_trace_number.to_s]))
    assert_success capture
    assert_equal 'APPROVED', capture.message
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization, @options.merge(:trace_number => authorization.params[:pg_trace_number.to_s]))
    assert_success void
    assert_equal 'APPROVED', void.message
  end

  def test_invalid_login
    gateway = PaymentsGatewayGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'INVALID MERCH', response.message
  end
end
