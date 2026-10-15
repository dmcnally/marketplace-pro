guard :minitest, env: { "RAILS_ENV" => "test", "RACK_ENV" => "test" } do
  test_or_dir = ->(path, dir) { File.exist?(path) ? path : dir }

  watch(%r{^test/.+_test\.rb$})
  watch(%r{^test/(?:test_helper|test_helpers/.+)\.rb$}) { "test" }

  watch(%r{^app/actions/(.+)\.rb$}) { |m| test_or_dir.call("test/actions/#{m[1]}_test.rb", "test/actions") }
  watch(%r{^app/controllers/application_controller\.rb$}) { "test/controllers" }
  watch(%r{^app/controllers/concerns/(.+)\.rb$}) { "test/controllers" }
  watch(%r{^app/controllers/(.+)_controller\.rb$}) { |m| test_or_dir.call("test/controllers/#{m[1]}_controller_test.rb", "test/controllers") }
  watch(%r{^app/helpers/(.+)_helper\.rb$}) { |m| test_or_dir.call("test/helpers/#{m[1]}_helper_test.rb", "test/helpers") }
  watch(%r{^app/mailers/(.+)_mailer\.rb$}) { |m| test_or_dir.call("test/mailers/#{m[1]}_mailer_test.rb", "test/mailers") }
  watch(%r{^app/models/(.+)\.rb$}) { |m| test_or_dir.call("test/models/#{m[1]}_test.rb", "test/models") }
  watch(%r{^app/policies/(.+)\.rb$}) { |m| test_or_dir.call("test/policies/#{m[1]}_test.rb", "test/policies") }
  watch(%r{^lib/(.+)\.rb$}) { |m| test_or_dir.call("test/lib/#{m[1]}_test.rb", "test") }
end

guard :shell, all_on_start: true do
  brakeman = lambda do
    throw :task_has_failed unless system("bin/brakeman --no-pager")
  end

  watch(%r{^(?:app/.+\.(?:erb|haml|rhtml|rb)|config/.+\.rb|lib/.+\.rb|Gemfile)$}) { brakeman.call }
end
