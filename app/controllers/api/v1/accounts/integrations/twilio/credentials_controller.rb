class Api::V1::Accounts::Integrations::Twilio::CredentialsController < Api::V1::Accounts::Integrations::Twilio::BaseController
  def show
    return render json: { connected: false } if credential.blank?

    render json: { connected: true, account_sid: credential.account_sid, friendly_name: client.friendly_name }
  end

  # Só grava depois que o Twilio confirma as credenciais: salvar uma chave que
  # não autentica deixaria a tela dizendo "conectado" com tudo quebrado abaixo.
  def create
    record = Current.account.twilio_credential || Current.account.build_twilio_credential
    record.assign_attributes(credential_params)
    return render json: { error: record.errors.full_messages.to_sentence }, status: :unprocessable_entity unless record.valid?

    friendly_name = Integrations::Twilio::AccountClient.new(credential: record).friendly_name
    record.save!
    render json: { connected: true, account_sid: record.account_sid, friendly_name: friendly_name }
  end

  def destroy
    credential&.destroy!
    head :ok
  end

  private

  def credential_params
    params.permit(:account_sid, :auth_token)
  end
end
