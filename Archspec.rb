component :controllers, in: "app/controllers/**/*.rb"

component :models,
  in: "app/models/**/*.rb",
  except: "app/models/current.rb"

component :application_context,
  in: "app/models/current.rb"

component :jobs, in: "app/jobs/**/*.rb"
component :mailers, in: "app/mailers/**/*.rb"
component :helpers, in: "app/helpers/**/*.rb"

component :policies, in: "app/policies/**/*.rb"
component :actions, in: "app/actions/**/*.rb"

controllers.can_only_use(
  :models,
  :application_context,
  :jobs,
  :mailers,
  :helpers,
  :policies,
)

actions.can_only_use(:policies, :models)
policies.can_only_use(:models)

models.cannot_use :controllers
application_context.cannot_use :controllers

# Jobs are excluded because models enqueue jobs and jobs call models.
no_cycles among: %i[
  controllers
  models
  mailers
  helpers
  application_context
  actions
  policies
]

no_cycles among: %i[ policies ]
