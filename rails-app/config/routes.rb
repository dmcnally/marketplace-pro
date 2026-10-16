Rails.application.routes.draw do
  resource :session
  resource :registration, only: [ :new, :create ]
  resources :passwords, param: :token
  resources :invitations, only: [ :show ], param: :token
  post "invitations/:token/accept", to: "invitations/acceptances#create", as: :accept_invitation
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :approval, only: [ :create ]
  resource :publication, only: [ :create, :destroy ]

  resources :articles

  resources :buckets, only: [] do
    resource :switch, only: [ :create, :destroy ], controller: "buckets/switch"
  end

  resources :recordings, only: [] do
    resource :diff, only: [ :show ], controller: "recordings/diffs"
    resources :comments, only: [ :create, :destroy ]
  end

  get "no_bucket", to: "bucket_access#show", as: :no_bucket

  namespace :sys_admin do
    resources :buckets, only: [ :index, :show, :new, :create, :edit, :update ]
    resources :users, only: [ :index, :show ] do
      resource :password, only: [ :create ], module: :users
    end
    resource :dashboard, only: [ :show ]
    root "dashboards#show"
  end

  scope path: "admin", as: "admin" do
    resources :menus, except: :destroy do
      resources :sections, controller: "menu_sections", except: %i[index show] do
        resource :product_order, only: :create, controller: "menu_sections/product_orders"
      end
      resource :section_order, only: :create, controller: "menus/section_orders"
      resource :preview, only: :show, controller: "menus/previews"
    end
    resources :products, except: :destroy do
      resources :variants, only: %i[new create edit update]
      resource :variant_order, only: :create, controller: "products/variant_orders"
      resource :allergen_assignment, only: :create, controller: "products/allergen_assignments"
      resource :publication, only: %i[new create destroy], controller: "products/publications"
      resource :reversion, only: %i[new create], controller: "products/reversions"
    end
    resources :allergens, except: :destroy do
      resource :archive, only: %i[create destroy], controller: "allergens/archives"
    end
    resources :categories, except: :destroy do
      resource :archive, only: %i[create destroy], controller: "categories/archives"
    end
  end

  namespace :admin do
    resources :csv_imports, only: [ :index, :show, :new, :create, :destroy ]

    resources :invitations, only: [ :index, :new, :create, :destroy ]
    resources :members, only: [ :index ]
    resource :dashboard, only: [ :show ]
    root "dashboards#show"
  end

  root "articles#index"
end
