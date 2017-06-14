Rails.application.routes.draw do
  devise_for :users
  get "/pages/:id" => "pages#show"

  resources :collected_inks do
    resource :privacy, only: [:create, :destroy]
  end
  resources :brands, only: [:index]
  resources :lines, only: [:index]
  resources :inks, only: [:index]
  resource :account, only: [:show, :edit, :update]

  resources :users, only: [:index, :show] do
    resource :possibly_wanted, only: [:show]
    resource :possibly_interesting, only: [:show]
  end

  root "pages#show", id: "home"
end
