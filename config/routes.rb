require 'sidekiq/web'
require 'sidekiq-scheduler/web'
Sidekiq::Web.set :sessions, false

Rails.application.routes.draw do
  devise_for :admins
  devise_for :users

  resource :dashboard, only: [:show]
  resources :pages, only: [:show]
  resources :blog, only: [:index, :show] do
    collection do
      get 'feed', defaults: { format: 'rss' }
    end
  end

  resources :reading_statuses, only: [:update]
  resources :collected_inks, only: [:index, :destroy, :edit, :update, :new, :create] do
    collection do
      get 'import'
    end
    member do
      post 'archive'
      post 'unarchive'
    end
  end

  resources :collected_pens do
    collection do
      get 'import'
    end
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

  resources :friendships, only: [:create, :update, :destroy]
  resources :usage_records, only: [:index, :destroy, :edit, :update]

  resources :brands, only: [:index] do
    resources :inks, only: [:show]
  end
  resources :inks, only: [:show]
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
    resources :users, only: [:index, :show, :update] do
      member do
        post 'become'
        post 'ink_import'
        post 'pen_import'
      end
    end
    resources :graphs, only: [:show]
    resources :brand_clusters, only: [:index, :new, :create, :update]
    resources :macro_clusters, only: [:index, :create, :update, :destroy, :show]
    resources :micro_clusters, only: [:index, :update] do
      collection do
        get 'ignored'
      end
      member do
        delete 'unassign'
      end
    end
    resources :blog_posts do
      member do
        put 'publish'
      end
    end
  end

  authenticate :admin do
    mount Sidekiq::Web => '/admins/sidekiq'
  end

  root "pages#show", id: "home"
end
