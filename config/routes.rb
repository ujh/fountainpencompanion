Rails.application.routes.draw do
  devise_for :users
  get "/pages/:id" => "pages#show"
  resources :inks
  root "pages#show", id: "home"
end
