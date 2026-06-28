# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# A demo Account + Profile with one seeded Directed Drawing, built from the
# hardcoded structured-drawing plan the spike validated (ADR-0001, ADR-0005).
# Proves the renderer end-to-end with zero LLM risk.
demo = User.find_or_create_by!(email: "demo@example.com") do |user|
  user.name = "Demo Parent"
  user.password = "Secret1*3*5*"
  user.verified = true
end

profile = demo.profiles.find_or_create_by!(name: "Demo Kid") do |child|
  child.age_band = :ages_4_6
end

plan = JSON.parse(Rails.root.join("db/seed_drawings/happy_sun.json").read)

unless profile.directed_drawings.exists?(subject: plan["subject"])
  DirectedDrawing.create_from_plan!(profile: profile, plan: plan)
end
