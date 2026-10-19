# A lista de exclusão decide quem a campanha não toca: é do admin.
class Outreach::SuppressionPolicy < ApplicationPolicy
  %i[index? create? destroy?].each do |action|
    define_method(action) { @account_user.administrator? }
  end
end
