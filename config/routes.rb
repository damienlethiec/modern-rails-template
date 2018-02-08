Rails.application.routes.draw do

  scope '(:locale)', locale: /fr|es/ do
    root to: 'pages#home'
  end
end