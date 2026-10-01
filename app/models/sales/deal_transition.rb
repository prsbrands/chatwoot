class Sales::DealTransition < ApplicationRecord
  self.table_name = 'sales_deal_transitions'

  ACTOR_TYPES = %w[user ai system].freeze

  belongs_to :account
  belongs_to :deal, class_name: 'Sales::Deal'
  belongs_to :from_stage, class_name: 'Sales::Stage', optional: true
  belongs_to :to_stage, class_name: 'Sales::Stage'
  belongs_to :actor, class_name: 'User', optional: true

  validates :actor_type, inclusion: { in: ACTOR_TYPES }
end
