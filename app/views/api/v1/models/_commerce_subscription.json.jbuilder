json.call(resource, :id, :name, :interval, :status, :currency, :language, :customer, :contact_id, :deal_id, :conversation_id, :item_id,
          :payment_method_id, :cancel_at_period_end, :public_url)
%i[quantity unit_price amount].each { |column| json.set! column, resource.public_send(column).to_s }
json.payment_method_name resource.payment_method&.name
%i[current_period_start current_period_end canceled_at sent_at created_at].each do |column|
  json.set! column, resource.public_send(column)&.to_i
end
if local_assigns[:full]
  json.invoices resource.invoices.includes(payments: :receipt) do |invoice|
    json.call(invoice, :id, :number, :status, :period_start, :period_end)
    json.total invoice.total.to_s
    json.receipts invoice.payments.filter_map(&:receipt).map { |receipt| { id: receipt.id, number: receipt.number } }
  end
end
