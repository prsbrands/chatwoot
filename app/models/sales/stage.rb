class Sales::Stage < ApplicationRecord
  self.table_name = 'sales_stages'

  DEFAULT_EXPECTED_HOURS = 24

  belongs_to :account
  belongs_to :pipeline, class_name: 'Sales::Pipeline'
  has_many :deals, class_name: 'Sales::Deal', dependent: :restrict_with_error

  enum :kind, { open: 0, won: 1, lost: 2 }

  validates :name, presence: true
  validates :agent_step, inclusion: { in: Sales::Pipeline::AGENT_STEPS }, allow_nil: true
  validates :agent_step, uniqueness: { scope: :pipeline_id }, allow_nil: true
  validates :expected_duration_hours, numericality: { greater_than: 0 }, allow_nil: true

  def expected_hours
    expected_duration_hours || DEFAULT_EXPECTED_HOURS
  end
end
