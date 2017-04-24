Rails.application.routes.draw do
  devise_for :users
  get "/pages/:id" => "pages#show"
  root "pages#show", id: "home"
end
