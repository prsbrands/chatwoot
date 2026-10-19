# Campanha manda mensagem para gente de fora e arrisca o número: ver, criar e
# iniciar é do admin.
class Outreach::CampaignPolicy < ApplicationPolicy
  %i[index? show? create? update? destroy? audience? prepare? start? pause? cancel? test? preview_import? recipients? attention_count?
     preview?].each do |action|
    define_method(action) { @account_user.administrator? }
  end
end
