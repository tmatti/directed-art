# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  fixtures :users

  describe "GET /dashboard" do
    context "when signed out" do
      it "redirects to the sign in page" do
        get dashboard_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in" do
      it "reaches the protected page" do
        sign_in users(:one)
        get dashboard_path
        expect(response).to have_http_status(:success)
      end
    end
  end
end
