Rails.application.routes.draw do
  devise_for :users
  get "/pages/:id" => "pages#show"

  resources :collected_inks do
    resource :privacy, only: [:create, :destroy]
  end
  resources :brands, only: [:index]
  resources :inks, only: [:index]

  root "pages#show", id: "home"
end
