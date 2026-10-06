json.call(resource, :id, :kind, :number, :status, :language, :currency, :tax_mode, :contact_id, :deal_id, :appointment_id,
          :conversation_id, :source_document_id, :customer, :notes, :terms, :footer, :details, :delivered_email)
json.display_status resource.display_status
json.editable resource.editable?
json.payable resource.payable?
json.issue_date resource.issue_date
json.due_date resource.due_date
%i[subtotal discount_total tax_total total amount_paid].each { |column| json.set! column, resource.public_send(column).to_s }
json.balance resource.balance.to_s
json.sent_at resource.sent_at&.to_i
json.archived_at resource.archived_at&.to_i
json.public_url "#{ENV.fetch('FRONTEND_URL')}/d/#{resource.public_token}"
if local_assigns[:full]
  json.items resource.items do |line|
    json.call(line, :id, :item_id, :name, :description, :unit)
    %i[quantity unit_price discount_percent tax_rate line_subtotal line_discount line_tax line_total].each do |column|
      json.set! column, line.public_send(column)&.to_s
    end
  end
  json.payments resource.payments.includes(:receipt) do |payment|
    json.call(payment, :id, :payment_method_id, :paid_on, :note, :receipt_id)
    json.amount payment.amount.to_s
    json.online payment.online?
    json.receipt_number payment.receipt&.number
  end
  json.pdfs resource.pdfs.attachments.sort_by(&:created_at).reverse do |pdf|
    json.id pdf.id
    json.url url_for(pdf)
    json.created_at pdf.created_at.to_i
  end
end
