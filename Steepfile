# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature 'sig'
  ignore_signature 'sig/test'

  check 'lib' # Directory name
  # ignore "lib/templates/*.rb"

  library 'bigdecimal'
  library 'digest'
  library 'logger'
  library 'openssl'
  library 'socket'
  library 'stringio'

  # configure_code_diagnostics(D::Ruby.lenient)
  # configure_code_diagnostics(D::Ruby.default)
  configure_code_diagnostics(D::Ruby.strict)
  configure_code_diagnostics do |hash|
    hash[D::Ruby::UnannotatedEmptyCollection] = :information
  end
end
