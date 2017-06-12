class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :collected_inks

  validates :name, length: { in: 1..100, allow_blank: true }

  def to_param
    "#{id}-#{name.downcase.gsub(/\s/, '-')}"
  end

  def public_inks
    collected_inks.where(private: false).order("brand_name, line_name, ink_name")
  end

  def private?
    name.blank?
  end
end
