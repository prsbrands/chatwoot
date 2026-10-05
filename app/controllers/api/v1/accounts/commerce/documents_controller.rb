class Api::V1::Accounts::Commerce::DocumentsController < Api::V1::Accounts::Commerce::BaseController
  RESULTS_PER_PAGE = 50

  before_action :fetch_document, except: [:index, :create]
  before_action -> { check_authorization(@document || ::Commerce::Document) }

  # Filtros: kind, status, contact_id, deal_id e q (número ou nome do cliente).
  def index
    @documents = Current.account.commerce_documents.order(issue_date: :desc, id: :desc)
    %i[kind status contact_id deal_id].each { |key| @documents = @documents.where(key => params[key]) if params[key].present? }
    @documents = ::Commerce::Search.where(@documents, ['number', "customer->>'name'"], params[:q]) if params[:q].present?
    @documents = @documents.page(params[:page]).per(RESULTS_PER_PAGE)
  end

  def show; end

  def create
    @document = Current.account.commerce_documents.new(kind: params.require(:kind), issue_date: Date.current, created_by: Current.user,
                                                       **defaults)
    ::Commerce::DocumentEditor.new(@document, document_params).save!
    render :show
  end

  def update
    ::Commerce::DocumentEditor.new(@document, document_params).save!
    render :show
  end

  def destroy
    raise Pundit::NotAuthorizedError unless @document.draft?

    @document.destroy!
    head :ok
  end

  # Gera um PDF novo e o guarda no arquivo do documento.
  def pdf
    flow.archive_pdf!
    render :show
  end

  # channel: conversation (conversation_id, content opcional) ou email (to, subject, body).
  def deliver
    sender = ::Commerce::DocumentSender.new(@document, Current.user)
    case params.require(:channel)
    when 'conversation'
      sender.to_conversation!(Current.account.conversations.find_by!(display_id: params.require(:conversation_id)), params[:content])
    when 'email'
      sender.to_email!(params.require(:to), subject: params[:subject], body: params[:body])
    else
      raise ActionController::BadRequest, 'invalid channel'
    end
    render :show
  end

  def accept
    flow.accept!
    render :show
  end

  def decline
    flow.decline!
    render :show
  end

  def void
    flow.void!
    render :show
  end

  def to_invoice
    @document = flow.to_invoice!
    render :show
  end

  def add_payment
    payment = params.permit(:amount, :paid_on, :note, :payment_method_id)
    Current.account.commerce_payment_methods.find(payment[:payment_method_id]) if payment[:payment_method_id].present?
    flow.add_payment!(payment.to_h.symbolize_keys)
    render :show
  end

  def remove_payment
    flow.remove_payment!(@document.payments.find(params.require(:payment_id)))
    render :show
  end

  private

  def fetch_document
    @document = Current.account.commerce_documents.includes(:items, :payments).find(params[:id])
  end

  def flow
    ::Commerce::DocumentFlow.new(@document, user: Current.user)
  end

  # Documento novo começa com a moeda, as condições e o rodapé da empresa.
  def defaults
    profile = ::Commerce::Profile.for(Current.account)
    { currency: profile.default_currency, terms: profile.default_terms, footer: profile.footer,
      language: Current.account.locale.to_s.first(2).presence_in(::Commerce::Document::LANGUAGES) || 'es' }
  end

  def document_params
    params.permit(*::Commerce::DocumentEditor::HEADER, customer: ::Commerce::Document::CUSTOMER_FIELDS,
                                                       items: ::Commerce::DocumentEditor::LINE).to_h.symbolize_keys
  end
end
