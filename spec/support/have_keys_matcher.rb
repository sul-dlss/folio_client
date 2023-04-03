# frozen_string_literal: true

# Check multiple hash keys at once
RSpec::Matchers.define :have_keys do |*keys|
  match do |hash|
    keys.all? { |key| expect(hash).to have_key(key) }
  end
end
