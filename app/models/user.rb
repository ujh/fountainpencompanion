class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, # :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :collected_inks

  def build_collected_ink(params)
    ci = CollectedInk.build(params)
    ci.user = self
    ci
  end
end
