# Linha do documento: um item do catálogo (copiado, para o documento não mudar
# quando o catálogo mudar) ou uma linha livre. Os totais da linha são
# calculados por Commerce::DocumentTotals.
class Commerce::DocumentItem < ApplicationRecord
  belongs_to :document, class_name: 'Commerce::Document', inverse_of: :items
  belongs_to :item, class_name: 'Commerce::Item', optional: true

  validates :name, presence: true, length: { maximum: 200 }
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit, inclusion: { in: Commerce::Item::UNITS }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :discount_percent, :tax_rate, numericality: { in: 0..100 }
end
