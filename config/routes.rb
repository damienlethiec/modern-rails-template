Rails.application.routes.draw do

  scope '(:locale)', locale: /fr|es/ do
  end
end