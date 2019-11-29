require 'sidekiq/web'

Rails.application.routes.draw do
  devise_for :admins
  devise_for :users

  resource :dashboard, only: [:show]
  resources :pages, only: [:show]

  resources :collected_inks, only: [:index, :create, :update, :destroy] do
    resource :archive, only: [:create, :destroy]
  end
  namespace :collected_inks do
    resources :beta, only: [:index, :destroy, :edit, :update, :new, :create] do
      member do
        post 'archive'
        post 'unarchive'
      end
    end
  end

  resources :collected_pens do
    resource :archive, only: [:create, :destroy]
  end
  resources :currently_inked do
    member do
      post 'archive'
      post 'refill'
    end
    resource :usage_record, only: [:create]
  end
  resources :currently_inked_archive, only: [:index, :edit, :update, :destroy] do
    member do
      post 'unarchive'
    end
  end

  resources :usage_records, only: [:index, :destroy, :edit, :update]

  resources :brands, only: [:index]
  namespace :pens do
    resources :brands, only: [:index]
    resources :models, only: [:index]
  end
  get 'brands/:id', to: "brands#show", constraints: { id: /[^\/]+/}, as: "brand"
  resources :lines, only: [:index]
  resources :inks, only: [:index]
  resource :account, only: [:show, :edit, :update]

  resources :users, only: [:index, :show]

  namespace :admins do
    resource :dashboard, only: [:show]
    resources :ink_brands, only: [:index, :show]
    resources :users, only: [:index] do
      member do
        post 'become'
        post 'ink_import'
        post 'pen_import'
      end
    end
  end

  authenticate :admin do
    mount Sidekiq::Web => '/admins/sidekiq'
  end

  root "pages#show", id: "home"
end
