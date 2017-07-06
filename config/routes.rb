Rails.application.routes.draw do
  devise_for :admins
  devise_for :users

  resources :pages, only: [:show]

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

  namespace :admins do
    resources :users, only: [:index] do
      member do
        post 'become'
        post 'import'
      end
    end
    resources :brands, only: [:index, :show]
  end

  root "pages#show", id: "home"
end
