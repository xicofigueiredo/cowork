Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
  get "pricing" => "pricing#index"
  get "our-space" => "our_space#index", as: :our_space
  get "location" => "location#index"
  post "location" => "location#create"
  get "privacy-policy" => "legal#privacy_policy", as: :privacy_policy

  resources :checkouts, only: [ :new, :create, :show ] do
    member do
      post :pay
    end
  end

  resources :bookings, only: [ :index, :new, :create, :edit, :update ]
  resource :meeting_booking, only: [ :new, :create ]

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
