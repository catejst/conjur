# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authentication::Security::ValidateWhitelistedWebservice do
  include_context "security mocks"

  let (:blank_env) { nil }
  let (:not_including_env) do
    "authn-other/service1"
  end

  let(:default_authenticator_mock) do
    double('authenticator').tap do |authenticator|
      allow(authenticator).to receive(:authenticator_name).and_return("authn")
    end
  end

  def mock_admin_role_class
    double('role_class').tap do |role_class|
      allow(role_class).to receive(:[])
                             .with(/#{test_account}:user:admin/)
                             .and_return("admin-role")

      allow(role_class).to receive(:[])
                             .with(/#{non_existing_account}:user:admin/)
                             .and_return(nil)
    end
  end

  def webservices_dict(includes_authenticator:)
    double('webservices_dict').tap do |webservices_dict|
      allow(webservices_dict).to receive(:include?)
                                   .and_return(includes_authenticator)
    end
  end

  def mock_webservices_class
    double('webservices_class').tap do |webservices_class|


      allow(webservices_class).to receive(:from_string)
                                    .with(anything, two_authenticator_env)
                                    .and_return(webservices_dict(includes_authenticator: true))

      allow(webservices_class).to receive(:from_string)
                                    .with(anything, not_including_env)
                                    .and_return(webservices_dict(includes_authenticator: false))

      allow(webservices_class).to receive(:from_string)
                                    .with(anything, blank_env)
                                    .and_return(webservices_dict(includes_authenticator: false))
    end
  end

  context "A whitelisted webservice" do
    subject do
      Authentication::Security::ValidateWhitelistedWebservice.new(
        role_class: mock_admin_role_class,
        webservices_class: mock_webservices_class
      ).(
        webservice: mock_webservice("#{fake_authenticator_name}/service1"),
          account: test_account,
          enabled_authenticators: two_authenticator_env
      )
    end

    it "validates without error" do
      expect { subject }.to_not raise_error
    end
  end

  context "A un-whitelisted webservice" do
    subject do
      Authentication::Security::ValidateWhitelistedWebservice.new(
        role_class: mock_admin_role_class,
        webservices_class: mock_webservices_class
      ).(
        webservice: mock_webservice("#{fake_authenticator_name}/service1"),
          account: test_account,
          enabled_authenticators: not_including_env
      )
    end

    it "raises a NotWhitelisted error" do
      expect { subject }.to raise_error(Errors::Authentication::Security::NotWhitelisted)
    end
  end

  context "An ENV lacking CONJUR_AUTHENTICATORS" do
    subject do
      Authentication::Security::ValidateWhitelistedWebservice.new(
        role_class: mock_admin_role_class,
        webservices_class: mock_webservices_class
      ).(
        webservice: default_authenticator_mock,
          account: test_account,
          enabled_authenticators: blank_env
      )
    end

    it "the default Conjur authenticator is included in whitelisted webservices" do
      expect { subject }.to_not raise_error
    end
  end

  context "A non-existing account" do
    subject do
      Authentication::Security::ValidateWhitelistedWebservice.new(
        role_class: mock_admin_role_class,
        webservices_class: mock_webservices_class
      ).(
        webservice: mock_webservice("#{fake_authenticator_name}/service1"),
          account: non_existing_account,
          enabled_authenticators: two_authenticator_env
      )
    end

    it "raises an AccountNotDefined error" do
      expect { subject }.to raise_error(Errors::Authentication::Security::AccountNotDefined)
    end
  end
end
