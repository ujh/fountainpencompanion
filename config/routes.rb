Rails.application.routes.draw do
  devise_for :admins
  devise_for :users

  resources :pages, only: [:show]

  resources :collected_inks do
    resource :archive, only: [:create, :destroy]
  end
  resources :collected_pens do
    resource :archive, only: [:create, :destroy]
  end
  resources :currently_inked do
    resource :archive, only: [:create, :destroy]
  end
  resources :brands, only: [:index]
  namespace :pens do
    resources :brands, only: [:index]
    resources :models, only: [:index]
  end
  get 'brands/:id', to: "brands#show", constraints: { id: /[^\/]+/}, as: "brand"
  resources :lines, only: [:index]
  resources :inks, only: [:index]
  resource :account, only: [:show, :edit, :update]

  resources :users, only: [:index, :show] do
    resource :possibly_wanted, only: [:show]
    resource :possibly_interesting, only: [:show]
  end

  namespace :admins do
    resource :dashboard, only: [:show]
    resources :ink_brands, only: [:index]
    resources :users, only: [:index] do
      member do
        post 'become'
        post 'import'
      end
    end
  end

  root "pages#show", id: "home"
end
