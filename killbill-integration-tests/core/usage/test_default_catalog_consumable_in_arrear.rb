$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestDefaultCatalogConsumableInArrear < Base

    def setup
      setup_base

      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    #
    # Test correct usage is generated when specifying boundaries date
    #
    def test_on_boundaries

      bp = create_entitlement_base(@account.account_id, 'Super', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Super', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)


      # Create Add-on
      ao_entitlement = create_entitlement_ao(@account.account_id, bp.bundle_id, 'Gas', 'NO_BILLING_PERIOD', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'Gas', 'ADD_ON', 'NO_BILLING_PERIOD', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Add usage on first day for prev period and first day of new period
      # Only the '2013-08-1' with 10 units, should be taken into account for the next upcoming invoice
      usage_input = [ {:unit_type => 'gallons',
                       :usage_records => [{:record_date => '2013-08-01', :amount => 10 },
                                          {:record_date => '2013-08-31', :amount => 5 }]
                      }]

      record_usage(ao_entitlement.subscription_id, usage_input, @user, @options)

      # Check recorded usage (we only see 10 units)
      recorded_usage = get_usage_for_subscription_and_type(ao_entitlement.subscription_id, '2013-08-1', '2013-08-31', 'gallons', @options)
      assert_equal(recorded_usage.subscription_id, ao_entitlement.subscription_id)
      assert_equal(recorded_usage.start_date, '2013-08-01')
      assert_equal(recorded_usage.end_date, '2013-08-31')
      assert_equal(recorded_usage.rolled_up_units.size, 1)
      assert_equal(recorded_usage.rolled_up_units[0].amount, 10)
      assert_equal(recorded_usage.rolled_up_units[0].unit_type, 'gallons')

      recorded_usage = get_usage_for_subscription_and_type(ao_entitlement.subscription_id, '2013-08-1', '2013-09-01', 'gallons', @options)
      assert_equal(recorded_usage.subscription_id, ao_entitlement.subscription_id)
      assert_equal(recorded_usage.start_date, '2013-08-01')
      assert_equal(recorded_usage.end_date, '2013-09-01')
      assert_equal(recorded_usage.rolled_up_units.size, 1)
      assert_equal(recorded_usage.rolled_up_units[0].amount, 15)
      assert_equal(recorded_usage.rolled_up_units[0].unit_type, 'gallons')

      #
      # Move to next invoice => Date = '2013-08-31' => Should see usage for '2013-08-1'
      #
      kb_clock_add_days(30, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 1039.50, 'USD', '2013-08-31')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'super-monthly', 'super-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_usage_invoice_item(second_invoice.items[1], second_invoice.invoice_id, 39.50, 'USD', 'USAGE', 'gas-monthly', 'gas-monthly-evergreen', 'gas-monthly-in-arrear', '2013-08-01', '2013-08-31')

      #
      # Move to next invoice => Date = '2013-09-30' => Should see usage for '2013-08-31' that was previously recorded
      #
      kb_clock_add_days(30, nil, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 1019.75, 'USD', '2013-09-30')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'super-monthly', 'super-monthly-evergreen', '2013-09-30', '2013-10-31')
      check_usage_invoice_item(third_invoice.items[1], third_invoice.invoice_id, 19.75, 'USD', 'USAGE', 'gas-monthly', 'gas-monthly-evergreen', 'gas-monthly-in-arrear', '2013-08-31', '2013-09-30')

      #
      # Move to next invoice => Date = '2013-10-31' => Should see no usage
      #
      kb_clock_add_days(31, nil, @options)
      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(4, all_invoices.size)
      fourth_invoice = all_invoices[3]
      check_invoice_no_balance(fourth_invoice, 1000.00, 'USD', '2013-10-31')
      check_invoice_item(fourth_invoice.items[0], fourth_invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'super-monthly', 'super-monthly-evergreen', '2013-10-31', '2013-11-30')
    end

    #
    # Test with a few different records for the same period
    #
    def test_with_multiple_records

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Create Add-on
      ao_entitlement = create_entitlement_ao(@account.account_id, bp.bundle_id, 'Gas', 'NO_BILLING_PERIOD', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'Gas', 'ADD_ON', 'NO_BILLING_PERIOD', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      usage_input = [ {:unit_type => 'gallons',
                       :usage_records => [{:record_date => '2013-08-11', :amount => 2 },
                                          {:record_date => '2013-08-12', :amount => 1 },
                                          {:record_date => '2013-08-13', :amount => 3 },
                                          {:record_date => '2013-08-14', :amount => 1 },
                                          {:record_date => '2013-08-15', :amount => 1 },
                                          {:record_date => '2013-08-17', :amount => 2 }]
                      }]

      record_usage(ao_entitlement.subscription_id, usage_input, @user, @options)

      # Check recorded usage
      recorded_usage = get_usage_for_subscription(ao_entitlement.subscription_id, '2013-08-1', '2013-08-31', @options)
      assert_equal(recorded_usage.subscription_id, ao_entitlement.subscription_id)
      assert_equal(recorded_usage.start_date, '2013-08-01')
      assert_equal(recorded_usage.end_date, '2013-08-31')
      assert_equal(recorded_usage.rolled_up_units.size, 1)
      assert_equal(recorded_usage.rolled_up_units[0].amount, 10)
      assert_equal(recorded_usage.rolled_up_units[0].unit_type, 'gallons')


      #
      # Move to next invoice => Date = '2013-09-01' (we moved 1 day after BCD on purpose)
      #
      kb_clock_add_days(31, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 539.50, 'USD', '2013-09-01')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_usage_invoice_item(second_invoice.items[1], second_invoice.invoice_id, 39.50, 'USD', 'USAGE', 'gas-monthly', 'gas-monthly-evergreen', 'gas-monthly-in-arrear', '2013-08-01', '2013-08-31')
    end

    #
    # Test with records inserted later for past period
    #
    def test_with_records_inserted_later

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Create Add-on
      ao_entitlement = create_entitlement_ao(@account.account_id, bp.bundle_id, 'Gas', 'NO_BILLING_PERIOD', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'Gas', 'ADD_ON', 'NO_BILLING_PERIOD', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      usage_input = [ {:unit_type => 'gallons',
                       :usage_records => [{:record_date => '2013-08-11', :amount => 10 }]
                      }]

      record_usage(ao_entitlement.subscription_id, usage_input, @user, @options)

      #
      # Move to next invoice => Date = '2013-08-31'
      #
      kb_clock_add_days(30, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 539.50, 'USD', '2013-08-31')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_usage_invoice_item(second_invoice.items[1], second_invoice.invoice_id, 39.50, 'USD', 'USAGE', 'gas-monthly', 'gas-monthly-evergreen', 'gas-monthly-in-arrear', '2013-08-01', '2013-08-31')

      # Add more usage for previous period and also new period

      usage_input = [ {:unit_type => 'gallons',
                       :usage_records => [{:record_date => '2013-08-13', :amount => 20 },
                                          {:record_date => '2013-09-2', :amount => 5 }]
                      }]
      record_usage(ao_entitlement.subscription_id, usage_input, @user, @options)

      kb_clock_add_days(30, nil, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 598.75, 'USD', '2013-09-30')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-30', '2013-10-31')
      check_usage_invoice_item(third_invoice.items[1], third_invoice.invoice_id, 79.0, 'USD', 'USAGE', 'gas-monthly', 'gas-monthly-evergreen', 'gas-monthly-in-arrear', '2013-08-01', '2013-08-31')
      check_usage_invoice_item(third_invoice.items[2], third_invoice.invoice_id, 19.75, 'USD', 'USAGE', 'gas-monthly', 'gas-monthly-evergreen', 'gas-monthly-in-arrear', '2013-08-31', '2013-09-30')

      #
      # Add more usage for the last 2 periods and also new period
      #
      usage_input = [ {:unit_type => 'gallons',
                       :usage_records => [{:record_date => '2013-09-3', :amount => 5 },
                                          {:record_date => '2013-10-3', :amount => 10 }]
                      }]

      record_usage(ao_entitlement.subscription_id, usage_input, @user, @options)

      kb_clock_add_days(31, nil, @options)
      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(4, all_invoices.size)
      fourth_invoice = all_invoices[3]
      check_invoice_no_balance(fourth_invoice, 559.25, 'USD', '2013-10-31')
      check_invoice_item(fourth_invoice.items[0], fourth_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-10-31', '2013-11-30')
      check_usage_invoice_item(fourth_invoice.items[1], fourth_invoice.invoice_id, 19.75, 'USD', 'USAGE', 'gas-monthly', 'gas-monthly-evergreen', 'gas-monthly-in-arrear', '2013-08-31', '2013-09-30')
      check_usage_invoice_item(fourth_invoice.items[2], fourth_invoice.invoice_id, 39.50, 'USD', 'USAGE', 'gas-monthly', 'gas-monthly-evergreen', 'gas-monthly-in-arrear', '2013-09-30', '2013-10-31')

      #
      # Add more usage for the last period and the period from '2013-08-1' -> '2013-08-31'. That one should NOT be invoiced because org.killbill.invoice.readMaxRawUsagePreviousPeriod is set to 2 by default
      #
      usage_input = [ {:unit_type => 'gallons',
                       :usage_records => [{:record_date => '2013-08-14', :amount => 20 },
                                          {:record_date => '2013-11-3', :amount => 10 }]
                      }]

      record_usage(ao_entitlement.subscription_id, usage_input, @user, @options)

      kb_clock_add_days(30, nil, @options)
      wait_for_expected_clause(5, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(5, all_invoices.size)
      fifth_invoice = all_invoices[4]
      check_invoice_no_balance(fifth_invoice, 539.50, 'USD', '2013-11-30')
      check_invoice_item(fifth_invoice.items[0], fifth_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-11-30', '2013-12-31')
      check_usage_invoice_item(fifth_invoice.items[1], fifth_invoice.invoice_id, 39.50, 'USD', 'USAGE', 'gas-monthly', 'gas-monthly-evergreen', 'gas-monthly-in-arrear', '2013-10-31', '2013-11-30')


    end


    #
    # Cancel BP EOT and verofy that when AO cancellation date is reached the usage is correctly generated; also check we can't record usage after cancellation
    #
    def test_with_subscription_cancelled_eot

      bp = create_entitlement_base(@account.account_id, 'Super', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Super', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)


      # Create Add-on
      ao_entitlement = create_entitlement_ao(@account.account_id, bp.bundle_id, 'Gas', 'NO_BILLING_PERIOD', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'Gas', 'ADD_ON', 'NO_BILLING_PERIOD', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)


      #
      # Move to next invoice => Date = '2013-08-31' so as to NOT BE in trial and EOT cancellation works as expected
      #
      kb_clock_add_days(30, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 1000.0, 'USD', '2013-08-31')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'super-monthly', 'super-monthly-evergreen', '2013-08-31', '2013-09-30')


      # Add usage on first day for prev period and first day of new period
      # Only the '2013-08-1', 10 should be taken into account for the next upcoming invoice
      usage_input = [ {:unit_type => 'gallons',
                       :usage_records => [{:record_date => '2013-08-1', :amount => 10 }]
                      }]

      record_usage(ao_entitlement.subscription_id, usage_input, @user, @options)

      requested_date = nil
      entitlement_policy = nil
      billing_policy = "END_OF_TERM"
      use_requested_date_for_billing = nil


      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      #
      # Move to next invoice => Date = '2013-09-30' => The ADD_ON is effectively cancelled and we should see usage for '2013-08-31' that was previously recorded
      #
      kb_clock_add_days(30, nil, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 39.5, 'USD', '2013-09-30')
      check_usage_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 39.5, 'USD', 'USAGE', 'gas-monthly', 'gas-monthly-evergreen', 'gas-monthly-in-arrear', '2013-08-01', '2013-08-31')


      # Attempt to record more usage, but that should fail because ADD_ON is not active
      usage_input = [ {:unit_type => 'gallons',
                       :usage_records => [{:record_date => '2013-09-5', :amount => 5 }]
                      }]

      got_exception = false
      begin
        record_usage(ao_entitlement.subscription_id, usage_input, @user, @options)
      rescue KillBillClient::API::BadRequest => e
        got_exception = true
      end
      assert(got_exception, "Failed to get exception")
    end

    #
    # Test BP IMM cancellation and verify that usage is generation right at the time of cancellation
    #
    def test_with_subscription_cancelled_imm

      bp = create_entitlement_base(@account.account_id, 'Super', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Super', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)


      # Create Add-on
      ao_entitlement = create_entitlement_ao(@account.account_id, bp.bundle_id, 'Gas', 'NO_BILLING_PERIOD', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'Gas', 'ADD_ON', 'NO_BILLING_PERIOD', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)


      #
      # Move to next invoice => Date = '2013-08-31' so as to NOT BE in trial and EOT cancellation works as expected
      #
      kb_clock_add_days(30, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 1000.0, 'USD', '2013-08-31')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'super-monthly', 'super-monthly-evergreen', '2013-08-31', '2013-09-30')


      # Add usage on first day for prev period and first day of new period
      # Only the '2013-08-1', 10 should be taken into account for the next upcoming invoice
      usage_input = [ {:unit_type => 'gallons',
                       :usage_records => [{:record_date => '2013-08-1', :amount => 10 }]
                      }]

      record_usage(ao_entitlement.subscription_id, usage_input, @user, @options)

      requested_date = nil
      entitlement_policy = nil
      billing_policy = "IMMEDIATE"
      use_requested_date_for_billing = nil


      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      third_invoice = all_invoices[2]
      # There is also a REPAIR from the IMM cancellation
      check_invoice_no_balance(third_invoice, -960.50, 'USD', '2013-08-31')
      check_usage_invoice_item(get_specific_invoice_item(third_invoice.items, 'USAGE', 39.5), third_invoice.invoice_id, 39.5, 'USD', 'USAGE', 'gas-monthly', 'gas-monthly-evergreen', 'gas-monthly-in-arrear', '2013-08-01', '2013-08-31')
    end

  end
end