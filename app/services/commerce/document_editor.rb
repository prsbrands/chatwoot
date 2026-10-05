# Salva o documento a partir da tela: cabeçalho, cliente e a lista inteira de
# linhas (a tela manda sempre todas). Enquanto ele pode ser editado, renova a
# cópia dos dados da empresa e recalcula os totais. Os dados fiscais digitados
# do cliente ficam lembrados no contato para o próximo documento.
class Commerce::DocumentEditor
  HEADER = %i[language currency tax_mode issue_date due_date notes terms footer contact_id deal_id appointment_id conversation_id].freeze
  LINE = %i[item_id name description quantity unit unit_price discount_percent tax_rate].freeze

  def initialize(document, params)
    @document = document
    @account = document.account
    @params = params
  end

  def save!
    unless @document.editable?
      @document.errors.add(:base, "#{@document.number} is #{@document.status} and can no longer be edited")
      raise ActiveRecord::RecordInvalid, @document
    end

    Commerce::Document.transaction do
      @document.assign_attributes(header)
      @document.customer = customer if @params.key?(:customer)
      replace_lines if @params.key?(:items)
      @document.company = company_snapshot
      @document.recalculate!
      @document.save!
      remember_customer
    end
    @document
  end

  private

  # Contato, negócio, compromisso e conversa têm que ser da conta.
  def header
    @params.slice(*HEADER).tap do |attrs|
      @account.contacts.find(attrs[:contact_id]) if attrs[:contact_id].present?
      @account.sales_deals.find(attrs[:deal_id]) if attrs[:deal_id].present?
      @account.agenda_appointments.find(attrs[:appointment_id]) if attrs[:appointment_id].present?
      @account.conversations.find(attrs[:conversation_id]) if attrs[:conversation_id].present?
    end
  end

  def customer
    (@params[:customer] || {}).to_h.slice(*Commerce::Document::CUSTOMER_FIELDS).transform_values { |v| v.to_s.strip }
  end

  def replace_lines
    @document.items.delete_all if @document.persisted?
    @document.items.reset
    Array(@params[:items]).each_with_index do |line, index|
      attrs = line.to_h.symbolize_keys.slice(*LINE)
      @account.commerce_items.find(attrs[:item_id]) if attrs[:item_id].present?
      attrs[:unit_price] = nil if attrs[:unit_price].blank?
      @document.items.build(attrs.merge(position: index))
    end
  end

  def company_snapshot
    profile = Commerce::Profile.for(@account)
    profile.slice(:trade_name, :legal_name, :tax_id_label, :tax_id, :address, :phone, :whatsapp, :email, :website)
           .merge('logo_blob_id' => profile.logo.attached? ? profile.logo.blob.id : nil)
  end

  def remember_customer
    return unless @document.contact && @params.key?(:customer)

    fiscal = @document.customer.slice('tax_id_label', 'tax_id', 'address').compact_blank
    return if fiscal.empty?

    attributes = (@document.contact.additional_attributes || {}).merge(fiscal.transform_keys { |key| "billing_#{key}" })
    @document.contact.update!(additional_attributes: attributes)
  end
end
