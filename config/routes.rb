require "sidekiq/web"
require "sidekiq-scheduler/web"

Rails.application.routes.draw do
  devise_for :users,
             controllers: {
               registrations: "users/registrations",
               sessions: "devise/passwordless/sessions"
             }

  devise_scope :user do
    get "/users/magic_link",
        to: "devise/passwordless/magic_links#show",
        as: "users_magic_link"
  end

  resource :dashboard, only: [:show] do
    resources :widgets, only: [:show]
  end
  resources :pages, only: [:show]
  resources :blog, only: %i[index show] do
    collection { get "feed", defaults: { format: "rss" } }
  end

  resources :reading_statuses, only: [:update]
  resources :collected_inks, only: %i[index edit update new create destroy] do
    collection { get "import" }
    member do
      post "archive"
      post "unarchive"
    end
  end
  namespace :collected_inks do
    resources :add, only: [:create]
  end

  resources :collected_pens, only: %i[index edit update new create] do
    collection { get "import" }
    member { post "archive" }
  end
  resources :collected_pens_archive, only: %i[index edit update destroy] do
    member { post "unarchive" }
  end
  resources :currently_inked do
    member do
      post "archive"
      post "refill"
    end
    resource :usage_record, only: [:create]
  end
  resources :currently_inked_archive, only: %i[index edit update destroy] do
    member { post "unarchive" }
  end

  resources :friendships, only: %i[create update destroy]
  resources :usage_records, only: %i[index destroy edit update]

  resources :brands, only: %i[index edit update show] do
    resources :inks, only: %i[show edit update] do
      resources :ink_review_submissions, only: [:create]
    end
  end
  resources :inks, only: [:show]
  namespace :pens do
    resources :brands, only: [:index]
    resources :models, only: [:index]
    resources :nibs, only: [:index]
  end
  resources :inks, only: [:index]
  resource :account, only: %i[show edit update]

  resources :users, only: %i[index show]

  resources :reviews, only: [] do
    collection do
      get "missing"
      get "my_missing"
    end
  end

  namespace :api do
    namespace :v1 do
      resources :brands, only: [:index]
      resources :lines, only: [:index]
      resources :inks, only: [:index]
      resources :collected_pens, only: [:index]
      resources :currently_inked, only: [:index]
    end
  end

  namespace :admins do
    resource :dashboard, only: [:show]
    resources :users, only: %i[index show update] do
      member do
        post "become"
        post "ink_import"
        post "pen_import"
        post "currently_inked_import"
      end
    end
    resources :graphs, only: [:show]
    resources :brand_clusters, only: %i[index new create update]
    resources :macro_clusters, only: %i[index create update destroy show]
    resources :micro_clusters, only: %i[index update] do
      collection { get "ignored" }
      member { delete "unassign" }
    end
    resources :blog_posts do
      member { put "publish" }
    end
    resources :reviews, only: %i[index update destroy] do
    end
    namespace :reviews do
      resources :missing, only: %i[index show] do
        member { post "add" }
      end
    end
    namespace :descriptions do
      resources :brands, only: [:index]
      resources :inks, only: [:index]
    end
  end

  authenticate :user, lambda { |user| user.admin? } do
    mount Sidekiq::Web => "/admins/sidekiq"
  end

  root "pages#show", id: "home"
end
