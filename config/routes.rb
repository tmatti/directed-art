# frozen_string_literal: true

Rails.application.routes.draw do
  get  "sign_in", to: "sessions#new", as: :sign_in
  post "sign_in", to: "sessions#create"
  get  "sign_up", to: "users#new", as: :sign_up
  post "sign_up", to: "users#create"

  resources :sessions, only: [ :destroy ]
  resource :users, only: [ :destroy ]

  namespace :identity do
    resource :email_verification, only: [ :show, :create ]
    resource :password_reset,     only: [ :new, :edit, :create, :update ]
  end

  get :dashboard, to: "dashboard#index"

  resources :profiles, except: [ :show ]
  resource :active_profile, only: [ :show, :update ]

  # The guided planning chat that assembles a Drawing Plan, one question at a
  # time, for the active Profile.
  resources :drawing_plans, only: [ :create, :show, :update ] do
    # Submits a completed Plan for background generation and serves the
    # "drawing your picture…" wait screen, which polls show until the Directed
    # Drawing is ready (ADR-0009).
    resource :generation, only: [ :create, :show ], module: :drawing_plans
  end

  resources :directed_drawings, only: [ :index, :show ] do
    # The resumable Walkthrough position, persisted so a child returns to where
    # they left off.
    resource :current_step, only: [ :update ], module: :directed_drawings
  end

  namespace :settings do
    resource :profile, only: [ :show, :update ]
    resource :password, only: [ :show, :update ]
    resource :email, only: [ :show, :update ]
    resources :sessions, only: [ :index ]
    inertia :appearance
  end

  root "home#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
