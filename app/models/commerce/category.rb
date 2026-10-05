class Commerce::Category < ApplicationRecord
  belongs_to :account
  has_many :items, class_name: 'Commerce::Item', dependent: :nullify, inverse_of: :category

  validates :name, presence: true, length: { maximum: 80 }
end
