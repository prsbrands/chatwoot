# A vitrine pública do catálogo (fase 4b), sem login: o token do link é a
# chave, e a empresa liga e desliga em Company & payments. Mostra os itens
# disponíveis com foto, preço e categoria; o botão de cada um abre o WhatsApp da
# empresa com a mensagem pronta (sem WhatsApp, o e-mail). Idioma: ?lang= ou o
# da conta.
class CommercePublicCatalogsController < PublicController
  layout false

  def show
    @profile = ::Commerce::Profile.find_by!(storefront_token: params[:token], storefront_enabled: true)
    account = @profile.account
    raise ActiveRecord::RecordNotFound unless account.feature_enabled?('commerce')

    @labels = ::Commerce::DocumentLabels.for(@language = language_of(account))
    @items = account.commerce_items.where(available: true).includes(:category, images_attachments: :blob).order(:position, :name)
    @categories = @items.filter_map(&:category).uniq.sort_by(&:name)
    @category = @categories.find { |category| category.id.to_s == params[:category] }
    @items = @items.where(category: @category) if @category
  end

  private

  def language_of(account)
    params[:lang].presence_in(::Commerce::Document::LANGUAGES) ||
      account.locale.to_s.first(2).presence_in(::Commerce::Document::LANGUAGES) || 'es'
  end
end
