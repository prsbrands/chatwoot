class Commerce::ItemPolicy < Commerce::BasePolicy
  def add_image?
    update?
  end

  def remove_image?
    update?
  end
end
