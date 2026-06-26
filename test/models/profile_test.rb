# frozen_string_literal: true

require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  test "is valid with a name and age band" do
    profile = users(:one).profiles.build(name: "Mia", age_band: :ages_4_6)
    assert profile.valid?
  end

  test "requires a name" do
    profile = users(:one).profiles.build(name: "", age_band: :ages_4_6)
    assert_not profile.valid?
    assert_includes profile.errors[:name], "can't be blank"
  end

  test "requires an age band" do
    profile = users(:one).profiles.build(name: "Mia", age_band: nil)
    assert_not profile.valid?
    assert profile.errors[:age_band].any?
  end

  test "rejects an unknown age band without raising" do
    profile = users(:one).profiles.build(name: "Mia")
    profile.age_band = "ages_99"
    assert_not profile.valid?
  end

  test "exposes the supported age bands" do
    assert_equal %w[ages_4_6 ages_7_10], Profile.age_bands.keys
  end

  test "destroying the owning account destroys its profiles" do
    user = User.create!(name: "Parent", email: "parent@example.com", password: "Secret1*3*5*")
    user.profiles.create!(name: "Mia", age_band: :ages_4_6)
    assert_difference -> { Profile.count }, -1 do
      user.destroy
    end
  end
end
