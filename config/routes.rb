Rails.application.routes.draw do
  get "/pages/:id" => "pages#show"
  root "pages#show", id: "home"
end
