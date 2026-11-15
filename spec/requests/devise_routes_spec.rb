require "rails_helper"

describe "Devise routes", type: :request do
  [
    %i[post /users/sign_in.json],
    %i[post /users/sign_in.html],
    %i[post /users/password.html],
    %i[put /users/password.json],
    %i[post /users.json],
    %i[put /users.html],
    %i[post /users/confirmation.json],
    %i[get /users/confirmation.html],
    %i[get /users/magic_link.json],
    %i[delete /users/sign_out.json]
  ].each do |method, path|
    it "answers #{method.upcase} #{path} with not found" do
      send(
        method,
        path.to_s,
        params: {
          user: {
            email: "someone@example.com",
            password: "secret"
          }
        }
      )

      expect(response).to have_http_status(:not_found)
    end
  end
end
