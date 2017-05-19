Rails.application.routes.draw do
  devise_for :users
  get "/pages/:id" => "pages#show"

  resources :collected_inks
  resources :manufacturers, only: [:index]
  resources :inks, only: [:index]

  root "pages#show", id: "home"
end
