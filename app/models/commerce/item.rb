# Produto ou serviço do catálogo. Preço é opcional: sem preço, o item é "sob
# orçamento" (o que se mede, se projeta ou se faz sob medida). Quando tem preço,
# a moeda vai junto.
class Commerce::Item < ApplicationRecord
  UNITS = %w[unit hour day week month m m2 m3 kg liter package project service].freeze
  MAX_IMAGES = 10

  belongs_to :account
  belongs_to :category, class_name: 'Commerce::Category', optional: true
  has_many_attached :images

  enum :kind, { product: 0, service: 1 }, validate: true

  validates :name, presence: true, length: { maximum: 160 }
  validates :sku, length: { maximum: 60 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency, inclusion: { in: Commerce::CURRENCIES }
  validates :unit, inclusion: { in: UNITS }
  validate :category_in_account
  validate :images_limit

  def on_quote?
    price.nil?
  end

  private

  def category_in_account
    errors.add(:category, :invalid) if category && category.account_id != account_id
  end

  def images_limit
    errors.add(:images, :too_long, count: MAX_IMAGES) if images.size > MAX_IMAGES
  end
end
